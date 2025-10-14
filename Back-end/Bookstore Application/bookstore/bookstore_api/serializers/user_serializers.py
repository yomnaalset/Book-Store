from rest_framework import serializers
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from django.utils import timezone
from ..models import User, UserProfile


class BaseUserSerializer(serializers.ModelSerializer):
    """
    Base serializer for user creation with common fields.
    """
    password = serializers.CharField(
        write_only=True,
        min_length=8,
        style={'input_type': 'password'},
        help_text="Password must be at least 8 characters long"
    )
    password_confirm = serializers.CharField(
        write_only=True,
        style={'input_type': 'password'},
        help_text="Confirm your password"
    )
    
    class Meta:
        model = User
        fields = [
            'email', 'first_name', 'last_name', 'password', 'password_confirm',
            'user_type', 'preferred_language'
        ]
        extra_kwargs = {
            'email': {'required': True},
            'first_name': {'required': True},
            'last_name': {'required': True},
            'user_type': {'required': True},
        }
    
    def validate_email(self, value):
        """Validate email uniqueness."""
        if User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError("A user with this email already exists.")
        return value.lower()
    
    def validate_password(self, value):
        """Validate password using Django's built-in validators."""
        try:
            validate_password(value)
        except ValidationError as e:
            raise serializers.ValidationError(e.messages)
        return value
    
    def validate(self, attrs):
        """Validate password confirmation."""
        if attrs['password'] != attrs['password_confirm']:
            raise serializers.ValidationError({
                'password_confirm': "Passwords do not match."
            })
        return attrs
    
    def create(self, validated_data):
        """Create user and automatically create profile."""
        validated_data.pop('password_confirm')
        password = validated_data.pop('password')
        
        user = User.objects.create_user(
            password=password,
            **validated_data
        )
        
        # Create user profile
        UserProfile.objects.create(user=user)
        
        return user


class UnifiedRegistrationSerializer(BaseUserSerializer):
    """
    Unified serializer for all user types (customer, library_admin, delivery_admin).
    Only requires basic registration fields - profile fields are handled separately.
    Validates single library admin constraint.
    """
    user_type = serializers.ChoiceField(
        choices=[
            ('customer', 'Customer'),
            ('library_admin', 'Library Administrator'), 
            ('delivery_admin', 'Delivery Administrator')
        ],
        required=True,
        help_text="Type of account to create"
    )
    
    class Meta(BaseUserSerializer.Meta):
        fields = BaseUserSerializer.Meta.fields
    
    def validate_user_type(self, value):
        """
        Validate user type selection.
        Ensure only one library administrator can exist.
        """
        if value == 'library_admin':
            # Check if a library admin already exists
            existing_library_admin = User.objects.filter(
                user_type='library_admin', 
                is_active=True
            ).exists()
            
            if existing_library_admin:
                raise serializers.ValidationError(
                    "A library administrator already exists in the system. "
                    "Only one library administrator is allowed."
                )
        
        return value
    
    def create(self, validated_data):
        """Create user with appropriate permissions."""
        # Double-check library admin constraint at creation time
        if validated_data.get('user_type') == 'library_admin':
            existing_library_admin = User.objects.filter(
                user_type='library_admin', 
                is_active=True
            ).exists()
            
            if existing_library_admin:
                raise serializers.ValidationError({
                    'user_type': "A library administrator already exists in the system."
                })
        
        # Set appropriate values based on user type
        user_type = validated_data.get('user_type')
        if user_type in ['library_admin', 'delivery_admin']:
            # Set staff status for admin users
            validated_data['is_staff'] = True
        
        # Create user
        user = super().create(validated_data)
        
        return user


# Keep the individual serializers for backward compatibility but simplify them
class CustomerRegistrationSerializer(BaseUserSerializer):
    """
    Serializer for customer account creation.
    """
    
    class Meta(BaseUserSerializer.Meta):
        fields = BaseUserSerializer.Meta.fields
    
    def create(self, validated_data):
        """Create customer account."""
        # Set user type
        validated_data['user_type'] = 'customer'
        
        # Create user
        user = super().create(validated_data)
        
        return user


class LibraryAdminRegistrationSerializer(BaseUserSerializer):
    """
    Serializer for library administrator account creation.
    Validates single library admin constraint.
    """
    
    class Meta(BaseUserSerializer.Meta):
        fields = BaseUserSerializer.Meta.fields
    
    def validate(self, attrs):
        """
        Validate library admin creation.
        Ensure only one library administrator can exist.
        """
        attrs = super().validate(attrs)
        
        # Check if a library admin already exists
        existing_library_admin = User.objects.filter(
            user_type='library_admin', 
            is_active=True
        ).exists()
        
        if existing_library_admin:
            raise serializers.ValidationError({
                'user_type': "A library administrator already exists in the system. Only one library administrator is allowed."
            })
        
        return attrs
    
    def create(self, validated_data):
        """Create library administrator with admin privileges."""
        # Set user type and admin status
        validated_data['user_type'] = 'library_admin'
        validated_data['is_staff'] = True
        
        # Create user
        user = super().create(validated_data)
        
        return user


# Keep the old name for backward compatibility
class SystemAdminRegistrationSerializer(LibraryAdminRegistrationSerializer):
    """
    Deprecated: Use LibraryAdminRegistrationSerializer instead.
    """
    pass


class DeliveryAdminRegistrationSerializer(BaseUserSerializer):
    """
    Serializer for delivery administrator account creation.
    """
    
    class Meta(BaseUserSerializer.Meta):
        fields = BaseUserSerializer.Meta.fields
    
    def create(self, validated_data):
        """Create delivery administrator with limited admin privileges."""
        # Set user type and staff status
        validated_data['user_type'] = 'delivery_admin'
        validated_data['is_staff'] = True
        
        # Create user
        user = super().create(validated_data)
        
        return user


class UserProfileSerializer(serializers.ModelSerializer):
    """
    Serializer for user profile information.
    """
    user_email = serializers.EmailField(source='user.email', read_only=True)
    user_name = serializers.CharField(source='user.get_full_name', read_only=True)
    user_type = serializers.CharField(source='user.get_user_type_display', read_only=True)
    
    class Meta:
        model = UserProfile
        fields = [
            'user_email', 'user_name', 'user_type',
            'date_of_birth', 'profile_picture', 'created_at', 'updated_at'
        ]
        read_only_fields = ['created_at', 'updated_at']


class UserDetailSerializer(serializers.ModelSerializer):
    """
    Detailed serializer for user information including profile.
    Used for profile management interface.
    """
    profile = UserProfileSerializer(read_only=True)
    full_name = serializers.CharField(source='get_full_name', read_only=True)
    user_type_display = serializers.CharField(source='get_user_type_display', read_only=True)
    
    # Profile fields that can be updated through this interface
    profile_picture = serializers.ImageField(
        required=False, 
        allow_null=True,
        help_text="Upload profile picture or set to null to delete current picture"
    )
    date_of_birth = serializers.DateField(required=False, help_text="Date of birth")
    
    class Meta:
        model = User
        fields = [
            'id', 'email', 'username', 'first_name', 'last_name', 'full_name',
            'user_type', 'user_type_display', 'preferred_language', 'is_active', 
            'date_joined', 'last_updated', 'profile', 'profile_picture', 'date_of_birth'
        ]
        read_only_fields = [
            'id', 'username', 'date_joined', 'last_updated', 'user_type'
        ]
    
    def update(self, instance, validated_data):
        """
        Update user and profile information.
        Handles profile picture deletion when set to None/null.
        """
        # Extract profile-specific fields
        profile_picture = validated_data.pop('profile_picture', 'not_provided')
        date_of_birth = validated_data.pop('date_of_birth', None)
        
        # Update user fields
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        
        # Update profile fields if provided
        if profile_picture != 'not_provided' or date_of_birth is not None:
            profile = instance.profile
            
            # Handle profile picture update or deletion
            if profile_picture != 'not_provided':
                if profile_picture is None:
                    # Delete existing profile picture
                    if profile.profile_picture:
                        # Delete the file from storage
                        profile.profile_picture.delete(save=False)
                    profile.profile_picture = None
                else:
                    # Update with new profile picture
                    profile.profile_picture = profile_picture
            
            if date_of_birth is not None:
                profile.date_of_birth = date_of_birth
                
            profile.save()
        
        return instance


class ProfileUpdateSerializer(serializers.ModelSerializer):
    """
    Dedicated serializer for profile updates through the profile interface.
    Handles address, city, mobile number, and profile picture.
    Supports partial updates via PATCH requests.
    """
    # Profile fields from UserProfile model
    phone_number = serializers.CharField(
        required=False,
        allow_null=True,
        allow_blank=True,
        help_text="Mobile number"
    )
    address = serializers.CharField(
        required=False,
        allow_null=True,
        allow_blank=True,
        help_text="Full address"
    )
    city = serializers.CharField(
        required=False,
        allow_null=True,
        allow_blank=True,
        help_text="City"
    )
    zip_code = serializers.CharField(
        required=False,
        allow_null=True,
        allow_blank=True,
        help_text="ZIP/Postal Code"
    )
    country = serializers.CharField(
        required=False,
        allow_null=True,
        allow_blank=True,
        help_text="Country"
    )
    profile_picture = serializers.ImageField(
        required=False, 
        allow_null=True,
        help_text="Upload profile picture or set to null to delete current picture"
    )
    date_of_birth = serializers.DateField(
        required=False, 
        allow_null=True,
        help_text="Date of birth"
    )
    
    class Meta:
        model = User
        fields = [
            'first_name', 'last_name', 'preferred_language',
            'phone_number', 'address', 'city', 'zip_code', 'country',
            'profile_picture', 'date_of_birth'
        ]
        extra_kwargs = {
            'first_name': {'help_text': 'First name (from registration)',
                          'required': False},
            'last_name': {'help_text': 'Last name (from registration)',
                         'required': False},
            'preferred_language': {'help_text': 'Preferred language',
                                 'required': False},
        }
    
    def update(self, instance, validated_data):
        """
        Update user profile information with partial updates support.
        Handles profile picture deletion when set to None/null.
        Only updates fields that are provided in the request.
        """
        # Remove 'state' field if sent from frontend (not supported)
        validated_data.pop('state', None)
        
        # Extract profile-specific fields
        phone_number = validated_data.pop('phone_number', 'not_provided')
        address = validated_data.pop('address', 'not_provided')
        city = validated_data.pop('city', 'not_provided')
        zip_code = validated_data.pop('zip_code', 'not_provided')
        country = validated_data.pop('country', 'not_provided')
        profile_picture = validated_data.pop('profile_picture', 'not_provided')
        date_of_birth = validated_data.pop('date_of_birth', 'not_provided')
        
        # Update user fields (first_name, last_name, preferred_language) only if provided
        user_updated = False
        for attr, value in validated_data.items():
            if value is not None:  # Only update if value is not None
                # Validate first_name and last_name length
                if attr in ['first_name', 'last_name'] and len(str(value).strip()) > 30:
                    raise serializers.ValidationError({
                        attr: f'{attr.replace("_", " ").title()} must be 30 characters or less.'
                    })
                setattr(instance, attr, value)
                user_updated = True
        
        if user_updated:
            instance.save()
        
        # Update profile fields only if provided
        profile = instance.profile
        profile_updated = False
        
        # Update contact information only if provided
        if phone_number != 'not_provided':
            # Validate phone number format if provided
            if phone_number and not self._is_valid_phone(phone_number):
                raise serializers.ValidationError({
                    'phone_number': 'Phone number must be in valid format (+999999999).'
                })
            profile.phone_number = phone_number if phone_number else None
            profile_updated = True
        if address != 'not_provided':
            profile.address = address if address else None
            profile_updated = True
        if city != 'not_provided':
            profile.city = city if city else None
            profile_updated = True
        if zip_code != 'not_provided':
            profile.zip_code = zip_code if zip_code else None
            profile_updated = True
        if country != 'not_provided':
            profile.country = country if country else None
            profile_updated = True
        
        # Handle profile picture update or deletion only if provided
        if profile_picture != 'not_provided':
            if profile_picture is None:
                # Delete existing profile picture
                if profile.profile_picture:
                    # Delete the file from storage
                    profile.profile_picture.delete(save=False)
                profile.profile_picture = None
            else:
                # Update with new profile picture
                profile.profile_picture = profile_picture
            profile_updated = True
        
        # Handle date of birth only if provided
        if date_of_birth != 'not_provided':
            # Validate date of birth is not in the future
            if date_of_birth and date_of_birth > timezone.now().date():
                raise serializers.ValidationError({
                    'date_of_birth': 'Date of birth cannot be in the future.'
                })
            profile.date_of_birth = date_of_birth
            profile_updated = True
        
        if profile_updated:
            profile.save()
        
        return instance
    
    def _is_valid_phone(self, phone):
        """Validate phone number format."""
        import re
        # More flexible phone number validation that accepts various international formats
        phone_regex = re.compile(r'^\+?[\d\s\-\(\)]{7,20}$')
        return phone_regex.match(phone) is not None


class UserBasicInfoSerializer(serializers.ModelSerializer):
    """
    Basic user information serializer for foreign key relationships.
    """
    full_name = serializers.CharField(source='get_full_name', read_only=True)
    user_type_display = serializers.CharField(source='get_user_type_display', read_only=True)
    location = serializers.SerializerMethodField()
    phone_number = serializers.SerializerMethodField()
    
    class Meta:
        model = User
        fields = ['id', 'email', 'first_name', 'last_name', 'full_name', 'user_type', 'user_type_display', 'location', 'phone_number']
        read_only_fields = ['id', 'email', 'first_name', 'last_name', 'full_name', 'user_type', 'user_type_display', 'location', 'phone_number']
    
    def get_location(self, obj):
        """Get location data for delivery managers."""
        if obj.is_delivery_admin():
            return obj.get_location_dict()
        return None
        
    def get_phone_number(self, obj):
        """Get phone number from user profile if available"""
        try:
            if hasattr(obj, 'profile') and obj.profile.phone_number:
                return obj.profile.phone_number
        except Exception:
            pass
        return None


class UserTypeOptionsSerializer(serializers.Serializer):
    """
    Serializer for returning available user type options for registration.
    """
    user_types = serializers.DictField(read_only=True)
    library_admin_exists = serializers.BooleanField(read_only=True)
    available_types = serializers.ListField(read_only=True)


class LanguagePreferenceSerializer(serializers.ModelSerializer):
    """
    Serializer for updating user's language preference.
    """
    class Meta:
        model = User
        fields = ['preferred_language']
        
    def validate_preferred_language(self, value):
        """Validate that the language is supported."""
        from django.conf import settings
        supported_languages = [lang[0] for lang in settings.LANGUAGES]
        if value not in supported_languages:
            raise serializers.ValidationError(
                f"Language '{value}' is not supported. Supported languages: {supported_languages}"
            )
        return value


class LanguageOptionsSerializer(serializers.Serializer):
    """
    Serializer for returning available language options.
    """
    languages = serializers.ListField(read_only=True, help_text="List of available language choices")
    current_language = serializers.CharField(read_only=True, help_text="Current user's language preference")


class DeliveryManagerLocationSerializer(serializers.ModelSerializer):
    """
    Serializer for managing delivery manager location.
    """
    location_display = serializers.CharField(source='get_location_display', read_only=True)
    has_location = serializers.BooleanField(source='has_location', read_only=True)
    
    class Meta:
        model = User
        fields = [
            'id', 'first_name', 'last_name', 'email',
            'latitude', 'longitude', 'address', 'location_updated_at',
            'location_display', 'has_location'
        ]
        read_only_fields = ['id', 'first_name', 'last_name', 'email', 'location_updated_at', 'location_display', 'has_location']
    
    def validate_latitude(self, value):
        """Validate latitude value."""
        if value is not None and not (-90 <= value <= 90):
            raise serializers.ValidationError("Latitude must be between -90 and 90")
        return value
    
    def validate_longitude(self, value):
        """Validate longitude value."""
        if value is not None and not (-180 <= value <= 180):
            raise serializers.ValidationError("Longitude must be between -180 and 180")
        return value
    
    def validate(self, attrs):
        """Validate that at least one location field is provided."""
        latitude = attrs.get('latitude')
        longitude = attrs.get('longitude')
        address = attrs.get('address')
        
        if not any([latitude, longitude, address]):
            raise serializers.ValidationError("At least one location field (latitude, longitude, or address) must be provided")
        
        return attrs


class EmailChangeSerializer(serializers.Serializer):
    """
    Serializer for changing user email address.
    Requires current password for security.
    """
    new_email = serializers.EmailField(
        required=True,
        help_text="New email address"
    )
    confirm_email = serializers.EmailField(
        required=True,
        help_text="Confirm new email address"
    )
    current_password = serializers.CharField(
        write_only=True,
        required=True,
        style={'input_type': 'password'},
        help_text="Current password for verification"
    )
    
    def validate_new_email(self, value):
        """Validate new email uniqueness."""
        value = value.lower()
        user = self.context.get('user')
        
        # Check if email already exists, excluding current user
        if user:
            if User.objects.filter(email__iexact=value).exclude(id=user.id).exists():
                raise serializers.ValidationError("A user with this email already exists.")
        else:
            if User.objects.filter(email__iexact=value).exists():
                raise serializers.ValidationError("A user with this email already exists.")
        
        return value
    
    def validate(self, attrs):
        """Validate email confirmation and current password."""
        new_email = attrs.get('new_email', '').lower().strip()
        confirm_email = attrs.get('confirm_email', '').lower().strip()
        current_password = attrs.get('current_password')
        
        # Check email confirmation
        if new_email != confirm_email:
            raise serializers.ValidationError({
                'confirm_email': "Email addresses do not match."
            })
        
        # Check if new email is different from current
        user = self.context.get('user')
        if user and new_email == user.email.lower():
            raise serializers.ValidationError({
                'new_email': "The new email address is the same as your current email address. Please enter a different email address."
            })
        
        # Verify current password
        if user and current_password:
            if not user.check_password(current_password):
                raise serializers.ValidationError({
                    'current_password': "Current password is incorrect."
                })
        elif not user:
            raise serializers.ValidationError({
                'current_password': "User context not available for password verification."
            })
        elif not current_password:
            raise serializers.ValidationError({
                'current_password': "Current password is required."
            })
        
        return attrs


class PasswordChangeSerializer(serializers.Serializer):
    """Serializer for password change requests."""
    
    current_password = serializers.CharField(write_only=True)
    new_password = serializers.CharField(write_only=True, min_length=8)
    confirm_password = serializers.CharField(write_only=True)
    
    def validate_new_password(self, value):
        """Validate new password strength."""
        if len(value) < 8:
            raise serializers.ValidationError("Password must be at least 8 characters long.")
        
        if not any(c.isupper() for c in value):
            raise serializers.ValidationError("Password must contain at least one uppercase letter.")
        
        if not any(c.islower() for c in value):
            raise serializers.ValidationError("Password must contain at least one lowercase letter.")
        
        if not any(c.isdigit() for c in value):
            raise serializers.ValidationError("Password must contain at least one number.")
        
        if not any(c in "!@#$%^&*(),.?\":{}|<>" for c in value):
            raise serializers.ValidationError("Password must contain at least one special character.")
        
        return value
    
    def validate(self, attrs):
        """Validate password confirmation and current password."""
        new_password = attrs.get('new_password')
        confirm_password = attrs.get('confirm_password')
        current_password = attrs.get('current_password')
        
        # Check password confirmation
        if new_password != confirm_password:
            raise serializers.ValidationError({
                'confirm_password': "Passwords do not match."
            })
        
        # Check if new password is different from current
        if new_password == current_password:
            raise serializers.ValidationError({
                'new_password': "New password must be different from current password."
            })
        
        # Verify current password
        user = self.context.get('user')
        if user and current_password:
            if not user.check_password(current_password):
                raise serializers.ValidationError({
                    'current_password': "Current password is incorrect."
                })
        elif not current_password:
            raise serializers.ValidationError({
                'current_password': "Current password is required."
            })
        
        return attrs 
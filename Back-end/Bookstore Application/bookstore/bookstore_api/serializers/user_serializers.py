from rest_framework import serializers
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
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
            'user_type'
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
            'user_type', 'user_type_display', 'is_active', 'date_joined', 'last_updated',
            'profile', 'profile_picture', 'date_of_birth'
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
    """
    # Profile fields from UserProfile model
    phone_number = serializers.CharField(
        required=False,
        allow_null=True,
        help_text="Mobile number"
    )
    address = serializers.CharField(
        required=False,
        allow_null=True,
        help_text="Full address"
    )
    city = serializers.CharField(
        required=False,
        allow_null=True,
        help_text="City"
    )
    profile_picture = serializers.ImageField(
        required=False, 
        allow_null=True,
        help_text="Upload profile picture or set to null to delete current picture"
    )
    date_of_birth = serializers.DateField(required=False, help_text="Date of birth")
    
    class Meta:
        model = User
        fields = [
            'first_name', 'last_name',
            'profile_picture', 'date_of_birth'
        ]
        extra_kwargs = {
            'first_name': {'help_text': 'First name (from registration)'},
            'last_name': {'help_text': 'Last name (from registration)'},
        }
    
    def update(self, instance, validated_data):
        """
        Update user profile information.
        Handles profile picture deletion when set to None/null.
        """
        # Extract profile-specific fields
        phone_number = validated_data.pop('phone_number', 'not_provided')
        address = validated_data.pop('address', 'not_provided')
        city = validated_data.pop('city', 'not_provided')
        profile_picture = validated_data.pop('profile_picture', 'not_provided')
        date_of_birth = validated_data.pop('date_of_birth', None)
        
        # Update user fields (first_name, last_name only)
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        
        # Update profile fields
        profile = instance.profile
        profile_updated = False
        
        # Update contact information
        if phone_number != 'not_provided':
            profile.phone_number = phone_number
            profile_updated = True
        if address != 'not_provided':
            profile.address = address
            profile_updated = True
        if city != 'not_provided':
            profile.city = city
            profile_updated = True
        
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
            profile_updated = True
        
        # Handle date of birth
        if date_of_birth is not None:
            profile.date_of_birth = date_of_birth
            profile_updated = True
        
        if profile_updated:
            profile.save()
        
        return instance


class UserBasicInfoSerializer(serializers.ModelSerializer):
    """
    Basic user information serializer for foreign key relationships.
    """
    full_name = serializers.CharField(source='get_full_name', read_only=True)
    user_type_display = serializers.CharField(source='get_user_type_display', read_only=True)
    
    class Meta:
        model = User
        fields = ['id', 'email', 'first_name', 'last_name', 'full_name', 'user_type', 'user_type_display']
        read_only_fields = ['id', 'email', 'first_name', 'last_name', 'full_name', 'user_type', 'user_type_display']


class UserTypeOptionsSerializer(serializers.Serializer):
    """
    Serializer for returning available user type options for registration.
    """
    user_types = serializers.DictField(read_only=True)
    library_admin_exists = serializers.BooleanField(read_only=True)
    available_types = serializers.ListField(read_only=True) 
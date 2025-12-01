from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.db import models
from django.core.validators import RegexValidator


class UserManager(BaseUserManager):
    """
    Custom user manager for email-based authentication.
    """
    
    def create_user(self, email, password=None, **extra_fields):
        """
        Create and return a regular user with an email and password.
        """
        if not email:
            raise ValueError('The Email field must be set')
        
        email = self.normalize_email(email)
        extra_fields.setdefault('username', email)  # Set username to email
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user
    
    def create_superuser(self, email, password=None, **extra_fields):
        """
        Create and return a superuser with an email and password.
        """
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('user_type', 'library_admin')
        
        if extra_fields.get('is_staff') is not True:
            raise ValueError('Superuser must have is_staff=True.')
        if extra_fields.get('is_superuser') is not True:
            raise ValueError('Superuser must have is_superuser=True.')
        
        return self.create_user(email, password, **extra_fields)


class User(AbstractUser):
    """
    Custom User model for the bookstore application.
    Supports three user types: Customer, Library Admin, and Delivery Admin.
    """
    
    USER_TYPE_CHOICES = [
        ('customer', 'Customer'),
        ('library_admin', 'Library Administrator'),
        ('delivery_admin', 'Delivery Administrator'),
    ]
    
    LANGUAGE_CHOICES = [
        ('en', 'English'),
        ('ar', 'Arabic'),
    ]
    
    # Basic user information (required during registration)
    email = models.EmailField(unique=True, help_text="User's email address")
    first_name = models.CharField(max_length=30, help_text="User's first name")
    last_name = models.CharField(max_length=30, help_text="User's last name")
    user_type = models.CharField(
        max_length=20, 
        choices=USER_TYPE_CHOICES,
        default='customer',
        help_text="Type of user account"
    )
    
    # Language preference
    preferred_language = models.CharField(
        max_length=5,
        choices=LANGUAGE_CHOICES,
        default='en',
        help_text="User's preferred language for the interface"
    )
    
    # Note: Contact information (phone_number, address, city) moved to UserProfile model
    # Note: Delivery-related fields moved to DeliveryProfile model
    
    # Account status and metadata
    date_joined = models.DateTimeField(auto_now_add=True, help_text="Date when account was created")
    last_updated = models.DateTimeField(auto_now=True, help_text="Date when account was last updated")
    
    # Use email as the username field
    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['first_name', 'last_name', 'user_type']
    
    # Use custom manager
    objects = UserManager()
    
    class Meta:
        db_table = 'auth_user'
        verbose_name = 'User'
        verbose_name_plural = 'Users'
        indexes = [
            models.Index(fields=['email']),
            models.Index(fields=['user_type']),
            models.Index(fields=['is_active']),
        ]
    
    def __str__(self):
        return f"{self.get_full_name()} ({self.get_user_type_display()})"
    
    def get_full_name(self):
        """Return the user's full name."""
        return f"{self.first_name} {self.last_name}".strip()
    
    def get_short_name(self):
        """Return the user's first name."""
        return self.first_name
    
    def is_customer(self):
        """Check if user is a customer."""
        return self.user_type == 'customer'
    
    def is_library_admin(self):
        """Check if user is a library administrator."""
        return self.user_type == 'library_admin'
    
    def is_delivery_admin(self):
        """Check if user is a delivery administrator."""
        return self.user_type == 'delivery_admin'
    
    # Keep old method for backward compatibility (deprecated)
    def is_system_admin(self):
        """Check if user is a library administrator (deprecated - use is_library_admin)."""
        return self.is_library_admin()
    
    def get_language_preference(self):
        """Get user's preferred language."""
        return self.preferred_language or 'en'
    
    def has_location(self):
        """Check if user has location data."""
        if hasattr(self, 'delivery_profile'):
            return self.delivery_profile.is_location_set()
        return False
    
    def get_location_display(self):
        """Get formatted location string."""
        if hasattr(self, 'delivery_profile'):
            if self.delivery_profile.address:
                return self.delivery_profile.address
            elif self.delivery_profile.is_location_set():
                location = self.delivery_profile.get_location()
                if location:
                    return f"Lat: {location[0]}, Lng: {location[1]}"
        return "No location set"
    
    def update_location(self, latitude=None, longitude=None, address=None):
        """Update user's location data."""
        if not self.is_delivery_admin():
            raise ValueError("Only delivery administrators can update location")
        
        if hasattr(self, 'delivery_profile'):
            self.delivery_profile.update_location(latitude, longitude, address)
        else:
            # Create delivery profile if it doesn't exist
            from .delivery_profile_model import DeliveryProfile
            delivery_profile = DeliveryProfile.create_for_user(self)
            delivery_profile.update_location(latitude, longitude, address)
    
    def get_location_dict(self):
        """Get location as dictionary."""
        if hasattr(self, 'delivery_profile'):
            return {
                'latitude': float(self.delivery_profile.latitude) if self.delivery_profile.latitude else None,
                'longitude': float(self.delivery_profile.longitude) if self.delivery_profile.longitude else None,
                'address': self.delivery_profile.address,
                'location_updated_at': self.delivery_profile.location_updated_at,
                'has_location': self.delivery_profile.is_location_set(),
                'is_tracking_active': self.delivery_profile.is_tracking_active,
                'last_tracking_update': self.delivery_profile.last_tracking_update,
            }
        return {
            'latitude': None,
            'longitude': None,
            'address': None,
            'location_updated_at': None,
            'has_location': False,
            'is_tracking_active': False,
            'last_tracking_update': None,
        }
    
    def start_real_time_tracking(self, interval_seconds=30):
        """Start real-time location tracking."""
        if not self.is_delivery_admin():
            return False, "Only delivery managers can start real-time tracking"
        
        if hasattr(self, 'delivery_profile'):
            self.delivery_profile.set_tracking_active(True)
        else:
            # Create delivery profile if it doesn't exist
            from .delivery_profile_model import DeliveryProfile
            delivery_profile = DeliveryProfile.create_for_user(self)
            delivery_profile.set_tracking_active(True)
        
        return True, "Real-time tracking started"
    
    def stop_real_time_tracking(self):
        """Stop real-time location tracking."""
        if hasattr(self, 'delivery_profile'):
            self.delivery_profile.set_tracking_active(False)
        
        return True, "Real-time tracking stopped"
    
    def update_tracking_location(self, latitude, longitude, address=None, tracking_type='gps', 
                                accuracy=None, speed=None, heading=None, battery_level=None, 
                                network_type=None, delivery_assignment=None):
        """Update location with tracking metadata."""
        from django.utils import timezone
        from .delivery_model import LocationHistory
        
        # Update main location
        self.update_location(latitude, longitude, address)
        
        # Update tracking timestamp
        if hasattr(self, 'delivery_profile'):
            self.delivery_profile.last_tracking_update = timezone.now()
            self.delivery_profile.save(update_fields=['last_tracking_update'])
        
        # Create location history entry
        LocationHistory.objects.create(
            delivery_manager=self,
            latitude=latitude,
            longitude=longitude,
            address=address,
            tracking_type=tracking_type,
            accuracy=accuracy,
            speed=speed,
            heading=heading,
            battery_level=battery_level,
            network_type=network_type,
            delivery_assignment=delivery_assignment
        )
        
        return True, "Location updated with tracking data"
    
    def get_location_history(self, hours=24):
        """Get location history for the user."""
        from .delivery_model import LocationHistory
        return LocationHistory.get_recent_locations(self, hours)
    
    def get_movement_summary(self, hours=24):
        """Get movement summary for the user."""
        from .delivery_model import LocationHistory
        return LocationHistory.get_movement_summary(self, hours)
    
    def has_unpaid_fines(self):
        """Check if user has any unpaid fines."""
        if not self.is_customer():
            return False
        
        from .borrowing_model import BorrowRequest, FineStatusChoices
        return BorrowRequest.objects.filter(
            customer=self,
            fine_status=FineStatusChoices.UNPAID,
            fine_amount__gt=0
        ).exists()
    
    def get_total_unpaid_fines(self):
        """Get total amount of unpaid fines."""
        if not self.is_customer():
            return 0
        
        from .borrowing_model import BorrowRequest, FineStatusChoices
        from django.db.models import Sum
        result = BorrowRequest.objects.filter(
            customer=self,
            fine_status=FineStatusChoices.UNPAID,
            fine_amount__gt=0
        ).aggregate(total=Sum('fine_amount'))
        return result['total'] or 0
    
    def can_submit_borrow_request(self):
        """Check if user can submit a new borrow request."""
        if not self.is_customer():
            return False, "Only customers can submit borrow requests"
        
        if self.has_unpaid_fines():
            return False, "You cannot submit a new borrowing request until your pending fine is paid."
        
        return True, "Can submit borrow request"
    
    def has_complete_profile(self):
        """Check if user has completed their profile."""
        # Basic required fields
        required_fields = [self.first_name, self.last_name, self.email]
        if not all(field.strip() for field in required_fields if field):
            return False
        
        # Optional profile fields - not required for completion but good to have
        try:
            profile = self.profile
            profile_fields = [profile.phone_number, profile.address, profile.city]
            profile_complete = any(field and field.strip() for field in profile_fields if field)
            return profile_complete
        except:
            return False
    
    def get_profile_completion_percentage(self):
        """Get profile completion percentage."""
        total_fields = 6  # first_name, last_name, email, phone_number, address, city
        completed_fields = 3  # first_name, last_name, email (always completed after registration)
        
        # Check optional fields from profile
        try:
            profile = self.profile
            if profile.phone_number and profile.phone_number.strip():
                completed_fields += 1
            if profile.address and profile.address.strip():
                completed_fields += 1
            if profile.city and profile.city.strip():
                completed_fields += 1
            
            # Check profile picture if exists
            if profile.profile_picture:
                completed_fields += 1
                total_fields += 1
        except:
            pass
        
        return int((completed_fields / total_fields) * 100)
    
    def save(self, *args, **kwargs):
        """Override save to handle email as username and sync profile names."""
        if not self.username:
            self.username = self.email
        super().save(*args, **kwargs)
        
        # Sync name changes to profile if it exists
        try:
            if hasattr(self, 'profile') and self.profile:
                self.profile.sync_name_from_user()
                self.profile.save()
        except UserProfile.DoesNotExist:
            pass


class UserProfile(models.Model):
    """
    Extended profile information for users.
    Contains additional optional fields not required during registration.
    """
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profile')
    
    # Name fields (denormalized from User model for easier access)
    first_name = models.CharField(max_length=30, blank=True, help_text="User's first name (copied from user)")
    last_name = models.CharField(max_length=30, blank=True, help_text="User's last name (copied from user)")
    
    # Contact information (moved from User model)
    phone_regex = RegexValidator(
        regex=r'^\+?[\d\s\-\(\)]{7,20}$',
        message="Phone number must be entered in a valid format (e.g., +1234567890)."
    )
    phone_number = models.CharField(
        validators=[phone_regex], 
        max_length=17, 
        blank=True,
        null=True,
        help_text="User's mobile number"
    )
    
    # Address information (moved from User model)
    address = models.TextField(
        blank=True, 
        null=True, 
        help_text="User's address"
    )
    city = models.CharField(
        max_length=100,
        blank=True,
        null=True,
        help_text="User's city"  
    )
    zip_code = models.CharField(
        max_length=20,
        blank=True,
        null=True,
        help_text="User's ZIP or postal code"
    )
    country = models.CharField(
        max_length=100,
        blank=True,
        null=True,
        help_text="User's country"
    )
    
    # Additional profile fields (optional)
    date_of_birth = models.DateField(null=True, blank=True, help_text="User's date of birth")
    profile_picture = models.ImageField(
        upload_to='profile_pictures/', 
        null=True, 
        blank=True,
        help_text="User's profile picture"
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'user_profile'
        verbose_name = 'User Profile'
        verbose_name_plural = 'User Profiles'
    
    def __str__(self):
        return f"Profile of {self.user.get_full_name()}"
    
    def get_full_name(self):
        """Return the profile's full name."""
        return f"{self.first_name} {self.last_name}".strip()
    
    def sync_name_from_user(self):
        """Sync name fields from the associated User model."""
        if self.user:
            self.first_name = self.user.first_name
            self.last_name = self.user.last_name
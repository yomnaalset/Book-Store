from django.db import models
from django.contrib.auth import get_user_model
from django.utils import timezone

User = get_user_model()


class DeliveryProfile(models.Model):
    """
    Model for storing delivery manager specific information.
    This model is separate from the User model to keep delivery-related
    data organized and only relevant for delivery managers.
    """
    
    DELIVERY_STATUS_CHOICES = [
        ('online', 'Online - Available'),
        ('offline', 'Offline - Unavailable'),
    ]
    
    # One-to-one relationship with User
    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name='delivery_profile',
        help_text="The user this delivery profile belongs to"
    )
    
    # Delivery status
    delivery_status = models.CharField(
        max_length=20,
        choices=DELIVERY_STATUS_CHOICES,
        default='offline',
        null=True,  # Allow NULL as fallback for safety
        blank=True,
        help_text="Delivery manager availability: online (available) or offline (unavailable)"
    )
    
    # Location fields
    latitude = models.DecimalField(
        max_digits=10,
        decimal_places=7,
        null=True,
        blank=True,
        help_text="Latitude coordinate for delivery manager location"
    )
    
    longitude = models.DecimalField(
        max_digits=10,
        decimal_places=7,
        null=True,
        blank=True,
        help_text="Longitude coordinate for delivery manager location"
    )
    
    address = models.TextField(
        null=True,
        blank=True,
        help_text="Text address for delivery manager location"
    )
    
    location_updated_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When the location was last updated"
    )
    
    # Real-time tracking fields
    is_tracking_active = models.BooleanField(
        default=False,
        help_text="Whether real-time location tracking is currently active"
    )
    
    last_tracking_update = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Last time location was updated via tracking"
    )
    
    # Timestamps
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When the delivery profile was created"
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="When the delivery profile was last updated"
    )
    
    class Meta:
        db_table = 'delivery_profile'
        verbose_name = 'Delivery Profile'
        verbose_name_plural = 'Delivery Profiles'
        indexes = [
            models.Index(fields=['user']),
            models.Index(fields=['delivery_status']),
            models.Index(fields=['is_tracking_active']),
        ]
    
    def __str__(self):
        return f"Delivery Profile for {self.user.get_full_name()}"
    
    def update_location(self, latitude=None, longitude=None, address=None):
        """
        Update the delivery manager's location.
        Can update coordinates, address, or both.
        Only updates fields that are provided (not None).
        """
        if latitude is not None:
            self.latitude = latitude
        if longitude is not None:
            self.longitude = longitude
        if address is not None and address.strip():
            self.address = address
        self.location_updated_at = timezone.now()
        self.save()
    
    def set_tracking_active(self, is_active=True):
        """
        Set the tracking status for the delivery manager.
        """
        self.is_tracking_active = is_active
        if is_active:
            self.last_tracking_update = timezone.now()
        self.save()
    
    def get_location(self):
        """
        Get the current location as a tuple (latitude, longitude).
        Returns None if location is not set.
        """
        if self.latitude is not None and self.longitude is not None:
            return (float(self.latitude), float(self.longitude))
        return None
    
    def is_location_set(self):
        """
        Check if the delivery manager has set their location.
        """
        return self.latitude is not None and self.longitude is not None
    
    def get_delivery_status_display(self):
        """
        Get the human-readable delivery status.
        """
        if self.delivery_status is None:
            return 'Offline - Unavailable'
        return dict(self.DELIVERY_STATUS_CHOICES).get(self.delivery_status, self.delivery_status.capitalize() if self.delivery_status else 'Offline - Unavailable')
    
    @classmethod
    def create_for_user(cls, user):
        """
        Create a delivery profile for a user.
        This should be called when a user becomes a delivery manager.
        """
        if not user.is_delivery_admin():
            raise ValueError("Only delivery administrators can have delivery profiles")
        
        delivery_profile, created = cls.objects.get_or_create(
            user=user,
            defaults={
                'delivery_status': 'offline',
                'is_tracking_active': False,
            }
        )
        return delivery_profile
    
    @classmethod
    def get_online_delivery_managers(cls):
        """
        Get all delivery managers who are currently online.
        """
        return cls.objects.filter(
            delivery_status='online',
            is_tracking_active=True
        ).select_related('user')
    
    @classmethod
    def get_available_delivery_managers(cls):
        """
        Get all delivery managers who are available for delivery.
        Only returns managers with 'online' status.
        """
        return cls.objects.filter(
            delivery_status='online',
            is_tracking_active=True
        ).select_related('user')
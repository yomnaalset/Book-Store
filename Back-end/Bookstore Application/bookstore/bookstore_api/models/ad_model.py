from django.db import models
from django.core.exceptions import ValidationError
from django.utils import timezone
from datetime import timedelta

from .user_model import User


class AdvertisementStatusChoices(models.TextChoices):
    """Choices for advertisement status"""
    ACTIVE = 'active', 'Active'
    INACTIVE = 'inactive', 'Inactive'
    SCHEDULED = 'scheduled', 'Scheduled'
    EXPIRED = 'expired', 'Expired'


class Advertisement(models.Model):
    """
    Advertisement model for managing library advertisements.
    Only library administrators can create, edit, or delete advertisements.
    """
    
    # Basic advertisement information
    title = models.CharField(
        max_length=200,
        help_text="Title of the advertisement"
    )
    
    content = models.TextField(
        help_text="Content/description of the advertisement"
    )
    
    
    # Image field for advertisement banner
    image = models.ImageField(
        upload_to='advertisements/',
        null=True,
        blank=True,
        help_text="Advertisement banner image"
    )
    
    # Date and time fields
    start_date = models.DateTimeField(
        help_text="Start date and time for the advertisement"
    )
    
    end_date = models.DateTimeField(
        help_text="End date and time for the advertisement"
    )
    
    # Status field
    status = models.CharField(
        max_length=20,
        choices=AdvertisementStatusChoices.choices,
        default=AdvertisementStatusChoices.INACTIVE,
        help_text="Current status of the advertisement"
    )
    
    
    # Metadata
    created_by = models.ForeignKey(
        User,
        on_delete=models.PROTECT,
        related_name='created_advertisements',
        limit_choices_to={'user_type': 'library_admin'},
        help_text="Library administrator who created this advertisement"
    )
    
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="Date and time when advertisement was created"
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="Date and time when advertisement was last updated"
    )
    
    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Advertisement'
        verbose_name_plural = 'Advertisements'
        indexes = [
            models.Index(fields=['status', 'start_date', 'end_date']),
            models.Index(fields=['created_by']),
        ]
    
    def __str__(self):
        return f"{self.title} ({self.get_status_display()})"
    
    def clean(self):
        """Validate the advertisement data"""
        super().clean()
        
        # Validate that end_date is after start_date
        if self.start_date and self.end_date:
            # Ensure both dates are timezone-aware for comparison
            start_date = self.start_date
            end_date = self.end_date
            
            if start_date.tzinfo is None:
                start_date = timezone.make_aware(start_date)
            if end_date.tzinfo is None:
                end_date = timezone.make_aware(end_date)
                
            if end_date <= start_date:
                raise ValidationError({
                    'end_date': 'End date must be after start date.'
                })
        
        # Validate that start_date is not in the past for new advertisements
        if self.pk is None and self.start_date:
            start_date = self.start_date
            if start_date.tzinfo is None:
                start_date = timezone.make_aware(start_date)
                
            if start_date < timezone.now():
                raise ValidationError({
                    'start_date': 'Start date cannot be in the past for new advertisements.'
                })
    
    def save(self, *args, **kwargs):
        """Override save to automatically set status based on dates"""
        self.full_clean()
        
        # Only auto-set status if it hasn't been explicitly set by the user
        # Check if this is an update (has pk) and if status was explicitly changed
        is_update = self.pk is not None
        original_status = None
        
        if is_update:
            try:
                original = Advertisement.objects.get(pk=self.pk)
                original_status = original.status
            except Advertisement.DoesNotExist:
                original_status = None
        
        # Auto-set status based on current time and dates only if:
        # 1. This is a new advertisement (not an update), OR
        # 2. This is an update but the status hasn't been explicitly changed by the user
        should_auto_set_status = not is_update or (is_update and self.status == original_status)
        
        if should_auto_set_status and self.status != AdvertisementStatusChoices.EXPIRED:
            # Ensure dates are timezone-aware for comparison
            now = timezone.now()
            start_date = self.start_date
            end_date = self.end_date
            
            if start_date and start_date.tzinfo is None:
                start_date = timezone.make_aware(start_date)
            if end_date and end_date.tzinfo is None:
                end_date = timezone.make_aware(end_date)
            
            if end_date and end_date <= now:
                self.status = AdvertisementStatusChoices.EXPIRED
            elif start_date and start_date > now:
                self.status = AdvertisementStatusChoices.SCHEDULED
            elif start_date and start_date <= now and (not end_date or end_date > now):
                if self.status == AdvertisementStatusChoices.SCHEDULED:
                    self.status = AdvertisementStatusChoices.ACTIVE
        
        super().save(*args, **kwargs)
    
    def is_active(self):
        """Check if advertisement is currently active"""
        now = timezone.now()
        
        # Ensure dates are timezone-aware for comparison
        start_date = self.start_date
        end_date = self.end_date
        
        if start_date and start_date.tzinfo is None:
            start_date = timezone.make_aware(start_date)
        if end_date and end_date.tzinfo is None:
            end_date = timezone.make_aware(end_date)
        
        return (
            self.status == AdvertisementStatusChoices.ACTIVE and
            start_date <= now and
            (not end_date or end_date > now)
        )
    
    def is_scheduled(self):
        """Check if advertisement is scheduled for future"""
        now = timezone.now()
        start_date = self.start_date
        
        if start_date and start_date.tzinfo is None:
            start_date = timezone.make_aware(start_date)
        
        return (
            self.status == AdvertisementStatusChoices.SCHEDULED and
            start_date > now
        )
    
    def is_expired(self):
        """Check if advertisement has expired"""
        now = timezone.now()
        end_date = self.end_date
        
        if end_date and end_date.tzinfo is None:
            end_date = timezone.make_aware(end_date)
        
        return (
            self.status == AdvertisementStatusChoices.EXPIRED or
            (end_date and end_date <= now)
        )
    
    
    def get_duration_days(self):
        """Get the duration of the advertisement in days"""
        if self.start_date and self.end_date:
            return (self.end_date - self.start_date).days
        return 0
    
    def get_remaining_days(self):
        """Get remaining days until expiration"""
        if self.end_date:
            now = timezone.now()
            end_date = self.end_date
            
            if end_date.tzinfo is None:
                end_date = timezone.make_aware(end_date)
                
            remaining = end_date - now
            return max(0, remaining.days)
        return None

from django.db import models
from django.contrib.auth import get_user_model
from django.core.validators import MinValueValidator, MaxValueValidator

User = get_user_model()


class UserNotificationPreferences(models.Model):
    """Model for storing user notification preferences."""
    
    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name='notification_preferences'
    )
    
    # Notification Channels
    email_notifications = models.BooleanField(default=True)
    push_notifications = models.BooleanField(default=True)
    sms_notifications = models.BooleanField(default=False)
    
    # Notification Types
    order_updates = models.BooleanField(default=True)
    book_availability = models.BooleanField(default=True)
    borrow_reminders = models.BooleanField(default=True)
    delivery_updates = models.BooleanField(default=True)
    promotional_emails = models.BooleanField(default=False)
    newsletter = models.BooleanField(default=False)
    
    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'user_notification_preferences'
        verbose_name = 'User Notification Preferences'
        verbose_name_plural = 'User Notification Preferences'
    
    def __str__(self):
        return f"Notification Preferences for {self.user.email}"


class UserPrivacyPreferences(models.Model):
    """Model for storing user privacy preferences."""
    
    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name='privacy_preferences'
    )
    
    # Profile Visibility
    profile_visibility = models.BooleanField(default=True)
    show_email = models.BooleanField(default=False)
    show_phone = models.BooleanField(default=False)
    show_address = models.BooleanField(default=False)
    
    # Data Collection
    data_collection = models.BooleanField(default=True)
    analytics = models.BooleanField(default=True)
    marketing = models.BooleanField(default=False)
    third_party_sharing = models.BooleanField(default=False)
    
    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'user_privacy_preferences'
        verbose_name = 'User Privacy Preferences'
        verbose_name_plural = 'User Privacy Preferences'
    
    def __str__(self):
        return f"Privacy Preferences for {self.user.email}"


class UserPreference(models.Model):
    """
    Comprehensive user preferences model that includes all user settings.
    This replaces the manage_settings functionality and makes settings user-specific.
    """
    
    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name='user_preferences'
    )
    
    # Language and Display Settings
    language = models.CharField(
        max_length=10,
        default='en',
        choices=[
            ('en', 'English'),
            ('ar', 'Arabic'),
        ]
    )
    dark_mode = models.BooleanField(default=False)
    theme = models.CharField(
        max_length=20,
        default='light',
        choices=[
            ('light', 'Light'),
            ('dark', 'Dark'),
            ('auto', 'Auto'),
            ('blue', 'Blue'),
            ('green', 'Green'),
            ('purple', 'Purple'),
        ]
    )
    timezone = models.CharField(max_length=50, default='UTC')
    date_format = models.CharField(
        max_length=20,
        default='YYYY-MM-DD',
        choices=[
            ('YYYY-MM-DD', 'YYYY-MM-DD'),
            ('MM/DD/YYYY', 'MM/DD/YYYY'),
            ('DD/MM/YYYY', 'DD/MM/YYYY'),
            ('DD-MM-YYYY', 'DD-MM-YYYY'),
        ]
    )
    time_format = models.CharField(
        max_length=10,
        default='24h',
        choices=[
            ('12h', '12 Hour'),
            ('24h', '24 Hour'),
        ]
    )
    currency = models.CharField(
        max_length=10,
        default='USD',
        choices=[
            ('USD', 'US Dollar'),
            ('EUR', 'Euro'),
            ('GBP', 'British Pound'),
            ('JPY', 'Japanese Yen'),
            ('CAD', 'Canadian Dollar'),
            ('AUD', 'Australian Dollar'),
            ('CHF', 'Swiss Franc'),
            ('CNY', 'Chinese Yuan'),
            ('INR', 'Indian Rupee'),
            ('BRL', 'Brazilian Real'),
        ]
    )
    
    # Notification Settings
    email_notifications = models.BooleanField(default=True)
    push_notifications = models.BooleanField(default=True)
    sms_notifications = models.BooleanField(default=False)
    notifications_sound = models.BooleanField(default=True)
    notifications_vibration = models.BooleanField(default=True)
    
    # Display and Performance Settings
    items_per_page = models.PositiveIntegerField(
        default=10,
        validators=[MinValueValidator(1), MaxValueValidator(100)]
    )
    auto_refresh = models.BooleanField(default=True)
    refresh_interval = models.PositiveIntegerField(
        default=30,
        validators=[MinValueValidator(5), MaxValueValidator(300)]
    )
    sidebar_collapsed = models.BooleanField(default=False)
    
    # Auto-save Settings
    auto_save = models.BooleanField(default=True)
    auto_save_interval = models.PositiveIntegerField(
        default=5,
        validators=[MinValueValidator(1), MaxValueValidator(60)]
    )
    
    # UI Settings
    show_tooltips = models.BooleanField(default=True)
    show_help_text = models.BooleanField(default=True)
    
    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'user_preferences'
        verbose_name = 'User Preferences'
        verbose_name_plural = 'User Preferences'
    
    def __str__(self):
        return f"Preferences for {self.user.email}"
    
    @classmethod
    def get_default_preferences(cls):
        """Get default preferences for a new user."""
        return {
            'language': 'en',
            'dark_mode': False,
            'theme': 'light',
            'timezone': 'UTC',
            'date_format': 'YYYY-MM-DD',
            'time_format': '24h',
            'currency': 'USD',
            'email_notifications': True,
            'push_notifications': True,
            'sms_notifications': False,
            'notifications_sound': True,
            'notifications_vibration': True,
            'items_per_page': 10,
            'auto_refresh': True,
            'refresh_interval': 30,
            'sidebar_collapsed': False,
            'auto_save': True,
            'auto_save_interval': 5,
            'show_tooltips': True,
            'show_help_text': True,
        }
    
    def reset_to_defaults(self):
        """Reset all preferences to default values."""
        defaults = self.get_default_preferences()
        for field, value in defaults.items():
            setattr(self, field, value)
        self.save()
    
    def get_settings_dict(self):
        """Get all settings as a dictionary."""
        return {
            'language': self.language,
            'dark_mode': self.dark_mode,
            'theme': self.theme,
            'timezone': self.timezone,
            'date_format': self.date_format,
            'time_format': self.time_format,
            'currency': self.currency,
            'email_notifications': self.email_notifications,
            'push_notifications': self.push_notifications,
            'sms_notifications': self.sms_notifications,
            'notifications_sound': self.notifications_sound,
            'notifications_vibration': self.notifications_vibration,
            'items_per_page': self.items_per_page,
            'auto_refresh': self.auto_refresh,
            'refresh_interval': self.refresh_interval,
            'sidebar_collapsed': self.sidebar_collapsed,
            'auto_save': self.auto_save,
            'auto_save_interval': self.auto_save_interval,
            'show_tooltips': self.show_tooltips,
            'show_help_text': self.show_help_text,
        }
    
    def update_settings(self, settings_dict):
        """Update settings from a dictionary."""
        for field, value in settings_dict.items():
            if hasattr(self, field):
                setattr(self, field, value)
        self.save()

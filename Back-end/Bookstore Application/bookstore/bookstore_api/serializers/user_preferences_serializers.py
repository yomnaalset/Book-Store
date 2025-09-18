from rest_framework import serializers
from ..models import UserNotificationPreferences, UserPrivacyPreferences, UserPreference


class UserNotificationPreferencesSerializer(serializers.ModelSerializer):
    """Serializer for user notification preferences."""
    
    class Meta:
        model = UserNotificationPreferences
        fields = [
            'email_notifications',
            'push_notifications',
            'sms_notifications',
            'order_updates',
            'book_availability',
            'borrow_reminders',
            'delivery_updates',
            'promotional_emails',
            'newsletter',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['created_at', 'updated_at']


class UserPrivacyPreferencesSerializer(serializers.ModelSerializer):
    """Serializer for user privacy preferences."""
    
    class Meta:
        model = UserPrivacyPreferences
        fields = [
            'profile_visibility',
            'show_email',
            'show_phone',
            'show_address',
            'data_collection',
            'analytics',
            'marketing',
            'third_party_sharing',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['created_at', 'updated_at']


class NotificationPreferencesUpdateSerializer(serializers.Serializer):
    """Serializer for updating notification preferences."""
    
    email_notifications = serializers.BooleanField(required=False)
    push_notifications = serializers.BooleanField(required=False)
    sms_notifications = serializers.BooleanField(required=False)
    order_updates = serializers.BooleanField(required=False)
    book_availability = serializers.BooleanField(required=False)
    borrow_reminders = serializers.BooleanField(required=False)
    delivery_updates = serializers.BooleanField(required=False)
    promotional_emails = serializers.BooleanField(required=False)
    newsletter = serializers.BooleanField(required=False)


class PrivacyPreferencesUpdateSerializer(serializers.Serializer):
    """Serializer for updating privacy preferences."""
    
    profile_visibility = serializers.BooleanField(required=False)
    show_email = serializers.BooleanField(required=False)
    show_phone = serializers.BooleanField(required=False)
    show_address = serializers.BooleanField(required=False)
    data_collection = serializers.BooleanField(required=False)
    analytics = serializers.BooleanField(required=False)
    marketing = serializers.BooleanField(required=False)
    third_party_sharing = serializers.BooleanField(required=False)


class UserPreferenceSerializer(serializers.ModelSerializer):
    """
    Comprehensive serializer for user preferences.
    This replaces the manage_settings serializers and makes settings user-specific.
    """
    
    class Meta:
        model = UserPreference
        fields = [
            # Language and Display Settings
            'language', 'dark_mode', 'theme', 'timezone', 'date_format', 
            'time_format', 'currency',
            # Notification Settings
            'email_notifications', 'push_notifications', 'sms_notifications',
            'notifications_sound', 'notifications_vibration',
            # Display and Performance Settings
            'items_per_page', 'auto_refresh', 'refresh_interval', 'sidebar_collapsed',
            # Auto-save Settings
            'auto_save', 'auto_save_interval',
            # UI Settings
            'show_tooltips', 'show_help_text',
            # Timestamps
            'created_at', 'updated_at',
        ]
        read_only_fields = ['created_at', 'updated_at']
    
    def validate_language(self, value):
        """Validate language code."""
        valid_languages = ['en', 'ar']
        if value not in valid_languages:
            raise serializers.ValidationError(f"Language '{value}' is not supported.")
        return value
    
    def validate_timezone(self, value):
        """Validate timezone string."""
        # Basic timezone validation without external dependencies
        if not isinstance(value, str) or len(value) < 3:
            raise serializers.ValidationError(f"Timezone '{value}' is not valid.")
        
        # Check for common timezone patterns
        valid_patterns = ['UTC', 'GMT', 'EST', 'PST', 'CST', 'MST', 'EDT', 'PDT', 'CDT', 'MDT']
        if not any(pattern in value.upper() for pattern in valid_patterns) and '/' not in value:
            raise serializers.ValidationError(f"Timezone '{value}' format is not recognized.")
        
        return value
    
    def validate_date_format(self, value):
        """Validate date format string."""
        valid_formats = ['YYYY-MM-DD', 'MM/DD/YYYY', 'DD/MM/YYYY', 'DD-MM-YYYY']
        if value not in valid_formats:
            raise serializers.ValidationError(f"Date format '{value}' is not supported.")
        return value
    
    def validate_time_format(self, value):
        """Validate time format string."""
        valid_formats = ['12h', '24h']
        if value not in valid_formats:
            raise serializers.ValidationError(f"Time format '{value}' is not supported.")
        return value
    
    def validate_currency(self, value):
        """Validate currency code."""
        valid_currencies = ['USD', 'EUR', 'GBP', 'JPY', 'CAD', 'AUD', 'CHF', 'CNY', 'INR', 'BRL']
        if value not in valid_currencies:
            raise serializers.ValidationError(f"Currency '{value}' is not supported.")
        return value
    
    def validate_theme(self, value):
        """Validate theme name."""
        valid_themes = ['light', 'dark', 'auto', 'blue', 'green', 'purple']
        if value not in valid_themes:
            raise serializers.ValidationError(f"Theme '{value}' is not supported.")
        return value
    
    def validate(self, data):
        """Validate the entire preferences object."""
        # Check for conflicting settings
        if data.get('dark_mode') and data.get('theme') == 'light':
            raise serializers.ValidationError(
                "Cannot have dark_mode=True with theme='light'"
            )
        
        if not data.get('dark_mode') and data.get('theme') == 'dark':
            raise serializers.ValidationError(
                "Cannot have dark_mode=False with theme='dark'"
            )
        
        # Check notification settings consistency
        if data.get('sms_notifications') and not data.get('email_notifications'):
            raise serializers.ValidationError(
                "SMS notifications require email notifications to be enabled"
            )
        
        return data


class UserPreferenceResponseSerializer(serializers.Serializer):
    """
    Serializer for user preference API responses.
    """
    
    success = serializers.BooleanField()
    message = serializers.CharField()
    data = UserPreferenceSerializer(required=False)
    errors = serializers.DictField(required=False)


class UserPreferenceUpdateSerializer(serializers.Serializer):
    """
    Serializer for updating user preferences.
    Allows partial updates.
    """
    
    # Language and Display Settings
    language = serializers.CharField(max_length=10, required=False)
    dark_mode = serializers.BooleanField(required=False)
    theme = serializers.CharField(max_length=20, required=False)
    timezone = serializers.CharField(max_length=50, required=False)
    date_format = serializers.CharField(max_length=20, required=False)
    time_format = serializers.CharField(max_length=10, required=False)
    currency = serializers.CharField(max_length=10, required=False)
    
    # Notification Settings
    email_notifications = serializers.BooleanField(required=False)
    push_notifications = serializers.BooleanField(required=False)
    sms_notifications = serializers.BooleanField(required=False)
    notifications_sound = serializers.BooleanField(required=False)
    notifications_vibration = serializers.BooleanField(required=False)
    
    # Display and Performance Settings
    items_per_page = serializers.IntegerField(min_value=1, max_value=100, required=False)
    auto_refresh = serializers.BooleanField(required=False)
    refresh_interval = serializers.IntegerField(min_value=5, max_value=300, required=False)
    sidebar_collapsed = serializers.BooleanField(required=False)
    
    # Auto-save Settings
    auto_save = serializers.BooleanField(required=False)
    auto_save_interval = serializers.IntegerField(min_value=1, max_value=60, required=False)
    
    # UI Settings
    show_tooltips = serializers.BooleanField(required=False)
    show_help_text = serializers.BooleanField(required=False)
    
    def validate(self, data):
        """Validate the update data."""
        if not data:
            raise serializers.ValidationError("At least one field must be provided for update.")
        return data


class UserPreferenceResetSerializer(serializers.Serializer):
    """
    Serializer for resetting user preferences to defaults.
    """
    
    confirm_reset = serializers.BooleanField(default=False)
    
    def validate_confirm_reset(self, value):
        """Validate that reset is confirmed."""
        if not value:
            raise serializers.ValidationError("Reset must be confirmed.")
        return value

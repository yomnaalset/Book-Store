from django.contrib.auth import get_user_model
from django.utils import timezone
from typing import Dict, Any, Optional, Tuple
from ..models import UserPreference
import logging

logger = logging.getLogger(__name__)

User = get_user_model()


class UserPreferencesService:
    """
    Service class for managing user preferences.
    Handles business logic for user-specific settings operations.
    """
    
    @staticmethod
    def get_or_create_user_preferences(user: User) -> Tuple[UserPreference, bool]:
        """
        Get or create user preferences for a specific user.
        Returns (preferences, created) tuple.
        """
        try:
            preferences, created = UserPreference.objects.get_or_create(
                user=user,
                defaults=UserPreference.get_default_preferences()
            )
            return preferences, created
        except Exception as e:
            logger.error(f"Error getting/creating preferences for user {user.id}: {e}")
            raise
    
    @staticmethod
    def get_user_preferences(user: User) -> Dict[str, Any]:
        """
        Get user preferences as a dictionary.
        """
        try:
            preferences, _ = UserPreferencesService.get_or_create_user_preferences(user)
            return preferences.get_settings_dict()
        except Exception as e:
            logger.error(f"Error getting preferences for user {user.id}: {e}")
            return UserPreference.get_default_preferences()
    
    @staticmethod
    def update_user_preferences(user: User, settings: Dict[str, Any]) -> bool:
        """
        Update user preferences with new settings.
        """
        try:
            preferences, _ = UserPreferencesService.get_or_create_user_preferences(user)
            
            # Validate and update settings
            validated_settings = UserPreferencesService.validate_settings(settings)
            preferences.update_settings(validated_settings)
            
            logger.info(f"Updated preferences for user {user.id}")
            return True
            
        except Exception as e:
            logger.error(f"Error updating preferences for user {user.id}: {e}")
            return False
    
    @staticmethod
    def reset_user_preferences(user: User) -> bool:
        """
        Reset user preferences to default values.
        """
        try:
            preferences, _ = UserPreferencesService.get_or_create_user_preferences(user)
            preferences.reset_to_defaults()
            
            logger.info(f"Reset preferences for user {user.id}")
            return True
            
        except Exception as e:
            logger.error(f"Error resetting preferences for user {user.id}: {e}")
            return False
    
    @staticmethod
    def validate_settings(settings: Dict[str, Any]) -> Dict[str, Any]:
        """
        Validate and sanitize settings data.
        """
        validated_settings = {}
        
        # Language validation
        if 'language' in settings:
            language = settings['language']
            valid_languages = ['en', 'ar']
            if isinstance(language, str) and language in valid_languages:
                validated_settings['language'] = language
            else:
                validated_settings['language'] = 'en'
        
        # Boolean settings validation
        boolean_fields = [
            'dark_mode', 'email_notifications', 'push_notifications',
            'sms_notifications', 'notifications_sound', 'notifications_vibration',
            'auto_refresh', 'sidebar_collapsed', 'auto_save', 'show_tooltips',
            'show_help_text'
        ]
        
        for field in boolean_fields:
            if field in settings:
                validated_settings[field] = bool(settings[field])
        
        # Numeric settings validation
        numeric_fields = {
            'items_per_page': (1, 100),
            'refresh_interval': (5, 300),
            'auto_save_interval': (1, 60)
        }
        
        for field, (min_val, max_val) in numeric_fields.items():
            if field in settings:
                try:
                    value = int(settings[field])
                    validated_settings[field] = max(min_val, min(max_val, value))
                except (ValueError, TypeError):
                    validated_settings[field] = min_val
        
        # String settings validation
        string_fields = {
            'timezone': 50,
            'date_format': 20,
            'time_format': 10,
            'currency': 10,
            'theme': 20
        }
        
        for field, max_length in string_fields.items():
            if field in settings:
                value = str(settings[field])
                validated_settings[field] = value[:max_length]
        
        # Theme validation
        if 'theme' in validated_settings:
            valid_themes = ['light', 'dark', 'auto', 'blue', 'green', 'purple']
            if validated_settings['theme'] not in valid_themes:
                validated_settings['theme'] = 'light'
        
        # Date format validation
        if 'date_format' in validated_settings:
            valid_formats = ['YYYY-MM-DD', 'MM/DD/YYYY', 'DD/MM/YYYY', 'DD-MM-YYYY']
            if validated_settings['date_format'] not in valid_formats:
                validated_settings['date_format'] = 'YYYY-MM-DD'
        
        # Time format validation
        if 'time_format' in validated_settings:
            valid_formats = ['12h', '24h']
            if validated_settings['time_format'] not in valid_formats:
                validated_settings['time_format'] = '24h'
        
        # Currency validation
        if 'currency' in validated_settings:
            valid_currencies = ['USD', 'EUR', 'GBP', 'JPY', 'CAD', 'AUD', 'CHF', 'CNY', 'INR', 'BRL']
            if validated_settings['currency'] not in valid_currencies:
                validated_settings['currency'] = 'USD'
        
        return validated_settings
    
    @staticmethod
    def merge_preferences(current_preferences: Dict[str, Any], new_preferences: Dict[str, Any]) -> Dict[str, Any]:
        """
        Merge new preferences with current preferences.
        """
        merged = current_preferences.copy()
        merged.update(new_preferences)
        return merged
    
    @staticmethod
    def get_preferences_for_user_type(user: User) -> Dict[str, Any]:
        """
        Get preferences tailored for the user's role (customer, library_admin, delivery_admin, etc.).
        """
        try:
            preferences = UserPreferencesService.get_user_preferences(user)
            
            # Add role-specific default preferences if not set
            if user.is_library_admin():
                preferences.setdefault('items_per_page', 20)  # Library admins might want more items per page
                preferences.setdefault('auto_refresh', True)  # Library admins need real-time updates
            elif user.is_delivery_admin():
                preferences.setdefault('items_per_page', 15)  # Delivery admins moderate page size
                preferences.setdefault('auto_refresh', True)  # Delivery admins need real-time updates
            else:
                # Regular customers
                preferences.setdefault('items_per_page', 10)
                preferences.setdefault('auto_refresh', False)  # Customers don't need auto-refresh
            
            return preferences
            
        except Exception as e:
            logger.error(f"Error getting role-specific preferences for user {user.id}: {e}")
            return UserPreference.get_default_preferences()
    
    @staticmethod
    def delete_user_preferences(user: User) -> bool:
        """
        Delete user preferences (useful for account deletion).
        """
        try:
            UserPreference.objects.filter(user=user).delete()
            logger.info(f"Deleted preferences for user {user.id}")
            return True
        except Exception as e:
            logger.error(f"Error deleting preferences for user {user.id}: {e}")
            return False
    
    @staticmethod
    def get_preferences_statistics() -> Dict[str, Any]:
        """
        Get statistics about user preferences (for admin purposes).
        """
        try:
            total_users = User.objects.count()
            users_with_preferences = UserPreference.objects.count()
            
            # Get most common settings
            language_stats = {}
            theme_stats = {}
            
            for pref in UserPreference.objects.all():
                language = pref.language
                theme = pref.theme
                
                language_stats[language] = language_stats.get(language, 0) + 1
                theme_stats[theme] = theme_stats.get(theme, 0) + 1
            
            return {
                'total_users': total_users,
                'users_with_preferences': users_with_preferences,
                'preferences_coverage': (users_with_preferences / total_users * 100) if total_users > 0 else 0,
                'language_distribution': language_stats,
                'theme_distribution': theme_stats,
            }
            
        except Exception as e:
            logger.error(f"Error getting preferences statistics: {e}")
            return {}

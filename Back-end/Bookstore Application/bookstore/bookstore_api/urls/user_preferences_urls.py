from django.urls import path
from bookstore_api.views.user_preferences_views import (
    NotificationPreferencesView,
    PrivacyPreferencesView,
    UserPreferencesView,
    UserPreferencesResetView,
    UserPreferencesStatisticsView,
)

user_preferences_urls = [
    # Legacy notification preferences endpoints
    path('notifications/', NotificationPreferencesView.as_view(), name='notification_preferences'),
    
    # Legacy privacy preferences endpoints
    path('privacy/', PrivacyPreferencesView.as_view(), name='privacy_preferences'),
    
    # Comprehensive user preferences endpoints (replaces manage_settings)
    path('settings/', UserPreferencesView.as_view(), name='user_preferences'),
    path('settings/reset/', UserPreferencesResetView.as_view(), name='user_preferences_reset'),
    
    # Admin statistics endpoint
    path('statistics/', UserPreferencesStatisticsView.as_view(), name='user_preferences_statistics'),
]

from rest_framework import status, permissions
from rest_framework.views import APIView
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
import logging

from ..models import UserNotificationPreferences, UserPrivacyPreferences, UserPreference
from ..serializers import (
    UserNotificationPreferencesSerializer,
    UserPrivacyPreferencesSerializer,
    NotificationPreferencesUpdateSerializer,
    PrivacyPreferencesUpdateSerializer,
    UserPreferenceSerializer,
    UserPreferenceUpdateSerializer,
    UserPreferenceResetSerializer,
)
from ..services.user_preferences_services import UserPreferencesService

logger = logging.getLogger(__name__)


class NotificationPreferencesView(APIView):
    """API view for managing user notification preferences."""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        """Get user's notification preferences."""
        try:
            user = request.user
            preferences, created = UserNotificationPreferences.objects.get_or_create(
                user=user,
                defaults={
                    'email_notifications': True,
                    'push_notifications': True,
                    'sms_notifications': False,
                    'order_updates': True,
                    'book_availability': True,
                    'borrow_reminders': True,
                    'delivery_updates': True,
                    'promotional_emails': False,
                    'newsletter': False,
                }
            )
            
            serializer = UserNotificationPreferencesSerializer(preferences)
            
            logger.info(f"Retrieved notification preferences for user {user.id}")
            return Response({
                'success': True,
                'message': 'Notification preferences retrieved successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving notification preferences for user {request.user.id}: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve notification preferences',
                'errors': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    def put(self, request):
        """Update user's notification preferences."""
        try:
            user = request.user
            preferences, created = UserNotificationPreferences.objects.get_or_create(
                user=user,
                defaults={
                    'email_notifications': True,
                    'push_notifications': True,
                    'sms_notifications': False,
                    'order_updates': True,
                    'book_availability': True,
                    'borrow_reminders': True,
                    'delivery_updates': True,
                    'promotional_emails': False,
                    'newsletter': False,
                }
            )
            
            serializer = NotificationPreferencesUpdateSerializer(data=request.data)
            if serializer.is_valid():
                # Update only the provided fields
                for field, value in serializer.validated_data.items():
                    setattr(preferences, field, value)
                
                preferences.save()
                
                response_serializer = UserNotificationPreferencesSerializer(preferences)
                
                logger.info(f"Updated notification preferences for user {user.id}")
                return Response({
                    'success': True,
                    'message': 'Notification preferences updated successfully',
                    'data': response_serializer.data
                }, status=status.HTTP_200_OK)
            else:
                logger.warning(f"Invalid notification preferences data for user {user.id}: {serializer.errors}")
                return Response({
                    'success': False,
                    'message': 'Invalid notification preferences data',
                    'errors': serializer.errors
                }, status=status.HTTP_400_BAD_REQUEST)
                
        except Exception as e:
            logger.error(f"Error updating notification preferences for user {request.user.id}: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to update notification preferences',
                'errors': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class PrivacyPreferencesView(APIView):
    """API view for managing user privacy preferences."""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        """Get user's privacy preferences."""
        try:
            user = request.user
            preferences, created = UserPrivacyPreferences.objects.get_or_create(
                user=user,
                defaults={
                    'profile_visibility': True,
                    'show_email': False,
                    'show_phone': False,
                    'show_address': False,
                    'data_collection': True,
                    'analytics': True,
                    'marketing': False,
                    'third_party_sharing': False,
                }
            )
            
            serializer = UserPrivacyPreferencesSerializer(preferences)
            
            logger.info(f"Retrieved privacy preferences for user {user.id}")
            return Response({
                'success': True,
                'message': 'Privacy preferences retrieved successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving privacy preferences for user {request.user.id}: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve privacy preferences',
                'errors': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    def put(self, request):
        """Update user's privacy preferences."""
        try:
            user = request.user
            preferences, created = UserPrivacyPreferences.objects.get_or_create(
                user=user,
                defaults={
                    'profile_visibility': True,
                    'show_email': False,
                    'show_phone': False,
                    'show_address': False,
                    'data_collection': True,
                    'analytics': True,
                    'marketing': False,
                    'third_party_sharing': False,
                }
            )
            
            serializer = PrivacyPreferencesUpdateSerializer(data=request.data)
            if serializer.is_valid():
                # Update only the provided fields
                for field, value in serializer.validated_data.items():
                    setattr(preferences, field, value)
                
                preferences.save()
                
                response_serializer = UserPrivacyPreferencesSerializer(preferences)
                
                logger.info(f"Updated privacy preferences for user {user.id}")
                return Response({
                    'success': True,
                    'message': 'Privacy preferences updated successfully',
                    'data': response_serializer.data
                }, status=status.HTTP_200_OK)
            else:
                logger.warning(f"Invalid privacy preferences data for user {user.id}: {serializer.errors}")
                return Response({
                    'success': False,
                    'message': 'Invalid privacy preferences data',
                    'errors': serializer.errors
                }, status=status.HTTP_400_BAD_REQUEST)
                
        except Exception as e:
            logger.error(f"Error updating privacy preferences for user {request.user.id}: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to update privacy preferences',
                'errors': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class UserPreferencesView(APIView):
    """
    Comprehensive API view for managing user preferences.
    This replaces the manage_settings functionality and makes settings user-specific.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        """Get user's comprehensive preferences."""
        try:
            user = request.user
            
            # Get user preferences using the service
            preferences_data = UserPreferencesService.get_preferences_for_user_type(user)
            
            # Create a mock UserPreference object for serialization
            preferences = UserPreference(**preferences_data)
            serializer = UserPreferenceSerializer(preferences)
            
            logger.info(f"Retrieved comprehensive preferences for user {user.id}")
            return Response({
                'success': True,
                'message': 'User preferences retrieved successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving preferences for user {request.user.id}: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve user preferences',
                'errors': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    def patch(self, request):
        """Update user's preferences."""
        try:
            user = request.user
            
            # Validate the request data
            serializer = UserPreferenceUpdateSerializer(data=request.data)
            if not serializer.is_valid():
                return Response({
                    'success': False,
                    'message': 'Invalid preferences data',
                    'errors': serializer.errors
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Update preferences using the service
            if UserPreferencesService.update_user_preferences(user, serializer.validated_data):
                # Get updated preferences
                updated_preferences = UserPreferencesService.get_user_preferences(user)
                updated_serializer = UserPreferenceSerializer(UserPreference(**updated_preferences))
                
                logger.info(f"Updated preferences for user {user.id}")
                return Response({
                    'success': True,
                    'message': 'User preferences updated successfully',
                    'data': updated_serializer.data
                }, status=status.HTTP_200_OK)
            else:
                return Response({
                    'success': False,
                    'message': 'Failed to update preferences',
                    'errors': {'update': ['Could not update preferences in database']}
                }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
                
        except Exception as e:
            logger.error(f"Error updating preferences for user {request.user.id}: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to update user preferences',
                'errors': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class UserPreferencesResetView(APIView):
    """
    API view to reset user preferences to default values.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        """Reset user preferences to default values."""
        try:
            user = request.user
            
            # Validate the reset request
            serializer = UserPreferenceResetSerializer(data=request.data)
            if not serializer.is_valid():
                return Response({
                    'success': False,
                    'message': 'Invalid reset request',
                    'errors': serializer.errors
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Reset preferences using the service
            if UserPreferencesService.reset_user_preferences(user):
                # Get the default preferences to return
                default_preferences = UserPreferencesService.get_user_preferences(user)
                default_serializer = UserPreferenceSerializer(UserPreference(**default_preferences))
                
                logger.info(f"Reset preferences for user {user.id}")
                return Response({
                    'success': True,
                    'message': 'User preferences reset to defaults successfully',
                    'data': default_serializer.data
                }, status=status.HTTP_200_OK)
            else:
                return Response({
                    'success': False,
                    'message': 'Failed to reset preferences',
                    'errors': {'reset': ['Could not reset preferences in database']}
                }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
            
        except Exception as e:
            logger.error(f"Error resetting preferences for user {request.user.id}: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to reset user preferences',
                'errors': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class UserPreferencesStatisticsView(APIView):
    """
    API view for getting preferences statistics (admin only).
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        """Get preferences statistics."""
        try:
            user = request.user
            
            # Check if user is admin or manager
            if not (user.is_staff or user.is_library_admin() or user.is_delivery_admin()):
                return Response({
                    'success': False,
                    'message': 'Access denied. Admin privileges required.',
                    'errors': {'permission': ['Only administrators can access this endpoint']}
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Get statistics using the service
            statistics = UserPreferencesService.get_preferences_statistics()
            
            logger.info(f"Retrieved preferences statistics for admin {user.id}")
            return Response({
                'success': True,
                'message': 'Preferences statistics retrieved successfully',
                'data': statistics
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving preferences statistics: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve preferences statistics',
                'errors': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

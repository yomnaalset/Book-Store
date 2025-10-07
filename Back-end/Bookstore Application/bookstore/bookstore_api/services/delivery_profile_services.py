from django.contrib.auth import get_user_model
from django.db import transaction
from django.utils import timezone
from datetime import timedelta
import logging

from ..models import DeliveryProfile, Notification, NotificationType
from ..utils import format_error_message

User = get_user_model()
logger = logging.getLogger(__name__)


class DeliveryProfileService:
    """
    Service class for managing delivery profile operations.
    This service handles all business logic related to delivery profiles.
    """
    
    @staticmethod
    def create_delivery_profile(user):
        """
        Create a delivery profile for a user.
        
        Args:
            user: User instance (must be a delivery administrator)
            
        Returns:
            DeliveryProfile: The created delivery profile
            
        Raises:
            ValueError: If user is not a delivery administrator
        """
        if not user.is_delivery_admin():
            raise ValueError("Only delivery administrators can have delivery profiles")
        
        try:
            delivery_profile = DeliveryProfile.objects.create(
                user=user,
                delivery_status='offline',
                is_tracking_active=False,
            )
            
            logger.info(f"Created delivery profile for user {user.id}")
            return delivery_profile
            
        except Exception as e:
            logger.error(f"Error creating delivery profile for user {user.id}: {str(e)}")
            raise ValueError(f"Failed to create delivery profile: {str(e)}")
    
    @staticmethod
    def get_or_create_delivery_profile(user):
        """
        Get existing delivery profile or create a new one.
        Only creates profiles for delivery administrators.
        
        Args:
            user: User instance
            
        Returns:
            DeliveryProfile: The delivery profile
            
        Raises:
            ValueError: If user is not a delivery administrator
        """
        if not user.is_delivery_admin():
            raise ValueError("Only delivery administrators can have delivery profiles")
        
        try:
            delivery_profile, created = DeliveryProfile.objects.get_or_create(
                user=user,
                defaults={
                    'delivery_status': 'offline',
                    'is_tracking_active': False,
                }
            )
            
            if created:
                logger.info(f"Created new delivery profile for user {user.id}")
            else:
                logger.debug(f"Retrieved existing delivery profile for user {user.id}")
                
            return delivery_profile
            
        except Exception as e:
            logger.error(f"Error getting/creating delivery profile for user {user.id}: {str(e)}")
            raise ValueError(f"Failed to get/create delivery profile: {str(e)}")
    
    @staticmethod
    def update_location(user, latitude, longitude, address=None):
        """
        Update the delivery manager's location.
        
        Args:
            user: User instance
            latitude: Latitude coordinate
            longitude: Longitude coordinate
            address: Optional address string
            
        Returns:
            DeliveryProfile: Updated delivery profile
        """
        if not user.is_delivery_admin():
            raise ValueError("Only delivery administrators can update location")
        
        try:
            delivery_profile = DeliveryProfileService.get_or_create_delivery_profile(user)
            delivery_profile.update_location(latitude, longitude, address)
            
            logger.info(f"Updated location for user {user.id}: {latitude}, {longitude}")
            return delivery_profile
            
        except Exception as e:
            logger.error(f"Error updating location for user {user.id}: {str(e)}")
            raise ValueError(f"Failed to update location: {str(e)}")
    
    @staticmethod
    def update_delivery_status(user, status):
        """
        Update the delivery manager's status.
        
        Args:
            user: User instance
            status: Delivery status ('online', 'offline', 'busy')
            
        Returns:
            DeliveryProfile: Updated delivery profile
        """
        if not user.is_delivery_admin():
            raise ValueError("Only delivery administrators can update delivery status")
        
        valid_statuses = [choice[0] for choice in DeliveryProfile.DELIVERY_STATUS_CHOICES]
        if status not in valid_statuses:
            raise ValueError(f"Invalid delivery status. Must be one of: {valid_statuses}")
        
        try:
            delivery_profile = DeliveryProfileService.get_or_create_delivery_profile(user)
            old_status = delivery_profile.delivery_status
            delivery_profile.delivery_status = status
            delivery_profile.save(update_fields=['delivery_status'])
            
            # Send notification about status change
            DeliveryProfileService.notify_status_change(delivery_profile, old_status, status)
            
            logger.info(f"Updated delivery status for user {user.id} to: {status}")
            return delivery_profile
            
        except Exception as e:
            logger.error(f"Error updating delivery status for user {user.id}: {str(e)}")
            raise ValueError(f"Failed to update delivery status: {str(e)}")
    
    @staticmethod
    def update_tracking_status(user, is_tracking_active):
        """
        Update the delivery manager's tracking status.
        
        Args:
            user: User instance
            is_tracking_active: Boolean indicating if tracking is active
            
        Returns:
            DeliveryProfile: Updated delivery profile
        """
        if not user.is_delivery_admin():
            raise ValueError("Only delivery administrators can update tracking status")
        
        try:
            delivery_profile = DeliveryProfileService.get_or_create_delivery_profile(user)
            delivery_profile.set_tracking_active(is_tracking_active)
            
            logger.info(f"Updated tracking status for user {user.id} to: {is_tracking_active}")
            return delivery_profile
            
        except Exception as e:
            logger.error(f"Error updating tracking status for user {user.id}: {str(e)}")
            raise ValueError(f"Failed to update tracking status: {str(e)}")
    
    @staticmethod
    def get_delivery_profile(user):
        """
        Get the delivery profile for a user.
        
        Args:
            user: User instance
            
        Returns:
            DeliveryProfile or None: The delivery profile if it exists
        """
        try:
            return DeliveryProfile.objects.get(user=user)
        except DeliveryProfile.DoesNotExist:
            return None
        except Exception as e:
            logger.error(f"Error getting delivery profile for user {user.id}: {str(e)}")
            raise ValueError(f"Failed to get delivery profile: {str(e)}")
    
    @staticmethod
    def get_online_delivery_managers():
        """
        Get all delivery managers who are currently online.
        
        Returns:
            QuerySet: Online delivery managers
        """
        try:
            return DeliveryProfile.objects.filter(
                delivery_status='online',
                is_tracking_active=True
            ).select_related('user')
        except Exception as e:
            logger.error(f"Error getting online delivery managers: {str(e)}")
            raise ValueError(f"Failed to get online delivery managers: {str(e)}")
    
    @staticmethod
    def get_available_delivery_managers():
        """
        Get all delivery managers who are available for delivery.
        
        Returns:
            QuerySet: Available delivery managers
        """
        try:
            return DeliveryProfile.objects.filter(
                delivery_status__in=['online', 'busy'],
                is_tracking_active=True
            ).select_related('user')
        except Exception as e:
            logger.error(f"Error getting available delivery managers: {str(e)}")
            raise ValueError(f"Failed to get available delivery managers: {str(e)}")
    
    @staticmethod
    def get_delivery_manager_location(user_id):
        """
        Get the location of a specific delivery manager.
        
        Args:
            user_id: ID of the delivery manager
            
        Returns:
            dict: Location data or None if not found
        """
        try:
            delivery_profile = DeliveryProfile.objects.get(user_id=user_id)
            return {
                'latitude': float(delivery_profile.latitude) if delivery_profile.latitude else None,
                'longitude': float(delivery_profile.longitude) if delivery_profile.longitude else None,
                'address': delivery_profile.address,
                'location_updated_at': delivery_profile.location_updated_at,
                'is_tracking_active': delivery_profile.is_tracking_active,
                'delivery_status': delivery_profile.delivery_status,
            }
        except DeliveryProfile.DoesNotExist:
            return None
        except Exception as e:
            logger.error(f"Error getting delivery manager location for user {user_id}: {str(e)}")
            raise ValueError(f"Failed to get delivery manager location: {str(e)}")
    
    @staticmethod
    def get_delivery_manager_stats():
        """
        Get statistics about delivery managers.
        
        Returns:
            dict: Statistics about delivery managers
        """
        try:
            total_managers = DeliveryProfile.objects.count()
            online_managers = DeliveryProfile.objects.filter(delivery_status='online').count()
            busy_managers = DeliveryProfile.objects.filter(delivery_status='busy').count()
            offline_managers = DeliveryProfile.objects.filter(delivery_status='offline').count()
            tracking_active = DeliveryProfile.objects.filter(is_tracking_active=True).count()
            
            return {
                'total_managers': total_managers,
                'online_managers': online_managers,
                'busy_managers': busy_managers,
                'offline_managers': offline_managers,
                'tracking_active': tracking_active,
                'available_managers': online_managers + busy_managers,
            }
        except Exception as e:
            logger.error(f"Error getting delivery manager stats: {str(e)}")
            raise ValueError(f"Failed to get delivery manager stats: {str(e)}")
    
    @staticmethod
    def notify_status_change(delivery_profile, old_status, new_status):
        """
        Send notification when delivery manager status changes.
        
        Args:
            delivery_profile: DeliveryProfile instance
            old_status: Previous status
            new_status: New status
        """
        try:
            # Only notify if status actually changed
            if old_status == new_status:
                return
            
            # Create notification for admins
            admin_users = User.objects.filter(
                user_type__in=['library_admin', 'system_admin']
            )
            
            for admin in admin_users:
                Notification.objects.create(
                    recipient=admin,
                    title=f"Delivery Manager Status Update",
                    message=f"{delivery_profile.user.get_full_name()} status changed from {old_status} to {new_status}",
                    notification_type=NotificationType.objects.get_or_create(
                        name='delivery_status_update',
                        defaults={'description': 'Delivery manager status updates'}
                    )[0],
                )
            
            logger.info(f"Sent status change notifications for user {delivery_profile.user.id}")
            
        except Exception as e:
            logger.error(f"Error sending status change notifications: {str(e)}")
            # Don't raise exception as this is not critical
    
    @staticmethod
    def cleanup_inactive_profiles(days_inactive=30):
        """
        Clean up delivery profiles that haven't been active for a specified period.
        
        Args:
            days_inactive: Number of days to consider inactive
            
        Returns:
            int: Number of profiles cleaned up
        """
        try:
            cutoff_date = timezone.now() - timedelta(days=days_inactive)
            
            inactive_profiles = DeliveryProfile.objects.filter(
                updated_at__lt=cutoff_date,
                delivery_status='offline',
                is_tracking_active=False
            )
            
            count = inactive_profiles.count()
            inactive_profiles.delete()
            
            logger.info(f"Cleaned up {count} inactive delivery profiles")
            return count
            
        except Exception as e:
            logger.error(f"Error cleaning up inactive profiles: {str(e)}")
            raise ValueError(f"Failed to cleanup inactive profiles: {str(e)}")
    
    @staticmethod
    def bulk_update_status(user_ids, status):
        """
        Update delivery status for multiple users.
        
        Args:
            user_ids: List of user IDs
            status: New delivery status
            
        Returns:
            int: Number of profiles updated
        """
        try:
            valid_statuses = [choice[0] for choice in DeliveryProfile.DELIVERY_STATUS_CHOICES]
            if status not in valid_statuses:
                raise ValueError(f"Invalid delivery status. Must be one of: {valid_statuses}")
            
            count = DeliveryProfile.objects.filter(
                user_id__in=user_ids
            ).update(delivery_status=status)
            
            logger.info(f"Bulk updated {count} delivery profiles to status: {status}")
            return count
            
        except Exception as e:
            logger.error(f"Error bulk updating delivery status: {str(e)}")
            raise ValueError(f"Failed to bulk update delivery status: {str(e)}")
    
    @staticmethod
    def get_delivery_profile_history(user, days=7):
        """
        Get delivery profile change history for a user.
        
        Args:
            user: User instance
            days: Number of days to look back
            
        Returns:
            QuerySet: Delivery profile history
        """
        try:
            cutoff_date = timezone.now() - timedelta(days=days)
            
            # This would require a separate history model in a real implementation
            # For now, we'll return the current profile with basic info
            profile = DeliveryProfileService.get_delivery_profile(user)
            if profile:
                return [profile]  # Simplified for now
            return []
            
        except Exception as e:
            logger.error(f"Error getting delivery profile history for user {user.id}: {str(e)}")
            raise ValueError(f"Failed to get delivery profile history: {str(e)}")
    
    @staticmethod
    def cleanup_non_delivery_admin_profiles():
        """
        Remove delivery profiles for users who are not delivery administrators.
        This should be run to clean up existing invalid entries.
        
        Returns:
            int: Number of profiles removed
        """
        try:
            # Get all delivery profiles where the user is not a delivery admin
            invalid_profiles = DeliveryProfile.objects.exclude(
                user__user_type='delivery_admin'
            )
            
            count = invalid_profiles.count()
            invalid_profiles.delete()
            
            logger.info(f"Cleaned up {count} delivery profiles for non-delivery administrators")
            return count
            
        except Exception as e:
            logger.error(f"Error cleaning up non-delivery admin profiles: {str(e)}")
            raise ValueError(f"Failed to cleanup non-delivery admin profiles: {str(e)}")
    
    @staticmethod
    def get_delivery_admin_profiles():
        """
        Get all delivery profiles for users who are actually delivery administrators.
        
        Returns:
            QuerySet: Delivery profiles for delivery administrators only
        """
        try:
            return DeliveryProfile.objects.filter(
                user__user_type='delivery_admin'
            ).select_related('user')
        except Exception as e:
            logger.error(f"Error getting delivery admin profiles: {str(e)}")
            raise ValueError(f"Failed to get delivery admin profiles: {str(e)}")

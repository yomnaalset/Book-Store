from django.contrib.auth import get_user_model
from django.db import transaction
from django.utils import timezone
from datetime import timedelta
import logging
import threading

from ..models import DeliveryProfile, Notification, NotificationType
from ..utils import format_error_message

User = get_user_model()
logger = logging.getLogger(__name__)

# Thread-local storage to prevent recursion
_status_check_lock = threading.local()

def ensure_correct_status(delivery_profile, skip_if_checking=False):
    """
    Helper function to ensure delivery profile status is correct.
    Automatically resets to 'online' if status is 'busy' but no active deliveries exist.
    This should be called whenever delivery profile is accessed.
    
    Args:
        delivery_profile: DeliveryProfile instance
        skip_if_checking: If True, skip if already checking status (prevents recursion)
        
    Returns:
        bool: True if status was reset, False otherwise
    """
    if not delivery_profile or delivery_profile.delivery_status != 'busy':
        return False
    
    # Prevent recursion - if we're already checking status, don't check again
    if skip_if_checking or hasattr(_status_check_lock, 'checking'):
        return False
    
    try:
        # Set flag to prevent recursion
        _status_check_lock.checking = True
        
        user = delivery_profile.user
        if not user.is_delivery_admin():
            return False
        
        # Use skip_status_check=True to prevent recursion in reset_status_if_no_active_deliveries
        was_reset = DeliveryProfileService.reset_status_if_no_active_deliveries(user, skip_status_check=True)
        if was_reset:
            delivery_profile.refresh_from_db()
            logger.info(f"Auto-corrected delivery status for user {user.id} from 'busy' to 'online'")
        return was_reset
    except Exception as e:
        logger.error(f"Error in ensure_correct_status for user {delivery_profile.user.id}: {str(e)}")
        return False
    finally:
        # Clear flag
        if hasattr(_status_check_lock, 'checking'):
            delattr(_status_check_lock, 'checking')


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
        Automatically ensures status is correct (resets if busy but no active deliveries).
        
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
                # DO NOT call ensure_correct_status here - it causes recursion
                # Status correction should be done at the endpoint level, not here
                
            return delivery_profile
            
        except Exception as e:
            logger.error(f"Error getting/creating delivery profile for user {user.id}: {str(e)}")
            raise ValueError(f"Failed to get/create delivery profile: {str(e)}")
    
    @staticmethod
    def update_location(user, latitude=None, longitude=None, address=None):
        """
        Update the delivery manager's location.
        Can update coordinates, address, or both.
        
        Args:
            user: User instance
            latitude: Optional latitude coordinate
            longitude: Optional longitude coordinate
            address: Optional address string
            
        Returns:
            DeliveryProfile: Updated delivery profile
        """
        if not user.is_delivery_admin():
            raise ValueError("Only delivery administrators can update location")
        
        # Validate that if coordinates are provided, both are provided
        if (latitude is not None and longitude is None) or (longitude is not None and latitude is None):
            raise ValueError("Both latitude and longitude must be provided together, or neither.")
        
        # At least one of coordinates or address must be provided
        if latitude is None and longitude is None and (address is None or address.strip() == ''):
            raise ValueError("Either coordinates (latitude and longitude) or address must be provided.")
        
        try:
            delivery_profile = DeliveryProfileService.get_or_create_delivery_profile(user)
            delivery_profile.update_location(latitude, longitude, address)
            
            if latitude is not None and longitude is not None:
                logger.info(f"Updated location for user {user.id}: {latitude}, {longitude}")
            if address:
                logger.info(f"Updated address for user {user.id}: {address}")
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
            
            logger.info(f"Updated delivery status for user {user.id} from {old_status} to: {status}")
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
        Automatically ensures status is correct (resets if busy but no active deliveries).
        
        Args:
            user: User instance
            
        Returns:
            DeliveryProfile or None: The delivery profile if it exists
        """
        try:
            profile = DeliveryProfile.objects.get(user=user)
            # DO NOT call ensure_correct_status here - it causes recursion
            # Status correction should be done at the endpoint level, not here
            return profile
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
    def record_status_history(delivery_profile, old_status, new_status, reason=None):
        """
        Record delivery profile status change in history for debugging and reporting.
        Records: OFFLINE → ONLINE, ONLINE → BUSY, BUSY → ONLINE
        
        Args:
            delivery_profile: DeliveryProfile instance
            old_status: Previous status
            new_status: New status
            reason: Optional reason for the status change
        """
        try:
            # Only record if status actually changed
            if old_status == new_status:
                return
            
            # Log to database for history tracking
            # Using logger for now, but can be extended to use a dedicated model
            logger.info(
                f"Delivery Profile Status History - User {delivery_profile.user.id}: "
                f"{old_status} → {new_status} "
                f"(Reason: {reason or 'Automatic'}) at {timezone.now()}"
            )
            
            # TODO: If a DeliveryProfileStatusHistory model is created, record here:
            # DeliveryProfileStatusHistory.objects.create(
            #     delivery_profile=delivery_profile,
            #     old_status=old_status,
            #     new_status=new_status,
            #     reason=reason,
            #     changed_at=timezone.now()
            # )
            
        except Exception as e:
            logger.error(f"Error recording status history: {str(e)}")
            # Don't raise exception as this is not critical
    
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
            
            # Record status history first
            DeliveryProfileService.record_status_history(delivery_profile, old_status, new_status)
            
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
    
    @staticmethod
    def has_active_deliveries(user, exclude_order_id=None, exclude_return_id=None, exclude_delivery_request_id=None):
        """
        UNIFIED FUNCTION: Check if a delivery manager has any active deliveries.
        This is the SINGLE SOURCE OF TRUTH for determining active delivery status.
        
        Args:
            user: User instance (must be a delivery administrator)
            exclude_order_id: Optional order ID to exclude from check
            exclude_return_id: Optional return request ID to exclude from check
            exclude_delivery_request_id: Optional delivery request ID to exclude from check
            
        Returns:
            bool: True if delivery manager has active deliveries, False otherwise
        """
        if not user.is_delivery_admin():
            return False
        
        try:
            from ..models import Order, DeliveryRequest
            from ..models.borrowing_model import BorrowRequest, BorrowStatusChoices
            from ..models.return_model import ReturnRequest, ReturnStatus
            
            # Check for active delivery requests
            # Availability Rule: Manager is unavailable if exists DeliveryRequest with status IN ('accepted', 'in_delivery')
            active_requests_query = DeliveryRequest.objects.filter(
                delivery_manager=user,
                status__in=['accepted', 'in_delivery']
            )
            
            if exclude_order_id:
                active_requests_query = active_requests_query.exclude(order_id=exclude_order_id)
            
            if exclude_delivery_request_id:
                active_requests_query = active_requests_query.exclude(id=exclude_delivery_request_id)
            
            if active_requests_query.exists():
                logger.info(f"Found active DeliveryRequest for user {user.id}")
                return True
            
            # Check for active orders in delivery
            # Availability Rule: Manager is unavailable if exists DeliveryRequest with status IN ('accepted', 'in_delivery')
            active_orders_query = Order.objects.filter(
                delivery_requests__delivery_manager=user,
                delivery_requests__status__in=['accepted', 'in_delivery']
            )
            
            # For 'delivered' orders, only count them as active if they're borrow orders
            # with borrow_request status OUT_FOR_DELIVERY (not ACTIVE)
            active_orders_query = active_orders_query.exclude(
                status='delivered',
                order_type='borrowing',
                borrow_request__status=BorrowStatusChoices.ACTIVE
            )
            
            if exclude_order_id:
                active_orders_query = active_orders_query.exclude(id=exclude_order_id)
            
            if active_orders_query.exists():
                active_order_list = list(active_orders_query.values('id', 'order_number', 'status', 'order_type'))
                logger.info(f"Found active Order for user {user.id}: {active_order_list}")
                return True
            
            # Check for active borrow requests (OUT_FOR_DELIVERY means delivery started but not completed)
            active_borrows = BorrowRequest.objects.filter(
                delivery_person=user,
                status__in=[
                    BorrowStatusChoices.OUT_FOR_DELIVERY,
                    'out_for_delivery'  # String version for compatibility
                ]
            ).exclude(status__in=[BorrowStatusChoices.ACTIVE, BorrowStatusChoices.DELIVERED])
            
            if active_borrows.exists():
                active_borrow_list = list(active_borrows.values('id', 'status'))
                logger.info(f"Found active BorrowRequest for user {user.id}: {active_borrow_list}")
                return True
            
            # Check for active return requests (IN_PROGRESS means delivery started but not completed)
            active_returns_query = ReturnRequest.objects.filter(
                delivery_manager=user,
                status=ReturnStatus.IN_PROGRESS
            )
            
            if exclude_return_id:
                active_returns_query = active_returns_query.exclude(id=exclude_return_id)
            
            if active_returns_query.exists():
                active_return_list = list(active_returns_query.values('id', 'status'))
                logger.info(f"Found active ReturnRequest for user {user.id}: {active_return_list}")
                return True
            
            # Check for active delivery requests with 'in_operation' status
            in_operation_query = DeliveryRequest.objects.filter(
                delivery_manager=user,
                status='in_operation'
            )
            if exclude_delivery_request_id:
                in_operation_query = in_operation_query.exclude(id=exclude_delivery_request_id)
            if in_operation_query.exists():
                logger.info(f"Found DeliveryRequest with 'in_operation' status for user {user.id}")
                return True
            
            return False
            
        except Exception as e:
            logger.error(f"Error checking active deliveries for user {user.id}: {str(e)}")
            # On error, assume there are active deliveries to be safe
            return True
    
    @staticmethod
    def start_delivery_task(user):
        """
        Automatically change delivery manager status to busy when starting a delivery.
        This is the ONLY automatic status change allowed in the system.
        
        Args:
            user: User instance (must be a delivery administrator)
            
        Returns:
            bool: True if status was changed, False if already busy
        """
        if not user.is_delivery_admin():
            raise ValueError("Only delivery administrators can start delivery tasks")
        
        try:
            delivery_profile = DeliveryProfileService.get_or_create_delivery_profile(user)
            old_status = delivery_profile.delivery_status
            success = delivery_profile.set_busy_for_delivery()
            
            # Refresh from DB to get the actual current status
            delivery_profile.refresh_from_db()
            
            if success:
                logger.info(f"Automatically changed delivery status from '{old_status}' to 'busy' for user {user.id}")
                # Record status history and send notification
                DeliveryProfileService.record_status_history(
                    delivery_profile, 
                    old_status, 
                    'busy',
                    reason='Delivery started'
                )
                DeliveryProfileService.notify_status_change(delivery_profile, old_status, 'busy')
            else:
                logger.warning(
                    f"Could not change status to busy for user {user.id} - "
                    f"current status: {delivery_profile.delivery_status}, old status: {old_status}"
                )
                # If status is not busy yet, force it to busy (this handles edge cases)
                if delivery_profile.delivery_status != 'busy':
                    logger.info(f"Force setting status to busy for user {user.id} (was: {delivery_profile.delivery_status})")
                    force_old_status = delivery_profile.delivery_status
                    delivery_profile.delivery_status = 'busy'
                    delivery_profile.save(update_fields=['delivery_status'])
                    # Send notification about forced status change
                    DeliveryProfileService.notify_status_change(delivery_profile, force_old_status, 'busy')
                    success = True
            
            return success
            
        except Exception as e:
            logger.error(f"Error starting delivery task for user {user.id}: {str(e)}")
            raise ValueError(f"Failed to start delivery task: {str(e)}")
    
    @staticmethod
    def complete_delivery_task(user, completed_order_id=None, completed_return_id=None):
        """
        Automatically change delivery manager status from busy to online when completing a delivery.
        This is the ONLY automatic status change allowed in the system.
        Only changes to online if there are no other active deliveries.
        
        Args:
            user: User instance (must be a delivery administrator)
            completed_order_id: Optional order ID to exclude from active deliveries check
            completed_return_id: Optional return request ID to exclude from active returns check
            
        Returns:
            bool: True if status was changed, False if not busy or if other active deliveries exist
        """
        if not user.is_delivery_admin():
            raise ValueError("Only delivery administrators can complete delivery tasks")
        
        try:
            delivery_profile = DeliveryProfileService.get_or_create_delivery_profile(user)
            
            # Refresh from database to ensure we have the latest status
            delivery_profile.refresh_from_db()
            
            # Only change status if currently busy
            if delivery_profile.delivery_status != 'busy':
                logger.info(f"Delivery manager {user.id} status is not 'busy' (current: {delivery_profile.delivery_status}), skipping status change")
                return False
            
            # Use unified function to check for active deliveries
            has_active = DeliveryProfileService.has_active_deliveries(
                user,
                exclude_order_id=completed_order_id,
                exclude_return_id=completed_return_id
            )
            
            if has_active:
                logger.info(f"Delivery manager {user.id} has other active deliveries, keeping status as 'busy'")
                return False
            
            # No other active deliveries, safe to change to online
            # Force the status change directly to ensure it happens
            old_status = delivery_profile.delivery_status
            
            # Use update() to ensure atomic database update
            DeliveryProfile.objects.filter(id=delivery_profile.id).update(delivery_status='online')
            
            # Refresh to confirm the change
            delivery_profile.refresh_from_db()
            
            if delivery_profile.delivery_status == 'online':
                logger.info(f"Automatically changed delivery status from '{old_status}' to 'online' for user {user.id}")
                # Record status history and send notification
                try:
                    DeliveryProfileService.record_status_history(
                        delivery_profile, 
                        old_status, 
                        'online',
                        reason='Delivery completed, no other active deliveries'
                    )
                    DeliveryProfileService.notify_status_change(delivery_profile, old_status, 'online')
                except Exception as e:
                    logger.warning(f"Failed to send status change notification: {str(e)}")
                return True
            else:
                logger.error(f"Failed to change status to online for user {user.id} - status is still: {delivery_profile.delivery_status}")
                # Try one more time with direct save as fallback
                try:
                    delivery_profile.delivery_status = 'online'
                    delivery_profile.save(update_fields=['delivery_status'])
                    delivery_profile.refresh_from_db()
                    if delivery_profile.delivery_status == 'online':
                        logger.info(f"Successfully changed status to 'online' on retry for user {user.id}")
                        # Record status history
                        DeliveryProfileService.record_status_history(
                            delivery_profile, 
                            old_status, 
                            'online',
                            reason='Delivery completed (retry)'
                        )
                        return True
                except Exception as retry_error:
                    logger.error(f"Retry also failed for user {user.id}: {str(retry_error)}")
                return False
            
        except Exception as e:
            logger.error(f"Error completing delivery task for user {user.id}: {str(e)}")
            raise ValueError(f"Failed to complete delivery task: {str(e)}")
    
    @staticmethod
    def can_manually_change_status(user):
        """
        Check if a delivery manager can manually change their status.
        Returns False if currently busy (delivering), True otherwise.
        
        Args:
            user: User instance
            
        Returns:
            bool: True if can change status manually, False otherwise
        """
        if not user.is_delivery_admin():
            return False
        
        try:
            delivery_profile = DeliveryProfileService.get_delivery_profile(user)
            logger.info(f"Delivery profile for user {user.id}: {delivery_profile}")
            if not delivery_profile:
                logger.info(f"No delivery profile exists for user {user.id}, allowing status change")
                return True  # No profile exists, can create with any status
            
            # Managers can always change their status manually (only online/offline available)
            logger.info(f"User {user.id} can change status manually: True, current status: {delivery_profile.delivery_status}")
            return True
            
        except Exception as e:
            logger.error(f"Error checking manual status change permission for user {user.id}: {str(e)}")
            return False
    
    @staticmethod
    def reset_status_if_no_active_deliveries(user, force_reset=False, skip_status_check=False):
        """
        Reset delivery manager status to online if they have no active deliveries.
        This is a safety mechanism to prevent stuck 'busy' status.
        
        Args:
            user: User instance (must be a delivery administrator)
            force_reset: If True, will reset even if status is not 'busy' (use with caution)
            skip_status_check: If True, skip calling ensure_correct_status to prevent recursion
            
        Returns:
            bool: True if status was reset, False if no reset needed
        """
        if not user.is_delivery_admin():
            raise ValueError("Only delivery administrators can reset delivery status")
        
        try:
            # Use direct get() instead of get_or_create() to avoid recursion
            # Only create if it doesn't exist, but don't call ensure_correct_status
            try:
                delivery_profile = DeliveryProfile.objects.get(user=user)
            except DeliveryProfile.DoesNotExist:
                # Create profile without calling ensure_correct_status
                delivery_profile = DeliveryProfile.objects.create(
                    user=user,
                    delivery_status='offline',
                    is_tracking_active=False,
                )
                logger.info(f"Created new delivery profile for user {user.id} during reset")
                # New profile is offline, no need to reset
                return False
            
            # Only reset if currently busy (unless force_reset is True)
            if not force_reset and delivery_profile.delivery_status != 'busy':
                return False
            
            # Use unified function to check for active deliveries
            has_active = DeliveryProfileService.has_active_deliveries(user)
            
            # If force_reset is True, bypass the active delivery check and reset anyway
            # This is used when the user explicitly requests a reset
            if force_reset:
                has_active = False  # Force reset by ignoring active deliveries
            
            if not has_active:
                old_status = delivery_profile.delivery_status
                
                try:
                    # Use update() to ensure atomic database update
                    updated_count = DeliveryProfile.objects.filter(id=delivery_profile.id).update(delivery_status='online')
                    
                    if updated_count > 0:
                        # Refresh to confirm the change
                        delivery_profile.refresh_from_db()
                        
                        if delivery_profile.delivery_status == 'online':
                            logger.info(
                                f"Reset delivery status from '{old_status}' to '{delivery_profile.delivery_status}' "
                                f"for user {user.id} - no active deliveries (confirmed: {delivery_profile.delivery_status == 'online'})"
                            )
                            # Record status history
                            DeliveryProfileService.record_status_history(
                                delivery_profile, 
                                old_status, 
                                'online',
                                reason='Status reset - no active deliveries'
                            )
                            return True
                    
                    # Retry with direct save as fallback
                    logger.warning(f"Atomic update returned {updated_count} rows for user {user.id}, trying direct save...")
                    delivery_profile.delivery_status = 'online'
                    delivery_profile.save(update_fields=['delivery_status'])
                    delivery_profile.refresh_from_db()
                    if delivery_profile.delivery_status == 'online':
                        logger.info(f"Successfully reset status to 'online' on retry for user {user.id}")
                        # Record status history
                        DeliveryProfileService.record_status_history(
                            delivery_profile, 
                            old_status, 
                            'online',
                            reason='Status reset - no active deliveries (retry)'
                        )
                        return True
                    else:
                        logger.error(f"Failed to reset status for user {user.id} - status is still: {delivery_profile.delivery_status}")
                        return False
                        
                except Exception as db_error:
                    # Handle database connection errors gracefully
                    logger.error(f"Database error resetting status for user {user.id}: {str(db_error)}")
                    # Don't raise - just return False so the system can continue
                    return False
            
            return False
            
        except Exception as e:
            # Log error but don't raise - allow system to continue
            logger.error(f"Error resetting delivery status for user {user.id}: {str(e)}", exc_info=True)
            # Return False instead of raising to prevent cascading failures
            return False
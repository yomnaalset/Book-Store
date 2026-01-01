from django.db import transaction
from django.utils import timezone
from django.core.exceptions import ValidationError
from ..models import DeliveryRequest, Order, User
from ..models.borrowing_model import BorrowRequest, BorrowStatusChoices
from ..models.return_model import ReturnRequest, ReturnStatus
from ..models.delivery_profile_model import DeliveryProfile
from ..services.notification_services import NotificationService
import logging

logger = logging.getLogger(__name__)


class DeliveryService:
    """
    Centralized service for all delivery operations.
    Contains all business logic for delivery management.
    """
    
    @staticmethod
    @transaction.atomic
    def create_delivery_request(delivery_type, customer, delivery_address, delivery_city=None, 
                                order=None, borrow_request=None, return_request=None):
        """
        Create a new delivery request by type.
        
        Args:
            delivery_type: 'purchase', 'borrow', or 'return'
            customer: User instance (customer)
            delivery_address: Delivery address string
            delivery_city: Optional city name
            order: Order instance (required for 'purchase')
            borrow_request: BorrowRequest instance (required for 'borrow')
            return_request: ReturnRequest instance (required for 'return')
        
        Returns:
            DeliveryRequest instance
        """
        # Validate delivery type and entity consistency
        if delivery_type == 'purchase' and not order:
            raise ValidationError("Order is required for purchase deliveries.")
        if delivery_type == 'borrow' and not borrow_request:
            raise ValidationError("BorrowRequest is required for borrowing deliveries.")
        if delivery_type == 'return' and not return_request:
            raise ValidationError("ReturnRequest is required for return pickups.")
        
        # Create delivery request
        delivery_request = DeliveryRequest.objects.create(
            delivery_type=delivery_type,
            customer=customer,
            delivery_address=delivery_address,
            delivery_city=delivery_city,
            order=order if delivery_type == 'purchase' else None,
            borrow_request=borrow_request if delivery_type == 'borrow' else None,
            return_request=return_request if delivery_type == 'return' else None,
            status='pending'
        )
        
        logger.info(f"Created {delivery_type} delivery request {delivery_request.id} for customer {customer.id}")
        return delivery_request
    
    @staticmethod
    @transaction.atomic
    def assign_delivery_manager(delivery_request_id, delivery_manager):
        """
        Assign a delivery manager to a delivery request.
        
        Args:
            delivery_request_id: ID of the delivery request
            delivery_manager: User instance (delivery_admin)
        
        Returns:
            DeliveryRequest instance
        """
        delivery_request = DeliveryRequest.objects.get(id=delivery_request_id)
        
        if delivery_request.status != 'pending':
            raise ValidationError("Only pending delivery requests can be assigned.")
        
        if not delivery_manager.is_delivery_admin():
            raise ValidationError("User must be a delivery manager.")
        
        delivery_request.delivery_manager = delivery_manager
        delivery_request.status = 'assigned'
        delivery_request.assigned_at = timezone.now()
        delivery_request.save()
        
        # Send notification to delivery manager
        try:
            NotificationService.create_notification(
                user_id=delivery_manager.id,
                title="New Delivery Assignment",
                message=f"You have been assigned to handle a {delivery_request.get_delivery_type_display()} delivery for {delivery_request.customer.get_full_name()}.",
                notification_type="delivery_assignment"
            )
        except Exception as e:
            logger.error(f"Error sending assignment notification: {str(e)}")
        
        # Send notification to customer
        try:
            NotificationService.create_notification(
                user_id=delivery_request.customer.id,
                title="Delivery Manager Assigned",
                message=f"A delivery manager has been assigned to handle your {delivery_request.get_delivery_type_display()} request.",
                notification_type="delivery_assigned"
            )
        except Exception as e:
            logger.error(f"Error sending customer notification: {str(e)}")
        
        logger.info(f"Assigned delivery manager {delivery_manager.id} to delivery request {delivery_request_id}")
        return delivery_request
    
    @staticmethod
    def get_delivery_requests(delivery_manager=None, delivery_type=None, status=None):
        """
        Fetch delivery requests with optional filters.
        
        Args:
            delivery_manager: Filter by delivery manager (User instance or ID)
            delivery_type: Filter by type ('purchase', 'borrow', 'return')
            status: Filter by status
        
        Returns:
            QuerySet of DeliveryRequest instances
        """
        queryset = DeliveryRequest.objects.all()
        
        if delivery_manager:
            if isinstance(delivery_manager, User):
                queryset = queryset.filter(delivery_manager=delivery_manager)
            else:
                queryset = queryset.filter(delivery_manager_id=delivery_manager)
        
        if delivery_type:
            queryset = queryset.filter(delivery_type=delivery_type)
        
        if status:
            queryset = queryset.filter(status=status)
        
        return queryset.order_by('-created_at')
    
    @staticmethod
    @transaction.atomic
    def accept_delivery_request(delivery_request_id, delivery_manager):
        """
        Accept a delivery request by the delivery manager.
        Prevents accepting multiple deliveries simultaneously.
        
        Args:
            delivery_request_id: ID of the delivery request
            delivery_manager: User instance (delivery_admin)
        
        Returns:
            DeliveryRequest instance
        """
        delivery_request = DeliveryRequest.objects.get(id=delivery_request_id)
        
        if delivery_request.status != 'assigned':
            raise ValidationError("Only assigned delivery requests can be accepted.")
        
        if delivery_request.delivery_manager != delivery_manager:
            raise ValidationError("Only the assigned delivery manager can accept this request.")
        
        # Check if delivery manager already has an active delivery
        # Exclude the current delivery request being accepted from the check
        from ..services.delivery_profile_services import DeliveryProfileService
        
        # Log the check for debugging
        logger.info(
            f"Checking for active deliveries for delivery manager {delivery_manager.id} "
            f"(excluding delivery request {delivery_request_id})"
        )
        
        has_active = DeliveryProfileService.has_active_deliveries(
            delivery_manager,
            exclude_delivery_request_id=delivery_request_id
        )
        
        if has_active:
            # Get details about the active delivery for better error message
            from ..models import Order
            from ..models.borrowing_model import BorrowRequest, BorrowStatusChoices
            from ..models.return_model import ReturnRequest, ReturnStatus
            
            # Check for active delivery requests
            active_deliveries = DeliveryRequest.objects.filter(
                delivery_manager=delivery_manager,
                status__in=['accepted', 'in_delivery', 'picked_up', 'in_transit', 'in_progress']
            ).exclude(
                id=delivery_request_id
            ).exclude(
                status__in=['completed', 'delivered', 'cancelled', 'rejected']
            )
            
            if active_deliveries.exists():
                active_delivery_list = list(active_deliveries.values('id', 'status', 'delivery_type'))
                logger.warning(
                    f"Delivery manager {delivery_manager.id} has active DeliveryRequest: {active_delivery_list}"
                )
                active_delivery = active_deliveries.first()
                raise ValidationError(
                    f"You cannot accept a new delivery while you have an active delivery in progress. "
                    f"Please complete delivery request #{active_delivery.id} (status: {active_delivery.status}) first."
                )
            
            # Check for active orders (only those with active delivery requests)
            active_orders = Order.objects.filter(
                delivery_requests__delivery_manager=delivery_manager,
                delivery_requests__status__in=['accepted', 'in_delivery', 'picked_up', 'in_transit', 'in_progress'],
                status__in=['in_delivery', 'in_progress', 'delivery_in_progress']
            ).exclude(
                status__in=['completed', 'delivered', 'rejected_by_admin', 'rejected_by_delivery_manager', 'cancelled']
            ).exclude(
                delivery_requests__status__in=['completed', 'delivered', 'cancelled', 'rejected']
            )
            
            if active_orders.exists():
                active_order = active_orders.first()
                logger.warning(
                    f"Delivery manager {delivery_manager.id} has active Order: {active_order.id} (status: {active_order.status})"
                )
                raise ValidationError(
                    f"You cannot accept a new delivery while you have an active order in progress. "
                    f"Please complete order #{active_order.order_number or active_order.id} (status: {active_order.status}) first."
                )
            
            # Check for active borrow requests
            active_borrows = BorrowRequest.objects.filter(
                delivery_person=delivery_manager,
                status__in=[BorrowStatusChoices.OUT_FOR_DELIVERY, 'out_for_delivery']
            ).exclude(status__in=[BorrowStatusChoices.ACTIVE, BorrowStatusChoices.DELIVERED])
            
            if active_borrows.exists():
                active_borrow = active_borrows.first()
                logger.warning(
                    f"Delivery manager {delivery_manager.id} has active BorrowRequest: {active_borrow.id} (status: {active_borrow.status})"
                )
                raise ValidationError(
                    f"You cannot accept a new delivery while you have an active borrow delivery in progress. "
                    f"Please complete borrow request #{active_borrow.id} (status: {active_borrow.status}) first."
                )
            
            # Check for active return requests
            active_returns = ReturnRequest.objects.filter(
                delivery_manager=delivery_manager,
                status=ReturnStatus.IN_PROGRESS
            )
            
            if active_returns.exists():
                active_return = active_returns.first()
                logger.warning(
                    f"Delivery manager {delivery_manager.id} has active ReturnRequest: {active_return.id} (status: {active_return.status})"
                )
                raise ValidationError(
                    f"You cannot accept a new delivery while you have an active return pickup in progress. "
                    f"Please complete return request #{active_return.id} (status: {active_return.status}) first."
                )
            
            # If we get here, something is wrong with the has_active_deliveries check
            logger.error(
                f"has_active_deliveries returned True for delivery manager {delivery_manager.id} "
                f"but no active deliveries found in any category. This is a bug."
            )
            raise ValidationError(
                "You cannot accept a new delivery while you have an active delivery in progress. "
                "Please complete your current delivery first."
            )
        
        logger.info(
            f"Delivery manager {delivery_manager.id} has no active deliveries, proceeding with acceptance"
        )
        
        delivery_request.status = 'accepted'
        delivery_request.accepted_at = timezone.now()
        delivery_request.save()
        
        # CRITICAL: Update delivery manager availability to busy when accepting
        # This indicates they are now committed to this delivery task
        # This MUST happen in the service layer to ensure consistency
        try:
            DeliveryService.update_delivery_manager_availability(delivery_manager, 'busy')
            logger.info(f"Successfully updated delivery manager {delivery_manager.id} availability to 'busy' after accepting delivery {delivery_request_id}")
        except Exception as e:
            logger.error(f"CRITICAL: Failed to update delivery manager {delivery_manager.id} availability to 'busy': {str(e)}")
            # Re-raise to ensure transaction rollback if availability update fails
            raise ValidationError(f"Failed to update availability status: {str(e)}")
        
        # Send notification to customer
        try:
            NotificationService.create_notification(
                user_id=delivery_request.customer.id,
                title="Delivery Accepted",
                message=f"Your {delivery_request.get_delivery_type_display()} request has been accepted by {delivery_manager.get_full_name()}. Delivery will start soon.",
                notification_type="delivery_accepted"
            )
        except Exception as e:
            logger.error(f"Error sending acceptance notification: {str(e)}")
        
        # Send notification to admins
        try:
            from ..models import User
            admins = User.objects.filter(user_type__in=['library_admin']).exclude(id=delivery_manager.id)
            for admin in admins:
                NotificationService.create_notification(
                    user_id=admin.id,
                    title="Delivery Accepted",
                    message=f"Delivery manager {delivery_manager.get_full_name()} accepted delivery request #{delivery_request_id}.",
                    notification_type="delivery_accepted"
                )
        except Exception as e:
            logger.error(f"Error sending admin notification: {str(e)}")
        
        logger.info(f"Delivery manager {delivery_manager.id} accepted delivery request {delivery_request_id}")
        return delivery_request
    
    @staticmethod
    @transaction.atomic
    def reject_delivery_request(delivery_request_id, delivery_manager, rejection_reason):
        """
        Reject a delivery request and return it to admin.
        
        Args:
            delivery_request_id: ID of the delivery request
            delivery_manager: User instance (delivery_admin)
            rejection_reason: Reason for rejection
        
        Returns:
            DeliveryRequest instance
        """
        delivery_request = DeliveryRequest.objects.get(id=delivery_request_id)
        
        if delivery_request.status != 'assigned':
            raise ValidationError("Only assigned delivery requests can be rejected.")
        
        if delivery_request.delivery_manager != delivery_manager:
            raise ValidationError("Only the assigned delivery manager can reject this request.")
        
        if not rejection_reason or not rejection_reason.strip():
            raise ValidationError("Rejection reason is required.")
        
        # Reset to pending and clear assignment so admin can assign another manager
        delivery_request.status = 'rejected'
        delivery_request.rejection_reason = rejection_reason.strip()
        delivery_request.rejected_at = timezone.now()
        delivery_request.delivery_manager = None  # Clear assignment
        delivery_request.assigned_at = None
        delivery_request.save()
        
        # Send notification to customer
        try:
            NotificationService.create_notification(
                user_id=delivery_request.customer.id,
                title="Delivery Request Rejected",
                message=f"Your {delivery_request.get_delivery_type_display()} request was rejected. Reason: {rejection_reason.strip()}. A new delivery manager will be assigned.",
                notification_type="delivery_rejected"
            )
        except Exception as e:
            logger.error(f"Error sending rejection notification: {str(e)}")
        
        # Send notification to admins
        try:
            from ..models import User
            admins = User.objects.filter(user_type__in=['library_admin'])
            for admin in admins:
                NotificationService.create_notification(
                    user_id=admin.id,
                    title="Delivery Request Rejected",
                    message=f"Delivery manager {delivery_manager.get_full_name()} rejected delivery request #{delivery_request_id}. Reason: {rejection_reason.strip()}. Please assign a new manager.",
                    notification_type="delivery_rejected"
                )
        except Exception as e:
            logger.error(f"Error sending admin notification: {str(e)}")
        
        logger.info(f"Delivery manager {delivery_manager.id} rejected delivery request {delivery_request_id}")
        return delivery_request
    
    @staticmethod
    @transaction.atomic
    def start_delivery(delivery_request_id, delivery_manager, notes=None):
        """
        Start delivery process.
        Updates status to in_delivery and sets delivery manager availability to busy.
        Prevents starting multiple deliveries simultaneously.
        
        Args:
            delivery_request_id: ID of the delivery request
            delivery_manager: User instance (delivery_admin)
            notes: Optional notes about the delivery start
        
        Returns:
            DeliveryRequest instance
        """
        delivery_request = DeliveryRequest.objects.get(id=delivery_request_id)
        
        if delivery_request.status != 'accepted':
            raise ValidationError("Only accepted delivery requests can be started.")
        
        if delivery_request.delivery_manager != delivery_manager:
            raise ValidationError("Only the assigned delivery manager can start this delivery.")
        
        # Check if delivery manager already has an active delivery (excluding this one)
        from ..services.delivery_profile_services import DeliveryProfileService
        exclude_order_id = delivery_request.order.id if delivery_request.order else None
        has_active = DeliveryProfileService.has_active_deliveries(
            delivery_manager, 
            exclude_order_id=exclude_order_id
        )
        if has_active:
            raise ValidationError(
                "You cannot start a new delivery while you have another active delivery in progress. "
                "Please complete your current delivery first."
            )
        
        delivery_request.status = 'in_delivery'
        delivery_request.started_at = timezone.now()
        if notes:
            delivery_request.start_notes = notes
        delivery_request.save()
        
        # Update delivery manager availability to busy
        DeliveryService.update_delivery_manager_availability(delivery_manager, 'busy')
        
        # Send notification to customer
        try:
            NotificationService.create_notification(
                user_id=delivery_request.customer.id,
                title="Delivery Started",
                message=f"Your {delivery_request.get_delivery_type_display()} is now on the way. Delivery manager {delivery_manager.get_full_name()} has started the delivery.",
                notification_type="delivery_started"
            )
        except Exception as e:
            logger.error(f"Error sending start notification: {str(e)}")
        
        logger.info(f"Delivery manager {delivery_manager.id} started delivery {delivery_request_id}")
        return delivery_request
    
    @staticmethod
    @transaction.atomic
    def update_location(delivery_request_id, delivery_manager, latitude, longitude):
        """
        Update delivery manager location (GPS).
        
        Args:
            delivery_request_id: ID of the delivery request
            delivery_manager: User instance (delivery_admin)
            latitude: Latitude coordinate
            longitude: Longitude coordinate
        
        Returns:
            DeliveryRequest instance
        """
        delivery_request = DeliveryRequest.objects.get(id=delivery_request_id)
        
        if delivery_request.status != 'in_delivery':
            raise ValidationError("Location can only be updated when delivery is in progress.")
        
        if delivery_request.delivery_manager != delivery_manager:
            raise ValidationError("Only the assigned delivery manager can update location.")
        
        delivery_request.latitude = latitude
        delivery_request.longitude = longitude
        delivery_request.save()
        
        # Also update delivery manager profile location
        DeliveryService.update_delivery_manager_location(delivery_manager, latitude, longitude)
        
        logger.info(f"Updated location for delivery {delivery_request_id}: ({latitude}, {longitude})")
        return delivery_request
    
    @staticmethod
    @transaction.atomic
    def complete_delivery(delivery_request_id, delivery_manager, notes=None):
        """
        Complete delivery and update associated entity.
        Updates status to completed and sets delivery manager availability to online.
        
        Args:
            delivery_request_id: ID of the delivery request
            delivery_manager: User instance (delivery_admin)
            notes: Optional completion notes
        
        Returns:
            DeliveryRequest instance
        """
        delivery_request = DeliveryRequest.objects.get(id=delivery_request_id)
        
        if delivery_request.status != 'in_delivery':
            raise ValidationError("Only in-progress deliveries can be completed.")
        
        if delivery_request.delivery_manager != delivery_manager:
            raise ValidationError("Only the assigned delivery manager can complete this delivery.")
        
        delivery_request.status = 'completed'
        delivery_request.completed_at = timezone.now()
        delivery_request.save()
        
        # Update associated entity based on delivery type
        if delivery_request.delivery_type == 'purchase' and delivery_request.order:
            delivery_request.order.status = 'delivered'
            delivery_request.order.save()
        elif delivery_request.delivery_type == 'borrow' and delivery_request.borrow_request:
            # For borrow requests, set status to DELIVERED (which transitions to ACTIVE after pickup)
            delivery_request.borrow_request.status = BorrowStatusChoices.DELIVERED
            delivery_request.borrow_request.save()
        elif delivery_request.delivery_type == 'return' and delivery_request.return_request:
            delivery_request.return_request.status = ReturnStatus.COMPLETED
            delivery_request.return_request.save()
        
        # Update delivery manager availability to online only if no other active deliveries
        # Check if there are other active deliveries before setting to online
        from ..services.delivery_profile_services import DeliveryProfileService
        exclude_order_id = delivery_request.order.id if delivery_request.order else None
        has_other_active = DeliveryProfileService.has_active_deliveries(
            delivery_manager,
            exclude_order_id=exclude_order_id
        )
        
        if not has_other_active:
            # No other active deliveries, safe to set to online
            DeliveryService.update_delivery_manager_availability(delivery_manager, 'online')
        else:
            # Still has other active deliveries, keep status as busy
            logger.info(f"Delivery manager {delivery_manager.id} completed delivery {delivery_request_id} but has other active deliveries, keeping status as 'busy'")
        
        # Send notification to customer
        try:
            NotificationService.create_notification(
                user_id=delivery_request.customer.id,
                title="Delivery Completed",
                message=f"Your {delivery_request.get_delivery_type_display()} has been completed successfully by {delivery_manager.get_full_name()}.",
                notification_type="delivery_completed"
            )
        except Exception as e:
            logger.error(f"Error sending completion notification: {str(e)}")
        
        # Send notification to admins
        try:
            from ..models import User
            admins = User.objects.filter(user_type__in=['library_admin'])
            for admin in admins:
                NotificationService.create_notification(
                    user_id=admin.id,
                    title="Delivery Completed",
                    message=f"Delivery request #{delivery_request_id} has been completed by {delivery_manager.get_full_name()}.",
                    notification_type="delivery_completed"
                )
        except Exception as e:
            logger.error(f"Error sending admin notification: {str(e)}")
        
        logger.info(f"Delivery manager {delivery_manager.id} completed delivery {delivery_request_id}")
        return delivery_request
    
    @staticmethod
    def update_delivery_manager_availability(delivery_manager, availability_status):
        """
        Update delivery manager availability status.
        This is the CRITICAL method that ensures availability is updated in the service layer.
        
        Args:
            delivery_manager: User instance (delivery_admin)
            availability_status: 'online', 'offline', or 'busy'
        """
        if not delivery_manager.is_delivery_admin():
            raise ValidationError("User must be a delivery manager.")
        
        try:
            delivery_profile, created = DeliveryProfile.objects.get_or_create(
                user=delivery_manager,
                defaults={'delivery_status': availability_status}
            )
            
            if not created:
                delivery_profile.delivery_status = availability_status
                delivery_profile.save()
            
            # Force refresh from database to ensure the change is persisted
            delivery_profile.refresh_from_db()
            
            # Verify the update was successful
            if delivery_profile.delivery_status != availability_status:
                logger.error(f"CRITICAL: Failed to update availability for manager {delivery_manager.id}. Expected: {availability_status}, Got: {delivery_profile.delivery_status}")
                raise ValidationError(f"Failed to update availability status to {availability_status}")
            
            logger.info(f"Successfully updated delivery manager {delivery_manager.id} availability to {availability_status} (verified)")
        except Exception as e:
            logger.error(f"Error updating delivery manager {delivery_manager.id} availability to {availability_status}: {str(e)}")
            raise
    
    @staticmethod
    def update_delivery_manager_location(delivery_manager, latitude, longitude):
        """
        Update delivery manager location in profile.
        
        Args:
            delivery_manager: User instance (delivery_admin)
            latitude: Latitude coordinate
            longitude: Longitude coordinate
        """
        if not delivery_manager.is_delivery_admin():
            raise ValidationError("User must be a delivery manager.")
        
        delivery_profile, created = DeliveryProfile.objects.get_or_create(
            user=delivery_manager,
            defaults={
                'latitude': latitude,
                'longitude': longitude,
                'location_updated_at': timezone.now()
            }
        )
        
        if not created:
            delivery_profile.latitude = latitude
            delivery_profile.longitude = longitude
            delivery_profile.location_updated_at = timezone.now()
            delivery_profile.save()
        
        logger.info(f"Updated delivery manager {delivery_manager.id} location: ({latitude}, {longitude})")
    
    @staticmethod
    @transaction.atomic
    def update_delivery_notes(delivery_request_id, notes, user):
        """
        Update delivery notes.
        Can only be updated before delivery is completed.
        
        Args:
            delivery_request_id: ID of the delivery request
            notes: Notes to add/update
            user: User making the request (for permission checking)
        
        Returns:
            DeliveryRequest instance
        """
        delivery_request = DeliveryRequest.objects.get(id=delivery_request_id)
        
        # Check if delivery is completed
        if delivery_request.status == 'completed':
            raise ValidationError("Cannot modify notes after delivery is completed.")
        
        # Validate permissions (this should be checked in the view, but double-check here)
        is_admin = user.user_type in ['library_admin', 'delivery_admin']
        is_customer = user.user_type == 'customer' and delivery_request.customer == user
        is_delivery_manager = user.user_type == 'delivery_admin' and delivery_request.delivery_manager == user
        
        if not (is_admin or is_customer or is_delivery_manager):
            raise ValidationError("You do not have permission to update notes for this delivery.")
        
        delivery_request.start_notes = notes
        delivery_request.save()
        
        logger.info(f"Updated notes for delivery {delivery_request_id} by user {user.id}")
        return delivery_request
    
    @staticmethod
    @transaction.atomic
    def delete_delivery_notes(delivery_request_id, user):
        """
        Delete delivery notes.
        Can only be deleted before delivery is completed.
        
        Args:
            delivery_request_id: ID of the delivery request
            user: User making the request (for permission checking)
        
        Returns:
            DeliveryRequest instance
        """
        delivery_request = DeliveryRequest.objects.get(id=delivery_request_id)
        
        # Check if delivery is completed
        if delivery_request.status == 'completed':
            raise ValidationError("Cannot delete notes after delivery is completed.")
        
        # Validate permissions (this should be checked in the view, but double-check here)
        is_admin = user.user_type in ['library_admin', 'delivery_admin']
        is_customer = user.user_type == 'customer' and delivery_request.customer == user
        is_delivery_manager = user.user_type == 'delivery_admin' and delivery_request.delivery_manager == user
        
        if not (is_admin or is_customer or is_delivery_manager):
            raise ValidationError("You do not have permission to delete notes for this delivery.")
        
        delivery_request.start_notes = None
        delivery_request.save()
        
        logger.info(f"Deleted notes for delivery {delivery_request_id} by user {user.id}")
        return delivery_request


from django.db.models import Q, Count, Avg, Sum
from django.db import transaction
from django.utils import timezone
from datetime import timedelta
from decimal import Decimal
from typing import List, Dict, Any, Optional, TYPE_CHECKING
import logging

if TYPE_CHECKING:
    pass

from ..models import (
    BorrowRequest, BorrowExtension, BorrowStatistics,
    Book, User, Payment, BorrowStatusChoices, ExtensionStatusChoices, FineStatusChoices,
    Notification, ReturnFine
)
from ..services.notification_services import NotificationService

logger = logging.getLogger(__name__)


class BorrowingService:
    """
    Service class for managing book borrowing operations
    """
    
    @staticmethod
    def create_borrow_request(customer: User, book: Book, borrow_period_days: int, delivery_address: str, additional_notes: str = "") -> BorrowRequest:
        """
        Create a new borrow request
        Stage 1: Customer initiates borrow request
        Step 1.1: Check if Available_Count > 0
        """
        # Check if customer has unpaid fines (Stage 1 validation)
        can_submit, message = customer.can_submit_borrow_request()
        if not can_submit:
            raise ValueError(message)
        
        # Step 1.1: Check if Available_Count > 0
        if book.available_copies <= 0:
            raise ValueError("Book is not available for borrowing. No copies available.")
        
        borrow_request = BorrowRequest.objects.create(
            customer=customer,
            book=book,
            borrow_period_days=borrow_period_days,
            delivery_address=delivery_address,
            additional_notes=additional_notes,
            expected_return_date=timezone.now() + timedelta(days=borrow_period_days),
            status=BorrowStatusChoices.PAYMENT_PENDING
        )
        
        # Step 1.2: Send notification to admin
        library_managers = User.objects.filter(user_type='library_admin', is_active=True)
        for library_manager in library_managers:
            NotificationService.create_notification(
                user_id=library_manager.id,
                title="New Borrowing Request",
                message=f"New borrowing request from {customer.get_full_name()} for '{book.name}'",
                notification_type="borrow_request"
            )
        
        return borrow_request
    
    @staticmethod
    @transaction.atomic
    def confirm_payment(borrow_request: BorrowRequest, payment_method: str, card_data: Dict[str, Any] = None) -> Dict[str, Any]:
        """
        Confirm payment for a borrowing request
        Step 3.1 & 3.2: Process payment and update request status
        """
        # Validate that request is in payment pending status
        if borrow_request.status != BorrowStatusChoices.PAYMENT_PENDING:
            raise ValueError(f"Borrow request must be in Payment Pending status. Current status: {borrow_request.get_status_display()}")
        
        try:
            if payment_method == 'cash':
                # Step 3.2a: Cash on Delivery
                borrow_request.payment_method = 'cash'
                borrow_request.status = BorrowStatusChoices.PENDING
                borrow_request.save()
                
                # Send notification to Admin
                library_admins = User.objects.filter(user_type='library_admin', is_active=True)
                for admin in library_admins:
                    NotificationService.create_notification(
                        user_id=admin.id,
                        title="New Borrowing Request - Payment Confirmed",
                        message=f"Customer {borrow_request.customer.get_full_name()} has confirmed payment (Cash on Delivery) for borrowing request of '{borrow_request.book.name}'.",
                        notification_type="borrow_payment_confirmed"
                    )
                
                return {
                    'success': True,
                    'message': 'Payment confirmed successfully. Request submitted.',
                    'payment_method': 'cash',
                    'status': borrow_request.get_status_display()
                }
            
            elif payment_method == 'mastercard':
                # Step 3.2b: Mastercard payment
                if not card_data:
                    raise ValueError("Card data is required for Mastercard payment")
                
                # Process payment through payment gateway
                # In a real implementation, this would call an external payment gateway API
                # For now, we'll simulate the payment processing
                payment_result = BorrowingService._process_mastercard_payment(
                    borrow_request=borrow_request,
                    card_data=card_data
                )
                
                if payment_result['success']:
                    # Update borrow request
                    borrow_request.payment_method = 'mastercard'
                    borrow_request.status = BorrowStatusChoices.PENDING
                    borrow_request.save()
                    
                    # Send notification to Admin
                    library_admins = User.objects.filter(user_type='library_admin', is_active=True)
                    for admin in library_admins:
                        NotificationService.create_notification(
                            user_id=admin.id,
                            title="New Borrowing Request - Payment Confirmed",
                            message=f"Customer {borrow_request.customer.get_full_name()} has confirmed payment (Mastercard) for borrowing request of '{borrow_request.book.name}'. Transaction ID: {payment_result.get('transaction_id', 'N/A')}",
                            notification_type="borrow_payment_confirmed"
                        )
                    
                    return {
                        'success': True,
                        'message': 'Payment confirmed successfully. Request submitted.',
                        'payment_method': 'mastercard',
                        'status': borrow_request.get_status_display(),
                        'transaction_id': payment_result.get('transaction_id')
                    }
                else:
                    return {
                        'success': False,
                        'message': payment_result.get('message', 'Payment processing failed'),
                        'error_code': payment_result.get('error_code')
                    }
            else:
                raise ValueError(f"Invalid payment method: {payment_method}")
                
        except Exception as e:
            logger.error(f"Error confirming payment for borrow request {borrow_request.id}: {str(e)}", exc_info=True)
            raise
    
    @staticmethod
    def _process_mastercard_payment(borrow_request: BorrowRequest, card_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Process Mastercard payment through payment gateway
        This is a placeholder for actual payment gateway integration
        """
        try:
            # In a real implementation, you would:
            # 1. Call the payment gateway API (e.g., Stripe, PayPal, etc.)
            # 2. Handle the response
            # 3. Store transaction details
            
            # For demo purposes, we'll simulate a successful payment
            # In production, replace this with actual payment gateway call
            
            import uuid
            transaction_id = f"TXN-{uuid.uuid4().hex[:12].upper()}"
            
            # Simulate payment gateway validation
            card_number = card_data.get('card_number', '').replace(' ', '').replace('-', '')
            
            # Basic validation (in production, this would be done by the payment gateway)
            if not card_number.isdigit() or len(card_number) < 13:
                return {
                    'success': False,
                    'message': 'Invalid card number',
                    'error_code': 'INVALID_CARD'
                }
            
            # Check if card is expired
            expiry_month = card_data.get('expiry_month')
            expiry_year = card_data.get('expiry_year')
            if expiry_year and expiry_month:
                from datetime import datetime
                current_date = timezone.now().date()
                if expiry_year < current_date.year or (expiry_year == current_date.year and expiry_month < current_date.month):
                    return {
                        'success': False,
                        'message': 'Card has expired',
                        'error_code': 'EXPIRED_CARD'
                    }
            
            # Simulate successful payment
            # TODO: Replace with actual payment gateway API call
            # Example:
            # payment_gateway_response = payment_gateway.charge(
            #     amount=borrow_request.book.borrow_price,
            #     card_number=card_number,
            #     expiry_month=expiry_month,
            #     expiry_year=expiry_year,
            #     cvv=card_data.get('cvv'),
            #     cardholder_name=card_data.get('cardholder_name')
            # )
            
            logger.info(f"Simulated successful payment for borrow request {borrow_request.id}, transaction ID: {transaction_id}")
            
            return {
                'success': True,
                'transaction_id': transaction_id,
                'message': 'Payment processed successfully'
            }
            
        except Exception as e:
            logger.error(f"Error processing Mastercard payment: {str(e)}", exc_info=True)
            return {
                'success': False,
                'message': f'Payment processing error: {str(e)}',
                'error_code': 'PAYMENT_PROCESSING_ERROR'
            }
    
    @staticmethod
    @transaction.atomic
    def approve_borrow_request(borrow_request: BorrowRequest, approved_by: User, delivery_manager: User = None) -> BorrowRequest:
        """
        Approve a borrow request and assign to delivery manager
        """
        try:
            # Reserve a copy of the book
            if not borrow_request.book.borrow_copy():
                raise ValueError("No copies available for borrowing")
            
            # Set status based on whether delivery manager is assigned
            if delivery_manager:
                borrow_request.status = BorrowStatusChoices.ASSIGNED_TO_DELIVERY
                borrow_request.delivery_person = delivery_manager
                logger.info(f"Assigning delivery manager {delivery_manager.id} to borrow request {borrow_request.id}, status set to ASSIGNED_TO_DELIVERY")
                
                # Do not change delivery_manager.delivery_status here
                # Keep the manager "Online" until they accept the task
            else:
                borrow_request.status = BorrowStatusChoices.APPROVED
                logger.info(f"Borrow request {borrow_request.id} approved without delivery manager assignment, status set to APPROVED")
            
            borrow_request.approved_by = approved_by
            borrow_request.approved_date = timezone.now()
            
            borrow_request.save()
            logger.info(f"Saved borrow request {borrow_request.id} with status {borrow_request.status}")
            
            # Create delivery order as specified in requirements
            from ..services.delivery_services import BorrowingDeliveryService
            delivery_order = BorrowingDeliveryService.create_delivery_for_borrow(borrow_request)
            logger.info(f"Created delivery order {delivery_order.id} for borrow request {borrow_request.id}")
            
        except Exception as e:
            logger.error(f"Error approving borrow request {borrow_request.id}: {str(e)}", exc_info=True)
            raise  # Re-raise to ensure transaction rollback
        
        # Send notification to customer (outside transaction - notifications can fail without breaking the flow)
        NotificationService.create_notification(
            user_id=borrow_request.customer.id,
            title="Borrowing Request Approved",
            message=f"Your request to borrow '{borrow_request.book.name}' has been approved and assigned to delivery manager {delivery_manager.get_full_name() if delivery_manager else 'TBD'}.",
            notification_type="borrow_approved"
        )
        
        # Send notification to assigned delivery manager
        if delivery_manager:
            NotificationService.create_notification(
                user_id=delivery_manager.id,
                title="New Delivery Assignment",
                message=f"You have been assigned to deliver '{borrow_request.book.name}' to {borrow_request.customer.get_full_name()} at {borrow_request.delivery_address}.",
                notification_type="delivery_assignment"
            )
        
        # Send notification to other delivery managers
        other_delivery_managers = User.objects.filter(
            user_type='delivery_admin', 
            is_active=True
        ).exclude(id=delivery_manager.id if delivery_manager else None)
        
        for manager in other_delivery_managers:
            NotificationService.create_notification(
                user_id=manager.id,
                title="New Delivery Task Available",
                message=f"New Request: Deliver the book '{borrow_request.book.name}' to {borrow_request.customer.get_full_name()} at address {borrow_request.delivery_address}.",
                notification_type="delivery_task_created"
            )
        
        return borrow_request
    
    @staticmethod
    def reject_borrow_request(borrow_request: BorrowRequest, rejection_reason: str) -> BorrowRequest:
        """
        Reject a borrow request
        """
        borrow_request.status = BorrowStatusChoices.REJECTED
        borrow_request.rejection_reason = rejection_reason
        borrow_request.save()
        
        # Send notification to customer
        NotificationService.create_notification(
            user_id=borrow_request.customer.id,
            title="Borrowing Request Rejected",
            message=f"Your borrowing request for '{borrow_request.book.name}' has been rejected. Reason: {rejection_reason}",
            notification_type="borrow_rejected"
        )
        
        return borrow_request
    
    @staticmethod
    def reject_delivery_request(borrow_request: BorrowRequest, delivery_person: User, rejection_reason: str) -> BorrowRequest:
        """
        Delivery Manager Rejects Delivery Assignment
        Unassigns the delivery manager and notifies admin
        """
        if borrow_request.status != BorrowStatusChoices.ASSIGNED_TO_DELIVERY:
            raise ValueError("Request must be assigned to delivery before rejection")
        
        if borrow_request.delivery_person != delivery_person:
            raise ValueError("Only the assigned delivery manager can reject this request")
        
        # Unassign the delivery manager
        borrow_request.delivery_person = None
        # Note: We don't change the status here - it remains ASSIGNED_TO_DELIVERY
        # so the admin can reassign it to another delivery manager
        borrow_request.save()
        
        # Send notification to library admin
        library_admins = User.objects.filter(user_type='library_admin', is_active=True)
        for admin in library_admins:
            NotificationService.create_notification(
                user_id=admin.id,
                title="Delivery Request Rejected",
                message=f"Delivery manager {delivery_person.get_full_name()} has rejected the delivery request for '{borrow_request.book.name}'. Reason: {rejection_reason}. Please reassign to another delivery manager.",
                notification_type="delivery_rejected"
            )
        
        return borrow_request
    
    @staticmethod
    def accept_delivery_request(borrow_request: BorrowRequest, delivery_person: User) -> BorrowRequest:
        """
        Step 3.1: Delivery Manager Accepts Request
        Update status to "Preparing"
        """
        if borrow_request.status != BorrowStatusChoices.ASSIGNED_TO_DELIVERY:
            raise ValueError("Request must be assigned to delivery before acceptance")
        
        if borrow_request.delivery_person != delivery_person:
            raise ValueError("Only the assigned delivery manager can accept this request")
        
        borrow_request.status = BorrowStatusChoices.PREPARING
        borrow_request.pickup_date = timezone.now()
        borrow_request.save()
        
        # Update associated Order status if it exists
        # This ensures the order remains visible in the Borrowing Requests list
        try:
            from ..models.delivery_model import Order
            order = Order.objects.filter(borrow_request=borrow_request, order_type='borrowing').first()
            if order:
                # Keep order status as 'assigned' - the BorrowRequest status 'preparing' 
                # is what makes it appear in the Borrowing Requests list
                # The order status doesn't need to change here, as we filter by BorrowRequest status
                logger.info(f"Order {order.id} associated with borrow request {borrow_request.id} - BorrowRequest status updated to 'preparing'")
        except Exception as e:
            logger.warning(f"Failed to update order status for borrow request {borrow_request.id}: {str(e)}")
        
        # Update delivery manager status to busy
        try:
            from ..services.delivery_profile_services import DeliveryProfileService
            DeliveryProfileService.start_delivery_task(delivery_person)
        except Exception as e:
            logger.warning(f"Failed to update delivery manager status to busy: {str(e)}")
        
        # Send notification to customer and admin
        NotificationService.create_notification(
            user_id=borrow_request.customer.id,
            title="Delivery Accepted",
            message=f"Delivery manager {delivery_person.get_full_name()} has accepted your request for '{borrow_request.book.name}'. Preparing for delivery.",
            notification_type="delivery_accepted"
        )
        
        library_admins = User.objects.filter(user_type='library_admin', is_active=True)
        for admin in library_admins:
            NotificationService.create_notification(
                user_id=admin.id,
                title="Delivery Accepted",
                message=f"Delivery manager {delivery_person.get_full_name()} has accepted the delivery request for '{borrow_request.book.name}'.",
                notification_type="delivery_accepted_admin"
        )
        
        return borrow_request
    
    @staticmethod
    def start_delivery(borrow_request: BorrowRequest, delivery_person: User) -> BorrowRequest:
        """
        Step 3.2: Delivery Manager Starts Delivery
        Update status to "Out for Delivery"
        Step 3.3: Location transmission begins (every 5 seconds)
        Step 3.4: Real-time tracking enabled
        """
        if borrow_request.status != BorrowStatusChoices.PREPARING:
            raise ValueError("Request must be in Preparing status before starting delivery")
        
        if borrow_request.delivery_person != delivery_person:
            raise ValueError("Only the assigned delivery manager can start delivery")
        
        borrow_request.status = BorrowStatusChoices.OUT_FOR_DELIVERY
        borrow_request.save()
        
        # Step 3.3 & 3.4: Enable real-time location tracking
        try:
            from ..services.delivery_services import LocationTrackingService
            from ..models.delivery_model import RealTimeTracking
            
            # Get or create RealTimeTracking for this delivery manager
            tracking, created = RealTimeTracking.objects.get_or_create(
                delivery_manager=delivery_person,
                defaults={
                    'is_tracking_enabled': True,
                    'is_delivering': True,
                    'tracking_interval': 5,  # 5 seconds as per Step 3.3
                }
            )
            
            if not created:
                # Update existing tracking
                tracking.is_tracking_enabled = True
                tracking.is_delivering = True
                tracking.tracking_interval = 5  # 5 seconds
                tracking.save()
            
            # Get delivery request if exists
            from ..models.delivery_model import Order, DeliveryRequest
            try:
                order = Order.objects.filter(
                    borrow_request=borrow_request,
                    order_type='borrowing'
                ).first()
                if order:
                    delivery_request = DeliveryRequest.objects.filter(order=order).first()
                    if delivery_request:
                        tracking.current_delivery_request = delivery_request
                        tracking.save()
            except Exception as e:
                logger.warning(f"Could not link delivery request to tracking: {str(e)}")
            
            logger.info(f"Enabled real-time tracking for delivery manager {delivery_person.id} with 5-second interval")
            
        except Exception as e:
            logger.warning(f"Failed to enable location tracking: {str(e)}")
        
        # Send notification to customer and admin
        NotificationService.create_notification(
            user_id=borrow_request.customer.id,
            title="Delivery Started",
            message=f"Your book '{borrow_request.book.name}' is now out for delivery. You can track the delivery in real-time.",
            notification_type="delivery_started"
        )
        
        library_admins = User.objects.filter(user_type='library_admin', is_active=True)
        for admin in library_admins:
            NotificationService.create_notification(
                user_id=admin.id,
                title="Delivery Started",
                message=f"Delivery of '{borrow_request.book.name}' to {borrow_request.customer.get_full_name()} has started. Real-time tracking is active.",
                notification_type="delivery_started_admin"
            )
        
        return borrow_request
    
    @staticmethod
    def start_delivery_legacy(borrow_request: BorrowRequest, delivery_person: User) -> BorrowRequest:
        """
        Legacy method: Mark book as picked up from library (Step 5: Pick up the book from the library)
        """
        borrow_request.status = BorrowStatusChoices.PENDING_DELIVERY
        borrow_request.pickup_date = timezone.now()
        borrow_request.delivery_person = delivery_person
        borrow_request.save()
        
        # Automatically change delivery manager status to busy when starting delivery
        try:
            from ..services.delivery_profile_services import DeliveryProfileService
            DeliveryProfileService.start_delivery_task(delivery_person)
        except Exception as e:
            logger.warning(f"Failed to update delivery manager status to busy: {str(e)}")
        
        # Send notification to customer
        NotificationService.create_notification(
            user_id=borrow_request.customer.id,
            title="Book Picked Up",
            message=f"Your book '{borrow_request.book.name}' has been picked up from the library and is on its way to you.",
            notification_type="delivery_started"
        )
        
        return borrow_request
    
    @staticmethod
    def mark_delivered(borrow_request: BorrowRequest, delivery_notes: str = "") -> BorrowRequest:
        """
        Step 3.5: Delivery Completion
        Mark book as delivered to customer and log expected return date
        Stop location tracking
        """
        if borrow_request.status != BorrowStatusChoices.OUT_FOR_DELIVERY:
            raise ValueError("Delivery must be started before completion")
        
        borrow_request.status = BorrowStatusChoices.ACTIVE
        borrow_request.delivery_date = timezone.now()
        borrow_request.delivery_notes = delivery_notes
        
        # Step 3.5: Log the expected return date
        borrow_request.final_return_date = borrow_request.expected_return_date
        borrow_request.save()
        
        # Update delivery manager status back to online
        if borrow_request.delivery_person and hasattr(borrow_request.delivery_person, 'delivery_profile'):
            try:
                from ..services.delivery_profile_services import DeliveryProfileService
                DeliveryProfileService.complete_delivery_task(borrow_request.delivery_person)
            except Exception as e:
                logger.warning(f"Failed to update delivery manager status to online: {str(e)}")
        
        # Stop location tracking when delivery is completed
        try:
            from ..models.delivery_model import RealTimeTracking
            tracking = RealTimeTracking.objects.filter(delivery_manager=borrow_request.delivery_person).first()
            if tracking:
                tracking.is_delivering = False
                tracking.current_delivery_assignment = None
                tracking.save()
                logger.info(f"Stopped location tracking for delivery manager {borrow_request.delivery_person.id}")
        except Exception as e:
            logger.warning(f"Failed to stop location tracking: {str(e)}")
        
        # Increment borrow count when book is successfully delivered
        borrow_request.book.borrow_count += 1
        borrow_request.book.save()
        
        # Update book statistics
        BorrowingService.update_book_statistics(borrow_request.book)
        
        # Send notification to customer
        NotificationService.create_notification(
            user_id=borrow_request.customer.id,
            title="Book Delivered Successfully",
            message=f"Your book '{borrow_request.book.name}' has been delivered. Loan period starts today. Return date: {borrow_request.final_return_date.strftime('%Y-%m-%d')}",
            notification_type="delivery_completed"
        )
        
        return borrow_request
    
    @staticmethod
    def request_extension(borrow_request: BorrowRequest, additional_days: int) -> BorrowExtension:
        """
        Request extension for a borrow
        """
        if not borrow_request.can_extend:
            raise ValueError("This borrowing cannot be extended")
        
        # Auto-approve extension (as per requirements)
        extension = BorrowExtension.objects.create(
            borrow_request=borrow_request,
            additional_days=additional_days,
            status=ExtensionStatusChoices.APPROVED,
            approved_date=timezone.now()
        )
        
        # Update borrow request
        borrow_request.extension_used = True
        borrow_request.extension_date = timezone.now()
        borrow_request.additional_days = additional_days
        borrow_request.status = BorrowStatusChoices.EXTENDED
        borrow_request.final_return_date = borrow_request.expected_return_date + timedelta(days=additional_days)
        borrow_request.save()
        
        # Send notifications
        NotificationService.create_notification(
            user_id=borrow_request.customer.id,
            title="Borrowing Extended",
            message=f"Your borrowing for '{borrow_request.book.name}' has been extended by {additional_days} days. New return date: {borrow_request.final_return_date.strftime('%Y-%m-%d')}",
            notification_type="borrowing_extended"
        )
        
        # Notify library and delivery managers
        managers = User.objects.filter(
            user_type__in=['library_admin', 'delivery_admin'],
            is_active=True
        )
        for manager in managers:
            NotificationService.create_notification(
                user_id=manager.id,
                title="Borrowing Extension Granted",
                message=f"Borrowing extension granted for '{borrow_request.book.name}' to {borrow_request.customer.get_full_name()}",
                notification_type="extension_granted"
            )
        
        return extension
    
    @staticmethod
    def request_early_return(borrow_request: BorrowRequest, return_reason: str = "") -> BorrowRequest:
        """
        Step 4.3: Customer Clicks "Early Return"
        Notification sent to Admin and Delivery Manager
        """
        if borrow_request.status not in [BorrowStatusChoices.ACTIVE, BorrowStatusChoices.EXTENDED]:
            raise ValueError("Can only request early return for active borrowings")
        
        borrow_request.status = BorrowStatusChoices.RETURN_REQUESTED
        borrow_request.save()
        
        # Step 4.3: Send notification to Admin
        library_admins = User.objects.filter(user_type='library_admin', is_active=True)
        for admin in library_admins:
            NotificationService.create_notification(
                user_id=admin.id,
                title="Early Return Requested",
                message=f"Customer {borrow_request.customer.get_full_name()} has requested early return of '{borrow_request.book.name}'.",
                notification_type="early_return_requested"
            )
        
        # Step 4.3: Send notification to Delivery Manager (if assigned)
        if borrow_request.delivery_person:
            NotificationService.create_notification(
                user_id=borrow_request.delivery_person.id,
                title="Early Return Requested",
                message=f"Customer {borrow_request.customer.get_full_name()} has requested early return of '{borrow_request.book.name}'. Please collect the book.",
                notification_type="early_return_requested_dm"
            )
        else:
            # Notify all delivery managers if no specific DM assigned
            delivery_managers = User.objects.filter(user_type='delivery_admin', is_active=True)
            for manager in delivery_managers:
                NotificationService.create_notification(
                    user_id=manager.id,
                    title="Early Return Requested",
                    message=f"Customer {borrow_request.customer.get_full_name()} has requested early return of '{borrow_request.book.name}'. Please collect the book.",
                    notification_type="early_return_requested_dm"
                )
        
        return borrow_request
    
    @staticmethod
    def complete_return(borrow_request: BorrowRequest, collection_notes: str = "") -> BorrowRequest:
        """
        Complete book return and release copy back to available pool (Step 7: Upon return)
        """
        borrow_request.status = BorrowStatusChoices.RETURNED
        borrow_request.actual_return_date = timezone.now()
        borrow_request.save()
        
        # Release copy back to available pool
        borrow_request.book.return_copy()
        
        # Update book statistics
        BorrowingService.update_book_statistics(borrow_request.book)
        
        # Send notification to customer
        NotificationService.create_notification(
            user_id=borrow_request.customer.id,
            title="Book Return Confirmed",
            message=f"Return of '{borrow_request.book.name}' has been confirmed. Thank you for using our library!",
            notification_type="return_confirmed"
        )
        
        # Send notification to library manager
        library_managers = User.objects.filter(user_type='library_admin', is_active=True)
        for manager in library_managers:
            NotificationService.create_notification(
                user_id=manager.id,
                title="Book Returned Successfully",
                message=f"Book '{borrow_request.book.name}' has been successfully returned by {borrow_request.customer.get_full_name()}",
                notification_type="book_returned"
            )
        
        return borrow_request
    
    @staticmethod
    def add_rating(borrow_request: BorrowRequest, rating: int, comment: str = "") -> BorrowRequest:
        """
        Add rating to borrowing experience
        """
        if not borrow_request.can_rate:
            raise ValueError("This borrowing experience cannot be rated")
        
        borrow_request.rating = rating
        borrow_request.rating_comment = comment
        borrow_request.rating_date = timezone.now()
        borrow_request.save()
        
        # Update book statistics
        BorrowingService.update_book_statistics(borrow_request.book)
        
        return borrow_request
    
    @staticmethod
    def cancel_request(borrow_request: BorrowRequest) -> BorrowRequest:
        """
        Cancel a pending borrow request
        """
        if borrow_request.status != BorrowStatusChoices.PENDING:
            raise ValueError("Only pending requests can be cancelled")
        
        borrow_request.status = BorrowStatusChoices.CANCELLED
        borrow_request.save()
        
        return borrow_request
    
    @staticmethod
    def process_borrowing_with_payment(borrow_request: BorrowRequest, payment_method: str) -> Dict[str, Any]:
        """
        Complete borrowing flow with payment creation
        """
        try:
            # Create payment
            payment = BorrowingPaymentService.create_borrowing_payment(borrow_request, payment_method)
            
            # For this demo, auto-complete the payment
            # In real implementation, this would be handled by payment gateway
            payment = BorrowingPaymentService.process_borrowing_payment(payment)
            
            # Create delivery order
            from ..services.delivery_services import BorrowingDeliveryService
            delivery_result = BorrowingDeliveryService.create_borrowing_delivery_order(borrow_request, payment)
            
            if not delivery_result['success']:
                raise ValueError(delivery_result['message'])
            
            return {
                'success': True,
                'message': 'Borrowing processed successfully',
                'payment': payment,
                'delivery_order': delivery_result['order']
            }
            
        except Exception as e:
            return {
                'success': False,
                'message': f'Failed to process borrowing: {str(e)}'
            }
    
    @staticmethod
    def initiate_early_return_collection(borrow_request: BorrowRequest) -> Dict[str, Any]:
        """
        Initiate early return collection process
        """
        try:
            # Update borrow request status
            borrow_request = BorrowingService.request_early_return(borrow_request)
            
            # Create collection order
            from ..services.delivery_services import BorrowingDeliveryService
            collection_result = BorrowingDeliveryService.create_return_collection_order(borrow_request)
            
            if not collection_result['success']:
                raise ValueError(collection_result['message'])
            
            return {
                'success': True,
                'message': 'Early return collection initiated',
                'collection_order': collection_result['order']
            }
            
        except Exception as e:
            return {
                'success': False,
                'message': f'Failed to initiate return collection: {str(e)}'
            }
    
    @staticmethod
    def reject_and_release_copy(borrow_request: BorrowRequest, rejection_reason: str) -> BorrowRequest:
        """
        Reject a borrow request and release reserved copy if it was approved
        """
        # If request was approved, release the reserved copy
        if borrow_request.status == BorrowStatusChoices.APPROVED:
            borrow_request.book.release_copy()
        
        borrow_request.status = BorrowStatusChoices.REJECTED
        borrow_request.rejection_reason = rejection_reason
        borrow_request.save()
        
        # Send notification to customer
        NotificationService.create_notification(
            user_id=borrow_request.customer.id,
            title="Borrowing Request Rejected",
            message=f"Your borrowing request for '{borrow_request.book.name}' has been rejected. Reason: {rejection_reason}",
            notification_type="borrow_rejected"
        )
        
        return borrow_request
    
    @staticmethod
    def get_most_borrowed_books(limit: int = 20) -> List[Book]:
        """
        Get most borrowed books
        """
        return Book.objects.filter(
            borrow_stats__isnull=False
        ).select_related('author', 'borrow_stats').order_by(
            '-borrow_stats__total_borrows'
        )[:limit]
    
    @staticmethod
    def get_customer_borrowings(customer: User, status: str = None) -> List[BorrowRequest]:
        """
        Get customer's borrow requests
        Excludes borrow requests with RETURN_REQUESTED status (these are handled by ReturnRequest model)
        """
        queryset = BorrowRequest.objects.filter(
            customer=customer
        ).exclude(
            status=BorrowStatusChoices.RETURN_REQUESTED
        ).select_related('book', 'book__author')
        
        if status:
            queryset = queryset.filter(status=status)
        
        return queryset.order_by('-request_date')
    
    @staticmethod
    def get_all_borrowing_requests(status: Optional[str] = None, search: Optional[str] = None) -> List[BorrowRequest]:
        """
        Get all borrowing requests with optional status filter and search
        Excludes borrow requests with RETURN_REQUESTED status (these are handled by ReturnRequest model)
        
        Args:
            status: Optional status filter (e.g., 'pending', 'approved', 'active', etc.)
            search: Optional search query for customer name, book title, or request ID
            
        Returns:
            List of borrowing requests
        """
        # Exclude RETURN_REQUESTED status - these should only appear in ReturnRequest views
        queryset = BorrowRequest.objects.exclude(
            status=BorrowStatusChoices.RETURN_REQUESTED
        ).select_related('customer', 'book').order_by('-request_date')
        
        # Add status filter if provided
        if status and status.lower() != 'all':
            # Map frontend status names to backend status values
            status_mapping = {
                'pending': BorrowStatusChoices.PENDING,
                'under review': BorrowStatusChoices.PENDING,
                'approved': BorrowStatusChoices.APPROVED,
                'rejected': BorrowStatusChoices.REJECTED,
                'active': BorrowStatusChoices.ACTIVE,
                'delivered': BorrowStatusChoices.ACTIVE,  # Delivered books are active
                'returned': BorrowStatusChoices.RETURNED,
                'overdue': BorrowStatusChoices.LATE,
            }
            
            backend_status = status_mapping.get(status.lower())
            if backend_status:
                queryset = queryset.filter(status=backend_status)
        
        # Add search filter if provided
        if search and search.strip():
            search_query = search.strip()
            queryset = queryset.filter(
                Q(customer__full_name__icontains=search_query) |
                Q(customer__email__icontains=search_query) |
                Q(book__title__icontains=search_query) |
                Q(book__isbn__icontains=search_query) |
                Q(id__icontains=search_query) |
                Q(notes__icontains=search_query)
            )
        
        return queryset
    
    @staticmethod
    def get_pending_requests(search: Optional[str] = None) -> List[BorrowRequest]:
        """
        Get pending borrow requests for library manager with optional search
        
        Args:
            search: Optional search query to filter by customer name, book name, or request ID
            
        Returns:
            List of pending borrow requests
        """
        queryset = BorrowRequest.objects.filter(
            status=BorrowStatusChoices.PENDING
        ).select_related('customer', 'book').order_by('request_date')
        
        # Add search functionality
        if search:
            queryset = queryset.filter(
                Q(customer__full_name__icontains=search) |
                Q(customer__email__icontains=search) |
                Q(book__name__icontains=search) |
                Q(book__author__name__icontains=search) |
                Q(id__icontains=search)
            )
        
        return queryset
    
    @staticmethod
    def get_ready_for_delivery() -> List[BorrowRequest]:
        """
        Get requests ready for delivery
        """
        return BorrowRequest.objects.filter(
            status=BorrowStatusChoices.APPROVED
        ).select_related('customer', 'book').order_by('approved_date')
    
    @staticmethod
    def get_overdue_borrowings() -> List[BorrowRequest]:
        """
        Get overdue borrowings
        """
        return BorrowRequest.objects.filter(
            status__in=[BorrowStatusChoices.ACTIVE, BorrowStatusChoices.EXTENDED],
            final_return_date__lt=timezone.now()
        ).select_related('customer', 'book')
    
    @staticmethod
    def update_book_statistics(book: Book):
        """
        Update borrowing statistics for a book
        """
        stats, created = BorrowStatistics.objects.get_or_create(book=book)
        
        # Update borrow counts
        stats.total_borrows = BorrowRequest.objects.filter(
            book=book,
            status__in=[BorrowStatusChoices.ACTIVE, BorrowStatusChoices.EXTENDED, BorrowStatusChoices.RETURNED]
        ).count()
        
        stats.current_borrows = BorrowRequest.objects.filter(
            book=book,
            status__in=[BorrowStatusChoices.ACTIVE, BorrowStatusChoices.EXTENDED]
        ).count()
        
        # Update ratings
        ratings = BorrowRequest.objects.filter(
            book=book,
            rating__isnull=False
        ).values_list('rating', flat=True)
        
        if ratings:
            stats.average_rating = sum(ratings) / len(ratings)
            stats.total_ratings = len(ratings)
        
        # Update last borrowed date
        last_borrow = BorrowRequest.objects.filter(
            book=book,
            delivery_date__isnull=False
        ).order_by('-delivery_date').first()
        
        if last_borrow:
            stats.last_borrowed = last_borrow.delivery_date
        
        stats.save()
    
    @staticmethod
    def get_available_delivery_managers() -> List[User]:
        """
        Get ALL delivery managers (online, busy, offline) with their status for admin selection.
        This method returns all delivery managers regardless of their status.
        Only online managers are selectable in the UI, but all managers are displayed.
        Ensures all delivery managers have delivery profiles.
        """
        from ..models import DeliveryProfile
        from ..services.delivery_profile_services import DeliveryProfileService
        
        # Get all active delivery managers - use prefetch_related to ensure we get all managers
        # even if they don't have profiles yet (though we create them below)
        delivery_managers = User.objects.filter(
            user_type='delivery_admin',
            is_active=True
        ).select_related('delivery_profile').order_by('first_name', 'last_name')
        
        # Ensure all delivery managers have profiles with valid status
        managers_list = list(delivery_managers)  # Convert to list to allow modification
        for manager in managers_list:
            try:
                # Get or create delivery profile
                delivery_profile = DeliveryProfileService.get_or_create_delivery_profile(manager)
                
                # Ensure status is not None
                if delivery_profile.delivery_status is None:
                    delivery_profile.delivery_status = 'offline'
                    delivery_profile.save(update_fields=['delivery_status'])
                    logger.info(f"Set delivery_status to 'offline' for manager {manager.id}")
                
                # Reload the manager to get the updated profile relationship
                manager = User.objects.select_related('delivery_profile').get(pk=manager.pk)
                
            except Exception as e:
                logger.warning(f"Failed to create/update delivery profile for manager {manager.id}: {str(e)}")
        
        # Re-query to ensure all relationships are properly loaded
        # Use select_related for OneToOne to ensure it's loaded
        queryset = User.objects.filter(
            user_type='delivery_admin',
            is_active=True
        ).select_related('delivery_profile').order_by('first_name', 'last_name')
        
        # Force evaluation and verify profiles exist
        managers_list = list(queryset)
        for manager in managers_list:
            # Ensure profile exists and has status
            try:
                if not hasattr(manager, 'delivery_profile') or manager.delivery_profile is None:
                    logger.warning(f"Manager {manager.id} has no delivery_profile, creating one...")
                    delivery_profile = DeliveryProfileService.get_or_create_delivery_profile(manager)
                    if delivery_profile.delivery_status is None:
                        delivery_profile.delivery_status = 'offline'
                        delivery_profile.save(update_fields=['delivery_status'])
                elif manager.delivery_profile.delivery_status is None:
                    logger.warning(f"Manager {manager.id} has null delivery_status, setting to offline...")
                    manager.delivery_profile.delivery_status = 'offline'
                    manager.delivery_profile.save(update_fields=['delivery_status'])
            except Exception as e:
                logger.error(f"Error ensuring profile for manager {manager.id}: {str(e)}")
        
        # After ensuring all profiles exist, re-query to get fresh data with all profiles loaded
        # This ensures we get all managers with their updated profiles
        # IMPORTANT: Return ALL managers regardless of status (online, busy, offline)
        # Use select_related to efficiently load profiles
        # Note: select_related with OneToOneField uses LEFT OUTER JOIN, so it includes
        # all managers even if they don't have profiles (though we create them above)
        final_queryset = User.objects.filter(
            user_type='delivery_admin',
            is_active=True
        ).select_related('delivery_profile').order_by('first_name', 'last_name')
        
        # Log the count for debugging
        manager_count = final_queryset.count()
        logger.info(f"BorrowingService.get_available_delivery_managers: Returning {manager_count} delivery managers (ALL statuses: online, busy, offline)")
        
        # Log each manager's status for debugging
        status_counts = {'online': 0, 'busy': 0, 'offline': 0, 'unknown': 0}
        for manager in final_queryset:
            try:
                status = 'unknown'
                if hasattr(manager, 'delivery_profile') and manager.delivery_profile:
                    status = manager.delivery_profile.delivery_status or 'offline'
                status_counts[status] = status_counts.get(status, 0) + 1
                logger.info(f"BorrowingService: Manager {manager.id} ({manager.get_full_name()}) - Status: {status}")
            except Exception as e:
                status_counts['unknown'] += 1
                logger.warning(f"BorrowingService: Error logging manager {manager.id}: {str(e)}")
        
        logger.info(f"BorrowingService: Status breakdown - Online: {status_counts['online']}, Busy: {status_counts['busy']}, Offline: {status_counts['offline']}, Unknown: {status_counts['unknown']}")
        
        # Return ALL delivery managers (online, busy, offline) - NO FILTERING BY STATUS
        # The frontend will display all managers but only allow selection of online ones
        return final_queryset


class BorrowingNotificationService:
    """
    Service for managing borrowing-related notifications
    """
    
    @staticmethod
    def send_return_reminders():
        """
        Send return reminders 2 days before due date (Step 6: Two days before the return date)
        """
        reminder_date = timezone.now() + timedelta(days=2)
        
        borrowings_due_soon = BorrowRequest.objects.filter(
            status__in=[BorrowStatusChoices.ACTIVE, BorrowStatusChoices.EXTENDED],
            final_return_date__date=reminder_date.date()
        )
        
        for borrowing in borrowings_due_soon:
            NotificationService.create_notification(
                user_id=borrowing.customer.id,
                title="Return Reminder",
                message=f"Reminder: The due date for return of '{borrowing.book.name}' is {borrowing.final_return_date.strftime('%m/%d/%Y')}.",
                notification_type="return_reminder"
            )
    
    @staticmethod
    def process_overdue_borrowings():
        """
        Process overdue borrowings and create fines as specified in requirements
        """
        overdue_borrowings = BorrowingService.get_overdue_borrowings()
        
        for borrowing in overdue_borrowings:
            # Update status to late
            if borrowing.status != BorrowStatusChoices.LATE:
                borrowing.status = BorrowStatusChoices.LATE
                borrowing.save()
                
                # Note: Borrowing itself never generates a fine.
                # Fines are only created when a return request is processed and the return is late/damaged/lost.
                # Just update status and send notifications about overdue status.
                
                # Send notification to customer about overdue status
                days_overdue = borrowing.get_days_overdue()
                NotificationService.create_notification(
                    user_id=borrowing.customer.id,
                    title="Book Overdue",
                    message=f"Your book '{borrowing.book.name}' is overdue by {days_overdue} days. Please return it as soon as possible.",
                    notification_type="overdue_alert"
                )
                
                # Send notification to library manager
                library_admins = User.objects.filter(user_type='library_admin')
                for admin in library_admins:
                    NotificationService.create_notification(
                        user_id=admin.id,
                        title="Overdue Book Alert",
                        message=f"Customer {borrowing.customer.get_full_name()} has been late returning book '{borrowing.book.name}' for {days_overdue} days.",
                        notification_type="overdue_alert"
                    )


class LateReturnService:
    """
    Comprehensive service for handling late book returns, fines, and deposit refunds
    """
    
    @staticmethod
    def process_late_return_scenario(borrow_request):
        """
        Process the complete late return scenario as described in the requirements
        """
        try:
            # Step 1: Check if book is overdue
            if not borrow_request.is_overdue():
                raise ValueError("Book is not overdue")
            
            # Step 2: Update status to late if not already
            if borrow_request.status != BorrowStatusChoices.LATE:
                borrow_request.status = BorrowStatusChoices.LATE
                borrow_request.save()
            
            # Step 3: Create or update fine
            fine = LateReturnService.create_or_update_fine(borrow_request)
            
            # Step 4: Send notifications to all stakeholders
            LateReturnService.send_late_return_notifications(borrow_request, fine)
            
            # Step 5: Freeze deposit refund
            LateReturnService.freeze_deposit_refund(borrow_request)
            
            return {
                'success': True,
                'message': 'Late return scenario processed successfully',
                'days_overdue': borrow_request.get_days_overdue(),
                'note': 'Fine will be created when return request is processed'
            }
            
        except Exception as e:
            return {
                'success': False,
                'message': f'Failed to process late return: {str(e)}'
            }
    
    @staticmethod
    def create_or_update_fine(borrow_request):
        """
        Note: This method is deprecated.
        Borrowing itself never generates a fine.
        Fines are only created when processing return requests (late return, damage, or loss).
        """
        # Return None - no fine is created during borrowing
        return None
    
    @staticmethod
    def send_late_return_notifications(borrow_request, fine):
        """Send notifications to all stakeholders about late return"""
        
        # Customer notification
        NotificationService.create_notification(
            user_id=borrow_request.customer.id,
            title="Book Return Overdue",
            message=f"You are late in returning '{borrow_request.book.name}'. Please return to avoid additional penalty.",
            notification_type="late_return_customer"
        )
        
        # Library manager notification
        library_admins = User.objects.filter(user_type='library_admin')
        for admin in library_admins:
            NotificationService.create_notification(
                user_id=admin.id,
                title="Customer Late Return Alert",
                message=f"Customer {borrow_request.customer.get_full_name()} has been late returning book '{borrow_request.book.name}'.",
                notification_type="late_return_admin"
            )
    
    @staticmethod
    def freeze_deposit_refund(borrow_request):
        """Freeze deposit refund until fine is paid"""
        if borrow_request.deposit_paid and not borrow_request.deposit_refunded:
            # Deposit refund is automatically frozen due to unpaid fine
            # This is handled by the is_deposit_frozen() method
            pass
    
    @staticmethod
    def process_book_return_with_fine(borrow_request, delivery_manager):
        """
        Process book return when customer returns overdue book
        """
        try:
            # Step 1: Update delivery status
            borrow_request.actual_return_date = timezone.now()
            borrow_request.status = BorrowStatusChoices.RETURNED_AFTER_DELAY
            borrow_request.save()
            
            # Step 2: Update book availability
            book = borrow_request.book
            book.copies_available += 1
            book.save()
            
            # Step 3: Send return confirmation notifications
            LateReturnService.send_return_confirmation_notifications(borrow_request, delivery_manager)
            
            return {
                'success': True,
                'message': 'Book returned successfully',
                'fine_amount': borrow_request.fine_amount,
                'deposit_frozen': borrow_request.is_deposit_frozen()
            }
            
        except Exception as e:
            return {
                'success': False,
                'message': f'Failed to process book return: {str(e)}'
            }
    
    @staticmethod
    def send_return_confirmation_notifications(borrow_request, delivery_manager):
        """Send notifications confirming book return"""
        
        # Delivery manager notification
        NotificationService.create_notification(
            user_id=delivery_manager.id,
            title="Book Return Completed",
            message=f"Book '{borrow_request.book.name}' has been successfully returned by {borrow_request.customer.get_full_name()}",
            notification_type="return_completed"
        )
        
        # Library manager notification
        library_admins = User.objects.filter(user_type='library_admin')
        for admin in library_admins:
            NotificationService.create_notification(
                user_id=admin.id,
                title="Book Returned with Fine",
                message=f"Book '{borrow_request.book.name}' has been received from customer {borrow_request.customer.get_full_name()} with ${borrow_request.fine_amount} late fee applied",
                notification_type="return_with_fine"
            )
    
    @staticmethod
    def process_fine_payment(borrow_request, payment_method='wallet'):
        """
        Process fine payment and enable deposit refund
        """
        try:
            if borrow_request.fine_status == FineStatusChoices.PAID:
                raise ValueError("Fine has already been paid")
            
            # Step 1: Process fine payment (simplified - in real implementation, integrate with payment gateway)
            fine = borrow_request.fine
            fine.mark_as_paid(borrow_request.customer)
            
            # Step 2: Calculate and process refund
            refund_amount = borrow_request.process_refund()
            
            # Step 3: Send payment confirmation notifications
            LateReturnService.send_payment_confirmation_notifications(borrow_request, refund_amount)
            
            return {
                'success': True,
                'message': 'Fine paid successfully',
                'fine_amount': fine.fine_amount if fine else 0,
                'refund_amount': refund_amount,
                'deposit_refunded': borrow_request.deposit_refunded
            }
            
        except Exception as e:
            return {
                'success': False,
                'message': f'Failed to process fine payment: {str(e)}'
            }
    
    @staticmethod
    def send_payment_confirmation_notifications(borrow_request, refund_amount):
        """Send notifications confirming fine payment and refund"""
        
        # Customer notification
        NotificationService.create_notification(
            user_id=borrow_request.customer.id,
            title="Fine Paid - Refund Processed",
            message=f"Your deposit has been refunded ${refund_amount} less a late fee (${borrow_request.fine_amount}). Thank you!",
            notification_type="refund_processed"
        )
        
        # Library manager notification
        library_admins = User.objects.filter(user_type='library_admin')
        for admin in library_admins:
            NotificationService.create_notification(
                user_id=admin.id,
                title="Fine Payment Completed",
                message=f"Customer {borrow_request.customer.get_full_name()} has paid the fine for '{borrow_request.book.name}'. Refund amount: ${refund_amount}",
                notification_type="fine_payment_completed"
            )
    
    @staticmethod
    def get_late_return_summary(borrow_request):
        """Get comprehensive summary of late return status"""
        fine = getattr(borrow_request, 'fine', None)
        
        return {
            'borrow_request_id': borrow_request.id,
            'customer_name': borrow_request.customer.get_full_name(),
            'book_name': borrow_request.book.name,
            'status': borrow_request.status,
            'days_overdue': borrow_request.get_days_overdue(),
            'deposit_amount': borrow_request.deposit_amount,
            'deposit_paid': borrow_request.deposit_paid,
            'deposit_refunded': borrow_request.deposit_refunded,
            'deposit_frozen': borrow_request.is_deposit_frozen(),
            'fine_amount': borrow_request.fine_amount,
            'fine_status': borrow_request.fine_status,
            'refund_amount': borrow_request.refund_amount,
            'fine_details': {
                'days_late': fine.days_late if fine else 0,
                'fine_amount': fine.fine_amount if fine else 0,
                'fine_reason': fine.fine_reason if fine else None,
                'late_return': fine.late_return if fine else False,
                'damaged': fine.damaged if fine else False,
                'lost': fine.lost if fine else False,
                'paid_date': fine.paid_at.isoformat() if fine and fine.paid_at else None
            } if fine else None
        }


class BorrowingReportService:
    """
    Service for generating borrowing reports
    """
    
    @staticmethod
    def get_borrowing_statistics() -> Dict[str, Any]:
        """
        Get overall borrowing statistics
        """
        total_borrows = BorrowRequest.objects.count()
        active_borrows = BorrowRequest.objects.filter(
            status__in=[BorrowStatusChoices.ACTIVE, BorrowStatusChoices.EXTENDED]
        ).count()
        overdue_borrows = BorrowRequest.objects.filter(status=BorrowStatusChoices.LATE).count()
        
        # Rating statistics
        ratings = BorrowRequest.objects.filter(rating__isnull=False).values_list('rating', flat=True)
        average_rating = sum(ratings) / len(ratings) if ratings else 0
        
        rating_distribution = {}
        for i in range(1, 6):
            rating_distribution[str(i)] = sum(1 for r in ratings if r == i)
        
        # Fine statistics - Note: Borrowing never generates fines. Only return requests can have fines.
        fines = ReturnFine.objects.aggregate(
            total=Sum('fine_amount'),
            paid=Sum('fine_amount', filter=Q(is_paid=True)),
            unpaid=Sum('fine_amount', filter=Q(is_paid=False))
        )
        
        return {
            'total_borrows': total_borrows,
            'active_borrows': active_borrows,
            'overdue_borrows': overdue_borrows,
            'average_rating': round(average_rating, 2),
            'total_ratings': len(ratings),
            'rating_distribution': rating_distribution,
            'total_fines': fines['total'] or 0,
            'paid_fines': fines['paid'] or 0,
            'unpaid_fines': fines['unpaid'] or 0
        }
    
    @staticmethod
    def get_recent_ratings(limit: int = 10) -> List[BorrowRequest]:
        """
        Get recent borrowing ratings
        """
        return BorrowRequest.objects.filter(
            rating__isnull=False
        ).select_related('customer', 'book').order_by('-rating_date')[:limit]
    
    @staticmethod
    def get_customer_borrowing_history(customer: User) -> Dict[str, Any]:
        """
        Get customer's borrowing history and statistics
        """
        borrowings = BorrowRequest.objects.filter(customer=customer)
        
        total_borrows = borrowings.count()
        active_borrows = borrowings.filter(
            status__in=[BorrowStatusChoices.ACTIVE, BorrowStatusChoices.EXTENDED]
        ).count()
        overdue_count = borrowings.filter(status=BorrowStatusChoices.LATE).count()
        
        # Calculate total fines
        # Note: Borrowing never generates fines. Only return requests can have fines.
        # Get fines from return requests for this customer
        customer_fines = ReturnFine.objects.filter(
            return_request__borrowing__customer=customer
        ).aggregate(
            total=Sum('fine_amount'),
            unpaid=Sum('fine_amount', filter=Q(is_paid=False))
        )
        
        return {
            'total_borrows': total_borrows,
            'active_borrows': active_borrows,
            'overdue_count': overdue_count,
            'total_fines': customer_fines['total'] or 0,
            'unpaid_fines': customer_fines['unpaid'] or 0,
            'borrowings': borrowings.order_by('-request_date')
        }


class BorrowingPaymentService:
    """
    Service for handling borrowing-related payments and refunds
    """
    
    @staticmethod
    def create_borrowing_payment(borrow_request: BorrowRequest, payment_method: str) -> Payment:
        """
        Create a payment for a borrowing request
        """
        payment = Payment.objects.create(
            user=borrow_request.customer,
            amount=borrow_request.book.borrow_price,
            payment_type='borrowing',
            payment_method=payment_method,
            is_borrow_payment=True,
            borrow_request=borrow_request
        )
        
        return payment
    
    @staticmethod
    def process_borrowing_payment(payment: Payment) -> Payment:
        """
        Process a borrowing payment and update borrow request status
        """
        if not payment.is_borrow_payment:
            raise ValueError("Not a borrowing payment")
        
        payment.status = 'completed'
        payment.save()
        
        # Notify delivery manager that payment is complete
        borrow_request = payment.borrow_request
        delivery_managers = User.objects.filter(user_type='delivery_admin', is_active=True)
        for manager in delivery_managers:
            NotificationService.create_notification(
                user_id=manager.id,
                title="Payment Completed - Ready for Delivery",
                message=f"Payment completed for '{borrow_request.book.name}' - ready for delivery to {borrow_request.customer.get_full_name()}",
                notification_type="payment_completed"
            )
        
        return payment
    
    @staticmethod
    def calculate_refund_amount(borrow_request: BorrowRequest) -> Decimal:
        """
        Calculate refund amount based on return timing
        """
        payment = borrow_request.payments.filter(is_borrow_payment=True, status='completed').first()
        if not payment:
            return Decimal('0.00')
        
        base_amount = payment.amount
        
        # Check if book was returned on time
        if borrow_request.status == BorrowStatusChoices.LATE:
            # Calculate late fee
            days_overdue = borrow_request.days_overdue
            late_fee = Decimal('4.00') * days_overdue  # $4 per day late fee
            
            # Refund half amount minus late fee
            refund_amount = (base_amount / 2) - late_fee
            return max(Decimal('0.00'), refund_amount)  # Don't refund negative amounts
        else:
            # On time return - refund half the amount
            return base_amount / 2
    
    @staticmethod
    def process_return_refund(borrow_request: BorrowRequest) -> Optional[Payment]:
        """
        Process refund when book is returned
        """
        payment = borrow_request.payments.filter(is_borrow_payment=True, status='completed').first()
        if not payment or not payment.can_refund():
            return None
        
        refund_amount = BorrowingPaymentService.calculate_refund_amount(borrow_request)
        
        if refund_amount > 0:
            payment.process_refund(refund_amount)
            
            # Notify customer about refund
            NotificationService.create_notification(
                user_id=borrow_request.customer.id,
                title="Refund Processed",
                message=f"Refund of ${refund_amount} has been processed for '{borrow_request.book.name}'",
                notification_type="refund_processed"
            )
        
        return payment
    
    @staticmethod
    def get_borrowing_payment(borrow_request: BorrowRequest) -> Optional[Payment]:
        """
        Get the borrowing payment for a request
        """
        return borrow_request.payments.filter(is_borrow_payment=True).first()
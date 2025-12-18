from django.db import transaction
from django.utils import timezone
from typing import Optional, Dict, Any
from decimal import Decimal
import logging

from ..models.return_model import ReturnRequest, ReturnStatus, ReturnFine
from ..models.user_model import User
from ..models.borrowing_model import BorrowRequest, BorrowStatusChoices, FineStatusChoices
from ..models.return_model import ReturnFine
from ..services.notification_services import NotificationService

logger = logging.getLogger(__name__)


class ReturnService:
    """
    Service class for managing return request operations
    """
    
    @staticmethod
    @transaction.atomic
    def approve_return_request(return_request: ReturnRequest) -> ReturnRequest:
        """
        Approve a return request
        Updates status to APPROVED
        Idempotent: if already approved, returns without error
        """
        # If already approved, return without error (idempotent operation)
        if return_request.status == ReturnStatus.APPROVED:
            logger.info(f"Return request {return_request.id} is already approved")
            return return_request
        
        # If not in PENDING status, raise error
        if return_request.status != ReturnStatus.PENDING:
            raise ValueError(f"Return request must be in PENDING status. Current status: {return_request.get_status_display()}")
        
        return_request.status = ReturnStatus.APPROVED
        return_request.save()
        
        # Update borrowing status
        borrowing = return_request.borrowing
        borrowing.status = BorrowStatusChoices.RETURN_REQUESTED
        borrowing.save()
        
        # Send notification to customer
        NotificationService.create_notification(
            user_id=borrowing.customer.id,
            title="Return Request Approved",
            message=f"Your return request for '{borrowing.book.name}' has been approved.",
            notification_type="return_approved"
        )
        
        logger.info(f"Return request {return_request.id} approved")
        return return_request
    
    @staticmethod
    @transaction.atomic
    def assign_delivery_manager(return_request: ReturnRequest, delivery_manager_id: int) -> ReturnRequest:
        """
        Assign a delivery manager to a return request
        Updates status to ASSIGNED
        """
        if return_request.status != ReturnStatus.APPROVED:
            raise ValueError(f"Return request must be in APPROVED status. Current status: {return_request.get_status_display()}")
        
        try:
            delivery_manager = User.objects.get(
                id=delivery_manager_id,
                user_type='delivery_admin',
                is_active=True
            )
        except User.DoesNotExist:
            raise ValueError("Delivery manager not found or inactive")
        
        return_request.delivery_manager = delivery_manager
        return_request.status = ReturnStatus.ASSIGNED
        return_request.save()
        
        # Update borrowing status
        borrowing = return_request.borrowing
        borrowing.status = BorrowStatusChoices.RETURN_ASSIGNED
        borrowing.save()
        
        # Create return_collection order if it doesn't exist
        from ..models.delivery_model import Order
        from ..services.delivery_services import BorrowingDeliveryService
        
        # Check if return_collection order already exists for this borrow_request
        existing_order = Order.objects.filter(
            order_type='return_collection',
            borrow_request=borrowing
        ).first()
        
        if not existing_order:
            # Create return_collection order
            collection_result = BorrowingDeliveryService.create_return_collection_order(borrowing)
            if collection_result['success']:
                logger.info(f"Created return_collection order for return request {return_request.id}")
            else:
                logger.warning(f"Failed to create return_collection order: {collection_result.get('message', 'Unknown error')}")
        
        # Send notification to delivery manager
        NotificationService.create_notification(
            user_id=delivery_manager.id,
            title="New Return Request Assigned",
            message=f"You have been assigned to handle return of '{borrowing.book.name}' from {borrowing.customer.get_full_name()}.",
            notification_type="return_assigned"
        )
        
        # Send notification to customer
        NotificationService.create_notification(
            user_id=borrowing.customer.id,
            title="Return Request Assigned",
            message=f"A delivery manager has been assigned to handle your return request for '{borrowing.book.name}'.",
            notification_type="return_assigned"
        )
        
        logger.info(f"Delivery manager {delivery_manager_id} assigned to return request {return_request.id}")
        return return_request
    
    @staticmethod
    @transaction.atomic
    def accept_return_request(return_request: ReturnRequest) -> ReturnRequest:
        """
        Delivery manager accepts a return request
        Updates status to ACCEPTED
        The return process starts when 'Start Return' is clicked (status becomes IN_PROGRESS)
        """
        if return_request.status != ReturnStatus.ASSIGNED:
            raise ValueError(f"Return request must be in ASSIGNED status. Current status: {return_request.get_status_display()}")
        
        return_request.status = ReturnStatus.ACCEPTED
        return_request.accepted_at = timezone.now()
        return_request.save()
        
        # Update borrowing status - keep as RETURN_ASSIGNED since pickup hasn't started yet
        borrowing = return_request.borrowing
        # Status should remain RETURN_ASSIGNED until pickup actually starts
        # OUT_FOR_RETURN_PICKUP will be set when start_return_process is called
        if borrowing.status != BorrowStatusChoices.RETURN_ASSIGNED:
            borrowing.status = BorrowStatusChoices.RETURN_ASSIGNED
            borrowing.save()
        
        # Send notification to customer
        NotificationService.create_notification(
            user_id=borrowing.customer.id,
            title="Return Request Accepted",
            message=f"Delivery manager has accepted your return request for '{borrowing.book.name}'. They will contact you soon.",
            notification_type="return_accepted"
        )
        
        logger.info(f"Return request {return_request.id} accepted by delivery manager")
        return return_request
    
    @staticmethod
    @transaction.atomic
    def start_return_process(return_request: ReturnRequest) -> ReturnRequest:
        """
        Delivery manager starts the return process (picks up the book)
        Updates status to IN_PROGRESS (return_in_progress)
        Automatically sets delivery manager status to 'busy'
        Idempotent: if already IN_PROGRESS, returns without error
        """
        # If already in progress, return without error (idempotent operation)
        if return_request.status == ReturnStatus.IN_PROGRESS:
            logger.info(f"Return request {return_request.id} is already in progress")
            return return_request
        
        # Return request must be approved/assigned/accepted before starting
        # Allow APPROVED, ASSIGNED, or ACCEPTED status to start the return process
        if return_request.status not in [ReturnStatus.APPROVED, ReturnStatus.ASSIGNED, ReturnStatus.ACCEPTED]:
            raise ValueError(
                f"Return request must be APPROVED, ASSIGNED, or ACCEPTED before starting the return process. "
                f"Current status: {return_request.get_status_display()}"
            )
        
        # Change status to IN_PROGRESS when starting the return process
        return_request.status = ReturnStatus.IN_PROGRESS
        return_request.picked_up_at = timezone.now()
        return_request.save()
        
        # Update borrowing status to indicate return pickup has started
        borrowing = return_request.borrowing
        borrowing.status = BorrowStatusChoices.OUT_FOR_RETURN_PICKUP
        borrowing.save()
        
        # Automatically set delivery manager status to 'busy' when starting return
        # Use centralized method that handles all delivery types consistently
        if return_request.delivery_manager:
            try:
                from ..services.delivery_profile_services import DeliveryProfileService
                
                logger.info(f"Updating delivery manager {return_request.delivery_manager.id} status to busy for return request {return_request.id}")
                
                # Use centralized start_delivery_task method - this ensures consistent behavior
                # across all delivery types (return, borrow, order)
                success = DeliveryProfileService.start_delivery_task(return_request.delivery_manager)
                
                if success:
                    logger.info(f"Delivery manager {return_request.delivery_manager.id} status successfully updated to busy")
                else:
                    logger.warning(f"Delivery manager {return_request.delivery_manager.id} status update returned False - may already be busy")
                
            except Exception as e:
                logger.error(f"Failed to update delivery manager status to busy: {str(e)}", exc_info=True)
                # Don't fail the return process if status update fails, just log the error
        
        # Send notification to customer
        NotificationService.create_notification(
            user_id=borrowing.customer.id,
            title="Return Process Started",
            message=f"Delivery manager has started the return process for '{borrowing.book.name}'. The book is being returned to the library.",
            notification_type="return_started"
        )
        
        logger.info(f"Return process started for return request {return_request.id}")
        return return_request
    
    @staticmethod
    @transaction.atomic
    def complete_return_request(return_request: ReturnRequest) -> ReturnRequest:
        """
        Complete the return request
        Updates status to COMPLETED (returned)
        Increments book available copies
        Automatically sets delivery manager status back to 'online'
        """
        if return_request.status != ReturnStatus.IN_PROGRESS:
            raise ValueError(f"Return request must be in IN_PROGRESS status. Current status: {return_request.get_status_display()}")
        
        # Update return request status to COMPLETED (returned)
        return_request.status = ReturnStatus.COMPLETED
        return_request.completed_at = timezone.now()
        return_request.save()
        
        # Update borrowing status
        borrowing = return_request.borrowing
        borrowing.status = BorrowStatusChoices.RETURNED
        borrowing.actual_return_date = timezone.now()
        borrowing.save()
        
        # Automatically set delivery manager status back to 'online' when completing return
        if return_request.delivery_manager:
            try:
                from ..services.delivery_profile_services import DeliveryProfileService
                from ..models.delivery_profile_model import DeliveryProfile
                
                logger.info(f"Updating delivery manager {return_request.delivery_manager.id} status to online after completing return request {return_request.id}")
                
                # Update status to online, excluding this return request from active returns check
                success = DeliveryProfileService.complete_delivery_task(
                    return_request.delivery_manager,
                    completed_return_id=return_request.id
                )
                
                # Get a fresh reference to verify the status was updated
                try:
                    delivery_profile = DeliveryProfile.objects.get(user=return_request.delivery_manager)
                    delivery_profile.refresh_from_db()
                    
                    if delivery_profile.delivery_status != 'online':
                        # Use unified function to check for active deliveries
                        from ..services.delivery_profile_services import DeliveryProfileService
                        has_active = DeliveryProfileService.has_active_deliveries(
                            return_request.delivery_manager,
                            exclude_return_id=return_request.id
                        )
                        
                        if not has_active:
                            # No other active deliveries, safe to force update
                            logger.warning(
                                f"Status update to online failed for delivery manager {return_request.delivery_manager.id}, "
                                f"current status: {delivery_profile.delivery_status}, forcing update (no other active deliveries)"
                            )
                            delivery_profile.delivery_status = 'online'
                            delivery_profile.save(update_fields=['delivery_status'])
                            logger.info(f"Force updated delivery manager {return_request.delivery_manager.id} status to online")
                        else:
                            logger.info(
                                f"Delivery manager {return_request.delivery_manager.id} has other active deliveries, "
                                f"keeping status as '{delivery_profile.delivery_status}'"
                            )
                    else:
                        logger.info(f"Delivery manager {return_request.delivery_manager.id} status successfully updated to online")
                except DeliveryProfile.DoesNotExist:
                    logger.error(f"Delivery profile not found for user {return_request.delivery_manager.id}")
                
            except Exception as e:
                logger.error(f"Failed to update delivery manager status after return completion: {str(e)}", exc_info=True)
                # Don't fail the return process if status update fails, just log the error
        
        # Increment book available copies
        book = borrowing.book
        if book.available_copies is not None:
            book.available_copies += 1
        else:
            book.available_copies = 1
        book.save(update_fields=['available_copies'])
        
        # Send notification to customer
        NotificationService.create_notification(
            user_id=borrowing.customer.id,
            title="Book Returned Successfully",
            message=f"Your book '{borrowing.book.name}' has been successfully returned to the library.",
            notification_type="return_completed"
        )
        
        logger.info(f"Return request {return_request.id} completed")
        return return_request
    
    @staticmethod
    def get_pending_return_requests():
        """Get all pending return requests"""
        return ReturnRequest.objects.filter(status=ReturnStatus.PENDING)
    
    @staticmethod
    def get_assigned_return_requests(delivery_manager: User):
        """Get return requests assigned to a specific delivery manager"""
        return ReturnRequest.objects.filter(
            delivery_manager=delivery_manager,
            status__in=[ReturnStatus.ASSIGNED, ReturnStatus.ACCEPTED, ReturnStatus.IN_PROGRESS]
        )
    
    # =====================================
    # FINE-RELATED METHODS FOR RETURNS
    # =====================================
    
    @staticmethod
    def get_or_create_return_fine(return_request: ReturnRequest, late_return: bool = False, damaged: bool = False, lost: bool = False):
        """
        Get or create ReturnFine for a return request.
        Business Rule: A fine is only created when there's an actual fine (late return, damage, or loss).
        If no fine exists, returns None instead of creating a zero-amount record.
        
        Args:
            return_request: The return request
            late_return: Whether the return is late
            damaged: Whether the item is damaged
            lost: Whether the item is lost
        
        Returns:
            ReturnFine object if a fine exists, None otherwise
        """
        from django.utils import timezone
        from decimal import Decimal
        
        borrow_request = return_request.borrowing
        
        # Check if a fine already exists
        try:
            return_fine = ReturnFine.objects.get(return_request=return_request)
        except ReturnFine.DoesNotExist:
            return_fine = None
        
        # Calculate fine amount if needed
        days_late = 0
        fine_amount = Decimal('0.00')
        
        if late_return and borrow_request.expected_return_date:
            # Calculate days late
            current_date = timezone.now().date()
            expected_date = borrow_request.expected_return_date.date() if hasattr(borrow_request.expected_return_date, 'date') else borrow_request.expected_return_date
            
            if current_date > expected_date:
                delta = current_date - expected_date
                days_late = delta.days
                daily_rate = Decimal('1.00')  # $1 per day
                fine_amount = daily_rate * days_late
        
        # Add damage/loss penalties if applicable
        if damaged:
            # Add damage penalty (e.g., $10 or percentage of book value)
            damage_penalty = Decimal('10.00')  # Default damage penalty
            fine_amount += damage_penalty
        
        if lost:
            # Add loss penalty (e.g., full book price)
            book_price = borrow_request.book.price if borrow_request.book.price else Decimal('50.00')
            fine_amount += book_price
        
        # Business Rule: No fine record if fine_amount = 0
        if fine_amount <= 0:
            # Delete existing fine if it exists and has zero amount
            if return_fine:
                return_fine.delete()
            return None
        
        # Create or update fine
        if return_fine:
            # Only update if not finalized
            if not return_fine.is_finalized:
                return_fine.fine_amount = fine_amount
                return_fine.fine_reason = ReturnService._build_fine_reason(late_return, damaged, lost, days_late)
                return_fine.late_return = late_return
                return_fine.damaged = damaged
                return_fine.lost = lost
                return_fine.days_late = days_late if late_return else 0
                return_fine.save()
        else:
            # Create new fine
            return_fine = ReturnFine.objects.create(
                return_request=return_request,
                fine_amount=fine_amount,
                fine_reason=ReturnService._build_fine_reason(late_return, damaged, lost, days_late),
                late_return=late_return,
                damaged=damaged,
                lost=lost,
                days_late=days_late if late_return else 0,
                is_paid=False
            )
        
        return return_fine

    @staticmethod
    def _build_fine_reason(late_return: bool, damaged: bool, lost: bool, days_late: int) -> str:
        """
        Build normalized fine reason from fine flags.
        Priority: late_return > damaged > lost
        """
        from ..models.return_model import FineReason
        
        if late_return:
            return FineReason.LATE_RETURN
        elif damaged:
            return FineReason.DAMAGED
        elif lost:
            return FineReason.LOST
        else:
            # Default to late_return if no reason specified (shouldn't happen due to validation)
            return FineReason.LATE_RETURN

    @staticmethod
    def check_and_create_fine_for_return(return_request: ReturnRequest) -> Optional[ReturnFine]:
        """
        Check if the return is late and create/update fine if needed.
        Business Rule: Only creates fine if actual return date exceeds expected return date.
        Returns the fine object if created/updated, None otherwise.
        """
        borrow_request = return_request.borrowing
        
        # Check if book is overdue (late return)
        is_late = borrow_request.is_overdue()
        
        if not is_late:
            # No fine if return is on time
            # Delete any existing zero-amount fine
            try:
                existing_fine = ReturnFine.objects.get(return_request=return_request)
                if existing_fine.fine_amount <= 0:
                    existing_fine.delete()
            except ReturnFine.DoesNotExist:
                pass
            return None
        
        # Calculate days overdue
        days_late = borrow_request.get_days_overdue()
        
        # Create or update fine using the new method
        fine = ReturnService.get_or_create_return_fine(
            return_request=return_request,
            late_return=True,
            damaged=False,
            lost=False
        )
        
        if fine:
            # Send notification to customer about fine
            NotificationService.create_notification(
                user_id=borrow_request.customer.id,
                title="Late Return Fine Applied",
                message=f"A fine of ${fine.fine_amount} has been applied for late return of '{borrow_request.book.name}'. Please pay the fine to complete your return.",
                notification_type="return_fine_applied"
            )
            
            logger.info(f"Fine created/updated for return request {return_request.id}: ${fine.fine_amount}")
        
        return fine
    
    @staticmethod
    @transaction.atomic
    def process_return_with_fine(return_request: ReturnRequest, delivery_manager: User) -> Dict[str, Any]:
        """
        Process return when book is overdue (has fine)
        Updates return status and handles fine-related logic
        """
        if return_request.status != ReturnStatus.IN_PROGRESS:
            raise ValueError(f"Return request must be in IN_PROGRESS status. Current status: {return_request.get_status_display()}")
        
        if return_request.delivery_manager != delivery_manager:
            raise ValueError("You are not assigned to this return request")
        
        borrow_request = return_request.borrowing
        
        # Check and create fine if overdue
        fine = ReturnService.check_and_create_fine_for_return(return_request)
        
        # Update return request status
        return_request.status = ReturnStatus.COMPLETED
        return_request.save()
        
        # Update borrowing status
        borrow_request.actual_return_date = timezone.now()
        if fine:
            borrow_request.status = BorrowStatusChoices.RETURNED_AFTER_DELAY
        else:
            borrow_request.status = BorrowStatusChoices.RETURNED
        borrow_request.save()
        
        # Increment book available copies
        book = borrow_request.book
        if book.available_copies is not None:
            book.available_copies += 1
        else:
            book.available_copies = 1
        book.save(update_fields=['available_copies'])
        
        # Send notifications
        NotificationService.create_notification(
            user_id=borrow_request.customer.id,
            title="Book Return Completed",
            message=f"Your book '{borrow_request.book.name}' has been successfully returned to the library." + 
                   (f" A fine of ${fine.fine_amount} has been applied due to late return." if fine else ""),
            notification_type="return_completed"
        )
        
        # Notify library admins
        library_admins = User.objects.filter(user_type='library_admin', is_active=True)
        for admin in library_admins:
            NotificationService.create_notification(
                user_id=admin.id,
                title="Book Returned" + (" with Fine" if fine else ""),
                message=f"Book '{borrow_request.book.name}' has been returned by {borrow_request.customer.get_full_name()}." +
                       (f" Fine: ${fine.fine_amount}" if fine else ""),
                notification_type="return_completed_admin"
            )
        
        logger.info(f"Return request {return_request.id} completed" + (f" with fine ${fine.fine_amount}" if fine else ""))
        
        return {
            'success': True,
            'message': 'Book returned successfully' + (f' with fine of ${fine.fine_amount}' if fine else ''),
            'return_request_id': return_request.id,
            'fine_amount': float(fine.fine_amount) if fine else 0.0,
            'has_fine': fine is not None,
            'deposit_frozen': borrow_request.is_deposit_frozen() if fine else False
        }
    
    @staticmethod
    @transaction.atomic
    def process_fine_payment_for_return(return_request: ReturnRequest, payment_method: str = 'wallet') -> Dict[str, Any]:
        """
        Process fine payment for a return request
        Enables deposit refund after fine is paid
        """
        borrow_request = return_request.borrowing
        
        # Check if fine exists
        try:
            fine = ReturnFine.objects.get(return_request=return_request)
        except ReturnFine.DoesNotExist:
            raise ValueError("No fine found for this return request")   
        
        # Check if fine is already paid
        if fine.is_paid:
            raise ValueError("Fine has already been paid")
        
        # Check if user owns this return request
        if borrow_request.customer != return_request.borrowing.customer:
            raise ValueError("You can only pay fines for your own return requests")
        
        # Mark fine as paid
        fine.mark_as_paid(borrow_request.customer)
        
        # Calculate and process refund
        refund_amount = borrow_request.process_refund()
        
        # Send payment confirmation notifications
        NotificationService.create_notification(
            user_id=borrow_request.customer.id,
            title="Fine Paid - Refund Processed",
            message=f"Your fine of ${fine.fine_amount} has been paid. Deposit refund of ${refund_amount} has been processed for '{borrow_request.book.name}'.",
            notification_type="fine_paid_refund_processed"
        )
        
        # Notify library admins
        library_admins = User.objects.filter(user_type='library_admin', is_active=True)
        for admin in library_admins:
            NotificationService.create_notification(
                user_id=admin.id,
                title="Fine Payment Completed",
                message=f"Customer {borrow_request.customer.get_full_name()} has paid the fine of ${fine.fine_amount} for return request #{return_request.id}. Refund amount: ${refund_amount}",
                notification_type="fine_payment_completed"
            )
        
        logger.info(f"Fine payment processed for return request {return_request.id}: ${fine.fine_amount}")
        
        return {
            'success': True,
            'message': 'Fine paid successfully',
            'fine_amount': float(fine.fine_amount),
            'refund_amount': float(refund_amount),
            'deposit_refunded': borrow_request.deposit_refunded,
            'return_request_id': return_request.id
        }
    
    @staticmethod
    def get_return_fine_summary(return_request: ReturnRequest) -> Dict[str, Any]:
        """
        Get comprehensive summary of fine status for a return request
        """
        borrow_request = return_request.borrowing
        
        try:
            fine = ReturnFine.objects.get(return_request=return_request)
        except ReturnFine.DoesNotExist:
            fine = None
        
        return {
            'return_request_id': return_request.id,
            'borrow_request_id': borrow_request.id,
            'customer_name': borrow_request.customer.get_full_name(),
            'book_name': borrow_request.book.name,
            'return_status': return_request.status,
            'borrow_status': borrow_request.status,
            'is_overdue': borrow_request.is_overdue(),
            'days_overdue': borrow_request.get_days_overdue() if borrow_request.is_overdue() else 0,
            'has_fine': fine is not None,
            'fine_amount': float(fine.fine_amount) if fine else 0.0,
            'fine_status': 'paid' if fine and fine.is_paid else 'pending' if fine else None,
            'fine_paid': fine.is_paid if fine else False,
            'deposit_amount': float(borrow_request.deposit_amount),
            'deposit_paid': borrow_request.deposit_paid,
            'deposit_refunded': borrow_request.deposit_refunded,
            'deposit_frozen': borrow_request.is_deposit_frozen(),
            'refund_amount': float(borrow_request.refund_amount) if borrow_request.refund_amount else 0.0,
            'fine_details': {
                'days_late': fine.days_late if fine else 0,
                'fine_amount': float(fine.fine_amount) if fine else 0.0,
                'fine_reason': fine.fine_reason if fine else None,
                'late_return': fine.late_return if fine else False,
                'damaged': fine.damaged if fine else False,
                'lost': fine.lost if fine else False,
                'paid_date': fine.paid_at.isoformat() if fine and fine.paid_at else None,
            } if fine else None
        }
    
    @staticmethod
    def can_complete_return_without_fine_payment(return_request: ReturnRequest) -> bool:
        """
        Check if return can be completed without fine payment
        Returns True if no fine exists or fine is already paid
        """
        borrow_request = return_request.borrowing
        
        try:
            fine = ReturnFine.objects.get(return_request=return_request)
            return fine.is_paid
        except ReturnFine.DoesNotExist:
            return True
    
    @staticmethod
    def get_fine_amount_for_return(return_request: ReturnRequest) -> Decimal:
        """
        Get the fine amount for a return request
        Returns 0 if no fine exists
        """
        borrow_request = return_request.borrowing
        
        try:
            fine = ReturnFine.objects.get(return_request=return_request)
            return fine.fine_amount
        except ReturnFine.DoesNotExist:
            return Decimal('0.00')


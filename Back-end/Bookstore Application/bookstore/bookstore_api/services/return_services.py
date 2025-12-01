from django.db import transaction
from django.utils import timezone
from typing import Optional, Dict, Any
from decimal import Decimal
import logging

from ..models.return_model import ReturnRequest, ReturnStatus
from ..models.user_model import User
from ..models.borrowing_model import BorrowRequest, BorrowFine, BorrowStatusChoices, FineStatusChoices
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
        Updates status to IN_PROGRESS (return_in_progress)
        """
        if return_request.status != ReturnStatus.ASSIGNED:
            raise ValueError(f"Return request must be in ASSIGNED status. Current status: {return_request.get_status_display()}")
        
        return_request.status = ReturnStatus.IN_PROGRESS
        return_request.accepted_at = timezone.now()
        return_request.save()
        
        # Update borrowing status
        borrowing = return_request.borrowing
        borrowing.status = BorrowStatusChoices.OUT_FOR_RETURN_PICKUP
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
        Status remains IN_PROGRESS but marks the return as started (return_started)
        Automatically sets delivery manager status to 'busy'
        """
        if return_request.status != ReturnStatus.IN_PROGRESS:
            raise ValueError(f"Return request must be in IN_PROGRESS status. Current status: {return_request.get_status_display()}")
        
        # Status remains IN_PROGRESS, but we mark the return as started
        # Set picked_up_at timestamp to track when return process started
        return_request.picked_up_at = timezone.now()
        return_request.save()
        
        # Update borrowing status to indicate return pickup has started
        borrowing = return_request.borrowing
        borrowing.status = BorrowStatusChoices.OUT_FOR_RETURN_PICKUP
        borrowing.save()
        
        # Automatically set delivery manager status to 'busy' when starting return
        if return_request.delivery_manager:
            try:
                from ..services.delivery_profile_services import DeliveryProfileService
                DeliveryProfileService.start_delivery_task(return_request.delivery_manager)
                logger.info(f"Delivery manager {return_request.delivery_manager.id} status updated to busy when starting return process")
            except Exception as e:
                logger.error(f"Failed to update delivery manager status to busy: {str(e)}")
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
        Automatically sets delivery manager status back to 'online' if no other active deliveries
        """
        if return_request.status != ReturnStatus.IN_PROGRESS:
            raise ValueError(f"Return request must be in IN_PROGRESS status. Current status: {return_request.get_status_display()}")
        
        return_request.status = ReturnStatus.COMPLETED
        return_request.completed_at = timezone.now()
        return_request.save()
        
        # Update borrowing status
        borrowing = return_request.borrowing
        borrowing.status = BorrowStatusChoices.RETURNED
        borrowing.actual_return_date = timezone.now()
        borrowing.save()
        
        # Automatically set delivery manager status back to 'online' when completing return
        # (only if no other active deliveries exist)
        if return_request.delivery_manager:
            try:
                from ..services.delivery_profile_services import DeliveryProfileService
                DeliveryProfileService.complete_delivery_task(return_request.delivery_manager)
                logger.info(f"Delivery manager {return_request.delivery_manager.id} status updated after completing return")
            except Exception as e:
                logger.error(f"Failed to update delivery manager status after return completion: {str(e)}")
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
    def check_and_create_fine_for_return(return_request: ReturnRequest) -> Optional[BorrowFine]:
        """
        Check if the borrowing is overdue and create/update fine if needed
        Returns the fine object if created/updated, None otherwise
        """
        borrow_request = return_request.borrowing
        
        # Check if book is overdue
        if not borrow_request.is_overdue():
            return None
        
        # Calculate days overdue
        days_overdue = borrow_request.get_days_overdue()
        daily_rate = Decimal('1.00')  # $1 per day as per requirements
        
        # Create or update fine
        fine, created = BorrowFine.objects.get_or_create(
            borrow_request=borrow_request,
            defaults={
                'daily_rate': daily_rate,
                'days_overdue': days_overdue,
                'total_amount': daily_rate * days_overdue,
                'reason': f"Late return - {days_overdue} days overdue"
            }
        )
        
        if not created:
            # Update existing fine
            fine.days_overdue = days_overdue
            fine.total_amount = fine.daily_rate * days_overdue
            fine.save()
        
        # Update borrow request fine information
        borrow_request.fine_amount = fine.total_amount
        borrow_request.fine_status = FineStatusChoices.UNPAID
        if borrow_request.status != BorrowStatusChoices.LATE:
            borrow_request.status = BorrowStatusChoices.LATE
        borrow_request.save()
        
        # Send notification to customer about fine
        NotificationService.create_notification(
            user_id=borrow_request.customer.id,
            title="Late Return Fine Applied",
            message=f"A fine of ${fine.total_amount} has been applied for late return of '{borrow_request.book.name}'. Please pay the fine to complete your return.",
            notification_type="return_fine_applied"
        )
        
        logger.info(f"Fine created/updated for return request {return_request.id}: ${fine.total_amount}")
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
                   (f" A fine of ${fine.total_amount} has been applied due to late return." if fine else ""),
            notification_type="return_completed"
        )
        
        # Notify library admins
        library_admins = User.objects.filter(user_type='library_admin', is_active=True)
        for admin in library_admins:
            NotificationService.create_notification(
                user_id=admin.id,
                title="Book Returned" + (" with Fine" if fine else ""),
                message=f"Book '{borrow_request.book.name}' has been returned by {borrow_request.customer.get_full_name()}." +
                       (f" Fine: ${fine.total_amount}" if fine else ""),
                notification_type="return_completed_admin"
            )
        
        logger.info(f"Return request {return_request.id} completed" + (f" with fine ${fine.total_amount}" if fine else ""))
        
        return {
            'success': True,
            'message': 'Book returned successfully' + (f' with fine of ${fine.total_amount}' if fine else ''),
            'return_request_id': return_request.id,
            'fine_amount': float(fine.total_amount) if fine else 0.0,
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
            fine = BorrowFine.objects.get(borrow_request=borrow_request)
        except BorrowFine.DoesNotExist:
            raise ValueError("No fine found for this return request")
        
        # Check if fine is already paid
        if fine.status == FineStatusChoices.PAID:
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
            message=f"Your fine of ${fine.total_amount} has been paid. Deposit refund of ${refund_amount} has been processed for '{borrow_request.book.name}'.",
            notification_type="fine_paid_refund_processed"
        )
        
        # Notify library admins
        library_admins = User.objects.filter(user_type='library_admin', is_active=True)
        for admin in library_admins:
            NotificationService.create_notification(
                user_id=admin.id,
                title="Fine Payment Completed",
                message=f"Customer {borrow_request.customer.get_full_name()} has paid the fine of ${fine.total_amount} for return request #{return_request.id}. Refund amount: ${refund_amount}",
                notification_type="fine_payment_completed"
            )
        
        logger.info(f"Fine payment processed for return request {return_request.id}: ${fine.total_amount}")
        
        return {
            'success': True,
            'message': 'Fine paid successfully',
            'fine_amount': float(fine.total_amount),
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
            fine = BorrowFine.objects.get(borrow_request=borrow_request)
        except BorrowFine.DoesNotExist:
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
            'fine_amount': float(fine.total_amount) if fine else 0.0,
            'fine_status': fine.status if fine else None,
            'fine_paid': fine.status == FineStatusChoices.PAID if fine else False,
            'deposit_amount': float(borrow_request.deposit_amount),
            'deposit_paid': borrow_request.deposit_paid,
            'deposit_refunded': borrow_request.deposit_refunded,
            'deposit_frozen': borrow_request.is_deposit_frozen(),
            'refund_amount': float(borrow_request.refund_amount) if borrow_request.refund_amount else 0.0,
            'fine_details': {
                'daily_rate': float(fine.daily_rate) if fine else 0.0,
                'days_overdue': fine.days_overdue if fine else 0,
                'total_amount': float(fine.total_amount) if fine else 0.0,
                'paid_date': fine.paid_date.isoformat() if fine and fine.paid_date else None,
                'reason': fine.reason if fine else None
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
            fine = BorrowFine.objects.get(borrow_request=borrow_request)
            return fine.status == FineStatusChoices.PAID
        except BorrowFine.DoesNotExist:
            return True
    
    @staticmethod
    def get_fine_amount_for_return(return_request: ReturnRequest) -> Decimal:
        """
        Get the fine amount for a return request
        Returns 0 if no fine exists
        """
        borrow_request = return_request.borrowing
        
        try:
            fine = BorrowFine.objects.get(borrow_request=borrow_request)
            return fine.total_amount
        except BorrowFine.DoesNotExist:
            return Decimal('0.00')


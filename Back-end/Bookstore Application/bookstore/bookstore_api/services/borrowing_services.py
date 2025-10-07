from django.db.models import Q, Count, Avg, Sum
from django.utils import timezone
from datetime import timedelta
from decimal import Decimal
from typing import List, Dict, Any, Optional

from ..models import (
    BorrowRequest, BorrowExtension, BorrowFine, BorrowStatistics,
    Book, User, Payment, BorrowStatusChoices, ExtensionStatusChoices, FineStatusChoices
)
from ..services.notification_services import NotificationService


class BorrowingService:
    """
    Service class for managing book borrowing operations
    """
    
    @staticmethod
    def create_borrow_request(customer: User, book: Book, borrow_period_days: int, delivery_address: str, additional_notes: str = "") -> BorrowRequest:
        """
        Create a new borrow request
        """
        borrow_request = BorrowRequest.objects.create(
            customer=customer,
            book=book,
            borrow_period_days=borrow_period_days,
            delivery_address=delivery_address,
            additional_notes=additional_notes,
            expected_return_date=timezone.now() + timedelta(days=borrow_period_days)
        )
        
        # Send notification to library manager
        library_manager = User.objects.filter(user_type='library_admin', is_active=True).first()
        if library_manager:
            NotificationService.create_notification(
                user_id=library_manager.id,
                title="New Borrowing Request",
                message=f"New borrowing request from {customer.get_full_name()} for '{book.name}'",
                notification_type="borrow_request"
            )
        
        return borrow_request
    
    @staticmethod
    def approve_borrow_request(borrow_request: BorrowRequest, approved_by: User, delivery_manager: User = None) -> BorrowRequest:
        """
        Approve a borrow request and assign to delivery manager
        """
        # Reserve a copy of the book
        if not borrow_request.book.borrow_copy():
            raise ValueError("No copies available for borrowing")
        
        borrow_request.status = BorrowStatusChoices.APPROVED
        borrow_request.approved_by = approved_by
        borrow_request.approved_date = timezone.now()
        
        # Assign delivery manager if provided
        if delivery_manager:
            borrow_request.delivery_person = delivery_manager
            
            # Update delivery manager status to busy
            if hasattr(delivery_manager, 'delivery_profile'):
                delivery_manager.delivery_profile.delivery_status = 'busy'
                delivery_manager.delivery_profile.save()
        
        borrow_request.save()
        
        # Create delivery order as specified in requirements
        from ..services.delivery_services import BorrowingDeliveryService
        delivery_order = BorrowingDeliveryService.create_delivery_for_borrow(borrow_request)
        
        # Send notification to customer
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
    def start_delivery(borrow_request: BorrowRequest, delivery_person: User) -> BorrowRequest:
        """
        Mark book as picked up from library (Step 5: Pick up the book from the library)
        """
        borrow_request.status = BorrowStatusChoices.PENDING_DELIVERY
        borrow_request.pickup_date = timezone.now()
        borrow_request.delivery_person = delivery_person
        borrow_request.save()
        
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
        Mark book as delivered to customer (Step 5: When the book is delivered to the customer)
        """
        borrow_request.status = BorrowStatusChoices.ACTIVE
        borrow_request.delivery_date = timezone.now()
        borrow_request.delivery_notes = delivery_notes
        
        # Set final return date
        borrow_request.final_return_date = borrow_request.expected_return_date
        borrow_request.save()
        
        # Update delivery manager status back to online
        if borrow_request.delivery_person and hasattr(borrow_request.delivery_person, 'delivery_profile'):
            from ..services.delivery_profile_services import DeliveryProfileService
            DeliveryProfileService.update_delivery_status(borrow_request.delivery_person, 'online')
        
        # Increment borrow count when book is successfully delivered
        borrow_request.book.borrow_count += 1
        borrow_request.book.save()
        
        # Update book statistics
        BorrowingService.update_book_statistics(borrow_request.book)
        
        # Send notification to customer
        NotificationService.create_notification(
            user_id=borrow_request.customer.id,
            title="Book Delivered Successfully",
            message=f"Your book '{borrow_request.book.name}' has been delivered. Return date: {borrow_request.final_return_date.strftime('%Y-%m-%d')}",
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
        Request early return of a book (Step 7: Return Process)
        """
        borrow_request.status = BorrowStatusChoices.RETURN_REQUESTED
        borrow_request.save()
        
        # Create return delivery task for delivery manager
        from ..models.delivery_model import DeliveryRequest
        delivery_request = DeliveryRequest.objects.create(
            customer=borrow_request.customer,
            request_type='return',
            pickup_address=getattr(borrow_request.customer, 'address', 'Address not provided'),
            delivery_address="Main Library",
            pickup_city=getattr(borrow_request.customer, 'city', 'Customer City'),
            delivery_city="Library City",
            preferred_pickup_time=timezone.now() + timedelta(hours=1),
            preferred_delivery_time=timezone.now() + timedelta(hours=4),
            notes=f"Collect book '{borrow_request.book.name}' from {borrow_request.customer.get_full_name()} for return",
            status='pending'
        )
        
        # Send notification to delivery managers
        delivery_managers = User.objects.filter(user_type='delivery_admin', is_active=True)
        for manager in delivery_managers:
            NotificationService.create_notification(
                user_id=manager.id,
                title="Book Return Request",
                message=f"New Request: Collect the book '{borrow_request.book.name}' from {borrow_request.customer.get_full_name()} and return it to the library.",
                notification_type="return_task_created"
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
        """
        queryset = BorrowRequest.objects.filter(customer=customer).select_related('book', 'book__author')
        
        if status:
            queryset = queryset.filter(status=status)
        
        return queryset.order_by('-request_date')
    
    @staticmethod
    def get_all_borrowing_requests(status: Optional[str] = None, search: Optional[str] = None) -> List[BorrowRequest]:
        """
        Get all borrowing requests with optional status filter and search
        
        Args:
            status: Optional status filter (e.g., 'pending', 'approved', 'active', etc.)
            search: Optional search query for customer name, book title, or request ID
            
        Returns:
            List of borrowing requests
        """
        queryset = BorrowRequest.objects.select_related('customer', 'book').order_by('-request_date')
        
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
        Get all delivery managers with their status for admin selection
        """
        from ..models import DeliveryProfile
        
        delivery_managers = User.objects.filter(
            user_type='delivery_admin',
            is_active=True
        ).select_related('delivery_profile').order_by('first_name', 'last_name')
        
        return delivery_managers


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
                
                # Create or update fine as specified in requirements
                fine, created = BorrowFine.objects.get_or_create(
                    borrow_request=borrowing,
                    defaults={
                        'daily_rate': Decimal('1.00'),  # $1 per day as specified
                        'days_overdue': borrowing.get_days_overdue(),
                        'total_amount': Decimal('1.00') * borrowing.get_days_overdue(),
                        'reason': "Delayed Return"
                    }
                )
                
                if not created:
                    # Update existing fine
                    fine.days_overdue = borrowing.get_days_overdue()
                    fine.total_amount = fine.daily_rate * borrowing.get_days_overdue()
                    fine.save()
                
                # Update borrow request fine information
                borrowing.fine_amount = fine.total_amount
                borrowing.fine_status = FineStatusChoices.UNPAID
                borrowing.save()
                
                # Send notification to customer as specified
                NotificationService.create_notification(
                    user_id=borrowing.customer.id,
                    title="Book Overdue - Fine Applied",
                    message=f"A penalty of ${fine.total_amount} has been imposed due to late return of the book '{borrowing.book.name}'.",
                    notification_type="overdue_fine"
                )
                
                # Send notification to library manager
                library_admins = User.objects.filter(user_type='library_admin')
                for admin in library_admins:
                    NotificationService.create_notification(
                        user_id=admin.id,
                        title="Overdue Book Alert",
                        message=f"Customer {borrowing.customer.get_full_name()} has been late returning book '{borrowing.book.name}' for {borrowing.get_days_overdue()} days. Fine: ${fine.total_amount}",
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
                'fine_amount': fine.total_amount,
                'days_overdue': fine.days_overdue
            }
            
        except Exception as e:
            return {
                'success': False,
                'message': f'Failed to process late return: {str(e)}'
            }
    
    @staticmethod
    def create_or_update_fine(borrow_request):
        """Create or update fine for overdue borrowing"""
        days_overdue = borrow_request.get_days_overdue()
        daily_rate = Decimal('1.00')  # $1 per day as per requirements
        
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
            fine.update_fine(days_overdue)
        
        # Update borrow request fine information
        borrow_request.fine_amount = fine.total_amount
        borrow_request.fine_status = FineStatusChoices.UNPAID
        borrow_request.save()
        
        return fine
    
    @staticmethod
    def send_late_return_notifications(borrow_request, fine):
        """Send notifications to all stakeholders about late return"""
        
        # Customer notification
        NotificationService.create_notification(
            user_id=borrow_request.customer.id,
            title="Book Return Overdue",
            message=f"You are late in returning '{borrow_request.book.name}'. Please return to avoid additional penalty. Current fine: ${fine.total_amount}",
            notification_type="late_return_customer"
        )
        
        # Library manager notification
        library_admins = User.objects.filter(user_type='library_admin')
        for admin in library_admins:
            NotificationService.create_notification(
                user_id=admin.id,
                title="Customer Late Return Alert",
                message=f"Customer {borrow_request.customer.get_full_name()} has been late returning book '{borrow_request.book.name}' for {fine.days_overdue} days. Fine: ${fine.total_amount}",
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
                'fine_amount': fine.total_amount,
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
                'daily_rate': fine.daily_rate if fine else 0,
                'days_overdue': fine.days_overdue if fine else 0,
                'total_amount': fine.total_amount if fine else 0,
                'paid_date': fine.paid_date if fine else None
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
        
        # Fine statistics
        fines = BorrowFine.objects.aggregate(
            total=Sum('total_amount'),
            paid=Sum('total_amount', filter=Q(status=FineStatusChoices.PAID)),
            unpaid=Sum('total_amount', filter=Q(status=FineStatusChoices.UNPAID))
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
        customer_fines = BorrowFine.objects.filter(
            borrow_request__customer=customer
        ).aggregate(
            total=Sum('total_amount'),
            unpaid=Sum('total_amount', filter=Q(status=FineStatusChoices.UNPAID))
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
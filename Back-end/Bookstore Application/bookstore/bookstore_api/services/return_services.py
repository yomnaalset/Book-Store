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

"""
CRITICAL DESIGN RULE: DeliveryRequest.status MUST be updated when delivery_manager is assigned or status changes.

This is the single source of truth for delivery status in the frontend. The frontend relies on 
delivery_request_status to determine UI state, menu visibility, and button availability.

Status Transition Rules:
1. When delivery_manager is assigned → DeliveryRequest.status MUST be 'assigned'
2. When return request is accepted → DeliveryRequest.status MUST be 'accepted'
3. When return process starts → DeliveryRequest.status MUST be 'in_delivery'
4. When return is completed → DeliveryRequest.status MUST be 'completed'

NEVER create or update DeliveryRequest with:
- status='pending' + delivery_manager (invalid state)
- delivery_manager set but status not updated (causes UI inconsistencies)

All status updates must be atomic and happen within the same transaction as the ReturnRequest update.
"""


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
        Idempotent: if already approved or past approval stage, returns without error
        """
        # If already approved or past approval stage, return without error (idempotent operation)
        # This includes: APPROVED, ASSIGNED, ACCEPTED, IN_PROGRESS, COMPLETED
        if return_request.status in [ReturnStatus.APPROVED, ReturnStatus.ASSIGNED, 
                                      ReturnStatus.ACCEPTED, ReturnStatus.IN_PROGRESS, 
                                      ReturnStatus.COMPLETED]:
            logger.info(f"Return request {return_request.id} is already approved or past approval stage (status: {return_request.status})")
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
        
        # Create delivery request for return collection if it doesn't exist
        # This ensures delivery_request_status is available for the frontend
        from ..models.delivery_model import DeliveryRequest
        
        existing_delivery = DeliveryRequest.objects.filter(
            return_request=return_request,
            delivery_type='return'
        ).first()
        
        if not existing_delivery:
            # Create delivery request with status='pending' (no delivery_manager yet)
            try:
                delivery_request = DeliveryRequest.objects.create(
                    delivery_type='return',
                    customer=borrowing.customer,
                    delivery_address=borrowing.delivery_address,
                    delivery_city=getattr(borrowing, 'delivery_city', None),
                    return_request=return_request,
                    delivery_manager=None,  # Will be assigned later
                    status='pending',
                    created_at=return_request.created_at
                )
                logger.info(f"Created delivery request {delivery_request.id} for return request {return_request.id} with status='pending'")
            except Exception as e:
                logger.warning(f"Failed to create delivery request for return: {str(e)}")
        
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
        Idempotent: if already assigned or past assignment stage, returns without error
        """
        logger.info("assign_delivery_manager called - ReturnRequest ID: %s, DeliveryManager ID: %s", 
                   return_request.id, delivery_manager_id)
        
        # If already assigned or past assignment stage, return without error (idempotent operation)
        # This includes: ASSIGNED, ACCEPTED, IN_PROGRESS, COMPLETED
        if return_request.status in [ReturnStatus.ASSIGNED, ReturnStatus.ACCEPTED, 
                                      ReturnStatus.IN_PROGRESS, ReturnStatus.COMPLETED]:
            logger.info(f"Return request {return_request.id} is already assigned or past assignment stage (status: {return_request.status})")
            return return_request
        
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
        
        # Check if delivery manager is available - only 'online' (available) managers can be assigned
        from ..models.delivery_profile_model import DeliveryProfile
        delivery_profile, created = DeliveryProfile.objects.get_or_create(
            user=delivery_manager,
            defaults={'delivery_status': 'offline'}
        )
        
        # Only allow assignment if manager is 'online' (available)
        if delivery_profile.delivery_status != 'online':
            status_display = delivery_profile.get_delivery_status_display() if delivery_profile.delivery_status else 'offline'
            raise ValueError(
                f"Cannot assign return request: Delivery manager is {status_display.lower()}. "
                f"Only available (online) managers can be assigned new requests."
            )
        
        return_request.delivery_manager = delivery_manager
        return_request.status = ReturnStatus.ASSIGNED
        return_request.save()
        
        # Update borrowing status
        borrowing = return_request.borrowing
        borrowing.status = BorrowStatusChoices.RETURN_ASSIGNED
        borrowing.save()
        
        # CRITICAL: Update or create DeliveryRequest with status='assigned'
        # Rule: When delivery_manager is assigned, DeliveryRequest.status MUST be 'assigned'
        from ..models import DeliveryRequest
        
        # 🔍 DEBUG: Check for duplicate DeliveryRequests BEFORE assignment
        all_deliveries = DeliveryRequest.objects.filter(
            return_request=return_request,
            delivery_type='return'
        ).order_by('-id')
        delivery_count = all_deliveries.count()
        
        if delivery_count > 1:
            logger.warning(
                f"🔴 DUPLICATE DETECTED: ReturnRequest {return_request.id} has {delivery_count} DeliveryRequests! "
                f"This is a serious bug. DeliveryRequest IDs: {list(all_deliveries.values_list('id', flat=True))}"
            )
            # Log all DeliveryRequests for debugging
            for dr in all_deliveries:
                logger.warning(
                    f"  DeliveryRequest {dr.id}: status='{dr.status}', "
                    f"delivery_manager_id={dr.delivery_manager_id}, created_at={dr.created_at}"
                )
        
        # Find existing delivery request (should be created during approval)
        existing_delivery = all_deliveries.first()
        
        if existing_delivery:
            # Update existing delivery request
            # CRITICAL: Always update status to 'assigned' when manager is assigned
            logger.info(
                f"BEFORE UPDATE: DeliveryRequest {existing_delivery.id} "
                f"status='{existing_delivery.status}', delivery_manager_id={existing_delivery.delivery_manager_id}"
            )
            
            # Explicitly set all fields to ensure update
            existing_delivery.delivery_manager = delivery_manager
            # CRITICAL: Change status from 'pending' to 'assigned' when manager is assigned
            if existing_delivery.status == 'pending':
                existing_delivery.status = 'assigned'
            elif existing_delivery.status not in ['assigned', 'accepted', 'in_delivery', 'completed']:
                # If status is somehow invalid, force it to 'assigned'
                existing_delivery.status = 'assigned'
            
            if not existing_delivery.assigned_at:
                existing_delivery.assigned_at = timezone.now()
            
            # CRITICAL: Use direct SQL update to ensure status is definitely changed
            # This bypasses any ORM issues, signals, or caching
            from django.db import connection
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    UPDATE delivery_request 
                    SET delivery_manager_id = %s, 
                        status = 'assigned', 
                        assigned_at = COALESCE(assigned_at, %s),
                        updated_at = NOW()
                    WHERE id = %s
                    """,
                    [delivery_manager.id, timezone.now(), existing_delivery.id]
                )
                updated_count = cursor.rowcount
                logger.info(
                    f"DIRECT SQL UPDATE: DeliveryRequest {existing_delivery.id} "
                    f"updated {updated_count} row(s) with status='assigned', delivery_manager_id={delivery_manager.id}"
                )
                
                if updated_count == 0:
                    logger.error(f"CRITICAL: Direct SQL update failed for DeliveryRequest {existing_delivery.id}")
                    raise ValueError("Failed to update delivery request status via direct SQL")
                
                # Immediately verify the update worked
                cursor.execute(
                    "SELECT status, delivery_manager_id FROM delivery_request WHERE id = %s",
                    [existing_delivery.id]
                )
                verify_row = cursor.fetchone()
                if verify_row:
                    verify_status, verify_manager_id = verify_row
                    if verify_status != 'assigned':
                        logger.error(
                            f"❌ CRITICAL: DeliveryRequest {existing_delivery.id} status is '{verify_status}', "
                            f"expected 'assigned'!"
                        )
                        raise ValueError(f"DeliveryRequest status update verification failed - status is '{verify_status}'")
                    logger.info(
                        f"✅ VERIFIED: DeliveryRequest {existing_delivery.id} "
                        f"status='{verify_status}', delivery_manager_id={verify_manager_id}"
                    )
            
            # Also update via ORM for consistency (though SQL already did it)
            existing_delivery.refresh_from_db()
            logger.info(
                f"AFTER REFRESH: DeliveryRequest {existing_delivery.id} "
                f"status='{existing_delivery.status}', delivery_manager_id={existing_delivery.delivery_manager_id}"
            )
            
            logger.info(
                f"✅ Updated DeliveryRequest {existing_delivery.id} for ReturnRequest {return_request.id}: "
                f"status='assigned', delivery_manager_id={delivery_manager.id}"
            )
        else:
            # Create new delivery request with status='assigned' and delivery_manager
            # CRITICAL: Never create with status='pending' + delivery_manager (invalid design)
            delivery_request = DeliveryRequest.objects.create(
                delivery_type='return',
                customer=borrowing.customer,
                delivery_address=borrowing.delivery_address,
                delivery_city=getattr(borrowing, 'delivery_city', None),
                return_request=return_request,
                delivery_manager=delivery_manager,
                status='assigned',
                assigned_at=timezone.now()
            )
            logger.info(
                f"Created DeliveryRequest {delivery_request.id} for ReturnRequest {return_request.id}: "
                f"status='assigned', delivery_manager_id={delivery_manager.id}"
            )
        
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
        
        # CRITICAL: Update DeliveryRequest status to 'accepted'
        # Rule: When return request is accepted, DeliveryRequest.status MUST be 'accepted'
        from ..models.delivery_model import DeliveryRequest
        delivery_request = DeliveryRequest.objects.filter(
            return_request=return_request,
            delivery_type='return'
        ).first()
        
        if delivery_request:
            if delivery_request.status != 'assigned':
                logger.warning(
                    f"DeliveryRequest {delivery_request.id} status is '{delivery_request.status}', "
                    f"expected 'assigned' before accepting. Updating to 'accepted' anyway."
                )
            delivery_request.status = 'accepted'
            delivery_request.accepted_at = timezone.now()
            delivery_request.save(update_fields=['status', 'accepted_at', 'updated_at'])
            logger.info(
                f"Updated DeliveryRequest {delivery_request.id} status to 'accepted' "
                f"for ReturnRequest {return_request.id}"
            )
        else:
            logger.warning(
                f"No DeliveryRequest found for ReturnRequest {return_request.id} when accepting. "
                f"This should not happen."
            )
        
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
        
        # CRITICAL: Update DeliveryRequest status to 'in_delivery'
        # Rule: When return process starts, DeliveryRequest.status MUST be 'in_delivery'
        from ..models.delivery_model import DeliveryRequest
        delivery_request = DeliveryRequest.objects.filter(
            return_request=return_request,
            delivery_type='return'
        ).first()
        
        if delivery_request:
            # Validate state transition: should be 'accepted' or 'assigned' before starting
            if delivery_request.status not in ['assigned', 'accepted']:
                logger.warning(
                    f"DeliveryRequest {delivery_request.id} status is '{delivery_request.status}', "
                    f"expected 'assigned' or 'accepted' before starting. Updating to 'in_delivery' anyway."
                )
            delivery_request.status = 'in_delivery'
            delivery_request.started_at = timezone.now()
            delivery_request.save(update_fields=['status', 'started_at', 'updated_at'])
            logger.info(
                f"Updated DeliveryRequest {delivery_request.id} status to 'in_delivery' "
                f"for ReturnRequest {return_request.id}"
            )
        else:
            logger.warning(
                f"No DeliveryRequest found for ReturnRequest {return_request.id} when starting return. "
                f"This should not happen."
            )
        
        # Note: Delivery manager availability remains unchanged when starting return process
        # Only 'online' (available) managers can start returns, and they stay 'online'
        
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
        Checks for late return and creates fine if needed
        Automatically sets delivery manager status back to 'online'
        """
        if return_request.status != ReturnStatus.IN_PROGRESS:
            raise ValueError(f"Return request must be in IN_PROGRESS status. Current status: {return_request.get_status_display()}")
        
        borrowing = return_request.borrowing
        return_date = timezone.now()
        
        # Check if the return is late BEFORE updating status
        # We need to check against expected_return_date while the book is still considered "active"
        is_late = borrowing.expected_return_date and return_date > borrowing.expected_return_date
        
        # CRITICAL: Update DeliveryRequest status to 'completed' FIRST
        # Rule: When return is completed, DeliveryRequest.status MUST be 'completed'
        from ..models.delivery_model import DeliveryRequest
        delivery_request = DeliveryRequest.objects.filter(
            return_request=return_request,
            delivery_type='return'
        ).first()
        
        if delivery_request:
            if delivery_request.status != 'in_delivery':
                logger.warning(
                    f"DeliveryRequest {delivery_request.id} status is '{delivery_request.status}', "
                    f"expected 'in_delivery' before completing. Updating to 'completed' anyway."
                )
            delivery_request.status = 'completed'
            delivery_request.completed_at = return_date
            delivery_request.save(update_fields=['status', 'completed_at', 'updated_at'])
            logger.info(
                f"Updated DeliveryRequest {delivery_request.id} status to 'completed' "
                f"for ReturnRequest {return_request.id}"
            )
        else:
            logger.warning(
                f"No DeliveryRequest found for ReturnRequest {return_request.id} when completing return. "
                f"This should not happen."
            )
        
        # Update return request status to COMPLETED (returned)
        return_request.status = ReturnStatus.COMPLETED
        return_request.completed_at = return_date
        return_request.save()
        
        # Update borrowing status
        if is_late:
            borrowing.status = BorrowStatusChoices.RETURNED_AFTER_DELAY
        else:
            borrowing.status = BorrowStatusChoices.RETURNED
        borrowing.actual_return_date = return_date
        borrowing.final_return_date = return_date  # Set final_return_date for frontend display
        borrowing.save()
        
        # Check and create fine if the return is late (more than 1 hour after due time)
        if is_late:
            # Calculate hours late
            delta = return_date - borrowing.expected_return_date
            total_seconds = delta.total_seconds()
            hours_late = int(total_seconds / 3600)  # Convert to hours
            
            # Only impose fine if more than 1 hour late
            if hours_late > 0:
                # Create fine for late return
                fine = ReturnService.get_or_create_return_fine(
                    return_request=return_request,
                    late_return=True,
                    damaged=False,
                    lost=False
                )
                
                if fine:
                    # Format time display
                    if hours_late < 24:
                        time_display = f"{hours_late} hour(s)"
                    else:
                        days = hours_late // 24
                        remaining_hours = hours_late % 24
                        if remaining_hours > 0:
                            time_display = f"{days} day(s) and {remaining_hours} hour(s)"
                        else:
                            time_display = f"{days} day(s)"
                    
                    # Send notification to customer about fine
                    NotificationService.create_notification(
                        user_id=borrowing.customer.id,
                        title="Late Return Fine Applied",
                        message=f"A fine of ${fine.fine_amount} has been applied for late return of '{borrowing.book.name}'. The book was due at {borrowing.expected_return_date.strftime('%Y-%m-%d %H:%M')} but was returned at {return_date.strftime('%Y-%m-%d %H:%M')} ({time_display} late). Please pay the fine.",
                        notification_type="return_fine_applied"
                    )
                    
                    logger.info(f"Late return fine created for return request {return_request.id}: ${fine.fine_amount} ({hours_late} hours late)")
        
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
        
        # Check if a fine already exists using raw SQL to avoid column issues
        from django.db import connection
        return_fine = None
        try:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT id, return_request_id, fine_amount, fine_reason, 
                           days_late, is_paid, payment_method, is_finalized, paid_at, transaction_id
                    FROM return_fine 
                    WHERE return_request_id = %s
                    """,
                    [return_request.id]
                )
                row = cursor.fetchone()
                if row:
                    # Create a minimal ReturnFine-like object with only available fields
                    return_fine = type('ReturnFine', (), {
                        'id': row[0],
                        'return_request_id': row[1],
                        'return_request': return_request,
                        'fine_amount': row[2],
                        'fine_reason': row[3],
                        'days_late': row[4] if row[4] else 0,
                        'is_paid': bool(row[5]),
                        'payment_method': row[6],
                        'is_finalized': bool(row[7]) if row[7] is not None else False,
                        'paid_at': row[8],
                        'transaction_id': row[9],
                        # Set boolean fields based on fine_reason
                        'late_return': row[3] == 'late' if row[3] else False,
                        'damaged': row[3] == 'damage' if row[3] else False,
                        'lost': row[3] == 'lost' if row[3] else False,
                    })()
        except Exception as sql_error:
            logger.error(f"Error querying return_fine with raw SQL: {str(sql_error)}")
            return_fine = None
        
        # If fine already exists, return it without recalculating
        # This preserves manually adjusted fine amounts (e.g., from increase-fine)
        # Fine amounts should only be recalculated when explicitly creating a new fine
        if return_fine:
            # Sync the existing fine amount to borrow request
            try:
                with connection.cursor() as cursor:
                    cursor.execute("""
                        UPDATE borrow_request SET fine_amount = %s WHERE id = %s
                    """, [str(return_fine.fine_amount), borrow_request.id])
            except Exception as sync_error:
                logger.warning(f"Could not sync fine amount to borrow request: {str(sync_error)}")
            return return_fine
        
        # Calculate fine amount if needed
        days_late = 0
        fine_amount = Decimal('0.00')
        
        # Auto-detect if book is overdue when no reason flags are provided
        if not (late_return or damaged or lost):
            # Check if the borrowing is overdue
            if borrow_request.expected_return_date:
                from django.utils import timezone
                current_datetime = timezone.now()
                expected_datetime = borrow_request.expected_return_date
                if current_datetime > expected_datetime:
                    late_return = True  # Auto-set late_return flag
        
        if late_return and borrow_request.expected_return_date:
            # Calculate hours late (fine imposed after 1 hour)
            current_datetime = timezone.now()
            expected_datetime = borrow_request.expected_return_date
            
            if current_datetime > expected_datetime:
                delta = current_datetime - expected_datetime
                total_seconds = delta.total_seconds()
                hours_late = int(total_seconds / 3600)  # Convert to hours
                
                # Only impose fine if more than 1 hour late
                if hours_late > 0:
                    # Fine rate: $0.10 per hour
                    hour_rate = Decimal('0.10')
                    fine_amount = hour_rate * hours_late
                    # Round to 2 decimal places
                    fine_amount = fine_amount.quantize(Decimal('0.01'))
                    # Store hours_late for display purposes (convert to days for days_late field)
                    days_late = hours_late
        
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
            if return_fine and return_fine.id:
                with connection.cursor() as cursor:
                    cursor.execute("DELETE FROM return_fine WHERE id = %s", [return_fine.id])
            return None
        
        # Create or update fine
        # Check if boolean fields exist in the database schema
        from django.db import connection
        has_boolean_fields = False
        try:
            with connection.cursor() as cursor:
                cursor.execute("""
                    SELECT COUNT(*) FROM information_schema.COLUMNS 
                    WHERE TABLE_SCHEMA = DATABASE() 
                    AND TABLE_NAME = 'return_fine' 
                    AND COLUMN_NAME = 'late_return'
                """)
                has_boolean_fields = cursor.fetchone()[0] > 0
        except Exception:
            # If we can't check, assume fields don't exist to be safe
            has_boolean_fields = False
        
        fine_reason = ReturnService._build_fine_reason(late_return, damaged, lost, days_late)
        
        if has_boolean_fields:
            # Database has boolean fields - use normal Django ORM
            if return_fine:
                # Only update if not finalized
                if not return_fine.is_finalized:
                    return_fine.fine_amount = fine_amount
                    return_fine.fine_reason = fine_reason
                    return_fine.late_return = late_return
                    return_fine.damaged = damaged
                    return_fine.lost = lost
                    return_fine.days_late = days_late if late_return else 0
                    return_fine.save()
            else:
                # Create new fine with boolean fields
                return_fine = ReturnFine.objects.create(
                    return_request=return_request,
                    fine_amount=fine_amount,
                    fine_reason=fine_reason,
                    days_late=days_late if late_return else 0,
                    is_paid=False,
                    late_return=late_return,
                    damaged=damaged,
                    lost=lost
                )
        else:
            # Database doesn't have boolean fields - use raw SQL
            if return_fine:
                # Update existing fine using raw SQL
                if not return_fine.is_finalized:
                    days_late_val = days_late if late_return else 0
                    with connection.cursor() as cursor:
                        cursor.execute("""
                            UPDATE return_fine 
                            SET fine_amount = %s, fine_reason = %s, days_late = %s
                            WHERE id = %s
                        """, [str(fine_amount), fine_reason, days_late_val, return_fine.id])
                    # Update the minimal object with new values
                    return_fine.fine_amount = fine_amount
                    return_fine.fine_reason = fine_reason
                    return_fine.days_late = days_late_val
            else:
                # Create new fine using raw SQL (without boolean fields)
                # Include all columns that exist in the database without default values
                # Note: payment_status doesn't exist - payment status is derived from is_paid
                days_late_val = days_late if late_return else 0
                fine_type = 'late' if late_return else ('damage' if damaged else ('lost' if lost else 'late'))
                with connection.cursor() as cursor:
                    cursor.execute("""
                        INSERT INTO return_fine (return_request_id, fine_amount, fine_reason, fine_type, days_late, days_overdue, is_paid, is_finalized, daily_rate, created_at, updated_at)
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, NOW(), NOW())
                    """, [return_request.id, str(fine_amount), fine_reason, fine_type, days_late_val, days_late_val, False, False, '1.00'])
                    fine_id = cursor.lastrowid
                
                # Create a minimal object with the data we just inserted
                # Don't use ORM as it tries to access columns that don't exist
                return_fine = type('ReturnFine', (), {
                    'id': fine_id,
                    'return_request': return_request,
                    'return_request_id': return_request.id,
                    'fine_amount': fine_amount,
                    'fine_reason': fine_reason,
                    'days_late': days_late_val,
                    'is_paid': False,
                    'is_finalized': False,
                    'payment_method': None,
                    'paid_at': None,
                    'transaction_id': None,
                    'late_return': late_return,
                    'damaged': damaged,
                    'lost': lost
                })()
        
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
    def check_and_apply_fines_for_completed_returns() -> Dict[str, Any]:
        """
        Check all completed returns and apply fines retroactively if they were late.
        This is useful for applying fines to returns that were completed before the fine system was implemented.
        """
        from ..models.return_model import ReturnFine
        
        # Get all completed return requests
        completed_returns = ReturnRequest.objects.filter(
            status=ReturnStatus.COMPLETED
        ).select_related('borrowing', 'borrowing__book', 'borrowing__customer')
        
        fines_created = 0
        fines_updated = 0
        returns_checked = 0
        
        for return_request in completed_returns:
            returns_checked += 1
            borrow_request = return_request.borrowing
            
            # Check if fine already exists (defer fields that may not exist in DB)
            try:
                existing_fine = ReturnFine.objects.defer(
                    'late_return', 'damaged', 'lost'
                ).get(return_request=return_request)
                has_fine = True
            except ReturnFine.DoesNotExist:
                has_fine = False
            except Exception:
                # If there's any other error, assume no fine exists
                has_fine = False
            
            # Check if the return was late by comparing actual return date with expected return date
            if borrow_request.actual_return_date and borrow_request.expected_return_date:
                is_late = borrow_request.actual_return_date > borrow_request.expected_return_date
                
                if is_late:
                    # Calculate hours late
                    delta = borrow_request.actual_return_date - borrow_request.expected_return_date
                    total_seconds = delta.total_seconds()
                    hours_late = int(total_seconds / 3600)  # Convert to hours
                    
                    if hours_late > 0:
                        # Create or update fine
                        fine = ReturnService.get_or_create_return_fine(
                            return_request=return_request,
                            late_return=True,
                            damaged=False,
                            lost=False
                        )
                        
                        if fine:
                            if has_fine:
                                fines_updated += 1
                                logger.info(f"Updated fine for return request {return_request.id}: ${fine.fine_amount} ({hours_late} hours late)")
                            else:
                                fines_created += 1
                                logger.info(f"Created fine for return request {return_request.id}: ${fine.fine_amount} ({hours_late} hours late)")
                                
                                # Send notification to customer
                                NotificationService.create_notification(
                                    user_id=borrow_request.customer.id,
                                    title="Late Return Fine Applied",
                                    message=f"A fine of ${fine.fine_amount} has been applied for late return of '{borrow_request.book.name}'. Please pay the fine.",
                                    notification_type="return_fine_applied"
                                )
        
        return {
            'success': True,
            'returns_checked': returns_checked,
            'fines_created': fines_created,
            'fines_updated': fines_updated,
            'message': f'Checked {returns_checked} completed returns. Created {fines_created} new fines, updated {fines_updated} existing fines.'
        }
    
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
        return_date = timezone.now()
        borrow_request.actual_return_date = return_date
        borrow_request.final_return_date = return_date  # Set final_return_date for frontend display
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


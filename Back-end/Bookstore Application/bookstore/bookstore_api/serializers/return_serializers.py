from rest_framework import serializers
from django.db import transaction
import logging
from ..models.return_model import ReturnRequest, ReturnStatus, ReturnFine
from ..models.borrowing_model import BorrowRequest
from ..models.user_model import User
from .borrowing_serializers import BorrowRequestDetailSerializer


class ReturnRequestSerializer(serializers.ModelSerializer):
    """
    Serializer for ReturnRequest model
    Includes delivery_request for unified delivery status display
    """
    borrowing_id = serializers.IntegerField(source='borrowing.id', read_only=True)
    borrowing = BorrowRequestDetailSerializer(read_only=True)
    borrowing_book_name = serializers.CharField(source='borrowing.book.name', read_only=True)
    borrowing_customer_name = serializers.CharField(source='borrowing.customer.get_full_name', read_only=True)
    borrowing_customer_id = serializers.IntegerField(source='borrowing.customer.id', read_only=True)
    borrowing_customer_email = serializers.EmailField(source='borrowing.customer.email', read_only=True)
    borrowing_customer_phone = serializers.SerializerMethodField()
    borrowing_duration_days = serializers.IntegerField(source='borrowing.borrow_period_days', read_only=True)
    delivery_manager_name = serializers.CharField(source='delivery_manager.get_full_name', read_only=True, allow_null=True)
    delivery_manager_email = serializers.EmailField(source='delivery_manager.email', read_only=True, allow_null=True)
    delivery_manager_phone = serializers.SerializerMethodField()
    expected_return_date = serializers.DateTimeField(source='borrowing.expected_return_date', read_only=True)
    delivery_request = serializers.SerializerMethodField()  # Include delivery_request for unified status
    delivery_request_status = serializers.SerializerMethodField()  # Primary status source for unified delivery
    # Fine information
    fine_amount = serializers.SerializerMethodField()
    fine_status = serializers.SerializerMethodField()
    fine = serializers.SerializerMethodField()  # Complete fine object
    
    class Meta:
        model = ReturnRequest
        # Explicitly include all fields including SerializerMethodFields to ensure delivery_request_status is included
        fields = [
            'id', 'borrowing', 'borrowing_id', 'status', 'delivery_manager', 'accepted_at', 
            'picked_up_at', 'completed_at', 'created_at', 'updated_at',
            # Serializer fields
            'borrowing_book_name', 'borrowing_customer_name', 'borrowing_customer_id',
            'borrowing_customer_email', 'borrowing_customer_phone', 'borrowing_duration_days',
            'delivery_manager_name', 'delivery_manager_email', 'delivery_manager_phone',
            'expected_return_date', 'delivery_request', 'delivery_request_status',  # CRITICAL: delivery_request_status must be included
            'fine_amount', 'fine_status', 'fine'
        ]
        read_only_fields = ['created_at', 'updated_at']
    
    def get_delivery_request(self, obj):
        """
        Get delivery request information for return requests.
        Returns None if no delivery request exists.
        """
        from ..models.delivery_model import DeliveryRequest
        from ..serializers.delivery_serializers import AdminDeliveryRequestSerializer
        
        # Check if user is admin to determine which serializer to use
        request = self.context.get('request')
        if request and (request.user.is_library_admin() or request.user.is_delivery_admin()):
            # Admin: Use AdminDeliveryRequestSerializer with location data
            delivery_request = DeliveryRequest.objects.filter(
                return_request=obj,
                delivery_type='return'
            ).select_related(
                'delivery_manager',
                'delivery_manager__delivery_profile'
            ).first()
            
            if delivery_request:
                serializer = AdminDeliveryRequestSerializer(delivery_request)
                return serializer.data
        else:
            # Customer: Use CustomerDeliveryRequestSerializer
            from ..serializers.delivery_serializers import CustomerDeliveryRequestSerializer
            delivery_request = DeliveryRequest.objects.filter(
                return_request=obj,
                delivery_type='return'
            ).select_related(
                'delivery_manager',
                'delivery_manager__delivery_profile'
            ).first()
            
            if delivery_request:
                serializer = CustomerDeliveryRequestSerializer(delivery_request)
                return serializer.data
        
        return None
    
    def get_borrowing_customer_phone(self, obj):
        """Get phone number from customer's profile if available"""
        try:
            customer = obj.borrowing.customer
            # Try to access profile - it should be prefetched
            if hasattr(customer, 'profile'):
                profile = customer.profile
                if profile and hasattr(profile, 'phone_number'):
                    phone = profile.phone_number
                    if phone and phone.strip():  # Check if not empty
                        logger = logging.getLogger(__name__)
                        logger.debug(f"Found customer phone: {phone} for customer {customer.id}")
                        return phone.strip()
            # Fallback: try to access profile directly (in case it wasn't prefetched)
            try:
                profile = customer.profile
                if profile and profile.phone_number and profile.phone_number.strip():
                    logger = logging.getLogger(__name__)
                    logger.debug(f"Found customer phone (fallback): {profile.phone_number} for customer {customer.id}")
                    return profile.phone_number.strip()
            except Exception:
                pass
        except Exception as e:
            logger = logging.getLogger(__name__)
            logger.debug(f"Error getting customer phone: {str(e)}")
        # Return "not found" instead of None when phone number is not available
        return "not found"
    
    def get_delivery_manager_phone(self, obj):
        """Get phone number from delivery manager's profile if available"""
        try:
            if obj.delivery_manager:
                delivery_manager = obj.delivery_manager
                # Try to access profile directly (should be prefetched)
                try:
                    if hasattr(delivery_manager, 'profile') and delivery_manager.profile:
                        phone = delivery_manager.profile.phone_number
                        if phone and phone.strip():  # Check if not empty
                            return phone.strip()
                except AttributeError:
                    # Profile might not be prefetched, try to access it
                    try:
                        profile = delivery_manager.profile
                        if profile and profile.phone_number and profile.phone_number.strip():
                            return profile.phone_number.strip()
                    except Exception:
                        pass
        except Exception as e:
            logger = logging.getLogger(__name__)
            logger.debug(f"Error getting delivery manager phone: {str(e)}")
        # Return "not found" instead of None when phone number is not available
        return "not found"
    
    def get_delivery_request_status(self, obj):
        """
        Get the delivery request status for unified status display.
        This becomes the primary status source for customers and delivery managers.
        Uses raw SQL to bypass any ORM caching and get the absolute latest value from database.
        """
        from django.db import connection
        import logging
        logger = logging.getLogger(__name__)
        
        try:
            # 🔎 DEBUG: Check for duplicate DeliveryRequests first
            with connection.cursor() as cursor:
                cursor.execute(
                    "SELECT COUNT(*) FROM delivery_request "
                    "WHERE return_request_id = %s AND delivery_type = 'return'",
                    [obj.id]
                )
                count = cursor.fetchone()[0]
                if count > 1:
                    logger.warning(
                        f"🔴 DUPLICATE DETECTED: ReturnRequest {obj.id} has {count} DeliveryRequests! "
                        f"This is a serious bug."
                    )
                    # Get all DeliveryRequests for debugging
                    cursor.execute(
                        "SELECT id, status, delivery_manager_id, created_at FROM delivery_request "
                        "WHERE return_request_id = %s AND delivery_type = 'return' "
                        "ORDER BY id DESC",
                        [obj.id]
                    )
                    all_rows = cursor.fetchall()
                    for dr_id, dr_status, dr_manager_id, dr_created in all_rows:
                        logger.warning(
                            f"  DeliveryRequest {dr_id}: status='{dr_status}', "
                            f"delivery_manager_id={dr_manager_id}, created_at={dr_created}"
                        )
            
            # Use raw SQL to get the absolute latest status from database (bypasses all ORM caching)
            with connection.cursor() as cursor:
                cursor.execute(
                    "SELECT status, id FROM delivery_request "
                    "WHERE return_request_id = %s AND delivery_type = 'return' "
                    "ORDER BY id DESC LIMIT 1",
                    [obj.id]
                )
                row = cursor.fetchone()
                
                if row:
                    status = row[0]
                    delivery_req_id = row[1]
                    logger.info(
                        f"ReturnRequestSerializer.get_delivery_request_status (RAW SQL): "
                        f"ReturnRequest {obj.id} -> DeliveryRequest {delivery_req_id} "
                        f"status='{status}'"
                    )
                    return status
                else:
                    logger.debug(
                        f"ReturnRequestSerializer.get_delivery_request_status (RAW SQL): "
                        f"No DeliveryRequest found for ReturnRequest {obj.id}"
                    )
        except Exception as e:
            logger.error(
                f"ReturnRequestSerializer.get_delivery_request_status (RAW SQL): "
                f"Error for ReturnRequest {obj.id}: {e}",
                exc_info=True
            )
        
        return None
    
    def get_fine_amount(self, obj):
        """Get the fine amount for this return request if it exists."""
        from django.db import connection
        try:
            # Query fine using raw SQL to avoid model field issues
            with connection.cursor() as cursor:
                cursor.execute("""
                    SELECT fine_amount FROM return_fine 
                    WHERE return_request_id = %s
                """, [obj.id])
                row = cursor.fetchone()
                if row and row[0]:
                    return float(row[0])
            return None
        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.error(f"Error getting fine amount for ReturnRequest {obj.id}: {str(e)}")
            return None
    
    def get_fine_status(self, obj):
        """Get the fine payment status for this return request if it exists."""
        from django.db import connection
        try:
            # Query fine using raw SQL to avoid model field issues
            with connection.cursor() as cursor:
                cursor.execute("""
                    SELECT is_paid FROM return_fine 
                    WHERE return_request_id = %s
                """, [obj.id])
                row = cursor.fetchone()
                if row is not None:
                    return 'paid' if row[0] else 'unpaid'
            return None
        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.error(f"Error getting fine status for ReturnRequest {obj.id}: {str(e)}")
            return None
    
    def get_fine(self, obj):
        """Get complete fine information for this return request if it exists."""
        from django.db import connection
        try:
            # Query fine using raw SQL to get all relevant fields
            # Note: payment_status doesn't exist in the database - derive it from is_paid
            with connection.cursor() as cursor:
                cursor.execute("""
                    SELECT id, fine_amount, days_late, payment_method, 
                           is_paid, fine_reason, is_finalized
                    FROM return_fine 
                    WHERE return_request_id = %s
                """, [obj.id])
                row = cursor.fetchone()
                if row:
                    is_paid = bool(row[4]) if row[4] is not None else False
                    return {
                        'id': row[0],
                        'fine_amount': float(row[1]) if row[1] else 0.0,
                        'days_late': row[2] if row[2] else 0,
                        'payment_method': row[3],
                        'payment_status': 'paid' if is_paid else 'pending',
                        'is_paid': is_paid,
                        'fine_reason': row[5],
                        'is_finalized': bool(row[6]) if row[6] is not None else False
                    }
            return None
        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.error(f"Error getting fine details for ReturnRequest {obj.id}: {str(e)}")
            return None


class ReturnRequestCreateSerializer(serializers.ModelSerializer):
    """
    Serializer for creating a return request
    """
    borrowing_id = serializers.IntegerField(write_only=True)
    
    class Meta:
        model = ReturnRequest
        fields = ['borrowing_id', 'status']
        read_only_fields = ['status', 'created_at', 'updated_at']
    
    def validate_borrowing_id(self, value):
        """Validate that borrowing exists and can have a return request"""
        try:
            borrowing = BorrowRequest.objects.get(id=value)
        except BorrowRequest.DoesNotExist:
            raise serializers.ValidationError("Borrowing request not found")
        
        # Check if borrowing is in a valid state for return request
        from ..models.borrowing_model import BorrowStatusChoices
        
        # Allow return requests for:
        # 1. ACTIVE or EXTENDED status (normal case)
        # 2. DELIVERED status (books that have been delivered can always be returned)
        is_valid_status = borrowing.status in [
            BorrowStatusChoices.ACTIVE, 
            BorrowStatusChoices.EXTENDED,
            BorrowStatusChoices.DELIVERED
        ]
        
        if not is_valid_status:
            raise serializers.ValidationError("Borrowing must be active, extended, or delivered to request return")
        
        # Check if there's already a pending return request
        existing_request = ReturnRequest.objects.filter(
            borrowing=borrowing,
            status__in=[ReturnStatus.PENDING, ReturnStatus.APPROVED, ReturnStatus.ASSIGNED]
        ).exists()
        
        if existing_request:
            raise serializers.ValidationError("A return request already exists for this borrowing")
        
        return value
    
    @transaction.atomic
    def create(self, validated_data):
        borrowing_id = validated_data.pop('borrowing_id')
        borrowing = BorrowRequest.objects.select_for_update().get(id=borrowing_id)
        
        return_request = ReturnRequest.objects.create(
            borrowing=borrowing,
            status=ReturnStatus.PENDING,
            **validated_data
        )
        
        # Update borrowing status to indicate return has been requested
        from ..models.borrowing_model import BorrowStatusChoices
        borrowing.status = BorrowStatusChoices.RETURN_REQUESTED
        borrowing.save(update_fields=['status', 'updated_at'])
        
        return return_request


class ReturnRequestApprovalSerializer(serializers.Serializer):
    """
    Serializer for approving a return request
    """
    pass


class ReturnRequestAssignSerializer(serializers.Serializer):
    """
    Serializer for assigning a delivery manager to a return request
    """
    delivery_manager_id = serializers.IntegerField()
    
    def validate_delivery_manager_id(self, value):
        """Validate that delivery manager exists and is active"""
        try:
            delivery_manager = User.objects.get(
                id=value,
                user_type='delivery_admin',
                is_active=True
            )
        except User.DoesNotExist:
            raise serializers.ValidationError("Delivery manager not found or inactive")
        
        return value


class ReturnFineSerializer(serializers.ModelSerializer):
    """
    Serializer for ReturnFine model - represents fines for return requests only.
    """
    borrow_request = serializers.SerializerMethodField()
    total_amount = serializers.DecimalField(source='fine_amount', max_digits=8, decimal_places=2, read_only=True)
    status = serializers.SerializerMethodField()
    status_display = serializers.SerializerMethodField()
    created_date = serializers.DateTimeField(source='created_at', read_only=True)
    paid_date = serializers.DateTimeField(source='paid_at', read_only=True)
    payment_reference = serializers.CharField(source='transaction_id', read_only=True)
    
    class Meta:
        model = ReturnFine
        fields = [
            'id', 'return_request', 'borrow_request', 'fine_amount', 'total_amount',
            'fine_reason', 'late_return', 'damaged', 'lost', 'days_late',
            'is_paid', 'status', 'status_display', 'created_date', 'paid_date',
            'payment_reference', 'payment_method', 'is_finalized'
        ]
        read_only_fields = ['created_at', 'updated_at']
    
    def get_borrow_request(self, obj):
        """Return borrowing information from the return request"""
        from .borrowing_serializers import BorrowRequestListSerializer
        if obj.return_request and obj.return_request.borrowing:
            return BorrowRequestListSerializer(obj.return_request.borrowing).data
        return None
    
    def get_status(self, obj):
        """Return payment status as string for backward compatibility"""
        return 'paid' if obj.is_paid else 'pending'
    
    def get_status_display(self, obj):
        """Return human-readable payment status"""
        return 'Paid' if obj.is_paid else 'Pending'


from rest_framework import serializers
import logging
from ..models.return_model import ReturnRequest, ReturnStatus, ReturnFine
from ..models.borrowing_model import BorrowRequest
from ..models.user_model import User
from .borrowing_serializers import BorrowRequestDetailSerializer


class ReturnRequestSerializer(serializers.ModelSerializer):
    """
    Serializer for ReturnRequest model
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
    
    class Meta:
        model = ReturnRequest
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at']
    
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
        from django.utils import timezone
        
        # Allow return requests for:
        # 1. ACTIVE or EXTENDED status (normal case)
        # 2. DELIVERED status if the book is overdue (overdue case)
        is_valid_status = borrowing.status in [
            BorrowStatusChoices.ACTIVE, 
            BorrowStatusChoices.EXTENDED
        ]
        
        # If status is DELIVERED, check if book is overdue
        is_overdue_delivered = False
        if borrowing.status == BorrowStatusChoices.DELIVERED:
            if borrowing.expected_return_date:
                is_overdue_delivered = timezone.now() > borrowing.expected_return_date
        
        if not is_valid_status and not is_overdue_delivered:
            raise serializers.ValidationError("Borrowing must be active, extended, or delivered and overdue to request return")
        
        # Check if there's already a pending return request
        existing_request = ReturnRequest.objects.filter(
            borrowing=borrowing,
            status__in=[ReturnStatus.PENDING, ReturnStatus.APPROVED, ReturnStatus.ASSIGNED]
        ).exists()
        
        if existing_request:
            raise serializers.ValidationError("A return request already exists for this borrowing")
        
        return value
    
    def create(self, validated_data):
        borrowing_id = validated_data.pop('borrowing_id')
        borrowing = BorrowRequest.objects.get(id=borrowing_id)
        
        return_request = ReturnRequest.objects.create(
            borrowing=borrowing,
            status=ReturnStatus.PENDING,
            **validated_data
        )
        
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


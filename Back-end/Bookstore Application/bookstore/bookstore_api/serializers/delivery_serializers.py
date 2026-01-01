from rest_framework import serializers
from django.db import transaction
from decimal import Decimal
from ..models import DeliveryRequest, Order, OrderItem, User, Cart, CartItem, Book
from ..models.borrowing_model import BorrowRequest
from ..models.return_model import ReturnRequest
from ..models.payment_model import Payment


class DeliveryRequestListSerializer(serializers.ModelSerializer):
    """
    Serializer for viewing delivery requests in list format.
    Includes all necessary information for display.
    """
    delivery_type_display = serializers.CharField(source='get_delivery_type_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    customer_name = serializers.CharField(source='customer.get_full_name', read_only=True)
    customer_phone = serializers.SerializerMethodField()
    customer_email = serializers.CharField(source='customer.email', read_only=True)
    delivery_manager_name = serializers.SerializerMethodField()
    order_number = serializers.SerializerMethodField()
    order = serializers.SerializerMethodField()
    # Alias for frontend compatibility (frontend expects approved_at but backend uses accepted_at)
    approved_at = serializers.DateTimeField(source='accepted_at', read_only=True)
    
    class Meta:
        model = DeliveryRequest
        fields = [
            'id',
            'delivery_type',
            'delivery_type_display',
            'status',
            'status_display',
            'customer',
            'customer_name',
            'customer_phone',
            'customer_email',
            'delivery_manager',
            'delivery_manager_name',
            'order',
            'order_number',
            'delivery_address',
            'delivery_city',
            'latitude',
            'longitude',
            'rejection_reason',
            'assigned_at',
            'accepted_at',
            'approved_at',  # Alias for frontend compatibility
            'rejected_at',
            'started_at',
            'start_notes',
            'completed_at',
            'created_at',
            'updated_at',
        ]
        read_only_fields = [
            'id',
            'created_at',
            'updated_at',
            'assigned_at',
            'accepted_at',
            'rejected_at',
            'started_at',
            'completed_at',
        ]
    
    def get_customer_phone(self, obj):
        """Get customer phone number from profile if available."""
        if hasattr(obj.customer, 'userprofile'):
            return obj.customer.userprofile.phone_number
        return None
    
    def get_delivery_manager_name(self, obj):
        """Get delivery manager full name."""
        if obj.delivery_manager:
            return obj.delivery_manager.get_full_name()
        return None
    
    def get_order_number(self, obj):
        """Get order number for purchase deliveries."""
        if obj.delivery_type == 'purchase' and obj.order:
            return obj.order.order_number
        return None
    
    def get_order(self, obj):
        """Get order details for purchase deliveries."""
        if obj.delivery_type == 'purchase' and obj.order:
            return {
                'id': obj.order.id,
                'order_number': obj.order.order_number,
                'total_amount': str(obj.order.total_amount),
            }
        return None


class DeliveryRequestDetailSerializer(DeliveryRequestListSerializer):
    """
    Detailed serializer for delivery requests.
    Includes full related entity information.
    """
    related_entity = serializers.SerializerMethodField()
    
    class Meta(DeliveryRequestListSerializer.Meta):
        fields = DeliveryRequestListSerializer.Meta.fields + ['related_entity']
    
    def get_related_entity(self, obj):
        """Get full details of the related entity based on delivery_type."""
        if obj.delivery_type == 'purchase' and obj.order:
            return {
                'type': 'order',
                'id': obj.order.id,
                'order_number': obj.order.order_number,
                'total_amount': str(obj.order.total_amount),
                'status': obj.order.status,
            }
        elif obj.delivery_type == 'borrow' and obj.borrow_request:
            return {
                'type': 'borrow_request',
                'id': obj.borrow_request.id,
                'book_name': obj.borrow_request.book.name if obj.borrow_request.book else None,
                'status': obj.borrow_request.status,
            }
        elif obj.delivery_type == 'return' and obj.return_request:
            return {
                'type': 'return_request',
                'id': obj.return_request.id,
                'borrowing_id': obj.return_request.borrowing.id if obj.return_request.borrowing else None,
                'status': obj.return_request.status,
            }
        return None


class AcceptDeliveryRequestSerializer(serializers.Serializer):
    """
    Serializer for accepting a delivery request.
    No additional fields needed - just validates the request can be accepted.
    """
    pass


class RejectDeliveryRequestSerializer(serializers.Serializer):
    """
    Serializer for rejecting a delivery request.
    Requires a rejection reason.
    """
    rejection_reason = serializers.CharField(
        required=True,
        allow_blank=False,
        max_length=500,
        help_text="Reason for rejecting the delivery request"
    )
    
    def validate_rejection_reason(self, value):
        """Validate that rejection reason is not empty."""
        if not value or not value.strip():
            raise serializers.ValidationError("Rejection reason is required.")
        return value.strip()


class StartDeliverySerializer(serializers.Serializer):
    """
    Serializer for starting delivery.
    Optional notes field for delivery start.
    """
    notes = serializers.CharField(
        required=False,
        allow_blank=True,
        max_length=1000,
        help_text="Optional notes about the delivery start"
    )


class UpdateLocationSerializer(serializers.Serializer):
    """
    Serializer for updating delivery manager location (GPS).
    """
    latitude = serializers.DecimalField(
        required=True,
        max_digits=10,
        decimal_places=7,
        help_text="Latitude coordinate"
    )
    
    longitude = serializers.DecimalField(
        required=True,
        max_digits=10,
        decimal_places=7,
        help_text="Longitude coordinate"
    )
    
    def validate_latitude(self, value):
        """Validate latitude is within valid range."""
        if value < -90 or value > 90:
            raise serializers.ValidationError("Latitude must be between -90 and 90.")
        return value
    
    def validate_longitude(self, value):
        """Validate longitude is within valid range."""
        if value < -180 or value > 180:
            raise serializers.ValidationError("Longitude must be between -180 and 180.")
        return value


class CompleteDeliverySerializer(serializers.Serializer):
    """
    Serializer for completing delivery.
    Optional notes field for delivery completion.
    """
    notes = serializers.CharField(
        required=False,
        allow_blank=True,
        max_length=1000,
        help_text="Optional notes about the delivery completion"
    )


class DeliveryNotesSerializer(serializers.Serializer):
    """
    Serializer for adding or updating delivery notes.
    """
    notes = serializers.CharField(
        required=True,
        allow_blank=False,
        max_length=1000,
        help_text="Notes about the delivery"
    )
    
    def validate_notes(self, value):
        """Validate that notes are not empty."""
        if not value or not value.strip():
            raise serializers.ValidationError("Notes cannot be empty.")
        return value.strip()


class BorrowingOrderSerializer(serializers.ModelSerializer):
    """
    Serializer for borrowing delivery orders.
    Used by delivery managers to view borrowing orders.
    """
    customer_name = serializers.CharField(source='customer.get_full_name', read_only=True)
    customer_email = serializers.CharField(source='customer.email', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    borrow_request_id = serializers.SerializerMethodField()
    borrow_request_status = serializers.SerializerMethodField()
    book_name = serializers.SerializerMethodField()
    delivery_address = serializers.SerializerMethodField()
    
    class Meta:
        model = Order
        fields = [
            'id',
            'order_number',
            'customer',
            'customer_name',
            'customer_email',
            'status',
            'status_display',
            'order_type',
            'total_amount',
            'delivery_cost',
            'tax_amount',
            'discount_amount',
            'delivery_address',
            'billing_address',
            'notes',
            'cancellation_reason',
            'created_at',
            'updated_at',
            'borrow_request_id',
            'borrow_request_status',
            'book_name',
            'delivery_address',
        ]
        read_only_fields = [
            'id',
            'order_number',
            'created_at',
            'updated_at',
        ]
    
    def get_borrow_request_id(self, obj):
        """Get the associated borrow request ID if available."""
        # Try to get borrow_request through reverse relation
        if hasattr(obj, 'borrow_request'):
            return obj.borrow_request.id
        # Or try through order items or other relations
        return None
    
    def get_borrow_request_status(self, obj):
        """Get the status of the associated borrow request."""
        if hasattr(obj, 'borrow_request') and obj.borrow_request:
            return obj.borrow_request.status
        return None
    
    def get_book_name(self, obj):
        """Get the book name from the associated borrow request."""
        if hasattr(obj, 'borrow_request') and obj.borrow_request and obj.borrow_request.book:
            return obj.borrow_request.book.name
        return None
    
    def get_delivery_address(self, obj):
        """Get delivery address from delivery_address or borrow_request."""
        if obj.delivery_address:
            return obj.delivery_address
        if hasattr(obj, 'borrow_request') and obj.borrow_request:
            return obj.borrow_request.delivery_address
        return None


class CartItemSerializer(serializers.Serializer):
    """
    Serializer for individual cart item in checkout.
    """
    book_id = serializers.IntegerField(min_value=1, help_text="Book ID")
    quantity = serializers.IntegerField(min_value=1, help_text="Quantity")


class OrderCreateSerializer(serializers.Serializer):
    """
    Serializer for creating orders from cart checkout.
    Backend calculates total_price from book prices for security.
    """
    cart_items = serializers.ListField(
        child=CartItemSerializer(),
        allow_empty=False,
        min_length=1,
        help_text="List of cart items with book_id and quantity"
    )
    total_price = serializers.DecimalField(
        max_digits=12,
        decimal_places=2,
        required=False,
        help_text="Total order price (optional, calculated server-side)"
    )
    address = serializers.CharField(
        required=False,
        allow_blank=True,
        help_text="Delivery address"
    )
    payment_method = serializers.ChoiceField(
        choices=['mastercard', 'cash_on_delivery', 'cash'],
        help_text="Payment method"
    )
    delivery_notes = serializers.CharField(
        required=False,
        allow_blank=True,
        help_text="Delivery notes"
    )
    card_details = serializers.DictField(
        required=False,
        allow_null=True,
        help_text="Card details for mastercard payment"
    )
    
    def validate_cart_items(self, value):
        """Validate that cart items have valid book_id and quantity."""
        if not value:
            raise serializers.ValidationError("At least one cart item is required.")
        
        # Check for duplicate book_ids
        book_ids = [item['book_id'] for item in value]
        if len(book_ids) != len(set(book_ids)):
            raise serializers.ValidationError("Duplicate book_id found in cart items.")
        
        return value
    
    def validate_payment_method(self, value):
        """Normalize payment method - convert 'cash' to 'cash_on_delivery'."""
        if value == 'cash':
            return 'cash_on_delivery'
        return value


class CustomerOrderSerializer(serializers.ModelSerializer):
    """
    Serializer for customer orders (both purchase and borrowing).
    Used by customers to view their orders.
    """
    customer_name = serializers.CharField(source='customer.get_full_name', read_only=True)
    customer_email = serializers.CharField(source='customer.email', read_only=True)
    customer_phone = serializers.SerializerMethodField()
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    order_type_display = serializers.CharField(source='get_order_type_display', read_only=True)
    payment_method = serializers.SerializerMethodField()
    payment_info = serializers.SerializerMethodField()
    payment = serializers.SerializerMethodField()
    total_quantity = serializers.SerializerMethodField()
    delivery_assignment = serializers.SerializerMethodField()
    items = serializers.SerializerMethodField()
    
    class Meta:
        model = Order
        fields = [
            'id',
            'order_number',
            'customer',
            'customer_name',
            'customer_email',
            'customer_phone',
            'status',
            'status_display',
            'order_type',
            'order_type_display',
            'total_amount',
            'delivery_cost',
            'tax_amount',
            'discount_amount',
            'delivery_address',
            'billing_address',
            'notes',
            'cancellation_reason',
            'created_at',
            'updated_at',
            'items',
            'payment',
            'payment_method',
            'payment_info',
            'total_quantity',
            'delivery_assignment',
        ]
        read_only_fields = [
            'id',
            'order_number',
            'created_at',
            'updated_at',
        ]
    
    def get_customer_phone(self, obj):
        """Get customer phone number from profile."""
        try:
            if hasattr(obj.customer, 'profile') and obj.customer.profile:
                return obj.customer.profile.phone_number
        except Exception:
            pass
        return None
    
    def get_payment_method(self, obj):
        """Get payment method from payment."""
        if obj.payment:
            return obj.payment.payment_type
        return None
    
    def get_payment_info(self, obj):
        """Get payment information as a dict."""
        if obj.payment:
            return {
                'id': obj.payment.id,
                'payment_id': obj.payment.payment_id,
                'payment_method': obj.payment.payment_type,
                'payment_type': obj.payment.payment_type,
                'status': obj.payment.status,
                'amount': str(obj.payment.amount),
                'created_at': obj.payment.created_at.isoformat() if obj.payment.created_at else None,
            }
        return None
    
    def get_payment(self, obj):
        """Get payment object (for compatibility with frontend)."""
        if obj.payment:
            return {
                'id': obj.payment.id,
                'payment_id': obj.payment.payment_id,
                'payment_type': obj.payment.payment_type,
                'payment_method': obj.payment.payment_type,  # Alias for frontend
                'status': obj.payment.status,
                'amount': str(obj.payment.amount),
                'created_at': obj.payment.created_at.isoformat() if obj.payment.created_at else None,
            }
        return None
    
    def get_total_quantity(self, obj):
        """Calculate total quantity of items in the order."""
        if hasattr(obj, 'items'):
            return sum(item.quantity for item in obj.items.all())
        return 0
    
    def get_delivery_assignment(self, obj):
        """Get delivery assignment information from delivery request."""
        try:
            from ..models import DeliveryRequest
            # Get the delivery request associated with this order
            delivery_request = DeliveryRequest.objects.filter(
                order=obj,
                delivery_type='purchase'
            ).first()
            
            if delivery_request and delivery_request.delivery_manager:
                manager = delivery_request.delivery_manager
                # Get phone from profile if available
                phone = None
                try:
                    if hasattr(manager, 'profile') and manager.profile:
                        phone = manager.profile.phone_number
                except Exception:
                    pass
                
                return {
                    'id': str(delivery_request.id),  # Delivery request ID
                    'order': str(obj.id),  # Order ID
                    'delivery_manager': {
                        'id': manager.id,
                        'name': manager.get_full_name(),
                        'full_name': manager.get_full_name(),
                        'email': manager.email,
                        'phone': phone,
                    },
                    'delivery_manager_id': str(manager.id),
                    'delivery_manager_name': manager.get_full_name(),
                    'delivery_manager_phone': phone,
                    'delivery_manager_email': manager.email,
                    'status': delivery_request.status,
                    'assigned_at': delivery_request.assigned_at.isoformat() if delivery_request.assigned_at else None,
                    'started_at': delivery_request.started_at.isoformat() if delivery_request.started_at else None,
                    'completed_at': delivery_request.completed_at.isoformat() if delivery_request.completed_at else None,
                    'assigned_by_name': None,  # Can be added if tracking who assigned is needed
                }
        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.warning(f"Error getting delivery assignment: {str(e)}")
        return None
    
    def get_items(self, obj):
        """Get order items as a simple list."""
        if hasattr(obj, 'items'):
            return [
                {
                    'id': item.id,
                    'book_id': item.book.id if item.book else None,
                    'book_title': item.book.name if item.book else 'Unknown',
                    'quantity': item.quantity,
                    'price': str(item.price),
                    'total_price': str(item.total_price),
                }
                for item in obj.items.all()
            ]
        return []


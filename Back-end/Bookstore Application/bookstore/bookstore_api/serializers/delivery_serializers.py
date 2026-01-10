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
    delivery_manager_availability = serializers.SerializerMethodField()
    delivery_manager_latitude = serializers.SerializerMethodField()
    delivery_manager_longitude = serializers.SerializerMethodField()
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
            'delivery_manager_availability',
            'delivery_manager_latitude',
            'delivery_manager_longitude',
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
    
    def get_delivery_manager_availability(self, obj):
        """Get delivery manager's current availability status (simplified for frontend)."""
        if not obj.delivery_manager:
            return None
        
        try:
            # Access delivery_profile - should be loaded via select_related in views
            # For OneToOne relationships, if it doesn't exist, it will be None (not raise exception)
            # when using select_related, or raise DoesNotExist when accessed directly
            profile = getattr(obj.delivery_manager, 'delivery_profile', None)
            if profile is not None:
                return profile.delivery_status or 'offline'
        except Exception as e:
            # Log exceptions for debugging (DoesNotExist, AttributeError, etc.)
            import logging
            logger = logging.getLogger(__name__)
            logger.debug(f"Error getting delivery manager availability for delivery {obj.id}: {str(e)}")
        
        # Return default if no profile exists
        return 'offline'
    
    def get_delivery_manager_latitude(self, obj):
        """Get delivery manager's latitude coordinate."""
        if not obj.delivery_manager:
            return None
        
        try:
            # Access delivery_profile - should be loaded via select_related in views
            profile = getattr(obj.delivery_manager, 'delivery_profile', None)
            if profile is not None:
                return profile.latitude
        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.debug(f"Error getting delivery manager latitude for delivery {obj.id}: {str(e)}")
        
        return None
    
    def get_delivery_manager_longitude(self, obj):
        """Get delivery manager's longitude coordinate."""
        if not obj.delivery_manager:
            return None
        
        try:
            # Access delivery_profile - should be loaded via select_related in views
            profile = getattr(obj.delivery_manager, 'delivery_profile', None)
            if profile is not None:
                return profile.longitude
        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.debug(f"Error getting delivery manager longitude for delivery {obj.id}: {str(e)}")
        
        return None
    
    def get_order_number(self, obj):
        """Get order number for purchase deliveries."""
        if obj.delivery_type == 'purchase' and obj.order:
            return obj.order.order_number
        return None
    
    def get_order(self, obj):
        """Get order details for purchase deliveries."""
        if obj.delivery_type == 'purchase' and obj.order:
            order = obj.order
            # Get payment information
            payment_method = None
            payment_status = None
            if order.payment:
                try:
                    payment = Payment.objects.get(id=order.payment.id)
                    payment_method = payment.payment_type
                    payment_status = payment.status
                except Payment.DoesNotExist:
                    pass
            
            return {
                'id': order.id,
                'order_number': order.order_number,
                'total_amount': str(order.total_amount),
                'payment_method': payment_method,
                'payment_status': payment_status,
            }
        return None


class DeliveryRequestDetailSerializer(DeliveryRequestListSerializer):
    """
    Detailed serializer for delivery requests.
    Includes full related entity information and delivery manager availability status.
    Note: delivery_manager_availability, delivery_manager_latitude, and delivery_manager_longitude
    are already included from DeliveryRequestListSerializer.
    """
    related_entity = serializers.SerializerMethodField()
    # delivery_manager_availability is already in parent class, but we can override if needed
    delivery_manager_availability_detail = serializers.SerializerMethodField()
    
    class Meta(DeliveryRequestListSerializer.Meta):
        fields = DeliveryRequestListSerializer.Meta.fields + ['related_entity', 'delivery_manager_availability_detail']
    
    def get_related_entity(self, obj):
        """Get full details of the related entity based on delivery_type."""
        if obj.delivery_type == 'purchase' and obj.order:
            order = obj.order
            # Get payment information
            payment_method = None
            payment_status = None
            if order.payment:
                try:
                    payment = Payment.objects.get(id=order.payment.id)
                    payment_method = payment.payment_type
                    payment_status = payment.status
                except Payment.DoesNotExist:
                    pass
            
            return {
                'type': 'order',
                'id': order.id,
                'order_number': order.order_number,
                'total_amount': str(order.total_amount),
                'status': order.status,
                'payment_method': payment_method,
                'payment_status': payment_status,
            }
        elif obj.delivery_type == 'borrow' and obj.borrow_request:
            borrow_request = obj.borrow_request
            # Get fine and deposit information
            # Calculate payment_status: if delivery is completed and payment is cash, status is 'completed'
            payment_status = None
            if borrow_request.payment_method in ['cash', 'cash_on_delivery']:
                # Check if delivery is completed (delivery_request status is 'completed')
                if obj.status == 'completed':
                    payment_status = 'completed'  # Will display as "Paid" in frontend
                else:
                    payment_status = 'pending'
            elif borrow_request.payment_method == 'mastercard':
                # For card payments, check if deposit is paid
                if borrow_request.deposit_paid:
                    payment_status = 'completed'
                else:
                    payment_status = 'pending'
            
            return {
                'type': 'borrow_request',
                'id': borrow_request.id,
                'book_name': borrow_request.book.name if borrow_request.book else None,
                'status': borrow_request.status,
                'payment_method': borrow_request.payment_method,
                'payment_status': payment_status,
                'fine_amount': str(borrow_request.fine_amount) if borrow_request.fine_amount else None,
                'fine_status': borrow_request.fine_status,
                'deposit_amount': str(borrow_request.deposit_amount) if borrow_request.deposit_amount else None,
                'deposit_paid': borrow_request.deposit_paid,
                'deposit_refunded': borrow_request.deposit_refunded,
                'refund_amount': str(borrow_request.refund_amount) if borrow_request.refund_amount else None,
            }
        elif obj.delivery_type == 'return' and obj.return_request:
            return_request = obj.return_request
            # Get fine information from ReturnFine
            fine_amount = None
            fine_status = None
            fine_payment_method = None
            fine_is_paid = None
            
            if hasattr(return_request, 'fine') and return_request.fine:
                fine = return_request.fine
                fine_amount = str(fine.fine_amount)
                fine_is_paid = fine.is_paid
                fine_status = 'paid' if fine.is_paid else 'unpaid'
                fine_payment_method = fine.payment_method
            
            return {
                'type': 'return_request',
                'id': return_request.id,
                'borrowing_id': return_request.borrowing.id if return_request.borrowing else None,
                'status': return_request.status,
                'fine_amount': fine_amount,
                'fine_status': fine_status,
                'fine_payment_method': fine_payment_method,
                'fine_is_paid': fine_is_paid,
            }
        return None
    
    def get_delivery_manager_availability_detail(self, obj):
        """Get delivery manager's detailed availability status (for backward compatibility)."""
        if obj.delivery_manager:
            try:
                # Get delivery profile if it exists
                if hasattr(obj.delivery_manager, 'delivery_profile') and obj.delivery_manager.delivery_profile:
                    profile = obj.delivery_manager.delivery_profile
                    return {
                        'status': profile.delivery_status or 'offline',
                        'status_display': profile.get_delivery_status_display(),
                        'can_change_manually': True,  # Managers can always change between online/offline
                    }
            except Exception:
                pass
            # Return default if no profile exists
            return {
                'status': 'offline',
                'status_display': 'Offline - Unavailable',
                'can_change_manually': True,
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


class CustomerDeliveryRequestSerializer(serializers.ModelSerializer):
    """
    Customer-facing serializer for DeliveryRequest.
    Only shows status, delivery manager name, and location (only when in_delivery).
    This protects privacy and prevents unnecessary tracking.
    """
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    delivery_manager_name = serializers.SerializerMethodField()
    latitude = serializers.SerializerMethodField()
    longitude = serializers.SerializerMethodField()
    
    class Meta:
        model = DeliveryRequest
        fields = [
            'id',
            'status',
            'status_display',
            'delivery_manager_name',
            'latitude',
            'longitude',
        ]
        read_only_fields = fields
    
    def get_delivery_manager_name(self, obj):
        """Get delivery manager full name."""
        if obj.delivery_manager:
            return obj.delivery_manager.get_full_name()
        return None
    
    def get_latitude(self, obj):
        """
        Return latitude when status >= 'assigned' (assigned, accepted, in_delivery, completed).
        This allows customers to track delivery manager location after assignment.
        """
        # Status hierarchy: pending < assigned < accepted < in_delivery < completed
        status_hierarchy = ['pending', 'assigned', 'accepted', 'in_delivery', 'completed', 'rejected']
        current_status_index = status_hierarchy.index(obj.status) if obj.status in status_hierarchy else -1
        assigned_index = status_hierarchy.index('assigned')
        
        if current_status_index >= assigned_index:
            # Get location from delivery manager's profile if available
            if obj.delivery_manager:
                try:
                    profile = getattr(obj.delivery_manager, 'delivery_profile', None)
                    if profile is not None and profile.latitude is not None:
                        return float(profile.latitude)
                except Exception:
                    pass
            # Fallback to DeliveryRequest's own location if available
            if obj.latitude is not None:
                return float(obj.latitude)
        return None
    
    def get_longitude(self, obj):
        """
        Return longitude when status >= 'assigned' (assigned, accepted, in_delivery, completed).
        This allows customers to track delivery manager location after assignment.
        """
        # Status hierarchy: pending < assigned < accepted < in_delivery < completed
        status_hierarchy = ['pending', 'assigned', 'accepted', 'in_delivery', 'completed', 'rejected']
        current_status_index = status_hierarchy.index(obj.status) if obj.status in status_hierarchy else -1
        assigned_index = status_hierarchy.index('assigned')
        
        if current_status_index >= assigned_index:
            # Get location from delivery manager's profile if available
            if obj.delivery_manager:
                try:
                    profile = getattr(obj.delivery_manager, 'delivery_profile', None)
                    if profile is not None and profile.longitude is not None:
                        return float(profile.longitude)
                except Exception:
                    pass
            # Fallback to DeliveryRequest's own location if available
            if obj.longitude is not None:
                return float(obj.longitude)
        return None


class AdminDeliveryRequestSerializer(serializers.ModelSerializer):
    """
    Admin-facing serializer for DeliveryRequest.
    Includes full delivery information including location data (for admins only).
    This provides complete visibility for administrative purposes.
    """
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    delivery_manager_name = serializers.SerializerMethodField()
    delivery_manager_email = serializers.SerializerMethodField()
    delivery_manager_phone = serializers.SerializerMethodField()
    last_latitude = serializers.SerializerMethodField()
    last_longitude = serializers.SerializerMethodField()
    location_updated_at = serializers.SerializerMethodField()
    
    class Meta:
        model = DeliveryRequest
        fields = [
            'id',
            'status',
            'status_display',
            'delivery_manager',
            'delivery_manager_name',
            'delivery_manager_email',
            'delivery_manager_phone',
            'last_latitude',
            'last_longitude',
            'location_updated_at',
            'latitude',  # DeliveryRequest's own location
            'longitude',  # DeliveryRequest's own location
            'assigned_at',
            'accepted_at',
            'rejected_at',
            'started_at',
            'completed_at',
        ]
        read_only_fields = fields
    
    def get_delivery_manager_name(self, obj):
        """Get delivery manager full name."""
        if obj.delivery_manager:
            return obj.delivery_manager.get_full_name()
        return None
    
    def get_delivery_manager_email(self, obj):
        """Get delivery manager email."""
        if obj.delivery_manager:
            return obj.delivery_manager.email
        return None
    
    def get_delivery_manager_phone(self, obj):
        """Get delivery manager phone number."""
        if obj.delivery_manager:
            if hasattr(obj.delivery_manager, 'userprofile'):
                return obj.delivery_manager.userprofile.phone_number
            if hasattr(obj.delivery_manager, 'phone_number'):
                return obj.delivery_manager.phone_number
        return None
    
    def get_last_latitude(self, obj):
        """
        Get delivery manager's current location latitude (from profile).
        Only available for admins.
        """
        if obj.delivery_manager:
            try:
                profile = getattr(obj.delivery_manager, 'delivery_profile', None)
                if profile is not None and profile.latitude is not None:
                    return float(profile.latitude)
            except Exception:
                pass
        # Fallback to DeliveryRequest's own location if available
        if obj.latitude is not None:
            return float(obj.latitude)
        return None
    
    def get_last_longitude(self, obj):
        """
        Get delivery manager's current location longitude (from profile).
        Only available for admins.
        """
        if obj.delivery_manager:
            try:
                profile = getattr(obj.delivery_manager, 'delivery_profile', None)
                if profile is not None and profile.longitude is not None:
                    return float(profile.longitude)
            except Exception:
                pass
        # Fallback to DeliveryRequest's own location if available
        if obj.longitude is not None:
            return float(obj.longitude)
        return None
    
    def get_location_updated_at(self, obj):
        """
        Get when the delivery manager's location was last updated.
        """
        if obj.delivery_manager:
            try:
                profile = getattr(obj.delivery_manager, 'delivery_profile', None)
                if profile is not None and profile.location_updated_at:
                    return profile.location_updated_at
            except Exception:
                pass
        return None


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
    discount_code = serializers.CharField(
        required=False,
        allow_blank=True,
        allow_null=True,
        help_text="Discount code applied to the order"
    )
    discount_amount = serializers.DecimalField(
        max_digits=12,
        decimal_places=2,
        required=False,
        allow_null=True,
        help_text="Discount amount applied to the order"
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
    notes = serializers.SerializerMethodField()  # Override to return as list with author info
    discount_code = serializers.SerializerMethodField()  # Get discount code from payment
    discount_amount = serializers.SerializerMethodField()  # Get discount amount from order or DiscountUsage
    total_amount = serializers.SerializerMethodField()  # Calculate total amount dynamically
    
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
            'discount_code',
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
            # Refresh payment from database to ensure we have the latest data
            from ..models import Payment
            try:
                payment = Payment.objects.get(id=obj.payment.id)
                return payment.payment_type
            except Payment.DoesNotExist:
                return None
        return None
    
    def get_payment_info(self, obj):
        """Get payment information as a dict."""
        if obj.payment:
            # Refresh payment from database to ensure we have the latest status
            from ..models import Payment
            try:
                payment = Payment.objects.get(id=obj.payment.id)
                return {
                    'id': payment.id,
                    'payment_id': payment.payment_id,
                    'payment_method': payment.payment_type,
                    'payment_type': payment.payment_type,
                    'status': payment.status,
                    'amount': str(payment.amount),
                    'created_at': payment.created_at.isoformat() if payment.created_at else None,
                }
            except Payment.DoesNotExist:
                return None
        return None
    
    def get_payment(self, obj):
        """Get payment object (for compatibility with frontend)."""
        if obj.payment:
            # Refresh payment from database to ensure we have the latest status
            from ..models import Payment
            try:
                payment = Payment.objects.get(id=obj.payment.id)
                return {
                    'id': payment.id,
                    'payment_id': payment.payment_id,
                    'payment_type': payment.payment_type,
                    'payment_method': payment.payment_type,  # Alias for frontend
                    'status': payment.status,
                    'amount': str(payment.amount),
                    'created_at': payment.created_at.isoformat() if payment.created_at else None,
                }
            except Payment.DoesNotExist:
                return None
        return None
    
    def get_discount_code(self, obj):
        """Get discount code from payment if available, or from discount usage records."""
        # First try to get from payment
        if obj.payment and obj.payment.discount_code_used:
            return obj.payment.discount_code_used
        
        # Fallback: Always check DiscountUsage records (regardless of discount_amount)
        # This handles cases where discount was applied but amount wasn't saved correctly
        try:
            from ..models.discount_model import DiscountUsage
            # Use the related manager if available (more efficient)
            if hasattr(obj, 'discount_usages'):
                discount_usage = obj.discount_usages.filter(discount_code__isnull=False).first()
            else:
                discount_usage = DiscountUsage.objects.filter(
                    order=obj,
                    discount_code__isnull=False
                ).select_related('discount_code').first()
            
            if discount_usage and discount_usage.discount_code:
                return discount_usage.discount_code.code
        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.warning(f"Error getting discount code from DiscountUsage: {str(e)}")
        
        return None
    
    def get_discount_amount(self, obj):
        """Get discount amount from order, DiscountUsage records, or calculate from discount code."""
        # First, check if order has a non-zero discount_amount
        if obj.discount_amount and obj.discount_amount > 0:
            return float(obj.discount_amount)
        
        # If order discount_amount is 0 or None, check DiscountUsage records
        # This handles cases where discount was applied but amount wasn't saved to order
        try:
            from ..models.discount_model import DiscountUsage, DiscountCode
            from decimal import Decimal
            
            # Use the related manager if available (more efficient)
            if hasattr(obj, 'discount_usages'):
                discount_usage = obj.discount_usages.filter(discount_code__isnull=False).select_related('discount_code').first()
            else:
                discount_usage = DiscountUsage.objects.filter(
                    order=obj,
                    discount_code__isnull=False
                ).select_related('discount_code').first()
            
            if discount_usage and discount_usage.discount_amount:
                return float(discount_usage.discount_amount)
            
            # If DiscountUsage exists but amount is 0, try to calculate from discount code
            if discount_usage and discount_usage.discount_code:
                discount_code = discount_usage.discount_code
                # Calculate subtotal from order items
                subtotal = Decimal('0.00')
                if hasattr(obj, 'items'):
                    for item in obj.items.all():
                        if item.price and item.quantity:
                            subtotal += Decimal(str(item.price)) * Decimal(str(item.quantity))
                
                # If we have a subtotal, calculate discount
                if subtotal > 0:
                    discount_amount = discount_code.get_discount_amount(float(subtotal))
                    return float(discount_amount)
        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.warning(f"Error getting discount amount from DiscountUsage: {str(e)}")
        
        # Final fallback: Try to get discount code from payment and calculate
        try:
            from ..models.discount_model import DiscountCode
            from decimal import Decimal
            
            # Get discount code
            discount_code_str = None
            if obj.payment and obj.payment.discount_code_used:
                discount_code_str = obj.payment.discount_code_used
            elif hasattr(obj, 'discount_usages'):
                discount_usage = obj.discount_usages.filter(discount_code__isnull=False).select_related('discount_code').first()
                if discount_usage and discount_usage.discount_code:
                    discount_code_str = discount_usage.discount_code.code
            
            if discount_code_str:
                # Look up the discount code
                discount_code = DiscountCode.objects.filter(
                    code=discount_code_str,
                    is_active=True
                ).first()
                
                if discount_code:
                    # Calculate subtotal from order items
                    subtotal = Decimal('0.00')
                    if hasattr(obj, 'items'):
                        for item in obj.items.all():
                            if item.price and item.quantity:
                                subtotal += Decimal(str(item.price)) * Decimal(str(item.quantity))
                    
                    # Alternative: Calculate from total_amount + discount_amount (if we had it)
                    # Since discount_amount is 0, we can approximate: subtotal ≈ total_amount + delivery_cost + tax_amount
                    # But this might not be accurate if discount was already applied
                    # Better: calculate from items
                    if subtotal > 0:
                        discount_amount = discount_code.get_discount_amount(float(subtotal))
                        return float(discount_amount)
        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.warning(f"Error calculating discount amount from code: {str(e)}")
        
        # Final fallback: return order's discount_amount (which may be 0.00)
        return float(obj.discount_amount) if obj.discount_amount else 0.00
    
    def get_total_amount(self, obj):
        """Calculate total amount dynamically: subtotal - discount + delivery + tax."""
        from decimal import Decimal
        
        # Calculate subtotal from order items
        subtotal = Decimal('0.00')
        if hasattr(obj, 'items'):
            for item in obj.items.all():
                if item.price and item.quantity:
                    subtotal += Decimal(str(item.price)) * Decimal(str(item.quantity))
        
        # Get discount amount (using the method we already have)
        discount_amount = Decimal(str(self.get_discount_amount(obj)))
        
        # Get delivery cost and tax
        delivery_cost = Decimal(str(obj.delivery_cost)) if obj.delivery_cost else Decimal('0.00')
        tax_amount = Decimal(str(obj.tax_amount)) if obj.tax_amount else Decimal('0.00')
        
        # Calculate final total: subtotal - discount + delivery + tax
        final_total = subtotal - discount_amount + delivery_cost + tax_amount
        
        # Ensure total is not negative
        if final_total < Decimal('0.00'):
            final_total = Decimal('0.00')
        
        return float(final_total.quantize(Decimal('0.01')))
    
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
    
    def get_notes(self, obj):
        """
        Get notes as a list of OrderNote objects with author information.
        Notes are stored in format: "[Author Name (Type)]: Note content"
        We parse them and return as a list with proper author info.
        """
        if not obj.notes:
            return []
        
        notes_content = obj.notes.strip()
        if not notes_content:
            return []
        
        # Get request user for permission checks
        request = self.context.get('request')
        current_user = None
        if request and hasattr(request, 'user') and request.user.is_authenticated:
            current_user = request.user
        
        # Split notes by newline to handle multiple notes
        note_lines = [line.strip() for line in notes_content.split('\n') if line.strip()]
        notes_list = []
        
        for idx, note_line in enumerate(note_lines, start=1):
            # Parse note format: "[Author Name (Type)]: Note content"
            author_name = None
            author_type = None
            content = note_line
            
            if note_line.startswith('[') and ']:' in note_line:
                # Extract author info from format "[Name (Type)]: content"
                try:
                    bracket_end = note_line.index(']:')
                    author_part = note_line[1:bracket_end]  # Remove brackets
                    content = note_line[bracket_end + 2:].strip()  # Content after "]: "
                    
                    # Parse "Name (Type)"
                    if '(' in author_part and author_part.endswith(')'):
                        name_end = author_part.rindex('(')
                        author_name = author_part[:name_end].strip()
                        author_type_str = author_part[name_end + 1:-1].strip()
                        # Map display type back to user_type
                        type_mapping = {
                            'Customer': 'customer',
                            'Admin': 'library_admin',
                            'Delivery Manager': 'delivery_admin'
                        }
                        author_type = type_mapping.get(author_type_str, 'customer')
                    else:
                        author_name = author_part
                        author_type = 'customer'
                except (ValueError, IndexError):
                    # If parsing fails, treat entire line as content
                    content = note_line
                    author_name = obj.customer.get_full_name()
                    author_type = getattr(obj.customer, 'user_type', 'customer')
            else:
                # Legacy format or no author info - use order customer
                author_name = obj.customer.get_full_name()
                author_type = getattr(obj.customer, 'user_type', 'customer')
            
            # Determine permissions
            can_edit = False
            can_delete = False
            if current_user:
                # Admins can edit/delete any note
                if current_user.user_type in ['library_admin', 'delivery_admin']:
                    can_edit = True
                    can_delete = True
                # Users can edit/delete their own notes
                elif author_name == current_user.get_full_name() or author_type == getattr(current_user, 'user_type', None):
                    can_edit = True
                    can_delete = True
            
            note_data = {
                'id': idx,
                'content': content,
                'author': obj.customer.id,  # Fallback to customer ID
                'author_name': author_name,
                'author_email': obj.customer.email,  # Fallback to customer email
                'author_type': author_type,
                'can_edit': can_edit,
                'can_delete': can_delete,
                'created_at': obj.created_at.isoformat() if obj.created_at else None,
                'updated_at': obj.updated_at.isoformat() if obj.updated_at else None,
            }
            notes_list.append(note_data)
        
        return notes_list
    
    def get_items(self, obj):
        """Get order items as a simple list."""
        if hasattr(obj, 'items'):
            return [
                {
                    'id': item.id,
                    'book_id': item.book.id if item.book else None,
                    'book_title': item.book.name if item.book else 'Unknown',
                    'book_author': item.book.author.name if item.book and item.book.author else None,
                    'book_image': item.book.get_primary_image_url() if item.book else None,
                    'quantity': item.quantity,
                    'price': str(item.price),
                    'unit_price': str(item.price),  # Alias for frontend compatibility
                    'total_price': str(item.total_price),
                }
                for item in obj.items.all()
            ]
        return []


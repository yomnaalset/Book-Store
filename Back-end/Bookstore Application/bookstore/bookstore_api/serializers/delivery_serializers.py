from rest_framework import serializers
from django.utils import timezone
from django.db import transaction
from ..models import Order, OrderItem, DeliveryAssignment, DeliveryStatusHistory, User, Payment, Book
from ..models.delivery_model import DeliveryRequest, LocationHistory, RealTimeTracking
from .user_serializers import UserBasicInfoSerializer, UserDetailSerializer 
from .payment_serializers import PaymentBasicSerializer
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.shortcuts import get_object_or_404
from rest_framework import generics
from rest_framework import permissions
from django.core.exceptions import PermissionDenied
from django.db import models
from rest_framework.permissions import IsAdminUser
from ..permissions import IsLibraryAdminReadOnly


class OrderItemSerializer(serializers.ModelSerializer):
    """
    Serializer for order items with book information snapshot.
    """
    from bookstore_api.serializers.library_serializers import BookSerializer
    book = BookSerializer(read_only=True)
    book_title = serializers.CharField(source='book.name', read_only=True)
    book_author = serializers.CharField(source='book.author.name', read_only=True)
    
    class Meta:
        model = OrderItem
        fields = [
            'id', 'book', 'book_title', 'book_author',
            'quantity', 'unit_price', 'total_price'
        ]
        read_only_fields = ['id', 'book_title', 'book_author', 'total_price']


class OrderListSerializer(serializers.ModelSerializer):
    """
    Serializer for listing orders with basic information.
    """
    customer_name = serializers.CharField(source='customer.get_full_name', read_only=True)
    customer_email = serializers.CharField(source='customer.email', read_only=True)
    payment_type = serializers.CharField(source='payment.get_payment_type_display', read_only=True)
    payment_status = serializers.CharField(source='payment.get_status_display', read_only=True)
    total_items = serializers.IntegerField(source='get_total_items', read_only=True)
    total_quantity = serializers.IntegerField(source='get_total_quantity', read_only=True)
    has_delivery_assignment = serializers.SerializerMethodField()
    
    class Meta:
        model = Order
        fields = [
            'id', 'order_number', 'customer_name', 'customer_email',
            'total_amount', 'status', 'payment_method', 'payment_type', 'payment_status',
            'total_items', 'total_quantity', 'has_delivery_assignment',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'order_number', 'created_at', 'updated_at']
    
    def get_has_delivery_assignment(self, obj):
        """Check if order has a delivery assignment."""
        return hasattr(obj, 'delivery_assignment')


class OrderDetailSerializer(serializers.ModelSerializer):
    """
    Detailed serializer for orders with all related information.
    """
    customer = UserDetailSerializer(read_only=True)
    payment = PaymentBasicSerializer(read_only=True)
    items = OrderItemSerializer(many=True, read_only=True)
    delivery_assignment = serializers.SerializerMethodField()
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    total_items = serializers.IntegerField(source='get_total_items', read_only=True)
    total_quantity = serializers.IntegerField(source='get_total_quantity', read_only=True)
    can_be_cancelled = serializers.BooleanField(read_only=True)
    can_be_delivered = serializers.BooleanField(read_only=True)
    
    class Meta:
        model = Order
        fields = [
            'id', 'order_number', 'customer', 'payment', 'items',
            'total_amount', 'status', 'status_display', 'payment_method',
            'delivery_address', 'delivery_city', 'delivery_notes',
            'total_items', 'total_quantity', 'can_be_cancelled', 'can_be_delivered',
            'delivery_assignment', 'created_at', 'updated_at'
        ]
        read_only_fields = [
            'id', 'order_number', 'customer', 'payment', 'items',
            'total_amount', 'total_items', 'total_quantity',
            'can_be_cancelled', 'can_be_delivered', 'delivery_assignment',
            'created_at', 'updated_at'
        ]
    
    def get_delivery_assignment(self, obj):
        """Get delivery assignment if exists."""
        if hasattr(obj, 'delivery_assignment'):
            return DeliveryAssignmentBasicSerializer(obj.delivery_assignment).data
        return None


class OrderStatusUpdateSerializer(serializers.Serializer):
    """
    Serializer for updating order status.
    """
    STATUS_CHOICES = Order.ORDER_STATUS_CHOICES
    
    status = serializers.ChoiceField(choices=STATUS_CHOICES)
    notes = serializers.CharField(max_length=1000, required=False, allow_blank=True)
    
    def validate_status(self, value):
        """Validate status transition."""
        order = self.context.get('order')
        if not order:
            raise serializers.ValidationError("Order context is required.")
        
        current_status = order.status
        valid_transitions = {
            'pending': ['confirmed', 'pending_assignment'],
            'pending_assignment': ['confirmed', 'in_delivery'],
            'confirmed': ['in_delivery'],
            'in_delivery': ['delivered', 'returned'],
            'delivered': [],  # Final state
            'returned': [],   # Final state
        }
        
        if value not in valid_transitions.get(current_status, []):
            raise serializers.ValidationError(
                f"Cannot change status from '{current_status}' to '{value}'"
            )
        
        return value


class DeliveryAssignmentBasicSerializer(serializers.ModelSerializer):
    """
    Basic serializer for delivery assignments.
    """
    delivery_manager_name = serializers.CharField(source='delivery_person.get_full_name', read_only=True)
    order_number = serializers.CharField(source='order.order_number', read_only=True)

    class Meta:
        model = DeliveryAssignment
        fields = [
            'id', 'order_number', 'delivery_manager_name',
            'assigned_at', 'estimated_delivery_time'
        ]
        read_only_fields = ['id', 'assigned_at']


class DeliveryAssignmentDetailSerializer(serializers.ModelSerializer):
    """
    Detailed serializer for delivery assignments.
    """
    order = OrderDetailSerializer(read_only=True)
    delivery_manager = UserBasicInfoSerializer(read_only=True)
    status_history = serializers.SerializerMethodField()
    delivery_duration = serializers.SerializerMethodField()

    class Meta:
        model = DeliveryAssignment
        fields = [
            'id', 'order', 'delivery_manager',
            'assigned_at', 'delivery_notes', 'estimated_delivery_time', 'actual_delivery_time',
            'updated_at', 'status_history', 'delivery_duration'
        ]
        read_only_fields = [
            'id', 'order', 'delivery_manager', 'assigned_at', 'updated_at',
            'status_history', 'delivery_duration'
        ]
    
    def get_status_history(self, obj):
        """Get status change history."""
        history = obj.status_history.all()[:5]  # Last 5 status changes
        return DeliveryStatusHistorySerializer(history, many=True).data
    
    def get_delivery_duration(self, obj):
        """Get delivery duration in minutes."""
        duration = obj.get_delivery_duration()
        if duration:
            return int(duration.total_seconds() / 60)  # Return in minutes
        return None


class DeliveryAssignmentCreateSerializer(serializers.ModelSerializer):
    """
    Serializer for creating delivery assignments.
    """
    order_id = serializers.IntegerField()
    delivery_manager_id = serializers.IntegerField()
    estimated_delivery_time = serializers.DateTimeField(required=False)
    
    class Meta:
        model = DeliveryAssignment
        fields = [
            'order_id', 'delivery_manager_id', 'delivery_notes',
            'estimated_delivery_time'
        ]
    
    def validate_order_id(self, value):
        """Validate order exists and is ready for assignment."""
        try:
            order = Order.objects.get(id=value)
        except Order.DoesNotExist:
            raise serializers.ValidationError("Order not found.")
        
        # Temporarily disable status check to allow assignment of confirmed orders
        # if order.status != 'ready_for_delivery':
        #     raise serializers.ValidationError(
        #         "Order must be in 'ready_for_delivery' status to assign for delivery."
        #     )
        
        if hasattr(order, 'delivery_assignment'):
            raise serializers.ValidationError("Order already has a delivery assignment.")
        
        return value
    
    def validate_delivery_manager_id(self, value):
        """Validate delivery manager exists and is a delivery admin."""
        try:
            user = User.objects.get(id=value)
        except User.DoesNotExist:
            raise serializers.ValidationError("Delivery manager not found.")
        
        if not user.is_delivery_admin():
            raise serializers.ValidationError("User must be a delivery administrator.")
        
        if not user.is_active:
            raise serializers.ValidationError("Delivery manager account is not active.")
        
        return value
    
    @transaction.atomic
    def create(self, validated_data):
        """Create delivery assignment and update order status."""
        order_id = validated_data.pop('order_id')
        delivery_manager_id = validated_data.pop('delivery_manager_id')
        
        order = Order.objects.get(id=order_id)
        delivery_manager = User.objects.get(id=delivery_manager_id)
        
        # Create assignment
        assignment = DeliveryAssignment.objects.create(
            order=order,
            delivery_manager=delivery_manager,
            **validated_data
        )
        
        # Update order status
        order.status = 'assigned_to_delivery'
        order.save()
        
        return assignment


class DeliveryAssignmentStatusUpdateSerializer(serializers.Serializer):
    """
    Serializer for updating delivery assignment status.
    """
    STATUS_CHOICES = DeliveryStatusHistory.STATUS_CHOICES
    
    status = serializers.ChoiceField(choices=STATUS_CHOICES)
    notes = serializers.CharField(max_length=1000, required=False, allow_blank=True)
    estimated_delivery_time = serializers.DateTimeField(required=False)
    failure_reason = serializers.CharField(max_length=1000, required=False, allow_blank=True)
    
    def validate_status(self, value):
        """Validate status transition."""
        assignment = self.context.get('assignment')
        if not assignment:
            raise serializers.ValidationError("Assignment context is required.")
        
        current_status = assignment.status
        valid_transitions = {
            'assigned': ['picked_up', 'delivered'],
            'picked_up': ['delivered'],
            'delivered': [],  # Final state
        }
        
        if value not in valid_transitions.get(current_status, []):
            raise serializers.ValidationError(
                f"Cannot change status from '{current_status}' to '{value}'"
            )
        
        return value
    
    def validate(self, attrs):
        """Additional validation."""
        return attrs


class DeliveryStatusHistorySerializer(serializers.ModelSerializer):
    """
    Serializer for delivery status history.
    """
    updated_by_name = serializers.CharField(source='updated_by.get_full_name', read_only=True)
    previous_status_display = serializers.SerializerMethodField()
    new_status_display = serializers.SerializerMethodField()
    
    class Meta:
        model = DeliveryStatusHistory
        fields = [
            'id', 'previous_status', 'previous_status_display',
            'new_status', 'new_status_display', 'updated_by_name',
            'notes', 'updated_at'
        ]
        read_only_fields = ['id', 'updated_at']
    
    def get_previous_status_display(self, obj):
        """Get display name for previous status."""
        return dict(DeliveryStatusHistory.STATUS_CHOICES).get(obj.previous_status, obj.previous_status)
    
    def get_new_status_display(self, obj):
        """Get display name for new status."""
        return dict(DeliveryStatusHistory.STATUS_CHOICES).get(obj.new_status, obj.new_status)


class OrderApprovalSerializer(serializers.Serializer):
    """
    Serializer for order approval with delivery manager assignment.
    """
    delivery_manager_id = serializers.IntegerField()
    notes = serializers.CharField(required=False, allow_blank=True)
    
    def validate_delivery_manager_id(self, value):
        try:
            delivery_manager = User.objects.get(
                id=value,
                user_type='delivery_admin'
            )
            
            # Check if delivery manager is available
            if hasattr(delivery_manager, 'delivery_profile'):
                if delivery_manager.delivery_profile.status not in ['online', 'available']:
                    raise serializers.ValidationError("Selected delivery manager is not available")
            
            return value
        except User.DoesNotExist:
            raise serializers.ValidationError("Invalid delivery manager")


class DeliveryManagerAssignmentSerializer(serializers.Serializer):
    """
    Serializer for assigning delivery manager to orders.
    """
    delivery_manager_id = serializers.IntegerField()
    assignment_notes = serializers.CharField(required=False, allow_blank=True)
    
    def validate_delivery_manager_id(self, value):
        try:
            delivery_manager = User.objects.get(
                id=value,
                user_type='delivery_admin'
            )
            return value
        except User.DoesNotExist:
            raise serializers.ValidationError("Invalid delivery manager")


class DeliveryStartSerializer(serializers.Serializer):
    """
    Serializer for starting delivery tracking.
    """
    latitude = serializers.DecimalField(max_digits=10, decimal_places=7, required=False)
    longitude = serializers.DecimalField(max_digits=10, decimal_places=7, required=False)
    address = serializers.CharField(required=False, allow_blank=True)
    notes = serializers.CharField(required=False, allow_blank=True)


class DeliveryCompletionSerializer(serializers.Serializer):
    """
    Serializer for completing delivery.
    """
    delivery_notes = serializers.CharField(required=False, allow_blank=True)
    customer_signature = serializers.CharField(required=False, allow_blank=True)
    delivery_photo = serializers.ImageField(required=False)
    rating = serializers.IntegerField(min_value=1, max_value=5, required=False)


class OrderCreateSerializer(serializers.ModelSerializer):
    """
    Serializer for creating orders directly from cart data.
    """
    customer = serializers.PrimaryKeyRelatedField(queryset=User.objects.filter(user_type='customer'))
    
    def validate_customer(self, value):
        """Validate customer exists and is a customer."""
        if value is None:
            raise serializers.ValidationError("Customer ID cannot be None.")
        
        try:
            customer = User.objects.get(id=value)
        except User.DoesNotExist:
            raise serializers.ValidationError("Customer not found.")
        
        if customer.user_type != 'customer':
            raise serializers.ValidationError("User must be a customer.")
        
        return value
    
    class Meta:
        model = Order
        fields = [
            'customer', 'total_amount', 'delivery_address', 'delivery_city',
            'delivery_notes', 'status', 'order_type'
        ]
        read_only_fields = ['status']
    
    def create(self, validated_data):
        # Generate unique order number
        import uuid
        order_number = f"ORD-{uuid.uuid4().hex[:8].upper()}"
        
        validated_data['order_number'] = order_number
        validated_data['status'] = 'pending'
        
        return super().create(validated_data)


class DeliveryAssignmentBasicSerializer(serializers.ModelSerializer):
    """
    Basic serializer for delivery assignments.
    """
    delivery_manager_name = serializers.CharField(source='delivery_manager.get_full_name', read_only=True)
    assigned_by_name = serializers.CharField(source='assigned_by.get_full_name', read_only=True)
    
    class Meta:
        model = DeliveryAssignment
        fields = [
            'id', 'order', 'delivery_manager', 'delivery_manager_name',
            'status', 'assigned_at', 'assigned_by', 'assigned_by_name',
            'started_at', 'completed_at'
        ]
        read_only_fields = ['id', 'assigned_at', 'assigned_by']


class OrderCreateFromPaymentSerializer(serializers.ModelSerializer):
    """
    Serializer for creating orders from completed payments.
    """
    payment_id = serializers.IntegerField()
    
    class Meta:
        model = Order
        fields = ['payment_id', 'delivery_address', 'delivery_notes']
    
    def validate_payment_id(self, value):
        """Validate payment exists and is completed."""
        try:
            payment = Payment.objects.get(id=value)
        except Payment.DoesNotExist:
            raise serializers.ValidationError("Payment not found.")
        
        if payment.status != 'completed':
            raise serializers.ValidationError("Payment must be completed to create order.")
        
        if hasattr(payment, 'order'):
            raise serializers.ValidationError("Order already exists for this payment.")
        
        return value
    
    @transaction.atomic
    def create(self, validated_data):
        """Create order from payment with cart items."""
        payment_id = validated_data.pop('payment_id')
        payment = Payment.objects.get(id=payment_id)
        
        # Get delivery info from cash on delivery payment if exists
        delivery_info = {}
        if hasattr(payment, 'cash_on_delivery_details'):
            cod_details = payment.cash_on_delivery_details
            delivery_info = {
                'delivery_address': cod_details.delivery_address,
                'delivery_notes': cod_details.notes or ''
            }
        
        # Override with provided data
        delivery_info.update(validated_data)
        
        # Create order
        order = Order.objects.create(
            customer=payment.user,
            payment=payment,
            total_amount=payment.amount,
            **delivery_info
        )
        
        # Create order items from cart and update book quantities
        cart = payment.user.cart
        for cart_item in cart.items.all():
            # Create order item
            OrderItem.objects.create(
                order=order,
                book=cart_item.book,
                book_name=cart_item.book.name,
                book_price=cart_item.book.price,
                quantity=cart_item.quantity
            )
            
            # Update book quantities
            book = cart_item.book
            if book.available_copies is not None:
                book.available_copies = max(0, book.available_copies - cart_item.quantity)
            if book.quantity is not None:
                book.quantity = max(0, book.quantity - cart_item.quantity)
            book.save(update_fields=['available_copies', 'quantity'])
        
        # Clear cart after order creation
        cart.clear()
        
        return order 


class DeliveryRequestCreateSerializer(serializers.ModelSerializer):
    """
    Serializer for creating delivery requests.
    """
    class Meta:
        model = DeliveryRequest
        fields = [
            'delivery_address', 'delivery_notes', 
            'preferred_delivery_date'
        ]
    
    def create(self, validated_data):
        # Set the customer to the current user
        user = self.context['request'].user
        return DeliveryRequest.objects.create(customer=user, **validated_data)


class DeliveryRequestListSerializer(serializers.ModelSerializer):
    """
    Serializer for listing delivery requests.
    """
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    request_type_display = serializers.CharField(source='get_request_type_display', read_only=True)
    customer_name = serializers.CharField(source='customer.get_full_name', read_only=True)
    customer_id = serializers.CharField(source='customer.id', read_only=True)
    customer_phone = serializers.SerializerMethodField()
    customer_email = serializers.CharField(source='customer.email', read_only=True)
    order_id = serializers.SerializerMethodField()
    order_number = serializers.SerializerMethodField()
    shipping_address = serializers.SerializerMethodField()
    delivery_manager_id = serializers.SerializerMethodField()
    delivery_manager_name = serializers.SerializerMethodField()
    order = OrderDetailSerializer(read_only=True)
    
    class Meta:
        model = DeliveryRequest
        fields = [
            'id', 'request_type', 'request_type_display', 'customer', 'customer_id',
            'customer_name', 'customer_phone', 'customer_email', 'order_id', 'order_number',
            'delivery_address', 'delivery_city', 'shipping_address', 'status', 'status_display', 
            'delivery_manager_id', 'delivery_manager_name', 'preferred_delivery_time', 'created_at', 'notes',
            'order'
        ]
        read_only_fields = ['id', 'created_at']
    
    def get_order_id(self, obj):
        """Get order ID if this delivery request is related to an order."""
        # Return the actual order ID if available, otherwise use delivery request ID
        if hasattr(obj, 'order') and obj.order:
            return obj.order.id
        return obj.id
    
    def get_order_number(self, obj):
        """Get order number if this delivery request is related to an order."""
        # Return actual order number if available, otherwise use delivery request number
        if hasattr(obj, 'order') and obj.order and hasattr(obj.order, 'order_number'):
            return obj.order.order_number
        return f"DR-{obj.id:06d}"
    
    def get_customer_phone(self, obj):
        """Get customer phone number safely."""
        try:
            if hasattr(obj.customer, 'profile') and obj.customer.profile.phone_number:
                return obj.customer.profile.phone_number
        except Exception:
            pass
        return None
    
    def get_shipping_address(self, obj):
        """Get shipping address from order or delivery request."""
        # Try to get address from related order first
        if hasattr(obj, 'order') and obj.order and hasattr(obj.order, 'shipping_address'):
            return obj.order.shipping_address
        # Fall back to delivery address
        return obj.delivery_address
    
    def get_delivery_manager_id(self, obj):
        """Get delivery manager ID if assigned."""
        return obj.delivery_manager.id if obj.delivery_manager else None
    
    def get_delivery_manager_name(self, obj):
        """Get delivery manager name if assigned."""
        if obj.delivery_manager:
            return f"{obj.delivery_manager.first_name} {obj.delivery_manager.last_name}".strip()
        return None


class DeliveryRequestDetailSerializer(serializers.ModelSerializer):
    """
    Serializer for detailed delivery request information.
    """
    customer = UserDetailSerializer(read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    request_type_display = serializers.CharField(source='get_request_type_display', read_only=True)
    delivery_manager_name = serializers.CharField(source='delivery_manager.get_full_name', read_only=True)
    assigned_by_name = serializers.CharField(source='assigned_by.get_full_name', read_only=True, allow_null=True)
    
    class Meta:
        model = DeliveryRequest
        fields = [
            'id', 'request_type', 'request_type_display', 'customer', 
            'pickup_address', 'pickup_city', 'delivery_address', 'delivery_city',
            'preferred_pickup_time', 'preferred_delivery_time', 'notes',
            'status', 'status_display', 'delivery_manager', 'delivery_manager_name',
            'assigned_by', 'assigned_by_name', 'created_at', 'updated_at', 
            'assigned_at', 'delivered_at'
        ]
        read_only_fields = [
            'id', 'customer', 'delivery_manager', 'assigned_by',
            'created_at', 'updated_at', 'assigned_at', 'delivered_at'
        ]


class DeliveryRequestAssignSerializer(serializers.Serializer):
    """
    Serializer for assigning delivery requests to managers.
    """
    delivery_manager_id = serializers.IntegerField()
    notes = serializers.CharField(required=False, allow_blank=True)
    
    def validate_delivery_manager_id(self, value):
        try:
            user = User.objects.get(id=value)
        except User.DoesNotExist:
            raise serializers.ValidationError("Delivery manager not found.")
        
        if not user.is_delivery_admin():
            raise serializers.ValidationError("User must be a delivery administrator.")
        
        if not user.is_active:
            raise serializers.ValidationError("Delivery manager account is not active.")
        
        return value


class DeliveryRequestStatusUpdateSerializer(serializers.Serializer):
    """
    Serializer for updating delivery request status.
    """
    STATUS_CHOICES = DeliveryRequest.STATUS_CHOICES
    
    status = serializers.ChoiceField(choices=STATUS_CHOICES)
    notes = serializers.CharField(required=False, allow_blank=True) 


class DeliveryManagerForRequestSerializer(serializers.ModelSerializer):
    """
    Serializer for delivery managers who are available to deliver requests.
    """
    full_name = serializers.CharField(source='get_full_name', read_only=True)
    
    class Meta:
        model = User
        fields = ['id', 'full_name', 'email']
        read_only_fields = ['id', 'full_name', 'email']


class DeliveryRequestWithAvailableManagersSerializer(serializers.ModelSerializer):
    """
    Serializer for delivery requests with a list of available delivery managers.
    Used by library admins to assign delivery managers to requests.
    """
    customer_name = serializers.CharField(source='customer.get_full_name', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    available_managers = serializers.SerializerMethodField()
    
    class Meta:
        model = DeliveryRequest
        fields = [
            'id', 'request_number', 'customer_name', 'delivery_address',
            'status', 'status_display', 'preferred_delivery_date',
            'created_at', 'delivery_notes', 'available_managers'
        ]
        read_only_fields = ['id', 'request_number', 'created_at']
    
    def get_available_managers(self, obj):
        """Get list of available delivery managers for this request."""
        available_managers = DeliveryRequest.get_available_delivery_managers()
        serializer = DeliveryManagerForRequestSerializer(available_managers, many=True)
        return serializer.data


class BorrowingOrderSerializer(serializers.ModelSerializer):
    """
    Serializer for borrowing orders to be displayed in delivery requests list.
    """
    customer_name = serializers.CharField(source='customer.get_full_name', read_only=True)
    book_title = serializers.CharField(source='borrow_request.book.title', read_only=True)
    status_display = serializers.SerializerMethodField()
    available_managers = serializers.SerializerMethodField()
    request_type = serializers.SerializerMethodField()
    
    class Meta:
        model = Order
        fields = [
            'id', 'order_number', 'customer_name', 'book_title', 'delivery_address',
            'status', 'status_display', 'created_at', 'delivery_notes', 
            'available_managers', 'request_type'
        ]
        read_only_fields = ['id', 'order_number', 'created_at']
    
    def get_status_display(self, obj):
        """Get human-readable status."""
        status_map = {
            'pending_assignment': 'Pending',
            'assigned': 'Assigned', 
            'in_delivery': 'In Progress',
            'delivered': 'Completed',
            'cancelled': 'Cancelled'
        }
        return status_map.get(obj.status, obj.status)
    
    def get_request_type(self, obj):
        """Get request type."""
        return 'Borrowing'
    
    def get_available_managers(self, obj):
        """Get list of available delivery managers for this request."""
        from ..models import User
        available_managers = User.objects.filter(
            user_type='delivery_admin',
            is_active=True,
            delivery_profile__delivery_status__in=['online', 'busy'],
            delivery_profile__is_tracking_active=True
        ).select_related('delivery_profile')
        
        serializer = DeliveryManagerForRequestSerializer(available_managers, many=True)
        return serializer.data


class LocationHistorySerializer(serializers.ModelSerializer):
    """
    Serializer for location history entries.
    """
    delivery_manager_name = serializers.CharField(source='delivery_manager.get_full_name', read_only=True)
    location_display = serializers.CharField(source='get_location_display', read_only=True)
    distance_from_previous = serializers.SerializerMethodField()
    
    class Meta:
        model = LocationHistory
        fields = [
            'id', 'delivery_manager', 'delivery_manager_name',
            'latitude', 'longitude', 'address', 'location_display',
            'tracking_type', 'accuracy', 'speed', 'heading',
            'recorded_at', 'delivery_assignment', 'battery_level',
            'network_type', 'distance_from_previous'
        ]
        read_only_fields = ['id', 'recorded_at', 'delivery_manager_name', 'location_display']
    
    def get_distance_from_previous(self, obj):
        """Calculate distance from previous location."""
        if not hasattr(self, '_previous_location'):
            return None
        
        return obj.get_distance_from(self._previous_location)


class LocationHistoryCreateSerializer(serializers.ModelSerializer):
    """
    Serializer for creating location history entries.
    """
    class Meta:
        model = LocationHistory
        fields = [
            'latitude', 'longitude', 'address', 'tracking_type',
            'accuracy', 'speed', 'heading', 'battery_level',
            'network_type', 'delivery_assignment'
        ]
    
    def validate_latitude(self, value):
        """Validate latitude value."""
        if not (-90 <= value <= 90):
            raise serializers.ValidationError("Latitude must be between -90 and 90")
        return value
    
    def validate_longitude(self, value):
        """Validate longitude value."""
        if not (-180 <= value <= 180):
            raise serializers.ValidationError("Longitude must be between -180 and 180")
        return value
    
    def validate_speed(self, value):
        """Validate speed value."""
        if value is not None and value < 0:
            raise serializers.ValidationError("Speed cannot be negative")
        return value
    
    def validate_heading(self, value):
        """Validate heading value."""
        if value is not None and not (0 <= value <= 360):
            raise serializers.ValidationError("Heading must be between 0 and 360 degrees")
        return value


class RealTimeTrackingSerializer(serializers.ModelSerializer):
    """
    Serializer for real-time tracking settings.
    """
    delivery_manager_name = serializers.CharField(source='delivery_manager.get_full_name', read_only=True)
    is_online = serializers.SerializerMethodField()
    
    class Meta:
        model = RealTimeTracking
        fields = [
            'id', 'delivery_manager', 'delivery_manager_name',
            'is_tracking_enabled', 'tracking_interval', 'last_location_update',
            'is_delivering', 'current_delivery_assignment', 'auto_track_deliveries',
            'share_location_with_admin', 'share_location_with_customers',
            'tracking_accuracy', 'max_tracking_duration', 'is_online',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'delivery_manager', 'last_location_update', 'created_at', 'updated_at']
    
    def get_is_online(self, obj):
        """Check if delivery manager is currently online."""
        if not obj.last_location_update:
            return False
        
        from django.utils import timezone
        from datetime import timedelta
        
        # Consider online if last update was within 5 minutes
        five_minutes_ago = timezone.now() - timedelta(minutes=5)
        return obj.last_location_update > five_minutes_ago


class RealTimeTrackingUpdateSerializer(serializers.ModelSerializer):
    """
    Serializer for updating real-time tracking settings.
    """
    class Meta:
        model = RealTimeTracking
        fields = [
            'is_tracking_enabled', 'tracking_interval', 'auto_track_deliveries',
            'share_location_with_admin', 'share_location_with_customers',
            'tracking_accuracy', 'max_tracking_duration'
        ]
    
    def validate_tracking_interval(self, value):
        """Validate tracking interval."""
        if not (10 <= value <= 300):  # 10 seconds to 5 minutes
            raise serializers.ValidationError("Tracking interval must be between 10 and 300 seconds")
        return value
    
    def validate_max_tracking_duration(self, value):
        """Validate max tracking duration."""
        if not (1 <= value <= 24):  # 1 to 24 hours
            raise serializers.ValidationError("Max tracking duration must be between 1 and 24 hours")
        return value


class LocationTrackingUpdateSerializer(serializers.Serializer):
    """
    Serializer for real-time location updates.
    """
    latitude = serializers.DecimalField(max_digits=10, decimal_places=7)
    longitude = serializers.DecimalField(max_digits=10, decimal_places=7)
    address = serializers.CharField(required=False, allow_blank=True)
    tracking_type = serializers.ChoiceField(
        choices=LocationHistory.TRACKING_TYPE_CHOICES,
        default='gps'
    )
    accuracy = serializers.FloatField(required=False, min_value=0)
    speed = serializers.FloatField(required=False, min_value=0)
    heading = serializers.FloatField(required=False, min_value=0, max_value=360)
    battery_level = serializers.IntegerField(required=False, min_value=0, max_value=100)
    network_type = serializers.CharField(required=False, max_length=20)
    delivery_assignment_id = serializers.IntegerField(required=False)
    
    def validate_latitude(self, value):
        """Validate latitude value."""
        if not (-90 <= value <= 90):
            raise serializers.ValidationError("Latitude must be between -90 and 90")
        return value
    
    def validate_longitude(self, value):
        """Validate longitude value."""
        if not (-180 <= value <= 180):
            raise serializers.ValidationError("Longitude must be between -180 and 180")
        return value


class MovementSummarySerializer(serializers.Serializer):
    """
    Serializer for movement summary data.
    """
    total_points = serializers.IntegerField()
    total_distance = serializers.FloatField()
    average_speed = serializers.FloatField()
    movement_time = serializers.FloatField()
    hours_analyzed = serializers.IntegerField()


class DeliveryManagerLocationWithHistorySerializer(serializers.ModelSerializer):
    """
    Serializer for delivery manager location with history.
    """
    location = serializers.SerializerMethodField()
    recent_locations = serializers.SerializerMethodField()
    movement_summary = serializers.SerializerMethodField()
    real_time_tracking = serializers.SerializerMethodField()
    
    class Meta:
        model = User
        fields = [
            'id', 'first_name', 'last_name', 'email',
            'location', 'recent_locations', 'movement_summary',
            'real_time_tracking'
        ]
    
    def get_location(self, obj):
        """Get current location data."""
        return obj.get_location_dict()
    
    def get_recent_locations(self, obj):
        """Get recent location history."""
        hours = self.context.get('hours', 24)
        recent_locations = obj.get_location_history(hours)
        return LocationHistorySerializer(recent_locations, many=True).data
    
    def get_movement_summary(self, obj):
        """Get movement summary."""
        hours = self.context.get('hours', 24)
        summary = obj.get_movement_summary(hours)
        return MovementSummarySerializer(summary).data
    
    def get_real_time_tracking(self, obj):
        """Get real-time tracking settings."""
        try:
            tracking = obj.real_time_tracking
            return RealTimeTrackingSerializer(tracking).data
        except RealTimeTracking.DoesNotExist:
            return None


 
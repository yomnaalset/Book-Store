from rest_framework import serializers
from django.utils import timezone
from django.db import transaction
from ..models import Order, OrderItem, DeliveryAssignment, DeliveryStatusHistory, User, Payment, Book
from ..models.delivery_model import DeliveryRequest
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
    book_title = serializers.CharField(source='book.name', read_only=True)
    book_author = serializers.CharField(source='book.author.name', read_only=True)
    
    class Meta:
        model = OrderItem
        fields = [
            'id', 'book', 'book_title', 'book_author',
            'book_name', 'book_price', 'quantity', 'subtotal'
        ]
        read_only_fields = ['id', 'book_title', 'book_author', 'subtotal']


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
            'total_amount', 'status', 'payment_type', 'payment_status',
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
            'total_amount', 'status', 'status_display',
            'delivery_address', 'contact_phone', 'delivery_notes',
            'total_items', 'total_quantity', 'can_be_cancelled', 'can_be_delivered',
            'delivery_assignment', 'created_at', 'updated_at',
            'confirmed_at', 'delivered_at'
        ]
        read_only_fields = [
            'id', 'order_number', 'customer', 'payment', 'items',
            'total_amount', 'total_items', 'total_quantity',
            'can_be_cancelled', 'can_be_delivered', 'delivery_assignment',
            'created_at', 'updated_at', 'confirmed_at', 'delivered_at'
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
            'pending': ['confirmed', 'cancelled'],
            'confirmed': ['preparing', 'cancelled'],
            'preparing': ['ready_for_delivery', 'cancelled'],
            'ready_for_delivery': ['assigned_to_delivery'],
            'assigned_to_delivery': ['out_for_delivery', 'ready_for_delivery'],
            'out_for_delivery': ['delivered', 'failed', 'returned'],
            'delivered': [],  # Final state
            'cancelled': [],  # Final state
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
    delivery_manager_name = serializers.CharField(source='delivery_manager.get_full_name', read_only=True)
    order_number = serializers.CharField(source='order.order_number', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)

    class Meta:
        model = DeliveryAssignment
        fields = [
            'id', 'order_number', 'delivery_manager_name',
            'status', 'status_display', 'assigned_at', 'estimated_delivery_time',
            'contact_phone'
        ]
        read_only_fields = ['id', 'assigned_at']


class DeliveryAssignmentDetailSerializer(serializers.ModelSerializer):
    """
    Detailed serializer for delivery assignments.
    """
    order = OrderDetailSerializer(read_only=True)
    delivery_manager = UserBasicInfoSerializer(read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    status_history = serializers.SerializerMethodField()
    delivery_duration = serializers.SerializerMethodField()

    class Meta:
        model = DeliveryAssignment
        fields = [
            'id', 'order', 'delivery_manager', 'status', 'status_display',
            'assigned_at', 'accepted_at', 'picked_up_at', 'delivered_at',
            'delivery_notes', 'estimated_delivery_time', 'actual_delivery_time',
            'failure_reason', 'retry_count', 'updated_at',
            'status_history', 'delivery_duration', 'contact_phone'
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
    contact_phone = serializers.CharField(max_length=20, required=False)
    
    class Meta:
        model = DeliveryAssignment
        fields = [
            'order_id', 'delivery_manager_id', 'delivery_notes',
            'estimated_delivery_time', 'contact_phone'
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
        
        # If contact_phone is not provided, use the delivery manager's phone from profile
        if 'contact_phone' not in validated_data or not validated_data['contact_phone']:
            try:
                if hasattr(delivery_manager, 'profile') and delivery_manager.profile.phone_number:
                    validated_data['contact_phone'] = delivery_manager.profile.phone_number
            except Exception as e:
                # If there's an error getting the phone number, just continue without it
                pass
        
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


class OrderCreateFromPaymentSerializer(serializers.ModelSerializer):
    """
    Serializer for creating orders from completed payments.
    """
    payment_id = serializers.IntegerField()
    
    class Meta:
        model = Order
        fields = ['payment_id', 'delivery_address', 'contact_phone', 'delivery_notes']
    
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
                'contact_phone': cod_details.contact_phone,
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
            if book.availableCopies is not None:
                book.availableCopies = max(0, book.availableCopies - cart_item.quantity)
            if book.quantity is not None:
                book.quantity = max(0, book.quantity - cart_item.quantity)
            book.save(update_fields=['availableCopies', 'quantity'])
        
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
            'delivery_address', 'contact_phone', 'delivery_notes', 
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
    
    class Meta:
        model = DeliveryRequest
        fields = [
            'id', 'request_number', 'delivery_address', 'status', 
            'status_display', 'preferred_delivery_date', 'created_at'
        ]
        read_only_fields = ['id', 'request_number', 'created_at']


class DeliveryRequestDetailSerializer(serializers.ModelSerializer):
    """
    Serializer for detailed delivery request information.
    """
    customer = UserDetailSerializer(read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    delivery_manager_name = serializers.CharField(source='delivery_manager.get_full_name', read_only=True)
    assigned_by_name = serializers.CharField(source='assigned_by.get_full_name', read_only=True, allow_null=True)
    
    class Meta:
        model = DeliveryRequest
        fields = [
            'id', 'request_number', 'customer', 'delivery_address',
            'contact_phone', 'delivery_notes', 'preferred_delivery_date',
            'status', 'status_display', 'delivery_manager', 'delivery_manager_name',
            'assigned_by', 'assigned_by_name', 'created_at', 'updated_at', 
            'assigned_at', 'delivered_at'
        ]
        read_only_fields = [
            'id', 'request_number', 'customer', 'delivery_manager', 'assigned_by',
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
            'contact_phone', 'status', 'status_display', 'preferred_delivery_date',
            'created_at', 'delivery_notes', 'available_managers'
        ]
        read_only_fields = ['id', 'request_number', 'created_at']
    
    def get_available_managers(self, obj):
        """Get list of available delivery managers for this request."""
        available_managers = DeliveryRequest.get_available_delivery_managers()
        serializer = DeliveryManagerForRequestSerializer(available_managers, many=True)
        return serializer.data


 
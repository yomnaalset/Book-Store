from rest_framework import serializers
from django.utils import timezone
from django.db import transaction
from ..models import Order, OrderItem, DeliveryAssignment, DeliveryStatusHistory, User, Payment, Book
from ..models.delivery_model import DeliveryRequest, LocationHistory, RealTimeTracking, DeliveryActivity, OrderNote
from .user_serializers import UserBasicInfoSerializer, UserDetailSerializer 
from .payment_serializers import PaymentBasicSerializer
from .library_serializers import BookSerializer
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
    
    def to_representation(self, instance):
        """Add debug logging to see what data is being serialized."""
        import logging
        logger = logging.getLogger(__name__)
        
        logger.info(f"OrderItemSerializer: Serializing OrderItem {instance.id}")
        logger.info(f"OrderItemSerializer: Book: {instance.book}")
        logger.info(f"OrderItemSerializer: Book name: {instance.book.name if instance.book else 'None'}")
        logger.info(f"OrderItemSerializer: Book author: {instance.book.author.name if instance.book and instance.book.author else 'None'}")
        
        data = super().to_representation(instance)
        logger.info(f"OrderItemSerializer: Serialized data: {data}")
        
        return data


class OrderForDeliverySerializer(serializers.ModelSerializer):
    """
    Simplified order serializer for delivery assignments (avoids circular reference).
    """
    customer = UserDetailSerializer(read_only=True)
    items = OrderItemSerializer(many=True, read_only=True)
    
    class Meta:
        model = Order
        fields = [
            'id', 'order_number', 'customer', 'items',
            'total_amount', 'status', 'payment_method',
            'delivery_address', 'delivery_city', 'delivery_notes',
            'created_at', 'updated_at'
        ]
        read_only_fields = fields


class DeliveryAssignmentBasicSerializer(serializers.ModelSerializer):
    """
    Basic serializer for delivery assignments with order details for delivery managers.
    """
    delivery_manager_name = serializers.CharField(source='delivery_manager.get_full_name', read_only=True)
    delivery_manager_email = serializers.EmailField(source='delivery_manager.email', read_only=True, allow_null=True)
    delivery_manager_phone = serializers.SerializerMethodField()
    order_number = serializers.CharField(source='order.order_number', read_only=True)
    assigned_by_name = serializers.CharField(source='assigned_by.get_full_name', read_only=True)
    order = serializers.SerializerMethodField()

    class Meta:
        model = DeliveryAssignment
        fields = [
            'id', 'order', 'order_number', 'delivery_manager', 'delivery_manager_name',
            'delivery_manager_email', 'delivery_manager_phone',
            'status', 'assigned_at', 'assigned_by', 'assigned_by_name',
            'estimated_delivery_time', 'started_at', 'completed_at'
        ]
        read_only_fields = ['id', 'assigned_at', 'assigned_by']
    
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
            import logging
            logger = logging.getLogger(__name__)
            logger.debug(f"Error getting delivery manager phone: {str(e)}")
        return None
    
    def get_order(self, obj):
        """Return full order details for delivery managers"""
        try:
            if obj.order:
                return OrderForDeliverySerializer(obj.order).data
        except Exception as e:
            # Fallback to just the order ID if serialization fails
            return obj.order.id if obj.order else None
        return None


class OrderListSerializer(serializers.ModelSerializer):
    """
    Serializer for listing orders with basic information.
    """
    customer_name = serializers.CharField(source='customer.get_full_name', read_only=True)
    customer_email = serializers.CharField(source='customer.email', read_only=True)
    payment_type = serializers.SerializerMethodField()
    payment_status = serializers.SerializerMethodField()
    total_items = serializers.SerializerMethodField()
    total_quantity = serializers.SerializerMethodField()
    has_delivery_assignment = serializers.SerializerMethodField()
    delivery_assignment = serializers.SerializerMethodField()

    class Meta:
        model = Order
        fields = [
            'id', 'order_number', 'customer_name', 'customer_email',
            'total_amount', 'status', 'order_type', 'payment_method', 'payment_type', 'payment_status',
            'total_items', 'total_quantity', 'has_delivery_assignment',
            'discount_code', 'discount_amount', 'discount_percentage', 'delivery_cost',
            'created_at', 'updated_at', 'delivery_assignment'
        ]
        read_only_fields = ['id', 'order_number', 'created_at', 'updated_at']
    
    def get_payment_type(self, obj):
        """Get payment type display."""
        try:
            if obj.payment:
                return obj.payment.get_payment_type_display()
        except Exception:
            pass
        return None
    
    def get_payment_status(self, obj):
        """Get payment status display."""
        try:
            if obj.payment:
                return obj.payment.get_status_display()
        except Exception:
            pass
        return None
    
    def get_total_items(self, obj):
        """Get total number of items in order."""
        try:
            return obj.get_total_items()
        except Exception:
            return 0
    
    def get_total_quantity(self, obj):
        """Get total quantity of all items."""
        try:
            return obj.get_total_quantity()
        except Exception:
            return 0
    
    def get_has_delivery_assignment(self, obj):
        """Check if order has a delivery assignment."""
        try:
            return hasattr(obj, 'delivery_assignment') and obj.delivery_assignment is not None
        except Exception:
            return False
            
    def get_delivery_assignment(self, obj):
        """Return delivery assignment details if exist"""
        try:
            if hasattr(obj, 'delivery_assignment') and obj.delivery_assignment is not None:
                return DeliveryAssignmentBasicSerializer(obj.delivery_assignment).data
        except Exception:
            pass
        return None


class OrderDetailSerializer(serializers.ModelSerializer):
    """
    Detailed serializer for orders with all related information.
    """
    customer = UserDetailSerializer(read_only=True)
    payment = PaymentBasicSerializer(read_only=True)
    items = OrderItemSerializer(many=True, read_only=True)
    delivery_assignment = serializers.SerializerMethodField()
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    total_items = serializers.SerializerMethodField()
    total_quantity = serializers.SerializerMethodField()
    can_be_cancelled = serializers.BooleanField(read_only=True)
    can_be_delivered = serializers.BooleanField(read_only=True)
    can_edit_notes = serializers.SerializerMethodField()
    can_delete_notes = serializers.SerializerMethodField()
    notes = serializers.SerializerMethodField()
    class Meta:
        model = Order
        fields = [
            'id', 'order_number', 'customer', 'payment', 'items',
            'total_amount', 'status', 'status_display', 'order_type', 'payment_method',
            'delivery_address', 'delivery_city', 'delivery_notes', 'cancellation_reason',
            'total_items', 'total_quantity', 'can_be_cancelled', 'can_be_delivered',
            'can_edit_notes', 'can_delete_notes', 'notes',
            'discount_code', 'discount_amount', 'discount_percentage', 'delivery_cost',
            'created_at', 'updated_at', 'delivery_assignment'
        ]
        read_only_fields = [
            'id', 'order_number', 'customer', 'payment', 'items',
            'total_amount', 'total_items', 'total_quantity',
            'can_be_cancelled', 'can_be_delivered', 'delivery_assignment',
            'created_at', 'updated_at'
        ]
    
    def get_total_items(self, obj):
        """Get total number of items in order."""
        try:
            return obj.get_total_items()
        except Exception:
            return 0
    
    def get_total_quantity(self, obj):
        """Get total quantity of all items."""
        try:
            return obj.get_total_quantity()
        except Exception:
            return 0
    
    def get_delivery_assignment(self, obj):
        """Return delivery assignment details if exist"""
        try:
            if hasattr(obj, 'delivery_assignment') and obj.delivery_assignment is not None:
                return DeliveryAssignmentBasicSerializer(obj.delivery_assignment).data
        except Exception:
            pass
        return None
    
    def get_can_edit_notes(self, obj):
        """Check if current user can edit notes for this order"""
        request = self.context.get('request')
        if not request or not request.user:
            return False
        
        user = request.user
        
        # Customers can edit notes for their own orders
        if user.is_customer() and obj.customer == user:
            return True
        
        # Admins (library_admin, delivery_admin) can edit notes for any order
        if user.user_type in ['library_admin', 'delivery_admin']:
            return True
        
        return False
    
    def get_can_delete_notes(self, obj):
        """Check if current user can delete notes for this order"""
        # Same permissions as editing
        return self.get_can_edit_notes(obj)
    
    def get_notes(self, obj):
        """Get all notes for this order with author information"""
        # Get all non-deleted notes, ordered by most recent first
        notes = obj.notes.filter(is_deleted=False).order_by('-created_at')
        return OrderNoteSerializer(notes, many=True, context=self.context).data


class OrderNoteSerializer(serializers.ModelSerializer):
    """
    Serializer for order notes with author information.
    """
    author_name = serializers.SerializerMethodField()
    author_email = serializers.SerializerMethodField()
    author_type = serializers.SerializerMethodField()
    can_edit = serializers.SerializerMethodField()
    can_delete = serializers.SerializerMethodField()
    
    class Meta:
        model = OrderNote
        fields = [
            'id', 'content', 'author', 'author_name', 'author_email', 'author_type',
            'can_edit', 'can_delete', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'author', 'created_at', 'updated_at']
    
    def get_author_name(self, obj):
        """Get author's full name"""
        if obj.author:
            full_name = obj.author.get_full_name()
            # If full_name is empty or just whitespace, use email
            if full_name and full_name.strip():
                return full_name
            # Fallback to email or username
            return obj.author.email or getattr(obj.author, 'username', 'Unknown')
        
        # If author is None, try to infer from order context
        # This handles notes created before author tracking was implemented
        try:
            order = obj.order
            # Check if there's a delivery assignment (likely delivery manager wrote it)
            # DeliveryAssignment has OneToOneField with related_name='delivery_assignment'
            assignment = getattr(order, 'delivery_assignment', None)
            if assignment and hasattr(assignment, 'delivery_manager') and assignment.delivery_manager:
                manager = assignment.delivery_manager
                full_name = manager.get_full_name()
                if full_name and full_name.strip():
                    return full_name
                return manager.email or getattr(manager, 'username', 'Unknown')
            
            # Fallback to customer
            if order.customer:
                full_name = order.customer.get_full_name()
                if full_name and full_name.strip():
                    return full_name
                return order.customer.email or getattr(order.customer, 'username', 'Unknown')
        except Exception:
            pass
        
        return "Unknown"
    
    def get_author_email(self, obj):
        """Get author's email"""
        if obj.author:
            return obj.author.email
        
        # Try to infer from order context
        try:
            order = obj.order
            assignment = getattr(order, 'delivery_assignment', None)
            if assignment and hasattr(assignment, 'delivery_manager') and assignment.delivery_manager:
                return assignment.delivery_manager.email
            if order.customer:
                return order.customer.email
        except Exception:
            pass
        
        return None
    
    def get_author_type(self, obj):
        """Get author's user type"""
        if obj.author:
            return obj.author.user_type
        
        # Try to infer from order context
        try:
            order = obj.order
            assignment = getattr(order, 'delivery_assignment', None)
            if assignment and hasattr(assignment, 'delivery_manager') and assignment.delivery_manager:
                return assignment.delivery_manager.user_type
            if order.customer:
                return order.customer.user_type
        except Exception:
            pass
        
        return None
    
    def get_can_edit(self, obj):
        """Check if current user can edit this specific note"""
        request = self.context.get('request')
        if not request or not request.user:
            return False
        
        user = request.user
        
        # Only the author can edit their own note
        if obj.author and obj.author == user:
            return True
        
        return False
    
    def get_can_delete(self, obj):
        """Check if current user can delete this specific note"""
        # Same permission as editing - only the author can delete
        return self.get_can_edit(obj)


class OrderStatusUpdateSerializer(serializers.Serializer):
    """
    Serializer for updating order status.
    """
    STATUS_CHOICES = Order.ORDER_STATUS_CHOICES
    
    status = serializers.ChoiceField(choices=STATUS_CHOICES)
    notes = serializers.CharField(max_length=1000, required=False, allow_blank=True)
    cancellation_reason = serializers.CharField(max_length=1000, required=False, allow_blank=True)
    
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
    
    def validate(self, data):
        """Validate that cancellation_reason is provided when status is cancelled."""
        status = data.get('status')
        cancellation_reason = data.get('cancellation_reason', '').strip()
        notes = data.get('notes', '').strip()
        
        if status == 'cancelled' and not cancellation_reason and not notes:
            raise serializers.ValidationError({
                'cancellation_reason': 'Cancellation reason is required when cancelling an order.'
            })
        
        return data


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
            'id', 'order', 'delivery_manager', 'status',
            'assigned_at', 'delivery_notes', 'estimated_delivery_time', 'actual_delivery_time',
            'accepted_at', 'picked_up_at', 'delivered_at', 'started_at', 'completed_at',
            'status_history', 'delivery_duration'
        ]
        read_only_fields = [
            'id', 'order', 'delivery_manager', 'assigned_at',
            'accepted_at', 'picked_up_at', 'delivered_at', 'started_at', 'completed_at',
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
        """Validate status - allow any status change for maximum flexibility."""
        assignment = self.context.get('assignment')
        if not assignment:
            raise serializers.ValidationError("Assignment context is required.")
        
        # Allow any status change - no restrictions
        return value
    
    def validate(self, attrs):
        """Additional validation."""
        return attrs


class DeliveryStatusHistorySerializer(serializers.ModelSerializer):
    """
    Serializer for delivery status history.
    """
    status_display = serializers.SerializerMethodField()
    
    class Meta:
        model = DeliveryStatusHistory
        fields = [
            'id', 'status', 'status_display',
            'notes', 'timestamp'
        ]
        read_only_fields = ['id', 'timestamp']
    
    def get_status_display(self, obj):
        """Get display name for status."""
        return dict(DeliveryStatusHistory.STATUS_CHOICES).get(obj.status, obj.status)


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
            if hasattr(delivery_manager, 'delivery_profile') and delivery_manager.delivery_profile:
                if delivery_manager.delivery_profile.delivery_status != 'online':
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
                quantity=cart_item.quantity,
                unit_price=cart_item.book.price,
                total_price=cart_item.book.price * cart_item.quantity
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
            'delivery_address', 'delivery_city',
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
    Returns the exact status from BorrowRequest model to match database.
    """
    customer_name = serializers.CharField(source='customer.get_full_name', read_only=True)
    customer_email = serializers.CharField(source='customer.email', read_only=True)
    book_title = serializers.SerializerMethodField()
    book_author = serializers.SerializerMethodField()  # Add author name (pseudonym)
    status = serializers.SerializerMethodField()  # Override to return borrow_request status
    status_display = serializers.SerializerMethodField()
    available_managers = serializers.SerializerMethodField()
    request_type = serializers.SerializerMethodField()
    payment_method = serializers.SerializerMethodField()
    borrow_request = serializers.SerializerMethodField()  # Include borrow_request data
    
    class Meta:
        model = Order
        fields = [
            'id', 'order_number', 'customer_name', 'customer_email', 'book_title', 'book_author', 'delivery_address',
            'status', 'status_display', 'created_at', 'delivery_notes', 
            'available_managers', 'request_type', 'payment_method', 'borrow_request'
        ]
        read_only_fields = ['id', 'order_number', 'created_at']
    
    def get_payment_method(self, obj):
        """Get payment method from borrow request if available."""
        try:
            if hasattr(obj, 'borrow_request') and obj.borrow_request:
                return obj.borrow_request.payment_method
        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.warning(f"Error getting payment method for order {obj.id}: {str(e)}")
        return obj.payment_method if hasattr(obj, 'payment_method') else None
    
    def get_book_title(self, obj):
        """Get book title from borrow request."""
        try:
            # Check if borrow_request exists and is loaded
            if hasattr(obj, 'borrow_request') and obj.borrow_request:
                # Check if book exists and is loaded
                if hasattr(obj.borrow_request, 'book') and obj.borrow_request.book:
                    return obj.borrow_request.book.name
        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.warning(f"Error getting book title for order {obj.id}: {str(e)}")
        return None
    
    def get_book_author(self, obj):
        """Get book author name (pseudonym) from borrow request."""
        try:
            # Check if borrow_request exists and is loaded
            if hasattr(obj, 'borrow_request') and obj.borrow_request:
                # Check if book exists and is loaded
                if hasattr(obj.borrow_request, 'book') and obj.borrow_request.book:
                    # Check if author exists and is loaded
                    if hasattr(obj.borrow_request.book, 'author') and obj.borrow_request.book.author:
                        return obj.borrow_request.book.author.name
        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.warning(f"Error getting book author for order {obj.id}: {str(e)}")
        return None
    
    def get_status(self, obj):
        """Return the exact status from BorrowRequest model to match database."""
        try:
            if hasattr(obj, 'borrow_request') and obj.borrow_request:
                return obj.borrow_request.status
        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.warning(f"Error getting borrow_request status for order {obj.id}: {str(e)}")
        # Fallback to order status if borrow_request not available
        return obj.status
    
    def get_status_display(self, obj):
        """Get human-readable status from BorrowRequest."""
        try:
            if hasattr(obj, 'borrow_request') and obj.borrow_request:
                # Use the borrow_request status for display
                status = obj.borrow_request.status
            else:
                status = obj.status
        except Exception:
            status = obj.status
        
        # Return the status exactly as it appears in database (no transformation)
        # The frontend will handle display formatting
        return status
    
    def get_borrow_request(self, obj):
        """Include borrow_request data so frontend can access it."""
        try:
            if hasattr(obj, 'borrow_request') and obj.borrow_request:
                from .borrowing_serializers import BorrowRequestListSerializer
                return BorrowRequestListSerializer(obj.borrow_request).data
        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.warning(f"Error serializing borrow_request for order {obj.id}: {str(e)}")
        return None
    
    def get_request_type(self, obj):
        """Get request type."""
        return 'Borrowing'
    
    def get_available_managers(self, obj):
        """Get list of available delivery managers for this request."""
        try:
            from ..models import User
            available_managers = User.objects.filter(
                user_type='delivery_admin',
                is_active=True,
                delivery_profile__delivery_status__in=['online', 'busy'],
                delivery_profile__is_tracking_active=True
            ).select_related('delivery_profile')
            
            serializer = DeliveryManagerForRequestSerializer(available_managers, many=True)
            return serializer.data
        except Exception as e:
            # Return empty list if there's an error getting managers
            import logging
            logger = logging.getLogger(__name__)
            logger.warning(f"Error getting available managers for order {obj.id}: {str(e)}")
            return []


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
    Step 3.3: Location transmission every 5 seconds
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
    borrow_request_id = serializers.IntegerField(required=False, help_text="Optional: Link location update to a specific borrow request")
    
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


class DeliveryActivitySerializer(serializers.ModelSerializer):
    """
    Serializer for delivery activity tracking.
    """
    delivery_manager_name = serializers.CharField(source='delivery_manager.get_full_name', read_only=True)
    order_number = serializers.CharField(source='order.order_number', read_only=True)
    activity_type_display = serializers.CharField(source='get_activity_type_display', read_only=True)
    
    class Meta:
        model = DeliveryActivity
        fields = [
            'id', 'delivery_manager', 'delivery_manager_name', 'order', 'order_number',
            'activity_type', 'activity_type_display', 'activity_data', 'timestamp',
            'ip_address', 'user_agent'
        ]
        read_only_fields = ['id', 'timestamp']


class DeliveryActivityCreateSerializer(serializers.ModelSerializer):
    """
    Serializer for creating delivery activities.
    """
    class Meta:
        model = DeliveryActivity
        fields = ['order', 'activity_type', 'activity_data']
    
    def create(self, validated_data):
        """Create activity with request context."""
        request = self.context.get('request')
        if request and request.user:
            validated_data['delivery_manager'] = request.user
            validated_data['ip_address'] = self._get_client_ip(request)
            validated_data['user_agent'] = request.META.get('HTTP_USER_AGENT', '')
        
        return super().create(validated_data)
    
    def _get_client_ip(self, request):
        """Get client IP address."""
        x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
        if x_forwarded_for:
            ip = x_forwarded_for.split(',')[0]
        else:
            ip = request.META.get('REMOTE_ADDR')
        return ip


 
from django.db import models
from django.core.exceptions import ValidationError
from .user_model import User
from .payment_model import Payment
from .cart_model import Cart, CartItem
from .library_model import Book
import uuid


class Order(models.Model):
    """
    Order model for tracking customer orders.
    Created when a payment is completed successfully.
    """
    ORDER_STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('confirmed', 'Confirmed'),
        ('delivered', 'Delivered'),
        ('returned', 'Returned'),  # For borrowing returns
    ]
    
    ORDER_TYPE_CHOICES = [
        ('purchase', 'Purchase'),
        ('borrowing', 'Borrowing'),
        ('return_collection', 'Return Collection'),
    ]
    
    # Order identification
    order_number = models.CharField(
        max_length=20,
        unique=True,
        help_text="Unique order number for tracking"
    )
    
    # Customer information
    customer = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='orders',
        limit_choices_to={'user_type': 'customer'},
        help_text="Customer who placed the order"
    )
    
    # Payment information
    payment = models.OneToOneField(
        Payment,
        on_delete=models.CASCADE,
        related_name='order',
        help_text="Associated payment for this order"
    )
    
    # Order details
    total_amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        help_text="Total order amount"
    )
    
    order_type = models.CharField(
        max_length=20,
        choices=ORDER_TYPE_CHOICES,
        default='purchase',
        help_text="Type of order (purchase, borrowing, or return collection)"
    )
    
    status = models.CharField(
        max_length=25,
        choices=ORDER_STATUS_CHOICES,
        default='pending',
        help_text="Current order status"
    )
    
    # Borrowing-related fields
    borrow_request = models.ForeignKey(
        'BorrowRequest',
        on_delete=models.CASCADE,
        related_name='delivery_orders',
        null=True,
        blank=True,
        help_text="Associated borrow request (for borrowing orders)"
    )
    
    is_return_collection = models.BooleanField(
        default=False,
        help_text="Whether this order is for collecting a returned book"
    )
    
    # Delivery information (for cash on delivery)
    delivery_address = models.TextField(
        blank=True,
        null=True,
        help_text="Delivery address (required for cash on delivery)"
    )
    
    contact_phone = models.CharField(
        max_length=20,
        blank=True,
        null=True,
        help_text="Contact phone for delivery"
    )
    
    delivery_notes = models.TextField(
        blank=True,
        null=True,
        help_text="Special delivery instructions"
    )
    
    # Timestamps
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When the order was created"
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="When the order was last updated"
    )
    
    # Order fulfillment
    confirmed_at = models.DateTimeField(
        blank=True,
        null=True,
        help_text="When the order was confirmed"
    )
    
    delivered_at = models.DateTimeField(
        blank=True,
        null=True,
        help_text="When the order was delivered"
    )
    
    class Meta:
        db_table = 'order'
        verbose_name = 'Order'
        verbose_name_plural = 'Orders'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['order_number']),
            models.Index(fields=['customer']),
            models.Index(fields=['status']),
            models.Index(fields=['created_at']),
        ]
    
    def __str__(self):
        return f"Order {self.order_number} - {self.get_status_display()}"
    
    def save(self, *args, **kwargs):
        # Generate order number if not exists
        if not self.order_number:
            self.order_number = self.generate_order_number()
        super().save(*args, **kwargs)
    
    @staticmethod
    def generate_order_number():
        """Generate a unique order number."""
        import time
        timestamp = str(int(time.time()))[-8:]  # Last 8 digits of timestamp
        random_part = str(uuid.uuid4().hex)[:4].upper()
        return f"ORD{timestamp}{random_part}"
    
    def get_total_items(self):
        """Get total number of items in the order."""
        return self.items.count()
    
    def get_total_quantity(self):
        """Get total quantity of all items in the order."""
        return sum(item.quantity for item in self.items.all())
    
    def can_be_cancelled(self):
        """Check if order can be cancelled."""
        return self.status in ['pending', 'confirmed', 'preparing']
    
    def can_be_delivered(self):
        """Check if order is ready for delivery status update."""
        return self.status == 'out_for_delivery'


class OrderItem(models.Model):
    """
    Individual item in an order.
    Stores a snapshot of the book details at the time of order.
    """
    order = models.ForeignKey(
        Order,
        on_delete=models.CASCADE,
        related_name='items',
        help_text="Order this item belongs to"
    )
    
    book = models.ForeignKey(
        Book,
        on_delete=models.CASCADE,
        related_name='order_items',
        help_text="Book ordered"
    )
    
    # Snapshot of book details at time of order
    book_name = models.CharField(
        max_length=255,
        help_text="Book name at time of order"
    )
    
    book_price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        help_text="Book price at time of order"
    )
    
    quantity = models.PositiveIntegerField(
        help_text="Quantity ordered"
    )
    
    subtotal = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        help_text="Subtotal for this item (price * quantity)"
    )
    
    class Meta:
        db_table = 'order_item'
        verbose_name = 'Order Item'
        verbose_name_plural = 'Order Items'
    
    def __str__(self):
        return f"{self.quantity} x {self.book_name} in {self.order.order_number}"
    
    def save(self, *args, **kwargs):
        # Calculate subtotal automatically
        if not self.subtotal:
            self.subtotal = self.book_price * self.quantity
        super().save(*args, **kwargs)


class DeliveryAssignment(models.Model):
    """
    Delivery assignment model for tracking orders assigned to delivery managers.
    """
    ASSIGNMENT_STATUS_CHOICES = [
        ('assigned', 'Assigned'),
        ('picked_up', 'Picked Up'),
        ('delivered', 'Delivered'),
        ('collected', 'Collected'),  # For return collections
    ]
    
    # Assignment details
    order = models.OneToOneField(
        Order,
        on_delete=models.CASCADE,
        related_name='delivery_assignment',
        help_text="Order assigned for delivery"
    )
    
    delivery_manager = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='delivery_assignments',
        limit_choices_to={'user_type': 'delivery_admin'},
        help_text="Delivery manager assigned to this order"
    )
    
    # Assignment status
    status = models.CharField(
        max_length=20,
        choices=ASSIGNMENT_STATUS_CHOICES,
        default='assigned',
        help_text="Current assignment status"
    )
    
    # Assignment details
    assigned_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When the assignment was created"
    )
    
    accepted_at = models.DateTimeField(
        blank=True,
        null=True,
        help_text="When the delivery manager accepted the assignment"
    )
    
    picked_up_at = models.DateTimeField(
        blank=True,
        null=True,
        help_text="When the order was picked up for delivery"
    )
    
    delivered_at = models.DateTimeField(
        blank=True,
        null=True,
        help_text="When the order was delivered"
    )
    
    collected_at = models.DateTimeField(
        blank=True,
        null=True,
        help_text="When the book was collected for return"
    )
    
    # Delivery notes and updates
    delivery_notes = models.TextField(
        blank=True,
        null=True,
        help_text="Delivery manager's notes"
    )
    
    estimated_delivery_time = models.DateTimeField(
        blank=True,
        null=True,
        help_text="Estimated delivery time"
    )
    
    # Contact information for customer communication
    contact_phone = models.CharField(
        max_length=20,
        blank=True,
        null=True,
        help_text="Contact phone for delivery representative"
    )
    
    actual_delivery_time = models.DateTimeField(
        blank=True,
        null=True,
        help_text="Actual delivery time"
    )
    
    # Failed delivery information
    failure_reason = models.TextField(
        blank=True,
        null=True,
        help_text="Reason for delivery failure"
    )
    
    retry_count = models.PositiveIntegerField(
        default=0,
        help_text="Number of delivery attempts"
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="When the assignment was last updated"
    )
    
    class Meta:
        db_table = 'delivery_assignment'
        verbose_name = 'Delivery Assignment'
        verbose_name_plural = 'Delivery Assignments'
        ordering = ['-assigned_at']
        indexes = [
            models.Index(fields=['delivery_manager']),
            models.Index(fields=['status']),
            models.Index(fields=['assigned_at']),
        ]
    
    def __str__(self):
        return f"Delivery of {self.order.order_number} to {self.delivery_manager.get_full_name()}"
    
    def clean(self):
        """Validate assignment constraints."""
        # Check if delivery manager is actually a delivery admin
        if self.delivery_manager and not self.delivery_manager.is_delivery_admin():
            raise ValidationError("Only delivery administrators can be assigned deliveries.")
        
        # Check if order is in appropriate status for assignment
        if self.order and self.order.status not in ['ready_for_delivery', 'assigned_to_delivery', 'out_for_delivery']:
            raise ValidationError("Order must be ready for delivery to create assignment.")
    
    def can_be_updated_by(self, user):
        """Check if user can update this assignment."""
        return (user.is_delivery_admin() and 
                (self.delivery_manager == user or user.is_staff))
    
    def get_delivery_duration(self):
        """Calculate delivery duration if completed."""
        if self.picked_up_at and self.delivered_at:
            return self.delivered_at - self.picked_up_at
        return None


class DeliveryStatusHistory(models.Model):
    """
    Track status changes for delivery assignments.
    """
    assignment = models.ForeignKey(
        DeliveryAssignment,
        on_delete=models.CASCADE,
        related_name='status_history',
        help_text="Delivery assignment this status update belongs to"
    )
    
    previous_status = models.CharField(
        max_length=20,
        choices=DeliveryAssignment.ASSIGNMENT_STATUS_CHOICES,
        help_text="Previous assignment status"
    )
    
    new_status = models.CharField(
        max_length=20,
        choices=DeliveryAssignment.ASSIGNMENT_STATUS_CHOICES,
        help_text="New assignment status"
    )
    
    updated_by = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='delivery_status_updates',
        help_text="User who updated the status"
    )
    
    notes = models.TextField(
        blank=True,
        null=True,
        help_text="Notes about the status change"
    )
    
    updated_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When the status was updated"
    )
    
    class Meta:
        db_table = 'delivery_status_history'
        verbose_name = 'Delivery Status History'
        verbose_name_plural = 'Delivery Status Histories'
        ordering = ['-updated_at']
    
    def __str__(self):
        return f"{self.assignment.order.order_number}: {self.previous_status} → {self.new_status}" 


class DeliveryRequest(models.Model):
    """
    Model for customer delivery requests with simplified status system.
    """
    REQUEST_STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('in_operation', 'In Operation'),
        ('delivered', 'Delivered'),
    ]
    
    # Request identification
    request_number = models.CharField(
        max_length=20,
        unique=True,
        help_text="Unique request number for tracking"
    )
    
    # Customer information
    customer = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='delivery_requests',
        limit_choices_to={'user_type': 'customer'},
        help_text="Customer who created the request"
    )
    
    # Delivery information
    delivery_address = models.TextField(
        help_text="Delivery address for the request"
    )
    
    contact_phone = models.CharField(
        max_length=20,
        help_text="Contact phone for delivery"
    )
    
    delivery_notes = models.TextField(
        blank=True,
        null=True,
        help_text="Special delivery instructions"
    )
    
    preferred_delivery_date = models.DateField(
        blank=True,
        null=True,
        help_text="Customer's preferred delivery date"
    )
    
    # Status information
    status = models.CharField(
        max_length=20,
        choices=REQUEST_STATUS_CHOICES,
        default='pending',
        help_text="Current request status"
    )
    
    # Assignment information
    delivery_manager = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        related_name='assigned_requests',
        limit_choices_to={'user_type': 'delivery_admin'},
        null=True,
        blank=True,
        help_text="Delivery manager assigned to this request"
    )
    
    assigned_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        related_name='manager_assignments',
        limit_choices_to={'user_type': 'library_admin'},
        null=True,
        blank=True,
        help_text="Library manager who assigned this request"
    )
    
    # Timestamps
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When the request was created"
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="When the request was last updated"
    )
    
    assigned_at = models.DateTimeField(
        blank=True,
        null=True,
        help_text="When the request was assigned to a manager"
    )
    
    delivered_at = models.DateTimeField(
        blank=True,
        null=True,
        help_text="When the request was delivered"
    )
    
    class Meta:
        db_table = 'delivery_request'
        verbose_name = 'Delivery Request'
        verbose_name_plural = 'Delivery Requests'
        ordering = ['-created_at']
    
    def __str__(self):
        return f"Request {self.request_number} - {self.get_status_display()}"
    
    def save(self, *args, **kwargs):
        # Generate request number if not exists
        if not self.request_number:
            self.request_number = self.generate_request_number()
        super().save(*args, **kwargs)
    
    @staticmethod
    def generate_request_number():
        """Generate a unique request number."""
        import time
        import uuid
        timestamp = str(int(time.time()))[-8:]  # Last 8 digits of timestamp
        random_part = str(uuid.uuid4().hex)[:4].upper()
        return f"REQ{timestamp}{random_part}"
    
    @staticmethod
    def get_available_delivery_managers():
        """
        Get a list of delivery managers who are available to deliver requests.
        A delivery manager is available if:
        1. They are active
        2. They are online (delivery_status = 'online')
        3. They are not currently delivering any requests (no in_operation assignments)
        """
        from django.db.models import Q
        return User.objects.filter(
            user_type='delivery_admin',
            is_active=True,
            delivery_status='online'
        ).exclude(
            Q(delivery_assignments__status__in=['assigned', 'accepted', 'picked_up', 'in_transit']) |
            Q(assigned_requests__status='in_operation')
        ).distinct()


 
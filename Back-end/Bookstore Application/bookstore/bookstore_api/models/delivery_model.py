from django.db import models
from django.core.exceptions import ValidationError
from .user_model import User
from .payment_model import Payment
from .cart_model import Cart, CartItem
from .library_model import Book
import uuid
from django.utils import timezone


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
    
    # Discount information
    original_amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Original order amount before discount"
    )
    
    discount_code = models.CharField(
        max_length=50,
        null=True,
        blank=True,
        help_text="Discount code applied to this order"
    )
    
    discount_amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0.00,
        help_text="Discount amount applied"
    )
    
    discount_percentage = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Discount percentage applied"
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
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='orders',
        help_text="Associated borrow request if this is a borrowing order"
    )
    
    # Delivery information
    delivery_address = models.TextField(
        help_text="Delivery address for the order"
    )
    
    delivery_city = models.CharField(
        max_length=100,
        help_text="City for delivery"
    )
    
    delivery_notes = models.TextField(
        blank=True,
        null=True,
        help_text="Additional delivery instructions"
    )
    
    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'order'
        verbose_name = 'Order'
        verbose_name_plural = 'Orders'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['order_number']),
            models.Index(fields=['customer']),
            models.Index(fields=['status']),
            models.Index(fields=['order_type']),
            models.Index(fields=['created_at']),
        ]
    
    def __str__(self):
        return f"Order {self.order_number} - {self.customer.get_full_name()}"
    
    def save(self, *args, **kwargs):
        """Override save to generate order number if not set."""
        if not self.order_number:
            self.order_number = self.generate_order_number()
        super().save(*args, **kwargs)
    
    def generate_order_number(self):
        """Generate a unique order number."""
        import uuid
        return f"ORD-{uuid.uuid4().hex[:8].upper()}"
    
    def restore_book_quantities(self):
        """Restore book quantities when order is cancelled or returned."""
        for item in self.items.all():
            book = item.book
            if book.availableCopies is not None:
                book.availableCopies += item.quantity
            if book.quantity is not None:
                book.quantity += item.quantity
            book.save(update_fields=['availableCopies', 'quantity'])
    
    def update_book_quantities(self):
        """Update book quantities when order is confirmed."""
        for item in self.items.all():
            book = item.book
            if book.availableCopies is not None:
                book.availableCopies = max(0, book.availableCopies - item.quantity)
            if book.quantity is not None:
                book.quantity = max(0, book.quantity - item.quantity)
            book.save(update_fields=['availableCopies', 'quantity'])
    
    def can_be_delivered(self):
        """Check if the order can be delivered."""
        return self.status in ['pending', 'confirmed']
    
    def can_be_returned(self):
        """Check if the order can be returned (for borrowing)."""
        return self.order_type == 'borrowing' and self.status == 'delivered'
    
    @classmethod
    def get_pending_orders(cls):
        """Get all pending orders."""
        return cls.objects.filter(status='pending')
    
    @classmethod
    def get_confirmed_orders(cls):
        """Get all confirmed orders."""
        return cls.objects.filter(status='confirmed')
    
    @classmethod
    def get_delivered_orders(cls):
        """Get all delivered orders."""
        return cls.objects.filter(status='delivered')
    
    @classmethod
    def get_order_stats(cls):
        """
        Get statistics about orders.
        """
        total_orders = cls.objects.count()
        pending_orders = cls.objects.filter(status='pending').count()
        confirmed_orders = cls.objects.filter(status='confirmed').count()
        delivered_orders = cls.objects.filter(status='delivered').count()
        
        return {
            'total_orders': total_orders,
            'pending_orders': pending_orders,
            'confirmed_orders': confirmed_orders,
            'delivered_orders': delivered_orders,
        }


class OrderItem(models.Model):
    """
    Individual items within an order.
    """
    order = models.ForeignKey(
        Order,
        on_delete=models.CASCADE,
        related_name='items',
        help_text="Order this item belongs to"
    )
    
    book = models.ForeignKey(
        Book,
        on_delete=models.PROTECT,
        help_text="Book in this order item"
    )
    
    quantity = models.PositiveIntegerField(
        default=1,
        help_text="Quantity of the book"
    )
    
    unit_price = models.DecimalField(
        max_digits=8,
        decimal_places=2,
        help_text="Price per unit"
    )
    
    total_price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        help_text="Total price for this item"
    )
    
    class Meta:
        db_table = 'order_item'
        verbose_name = 'Order Item'
        verbose_name_plural = 'Order Items'
        unique_together = ['order', 'book']
    
    def __str__(self):
        return f"{self.quantity}x {self.book.name} in {self.order}"
    
    def save(self, *args, **kwargs):
        """Override save to calculate total price."""
        self.total_price = self.unit_price * self.quantity
        super().save(*args, **kwargs)


class DeliveryAssignment(models.Model):
    """
    Assignment of delivery personnel to orders.
    """
    order = models.OneToOneField(
        Order,
        on_delete=models.CASCADE,
        related_name='delivery_assignment',
        help_text="Order to be delivered"
    )
    
    delivery_person = models.ForeignKey(
        User,
        on_delete=models.PROTECT,
        limit_choices_to={'user_type': 'delivery_admin'},
        related_name='delivery_assignments',
        help_text="Delivery personnel assigned to this order"
    )
    
    assigned_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When the assignment was made"    
    )
    
    estimated_delivery_time = models.DateTimeField(
        help_text="Estimated delivery time"
    )
    
    actual_delivery_time = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Actual delivery time"
    )
    
    delivery_notes = models.TextField(
        blank=True,
        null=True,
        help_text="Notes from delivery personnel"
    )
    
    class Meta:
        db_table = 'delivery_assignment'
        verbose_name = 'Delivery Assignment'
        verbose_name_plural = 'Delivery Assignments'
        ordering = ['-assigned_at']
    
    def __str__(self):
        return f"Delivery of {self.order} by {self.delivery_person.get_full_name()}"
    
    def is_delivered(self):
        """Check if the delivery is completed."""
        return self.actual_delivery_time is not None
    
    def is_overdue(self):
        """Check if the delivery is overdue."""
        if not self.is_delivered():
            return timezone.now() > self.estimated_delivery_time
        return False
    
    def mark_as_delivered(self, notes=None):
        """Mark the delivery as completed."""
        self.actual_delivery_time = timezone.now()
        if notes:
            self.delivery_notes = notes
        self.save()
        
        # Update order status
        self.order.status = 'delivered'
        self.order.save()


class DeliveryStatusHistory(models.Model):
    """
    History of delivery status changes.
    """
    delivery_assignment = models.ForeignKey(
        DeliveryAssignment,
        on_delete=models.CASCADE,
        related_name='status_history',
        help_text="Delivery assignment this status belongs to"
    )
    
    STATUS_CHOICES = [
        ('assigned', 'Assigned'),
        ('picked_up', 'Picked Up'),
        ('in_transit', 'In Transit'),
        ('out_for_delivery', 'Out for Delivery'),
        ('delivered', 'Delivered'),
        ('failed', 'Delivery Failed'),
    ]
    
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        help_text="Delivery status"
    )
    
    notes = models.TextField(
        blank=True,
        null=True,
        help_text="Additional notes about this status"
    )
    
    timestamp = models.DateTimeField(
        auto_now_add=True,
        help_text="When this status was recorded"
    )
    
    class Meta:
        db_table = 'delivery_status_history'
        verbose_name = 'Delivery Status History'
        verbose_name_plural = 'Delivery Status Histories'
        ordering = ['timestamp']
    
    def __str__(self):
        return f"{self.delivery_assignment} - {self.get_status_display()} at {self.timestamp}"


class DeliveryRequest(models.Model):
    """
    Request for delivery service.
    """
    customer = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='delivery_requests',
        limit_choices_to={'user_type': 'customer'},
        help_text="Customer requesting delivery"
    )
    
    REQUEST_TYPE_CHOICES = [
        ('pickup', 'Pickup Request'),
        ('delivery', 'Delivery Request'),
        ('return', 'Return Request'),
    ]
    
    request_type = models.CharField(
        max_length=20,
        choices=REQUEST_TYPE_CHOICES,
        help_text="Type of delivery request"
    )
    
    pickup_address = models.TextField(
        help_text="Address for pickup"
    )
    
    delivery_address = models.TextField(
        help_text="Address for delivery"
    )
    
    pickup_city = models.CharField(
        max_length=100,
        help_text="City for pickup"
    )
    
    delivery_city = models.CharField(
        max_length=100,
        help_text="City for delivery"
    )
    
    preferred_pickup_time = models.DateTimeField(
        help_text="Preferred pickup time"
    )
    
    preferred_delivery_time = models.DateTimeField(
        help_text="Preferred delivery time"
    )
    
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('assigned', 'Assigned'),
        ('in_progress', 'In Progress'),
        ('completed', 'Completed'),
        ('cancelled', 'Cancelled'),
    ]
    
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='pending',
        help_text="Current status of the request"
    )
    
    notes = models.TextField(
        blank=True,
        null=True,
        help_text="Additional notes about the request"
    )
    
    # Delivery manager assignment
    delivery_manager = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='assigned_requests',
        limit_choices_to={'user_type': 'delivery_admin'},
        help_text="Delivery manager assigned to this request"
    )
    
    # Assignment tracking
    assigned_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='assigned_delivery_requests',
        help_text="User who assigned the delivery manager"
    )
    
    assigned_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When the request was assigned to a delivery manager"
    )
    
    delivered_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When the delivery was completed"
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'delivery_request'
        verbose_name = 'Delivery Request'
        verbose_name_plural = 'Delivery Requests'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['customer']),
            models.Index(fields=['request_type']),
            models.Index(fields=['status']),
            models.Index(fields=['created_at']),
        ]
    
    def __str__(self):
        return f"{self.get_request_type_display()} for {self.customer.get_full_name()}"
    
    def can_be_assigned(self):
        """Check if the request can be assigned to delivery personnel."""
        return self.status == 'pending'
    
    def can_be_cancelled(self):
        """Check if the request can be cancelled."""
        return self.status in ['pending', 'assigned']
    
    @classmethod
    def get_pending_requests(cls):
        """Get all pending delivery requests."""
        return cls.objects.filter(status='pending')
    
    @classmethod
    def get_request_stats(cls):
        """
        Get statistics about delivery requests.
        """
        total_requests = cls.objects.count()
        pending_requests = cls.objects.filter(status='pending').count()
        in_progress_requests = cls.objects.filter(status='in_progress').count()
        completed_requests = cls.objects.filter(status='completed').count()
        
        return {
            'total_requests': total_requests,
            'pending_requests': pending_requests,
            'in_progress_requests': in_progress_requests,
            'completed_requests': completed_requests,
        }
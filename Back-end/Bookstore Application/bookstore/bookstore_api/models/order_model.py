from django.db import models
from django.core.validators import MinValueValidator
from .user_model import User
from .payment_model import Payment


class Order(models.Model):
    """
    Order model for purchase orders.
    """
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('confirmed', 'Confirmed'),
        ('processing', 'Processing'),
        ('delivered', 'Delivered'),
        ('cancelled', 'Cancelled'),
    ]
    
    ORDER_TYPE_CHOICES = [
        ('purchase', 'Purchase'),
        ('borrowing', 'Borrowing'),
    ]
    
    # Order identification
    order_number = models.CharField(
        max_length=50,
        unique=True,
        help_text="Unique order number"
    )
    
    # Customer
    customer = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='orders',
        limit_choices_to={'user_type': 'customer'},
        help_text="Customer who placed the order"
    )
    
    # Order details
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='pending',
        help_text="Current order status"
    )
    
    order_type = models.CharField(
        max_length=20,
        choices=ORDER_TYPE_CHOICES,
        default='purchase',
        help_text="Type of order"
    )
    
    # Payment reference
    payment = models.ForeignKey(
        Payment,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='orders',
        help_text="Payment associated with this order"
    )
    
    # Borrow request reference (for borrowing orders)
    borrow_request = models.ForeignKey(
        'BorrowRequest',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='orders',
        help_text="Borrow request associated with this order (for borrowing type orders)"
    )
    
    # Financial information
    total_amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        validators=[MinValueValidator(0.01)],
        help_text="Total order amount"
    )
    
    delivery_cost = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0.00,
        help_text="Delivery cost"
    )
    
    tax_amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0.00,
        help_text="Tax amount"
    )
    
    discount_amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0.00,
        help_text="Discount amount applied"
    )
    
    # Address information (stored as JSON or text)
    delivery_address = models.TextField(
        default='',
        blank=True,
        help_text="Delivery address"
    )
    
    billing_address = models.TextField(
        blank=True,
        null=True,
        help_text="Billing address"
    )
    
    # Additional information
    notes = models.TextField(
        blank=True,
        null=True,
        help_text="Order notes"
    )
    
    cancellation_reason = models.TextField(
        blank=True,
        null=True,
        help_text="Reason for cancellation if cancelled"
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
        return f"Order {self.order_number} - {self.customer.get_full_name()} ({self.get_status_display()})"
    
    def save(self, *args, **kwargs):
        """Override save to generate order number if not set."""
        if not self.order_number:
            self.order_number = self.generate_order_number()
        super().save(*args, **kwargs)
    
    def generate_order_number(self):
        """Generate a unique order number."""
        import uuid
        import time
        timestamp = str(int(time.time()))[-8:]
        random_part = str(uuid.uuid4().hex)[:6].upper()
        prefix = 'BR' if self.order_type == 'borrowing' else 'ORD'
        return f"{prefix}{timestamp}{random_part}"


class OrderItem(models.Model):
    """
    Order item model representing individual items in an order.
    """
    order = models.ForeignKey(
        Order,
        on_delete=models.CASCADE,
        related_name='items',
        help_text="Order this item belongs to"
    )
    
    book = models.ForeignKey(
        'Book',
        on_delete=models.CASCADE,
        related_name='order_items',
        help_text="Book in this order"
    )
    
    quantity = models.PositiveIntegerField(
        validators=[MinValueValidator(1)],
        help_text="Quantity ordered"
    )
    
    price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0.00,
        validators=[MinValueValidator(0.01)],
        help_text="Price per unit at time of order"
    )
    
    created_at = models.DateTimeField(auto_now_add=True, null=True, blank=True)
    
    class Meta:
        db_table = 'order_item'
        verbose_name = 'Order Item'
        verbose_name_plural = 'Order Items'
        indexes = [
            models.Index(fields=['order']),
            models.Index(fields=['book']),
        ]
    
    def __str__(self):
        return f"{self.quantity}x {self.book.title} - Order {self.order.order_number}"
    
    @property
    def total_price(self):
        """Calculate total price for this item."""
        return self.price * self.quantity


# Placeholder models for compatibility
class DeliveryActivity(models.Model):
    """Placeholder model for delivery activity tracking."""
    class Meta:
        managed = False
        db_table = 'delivery_activity'


class OrderNote(models.Model):
    """Placeholder model for order notes."""
    class Meta:
        managed = False
        db_table = 'order_note'


class Delivery(models.Model):
    """Placeholder model for delivery."""
    class Meta:
        managed = False
        db_table = 'delivery'


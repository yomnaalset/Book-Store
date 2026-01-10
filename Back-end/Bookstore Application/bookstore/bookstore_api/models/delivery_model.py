from django.db import models
from django.core.exceptions import ValidationError
from .user_model import User

# Note: This file should also contain Order, OrderItem, DeliveryActivity, OrderNote, Delivery models
# If those are missing, they need to be restored from backup or recreated


class DeliveryRequest(models.Model):
    """
    Unified Delivery Request model for all delivery types.
    Supports Purchase Delivery, Borrowing Delivery, and Returned Book Pickup.
    This is the single source of truth for all delivery operations.
    """
    
    # Delivery Type Choices
    DELIVERY_TYPE_CHOICES = [
        ('purchase', 'Purchase Delivery'),
        ('borrow', 'Borrowing Delivery'),
        ('return', 'Returned Book Pickup'),
    ]
    
    # Delivery Status Choices
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('assigned', 'Assigned'),
        ('accepted', 'Accepted'),
        ('in_delivery', 'In Delivery'),
        ('completed', 'Completed'),
        ('rejected', 'Rejected'),
    ]
    
    # Delivery Type
    delivery_type = models.CharField(
        max_length=20,
        choices=DELIVERY_TYPE_CHOICES,
        default='purchase',
        help_text="Type of delivery: purchase, borrow, or return"
    )
    
    # Delivery Status
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='pending',
        help_text="Current delivery status"
    )
    
    # Customer
    customer = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='delivery_requests',
        limit_choices_to={'user_type': 'customer'},
        help_text="Customer requesting delivery"
    )
    
    # Delivery Manager
    delivery_manager = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='assigned_delivery_requests',
        limit_choices_to={'user_type': 'delivery_admin'},
        help_text="Delivery manager assigned to this request"
    )
    
    # Relations to different entity types (only one should be set based on delivery_type)
    # Using string references to avoid circular imports
    order = models.ForeignKey(
        'Order',
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='delivery_requests',
        help_text="Associated order for purchase deliveries"
    )
    
    borrow_request = models.ForeignKey(
        'bookstore_api.BorrowRequest',
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='delivery_requests',
        help_text="Associated borrow request for borrowing deliveries"
    )
    
    return_request = models.ForeignKey(
        'bookstore_api.ReturnRequest',
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='delivery_requests',
        help_text="Associated return request for return pickups"
    )
    
    # Rejection Reason
    rejection_reason = models.TextField(
        blank=True,
        null=True,
        help_text="Reason for rejection when status is rejected"
    )
    
    # Location Data (Optional - for GPS tracking)
    latitude = models.DecimalField(
        max_digits=10,
        decimal_places=7,
        null=True,
        blank=True,
        help_text="Latitude coordinate for delivery location"
    )
    
    longitude = models.DecimalField(
        max_digits=10,
        decimal_places=7,
        null=True,
        blank=True,
        help_text="Longitude coordinate for delivery location"
    )
    
    # Delivery Address
    delivery_address = models.TextField(
        default='',
        blank=True,
        help_text="Delivery address for the request"
    )
    
    delivery_city = models.CharField(
        max_length=100,
        blank=True,
        null=True,
        help_text="City for delivery"
    )
    
    # Timestamps
    assigned_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When the delivery manager was assigned"
    )
    
    accepted_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When the delivery manager accepted the request"
    )
    
    rejected_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When the request was rejected"
    )
    
    started_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When delivery was started"
    )
    
    start_notes = models.TextField(
        blank=True,
        null=True,
        help_text="Notes added when starting delivery"
    )
    
    completed_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When delivery was completed"
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'delivery_request'
        verbose_name = 'Delivery Request'
        verbose_name_plural = 'Delivery Requests'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['delivery_type']),
            models.Index(fields=['status']),
            models.Index(fields=['customer']),
            models.Index(fields=['delivery_manager']),
            models.Index(fields=['order']),
            models.Index(fields=['borrow_request']),
            models.Index(fields=['return_request']),
            models.Index(fields=['created_at']),
        ]
    
    def __str__(self):
        return f"{self.get_delivery_type_display()} - {self.get_status_display()} - {self.customer.get_full_name()}"
    
    def clean(self):
        """Validate that the correct entity is set based on delivery_type."""
        if self.delivery_type == 'purchase' and not self.order:
            raise ValidationError("Order must be set for purchase deliveries.")
        if self.delivery_type == 'borrow' and not self.borrow_request:
            raise ValidationError("BorrowRequest must be set for borrowing deliveries.")
        if self.delivery_type == 'return' and not self.return_request:
            raise ValidationError("ReturnRequest must be set for return pickups.")
    
    def save(self, *args, **kwargs):
        """Override save to validate entity consistency and enforce status rules."""
        # CRITICAL: Enforce status rule - if delivery_manager is assigned, status cannot be 'pending'
        # This prevents invalid states from being saved
        if self.delivery_manager and self.status == 'pending':
            self.status = 'assigned'
            # Set assigned_at if not already set
            if not self.assigned_at:
                from django.utils import timezone
                self.assigned_at = timezone.now()
        
        self.full_clean()
        super().save(*args, **kwargs)
    
    def get_related_entity(self):
        """Get the related entity based on delivery_type."""
        if self.delivery_type == 'purchase':
            return self.order
        elif self.delivery_type == 'borrow':
            return self.borrow_request
        elif self.delivery_type == 'return':
            return self.return_request
        return None


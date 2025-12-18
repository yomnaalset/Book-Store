from django.db import models
from django.core.exceptions import ValidationError
from django.db.models.signals import post_save
from django.dispatch import receiver
from .user_model import User
from .payment_model import Payment
from .cart_model import Cart, CartItem
from .library_model import Book
import uuid
from django.utils import timezone
import logging

logger = logging.getLogger(__name__)


class Order(models.Model):
    """
    Order model for tracking customer orders.
    Created when a payment is completed successfully.
    """
    ORDER_STATUS_CHOICES = [
        ('pending', 'Pending Review'),
        ('rejected_by_admin', 'Rejected by Admin'),
        ('waiting_for_delivery_manager', 'Waiting for Delivery Manager'),
        ('rejected_by_delivery_manager', 'Rejected by Delivery Manager'),
        ('in_delivery', 'In Delivery'),
        ('completed', 'Completed'),
        ('approved', 'Approved'),
        ('assigned', 'Assigned'),
        ('accepted', 'Accepted'),
        ('in_progress', 'InProgress'),
        ('confirmed', 'Confirmed'),
        ('assigned_to_delivery', 'Assigned to Delivery'),
        ('delivery_in_progress', 'Delivery In Progress'),
        ('delivery_rejected', 'Delivery Rejected'),
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
        null=True,
        blank=True,
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
    
    delivery_cost = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0.00,
        help_text="Delivery cost (4% of final invoice value)"
    )
    
    order_type = models.CharField(
        max_length=20,
        choices=ORDER_TYPE_CHOICES,
        default='purchase',
        help_text="Type of order (purchase, borrowing, or return collection)"
    )
    
    # Payment method used for this order
    payment_method = models.CharField(
        max_length=20,
        choices=[
            ('cash', 'Cash on Delivery'),
            ('mastercard', 'Mastercard'),
        ],
        default='cash',
        help_text="Payment method used for this order"
    )
    
    status = models.CharField(
        max_length=30,
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
    
    # Cancellation information
    cancellation_reason = models.TextField(
        blank=True,
        null=True,
        help_text="Reason for order cancellation"
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
            if book.available_copies is not None:
                book.available_copies += item.quantity
            if book.quantity is not None:
                book.quantity += item.quantity
            book.save(update_fields=['available_copies', 'quantity'])
    
    def update_book_quantities(self):
        """Update book quantities when order is confirmed."""
        for item in self.items.all():
            book = item.book
            if book.available_copies is not None:
                book.available_copies = max(0, book.available_copies - item.quantity)
            if book.quantity is not None:
                book.quantity = max(0, book.quantity - item.quantity)
            book.save(update_fields=['available_copies', 'quantity'])
    
    def can_be_delivered(self):
        """Check if the order can be delivered."""
        return self.status in ['pending', 'confirmed']
    
    def can_be_cancelled(self):
        """Check if the order can be cancelled."""
        return self.status in ['pending', 'confirmed']
    
    def get_total_items(self):
        """Get total number of different items in the order."""
        return self.items.count()
    
    def get_total_quantity(self):
        """Get total quantity of all items in the order."""
        return sum(item.quantity for item in self.items.all())
    
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


@receiver(post_save, sender=Order)
def reset_delivery_status_on_order_completion(sender, instance, created, **kwargs):
    """
    Signal handler to automatically reset delivery manager status when order is completed/delivered.
    This is a safety mechanism to ensure status is always correct.
    """
    # Only process updates (not new orders) and only for completed/delivered status
    if created:
        return
    
    if instance.status in ['completed', 'delivered']:
        try:
            # Check if order has a delivery assignment
            if hasattr(instance, 'delivery_request') and instance.delivery_request:
                delivery_manager = instance.delivery_request.delivery_manager
                if delivery_manager and delivery_manager.is_delivery_admin():
                    from ..services.delivery_profile_services import DeliveryProfileService
                    DeliveryProfileService.complete_delivery_task(
                        delivery_manager,
                        completed_order_id=instance.id
                    )
                    logger.info(
                        f"Signal: Auto-reset delivery manager {delivery_manager.id} status "
                        f"after order {instance.order_number} was marked as {instance.status}"
                    )
        except Exception as e:
            logger.error(f"Signal error resetting delivery status for order {instance.id}: {str(e)}")


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


# NOTE: DeliveryAssignment model is temporarily kept for migration state resolution
# It will be removed after all migrations are applied
class DeliveryAssignment(models.Model):
    """
    Temporary model for migration state resolution.
    This model is managed=False and will be removed after migrations complete.
    """
    class Meta:
        db_table = 'delivery_assignment'
        verbose_name = 'Delivery Assignment'
        verbose_name_plural = 'Delivery Assignments'
        managed = False  # Don't manage this model - it's only for migration state


# NOTE: DeliveryStatusHistory model has been merged into DeliveryActivity.
# The model definition is removed - migration 0013 handles the data migration and table deletion.
# STATUS_CHOICES are now available in DeliveryActivity.STATUS_CHOICES


class OrderNote(models.Model):
    """
    Model to track notes added to orders with author and timestamp information.
    Each note entry tracks who wrote it and when.
    """
    order = models.ForeignKey(
        Order,
        on_delete=models.CASCADE,
        related_name='notes',
        help_text="Order this note belongs to"
    )
    
    author = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        related_name='order_notes',
        help_text="User who wrote this note"
    )
    
    content = models.TextField(
        help_text="Note content"
    )
    
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When the note was created"
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="When the note was last updated"
    )
    
    is_deleted = models.BooleanField(
        default=False,
        help_text="Whether this note has been deleted (soft delete)"
    )
    
    class Meta:
        db_table = 'order_note'
        verbose_name = 'Order Note'
        verbose_name_plural = 'Order Notes'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['order', 'is_deleted']),
            models.Index(fields=['author']),
            models.Index(fields=['created_at']),
        ]
    
    def __str__(self):
        author_name = self.author.get_full_name() if self.author else "Unknown"
        return f"Note by {author_name} on Order {self.order.order_number}"


class DeliveryRequest(models.Model):
    """
    Unified model for delivery requests and assignments.
    Merges delivery_request and delivery_assignment into a single source of truth.
    """
    customer = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='delivery_requests',
        limit_choices_to={'user_type': 'customer'},
        help_text="Customer requesting delivery"
    )
    
    # Order reference (OneToOne for order deliveries, nullable for standalone requests)
    # Changed from ForeignKey to OneToOneField to match DeliveryAssignment structure
    order = models.OneToOneField(
        Order,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='delivery_request',
        help_text="Associated order if this delivery request is for a specific order (merged from DeliveryAssignment)"
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
    
    STATUS_CHOICES = [
        # Request statuses
        ('pending', 'Pending'),
        ('assigned', 'Assigned'),
        ('in_progress', 'In Progress'),
        ('completed', 'Completed'),
        ('cancelled', 'Cancelled'),
        # Assignment statuses (merged from DeliveryAssignment)
        ('accepted', 'Accepted'),
        ('picked_up', 'Picked Up'),
        ('in_transit', 'In Transit'),
        ('delivered', 'Delivered'),
    ]
    
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='pending',
        help_text="Current status of the request/assignment"
    )
    
    # Delivery manager assignment (merged from DeliveryAssignment)
    delivery_manager = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='assigned_requests',
        limit_choices_to={'user_type': 'delivery_admin'},
        help_text="Delivery manager assigned to this request/order"
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
            models.Index(fields=['order']),
            models.Index(fields=['request_type']),
            models.Index(fields=['status']),
            models.Index(fields=['delivery_manager']),
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
    
    def is_delivered(self):
        """Check if the delivery is completed."""
        return self.status in ['delivered', 'completed']
    
    def mark_as_delivered(self):
        """Mark the delivery as completed."""
        self.status = 'completed'
        if self.order:
            self.order.status = 'completed'
            self.order.save()
        self.save()
    
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
        in_progress_requests = cls.objects.filter(status__in=['in_progress', 'in_transit']).count()
        completed_requests = cls.objects.filter(status__in=['completed', 'delivered']).count()
        
        return {
            'total_requests': total_requests,
            'pending_requests': pending_requests,
            'in_progress_requests': in_progress_requests,
            'completed_requests': completed_requests,
        }


class LocationHistory(models.Model):
    """
    Model to store historical location data for delivery managers.
    Tracks movement and location changes over time.
    """
    TRACKING_TYPE_CHOICES = [
        ('manual', 'Manual Update'),
        ('gps', 'GPS Automatic'),
        ('delivery_start', 'Delivery Start'),
        ('delivery_end', 'Delivery End'),
        ('break_start', 'Break Start'),
        ('break_end', 'Break End'),
    ]
    
    # Delivery manager reference
    delivery_manager = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='location_history',
        limit_choices_to={'user_type': 'delivery_admin'},
        help_text="Delivery manager whose location is being tracked"
    )
    
    # Location data
    latitude = models.DecimalField(
        max_digits=10,
        decimal_places=7,
        help_text="Latitude coordinate"
    )
    
    longitude = models.DecimalField(
        max_digits=10,
        decimal_places=7,
        help_text="Longitude coordinate"
    )
    
    address = models.TextField(
        null=True,
        blank=True,
        help_text="Text address at this location"
    )
    
    # Tracking metadata
    tracking_type = models.CharField(
        max_length=20,
        choices=TRACKING_TYPE_CHOICES,
        default='manual',
        help_text="Type of location update"
    )
    
    accuracy = models.FloatField(
        null=True,
        blank=True,
        help_text="GPS accuracy in meters"
    )
    
    speed = models.FloatField(
        null=True,
        blank=True,
        help_text="Speed in km/h at time of recording"
    )
    
    heading = models.FloatField(
        null=True,
        blank=True,
        help_text="Direction of movement in degrees"
    )
    
    # Timestamps
    recorded_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When this location was recorded"
    )
    
    # Related delivery request (if applicable) - merged from DeliveryAssignment
    delivery_request = models.ForeignKey(
        'DeliveryRequest',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='location_updates',
        help_text="Delivery request this location update is related to (merged from DeliveryAssignment)"
    )
    
    # Additional metadata
    battery_level = models.IntegerField(
        null=True,
        blank=True,
        help_text="Device battery level at time of recording"
    )
    
    network_type = models.CharField(
        max_length=20,
        null=True,
        blank=True,
        help_text="Network type (wifi, 4g, 5g, etc.)"
    )
    
    class Meta:
        ordering = ['-recorded_at']
        indexes = [
            models.Index(fields=['delivery_manager', 'recorded_at']),
            models.Index(fields=['delivery_request', 'recorded_at']),
            models.Index(fields=['tracking_type', 'recorded_at']),
        ]
    
    def __str__(self):
        return f"{self.delivery_manager.get_full_name()} - {self.recorded_at.strftime('%Y-%m-%d %H:%M')}"
    
    def get_location_display(self):
        """Get formatted location string."""
        if self.address:
            return self.address
        return f"Lat: {self.latitude}, Lng: {self.longitude}"
    
    def get_distance_from(self, other_location):
        """Calculate distance from another location in kilometers."""
        from math import radians, cos, sin, asin, sqrt
        
        if not other_location:
            return None
            
        # Haversine formula
        lat1, lon1 = float(self.latitude), float(self.longitude)
        lat2, lon2 = float(other_location.latitude), float(other_location.longitude)
        
        # Convert decimal degrees to radians
        lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])
        
        # Haversine formula
        dlat = lat2 - lat1
        dlon = lon2 - lon1
        a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
        c = 2 * asin(sqrt(a))
        
        # Radius of earth in kilometers
        r = 6371
        return c * r
    
    @classmethod
    def get_recent_locations(cls, delivery_manager, hours=24):
        """Get recent locations for a delivery manager."""
        from django.utils import timezone
        cutoff_time = timezone.now() - timezone.timedelta(hours=hours)
        return cls.objects.filter(
            delivery_manager=delivery_manager,
            recorded_at__gte=cutoff_time
        ).order_by('-recorded_at')
    
    @classmethod
    def get_movement_summary(cls, delivery_manager, hours=24):
        """Get movement summary for a delivery manager."""
        recent_locations = cls.get_recent_locations(delivery_manager, hours)
        
        if not recent_locations.exists():
            return {
                'total_points': 0,
                'total_distance': 0,
                'average_speed': 0,
                'movement_time': 0,
            }
        
        total_distance = 0
        total_speed = 0
        speed_count = 0
        previous_location = None
        
        for location in recent_locations:
            if previous_location:
                distance = location.get_distance_from(previous_location)
                if distance:
                    total_distance += distance
            
            if location.speed is not None:
                total_speed += location.speed
                speed_count += 1
            
            previous_location = location
        
        movement_time = 0
        if recent_locations.count() > 1:
            first_location = recent_locations.last()
            last_location = recent_locations.first()
            movement_time = (last_location.recorded_at - first_location.recorded_at).total_seconds() / 3600  # hours
        
        return {
            'total_points': recent_locations.count(),
            'total_distance': round(total_distance, 2),
            'average_speed': round(total_speed / speed_count, 2) if speed_count > 0 else 0,
            'movement_time': round(movement_time, 2),
        }


class RealTimeTracking(models.Model):
    """
    Model to store real-time tracking status and settings.
    """
    delivery_manager = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name='real_time_tracking',
        limit_choices_to={'user_type': 'delivery_admin'},
        help_text="Delivery manager for real-time tracking"
    )
    
    is_tracking_enabled = models.BooleanField(
        default=False,
        help_text="Whether real-time tracking is enabled"
    )
    
    tracking_interval = models.IntegerField(
        default=30,
        help_text="Tracking interval in seconds"
    )
    
    last_location_update = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Last time location was updated"
    )
    
    is_delivering = models.BooleanField(
        default=False,
        help_text="Whether currently on a delivery"
    )
    
    current_delivery_request = models.ForeignKey(
        'DeliveryRequest',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='real_time_tracking',
        help_text="Current delivery request being tracked (merged from DeliveryAssignment)"
    )
    
    # Settings
    auto_track_deliveries = models.BooleanField(
        default=True,
        help_text="Automatically start tracking when delivery starts"
    )
    
    share_location_with_admin = models.BooleanField(
        default=True,
        help_text="Share location with library admin"
    )
    
    share_location_with_customers = models.BooleanField(
        default=True,
        help_text="Share location with customers for their orders"
    )
    
    # Privacy settings
    tracking_accuracy = models.CharField(
        max_length=20,
        choices=[
            ('high', 'High Accuracy (GPS)'),
            ('medium', 'Medium Accuracy'),
            ('low', 'Low Accuracy'),
        ],
        default='high',
        help_text="Tracking accuracy level"
    )
    
    max_tracking_duration = models.IntegerField(
        default=8,
        help_text="Maximum tracking duration in hours per day"
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        verbose_name = "Real-time Tracking"
        verbose_name_plural = "Real-time Tracking"
    
    def __str__(self):
        return f"{self.delivery_manager.get_full_name()} - Tracking: {'ON' if self.is_tracking_enabled else 'OFF'}"
    
    def can_start_tracking(self):
        """Check if tracking can be started."""
        if not self.is_tracking_enabled:
            return False, "Tracking is disabled"
        
        if self.is_delivering and not self.auto_track_deliveries:
            return False, "Auto-tracking is disabled for deliveries"
        
        return True, "Tracking can be started"
    
    def start_tracking(self, delivery_request=None):
        """Start real-time tracking."""
        can_start, message = self.can_start_tracking()
        if not can_start:
            return False, message
        
        self.is_delivering = True
        if delivery_request:
            self.current_delivery_request = delivery_request
        self.save()
        
        return True, "Tracking started successfully"
    
    def stop_tracking(self):
        """Stop real-time tracking."""
        self.is_delivering = False
        self.current_delivery_request = None
        self.save()
        
        return True, "Tracking stopped successfully"


class DeliveryActivity(models.Model):
    """
    Unified model to track all delivery activities and status changes.
    Merges delivery_activity and delivery_status_history into a single source of truth.
    """
    ACTIVITY_TYPES = [
        # General activities
        ('contact_customer', 'Contact Customer'),
        ('view_route', 'View Route'),
        ('add_notes', 'Add Notes'),
        ('edit_notes', 'Edit Notes'),
        ('delete_notes', 'Delete Notes'),
        ('update_location', 'Update Location'),
        ('start_delivery', 'Start Delivery'),
        ('complete_delivery', 'Complete Delivery'),
        ('update_eta', 'Update ETA'),
        # Status change activities (from DeliveryStatusHistory)
        ('status_change', 'Status Change'),
    ]
    
    ACTOR_TYPE_CHOICES = [
        ('delivery_manager', 'Delivery Manager'),
        ('system', 'System'),
        ('admin', 'Administrator'),
        ('customer', 'Customer'),
    ]
    
    STATUS_CHOICES = [
        ('assigned', 'Assigned'),
        ('accepted', 'Accepted'),
        ('picked_up', 'Picked Up'),
        ('in_transit', 'In Transit'),
        ('delivered', 'Delivered'),
        ('completed', 'Completed'),
        ('failed', 'Delivery Failed'),
        ('cancelled', 'Cancelled'),
    ]
    
    # Delivery assignment (optional, for status history)
    delivery_request = models.ForeignKey(
        DeliveryRequest,
        on_delete=models.CASCADE,
        related_name='activities',
        null=True,
        blank=True,
        help_text="Delivery request this activity belongs to (for status changes, merged from DeliveryAssignment)"
    )
    
    # Delivery manager (optional, for system-generated activities)
    delivery_manager = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='delivery_activities',
        limit_choices_to={'user_type': 'delivery_admin'},
        null=True,
        blank=True,
        help_text="Delivery manager who performed the activity"
    )
    
    # Order (optional, can derive from delivery_request)
    order = models.ForeignKey(
        Order,
        on_delete=models.CASCADE,
        related_name='delivery_activities',
        null=True,
        blank=True,
        help_text="Order related to this activity"
    )
    
    activity_type = models.CharField(
        max_length=50,
        choices=ACTIVITY_TYPES,
        help_text="Type of activity performed"
    )
    
    # Status change fields (for status history)
    previous_status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        null=True,
        blank=True,
        help_text="Previous delivery status (for status changes)"
    )
    
    new_status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        null=True,
        blank=True,
        help_text="New delivery status (for status changes)"
    )
    
    # Actor information
    actor_type = models.CharField(
        max_length=20,
        choices=ACTOR_TYPE_CHOICES,
        default='delivery_manager',
        help_text="Type of actor who performed this activity"
    )
    
    # Notes (from DeliveryStatusHistory)
    notes = models.TextField(
        blank=True,
        null=True,
        help_text="Additional notes about this activity or status change"
    )
    
    activity_data = models.JSONField(
        default=dict,
        blank=True,
        help_text="Additional data related to the activity"
    )
    
    timestamp = models.DateTimeField(
        auto_now_add=True,
        help_text="When the activity was performed"
    )
    
    ip_address = models.GenericIPAddressField(
        null=True,
        blank=True,
        help_text="IP address of the request"
    )
    
    user_agent = models.TextField(
        blank=True,
        help_text="User agent string from the request"
    )
    
    class Meta:
        ordering = ['-timestamp']
        verbose_name = 'Delivery Activity'
        verbose_name_plural = 'Delivery Activities'
        indexes = [
            models.Index(fields=['delivery_manager', 'timestamp']),
            models.Index(fields=['delivery_request', 'timestamp']),
            models.Index(fields=['order', 'timestamp']),
            models.Index(fields=['activity_type', 'timestamp']),
            models.Index(fields=['new_status', 'timestamp']),
            models.Index(fields=['actor_type', 'timestamp']),
        ]
    
    def clean(self):
        """
        Validate that required fields are present based on activity type.
        """
        from django.core.exceptions import ValidationError
        
        # For status changes, require delivery_request and status fields
        if self.activity_type == 'status_change':
            if not self.delivery_request:
                raise ValidationError("delivery_request is required for status_change activities.")
            if not self.new_status:
                raise ValidationError("new_status is required for status_change activities.")
            # Set order from delivery_request if not set
            if not self.order and self.delivery_request:
                self.order = self.delivery_request.order
        
        # For other activities, require either order or delivery_request
        elif not self.order and not self.delivery_request:
            raise ValidationError("Either order or delivery_request must be provided.")
        
        # Set order from delivery_request if not set
        if not self.order and self.delivery_request:
            self.order = self.delivery_request.order
    
    def save(self, *args, **kwargs):
        """Override save to ensure order is set from delivery_request if needed."""
        self.full_clean()
        super().save(*args, **kwargs)
    
    def __str__(self):
        if self.activity_type == 'status_change':
            actor = self.delivery_manager.email if self.delivery_manager else self.actor_type
            return f"{actor} - {self.previous_status} → {self.new_status} - {self.order.order_number if self.order else 'N/A'}"
        else:
            actor = self.delivery_manager.email if self.delivery_manager else self.actor_type
            order_num = self.order.order_number if self.order else 'N/A'
            return f"{actor} - {self.get_activity_type_display()} - {order_num}"
from django.db import models
from django.utils import timezone
from .user_model import User
from .delivery_model import Order


class NotificationType(models.TextChoices):
    ORDER_DELIVERED = 'ORDER_DELIVERED', 'Order Delivered'
    ORDER_ACCEPTED = 'ORDER_ACCEPTED', 'Order Accepted'
    DELIVERY_ASSIGNED = 'DELIVERY_ASSIGNED', 'Delivery Representative Assigned'
    DELIVERY_TIME_UPDATED = 'DELIVERY_TIME_UPDATED', 'Delivery Time Updated'
    # Add more notification types as needed


class Notification(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='notifications')
    title = models.CharField(max_length=255)
    message = models.TextField()
    notification_type = models.CharField(
        max_length=50,
        choices=NotificationType.choices,
        default=NotificationType.ORDER_ACCEPTED
    )
    related_order = models.ForeignKey(Order, on_delete=models.SET_NULL, null=True, blank=True)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(default=timezone.now)
    
    class Meta:
        ordering = ['-created_at']
        
    def __str__(self):
        return f"{self.notification_type} for {self.user.username}"
    
    def mark_as_read(self):
        self.is_read = True
        self.save()
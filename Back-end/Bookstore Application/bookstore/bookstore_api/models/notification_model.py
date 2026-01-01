from django.db import models
from .user_model import User
from django.utils import timezone


class NotificationType(models.Model):
    """
    Model for defining different types of notifications.
    """
    name = models.CharField(
        max_length=100,
        unique=True,
        help_text="Name of the notification type"
    )
    
    description = models.TextField(
        help_text="Description of what this notification type is for"
    )
    
    template = models.TextField(
        help_text="Template for the notification message"
    )
    
    is_active = models.BooleanField(
        default=True,
        help_text="Whether this notification type is active"
    )
    
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When this notification type was created"
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="When this notification type was last updated"
    )
    
    class Meta:
        db_table = 'notification_type'
        verbose_name = 'Notification Type'
        verbose_name_plural = 'Notification Types'
        ordering = ['name']
    
    def __str__(self):
        return self.name
    
    def get_template_variables(self):
        """Get available template variables for this notification type."""
        # This would typically parse the template to find variables like {user_name}, {book_title}, etc.
        import re
        variables = re.findall(r'\{(\w+)\}', self.template)
        return list(set(variables))


class Notification(models.Model):
    """
    Model for storing user notifications.
    """
    PRIORITY_CHOICES = [
        ('low', 'Low'),
        ('normal', 'Normal'),
        ('high', 'High'),
        ('urgent', 'Urgent'),
    ]
    
    STATUS_CHOICES = [
        ('unread', 'Unread'),
        ('read', 'Read'),
        ('archived', 'Archived'),
    ]
    
    # Recipient information
    recipient = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='notifications',
        help_text="User who will receive this notification"
    )
    
    # Notification type and content
    notification_type = models.ForeignKey(
        NotificationType,
        on_delete=models.CASCADE,
        related_name='notifications',
        help_text="Type of notification"
    )
    
    title = models.CharField(
        max_length=200,
        help_text="Notification title"
    )
    
    message = models.TextField(
        help_text="Notification message content"
    )
    
    # Priority and status
    priority = models.CharField(
        max_length=10,
        choices=PRIORITY_CHOICES,
        default='normal',
        help_text="Priority level of the notification"
    )
    
    status = models.CharField(
        max_length=10,
        choices=STATUS_CHOICES,
        default='unread',
        help_text="Current status of the notification"
    )
    
    # Related objects (optional)
    related_object_type = models.CharField(
        max_length=50,
        blank=True,
        null=True,
        help_text="Type of related object (e.g., 'book', 'order', 'borrow_request')"
    )
    
    related_object_id = models.PositiveIntegerField(
        blank=True,
        null=True,
        help_text="ID of the related object"
    )
    
    # Action information
    action_url = models.URLField(
        blank=True,
        null=True,
        help_text="URL to navigate to when notification is clicked"
    )
    
    action_text = models.CharField(
        max_length=100,
        blank=True,
        null=True,
        help_text="Text for the action button"
    )
    
    # Timestamps
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When the notification was created"
    )
    
    read_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When the notification was read"
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="When the notification was last updated"
    )
    
    class Meta:
        db_table = 'notification'
        verbose_name = 'Notification'
        verbose_name_plural = 'Notifications'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['recipient']),
            models.Index(fields=['status']),
            models.Index(fields=['priority']),
            models.Index(fields=['created_at']),
            models.Index(fields=['notification_type']),
        ]
    
    def __str__(self):
        return f"Notification for {self.recipient.get_full_name()}: {self.title}"
    
    def mark_as_read(self):
        """Mark the notification as read."""
        if self.status == 'unread':
            self.status = 'read'
            self.read_at = timezone.now()
            self.save()
    
    def mark_as_archived(self):
        """Mark the notification as archived."""
        self.status = 'archived'
        self.save()
    
    def is_unread(self):
        """Check if the notification is unread."""
        return self.status == 'unread'
    
    def is_high_priority(self):
        """Check if the notification is high priority."""
        return self.priority in ['high', 'urgent']
    
    def get_related_object(self):
        """Get the related object if it exists."""
        if not self.related_object_type or not self.related_object_id:
            return None
        
        try:
            # Import models dynamically to avoid circular imports
            if self.related_object_type == 'book':
                from .library_model import Book
                return Book.objects.get(id=self.related_object_id)
            elif self.related_object_type == 'order':
                from .order_model import Order
                return Order.objects.get(id=self.related_object_id)
            elif self.related_object_type == 'borrow_request':
                from .borrowing_model import BorrowRequest
                return BorrowRequest.objects.get(id=self.related_object_id)
            # Add more object types as needed
        except:
            return None
        
        return None
    
    @classmethod
    def create_notification(cls, recipient, notification_type, title, message, **kwargs):
        """
        Create a new notification with the given parameters.
        """
        notification = cls.objects.create(
            recipient=recipient,
            notification_type=notification_type,
            title=title,
            message=message,
            **kwargs
        )
        return notification
    
    @classmethod
    def get_user_notifications(cls, user, status=None, limit=None):
        """
        Get notifications for a specific user.
        """
        queryset = cls.objects.filter(recipient=user)
        
        if status:
            queryset = queryset.filter(status=status)
        
        if limit:
            queryset = queryset[:limit]
        
        return queryset
    
    @classmethod
    def get_unread_count(cls, user):
        """
        Get the count of unread notifications for a user.
        """
        return cls.objects.filter(recipient=user, status='unread').count()
    
    @classmethod
    def mark_all_as_read(cls, user):
        """
        Mark all unread notifications for a user as read.
        """
        from django.utils import timezone
        now = timezone.now()
        
        cls.objects.filter(
            recipient=user,
            status='unread'
        ).update(
            status='read',
            read_at=now
        )
    
    @classmethod
    def cleanup_old_notifications(cls, days=30):
        """
        Clean up old read notifications.
        """
        from django.utils import timezone
        from datetime import timedelta
        
        cutoff_date = timezone.now() - timedelta(days=days)
        
        # Archive old read notifications
        old_notifications = cls.objects.filter(
            status='read',
            read_at__lt=cutoff_date
        )
        
        count = old_notifications.update(status='archived')
        return count
    
    @classmethod
    def get_notification_stats(cls, user):
        """
        Get notification statistics for a user.
        """
        total_notifications = cls.objects.filter(recipient=user).count()
        unread_count = cls.get_unread_count(user)
        read_count = cls.objects.filter(recipient=user, status='read').count()
        archived_count = cls.objects.filter(recipient=user, status='archived').count()
        
        return {
            'total': total_notifications,
            'unread': unread_count,
            'read': read_count,
            'archived': archived_count,
        }
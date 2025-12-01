from django.conf import settings
from django.core.mail import send_mail
from django.template.loader import render_to_string
from django.utils.html import strip_tags
from django.db.models import Q
from django.utils import timezone

from ..models import Notification, NotificationType, User, Order


class NotificationService:
    @staticmethod
    def create_notification(user_id, title, message, notification_type, related_order_id=None, prevent_duplicates=True):
        """
        Create a notification for a specific user
        """
        try:
            user = User.objects.get(id=user_id)
            related_order = None
            if related_order_id:
                related_order = Order.objects.get(id=related_order_id)
            
            # Handle notification_type as string name instead of instance
            notification_type_obj = None
            if isinstance(notification_type, str):
                try:
                    notification_type_obj = NotificationType.objects.get(name=notification_type)
                except NotificationType.DoesNotExist:
                    # Create a default notification type if it doesn't exist
                    notification_type_obj = NotificationType.objects.create(
                        name=notification_type,
                        description=f"Notification type for {notification_type}",
                        template=f"{{title}}: {{message}}"
                    )
            else:
                notification_type_obj = notification_type
            
            # Check for duplicate notifications if prevent_duplicates is True
            if prevent_duplicates:
                # Check if a similar notification already exists within the last 10 minutes
                from django.utils import timezone
                from datetime import timedelta
                
                recent_time = timezone.now() - timedelta(minutes=10)
                
                # More flexible duplicate detection - check for same type and similar content
                existing_notification = Notification.objects.filter(
                    recipient=user,
                    notification_type=notification_type_obj,
                    created_at__gte=recent_time
                ).filter(
                    Q(title=title) | 
                    Q(message__icontains=title.split()[0]) if title else Q()
                ).first()
                
                if existing_notification:
                    # Return the existing notification instead of creating a duplicate
                    return existing_notification
                
            notification = Notification.objects.create(
                recipient=user,
                title=title,
                message=message,
                notification_type=notification_type_obj,
                related_object_type='order' if related_order else None,
                related_object_id=related_order.id if related_order else None,
            )
            return notification
        except User.DoesNotExist:
            raise ValueError(f"User with ID {user_id} does not exist")
        except Order.DoesNotExist:
            raise ValueError(f"Order with ID {related_order_id} does not exist")
    
    @staticmethod
    def get_user_notifications(user_id, is_read=None, notification_type=None, search=None):
        """
        Get all notifications for a specific user with optional filters
        """
        try:
            user = User.objects.get(id=user_id)
            notifications = Notification.objects.filter(recipient=user)
            
            if is_read is not None:
                status_filter = 'read' if is_read else 'unread'
                notifications = notifications.filter(status=status_filter)
                
            if notification_type:
                # Handle notification_type as string name instead of ID
                try:
                    from ..models import NotificationType
                    notification_type_obj = NotificationType.objects.get(name=notification_type)
                    notifications = notifications.filter(notification_type=notification_type_obj)
                except NotificationType.DoesNotExist:
                    # If notification type doesn't exist, return empty queryset
                    notifications = notifications.none()
            
            if search:
                # Search in title and message fields
                from django.db.models import Q
                notifications = notifications.filter(
                    Q(title__icontains=search) |
                    Q(message__icontains=search)
                )
                
            return notifications
        except User.DoesNotExist:
            raise ValueError(f"User with ID {user_id} does not exist")
    
    @staticmethod
    def mark_notification_as_read(notification_id):
        """
        Mark a notification as read
        """
        try:
            notification = Notification.objects.get(id=notification_id)
            notification.status = 'read'
            notification.read_at = timezone.now()
            notification.save()
            return notification
        except Notification.DoesNotExist:
            raise ValueError(f"Notification with ID {notification_id} does not exist")
    
    @staticmethod
    def mark_all_as_read(user_id):
        """
        Mark all notifications for a user as read
        """
        try:
            user = User.objects.get(id=user_id)
            notifications = Notification.objects.filter(recipient=user, status='unread')
            count = notifications.count()
            
            # Update notifications to read status and set read_at timestamp
            from django.utils import timezone
            notifications.update(
                status='read',
                read_at=timezone.now()
            )
            
            return count
        except User.DoesNotExist:
            raise ValueError(f"User with ID {user_id} does not exist")
    
    @staticmethod
    def delete_notification(notification_id):
        """
        Delete a notification
        """
        try:
            notification = Notification.objects.get(id=notification_id)
            notification.delete()
            return True
        except Notification.DoesNotExist:
            raise ValueError(f"Notification with ID {notification_id} does not exist")
    
    @staticmethod
    def delete_all_notifications(user_id):
        """
        Delete all notifications for a user
        """
        try:
            user = User.objects.get(id=user_id)
            count = Notification.objects.filter(recipient=user).count()
            Notification.objects.filter(recipient=user).delete()
            return count
        except User.DoesNotExist:
            raise ValueError(f"User with ID {user_id} does not exist")
    
    @staticmethod
    def send_email_notification(user_email, subject, message):
        """
        Send email notification to user
        """
        if not settings.EMAIL_HOST_USER:
            # Email settings not configured, log this or handle accordingly
            return False
        
        html_message = render_to_string(
            'email/notification_email.html',
            {'message': message}
        )
        plain_message = strip_tags(html_message)
        
        try:
            send_mail(
                subject,
                plain_message,
                settings.EMAIL_HOST_USER,
                [user_email],
                html_message=html_message,
                fail_silently=False
            )
            return True
        except Exception as e:
            # Log the error or handle accordingly
            print(f"Failed to send email: {str(e)}")
            return False
    
    @staticmethod
    def notify_order_delivered(order_id):
        """
        Create notification when order is delivered
        """
        try:
            order = Order.objects.get(id=order_id)
            user = order.customer
            
            # Create notification
            notification = NotificationService.create_notification(
                user_id=user.id,
                title="Order Delivered",
                message=f"Your order #{order.id} has been delivered successfully.",
                notification_type="order_delivered",
                related_order_id=order.id
            )
            
            # Email notifications removed
            
            return notification
        except Order.DoesNotExist:
            raise ValueError(f"Order with ID {order_id} does not exist")
    
    @staticmethod
    def notify_order_accepted(order_id):
        """
        Create notification when order is accepted
        """
        try:
            order = Order.objects.get(id=order_id)
            user = order.customer
            
            # Create notification
            notification = NotificationService.create_notification(
                user_id=user.id,
                title="Order Accepted",
                message=f"Your order #{order.id} has been accepted and is being processed.",
                notification_type="order_accepted",
                related_order_id=order.id
            )
            
            # Email notifications removed
            
            return notification
        except Order.DoesNotExist:
            raise ValueError(f"Order with ID {order_id} does not exist")
    
    @staticmethod
    def notify_delivery_assigned(order_id, delivery_rep_name, delivery_rep_phone=None):
        """
        Create notification when delivery representative is assigned
        """
        try:
            order = Order.objects.get(id=order_id)
            user = order.customer
            
            # Create notification with contact info if available
            message = f"A delivery representative ({delivery_rep_name}) has been assigned to your order #{order.id}."
            if delivery_rep_phone:
                message += f" Contact: {delivery_rep_phone}"
                
            notification = NotificationService.create_notification(
                user_id=user.id,
                title="Delivery Representative Assigned",
                message=message,
                notification_type="delivery_assigned",
                related_order_id=order.id
            )
            
            # Email notifications removed
            
            return notification
        except Order.DoesNotExist:
            raise ValueError(f"Order with ID {order_id} does not exist")
            
    @staticmethod
    def notify_delivery_time_updated(order_id, estimated_delivery_time):
        """
        Create notification when estimated delivery time is updated
        """
        try:
            order = Order.objects.get(id=order_id)
            user = order.customer
            
            # Format the delivery time
            formatted_time = estimated_delivery_time.strftime("%B %d, %Y at %I:%M %p")
            
            # Create notification
            notification = NotificationService.create_notification(
                user_id=user.id,
                title="Delivery Time Updated",
                message=f"The estimated delivery time for your order #{order.id} has been updated to {formatted_time}.",
                notification_type="delivery_time_updated",
                related_order_id=order.id
            )
            
            # Email notifications removed
            
            return notification
        except Order.DoesNotExist:
            raise ValueError(f"Order with ID {order_id} does not exist")
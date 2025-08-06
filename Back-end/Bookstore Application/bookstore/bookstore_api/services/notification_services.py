from django.conf import settings
from django.core.mail import send_mail
from django.template.loader import render_to_string
from django.utils.html import strip_tags
from django.db.models import Q

from ..models import Notification, NotificationType, User, Order


class NotificationService:
    @staticmethod
    def create_notification(user_id, title, message, notification_type, related_order_id=None):
        """
        Create a notification for a specific user
        """
        try:
            user = User.objects.get(id=user_id)
            related_order = None
            if related_order_id:
                related_order = Order.objects.get(id=related_order_id)
                
            notification = Notification.objects.create(
                user=user,
                title=title,
                message=message,
                notification_type=notification_type,
                related_order=related_order
            )
            return notification
        except User.DoesNotExist:
            raise ValueError(f"User with ID {user_id} does not exist")
        except Order.DoesNotExist:
            raise ValueError(f"Order with ID {related_order_id} does not exist")
    
    @staticmethod
    def get_user_notifications(user_id, is_read=None, notification_type=None):
        """
        Get all notifications for a specific user with optional filters
        """
        try:
            user = User.objects.get(id=user_id)
            notifications = Notification.objects.filter(user=user)
            
            if is_read is not None:
                notifications = notifications.filter(is_read=is_read)
                
            if notification_type:
                notifications = notifications.filter(notification_type=notification_type)
                
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
            notification.is_read = True
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
            notifications = Notification.objects.filter(user=user, is_read=False)
            notifications.update(is_read=True)
            return notifications.count()
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
            user = order.user
            
            # Create notification
            notification = NotificationService.create_notification(
                user_id=user.id,
                title="Order Delivered",
                message=f"Your order #{order.id} has been delivered successfully.",
                notification_type=NotificationType.ORDER_DELIVERED,
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
            user = order.user
            
            # Create notification
            notification = NotificationService.create_notification(
                user_id=user.id,
                title="Order Accepted",
                message=f"Your order #{order.id} has been accepted and is being processed.",
                notification_type=NotificationType.ORDER_ACCEPTED,
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
            user = order.user
            
            # Create notification with contact info if available
            message = f"A delivery representative ({delivery_rep_name}) has been assigned to your order #{order.id}."
            if delivery_rep_phone:
                message += f" Contact: {delivery_rep_phone}"
                
            notification = NotificationService.create_notification(
                user_id=user.id,
                title="Delivery Representative Assigned",
                message=message,
                notification_type=NotificationType.DELIVERY_ASSIGNED,
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
            user = order.user
            
            # Format the delivery time
            formatted_time = estimated_delivery_time.strftime("%B %d, %Y at %I:%M %p")
            
            # Create notification
            notification = NotificationService.create_notification(
                user_id=user.id,
                title="Delivery Time Updated",
                message=f"The estimated delivery time for your order #{order.id} has been updated to {formatted_time}.",
                notification_type=NotificationType.DELIVERY_TIME_UPDATED,
                related_order_id=order.id
            )
            
            # Email notifications removed
            
            return notification
        except Order.DoesNotExist:
            raise ValueError(f"Order with ID {order_id} does not exist")
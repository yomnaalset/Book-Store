from rest_framework import serializers
from ..models import Notification, Order


class NotificationSerializer(serializers.ModelSerializer):
    order_id = serializers.SerializerMethodField()
    is_read = serializers.SerializerMethodField()
    notification_type = serializers.SerializerMethodField()
    type = serializers.SerializerMethodField()  # Alias for frontend compatibility
    priority = serializers.CharField(read_only=True)  # Include priority field
    
    class Meta:
        model = Notification
        fields = ['id', 'title', 'message', 'notification_type', 'type', 'priority', 
                  'is_read', 'created_at', 'order_id']
        read_only_fields = ['id', 'created_at', 'type', 'priority']
    
    def get_order_id(self, obj):
        # Check if this notification is related to an order
        if obj.related_object_type == 'order' and obj.related_object_id:
            return obj.related_object_id
        return None
    
    def get_is_read(self, obj):
        return obj.status == 'read'
    
    def get_notification_type(self, obj):
        return obj.notification_type.name if obj.notification_type else None
    
    def get_type(self, obj):
        # Return notification_type name as 'type' for frontend compatibility
        return obj.notification_type.name if obj.notification_type else None


class NotificationCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ['recipient', 'title', 'message', 'notification_type', 'related_object_type', 'related_object_id']
        

class NotificationUpdateSerializer(serializers.ModelSerializer):
    is_read = serializers.BooleanField(write_only=True)
    
    class Meta:
        model = Notification
        fields = ['is_read']
    
    def update(self, instance, validated_data):
        is_read = validated_data.get('is_read', False)
        instance.status = 'read' if is_read else 'unread'
        instance.save()
        return instance
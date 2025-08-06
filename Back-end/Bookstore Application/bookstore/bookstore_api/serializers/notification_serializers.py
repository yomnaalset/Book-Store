from rest_framework import serializers
from ..models import Notification, Order


class NotificationSerializer(serializers.ModelSerializer):
    order_id = serializers.SerializerMethodField()
    
    class Meta:
        model = Notification
        fields = ['id', 'title', 'message', 'notification_type', 'is_read', 
                  'created_at', 'order_id']
        read_only_fields = ['id', 'created_at']
    
    def get_order_id(self, obj):
        if obj.related_order:
            return obj.related_order.id
        return None


class NotificationCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ['user', 'title', 'message', 'notification_type', 'related_order']
        

class NotificationUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ['is_read']
from rest_framework import serializers
from ..models import Complaint, ComplaintResponse, User, Order, BorrowRequest


class ComplaintResponseSerializer(serializers.ModelSerializer):
    """
    Serializer for complaint responses.
    """
    responder_name = serializers.CharField(source='responder.get_full_name', read_only=True)
    responder_email = serializers.CharField(source='responder.email', read_only=True)
    
    class Meta:
        model = ComplaintResponse
        fields = [
            'id', 'complaint', 'responder', 'responder_name', 'responder_email',
            'response_text', 'is_internal', 'created_at'
        ]
        read_only_fields = ['id', 'created_at']


class ComplaintListSerializer(serializers.ModelSerializer):
    """
    Serializer for complaint list view (basic information).
    """
    customer_name = serializers.CharField(source='customer.get_full_name', read_only=True)
    customer_email = serializers.CharField(source='customer.email', read_only=True)
    assigned_to_name = serializers.CharField(source='assigned_to.get_full_name', read_only=True)
    assigned_to_email = serializers.CharField(source='assigned_to.email', read_only=True)
    order_number = serializers.CharField(source='related_order.order_number', read_only=True)
    
    class Meta:
        model = Complaint
        fields = [
            'id', 'complaint_id', 'customer', 'customer_name', 'customer_email',
            'title', 'description', 'complaint_type', 'priority', 'status',
            'assigned_to', 'assigned_to_name', 'assigned_to_email',
            'related_order', 'order_number', 'related_borrow_request',
            'resolution', 'resolved_at', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'complaint_id', 'created_at', 'updated_at']


class ComplaintDetailSerializer(serializers.ModelSerializer):
    """
    Serializer for complaint detail view (includes responses).
    """
    customer_name = serializers.CharField(source='customer.get_full_name', read_only=True)
    customer_email = serializers.CharField(source='customer.email', read_only=True)
    assigned_to_name = serializers.CharField(source='assigned_to.get_full_name', read_only=True)
    assigned_to_email = serializers.CharField(source='assigned_to.email', read_only=True)
    order_number = serializers.CharField(source='related_order.order_number', read_only=True)
    responses = ComplaintResponseSerializer(many=True, read_only=True)
    
    class Meta:
        model = Complaint
        fields = [
            'id', 'complaint_id', 'customer', 'customer_name', 'customer_email',
            'title', 'description', 'complaint_type', 'priority', 'status',
            'assigned_to', 'assigned_to_name', 'assigned_to_email',
            'related_order', 'order_number', 'related_borrow_request',
            'resolution', 'resolved_at', 'responses', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'complaint_id', 'created_at', 'updated_at']


class ComplaintCreateSerializer(serializers.ModelSerializer):
    """
    Serializer for creating new complaints.
    """
    class Meta:
        model = Complaint
        fields = [
            'title', 'description', 'complaint_type', 'priority',
            'related_order', 'related_borrow_request'
        ]
    
    def create(self, validated_data):
        # Set the customer from the request user
        validated_data['customer'] = self.context['request'].user
        return super().create(validated_data)


class ComplaintUpdateSerializer(serializers.ModelSerializer):
    """
    Serializer for updating complaints (admin use).
    """
    class Meta:
        model = Complaint
        fields = [
            'status', 'priority', 'assigned_to', 'resolution'
        ]
    
    def update(self, instance, validated_data):
        # Set resolved_at when status is changed to resolved
        if validated_data.get('status') == 'resolved' and instance.status != 'resolved':
            from django.utils import timezone
            validated_data['resolved_at'] = timezone.now()
        return super().update(instance, validated_data)


class ComplaintResponseCreateSerializer(serializers.ModelSerializer):
    """
    Serializer for creating complaint responses.
    """
    class Meta:
        model = ComplaintResponse
        fields = ['response_text', 'is_internal']
    
    def create(self, validated_data):
        # Set the responder from the request user
        validated_data['responder'] = self.context['request'].user
        # Set the complaint from the URL parameter
        validated_data['complaint_id'] = self.context['complaint_id']
        return super().create(validated_data)

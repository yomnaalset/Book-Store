from rest_framework import serializers
from ..models import Complaint, ComplaintResponse, User


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
    
    class Meta:
        model = Complaint
        fields = [
            'id', 'complaint_id', 'customer', 'customer_name', 'customer_email',
            'title', 'description', 'complaint_type', 'status',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'complaint_id', 'created_at', 'updated_at']


class ComplaintDetailSerializer(serializers.ModelSerializer):
    """
    Serializer for complaint detail view (includes responses).
    Filters responses based on user type - customers only see non-internal responses.
    """
    customer_name = serializers.CharField(source='customer.get_full_name', read_only=True)
    customer_email = serializers.CharField(source='customer.email', read_only=True)
    responses = serializers.SerializerMethodField()
    
    class Meta:
        model = Complaint
        fields = [
            'id', 'complaint_id', 'customer', 'customer_name', 'customer_email',
            'title', 'description', 'complaint_type', 'status',
            'responses', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'complaint_id', 'created_at', 'updated_at']
    
    def get_responses(self, obj):
        """
        Filter responses based on user type.
        Customers only see non-internal responses.
        Admins see all responses.
        Responses are ordered by creation date (oldest first).
        """
        request = self.context.get('request')
        if request and request.user:
            user = request.user
            if user.user_type == 'customer':
                # Customers only see non-internal responses
                responses = obj.responses.filter(is_internal=False).order_by('created_at')
            else:
                # Admins see all responses
                responses = obj.responses.all().order_by('created_at')
        else:
            # Default: show all responses (for backward compatibility)
            responses = obj.responses.all().order_by('created_at')
        
        return ComplaintResponseSerializer(responses, many=True, context=self.context).data


class ComplaintCreateSerializer(serializers.ModelSerializer):
    """
    Serializer for creating new complaints.
    """
    class Meta:
        model = Complaint
        fields = [
            'title', 'description', 'complaint_type'
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
            'status'
        ]
    
    def update(self, instance, validated_data):
        return super().update(instance, validated_data)


class ComplaintCustomerUpdateSerializer(serializers.ModelSerializer):
    """
    Serializer for customers to update their own complaints.
    Only allows updating title and description if status is 'open'.
    """
    class Meta:
        model = Complaint
        fields = [
            'title', 'description', 'complaint_type'
        ]
    
    def validate(self, attrs):
        # Customers can only update complaints with status 'open'
        if self.instance.status != 'open':
            raise serializers.ValidationError(
                "You can only update complaints that are still open."
            )
        return attrs
    
    def update(self, instance, validated_data):
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

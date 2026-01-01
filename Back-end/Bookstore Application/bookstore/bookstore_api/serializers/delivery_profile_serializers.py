from rest_framework import serializers
from ..models import DeliveryProfile, User


class DeliveryProfileSerializer(serializers.ModelSerializer):
    """
    Serializer for DeliveryProfile model.
    """
    user_id = serializers.IntegerField(source='user.id', read_only=True)
    user_name = serializers.CharField(source='user.get_full_name', read_only=True)
    user_email = serializers.EmailField(source='user.email', read_only=True)
    user_type = serializers.CharField(source='user.user_type', read_only=True)
    
    class Meta:
        model = DeliveryProfile
        fields = [
            'id',
            'user_id',
            'user_name',
            'user_email',
            'user_type',
            'delivery_status',
            'latitude',
            'longitude',
            'address',
            'location_updated_at',
            'is_tracking_active',
            'last_tracking_update',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']
    
    def validate_delivery_status(self, value):
        """Validate delivery status."""
        valid_statuses = [choice[0] for choice in DeliveryProfile.DELIVERY_STATUS_CHOICES]
        if value not in valid_statuses:
            raise serializers.ValidationError(f"Invalid delivery status. Must be one of: {valid_statuses}")
        return value
    
    def validate_latitude(self, value):
        """Validate latitude."""
        if value is not None:
            if not (-90 <= value <= 90):
                raise serializers.ValidationError("Latitude must be between -90 and 90 degrees")
        return value
    
    def validate_longitude(self, value):
        """Validate longitude."""
        if value is not None:
            if not (-180 <= value <= 180):
                raise serializers.ValidationError("Longitude must be between -180 and 180 degrees")
        return value
    
    def validate(self, data):
        """Validate the entire data."""
        # If latitude is provided, longitude must also be provided
        if data.get('latitude') is not None and data.get('longitude') is None:
            raise serializers.ValidationError("Longitude is required when latitude is provided")
        
        # If longitude is provided, latitude must also be provided
        if data.get('longitude') is not None and data.get('latitude') is None:
            raise serializers.ValidationError("Latitude is required when longitude is provided")
        
        return data


class DeliveryProfileCreateSerializer(serializers.ModelSerializer):
    """
    Serializer for creating DeliveryProfile instances.
    """
    user_id = serializers.IntegerField(write_only=True)
    
    class Meta:
        model = DeliveryProfile
        fields = [
            'user_id',
            'delivery_status',
            'latitude',
            'longitude',
            'address',
            'is_tracking_active',
        ]
    
    def validate_user_id(self, value):
        """Validate that the user exists and is a delivery admin."""
        try:
            user = User.objects.get(id=value)
            if not user.is_delivery_admin():
                raise serializers.ValidationError("Only delivery administrators can have delivery profiles")
            return value
        except User.DoesNotExist:
            raise serializers.ValidationError("User does not exist")
    
    def create(self, validated_data):
        """Create a new delivery profile."""
        user_id = validated_data.pop('user_id')
        user = User.objects.get(id=user_id)
        
        delivery_profile = DeliveryProfile.objects.create(
            user=user,
            **validated_data
        )
        return delivery_profile


class DeliveryProfileUpdateSerializer(serializers.ModelSerializer):
    """
    Serializer for updating DeliveryProfile instances.
    """
    class Meta:
        model = DeliveryProfile
        fields = [
            'delivery_status',
            'latitude',
            'longitude',
            'address',
            'is_tracking_active',
        ]
    
    def validate_latitude(self, value):
        """Validate latitude."""
        if value is not None:
            if not (-90 <= value <= 90):
                raise serializers.ValidationError("Latitude must be between -90 and 90 degrees")
        return value
    
    def validate_longitude(self, value):
        """Validate longitude."""
        if value is not None:
            if not (-180 <= value <= 180):
                raise serializers.ValidationError("Longitude must be between -180 and 180 degrees")
        return value
    
    def validate(self, data):
        """Validate the entire data."""
        # If latitude is provided, longitude must also be provided
        if data.get('latitude') is not None and data.get('longitude') is None:
            raise serializers.ValidationError("Longitude is required when latitude is provided")
        
        # If longitude is provided, latitude must also be provided
        if data.get('longitude') is not None and data.get('latitude') is None:
            raise serializers.ValidationError("Latitude is required when longitude is provided")
        
        return data


class DeliveryProfileLocationUpdateSerializer(serializers.Serializer):
    """
    Serializer specifically for updating location data.
    Allows updating address only, or coordinates with optional address.
    """
    latitude = serializers.DecimalField(max_digits=10, decimal_places=7, required=False, allow_null=True)
    longitude = serializers.DecimalField(max_digits=10, decimal_places=7, required=False, allow_null=True)
    address = serializers.CharField(max_length=500, required=False, allow_blank=True)
    
    def validate_latitude(self, value):
        """Validate latitude."""
        if value is not None and not (-90 <= value <= 90):
            raise serializers.ValidationError("Latitude must be between -90 and 90 degrees")
        return value
    
    def validate_longitude(self, value):
        """Validate longitude."""
        if value is not None and not (-180 <= value <= 180):
            raise serializers.ValidationError("Longitude must be between -180 and 180 degrees")
        return value
    
    def validate(self, data):
        """Validate that either coordinates or address is provided."""
        latitude = data.get('latitude')
        longitude = data.get('longitude')
        address = data.get('address', '').strip()
        
        # If coordinates are provided, both must be provided
        if (latitude is not None and longitude is None) or (longitude is not None and latitude is None):
            raise serializers.ValidationError("Both latitude and longitude must be provided together, or neither.")
        
        # At least one of coordinates or address must be provided
        if latitude is None and longitude is None and (address == '' or address is None):
            raise serializers.ValidationError("Either coordinates (latitude and longitude) or address must be provided.")
        
        return data


class DeliveryProfileStatusUpdateSerializer(serializers.Serializer):
    """
    Serializer specifically for updating delivery status.
    IMPORTANT: Manual status changes are not allowed when status is 'busy'.
    """
    delivery_status = serializers.ChoiceField(choices=DeliveryProfile.DELIVERY_STATUS_CHOICES)
    
    def validate_delivery_status(self, value):
        """Validate delivery status."""
        valid_statuses = [choice[0] for choice in DeliveryProfile.DELIVERY_STATUS_CHOICES]
        if value not in valid_statuses:
            raise serializers.ValidationError(f"Invalid delivery status. Must be one of: {valid_statuses}")
        return value
    
    def validate(self, data):
        """
        Additional validation to prevent manual status changes when busy.
        This validation should be used in conjunction with the service layer check.
        """
        # Note: The main validation for busy status is handled in the view layer
        # using DeliveryProfileService.can_manually_change_status()
        return data


class DeliveryProfileTrackingUpdateSerializer(serializers.Serializer):
    """
    Serializer specifically for updating tracking status.
    """
    is_tracking_active = serializers.BooleanField()
    
    def validate_is_tracking_active(self, value):
        """Validate tracking status."""
        return value


class DeliveryProfileCurrentStatusSerializer(serializers.Serializer):
    """
    Serializer for the current status endpoint.
    This is a read-only serializer that returns the current persistent status.
    """
    user_id = serializers.IntegerField(read_only=True)
    delivery_status = serializers.CharField(read_only=True)
    can_change_manually = serializers.BooleanField(read_only=True)
    is_tracking_active = serializers.BooleanField(read_only=True)
    last_updated = serializers.DateTimeField(read_only=True)

from rest_framework import serializers
from django.utils import timezone
from datetime import timedelta

from ..models.ad_model import Advertisement, AdvertisementStatusChoices


class AdvertisementCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating new advertisements"""
    
    # Add camelCase field mappings for frontend compatibility
    startDate = serializers.DateTimeField(source='start_date', required=False)
    endDate = serializers.DateTimeField(source='end_date', required=False)
    imageUrl = serializers.URLField(source='image', required=False, allow_blank=True)
    
    class Meta:
        model = Advertisement
        fields = [
            'title', 'content', 'image', 'start_date', 'end_date',
            # Add camelCase fields for frontend compatibility
            'startDate', 'endDate', 'imageUrl'
        ]
    
    def to_internal_value(self, data):
        """Override to handle both snake_case and camelCase field names"""
        # Convert camelCase to snake_case if needed
        if isinstance(data, dict):
            # Create a copy to avoid modifying the original data
            data = data.copy()
            
            # Map camelCase to snake_case
            field_mapping = {
                'startDate': 'start_date',
                'endDate': 'end_date',
                'imageUrl': 'image'
            }
            
            for camel_case, snake_case in field_mapping.items():
                if camel_case in data and snake_case not in data:
                    data[snake_case] = data.pop(camel_case)
        
        return super().to_internal_value(data)
    
    def validate_start_date(self, value):
        """Validate start date"""
        # Ensure both datetimes are timezone-aware for comparison
        if value and value.tzinfo is None:
            value = timezone.make_aware(value)
        
        now = timezone.now()
        if value < now:
            raise serializers.ValidationError(
                "Start date cannot be in the past for new advertisements."
            )
        return value
    
    def validate_startDate(self, value):
        """Validate start date (camelCase)"""
        return self.validate_start_date(value)
    
    def validate_end_date(self, value):
        """Validate end date"""
        # Ensure the end date is timezone-aware
        if value and value.tzinfo is None:
            value = timezone.make_aware(value)
            
        start_date = self.initial_data.get('start_date') or self.initial_data.get('startDate')
        if start_date:
            if isinstance(start_date, str):
                start_date = timezone.datetime.fromisoformat(start_date.replace('Z', '+00:00'))
            # Ensure start_date is also timezone-aware
            if start_date and start_date.tzinfo is None:
                start_date = timezone.make_aware(start_date)
            if value <= start_date:
                raise serializers.ValidationError(
                    "End date must be after start date."
                )
        return value
    
    def validate_endDate(self, value):
        """Validate end date (camelCase)"""
        return self.validate_end_date(value)
    
    def validate(self, attrs):
        """Validate the entire advertisement data"""
        # Check both snake_case and camelCase field names
        start_date = attrs.get('start_date')
        end_date = attrs.get('end_date')
        
        # If snake_case fields are not present, check if camelCase fields were provided
        if not start_date and 'startDate' in self.initial_data:
            # This means camelCase was used, the source mapping should handle it
            # But we need to check if the mapping worked
            pass
        
        # Check if at least one date field is provided
        if not start_date:
            raise serializers.ValidationError({
                'start_date': 'Start date is required.'
            })
        
        if not end_date:
            raise serializers.ValidationError({
                'end_date': 'End date is required.'
            })
        
        # Ensure both dates are timezone-aware for comparison
        if start_date and start_date.tzinfo is None:
            start_date = timezone.make_aware(start_date)
            attrs['start_date'] = start_date
            
        if end_date and end_date.tzinfo is None:
            end_date = timezone.make_aware(end_date)
            attrs['end_date'] = end_date
        
        if start_date and end_date and end_date <= start_date:
            raise serializers.ValidationError({
                'end_date': 'End date must be after start date.'
            })
        
        return attrs


class AdvertisementUpdateSerializer(serializers.ModelSerializer):
    """Serializer for updating existing advertisements"""
    
    # Add camelCase field mappings for frontend compatibility
    startDate = serializers.DateTimeField(source='start_date', required=False)
    endDate = serializers.DateTimeField(source='end_date', required=False)
    imageUrl = serializers.URLField(source='image', required=False, allow_blank=True)
    
    class Meta:
        model = Advertisement
        fields = [
            'title', 'content', 'image', 'start_date', 'end_date', 'status',
            # Add camelCase fields for frontend compatibility
            'startDate', 'endDate', 'imageUrl'
        ]
    
    def to_internal_value(self, data):
        """Override to handle both snake_case and camelCase field names"""
        # Convert camelCase to snake_case if needed
        if isinstance(data, dict):
            # Create a copy to avoid modifying the original data
            data = data.copy()
            
            # Map camelCase to snake_case
            field_mapping = {
                'startDate': 'start_date',
                'endDate': 'end_date',
                'imageUrl': 'image'
            }
            
            for camel_case, snake_case in field_mapping.items():
                if camel_case in data and snake_case not in data:
                    data[snake_case] = data.pop(camel_case)
        
        return super().to_internal_value(data)
    
    def validate_start_date(self, value):
        """Validate start date"""
        # Allow past dates for updates (in case of rescheduling)
        return value
    
    def validate_startDate(self, value):
        """Validate start date (camelCase)"""
        return self.validate_start_date(value)
    
    def validate_end_date(self, value):
        """Validate end date"""
        start_date = self.initial_data.get('start_date') or self.initial_data.get('startDate')
        if start_date:
            try:
                if isinstance(start_date, str):
                    start_date = timezone.datetime.fromisoformat(start_date.replace('Z', '+00:00'))
                if value <= start_date:
                    raise serializers.ValidationError(
                        "End date must be after start date."
                    )
            except (ValueError, TypeError):
                pass  # Skip validation if start_date is invalid
        return value
    
    def validate_endDate(self, value):
        """Validate end date (camelCase)"""
        return self.validate_end_date(value)
    
    def validate_status(self, value):
        """Validate status changes"""
        if self.instance:
            current_status = self.instance.status
            
            # Only prevent changing status of expired advertisements
            if current_status == AdvertisementStatusChoices.EXPIRED:
                if value != AdvertisementStatusChoices.EXPIRED:
                    raise serializers.ValidationError(
                        "Cannot change status of expired advertisements."
                    )
            
            # Always respect the user's status choice for all other cases
            # Remove automatic status changes to allow manual control
        
        return value
    
    def validate(self, attrs):
        """Validate the entire advertisement data"""
        start_date = attrs.get('start_date')
        end_date = attrs.get('end_date')
        
        if start_date and end_date and end_date <= start_date:
            raise serializers.ValidationError({
                'end_date': 'End date must be after start date.'
            })
        
        return attrs


class AdvertisementDetailSerializer(serializers.ModelSerializer):
    """Serializer for detailed advertisement information"""
    
    created_by_name = serializers.CharField(source='created_by.get_full_name', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    is_active = serializers.BooleanField(read_only=True)
    is_scheduled = serializers.BooleanField(read_only=True)
    is_expired = serializers.BooleanField(read_only=True)
    duration_days = serializers.IntegerField(source='get_duration_days', read_only=True)
    remaining_days = serializers.IntegerField(source='get_remaining_days', read_only=True)
    image_url = serializers.SerializerMethodField()
    
    class Meta:
        model = Advertisement
        fields = [
            'id', 'title', 'content', 'image', 'image_url', 'start_date', 'end_date',
            'status', 'status_display', 'created_by', 'created_by_name',
            'created_at', 'updated_at', 'is_active', 'is_scheduled', 'is_expired',
            'duration_days', 'remaining_days'
        ]
        read_only_fields = ['id', 'created_by', 'created_at', 'updated_at']
    
    def get_image_url(self, obj):
        """Get the full URL for the advertisement image"""
        if obj.image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.image.url)
            return obj.image.url
        return None


class AdvertisementListSerializer(serializers.ModelSerializer):
    """Serializer for listing advertisements"""
    
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    is_active = serializers.BooleanField(read_only=True)
    is_scheduled = serializers.BooleanField(read_only=True)
    is_expired = serializers.BooleanField(read_only=True)
    remaining_days = serializers.IntegerField(source='get_remaining_days', read_only=True)
    image_url = serializers.SerializerMethodField()
    
    class Meta:
        model = Advertisement
        fields = [
            'id', 'title', 'content', 'image', 'image_url', 'start_date', 'end_date',
            'status', 'status_display', 'is_active', 'is_scheduled', 'is_expired',
            'remaining_days', 'created_at'
        ]
    
    def get_image_url(self, obj):
        """Get the full URL for the advertisement image"""
        if obj.image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.image.url)
            return obj.image.url
        return None


class AdvertisementStatusUpdateSerializer(serializers.Serializer):
    """Serializer for updating advertisement status"""
    
    status = serializers.ChoiceField(choices=AdvertisementStatusChoices.choices)
    
    def validate_status(self, value):
        """Validate status change"""
        if self.instance:
            current_status = self.instance.status
            
            # Prevent invalid status transitions
            if current_status == AdvertisementStatusChoices.EXPIRED:
                if value != AdvertisementStatusChoices.EXPIRED:
                    raise serializers.ValidationError(
                        "Cannot change status of expired advertisements."
                    )
            
            # Auto-activate scheduled ads if start date has passed
            if (value == AdvertisementStatusChoices.SCHEDULED and 
                self.instance.start_date and 
                self.instance.start_date <= timezone.now()):
                return AdvertisementStatusChoices.ACTIVE
        
        return value


class AdvertisementStatsSerializer(serializers.ModelSerializer):
    """Serializer for advertisement statistics"""
    
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    duration_days = serializers.IntegerField(source='get_duration_days', read_only=True)
    remaining_days = serializers.IntegerField(source='get_remaining_days', read_only=True)
    class Meta:
        model = Advertisement
        fields = [
            'id', 'title', 'status', 'status_display', 'start_date', 'end_date',
            'duration_days', 'remaining_days'
        ]


class AdvertisementPublicSerializer(serializers.ModelSerializer):
    """Serializer for public advertisement display (limited fields)"""
    
    image_url = serializers.SerializerMethodField()
    
    class Meta:
        model = Advertisement
        fields = [
            'id', 'title', 'content', 'image', 'image_url'
        ]
    
    def get_image_url(self, obj):
        """Get the full URL for the advertisement image"""
        if obj.image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.image.url)
            return obj.image.url
        return None


class AdvertisementBulkStatusUpdateSerializer(serializers.Serializer):
    """Serializer for bulk status updates"""
    
    advertisement_ids = serializers.ListField(
        child=serializers.IntegerField(),
        min_length=1,
        help_text="List of advertisement IDs to update"
    )
    status = serializers.ChoiceField(choices=AdvertisementStatusChoices.choices)
    
    def validate_advertisement_ids(self, value):
        """Validate that all advertisement IDs exist"""
        if not value:
            raise serializers.ValidationError("At least one advertisement ID is required.")
        
        existing_ids = Advertisement.objects.filter(id__in=value).values_list('id', flat=True)
        missing_ids = set(value) - set(existing_ids)
        
        if missing_ids:
            raise serializers.ValidationError(
                f"Advertisement IDs not found: {list(missing_ids)}"
            )
        
        return value

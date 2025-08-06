from rest_framework import serializers
from django.utils import timezone
from ..models import DiscountCode, DiscountUsage, User


class DiscountCodeSerializer(serializers.ModelSerializer):
    """
    Serializer for DiscountCode model - used for CRUD operations by library admins.
    """
    
    class Meta:
        model = DiscountCode
        fields = [
            'id', 'code', 'discount_percentage', 'usage_limit_per_customer',
            'expiration_date', 'is_active', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']
        extra_kwargs = {
            'code': {
                'required': True,
                'help_text': 'Unique discount code (e.g., SAVE10)',
                'max_length': 50
            },
            'discount_percentage': {
                'required': True,
                'help_text': 'Discount percentage (1-100%)',
                'min_value': 0.01,
                'max_value': 100.00
            },
            'usage_limit_per_customer': {
                'required': True,
                'help_text': 'Maximum number of times each customer can use this code',
                'min_value': 1
            },
            'expiration_date': {
                'required': True,
                'help_text': 'When this discount code expires'
            }
        }
    
    def validate_code(self, value):
        """
        Validate discount code format and uniqueness.
        """
        if not value:
            raise serializers.ValidationError("Discount code is required.")
        
        # Clean and format the code
        code = value.upper().strip()
        
        # Check format
        if not code.replace('_', '').replace('-', '').isalnum():
            raise serializers.ValidationError(
                "Code can only contain letters, numbers, hyphens, and underscores."
            )
        
        # Check length
        if len(code) < 3:
            raise serializers.ValidationError("Code must be at least 3 characters long.")
        
        # Check uniqueness (excluding current instance for updates)
        queryset = DiscountCode.objects.filter(code=code)
        if self.instance:
            queryset = queryset.exclude(pk=self.instance.pk)
        
        if queryset.exists():
            raise serializers.ValidationError("A discount code with this code already exists.")
        
        return code
    
    def validate_expiration_date(self, value):
        """
        Validate that expiration date is in the future.
        """
        if value <= timezone.now():
            raise serializers.ValidationError("Expiration date must be in the future.")
        return value
    
    def validate_discount_percentage(self, value):
        """
        Validate discount percentage range.
        """
        if value <= 0:
            raise serializers.ValidationError("Discount percentage must be greater than 0.")
        if value > 100:
            raise serializers.ValidationError("Discount percentage cannot exceed 100%.")
        return value


class DiscountCodeCreateSerializer(DiscountCodeSerializer):
    """
    Serializer for creating new discount codes.
    """
    pass


class DiscountCodeUpdateSerializer(serializers.ModelSerializer):
    """
    Serializer for updating existing discount codes.
    Limited fields can be updated as per requirements.
    """
    
    class Meta:
        model = DiscountCode
        fields = [
            'discount_percentage', 'usage_limit_per_customer', 'expiration_date'
        ]
        extra_kwargs = {
            'discount_percentage': {
                'help_text': 'Discount percentage (1-100%)',
                'min_value': 0.01,
                'max_value': 100.00
            },
            'usage_limit_per_customer': {
                'help_text': 'Maximum number of times each customer can use this code',
                'min_value': 1
            },
            'expiration_date': {
                'help_text': 'When this discount code expires'
            }
        }
    
    def validate_expiration_date(self, value):
        """
        Validate that expiration date is in the future.
        """
        if value <= timezone.now():
            raise serializers.ValidationError("Expiration date must be in the future.")
        return value
    
    def validate_discount_percentage(self, value):
        """
        Validate discount percentage range.
        """
        if value <= 0:
            raise serializers.ValidationError("Discount percentage must be greater than 0.")
        if value > 100:
            raise serializers.ValidationError("Discount percentage cannot exceed 100%.")
        return value


class DiscountCodeListSerializer(serializers.ModelSerializer):
    """
    Serializer for listing discount codes with additional computed fields.
    """
    usage_count = serializers.SerializerMethodField()
    is_expired = serializers.SerializerMethodField()
    status = serializers.SerializerMethodField()
    
    class Meta:
        model = DiscountCode
        fields = [
            'id', 'code', 'discount_percentage', 'usage_limit_per_customer',
            'expiration_date', 'is_active', 'created_at', 'updated_at',
            'usage_count', 'is_expired', 'status'
        ]
    
    def get_usage_count(self, obj):
        """Get total usage count for this discount code."""
        return obj.usage_records.count()
    
    def get_is_expired(self, obj):
        """Check if the discount code is expired."""
        return obj.expiration_date <= timezone.now()
    
    def get_status(self, obj):
        """Get human-readable status of the discount code."""
        if not obj.is_active:
            return "Inactive"
        elif obj.expiration_date <= timezone.now():
            return "Expired"
        else:
            return "Active"


class DiscountCodeValidationSerializer(serializers.Serializer):
    """
    Serializer for validating discount codes during checkout.
    """
    code = serializers.CharField(
        max_length=50,
        required=True,
        help_text="Discount code to validate"
    )
    cart_total = serializers.DecimalField(
        max_digits=10,
        decimal_places=2,
        required=True,
        help_text="Total cart amount before discount"
    )
    
    def validate_code(self, value):
        """
        Validate that the discount code exists and format it properly.
        """
        if not value:
            raise serializers.ValidationError("Discount code is required.")
        
        return value.upper().strip()
    
    def validate_cart_total(self, value):
        """
        Validate cart total is positive.
        """
        if value <= 0:
            raise serializers.ValidationError("Cart total must be greater than 0.")
        return value


class DiscountApplicationSerializer(serializers.Serializer):
    """
    Serializer for applying discount codes during checkout.
    """
    code = serializers.CharField(
        max_length=50,
        required=True,
        help_text="Discount code to apply"
    )
    original_amount = serializers.DecimalField(
        max_digits=10,
        decimal_places=2,
        required=True,
        help_text="Original order amount"
    )
    discount_amount = serializers.DecimalField(
        max_digits=10,
        decimal_places=2,
        read_only=True,
        help_text="Amount discounted"
    )
    final_amount = serializers.DecimalField(
        max_digits=10,
        decimal_places=2,
        read_only=True,
        help_text="Final amount after discount"
    )


class DiscountUsageSerializer(serializers.ModelSerializer):
    """
    Serializer for DiscountUsage model - tracks when customers use discount codes.
    """
    discount_code_text = serializers.CharField(
        source='discount_code.code',
        read_only=True,
        help_text="The discount code that was used"
    )
    user_email = serializers.CharField(
        source='user.email',
        read_only=True,
        help_text="Email of the user who used the code"
    )
    discount_percentage = serializers.DecimalField(
        source='discount_code.discount_percentage',
        max_digits=5,
        decimal_places=2,
        read_only=True,
        help_text="Percentage discount applied"
    )
    
    class Meta:
        model = DiscountUsage
        fields = [
            'id', 'discount_code', 'discount_code_text', 'user', 'user_email',
            'order_amount', 'discount_amount', 'final_amount', 'used_at',
            'payment_reference', 'discount_percentage'
        ]
        read_only_fields = ['id', 'used_at']


class DiscountUsageCreateSerializer(serializers.ModelSerializer):
    """
    Serializer for creating discount usage records.
    """
    
    class Meta:
        model = DiscountUsage
        fields = [
            'discount_code', 'user', 'order_amount', 'discount_amount',
            'final_amount', 'payment_reference'
        ]
    
    def validate(self, attrs):
        """
        Validate the discount usage data.
        """
        discount_code = attrs.get('discount_code')
        user = attrs.get('user')
        order_amount = attrs.get('order_amount')
        discount_amount = attrs.get('discount_amount')
        
        # Validate that the user can use this discount code
        can_use, message = discount_code.can_be_used_by_user(user)
        if not can_use:
            raise serializers.ValidationError(f"Cannot use discount code: {message}")
        
        # Validate discount amount calculation
        expected_discount = discount_code.calculate_discount_amount(order_amount)
        if abs(discount_amount - expected_discount) > 0.01:  # Allow for small rounding differences
            raise serializers.ValidationError(
                f"Invalid discount amount. Expected: {expected_discount}, Got: {discount_amount}"
            )
        
        return attrs


class CustomerDiscountUsageSerializer(serializers.ModelSerializer):
    """
    Serializer for customer view of their discount usage history.
    """
    discount_code_text = serializers.CharField(
        source='discount_code.code',
        read_only=True
    )
    discount_percentage = serializers.DecimalField(
        source='discount_code.discount_percentage',
        max_digits=5,
        decimal_places=2,
        read_only=True
    )
    savings = serializers.DecimalField(
        source='discount_amount',
        max_digits=10,
        decimal_places=2,
        read_only=True
    )
    
    class Meta:
        model = DiscountUsage
        fields = [
            'discount_code_text', 'discount_percentage', 'order_amount',
            'savings', 'final_amount', 'used_at'
        ]
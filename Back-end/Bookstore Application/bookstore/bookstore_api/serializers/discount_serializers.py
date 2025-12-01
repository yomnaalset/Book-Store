from rest_framework import serializers
from django.utils import timezone
from decimal import Decimal
from ..models import DiscountCode, DiscountUsage, User, BookDiscount, BookDiscountUsage, Book


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
                'min_value': Decimal('0.01'),
                'max_value': Decimal('100.00')
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
            'discount_percentage', 'usage_limit_per_customer', 'expiration_date', 'is_active'
        ]
        extra_kwargs = {
            'discount_percentage': {
                'help_text': 'Discount percentage (1-100%)',
                'min_value': Decimal('0.01'),
                'max_value': Decimal('100.00')
            },
            'usage_limit_per_customer': {
                'help_text': 'Maximum number of times each customer can use this code',
                'min_value': 1
            },
            'expiration_date': {
                'help_text': 'When this discount code expires'
            },
            'is_active': {
                'help_text': 'Whether this discount code is currently active'
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
        return obj.usages.count()
    
    def get_is_expired(self, obj):
        """Check if the discount code is expired."""
        if obj.expiration_date is None:
            return False
        # Compare only date parts (ignore time)
        now = timezone.now()
        today = now.date()
        expiry_date = obj.expiration_date.date()
        return expiry_date < today
    
    def get_status(self, obj):
        """Get human-readable status of the discount code."""
        if not obj.is_active:
            return "Inactive"
        elif obj.expiration_date is not None:
            # Compare only date parts (ignore time)
            now = timezone.now()
            today = now.date()
            expiry_date = obj.expiration_date.date()
            if expiry_date < today:
                return "Expired"
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
            'discount_code', 'customer', 'order', 'discount_amount'
        ]
    
    # Removed validation since it's already done in the service layer
    # and causes issues when passing IDs instead of instances


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


# Book Discount Serializers

class BookDiscountSerializer(serializers.ModelSerializer):
    """
    Serializer for BookDiscount model - used for CRUD operations by library admins.
    """
    
    book_name = serializers.CharField(source='book.name', read_only=True)
    book_price = serializers.DecimalField(source='book.price', max_digits=10, decimal_places=2, read_only=True)
    book_thumbnail = serializers.SerializerMethodField()
    
    class Meta:
        model = BookDiscount
        fields = [
            'id', 'code', 'discount_type', 'book', 'book_name', 'book_price', 'book_thumbnail',
            'discounted_price', 'usage_limit_per_customer',
            'start_date', 'end_date', 'is_active', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']
        extra_kwargs = {
            'code': {
                'required': True,
                'help_text': 'Unique discount code (e.g., BOOK20)',
                'max_length': 50
            },
            'discount_type': {
                'required': True,
                'help_text': 'Type of discount: fixed_price only'
            },
            'book': {
                'required': True,
                'help_text': 'Book this discount applies to'
            },
            'discounted_price': {
                'required': True,
                'help_text': 'Fixed discounted price for the book',
                'min_value': Decimal('0.01')
            },
            'usage_limit_per_customer': {
                'required': True,
                'help_text': 'Maximum number of times each customer can use this discount',
                'min_value': 1
            },
            'start_date': {
                'required': True,
                'help_text': 'When this discount becomes active'
            },
            'end_date': {
                'required': True,
                'help_text': 'When this discount expires'
            }
        }
    
    def get_book_thumbnail(self, obj):
        """Get the primary image URL for the book."""
        try:
            primary_image = obj.book.images.filter(is_primary=True).first()
            if primary_image:
                request = self.context.get('request')
                if request:
                    return request.build_absolute_uri(primary_image.image.url)
                return primary_image.image.url
        except:
            pass
        return None
    
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
        queryset = BookDiscount.objects.filter(code=code)
        if self.instance:
            queryset = queryset.exclude(pk=self.instance.pk)
        
        if queryset.exists():
            raise serializers.ValidationError("A discount code with this code already exists.")
        
        return code
    
    def validate(self, data):
        """
        Validate the discount data for fixed price discounts.
        """
        discounted_price = data.get('discounted_price')
        book = data.get('book')
        start_date = data.get('start_date')
        end_date = data.get('end_date')
        
        # Validate discounted price
        if not discounted_price:
            raise serializers.ValidationError({
                'discounted_price': 'Discounted price is required.'
            })
        if discounted_price <= 0:
            raise serializers.ValidationError({
                'discounted_price': 'Discounted price must be greater than 0.'
            })
        if book and book.price and discounted_price >= book.price:
            raise serializers.ValidationError({
                'discounted_price': 'Discounted price must be less than the original book price.'
            })
        
        # Validate date range
        if start_date and end_date and start_date >= end_date:
            raise serializers.ValidationError({
                'end_date': 'End date must be after start date.'
            })
        
        if start_date and start_date <= timezone.now():
            raise serializers.ValidationError({
                'start_date': 'Start date must be in the future.'
            })
        
        return data


class BookDiscountCreateSerializer(BookDiscountSerializer):
    """
    Serializer for creating new book discounts.
    """
    
    class Meta(BookDiscountSerializer.Meta):
        fields = BookDiscountSerializer.Meta.fields + ['created_by']
        extra_kwargs = {
            **BookDiscountSerializer.Meta.extra_kwargs,
            'created_by': {
                'required': True,
                'help_text': 'User who created this discount'
            }
        }


class BookDiscountUpdateSerializer(serializers.ModelSerializer):
    """
    Serializer for updating existing book discounts.
    Limited fields can be updated as per requirements.
    """
    
    class Meta:
        model = BookDiscount
        fields = [
            'discounted_price', 'usage_limit_per_customer',
            'start_date', 'end_date', 'is_active'
        ]
        extra_kwargs = {
            'discounted_price': {
                'help_text': 'Fixed discounted price',
                'min_value': Decimal('0.01')
            },
            'usage_limit_per_customer': {
                'help_text': 'Maximum number of times each customer can use this discount',
                'min_value': 1
            },
            'start_date': {
                'help_text': 'When this discount becomes active'
            },
            'end_date': {
                'help_text': 'When this discount expires'
            },
            'is_active': {
                'help_text': 'Whether this discount is currently active'
            }
        }
    
    def validate(self, data):
        """
        Validate the discount data for fixed price discounts.
        """
        # Get the instance to check current discount type
        instance = self.instance
        if not instance:
            return data
        
        discounted_price = data.get('discounted_price', instance.discounted_price)
        start_date = data.get('start_date', instance.start_date)
        end_date = data.get('end_date', instance.end_date)
        
        # Validate discounted price
        if not discounted_price:
            raise serializers.ValidationError({
                'discounted_price': 'Discounted price is required.'
            })
        if discounted_price <= 0:
            raise serializers.ValidationError({
                'discounted_price': 'Discounted price must be greater than 0.'
            })
        if instance.book.price and discounted_price >= instance.book.price:
            raise serializers.ValidationError({
                'discounted_price': 'Discounted price must be less than the original book price.'
            })
        
        # Validate date range
        if start_date and end_date and start_date >= end_date:
            raise serializers.ValidationError({
                'end_date': 'End date must be after start date.'
            })
        
        return data


class BookDiscountListSerializer(serializers.ModelSerializer):
    """
    Serializer for listing book discounts with additional computed fields.
    """
    book_name = serializers.CharField(source='book.name', read_only=True)
    book_price = serializers.DecimalField(source='book.price', max_digits=10, decimal_places=2, read_only=True)
    book_thumbnail = serializers.SerializerMethodField()
    usage_count = serializers.SerializerMethodField()
    is_expired = serializers.SerializerMethodField()
    is_not_started = serializers.SerializerMethodField()
    status = serializers.SerializerMethodField()
    final_price = serializers.SerializerMethodField()
    
    class Meta:
        model = BookDiscount
        fields = [
            'id', 'code', 'discount_type', 'book', 'book_name', 'book_price', 'book_thumbnail',
            'discounted_price', 'usage_limit_per_customer',
            'start_date', 'end_date', 'is_active', 'created_at', 'updated_at',
            'usage_count', 'is_expired', 'is_not_started', 'status', 'final_price'
        ]
    
    def get_book_thumbnail(self, obj):
        """Get the primary image URL for the book."""
        try:
            primary_image = obj.book.images.filter(is_primary=True).first()
            if primary_image:
                request = self.context.get('request')
                if request:
                    return request.build_absolute_uri(primary_image.image.url)
                return primary_image.image.url
        except:
            pass
        return None
    
    def get_usage_count(self, obj):
        """Get total usage count for this book discount."""
        return obj.usages.count()
    
    def get_is_expired(self, obj):
        """Check if the discount has expired."""
        return obj.is_expired()
    
    def get_is_not_started(self, obj):
        """Check if the discount hasn't started yet."""
        return obj.is_not_started()
    
    def get_status(self, obj):
        """Get human-readable status of the discount."""
        if not obj.is_active:
            return "Inactive"
        elif obj.is_not_started():
            return "Not Started"
        elif obj.is_expired():
            return "Expired"
        else:
            return "Active"
    
    def get_final_price(self, obj):
        """Get the final price after discount."""
        if obj.book.price:
            return obj.get_final_price(obj.book.price)
        return None


class BookDiscountValidationSerializer(serializers.Serializer):
    """
    Serializer for validating book discount codes during checkout.
    """
    code = serializers.CharField(
        max_length=50,
        required=True,
        help_text="Book discount code to validate"
    )
    book_id = serializers.IntegerField(
        required=True,
        help_text="ID of the book to apply discount to"
    )
    
    def validate_code(self, value):
        """
        Validate that the discount code exists and format it properly.
        """
        if not value:
            raise serializers.ValidationError("Discount code is required.")
        
        return value.upper().strip()
    
    def validate_book_id(self, value):
        """
        Validate that the book exists.
        """
        try:
            Book.objects.get(id=value)
        except Book.DoesNotExist:
            raise serializers.ValidationError("Book not found.")
        return value


class BookDiscountApplicationSerializer(serializers.Serializer):
    """
    Serializer for applying book discount codes during checkout.
    """
    code = serializers.CharField(
        max_length=50,
        required=True,
        help_text="Book discount code to apply"
    )
    book_id = serializers.IntegerField(
        required=True,
        help_text="ID of the book to apply discount to"
    )
    original_price = serializers.DecimalField(
        max_digits=10,
        decimal_places=2,
        required=True,
        help_text="Original book price"
    )
    discount_amount = serializers.DecimalField(
        max_digits=10,
        decimal_places=2,
        read_only=True,
        help_text="Amount discounted"
    )
    final_price = serializers.DecimalField(
        max_digits=10,
        decimal_places=2,
        read_only=True,
        help_text="Final price after discount"
    )


class BookDiscountUsageSerializer(serializers.ModelSerializer):
    """
    Serializer for BookDiscountUsage model - tracks when customers use book discounts.
    """
    discount_code_text = serializers.CharField(
        source='book_discount.code',
        read_only=True,
        help_text="The discount code that was used"
    )
    book_name = serializers.CharField(
        source='book_discount.book.name',
        read_only=True,
        help_text="Name of the book"
    )
    user_email = serializers.CharField(
        source='customer.email',
        read_only=True,
        help_text="Email of the user who used the code"
    )
    discount_type = serializers.CharField(
        source='book_discount.discount_type',
        read_only=True,
        help_text="Type of discount applied"
    )
    
    class Meta:
        model = BookDiscountUsage
        fields = [
            'id', 'book_discount', 'discount_code_text', 'book_name', 'customer', 'user_email',
            'original_price', 'discount_amount', 'final_price', 'used_at', 'discount_type'
        ]
        read_only_fields = ['id', 'used_at']


class BookDiscountUsageCreateSerializer(serializers.ModelSerializer):
    """
    Serializer for creating book discount usage records.
    """
    
    class Meta:
        model = BookDiscountUsage
        fields = [
            'book_discount', 'customer', 'order', 'original_price',
            'discount_amount', 'final_price'
        ]


class CustomerBookDiscountUsageSerializer(serializers.ModelSerializer):
    """
    Serializer for customer view of their book discount usage history.
    """
    discount_code_text = serializers.CharField(
        source='book_discount.code',
        read_only=True
    )
    book_name = serializers.CharField(
        source='book_discount.book.name',
        read_only=True
    )
    discount_type = serializers.CharField(
        source='book_discount.discount_type',
        read_only=True
    )
    savings = serializers.DecimalField(
        source='discount_amount',
        max_digits=10,
        decimal_places=2,
        read_only=True
    )
    
    class Meta:
        model = BookDiscountUsage
        fields = [
            'discount_code_text', 'book_name', 'discount_type', 'original_price',
            'savings', 'final_price', 'used_at'
        ]


class AvailableBooksSerializer(serializers.ModelSerializer):
    """
    Serializer for listing available books for discount creation.
    """
    author_name = serializers.CharField(source='author.name', read_only=True)
    category_name = serializers.CharField(source='category.name', read_only=True)
    thumbnail = serializers.SerializerMethodField()
    has_active_discount = serializers.SerializerMethodField()
    
    class Meta:
        model = Book
        fields = [
            'id', 'name', 'author_name', 'category_name', 'price',
            'thumbnail', 'is_available', 'has_active_discount'
        ]
    
    def get_thumbnail(self, obj):
        """Get the primary image URL for the book."""
        try:
            primary_image = obj.images.filter(is_primary=True).first()
            if primary_image:
                request = self.context.get('request')
                if request:
                    return request.build_absolute_uri(primary_image.image.url)
                return primary_image.image.url
        except:
            pass
        return None
    
    def get_has_active_discount(self, obj):
        """Check if the book has an active discount."""
        return BookDiscount.objects.get_discount_for_book(obj) is not None
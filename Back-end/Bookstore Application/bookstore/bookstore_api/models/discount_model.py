from django.db import models
from django.core.validators import MinValueValidator, MaxValueValidator
from django.core.exceptions import ValidationError
from django.utils import timezone
from .user_model import User


class DiscountCode(models.Model):
    """
    Model to store discount codes that can be applied to purchases.
    Only supports percentage discounts for purchase orders.
    """
    
    code = models.CharField(
        max_length=50,
        unique=True,
        help_text="Unique discount code (e.g., SAVE10)"
    )
    
    discount_percentage = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        validators=[MinValueValidator(0.01), MaxValueValidator(100.00)],
        help_text="Discount percentage (1-100%)"
    )
    
    usage_limit_per_customer = models.PositiveIntegerField(
        default=1,
        help_text="Maximum number of times each customer can use this code"
    )
    
    expiration_date = models.DateTimeField(
        help_text="When this discount code expires"
    )
    
    # Order type is always 'purchase' - no field needed as it's fixed
    # Discount type is always 'percentage' - no field needed as it's fixed
    
    is_active = models.BooleanField(
        default=True,
        help_text="Whether this discount code is currently active"
    )
    
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When this discount code was created"
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="When this discount code was last updated"
    )
    
    class Meta:
        db_table = 'discount_code'
        verbose_name = 'Discount Code'
        verbose_name_plural = 'Discount Codes'
        ordering = ['-created_at']
    
    def __str__(self):
        return f"{self.code} ({self.discount_percentage}% off)"
    
    def clean(self):
        """
        Custom validation for the discount code.
        """
        super().clean()
        
        # Ensure code is uppercase and alphanumeric
        if self.code:
            self.code = self.code.upper().strip()
            if not self.code.replace('_', '').replace('-', '').isalnum():
                raise ValidationError({
                    'code': 'Code can only contain letters, numbers, hyphens, and underscores.'
                })
    
    def save(self, *args, **kwargs):
        """
        Override save to ensure code is properly formatted.
        """
        self.full_clean()
        super().save(*args, **kwargs)
    
    def is_valid(self):
        """
        Check if the discount code is currently valid (active and not expired).
        """
        return self.is_active and self.expiration_date > timezone.now()
    
    def get_usage_count_for_user(self, user):
        """
        Get the number of times a specific user has used this discount code.
        """
        return self.usage_records.filter(user=user).count()
    
    def can_be_used_by_user(self, user):
        """
        Check if a user can use this discount code.
        """
        if not self.is_valid():
            return False, "Discount code is not valid or has expired"
        
        usage_count = self.get_usage_count_for_user(user)
        if usage_count >= self.usage_limit_per_customer:
            return False, f"You have already used this code the maximum number of times ({self.usage_limit_per_customer})"
        
        return True, "Code can be used"
    
    def calculate_discount_amount(self, total_amount):
        """
        Calculate the discount amount based on the percentage and total amount.
        """
        if not self.is_valid():
            return 0
        
        discount_amount = (total_amount * self.discount_percentage) / 100
        return round(discount_amount, 2)


class DiscountUsage(models.Model):
    """
    Model to track usage of discount codes by customers.
    Records each time a customer uses a discount code.
    """
    
    discount_code = models.ForeignKey(
        DiscountCode,
        on_delete=models.CASCADE,
        related_name='usage_records',
        help_text="The discount code that was used"
    )
    
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='discount_usages',
        help_text="User who used the discount code"
    )
    
    order_amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        help_text="Original order amount before discount"
    )
    
    discount_amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        help_text="Amount discounted from the order"
    )
    
    final_amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        help_text="Final amount after discount is applied"
    )
    
    used_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When the discount code was used"
    )
    
    # Reference to payment/order if needed for tracking
    payment_reference = models.CharField(
        max_length=100,
        blank=True,
        null=True,
        help_text="Reference to the payment/order where this discount was applied"
    )
    
    class Meta:
        db_table = 'discount_usage'
        verbose_name = 'Discount Usage'
        verbose_name_plural = 'Discount Usages'
        ordering = ['-used_at']
        # Ensure uniqueness per user per code per transaction
        unique_together = ['discount_code', 'user', 'payment_reference']
    
    def __str__(self):
        return f"{self.user.email} used {self.discount_code.code} - ${self.discount_amount} off"
    
    def save(self, *args, **kwargs):
        """
        Calculate final amount before saving if not provided.
        """
        if not self.final_amount:
            self.final_amount = self.order_amount - self.discount_amount
        super().save(*args, **kwargs)


class DiscountCodeManager(models.Manager):
    """
    Custom manager for DiscountCode model with utility methods.
    """
    
    def get_valid_codes(self):
        """
        Get all currently valid discount codes.
        """
        return self.filter(
            is_active=True,
            expiration_date__gt=timezone.now()
        )
    
    def get_expired_codes(self):
        """
        Get all expired discount codes.
        """
        return self.filter(
            expiration_date__lte=timezone.now()
        )
    
    def cleanup_expired_codes(self):
        """
        Remove expired discount codes that haven't been used.
        """
        expired_codes = self.get_expired_codes()
        unused_expired = expired_codes.filter(usage_records__isnull=True)
        count = unused_expired.count()
        unused_expired.delete()
        return count


# Add the custom manager to the DiscountCode model
DiscountCode.add_to_class('objects', DiscountCodeManager())
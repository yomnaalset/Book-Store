from django.db import models
from django.core.validators import MinValueValidator, MaxValueValidator
from django.utils import timezone
from .user_model import User


class DiscountCodeManager(models.Manager):
    """
    Custom manager for DiscountCode model.
    """
    
    def get_active_codes(self):
        """Get all active discount codes."""
        now = timezone.now()
        return self.filter(
            is_active=True,
            expiration_date__gt=now
        )
    
    def get_valid_code(self, code):
        """Get a valid discount code by code string."""
        now = timezone.now()
        try:
            return self.get(
                code=code,
                is_active=True,
                expiration_date__gt=now
            )
        except DiscountCode.DoesNotExist:
            return None
    
    def cleanup_expired_codes(self):
        """Deactivate expired discount codes."""
        now = timezone.now()
        expired_codes = self.filter(
            expiration_date__lte=now,
            is_active=True
        )
        count = expired_codes.update(is_active=False)
        return count


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
    
    # Use custom manager
    objects = DiscountCodeManager()
    
    class Meta:
        db_table = 'discount_code'
        verbose_name = 'Discount Code'
        verbose_name_plural = 'Discount Codes'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['code']),
            models.Index(fields=['is_active']),
            models.Index(fields=['expiration_date']),
            models.Index(fields=['created_at']),
        ]
    
    def __str__(self):
        return f"{self.code} ({self.discount_percentage}% off)"
    
    def clean(self):
        """
        Custom validation for the discount code.
        """
        if self.discount_percentage <= 0 or self.discount_percentage > 100:
            raise ValidationError(_("Discount percentage must be between 1 and 100."))
        
        if self.expiration_date and self.expiration_date <= timezone.now():
            raise ValidationError(_("Expiration date must be in the future."))
    
    def is_expired(self):
        """Check if the discount code has expired."""
        return timezone.now() > self.expiration_date
    
    def is_valid(self):
        """Check if the discount code is valid (active and not expired)."""
        return self.is_active and not self.is_expired()
    
    def can_be_used_by(self, customer):
        """Check if a customer can use this discount code."""
        if not self.is_valid():
            return False
        
        # Check usage limit
        usage_count = DiscountUsage.objects.filter(
            discount_code=self,
            customer=customer
        ).count()
        
        return usage_count < self.usage_limit_per_customer
    
    def get_discount_amount(self, order_total):
        """Calculate the discount amount for a given order total."""
        return (order_total * self.discount_percentage) / 100
    
    def get_final_price(self, order_total):
        """Calculate the final price after applying the discount."""
        discount_amount = self.get_discount_amount(order_total)
        return order_total - discount_amount
    
    def use_by_customer(self, customer, order):
        """Record usage of this discount code by a customer."""
        if not self.can_be_used_by(customer):
            raise ValidationError(_("This discount code cannot be used by this customer."))
        
        usage = DiscountUsage.objects.create(
            discount_code=self,
            customer=customer,
            order=order,
            discount_amount=self.get_discount_amount(order.total_amount)
        )
        
        return usage
    
    @classmethod
    def get_available_codes(cls):
        """Get all available discount codes."""
        return cls.objects.get_active_codes()
    
    @classmethod
    def validate_code(cls, code, customer):
        """Validate a discount code for a specific customer."""
        discount_code = cls.objects.get_valid_code(code)
        if not discount_code:
            return None, _("Invalid or expired discount code.")
        
        if not discount_code.can_be_used_by(customer):
            return None, _("You have already used this discount code the maximum number of times.")
        
        return discount_code, None


class DiscountUsage(models.Model):
    """
    Model to track usage of discount codes by customers.
    """
    discount_code = models.ForeignKey(
        DiscountCode,
        on_delete=models.CASCADE,
        related_name='usages',
        help_text="Discount code that was used"
    )
    
    customer = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='discount_usages',
        limit_choices_to={'user_type': 'customer'},
        help_text="Customer who used the discount code"
    )
    
    order = models.ForeignKey(
        'Order',
        on_delete=models.CASCADE,
        related_name='discount_usages',
        help_text="Order where the discount code was applied"
    )
    
    discount_amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        help_text="Amount of discount applied"
    )
    
    used_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When the discount code was used"
    )
    
    class Meta:
        db_table = 'discount_usage' 
        verbose_name = 'Discount Usage'
        verbose_name_plural = 'Discount Usages'
        ordering = ['-used_at']
        indexes = [
            models.Index(fields=['discount_code']),
            models.Index(fields=['customer']),
            models.Index(fields=['order']),
            models.Index(fields=['used_at']),
        ]
        unique_together = ['discount_code', 'order']  # One usage per order
    
    def __str__(self):
        return f"{self.customer.get_full_name()} used {self.discount_code.code} on {self.order}"
    
    @classmethod
    def get_customer_usage_stats(cls, customer):
        """
        Get discount usage statistics for a customer.
        """
        total_usage = cls.objects.filter(customer=customer).count()
        total_savings = cls.objects.filter(customer=customer).aggregate(
            total=models.Sum('discount_amount')
        )['total'] or 0
        
        return {
            'total_usage': total_usage,
            'total_savings': total_savings,
        }
    
    @classmethod
    def get_discount_usage_stats(cls):
        """
        Get overall discount usage statistics.
        """
        total_usage = cls.objects.count()
        total_savings = cls.objects.aggregate(
            total=models.Sum('discount_amount')
        )['total'] or 0
        
        # Get most popular discount codes
        popular_codes = cls.objects.values('discount_code__code').annotate(
            usage_count=models.Count('id')
        ).order_by('-usage_count')[:5]
        
        return {
            'total_usage': total_usage,
            'total_savings': total_savings,
            'popular_codes': popular_codes,
        }
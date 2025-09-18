from django.db import models
from django.core.validators import MinValueValidator
from .user_model import User
from .cart_model import Cart


class Payment(models.Model):
    """
    Base payment model for all payment types.
    """
    PAYMENT_STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('processing', 'Processing'),
        ('completed', 'Completed'),
        ('failed', 'Failed'),
        ('cancelled', 'Cancelled'),
        ('refunded', 'Refunded'),
    ]
    
    PAYMENT_TYPE_CHOICES = [
        ('credit_card', 'Credit Card'),
        ('cash_on_delivery', 'Cash on Delivery'),
        ('bank_transfer', 'Bank Transfer'),
        ('digital_wallet', 'Digital Wallet'),
    ]
    
    # Payment identification
    payment_id = models.CharField(
        max_length=50,
        unique=True,
        help_text="Unique payment identifier"
    )
    
    # Customer information
    customer = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='payments',
        limit_choices_to={'user_type': 'customer'},
        help_text="Customer making the payment"
    )
    
    # Payment details
    amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        validators=[MinValueValidator(0.01)],
        help_text="Payment amount"
    )
    
    currency = models.CharField(
        max_length=3,
        default='USD',
        help_text="Payment currency (ISO 4217 code)"
    )
    
    payment_type = models.CharField(
        max_length=20,
        choices=PAYMENT_TYPE_CHOICES,
        help_text="Type of payment method"
    )
    
    status = models.CharField(
        max_length=20,
        choices=PAYMENT_STATUS_CHOICES,
        default='pending',
        help_text="Current payment status"
    )
    
    # Cart reference
    cart = models.ForeignKey(
        Cart,
        on_delete=models.CASCADE,
        related_name='payments',
        help_text="Cart associated with this payment"
    )
    
    # Timestamps
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When the payment was created"
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="When the payment was last updated"
    )
    
    completed_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When the payment was completed"
    )
    
    # Additional information
    description = models.TextField(
        blank=True,
        null=True,
        help_text="Payment description or notes"
    )
    
    # Discount information
    original_amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Original amount before discount"
    )
    
    discount_code_used = models.CharField(
        max_length=50,
        null=True,
        blank=True,
        help_text="Discount code applied to this payment"
    )
    
    discount_amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0.00,
        help_text="Discount amount applied"
    )
    
    discount_percentage = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Discount percentage applied"
    )
    
    failure_reason = models.TextField(
        blank=True,
        null=True,
        help_text="Reason for payment failure if applicable"
    )
    
    class Meta:
        db_table = 'payment'
        verbose_name = 'Payment'
        verbose_name_plural = 'Payments'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['payment_id']),
            models.Index(fields=['customer']),
            models.Index(fields=['status']),
            models.Index(fields=['payment_type']),
            models.Index(fields=['created_at']),
        ]
    
    def __str__(self):
        return f"Payment {self.payment_id} - {self.customer.get_full_name()} ({self.get_status_display()})"
    
    def save(self, *args, **kwargs):
        """Override save to generate payment ID if not set."""
        if not self.payment_id:
            self.payment_id = self.generate_payment_id()
        super().save(*args, **kwargs)
    
    def generate_payment_id(self):
        """Generate a unique payment ID."""
        import uuid
        import time
        timestamp = str(int(time.time()))[-8:]
        random_part = str(uuid.uuid4().hex)[:6].upper()
        return f"PAY{timestamp}{random_part}"
    
    def can_be_processed(self):
        """Check if the payment can be processed."""
        return self.status == 'pending'
    
    def can_be_cancelled(self):
        """Check if the payment can be cancelled."""
        return self.status in ['pending', 'processing']
    
    def can_be_refunded(self):
        """Check if the payment can be refunded."""
        return self.status == 'completed'
    
    def mark_as_processing(self):
        """Mark the payment as processing."""
        self.status = 'processing'
        self.save()
    
    def mark_as_completed(self):
        """Mark the payment as completed."""
        self.status = 'completed'
        self.completed_at = timezone.now()
        self.save()
    
    def mark_as_failed(self, reason):
        """Mark the payment as failed."""
        self.status = 'failed'
        self.failure_reason = reason
        self.save()
    
    def mark_as_cancelled(self):
        """Mark the payment as cancelled."""
        self.status = 'cancelled'
        self.save()
    
    def mark_as_refunded(self):
        """Mark the payment as refunded."""
        self.status = 'refunded'
        self.save()
    
    def get_payment_summary(self):
        """Get a summary of the payment."""
        return {
            'payment_id': self.payment_id,
            'amount': self.amount,
            'currency': self.currency,
            'payment_type': self.get_payment_type_display(),
            'status': self.get_status_display(),
            'customer_name': self.customer.get_full_name(),
            'created_at': self.created_at,
        }
    
    @classmethod
    def get_payment_stats(cls):
        """
        Get statistics about payments.
        """
        total_payments = cls.objects.count()
        pending_payments = cls.objects.filter(status='pending').count()
        completed_payments = cls.objects.filter(status='completed').count()
        failed_payments = cls.objects.filter(status='failed').count()
        
        total_amount = cls.objects.filter(status='completed').aggregate(
            total=models.Sum('amount')
        )['total'] or 0
        
        return {
            'total_payments': total_payments,
            'pending_payments': pending_payments,
            'completed_payments': completed_payments,
            'failed_payments': failed_payments,
            'total_amount': total_amount,
        }


class CreditCardPayment(Payment):
    """
    Credit card payment model.
    """
    # Credit card information
    card_number = models.CharField(
        max_length=20,
        help_text="Last 4 digits of the credit card"
    )
    
    card_type = models.CharField(
        max_length=20,
        choices=[
            ('visa', 'Visa'),
            ('mastercard', 'Mastercard'),
            ('amex', 'American Express'),
            ('discover', 'Discover'),
            ('other', 'Other'),
        ],
        help_text="Type of credit card"
    )
    
    expiry_month = models.PositiveIntegerField(
        validators=[MinValueValidator(1)],
        help_text="Card expiry month (1-12)"
    )
    
    expiry_year = models.PositiveIntegerField(
        validators=[MinValueValidator(2024)],
        help_text="Card expiry year"
    )
    
    cardholder_name = models.CharField(
        max_length=100,
        help_text="Name on the credit card"
    )
    
    # Transaction information
    transaction_id = models.CharField(
        max_length=100,
        blank=True,
        null=True,
        help_text="External transaction ID from payment processor"
    )
    
    authorization_code = models.CharField(
        max_length=50,
        blank=True,
        null=True,
        help_text="Payment authorization code"
    )
    
    class Meta:
        db_table = 'credit_card_payment'
        verbose_name = 'Credit Card Payment'
        verbose_name_plural = 'Credit Card Payments'
    
    def __str__(self):
        return f"Credit Card Payment {self.payment_id} - {self.cardholder_name}"
    
    def get_masked_card_number(self):
        """Get a masked version of the card number for display."""
        if len(self.card_number) >= 4:
            return f"**** **** **** {self.card_number[-4:]}"
        return "**** **** **** ****"
    
    def is_expired(self):
        """Check if the credit card is expired."""
        from django.utils import timezone
        current_date = timezone.now().date()
        return current_date.year > self.expiry_year or (
            current_date.year == self.expiry_year and 
            current_date.month > self.expiry_month
        )
    
    def get_card_info(self):
        """Get credit card information for display."""
        return {
            'card_type': self.get_card_type_display(),
            'masked_number': self.get_masked_card_number(),
            'expiry': f"{self.expiry_month:02d}/{self.expiry_year}",
            'cardholder_name': self.cardholder_name,
        }


class CashOnDeliveryPayment(Payment):
    """
    Cash on delivery payment model.
    """
    # Delivery information
    delivery_address = models.TextField(
        help_text="Delivery address for cash collection"
    )
    
    delivery_city = models.CharField(
        max_length=100,
        help_text="City for delivery"
    )
    
    contact_phone = models.CharField(
        max_length=20,
        help_text="Contact phone for delivery"
    )
    
    # Cash collection details
    exact_change = models.BooleanField(
        default=False,
        help_text="Whether exact change is required"
    )
    
    preferred_delivery_time = models.CharField(
        max_length=50,
        blank=True,
        null=True,
        help_text="Preferred delivery time (e.g., 'Morning', 'Afternoon')"
    )
    
    delivery_notes = models.TextField(
        blank=True,
        null=True,
        help_text="Additional delivery instructions"        
    )
    
    class Meta:
        db_table = 'cash_on_delivery_payment'
        verbose_name = 'Cash on Delivery Payment'
        verbose_name_plural = 'Cash on Delivery Payments'
    
    def __str__(self):
        return f"Cash on Delivery Payment {self.payment_id} - {self.customer.get_full_name()}"
    
    def get_delivery_info(self):
        """Get delivery information for the payment."""
        return {
            'delivery_address': self.delivery_address,
            'delivery_city': self.delivery_city,
            'contact_phone': self.contact_phone,
            'exact_change': self.exact_change,
            'preferred_delivery_time': self.preferred_delivery_time,
            'delivery_notes': self.delivery_notes,
        }
    
    def can_be_delivered(self):
        """Check if the payment can be delivered."""
        return self.status == 'completed'
    
    def get_cash_collection_amount(self):
        """Get the amount to be collected in cash."""
        return self.amount

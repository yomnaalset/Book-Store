from django.db import models
from .user_model import User
from .cart_model import Cart

class Payment(models.Model):
    """
    Payment model for tracking customer payments.
    """
    PAYMENT_STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('processing', 'Processing'),
        ('completed', 'Completed'),
        ('failed', 'Failed'),
        ('refunded', 'Refunded'),
        ('cancelled', 'Cancelled'),
    ]
    
    PAYMENT_METHOD_CHOICES = [
        ('credit_card', 'Credit Card'),
        ('cash_on_delivery', 'Cash on Delivery'),
    ]
    
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='payments',
        help_text="User who made the payment"
    )
    
    amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        help_text="Payment amount"
    )
    
    payment_method = models.CharField(
        max_length=20,
        choices=PAYMENT_METHOD_CHOICES,
        help_text="Method of payment"
    )
    
    status = models.CharField(
        max_length=20,
        choices=PAYMENT_STATUS_CHOICES,
        default='pending',
        help_text="Current status of the payment"
    )
    
    transaction_id = models.CharField(
        max_length=100,
        blank=True,
        null=True,
        help_text="Payment gateway transaction ID (for credit card payments)"
    )
    
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When the payment was created"
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="When the payment was last updated"
    )
    
    class Meta:
        db_table = 'payment'
        verbose_name = 'Payment'
        verbose_name_plural = 'Payments'
        ordering = ['-created_at']
    
    def __str__(self):
        return f"Payment {self.id} - {self.get_payment_method_display()} - {self.get_status_display()}"


class CreditCardPayment(models.Model):
    """
    Credit card payment details.
    Note: In a production environment, you should never store full credit card details.
    This is just for demonstration purposes.
    """
    payment = models.OneToOneField(
        Payment,
        on_delete=models.CASCADE,
        related_name='credit_card_details',
        help_text="Associated payment"
    )
    
    card_holder_name = models.CharField(
        max_length=100,
        help_text="Name on the credit card"
    )
    
    # In a real system, you would only store the last 4 digits
    card_number_last_four = models.CharField(
        max_length=4,
        help_text="Last 4 digits of the credit card number"
    )
    
    # Store card type (Visa, MasterCard, etc.)
    card_type = models.CharField(
        max_length=20,
        help_text="Type of credit card"
    )
    
    # Store expiry month and year (not the full date)
    expiry_month = models.CharField(
        max_length=2,
        help_text="Credit card expiry month (MM)"
    )
    
    expiry_year = models.CharField(
        max_length=4,
        help_text="Credit card expiry year (YYYY)"
    )
    
    class Meta:
        db_table = 'credit_card_payment'
        verbose_name = 'Credit Card Payment'
        verbose_name_plural = 'Credit Card Payments'
    
    def __str__(self):
        return f"Credit Card Payment for {self.payment}"


class CashOnDeliveryPayment(models.Model):
    """
    Cash on delivery payment details.
    """
    payment = models.OneToOneField(
        Payment,
        on_delete=models.CASCADE,
        related_name='cash_on_delivery_details',
        help_text="Associated payment"
    )
    
    delivery_address = models.TextField(
        help_text="Delivery address for cash on delivery"
    )
    
    contact_phone = models.CharField(
        max_length=20,
        help_text="Contact phone number for delivery"
    )
    
    notes = models.TextField(
        blank=True,
        null=True,
        help_text="Additional notes for delivery"
    )
    
    class Meta:
        db_table = 'cash_on_delivery_payment'
        verbose_name = 'Cash on Delivery Payment'
        verbose_name_plural = 'Cash on Delivery Payments'
    
    def __str__(self):
        return f"Cash on Delivery Payment for {self.payment}"

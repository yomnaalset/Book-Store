from django.db import models
from django.utils import timezone
from .user_model import User


class ReturnStatus(models.TextChoices):
    PENDING = 'PENDING', 'Pending'
    APPROVED = 'APPROVED', 'Approved'
    ASSIGNED = 'ASSIGNED', 'Assigned'
    ACCEPTED = 'ACCEPTED', 'Accepted'
    IN_PROGRESS = 'IN_PROGRESS', 'In Progress'
    COMPLETED = 'COMPLETED', 'Completed'


class ReturnRequest(models.Model):
    """
    Model for managing book return requests
    """
    borrowing = models.ForeignKey(
        'bookstore_api.BorrowRequest',
        on_delete=models.CASCADE,
        related_name='return_requests',
        help_text="Associated borrow request"
    )
    status = models.CharField(
        max_length=20,
        choices=ReturnStatus.choices,
        default=ReturnStatus.PENDING,
        help_text="Current status of the return request"
    )
    delivery_manager = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='assigned_return_requests',
        limit_choices_to={'user_type': 'delivery_admin'},
        help_text="Delivery manager assigned to handle this return"
    )
    accepted_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When the delivery manager accepted the return request"
    )
    picked_up_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When the delivery manager started the return process (picked up the book)"
    )
    completed_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When the return was completed"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'return_request'
        verbose_name = 'Return Request'
        verbose_name_plural = 'Return Requests'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['borrowing']),
            models.Index(fields=['status']),
            models.Index(fields=['delivery_manager']),
            models.Index(fields=['created_at']),
        ]
    
    def __str__(self):
        return f"Return Request for {self.borrowing.book.name} - {self.get_status_display()}"


class ReturnFinePaymentMethod(models.TextChoices):
    CASH = 'cash', 'Cash'
    CARD = 'card', 'Card'


class FineReason(models.TextChoices):
    """Normalized fine reason values"""
    LATE_RETURN = 'late_return', 'Late Return'
    DAMAGED = 'damaged', 'Damaged'
    LOST = 'lost', 'Lost'


class ReturnFine(models.Model):
    """
    Model for managing fines related to return requests only.
    A fine is created only when:
    - The actual return date exceeds the expected return date (late return)
    - The item is returned damaged or lost
    
    Business Rule: No fine record is created if there is no fine (fine_amount = 0).
    """
    return_request = models.OneToOneField(
        ReturnRequest,
        on_delete=models.CASCADE,
        related_name='fine',
        help_text="Associated return request"
    )
    
    fine_amount = models.DecimalField(
        max_digits=8,
        decimal_places=2,
        help_text="Total fine amount (must be > 0)"
    )
    
    fine_reason = models.CharField(
        max_length=20,
        choices=FineReason.choices,
        help_text="Normalized reason for the fine (late_return, damaged, or lost)"
    )
    
    late_return = models.BooleanField(
        default=False,
        help_text="Whether the fine is due to late return"
    )
    
    damaged = models.BooleanField(
        default=False,
        help_text="Whether the fine is due to damage"
    )
    
    lost = models.BooleanField(
        default=False,
        help_text="Whether the fine is due to loss"
    )
    
    days_late = models.PositiveIntegerField(
        default=0,
        help_text="Number of days late (only for late return fines, must be > 0 if late_return=True)"
    )
    
    is_paid = models.BooleanField(
        default=False,
        help_text="Whether the fine has been paid"
    )
    
    paid_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When the fine was paid"
    )
    
    payment_method = models.CharField(
        max_length=10,
        choices=ReturnFinePaymentMethod.choices,
        null=True,
        blank=True,
        help_text="Payment method selected by customer (cash or card)"
    )
    
    paid_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='paid_fines',
        help_text="User who confirmed the payment (delivery manager for cash, system for card)"
    )
    
    transaction_id = models.CharField(
        max_length=255,
        null=True,
        blank=True,
        help_text="Transaction ID for card payments"
    )
    
    is_finalized = models.BooleanField(
        default=False,
        help_text="Whether the fine has been confirmed by admin and is locked"
    )
    
    finalized_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When the fine was finalized by admin"
    )
    
    finalized_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='finalized_return_fines',
        help_text="Admin who finalized the fine"
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'return_fine'
        verbose_name = 'Fine'
        verbose_name_plural = 'Fines'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['return_request']),
            models.Index(fields=['is_paid']),
            models.Index(fields=['created_at']),
        ]
        constraints = [
            models.CheckConstraint(
                check=models.Q(fine_amount__gt=0),
                name='return_fine_amount_positive'
            ),
            models.CheckConstraint(
                check=models.Q(
                    models.Q(late_return=True, days_late__gt=0) |
                    models.Q(late_return=False)
                ),
                name='return_fine_late_days_positive_if_late'
            ),
        ]
    
    def __str__(self):
        return f"Return Fine for Return Request #{self.return_request.id} - ${self.fine_amount} ({'Paid' if self.is_paid else 'Unpaid'})"
    
    def clean(self):
        """Validate fine business rules."""
        from django.core.exceptions import ValidationError
        
        # Fine amount must be positive
        if self.fine_amount <= 0:
            raise ValidationError("Fine amount must be greater than 0.")
        
        # At least one reason flag must be set
        if not (self.late_return or self.damaged or self.lost):
            raise ValidationError("At least one fine reason (late_return, damaged, or lost) must be set.")
        
        # If late return, days_late must be positive
        if self.late_return and self.days_late <= 0:
            raise ValidationError("days_late must be greater than 0 for late return fines.")
        
        # Auto-set fine_reason from boolean flags if not already set
        if not self.fine_reason:
            if self.late_return:
                self.fine_reason = FineReason.LATE_RETURN
            elif self.damaged:
                self.fine_reason = FineReason.DAMAGED
            elif self.lost:
                self.fine_reason = FineReason.LOST
    
    def save(self, *args, **kwargs):
        """Override save to enforce business rules and auto-set fine_reason."""
        # Auto-set fine_reason from boolean flags (priority: late_return > damaged > lost)
        if self.late_return:
            self.fine_reason = FineReason.LATE_RETURN
        elif self.damaged:
            self.fine_reason = FineReason.DAMAGED
        elif self.lost:
            self.fine_reason = FineReason.LOST
        
        self.full_clean()
        super().save(*args, **kwargs)
    
    def mark_as_paid(self, paid_by, transaction_id=None):
        """Mark the fine as paid"""
        self.is_paid = True
        self.paid_at = timezone.now()
        self.paid_by = paid_by
        if transaction_id:
            self.transaction_id = transaction_id
        self.save()

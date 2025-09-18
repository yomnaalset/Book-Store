from django.db import models
from django.utils import timezone
from datetime import timedelta
from django.core.validators import MinValueValidator, MaxValueValidator
from .user_model import User
from .library_model import Book


class BorrowStatusChoices(models.TextChoices):
    PENDING = 'pending', 'Pending'
    APPROVED = 'approved', 'Approved' 
    REJECTED = 'rejected', 'Rejected'
    ON_DELIVERY = 'on_delivery', 'On Delivery'
    ACTIVE = 'active', 'Active'
    EXTENDED = 'extended', 'Extended'
    RETURN_REQUESTED = 'return_requested', 'Return Requested'
    RETURNED = 'returned', 'Returned'
    LATE = 'late', 'Late'
    CANCELLED = 'cancelled', 'Cancelled'


class ExtensionStatusChoices(models.TextChoices):
    REQUESTED = 'requested', 'Extension Requested'


class FineStatusChoices(models.TextChoices):
    UNPAID = 'unpaid', 'Unpaid'
    PAID = 'paid', 'Paid'


class BorrowRequest(models.Model):
    """
    Model for managing book borrowing requests and active borrowings
    """
    customer = models.ForeignKey(
        User, 
        on_delete=models.CASCADE, 
        related_name='borrow_requests',
        limit_choices_to={'user_type': 'customer'}
    )
    book = models.ForeignKey(
        Book, 
        on_delete=models.CASCADE, 
        related_name='borrow_requests'
    )
    
    # Request details
    status = models.CharField(
        max_length=20,
        choices=BorrowStatusChoices.choices,
        default=BorrowStatusChoices.PENDING
    )
    borrow_period_days = models.PositiveIntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(30)],
        help_text="Number of days to borrow the book (1-30)"
    )
    
    # Dates and timestamps
    request_date = models.DateTimeField(auto_now_add=True)
    expected_return_date = models.DateTimeField(
        help_text="Initial expected return date based on borrow period"
    )
    
    # Approval details
    approved_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='approved_borrow_requests',
        limit_choices_to={'user_type': 'library_admin'}
    )
    approved_date = models.DateTimeField(null=True, blank=True)
    rejection_reason = models.TextField(blank=True, null=True)
    
    # Delivery details
    pickup_date = models.DateTimeField(null=True, blank=True)
    delivery_date = models.DateTimeField(null=True, blank=True)
    delivery_person = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='delivered_borrows',
        limit_choices_to={'user_type': 'delivery_admin'}
    )
    delivery_notes = models.TextField(blank=True, null=True)
    
    # Return details
    actual_return_date = models.DateTimeField(null=True, blank=True)
    final_return_date = models.DateTimeField(null=True, blank=True)
    
    # Fine information
    fine_amount = models.DecimalField(
        max_digits=8, 
        decimal_places=2, 
        default=0.00,
        help_text="Fine amount for late return"
    )
    fine_status = models.CharField(
        max_length=10,
        choices=FineStatusChoices.choices,
        default=FineStatusChoices.UNPAID
    )
    
    # Metadata
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'borrow_request'
        verbose_name = 'Borrow Request'
        verbose_name_plural = 'Borrow Requests'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['customer']),
            models.Index(fields=['book']),
            models.Index(fields=['status']),
            models.Index(fields=['request_date']),
            models.Index(fields=['expected_return_date']),
            models.Index(fields=['fine_status']),
        ]
    
    def __str__(self):
        return f"{self.customer.get_full_name()} - {self.book.name} ({self.get_status_display()})"
    
    def save(self, *args, **kwargs):
        """Override save to set expected return date if not set."""
        if not self.expected_return_date:
            self.expected_return_date = timezone.now() + timedelta(days=self.borrow_period_days)
        super().save(*args, **kwargs)
    
    def is_overdue(self):
        """Check if the borrow request is overdue."""
        if self.status == BorrowStatusChoices.ACTIVE and self.expected_return_date:
            return timezone.now() > self.expected_return_date
        return False
    
    def get_days_overdue(self):
        """Get the number of days overdue."""
        if self.is_overdue():
            delta = timezone.now() - self.expected_return_date
            return delta.days
        return 0
    
    def calculate_fine(self):
        """Calculate fine amount for late return."""
        if self.is_overdue():
            days_overdue = self.get_days_overdue()
            # Fine rate: 1.00 per day overdue
            fine_rate = 1.00
            return days_overdue * fine_rate
        return 0.00
    
    def can_be_extended(self):
        """Check if the borrow request can be extended."""
        return (
            self.status == BorrowStatusChoices.ACTIVE and 
            not self.is_overdue() and
            self.extensions.filter(status=ExtensionStatusChoices.REQUESTED).count() == 0
        )
    
    def can_request_return(self):
        """Check if return can be requested."""
        return self.status == BorrowStatusChoices.ACTIVE
    
    @classmethod
    def get_overdue_borrows(cls):
        """Get all overdue borrow requests."""
        return cls.objects.filter(
            status=BorrowStatusChoices.ACTIVE,
            expected_return_date__lt=timezone.now()
        )
    
    @classmethod
    def get_active_borrows(cls):
        """Get all active borrow requests."""
        return cls.objects.filter(status=BorrowStatusChoices.ACTIVE)
    
    @classmethod
    def get_pending_borrows(cls):
        """Get all pending borrow requests."""
        return cls.objects.filter(status=BorrowStatusChoices.PENDING)
    
    @classmethod
    def get_borrow_stats(cls):
        """
        Get statistics about borrow requests.
        """
        total_borrows = cls.objects.count()
        active_borrows = cls.objects.filter(status=BorrowStatusChoices.ACTIVE).count()
        pending_borrows = cls.objects.filter(status=BorrowStatusChoices.PENDING).count()
        overdue_borrows = cls.get_overdue_borrows().count()
        
        return {
            'total_borrows': total_borrows,
            'active_borrows': active_borrows,
            'pending_borrows': pending_borrows,
            'overdue_borrows': overdue_borrows,
        }


class BorrowExtension(models.Model):
    """
    Model for managing borrow extensions
    """
    borrow_request = models.ForeignKey(
        BorrowRequest,
        on_delete=models.CASCADE,
        related_name='extensions'
    )
    
    extension_days = models.PositiveIntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(7)],
        help_text="Number of additional days requested (1-7)"
    )
    
    status = models.CharField(
        max_length=20,
        choices=ExtensionStatusChoices.choices,
        default=ExtensionStatusChoices.REQUESTED
    )
    
    approved_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='approved_extensions',
        limit_choices_to={'user_type': 'library_admin'}
    )
    
    approved_date = models.DateTimeField(null=True, blank=True)
    rejection_reason = models.TextField(blank=True, null=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'borrow_extension'
        verbose_name = 'Borrow Extension'
        verbose_name_plural = 'Borrow Extensions'
        ordering = ['-created_at']
    
    def __str__(self):
        return f"Extension for {self.borrow_request} ({self.extension_days} days)"
    
    def approve(self, approved_by):
        """Approve the extension request."""
        self.status = ExtensionStatusChoices.APPROVED
        self.approved_by = approved_by
        self.approved_date = timezone.now()
        
        # Update the borrow request
        borrow = self.borrow_request
        borrow.expected_return_date += timedelta(days=self.extension_days)
        borrow.status = BorrowStatusChoices.EXTENDED
        borrow.save()
        
        self.save()
    
    def reject(self, rejected_by, reason):
        """Reject the extension request."""
        self.status = ExtensionStatusChoices.REJECTED
        self.rejection_reason = reason
        self.save()


class BorrowFine(models.Model):
    """
    Model for managing fines related to borrow requests
    """
    borrow_request = models.OneToOneField(
        BorrowRequest,
        on_delete=models.CASCADE,
        related_name='fine'
    )
    
    amount = models.DecimalField(
        max_digits=8,
        decimal_places=2,
        help_text="Fine amount"
    )
    
    status = models.CharField(
        max_length=10,
        choices=FineStatusChoices.choices,
        default=FineStatusChoices.UNPAID
    )
    
    reason = models.TextField(
        help_text="Reason for the fine"
    )
    
    paid_date = models.DateTimeField(null=True, blank=True)
    paid_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='paid_fines'
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'borrow_fine'
        verbose_name = 'Borrow Fine'
        verbose_name_plural = 'Borrow Fines'
        ordering = ['-created_at']
    
    def __str__(self):
        return f"Fine for {self.borrow_request} - {self.amount}"
    
    def mark_as_paid(self, paid_by):
        """Mark the fine as paid."""
        self.status = FineStatusChoices.PAID
        self.paid_by = paid_by
        self.paid_date = timezone.now()
        self.save()
    
    @classmethod
    def get_unpaid_fines(cls):
        """Get all unpaid fines."""
        return cls.objects.filter(status=FineStatusChoices.UNPAID)
    
    @classmethod
    def get_fine_stats(cls):
        """
        Get statistics about fines.
        """
        total_fines = cls.objects.count()
        unpaid_fines = cls.objects.filter(status=FineStatusChoices.UNPAID).count()
        paid_fines = cls.objects.filter(status=FineStatusChoices.PAID).count()
        
        return {
            'total_fines': total_fines,
            'unpaid_fines': unpaid_fines,
            'paid_fines': paid_fines,
        }


class BorrowStatistics(models.Model):
    """
    Model for storing borrowing statistics
    """
    date = models.DateField(unique=True)
    
    total_borrows = models.PositiveIntegerField(default=0)
    new_borrows = models.PositiveIntegerField(default=0)
    returns = models.PositiveIntegerField(default=0)
    extensions = models.PositiveIntegerField(default=0)
    fines_issued = models.PositiveIntegerField(default=0)
    fines_paid = models.PositiveIntegerField(default=0)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'borrow_statistics'
        verbose_name = 'Borrow Statistics'
        verbose_name_plural = 'Borrow Statistics'
        ordering = ['-date']
    
    def __str__(self):
        return f"Borrow Statistics for {self.date}"
    
    @classmethod
    def get_or_create_today(cls):
        """Get or create statistics for today."""
        today = timezone.now().date()
        stats, created = cls.objects.get_or_create(date=today)
        return stats
    
    @classmethod
    def update_today_stats(cls):
        """Update statistics for today."""
        stats = cls.get_or_create_today()
        
        today = timezone.now().date()
        
        # Count new borrows today
        stats.new_borrows = BorrowRequest.objects.filter(
            created_at__date=today
        ).count()
        
        # Count returns today
        stats.returns = BorrowRequest.objects.filter(
            actual_return_date__date=today,
            status=BorrowStatusChoices.RETURNED
        ).count()
        
        # Count extensions today
        stats.extensions = BorrowExtension.objects.filter(
            created_at__date=today,
            status=ExtensionStatusChoices.APPROVED
        ).count()
        
        # Count fines issued today
        stats.fines_issued = BorrowFine.objects.filter(
            created_at__date=today
        ).count()
        
        # Count fines paid today
        stats.fines_paid = BorrowFine.objects.filter(
            paid_date__date=today,
            status=FineStatusChoices.PAID
        ).count()
        
        stats.save()
        return stats
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
    APPROVED = 'approved', 'Approved'
    REJECTED = 'rejected', 'Rejected'


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
    final_return_date = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Final return date after any extensions"
    )
    
    # Extension tracking
    extension_used = models.BooleanField(default=False)
    extension_date = models.DateTimeField(null=True, blank=True)
    additional_days = models.PositiveIntegerField(
        default=0,
        help_text="Additional days granted through extension"
    )
    
    # Early return
    early_return_requested = models.BooleanField(default=False)
    early_return_date = models.DateTimeField(null=True, blank=True)
    return_reason = models.TextField(blank=True, null=True)
    
    # Rating and feedback
    rating = models.PositiveIntegerField(
        null=True,
        blank=True,
        validators=[MinValueValidator(1), MaxValueValidator(5)],
        help_text="Customer rating (1-5 stars)"
    )
    rating_comment = models.TextField(blank=True, null=True)
    rating_date = models.DateTimeField(null=True, blank=True)
    
    # Metadata
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'borrowing_requests'
        ordering = ['-request_date']
        indexes = [
            models.Index(fields=['customer', 'status']),
            models.Index(fields=['book', 'status']),
            models.Index(fields=['status']),
            models.Index(fields=['expected_return_date']),
            models.Index(fields=['final_return_date']),
        ]
    
    def __str__(self):
        return f"{self.customer.get_full_name()} - {self.book.name} ({self.get_status_display()})"
    
    def save(self, *args, **kwargs):
        # Set expected return date if not set
        if not self.expected_return_date and self.request_date:
            self.expected_return_date = self.request_date + timedelta(days=self.borrow_period_days)
        
        # Set final return date based on extensions
        if self.expected_return_date:
            self.final_return_date = self.expected_return_date + timedelta(days=self.additional_days)
        
        super().save(*args, **kwargs)
    
    @property
    def days_remaining(self):
        """Calculate days remaining until return"""
        if not self.final_return_date:
            return None
        
        if self.status in [BorrowStatusChoices.RETURNED, BorrowStatusChoices.CANCELLED]:
            return 0
            
        remaining = (self.final_return_date - timezone.now()).days
        return max(0, remaining)
    
    @property
    def days_overdue(self):
        """Calculate days overdue"""
        if not self.final_return_date or self.status == BorrowStatusChoices.RETURNED:
            return 0
            
        overdue = (timezone.now() - self.final_return_date).days
        return max(0, overdue)
    
    @property
    def is_overdue(self):
        """Check if the borrowing is overdue"""
        return self.days_overdue > 0
    
    @property
    def can_extend(self):
        """Check if borrowing can be extended"""
        return (
            not self.extension_used and 
            self.status in [BorrowStatusChoices.ACTIVE, BorrowStatusChoices.EXTENDED] and
            not self.is_overdue
        )
    
    @property
    def can_rate(self):
        """Check if borrowing experience can be rated"""
        return (
            self.status == BorrowStatusChoices.RETURNED and
            self.rating is None
        )


class BorrowExtension(models.Model):
    """
    Model for tracking extension requests
    """
    borrow_request = models.OneToOneField(
        BorrowRequest,
        on_delete=models.CASCADE,
        related_name='extension'
    )
    additional_days = models.PositiveIntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(14)],
        help_text="Additional days requested (1-14)"
    )
    status = models.CharField(
        max_length=20,
        choices=ExtensionStatusChoices.choices,
        default=ExtensionStatusChoices.REQUESTED
    )
    request_date = models.DateTimeField(auto_now_add=True)
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
    
    class Meta:
        db_table = 'borrowing_extensions'
    
    def __str__(self):
        return f"Extension for {self.borrow_request} - {self.additional_days} days"


class BorrowFine(models.Model):
    """
    Model for tracking fines on overdue books
    """
    borrow_request = models.OneToOneField(
        BorrowRequest,
        on_delete=models.CASCADE,
        related_name='fine'
    )
    daily_rate = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        default=4.00,
        help_text="Fine amount per day"
    )
    days_overdue = models.PositiveIntegerField()
    total_amount = models.DecimalField(
        max_digits=8,
        decimal_places=2,
        help_text="Total fine amount"
    )
    status = models.CharField(
        max_length=20,
        choices=FineStatusChoices.choices,
        default=FineStatusChoices.UNPAID
    )
    created_date = models.DateTimeField(auto_now_add=True)
    paid_date = models.DateTimeField(null=True, blank=True)
    payment_reference = models.CharField(max_length=100, blank=True, null=True)
    
    class Meta:
        db_table = 'borrowing_fines'
    
    def __str__(self):
        return f"Fine for {self.borrow_request} - ${self.total_amount}"
    
    def save(self, *args, **kwargs):
        # Calculate total amount
        self.total_amount = self.daily_rate * self.days_overdue
        super().save(*args, **kwargs)


class BorrowStatistics(models.Model):
    """
    Model for tracking borrowing statistics
    """
    book = models.OneToOneField(
        Book,
        on_delete=models.CASCADE,
        related_name='borrow_stats'
    )
    total_borrows = models.PositiveIntegerField(default=0)
    current_borrows = models.PositiveIntegerField(default=0)
    average_rating = models.DecimalField(
        max_digits=3,
        decimal_places=2,
        null=True,
        blank=True
    )
    total_ratings = models.PositiveIntegerField(default=0)
    last_borrowed = models.DateTimeField(null=True, blank=True)
    
    class Meta:
        db_table = 'borrowing_statistics'
        verbose_name_plural = 'Borrowing Statistics'
    
    def __str__(self):
        return f"Stats for {self.book.name} - {self.total_borrows} borrows"
    
    def update_rating(self):
        """Update average rating based on all ratings"""
        ratings = BorrowRequest.objects.filter(
            book=self.book,
            rating__isnull=False
        ).values_list('rating', flat=True)
        
        if ratings:
            self.average_rating = sum(ratings) / len(ratings)
            self.total_ratings = len(ratings)
        else:
            self.average_rating = None
            self.total_ratings = 0
        
        self.save()
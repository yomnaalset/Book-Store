from django.db import models
from django.core.validators import MinValueValidator, MaxValueValidator
from .user_model import User


class Complaint(models.Model):
    """
    Model for managing customer complaints and feedback.
    """
    COMPLAINT_TYPE_CHOICES = [
        ('service', 'Service Issue'),
        ('delivery', 'Delivery Problem'),
        ('product', 'Product Issue'),
        ('payment', 'Payment Problem'),
        ('general', 'General Complaint'),
        ('suggestion', 'Suggestion'),
        ('other', 'Other'),
    ]
    
    PRIORITY_CHOICES = [
        ('low', 'Low'),
        ('medium', 'Medium'),
        ('high', 'High'),
        ('urgent', 'Urgent'),
    ]
    
    STATUS_CHOICES = [
        ('open', 'Open'),
        ('in_progress', 'In Progress'),
        ('resolved', 'Resolved'),
        ('closed', 'Closed'),
    ]
    
    # Complaint identification
    complaint_id = models.CharField(
        max_length=20,
        unique=True,
        help_text="Unique complaint identifier"
    )
    
    # Customer information
    customer = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='complaints',
        limit_choices_to={'user_type': 'customer'},
        help_text="Customer who submitted the complaint"
    )
    
    # Complaint details
    title = models.CharField(
        max_length=200,
        help_text="Complaint title"
    )
    
    description = models.TextField(
        help_text="Detailed description of the complaint"
    )
    
    complaint_type = models.CharField(
        max_length=20,
        choices=COMPLAINT_TYPE_CHOICES,
        help_text="Type of complaint"
    )
    
    priority = models.CharField(
        max_length=10,
        choices=PRIORITY_CHOICES,
        default='medium',
        help_text="Priority level of the complaint"
    )
    
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='open',
        help_text="Current status of the complaint"
    )
    
    # Related objects (optional)
    related_order = models.ForeignKey(
        'bookstore_api.Order',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='complaints',
        help_text="Related order if applicable"
    )
    
    related_borrow_request = models.ForeignKey(
        'bookstore_api.BorrowRequest',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='complaints',
        help_text="Related borrow request if applicable"
    )
    
    # Assignment and resolution
    assigned_to = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='assigned_complaints',
        limit_choices_to={'user_type__in': ['library_admin', 'delivery_admin', 'system_admin']},
        help_text="Staff member assigned to handle this complaint"
    )
    
    resolution = models.TextField(
        blank=True,
        null=True,
        help_text="Resolution details"
    )
    
    resolved_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Date and time when complaint was resolved"
    )
    
    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'complaints'
        verbose_name = 'Complaint'
        verbose_name_plural = 'Complaints'
        ordering = ['-created_at']
    
    def __str__(self):
        return f"Complaint #{self.complaint_id} - {self.title}"
    
    def save(self, *args, **kwargs):
        if not self.complaint_id:
            # Generate unique complaint ID
            import uuid
            self.complaint_id = f"COMP-{uuid.uuid4().hex[:8].upper()}"
        super().save(*args, **kwargs)


class ComplaintResponse(models.Model):
    """
    Model for storing responses to complaints.
    """
    complaint = models.ForeignKey(
        Complaint,
        on_delete=models.CASCADE,
        related_name='responses',
        help_text="Complaint this response belongs to"
    )
    
    responder = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='complaint_responses',
        help_text="User who wrote this response"
    )
    
    response_text = models.TextField(
        help_text="Response content"
    )
    
    is_internal = models.BooleanField(
        default=False,
        help_text="Whether this is an internal note (not visible to customer)"
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        db_table = 'complaint_responses'
        verbose_name = 'Complaint Response'
        verbose_name_plural = 'Complaint Responses'
        ordering = ['created_at']
    
    def __str__(self):
        return f"Response to {self.complaint.complaint_id} by {self.responder.email}"

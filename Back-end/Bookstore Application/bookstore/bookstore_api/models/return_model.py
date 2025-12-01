from django.db import models
from django.utils import timezone
from .borrowing_model import BorrowRequest
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
        BorrowRequest,
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


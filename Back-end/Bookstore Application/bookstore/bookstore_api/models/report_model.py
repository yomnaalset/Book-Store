from django.db import models
from django.contrib.auth import get_user_model
from django.utils import timezone
from django.core.exceptions import ValidationError

User = get_user_model()


class Report(models.Model):
    """
    Model for storing generated reports
    """
    REPORT_TYPES = [
        ('dashboard', 'Dashboard Overview'),
        ('borrowing', 'Borrowing Report'),
        ('delivery', 'Delivery Report'),
        ('fines', 'Fines Report'),
        ('books', 'Book Popularity'),
        ('authors', 'Author Popularity'),
        ('sales', 'Sales Report'),
        ('users', 'User Report'),
    ]
    
    
    report_type = models.CharField(max_length=20, choices=REPORT_TYPES)
    title = models.CharField(max_length=200)
    description = models.TextField(blank=True, null=True)
    
    # Date range for the report
    start_date = models.DateTimeField(null=True, blank=True)
    end_date = models.DateTimeField(null=True, blank=True)
    
    # Report data (JSON field)
    data = models.JSONField(default=dict)
    
    
    # Metadata
    created_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name='created_reports')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    # Status
    is_generated = models.BooleanField(default=False)
    
    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Report'
        verbose_name_plural = 'Reports'
    
    def __str__(self):
        return f"{self.get_report_type_display()} - {self.title}"
    
    @property
    def is_expired(self):
        """Check if report is older than 7 days"""
        return (timezone.now() - self.created_at).days > 7
    
    def clean(self):
        if self.start_date and self.end_date and self.start_date > self.end_date:
            raise ValidationError("Start date cannot be after end date")


class ReportTemplate(models.Model):
    """
    Model for storing report templates
    """
    name = models.CharField(max_length=100)
    description = models.TextField(blank=True, null=True)
    report_type = models.CharField(max_length=20, choices=Report.REPORT_TYPES)
    
    # Template configuration
    template_config = models.JSONField(default=dict)
    
    # Metadata
    created_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name='created_templates')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    # Status
    is_active = models.BooleanField(default=True)
    is_public = models.BooleanField(default=False)
    
    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Report Template'
        verbose_name_plural = 'Report Templates'
    
    def __str__(self):
        return f"{self.name} ({self.get_report_type_display()})"

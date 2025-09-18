from django.db import models
from django.conf import settings


class FAQ(models.Model):
    question = models.CharField(max_length=500)
    answer = models.TextField()
    category = models.CharField(max_length=100, choices=[
        ('general', 'General'),
        ('account', 'Account'),
        ('books', 'Books'),
        ('borrowing', 'Borrowing'),
        ('technical', 'Technical'),
        ('payment', 'Payment'),
    ])
    is_active = models.BooleanField(default=True)
    order = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['order', 'created_at']
        verbose_name = 'FAQ'
        verbose_name_plural = 'FAQs'

    def __str__(self):
        return self.question


class UserGuide(models.Model):
    title = models.CharField(max_length=200)
    content = models.TextField()
    section = models.CharField(max_length=100, choices=[
        ('getting_started', 'Getting Started'),
        ('browsing_books', 'Browsing Books'),
        ('borrowing', 'Borrowing Books'),
        ('account', 'Account Management'),
        ('notifications', 'Notifications'),
        ('troubleshooting', 'Troubleshooting'),
    ])
    is_active = models.BooleanField(default=True)
    order = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['section', 'order', 'created_at']
        verbose_name = 'User Guide Article'
        verbose_name_plural = 'User Guide Articles'

    def __str__(self):
        return self.title


class TroubleshootingGuide(models.Model):
    title = models.CharField(max_length=200)
    description = models.TextField()
    solution = models.TextField()
    category = models.CharField(max_length=100, choices=[
        ('login', 'Login Issues'),
        ('app_crash', 'App Crashes'),
        ('performance', 'Performance'),
        ('sync', 'Data Sync'),
        ('notifications', 'Notifications'),
        ('other', 'Other'),
    ])
    is_active = models.BooleanField(default=True)
    order = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['category', 'order', 'created_at']
        verbose_name = 'Troubleshooting Guide'
        verbose_name_plural = 'Troubleshooting Guides'

    def __str__(self):
        return self.title


class SupportContact(models.Model):
    contact_type = models.CharField(max_length=50, choices=[
        ('live_chat', 'Live Chat'),
        ('email', 'Email Support'),
        ('phone', 'Phone Support'),
    ])
    title = models.CharField(max_length=200)
    description = models.TextField()
    contact_info = models.CharField(max_length=200)  # URL, email, or phone number
    is_available = models.BooleanField(default=True)
    available_hours = models.CharField(max_length=100, blank=True)
    is_admin_only = models.BooleanField(default=False)
    order = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['order', 'contact_type']
        verbose_name = 'Support Contact'
        verbose_name_plural = 'Support Contacts'

    def __str__(self):
        return f"{self.get_contact_type_display()} - {self.title}"

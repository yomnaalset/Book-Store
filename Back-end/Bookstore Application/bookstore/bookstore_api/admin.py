from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.contrib.auth.models import Group
from .models import User, UserProfile, Library, Notification, DiscountCode, DiscountUsage
from .models.library_model import Book, BookImage, Category, Author


class UserProfileInline(admin.StackedInline):
    """
    Inline admin for UserProfile.
    """
    model = UserProfile
    can_delete = False
    verbose_name_plural = 'Profile'
    fields = ('date_of_birth', 'profile_picture')


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    """
    Custom admin for User model.
    """
    inlines = (UserProfileInline,)
    
    # Fields to display in the user list
    list_display = (
        'email', 'first_name', 'last_name', 'user_type', 
        'is_active', 'is_staff', 'date_joined'
    )
    
    # Fields that can be used to filter the user list
    list_filter = (
        'user_type', 'is_active', 'is_staff', 'is_superuser', 'date_joined'
    )
    
    # Fields that can be searched
    search_fields = ('email', 'first_name', 'last_name', 'phone_number')
    
    # Default ordering
    ordering = ('-date_joined',)
    
    # Fields for the user creation form
    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': (
                'email', 'username', 'password1', 'password2',
                'first_name', 'last_name', 'user_type'
            ),
        }),
        ('Contact Information', {
            'fields': ('phone_number', 'address', 'city'),
        }),
        ('Permissions', {
            'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions'),
        }),
    )
    
    # Fields for the user edit form
    fieldsets = (
        (None, {
            'fields': ('email', 'username', 'password')
        }),
        ('Personal info', {
            'fields': ('first_name', 'last_name', 'user_type', 'phone_number')
        }),
        ('Address', {
            'fields': ('address', 'city'),
            'classes': ('collapse',)
        }),
        ('Permissions', {
            'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions'),
        }),
        ('Important dates', {
            'fields': ('last_login', 'date_joined', 'last_updated'),
            'classes': ('collapse',)
        }),
    )
    
    # Read-only fields
    readonly_fields = ('date_joined', 'last_updated', 'last_login')
    
    # Custom actions
    actions = ['make_active', 'make_inactive']
    
    def make_active(self, request, queryset):
        """Action to activate selected users."""
        queryset.update(is_active=True)
        self.message_user(request, f'{queryset.count()} users were successfully activated.')
    make_active.short_description = "Activate selected users"
    
    def make_inactive(self, request, queryset):
        """Action to deactivate selected users."""
        queryset.update(is_active=False)
        self.message_user(request, f'{queryset.count()} users were successfully deactivated.')
    make_inactive.short_description = "Deactivate selected users"
    
    # Email verification action removed


@admin.register(Library)
class LibraryAdmin(admin.ModelAdmin):
    """
    Custom admin for Library model.
    """
    
    # Fields to display in the library list
    list_display = (
        'name', 'is_active', 'created_by', 'created_at', 
        'last_updated_by', 'updated_at', 'has_logo'
    )
    
    # Fields that can be used to filter the library list
    list_filter = (
        'is_active', 'created_at', 'updated_at'
    )
    
    # Fields that can be searched
    search_fields = ('name', 'details', 'created_by__email', 'last_updated_by__email')
    
    # Default ordering
    ordering = ('-created_at',)
    
    # Fields for the library form
    fieldsets = (
        ('Library Information', {
            'fields': ('name', 'logo', 'details')
        }),
        ('Status', {
            'fields': ('is_active',)
        }),
        ('Metadata', {
            'fields': (
                'created_by', 'created_at', 
                'last_updated_by', 'updated_at'
            ),
            'classes': ('collapse',)
        }),
    )
    
    # Read-only fields
    readonly_fields = ('created_at', 'updated_at')
    
    # Limit created_by and last_updated_by to library administrators
    def formfield_for_foreignkey(self, db_field, request, **kwargs):
        if db_field.name in ['created_by', 'last_updated_by']:
            kwargs["queryset"] = User.objects.filter(user_type='library_admin')
        return super().formfield_for_foreignkey(db_field, request, **kwargs)
    
    # Custom methods for display
    def has_logo(self, obj):
        return obj.has_logo()
    has_logo.boolean = True
    has_logo.short_description = 'Has Logo'
    
    # Override save to ensure single library constraint
    def save_model(self, request, obj, form, change):
        if not change:  # Creating new library
            obj.created_by = request.user
        obj.last_updated_by = request.user
        super().save_model(request, obj, form, change)


@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    """
    Custom admin for UserProfile model.
    """
    
    # Fields to display in the profile list
    list_display = (
        'user', 'user_email', 'user_type', 'date_of_birth', 
        'has_profile_picture', 'created_at'
    )
    
    # Fields that can be used to filter the profile list
    list_filter = (
        'user__user_type', 'created_at', 'updated_at'
    )
    
    # Fields that can be searched
    search_fields = (
        'user__email', 'user__first_name', 'user__last_name'
    )
    
    # Default ordering
    ordering = ('-created_at',)
    
    # Custom methods for display
    def user_email(self, obj):
        return obj.user.email
    user_email.short_description = 'Email'
    
    def user_type(self, obj):
        return obj.user.get_user_type_display()
    user_type.short_description = 'User Type'
    
    def has_profile_picture(self, obj):
        return bool(obj.profile_picture)
    has_profile_picture.boolean = True
    has_profile_picture.short_description = 'Has Picture'


# Register Library models
@admin.register(Book)
class BookAdmin(admin.ModelAdmin):
    """Custom admin for Book model."""
    list_display = ('name', 'author', 'price', 'category', 'is_available', 'is_new')
    list_filter = ('is_available', 'is_new', 'category', 'created_at')
    search_fields = ('name', 'description', 'author__name')


@admin.register(BookImage)
class BookImageAdmin(admin.ModelAdmin):
    """Custom admin for BookImage model."""
    list_display = ('id', 'book', 'is_primary', 'uploaded_at')
    list_filter = ('is_primary', 'uploaded_at')
    search_fields = ('book__name', 'alt_text')


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    """Custom admin for Category model."""
    list_display = ('name', 'is_active', 'get_books_count')
    list_filter = ('is_active',)
    search_fields = ('name', 'description')


@admin.register(Author)
class AuthorAdmin(admin.ModelAdmin):
    """Custom admin for Author model."""
    list_display = ('name', 'nationality', 'birth_date', 'get_books_count')
    search_fields = ('name', 'bio', 'nationality')


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    """Custom admin for Notification model."""
    list_display = ('recipient', 'title', 'notification_type', 'status', 'created_at')
    list_filter = ('notification_type', 'status', 'created_at')
    search_fields = ('recipient__email', 'title', 'message')
    readonly_fields = ('created_at',)
    
    actions = ['mark_as_read', 'mark_as_unread']
    
    def mark_as_read(self, request, queryset):
        """Action to mark selected notifications as read."""
        queryset.update(status='read')
        self.message_user(request, f'{queryset.count()} notifications were marked as read.')
    mark_as_read.short_description = "Mark selected notifications as read"
    
    def mark_as_unread(self, request, queryset):
        """Action to mark selected notifications as unread."""
        queryset.update(status='unread')
        self.message_user(request, f'{queryset.count()} notifications were marked as unread.')
    mark_as_unread.short_description = "Mark selected notifications as unread"


class DiscountUsageInline(admin.TabularInline):
    """
    Inline admin for DiscountUsage to show usage history in DiscountCode admin.
    """
    model = DiscountUsage
    extra = 0
    readonly_fields = ('customer', 'order', 'discount_amount', 'used_at')
    fields = ('customer', 'order', 'discount_amount', 'used_at')
    
    def has_add_permission(self, request, obj=None):
        """Prevent manual addition of usage records."""
        return False


@admin.register(DiscountCode)
class DiscountCodeAdmin(admin.ModelAdmin):
    """
    Custom admin for DiscountCode model.
    Provides comprehensive management interface for library administrators.
    """
    
    # Fields to display in the discount code list
    list_display = (
        'code', 'discount_percentage', 'usage_limit_per_customer',
        'expiration_date', 'is_active', 'is_expired', 'usage_count',
        'created_at'
    )
    
    # Fields that can be used to filter the discount code list
    list_filter = (
        'is_active', 'discount_percentage', 'created_at', 'expiration_date'
    )
    
    # Fields that can be searched
    search_fields = ('code', 'discount_percentage')
    
    # Default ordering
    ordering = ('-created_at',)
    
    # Fields for the discount code form
    fieldsets = (
        ('Discount Code Information', {
            'fields': ('code', 'discount_percentage', 'usage_limit_per_customer', 'expiration_date')
        }),
        ('Status', {
            'fields': ('is_active',)
        }),
        ('Metadata', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    # Read-only fields
    readonly_fields = ('created_at', 'updated_at')
    
    # Include usage history inline
    inlines = [DiscountUsageInline]
    
    # Custom actions
    actions = ['activate_codes', 'deactivate_codes', 'cleanup_expired']
    
    def activate_codes(self, request, queryset):
        """Action to activate selected discount codes."""
        queryset.update(is_active=True)
        self.message_user(request, f'{queryset.count()} discount codes were activated.')
    activate_codes.short_description = "Activate selected discount codes"
    
    def deactivate_codes(self, request, queryset):
        """Action to deactivate selected discount codes."""
        queryset.update(is_active=False)
        self.message_user(request, f'{queryset.count()} discount codes were deactivated.')
    deactivate_codes.short_description = "Deactivate selected discount codes"
    
    def cleanup_expired(self, request, queryset):
        """Action to clean up expired, unused discount codes."""
        from django.utils import timezone
        expired_unused = queryset.filter(
            expiration_date__lte=timezone.now(),
            usages__isnull=True
        )
        count = expired_unused.count()
        expired_unused.delete()
        self.message_user(request, f'{count} expired unused discount codes were deleted.')
    cleanup_expired.short_description = "Delete expired unused codes"
    
    # Custom methods for display
    def is_expired(self, obj):
        """Check if the discount code is expired."""
        from django.utils import timezone
        return obj.expiration_date <= timezone.now()
    is_expired.boolean = True
    is_expired.short_description = 'Expired'
    
    def usage_count(self, obj):
        """Get the total usage count for this discount code."""
        return obj.usages.count()
    usage_count.short_description = 'Total Uses'
    
    # Limit queryset to ensure proper permissions
    def get_queryset(self, request):
        """
        Override to ensure only library admins can manage discount codes.
        """
        qs = super().get_queryset(request)
        # Additional permission checks can be added here if needed
        return qs


@admin.register(DiscountUsage)
class DiscountUsageAdmin(admin.ModelAdmin):
    """
    Custom admin for DiscountUsage model.
    Primarily for viewing usage history and statistics.
    """
    
    # Fields to display in the usage list
    list_display = (
        'discount_code', 'customer', 'order', 'discount_amount', 'used_at'
    )
    
    # Fields that can be used to filter the usage list
    list_filter = (
        'discount_code', 'used_at', 'customer__user_type'
    )
    
    # Fields that can be searched
    search_fields = (
        'discount_code__code', 'customer__email', 'customer__first_name', 
        'customer__last_name'
    )
    
    # Default ordering
    ordering = ('-used_at',)
    
    # Fields for the usage form
    fieldsets = (
        ('Usage Information', {
            'fields': (
                'discount_code', 'customer', 'order', 'discount_amount'
            )
        }),
        ('Metadata', {
            'fields': ('used_at',),
            'classes': ('collapse',)
        }),
    )
    
    # Read-only fields (usage records should not be manually edited)
    readonly_fields = ('used_at',)
    
    # Limit permissions
    def has_add_permission(self, request):
        """Prevent manual addition of usage records."""
        return False
    
    def has_change_permission(self, request, obj=None):
        """Prevent editing of usage records."""
        return False
    
    def has_delete_permission(self, request, obj=None):
        """Allow deletion only for superusers or specific cases."""
        return request.user.is_superuser
    
    # Custom methods for display
    def get_discount_percentage(self, obj):
        """Get the discount percentage from the related discount code."""
        return f"{obj.discount_code.discount_percentage}%"
    get_discount_percentage.short_description = 'Discount %'


# Unregister the default Group admin (optional)
admin.site.unregister(Group)


# Customize admin site headers
admin.site.site_header = "Bookstore Administration"
admin.site.site_title = "Bookstore Admin"
admin.site.index_title = "Welcome to Bookstore Administration"

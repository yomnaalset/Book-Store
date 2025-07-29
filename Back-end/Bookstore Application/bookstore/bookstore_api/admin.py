from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.contrib.auth.models import Group
from django.utils.translation import gettext_lazy as _

from .models import User, UserProfile, Library
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
        (_('Personal info'), {
            'fields': ('first_name', 'last_name', 'user_type', 'phone_number')
        }),
        (_('Address'), {
            'fields': ('address', 'city'),
            'classes': ('collapse',)
        }),
        (_('Permissions'), {
            'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions'),
        }),
        (_('Important dates'), {
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


# Unregister the default Group admin (optional)
admin.site.unregister(Group)


# Customize admin site headers
admin.site.site_header = "Bookstore Administration"
admin.site.site_title = "Bookstore Admin"
admin.site.index_title = "Welcome to Bookstore Administration"

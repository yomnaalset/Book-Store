from rest_framework import permissions
from django.contrib.auth.models import AnonymousUser


class IsCustomer(permissions.BasePermission):
    """
    Custom permission to only allow customers to access certain views.
    """
    message = "This action is only available to customers."
    
    def has_permission(self, request, view):
        return (
            request.user and 
            request.user.is_authenticated and 
            request.user.user_type == 'customer' and
            request.user.is_active
        )


class IsLibraryAdmin(permissions.BasePermission):
    """
    Custom permission to only allow library administrators to access certain views.
    """
    message = "This action is only available to library administrators."
    
    def has_permission(self, request, view):
        return (
            request.user and 
            request.user.is_authenticated and 
            request.user.is_library_admin() and
            request.user.is_active
        )


class IsSystemAdmin(permissions.BasePermission):
    """
    Custom permission to only allow library administrators to access certain views.
    """
    message = "This action is only available to library administrators."
    
    def has_permission(self, request, view):
        return (
            request.user and 
            request.user.is_authenticated and 
            request.user.is_library_admin() and
            request.user.is_active
        )


class IsDeliveryAdmin(permissions.BasePermission):
    """
    Custom permission to only allow delivery administrators to access certain views.
    """
    message = "This action is only available to delivery administrators."
    
    def has_permission(self, request, view):
        return (
            request.user and 
            request.user.is_authenticated and 
            request.user.user_type == 'delivery_admin' and
            request.user.is_active
        )


class IsAnyAdmin(permissions.BasePermission):
    """
    Custom permission to allow any type of administrator (system or delivery).
    """
    message = "This action is only available to administrators."
    
    def has_permission(self, request, view):
        return (
            request.user and 
            request.user.is_authenticated and 
            request.user.user_type in ['library_admin', 'delivery_admin'] and
            request.user.is_active
        )


class IsDeliveryAdminOrLibraryAdmin(permissions.BasePermission):
    """
    Custom permission to allow delivery administrators or library administrators.
    """
    message = "This action is only available to delivery or library administrators."
    
    def has_permission(self, request, view):
        return (
            request.user and 
            request.user.is_authenticated and 
            request.user.user_type in ['library_admin', 'delivery_admin'] and
            request.user.is_active
        )


class IsOwnerOrAdmin(permissions.BasePermission):
    """
    Custom permission to allow users to edit their own data or allow admins to edit any data.
    """
    message = "You can only edit your own data unless you are an administrator."
    
    def has_permission(self, request, view):
        return request.user and request.user.is_authenticated and request.user.is_active
    
    def has_object_permission(self, request, view, obj):
        # Check if the object has a user attribute (for profiles, orders, etc.)
        if hasattr(obj, 'user'):
            return (
                obj.user == request.user or 
                request.user.user_type in ['library_admin', 'delivery_admin']
            )
        
        # Check if the object is the user itself
        if hasattr(obj, 'email'):  # User model
            return (
                obj == request.user or 
                request.user.user_type in ['library_admin', 'delivery_admin']
            )
        
        return False


class IsOwnerOrReadOnly(permissions.BasePermission):
    """
    Custom permission to allow users to read any data but only edit their own.
    """
    message = "You can only edit your own data."
    
    def has_permission(self, request, view):
        return request.user and request.user.is_authenticated and request.user.is_active
    
    def has_object_permission(self, request, view, obj):
        # Read permissions for any authenticated user
        if request.method in permissions.SAFE_METHODS:
            return True
        
        # Write permissions only to the owner
        if hasattr(obj, 'user'):
            return obj.user == request.user
        
        if hasattr(obj, 'email'):  # User model
            return obj == request.user
        
        return False


class IsVerifiedUser(permissions.BasePermission):
    """
    Custom permission to only allow verified users to access certain views.
    """
    message = "Your account must be verified to perform this action."
    
    def has_permission(self, request, view):
        return (
            request.user and 
            request.user.is_authenticated and 
            request.user.is_active
        )


class AllowAnonymousRegistration(permissions.BasePermission):
    """
    Custom permission to allow anonymous users to register accounts.
    This is typically used for registration endpoints.
    """
    
    def has_permission(self, request, view):
        # Allow POST requests for registration even from anonymous users
        if request.method == 'POST':
            return True
        
        # For other methods, require authentication
        return request.user and request.user.is_authenticated


class IsCustomerOrReadOnlyAdmin(permissions.BasePermission):
    """
    Custom permission for customer-specific resources that admins can view but not modify.
    """
    message = "Customers can modify this resource, administrators can only view it."
    
    def has_permission(self, request, view):
        return request.user and request.user.is_authenticated and request.user.is_active
    
    def has_object_permission(self, request, view, obj):
        # Customers can do anything with their own data
        if request.user.user_type == 'customer':
            if hasattr(obj, 'user'):
                return obj.user == request.user
            if hasattr(obj, 'email'):
                return obj == request.user
        
        # Admins can only read
        if request.user.user_type in ['library_admin', 'delivery_admin']:
            return request.method in permissions.SAFE_METHODS
        
        return False


class CanManageUsers(permissions.BasePermission):
    """
    Permission for user management operations (create admin accounts, deactivate users, etc.).
    Only library administrators should have this permission.
    """
    message = "User management operations are restricted to library administrators."
    
    def has_permission(self, request, view):
        return (
            request.user and 
            request.user.is_authenticated and 
            request.user.user_type == 'library_admin' and
            request.user.is_active
        )


class CanManageDeliveries(permissions.BasePermission):
    """
    Permission for delivery management operations.
    Both system and delivery administrators should have this permission.
    """
    message = "Delivery management operations require administrative privileges."
    
    def has_permission(self, request, view):
        return (
            request.user and 
            request.user.is_authenticated and 
            request.user.user_type in ['library_admin', 'delivery_admin'] and
            request.user.is_active
        )


class HasAdvancedPermissions(permissions.BasePermission):
    """
    Permission for operations requiring advanced access level.
    """
    message = "This operation requires advanced permissions."
    
    def has_permission(self, request, view):
        if not (request.user and request.user.is_authenticated and request.user.is_active):
            return False
        
        # Library admins always have advanced permissions
        if request.user.is_library_admin():
            return True
        
        # For delivery admins, grant basic permissions
        if request.user.user_type == 'delivery_admin':
            return True
        
        return False


class HasFullPermissions(permissions.BasePermission):
    """
    Permission for operations requiring full access level.
    Typically only for library administrators with full access.
    """
    message = "This operation requires full administrative permissions."
    
    def has_permission(self, request, view):
        if not (request.user and request.user.is_authenticated and request.user.is_active):
            return False
        
        # Only library admins can have full permissions
        if request.user.is_library_admin():
            return True  # All library admins have full access
        
        return False    


# Convenience permission classes for common combinations
class CustomerOrAdmin(permissions.BasePermission):
    """
    Allow customers for their own data or any admin for any data.
    """
    
    def has_permission(self, request, view):
        return request.user and request.user.is_authenticated and request.user.is_active
    
    def has_object_permission(self, request, view, obj):
        # Admins can access anything
        if request.user.user_type in ['library_admin', 'delivery_admin']:
            return True
        
        # Customers can access their own data
        if request.user.user_type == 'customer':
            if hasattr(obj, 'user'):
                return obj.user == request.user
            if hasattr(obj, 'email'):
                return obj == request.user
        
        return False


class IsLibraryAdminReadOnly(permissions.BasePermission):
    """
    Custom permission to only allow library admins read-only access.
    """
    def has_permission(self, request, view):
        # Allow read-only access for library admins
        if request.user.is_library_admin():
            return request.method in permissions.SAFE_METHODS
        return False


class IsAdminUser(permissions.BasePermission):
    """
    Allows access only to admin users.
    """
    def has_permission(self, request, view):
        return bool(request.user and request.user.is_staff)

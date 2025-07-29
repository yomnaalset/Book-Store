from django.contrib.auth import authenticate
from django.core.mail import send_mail
from django.template.loader import render_to_string
from django.utils.html import strip_tags
from django.conf import settings
from django.db import transaction
from django.core.exceptions import ValidationError
from typing import Dict, Any, Optional
import logging

from ..models import User, UserProfile
from ..serializers import (
    CustomerRegistrationSerializer,
    LibraryAdminRegistrationSerializer,
    DeliveryAdminRegistrationSerializer,
)
from ..utils import format_error_message

logger = logging.getLogger(__name__)


class UserRegistrationService:
    """
    Service class for handling user registration and account creation.
    """
    
    @staticmethod
    def get_registration_serializer(user_type: str):
        """
        Get the appropriate serializer based on user type.
        """
        serializer_map = {
            'customer': CustomerRegistrationSerializer,
            'library_admin': LibraryAdminRegistrationSerializer,
            'delivery_admin': DeliveryAdminRegistrationSerializer,
        }
        
        if user_type not in serializer_map:
            raise ValidationError(f"Invalid user type: {user_type}")
        
        return serializer_map[user_type]
    
    @staticmethod
    def library_admin_exists() -> bool:
        """
        Check if a library administrator already exists in the system.
        
        Returns:
            Boolean indicating if a library admin exists
        """
        return User.objects.filter(user_type='library_admin', is_active=True).exists()
    
    @staticmethod
    def system_admin_exists() -> bool:
        """
        Deprecated: Use library_admin_exists() instead.
        Check if a library administrator already exists in the system.
        
        Returns:
            Boolean indicating if a library admin exists
        """
        return UserRegistrationService.library_admin_exists()
    
    @staticmethod
    def get_available_user_types() -> Dict[str, Any]:
        """
        Get available user types for registration.
        Library admin option is disabled if one already exists.
        
        Returns:
            Dictionary with available user types and their availability
        """
        library_admin_exists = UserRegistrationService.library_admin_exists()
        
        user_types = {
            'customer': {
                'value': 'customer',
                'label': 'Customer',
                'available': True,
                'description': 'Regular customer account for browsing and purchasing books'
            },
            'delivery_admin': {
                'value': 'delivery_admin', 
                'label': 'Delivery Administrator',
                'available': True,
                'description': 'Delivery administrator account for managing deliveries'
            },
            'library_admin': {
                'value': 'library_admin',
                'label': 'Library Administrator', 
                'available': not library_admin_exists,
                'description': 'Library administrator account for managing the entire system',
                'disabled_reason': 'A library administrator already exists' if library_admin_exists else None
            }
        }
        
        return {
            'user_types': user_types,
            'library_admin_exists': library_admin_exists,
            'available_types': [ut for ut_key, ut in user_types.items() if ut['available']]
        }
    
    @staticmethod
    @transaction.atomic
    def create_user_account(user_type: str, registration_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Create a new user account with the specified type and data.
        
        Args:
            user_type: Type of user account to create
            registration_data: User registration data
            
        Returns:
            Dictionary containing success status and user data or error message
        """
        try:
            # Check if library admin registration is allowed
            if user_type == 'library_admin':
                if UserRegistrationService.library_admin_exists():
                    return {
                        'success': False,
                        'message': 'A library administrator already exists in the system. Only one library administrator is allowed.',
                        'error_code': 'LIBRARY_ADMIN_EXISTS'
                    }
            # Backward compatibility check for system_admin
            elif user_type == 'system_admin':
                if UserRegistrationService.library_admin_exists():
                    return {
                        'success': False,
                        'message': 'A library administrator already exists in the system. Only one library administrator is allowed.',
                        'error_code': 'LIBRARY_ADMIN_EXISTS'
                    }
            
            # Get the appropriate serializer
            serializer_class = UserRegistrationService.get_registration_serializer(user_type)
            serializer = serializer_class(data=registration_data)
            
            if serializer.is_valid():
                # Create the user
                user = serializer.save()
                
                # Send welcome email
                UserRegistrationService.send_welcome_email(user)
                
                # Log successful registration
                logger.info(f"New {user_type} account created: {user.email}")
                
                return {
                    'success': True,
                    'message': f'{user.get_user_type_display()} account created successfully',
                    'user_id': user.id,
                    'email': user.email,
                    'user_type': user.user_type,
                }
            else:
                return {
                    'success': False,
                    'message': 'Invalid registration data',
                    'errors': serializer.errors
                }
                
        except ValidationError as e:
            return {
                'success': False,
                'message': 'Validation error',
                'errors': format_error_message(str(e))
            }
        except Exception as e:
            logger.error(f"Error creating {user_type} account: {str(e)}")
            return {
                'success': False,
                'message': 'An error occurred during registration',
                'errors': format_error_message(str(e))
            }
    
    @staticmethod
    def send_welcome_email(user: User) -> bool:
        """
        Send welcome email to newly registered user.
        
        Args:
            user: User instance
            
        Returns:
            Boolean indicating if email was sent successfully
        """
        try:
            subject = f'Welcome to Bookstore - {user.get_user_type_display()} Account Created'
            
            # Prepare context for email template
            context = {
                'user': user,
                'user_type': user.get_user_type_display(),
                'site_name': 'Bookstore',
                'contact_email': settings.EMAIL_HOST_USER,
            }
            
            # Generate email content based on user type
            if user.is_customer():
                template_name = 'emails/welcome_customer.html'
                message = f"""
                Dear {user.get_full_name()},
                
                Welcome to Bookstore! Your customer account has been successfully created.
                
                You can now:
                - Browse our extensive book collection
                - Add books to your wishlist and cart
                - Track your orders
                - Leave reviews and ratings
                
                Thank you for joining our community of book lovers!
                
                Best regards,
                The Bookstore Team
                """
            elif user.is_library_admin():
                template_name = 'emails/welcome_library_admin.html'
                message = f"""
                Dear {user.get_full_name()},
                
                Your Library Administrator account has been created for Bookstore.
                
                As a library administrator, you have access to:
                - User management
                - System configuration
                - Reports and analytics
                - Content management
                - Library management
                
                Please contact your supervisor for additional training and access details.
                
                Best regards,
                The Bookstore Team
                """
            else:  # delivery_admin
                template_name = 'emails/welcome_delivery_admin.html'
                message = f"""
                Dear {user.get_full_name()},
                
                Your Delivery Administrator account has been created for Bookstore.
                
                As a delivery administrator, you can:
                - Manage delivery schedules
                - Track shipments
                - Update delivery status
                - Handle delivery-related customer inquiries
                
                Please contact your supervisor for delivery system access and training.
                
                Best regards,
                The Bookstore Team
                """
            
            # Send email
            send_mail(
                subject=subject,
                message=message,
                from_email=settings.EMAIL_HOST_USER,
                recipient_list=[user.email],
                fail_silently=False,
            )
            
            logger.info(f"Welcome email sent to {user.email}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to send welcome email to {user.email}: {str(e)}")
            return False
    
    @staticmethod
    def validate_registration_data(user_type: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Validate registration data without creating the user.
        
        Args:
            user_type: Type of user account
            data: Registration data to validate
            
        Returns:
            Dictionary with validation results
        """
        try:
            # Check library admin constraint first
            if user_type == 'library_admin':
                if UserRegistrationService.library_admin_exists():
                    return {
                        'valid': False,
                        'errors': {
                            'user_type': ['A library administrator already exists in the system. Only one library administrator is allowed.']
                        }
                    }
            # Backward compatibility check for system_admin
            elif user_type == 'system_admin':
                if UserRegistrationService.library_admin_exists():
                    return {
                        'valid': False,
                        'errors': {
                            'user_type': ['A library administrator already exists in the system. Only one library administrator is allowed.']
                        }
                    }
            
            serializer_class = UserRegistrationService.get_registration_serializer(user_type)
            serializer = serializer_class(data=data)
            
            if serializer.is_valid():
                return {
                    'valid': True,
                    'message': 'Registration data is valid'
                }
            else:
                return {
                    'valid': False,
                    'errors': serializer.errors
                }
                
        except Exception as e:
            return {
                'valid': False,
                'errors': format_error_message(str(e))
            }


class UserAccountService:
    """
    Service class for managing user accounts after creation.
    """
    
    # Email and phone verification methods removed as fields no longer exist
    
    @staticmethod
    def deactivate_account(user: User, reason: str = None) -> bool:
        """
        Deactivate user account.
        """
        try:
            user.is_active = False
            user.save(update_fields=['is_active'])
            
            if reason:
                logger.info(f"Account deactivated for {user.email}. Reason: {reason}")
            else:
                logger.info(f"Account deactivated for {user.email}")
            
            return True
        except Exception as e:
            logger.error(f"Failed to deactivate account for {user.email}: {str(e)}")
            return False
    
    @staticmethod
    def reactivate_account(user: User) -> bool:
        """
        Reactivate user account.
        """
        try:
            user.is_active = True
            user.save(update_fields=['is_active'])
            logger.info(f"Account reactivated for {user.email}")
            return True
        except Exception as e:
            logger.error(f"Failed to reactivate account for {user.email}: {str(e)}")
            return False
    
    @staticmethod
    def update_profile(user: User, profile_data: Dict[str, Any]) -> bool:
        """
        Update user profile information.
        """
        try:
            profile = user.profile
            
            for field, value in profile_data.items():
                if hasattr(profile, field):
                    setattr(profile, field, value)
            
            profile.save()
            logger.info(f"Profile updated for user {user.email}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to update profile for {user.email}: {str(e)}")
            return False
    
    @staticmethod
    def get_user_statistics() -> Dict[str, Any]:
        """
        Get user registration statistics.
        """
        try:
            stats = {
                'total_users': User.objects.count(),
                'active_users': User.objects.filter(is_active=True).count(),
                'customers': User.objects.filter(user_type='customer').count(),
                'library_admins': User.objects.filter(user_type='library_admin').count(),
                'delivery_admins': User.objects.filter(user_type='delivery_admin').count(),
                'library_admin_exists': User.objects.filter(user_type='library_admin', is_active=True).exists(),
            }
            
            return stats
            
        except Exception as e:
            logger.error(f"Failed to get user statistics: {str(e)}")
            return {}


class AuthenticationService:
    """
    Service class for user authentication operations.
    """
    
    @staticmethod
    def authenticate_user(email: str, password: str) -> Optional[User]:
        """
        Authenticate user with email and password.
        """
        try:
            user = authenticate(username=email, password=password)
            if user and user.is_active:
                logger.info(f"User authenticated: {email}")
                return user
            else:
                logger.warning(f"Authentication failed for: {email}")
                return None
        except Exception as e:
            logger.error(f"Authentication error for {email}: {str(e)}")
            return None
    
    @staticmethod
    def is_user_authorized(user: User, required_user_type: str) -> bool:
        """
        Check if user is authorized for a specific user type requirement.
        """
        if not user or not user.is_active:
            return False
        
        if required_user_type == 'any':
            return True
        elif required_user_type == 'admin':
            return user.is_library_admin() or user.is_delivery_admin()
        else:
            return user.user_type == required_user_type 
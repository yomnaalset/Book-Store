from rest_framework import generics, status, permissions
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.views import APIView
from django.contrib.auth import authenticate
from django.shortcuts import get_object_or_404
from django.contrib.auth.tokens import default_token_generator
from django.utils.encoding import force_bytes, force_str
from django.utils.http import urlsafe_base64_encode, urlsafe_base64_decode
from django.core.mail import send_mail
from django.conf import settings
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.exceptions import TokenError
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator
import logging

from ..models import User, UserProfile
from ..serializers import (
    UnifiedRegistrationSerializer,
    UserDetailSerializer,
    UserProfileSerializer,
    ProfileUpdateSerializer,
    UserTypeOptionsSerializer,
    LanguagePreferenceSerializer,
    LanguageOptionsSerializer,
    EmailChangeSerializer,
    PasswordChangeSerializer,
)
from ..services import UserRegistrationService, UserAccountService, AuthenticationService
from ..permissions import (
    AllowAnonymousRegistration,
    IsOwnerOrAdmin,
)
from ..utils import format_error_message

logger = logging.getLogger(__name__)


class UserTypeOptionsView(APIView):
    """
    API view to get available user type options for registration.
    Shows which user types are available, with library_admin disabled if one already exists.
    """
    permission_classes = [permissions.AllowAny]
    
    def get(self, request):
        """
        Get available user type options.
        """
        try:
            user_type_options = UserRegistrationService.get_available_user_types()
            
            return Response({
                'success': True,
                'message': 'User type options retrieved successfully',
                'data': user_type_options
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving user type options: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve user type options',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@method_decorator(csrf_exempt, name='dispatch')
class RegisterView(generics.CreateAPIView):
    """
    Simplified registration view for all user types (customer, library_admin, delivery_admin).
    Only requires basic information: email, password, password_confirm, first_name, last_name, user_type.
    Profile information (address, city, mobile number, profile picture) is handled separately.
    
    Library administrator registration is limited to one account only.
    """
    serializer_class = UnifiedRegistrationSerializer
    permission_classes = [AllowAnonymousRegistration]
    
    def create(self, request, *args, **kwargs):
        """
        Create a new user account of the specified type.
        """
        try:
            # Check library admin constraint before processing
            user_type = request.data.get('user_type')
            if user_type == 'library_admin':
                if UserRegistrationService.library_admin_exists():
                    return Response({
                        'success': False,
                        'message': 'A library administrator already exists in the system. Only one library administrator is allowed.',
                        'error_code': 'LIBRARY_ADMIN_EXISTS',
                        'errors': {
                            'user_type': ['A library administrator already exists in the system.']
                        }
                    }, status=status.HTTP_400_BAD_REQUEST)
            # Backward compatibility check for system_admin
            elif user_type == 'system_admin':
                if UserRegistrationService.library_admin_exists():
                    return Response({
                        'success': False,
                        'message': 'A library administrator already exists in the system. Only one library administrator is allowed.',
                        'error_code': 'LIBRARY_ADMIN_EXISTS',
                        'errors': {
                            'user_type': ['A library administrator already exists in the system.']
                        }
                    }, status=status.HTTP_400_BAD_REQUEST)
            
            serializer = self.get_serializer(data=request.data)
            
            if serializer.is_valid():
                # Create the user
                user = serializer.save()
                
                # Send welcome email (optional - commented out for now)
                # UserRegistrationService.send_welcome_email(user)
                
                # Log successful registration
                logger.info(f"New {user.user_type} account created: {user.email}")
                
                return Response({
                    'success': True,
                    'message': f'{user.get_user_type_display()} account created successfully',
                    'data': {
                        'user_id': user.id,
                        'email': user.email,
                        'user_type': user.user_type,
                        'full_name': user.get_full_name(),
                        'preferred_language': user.preferred_language,
                        'profile_complete': user.has_complete_profile(),
                        'profile_completion_percentage': user.get_profile_completion_percentage(),
                        'is_library_admin': user.is_library_admin(),
                    }
                }, status=status.HTTP_201_CREATED)
            else:
                return Response({
                    'success': False,
                    'message': 'Invalid registration data',
                    'errors': serializer.errors
                }, status=status.HTTP_400_BAD_REQUEST)
                
        except Exception as e:
            logger.error(f"Error in registration: {str(e)}")
            return Response({
                'success': False,
                'message': 'Registration failed',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@method_decorator(csrf_exempt, name='dispatch')
class LoginView(APIView):
    """
    API view for user authentication and JWT token generation.
    Requires only email and password.
    """
    permission_classes = [permissions.AllowAny]
    
    def get(self, request):
        """
        Handle GET requests for connectivity testing.
        Returns a simple status message.
        """
        return Response({
            'success': True,
            'message': 'Login endpoint is available. Use POST method for authentication.',
            'method': 'GET',
            'note': 'This endpoint accepts POST requests for user login.'
        }, status=status.HTTP_200_OK)
    
    def post(self, request):
        """
        Authenticate user and return JWT tokens.
        """
        email = request.data.get('email')
        password = request.data.get('password')
        
        if not email or not password:
            return Response({
                'success': False,
                'message': 'Email and password are required',
                'errors': {'email': ['Email is required'], 'password': ['Password is required']}
            }, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            user = AuthenticationService.authenticate_user(email, password)
            
            if user:
                # Generate JWT tokens
                refresh = RefreshToken.for_user(user)
                access_token = refresh.access_token
                
                return Response({
                    'success': True,
                    'message': 'Login successful',
                    'data': {
                        'user_id': user.id,
                        'email': user.email,
                        'user_type': user.user_type,
                        'full_name': user.get_full_name(),
                        'preferred_language': user.preferred_language,
                        'access_token': str(access_token),
                        'refresh_token': str(refresh),
                        'profile_complete': user.has_complete_profile(),
                        'profile_completion_percentage': user.get_profile_completion_percentage(),
                        'is_library_admin': user.is_library_admin(),
                    }
                }, status=status.HTTP_200_OK)
            else:
                return Response({
                    'success': False,
                    'message': 'Invalid credentials provided',
                    'errors': {'credentials': ['Invalid email or password']}
                }, status=status.HTTP_401_UNAUTHORIZED)
                
        except Exception as e:
            logger.error(f"Error in login: {str(e)}")
            return Response({
                'success': False,
                'message': 'Login failed',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class LogoutView(APIView):
    """
    API view for user logout.
    Blacklists the refresh token to invalidate it.
    """
    permission_classes = [permissions.AllowAny]
    
    def post(self, request):
        """
        Logout user by blacklisting the refresh token.
        """
        try:
            refresh_token = request.data.get('refresh_token')
            
            if not refresh_token:
                return Response({
                    'success': False,
                    'message': 'Refresh token is required for logout',
                    'errors': {'refresh_token': ['Refresh token is required']}
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Blacklist the refresh token
            token = RefreshToken(refresh_token)
            token.blacklist()
            
            # Get user email from token if available
            user_email = "Unknown"
            try:
                user_email = token.payload.get('email', 'Unknown')
            except:
                pass
            
            logger.info(f"User {user_email} logged out successfully")
            
            return Response({
                'success': True,
                'message': 'Logout successful'
            }, status=status.HTTP_200_OK)
            
        except TokenError as e:
            logger.warning(f"Invalid token during logout: {str(e)}")
            return Response({
                'success': False,
                'message': 'Invalid refresh token',
                'errors': {'refresh_token': ['Invalid or expired refresh token']}
            }, status=status.HTTP_400_BAD_REQUEST)
            
        except Exception as e:
            logger.error(f"Error during logout: {str(e)}")
            return Response({
                'success': False,
                'message': 'Logout failed',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class PasswordResetRequestView(APIView):
    """
    API view for requesting password reset.
    Sends password reset email to user.
    """
    permission_classes = [permissions.AllowAny]
    
    def post(self, request):
        """
        Send password reset email to user.
        """
        email = request.data.get('email')
        
        if not email:
            return Response({
                'success': False,
                'message': 'Email is required',
                'errors': {'email': ['Email is required']}
            }, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            user = User.objects.filter(email__iexact=email).first()
            
            if user:
                # Generate password reset token
                token = default_token_generator.make_token(user)
                uid = urlsafe_base64_encode(force_bytes(user.pk))
                
                # Send password reset email
                reset_url = f"{settings.FRONTEND_URL}/password-reset-confirm/{uid}/{token}/"
                
                subject = 'Password Reset Request - Bookstore'
                message = f"""
                Dear {user.get_full_name()},
                
                You have requested to reset your password for your Bookstore account.
                
                Please click the link below to reset your password:
                {reset_url}
                
                If you did not request this password reset, please ignore this email.
                This link will expire in 24 hours.
                
                Best regards,
                The Bookstore Team
                """
                
                send_mail(
                    subject=subject,
                    message=message,
                    from_email=settings.EMAIL_HOST_USER,
                    recipient_list=[user.email],
                    fail_silently=False,
                )
                
                logger.info(f"Password reset email sent to {email}")
            
            # Always return success to prevent email enumeration
            return Response({
                'success': True,
                'message': 'If an account with this email exists, a password reset link has been sent.'  
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error in password reset request: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to process password reset request',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class PasswordResetView(APIView):
    """
    API view for confirming password reset with token.
    """
    permission_classes = [permissions.AllowAny]
    
    def post(self, request, uidb64, token):
        """
        Reset user password using token.
        """
        new_password = request.data.get('password')
        confirm_password = request.data.get('confirm_password')
        
        if not new_password or not confirm_password:
            return Response({
                'success': False,
                'message': 'Password and confirmation are required',
                'errors': {'password': ['Password fields are required']}
            }, status=status.HTTP_400_BAD_REQUEST)
        
        if new_password != confirm_password:
            return Response({
                'success': False,
                'message': 'Passwords do not match',
                'errors': {'password': ['Passwords do not match']}
            }, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            # Decode user ID
            uid = force_str(urlsafe_base64_decode(uidb64))
            user = User.objects.get(pk=uid)
            
            # Verify token
            if default_token_generator.check_token(user, token):
                # Set new password
                user.set_password(new_password)
                user.save()
                
                logger.info(f"Password reset successful for user {user.email}")
                
                return Response({
                    'success': True,
                    'message': 'Password has been reset successfully'
                }, status=status.HTTP_200_OK)
            else:
                return Response({
                    'success': False,
                    'message': 'Invalid or expired reset link',
                    'errors': {'token': ['Invalid or expired reset link']}
                }, status=status.HTTP_400_BAD_REQUEST)
                
        except (TypeError, ValueError, OverflowError, User.DoesNotExist):
            return Response({
                'success': False,
                'message': 'Invalid reset link',
                'errors': {'token': ['Invalid reset link']}
            }, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error(f"Error in password reset: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to reset password',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)




class UserProfileView(generics.RetrieveUpdateAPIView):
    """
    Personal Profile Interface for all user types (Customer, Library Administrator, Delivery Administrator).
    
    Features:
    - Display first name and last name from registration
    - Allow editing of address, city, mobile number, and profile picture
    - Save all changes to database
    - Available to all authenticated user types
    """
    serializer_class = ProfileUpdateSerializer
    permission_classes = [permissions.IsAuthenticated]  # Changed to allow all authenticated users
    
    def get_object(self):
        """
        Get the current user's profile.
        """
        return self.request.user
    
    def get(self, request, *args, **kwargs):
        """
        Retrieve user profile information for the profile interface.
        Shows registration data and profile fields.
        """
        try:
            user = self.get_object()
            
            # Prepare profile data for the interface
            profile_data = {
                'user_info': {
                    'id': user.id,
                    'email': user.email,
                    'user_type': user.user_type,
                    'user_type_display': user.get_user_type_display(),
                    'date_joined': user.date_joined,
                },
                'registration_data': {
                    'first_name': user.first_name,
                    'last_name': user.last_name,
                },
                'profile_data': {
                    'phone_number': user.profile.phone_number,
                    'address': user.profile.address,
                    'city': user.profile.city,
                    'state': user.profile.state,
                    'zip_code': user.profile.zip_code,
                    'country': user.profile.country,
                    'profile_picture': user.profile.profile_picture.url if user.profile.profile_picture else None,
                    'date_of_birth': user.profile.date_of_birth,
                },
                'profile_stats': {
                    'profile_complete': user.has_complete_profile(),
                    'completion_percentage': user.get_profile_completion_percentage(),
                }
            }
            
            return Response({
                'success': True,
                'message': 'Profile retrieved successfully',
                'data': profile_data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving profile: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve profile',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def patch(self, request, *args, **kwargs):
        """
        Update profile information through the profile interface using PATCH.
        Allows partial updates: only changed fields are updated.
        Supports updating: first_name, last_name, phone_number, address, city, profile_picture.
        Profile picture can be deleted by setting it to null.
        """
        try:
            user = self.get_object()
            
            # Filter out empty strings and convert them to None for optional fields
            filtered_data = {}
            for key, value in request.data.items():
                if value == '' and key in ['phone_number', 'address', 'city', 'state', 'zip_code', 'country']:
                    filtered_data[key] = None  # Convert empty strings to None for optional fields
                elif value is not None:  # Only include non-None values
                    filtered_data[key] = value
            
            
            # Check if user is requesting to delete profile picture
            profile_picture_deleted = False
            if 'profile_picture' in filtered_data and filtered_data['profile_picture'] is None:
                profile_picture_deleted = True
            
            serializer = self.get_serializer(user, data=filtered_data, partial=True)
            
            if serializer.is_valid():
                updated_user = serializer.save()
                
                # Prepare success message with specific handling for date of birth
                updated_fields = list(filtered_data.keys())
                if 'date_of_birth' in updated_fields:
                    if profile_picture_deleted:
                        message = f'Date of birth updated successfully. Updated fields: {", ".join(updated_fields)}. Profile picture has been deleted.'
                    else:
                        message = f'Date of birth updated successfully. Updated fields: {", ".join(updated_fields)}'
                elif profile_picture_deleted:
                    message = f'Profile updated successfully. Updated fields: {", ".join(updated_fields)}. Profile picture has been deleted.'
                else:
                    message = f'Profile updated successfully. Updated fields: {", ".join(updated_fields)}'
                
                # Return updated profile data
                profile_data = {
                    'user_info': {
                        'id': updated_user.id,
                        'email': updated_user.email,
                        'user_type': updated_user.user_type,
                        'user_type_display': updated_user.get_user_type_display(),
                    },
                    'registration_data': {
                        'first_name': updated_user.first_name,
                        'last_name': updated_user.last_name,
                    },
                    'profile_data': {
                        'phone_number': updated_user.profile.phone_number,
                        'address': updated_user.profile.address,
                        'city': updated_user.profile.city,
                        'state': updated_user.profile.state,
                        'zip_code': updated_user.profile.zip_code,
                        'country': updated_user.profile.country,
                        'profile_picture': updated_user.profile.profile_picture.url if updated_user.profile.profile_picture else None,
                        'date_of_birth': updated_user.profile.date_of_birth,
                    },
                    'profile_stats': {
                        'profile_complete': updated_user.has_complete_profile(),
                        'completion_percentage': updated_user.get_profile_completion_percentage(),
                    }
                }
                
                return Response({
                    'success': True,
                    'message': message,
                    'data': profile_data
                }, status=status.HTTP_200_OK)
            else:
                logger.warning(f"Profile update validation failed for user {user.id}: {serializer.errors}")
                return Response({
                    'success': False,
                    'message': 'Invalid profile data',
                    'errors': serializer.errors
                }, status=status.HTTP_400_BAD_REQUEST)
                
        except Exception as e:
            logger.error(f"Error updating profile for user {user.id}: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to update profile',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class CustomerAccountView(APIView):
    """
    API view for customer account management.
    Provides comprehensive account information and settings.
    Note: This view is kept for backward compatibility but UserProfileView 
    now handles profile management for all user types.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        """
        Get comprehensive customer account information.
        """
        try:
            user = request.user
            
            # Get user details
            user_serializer = UserDetailSerializer(user)
            
            # Get account statistics
            account_stats = {
                'account_created': user.date_joined,
                'last_login': user.last_login,
                'profile_complete': user.has_complete_profile(),
                'profile_completion_percentage': user.get_profile_completion_percentage(),
            }
            
            return Response({
                'success': True,
                'message': 'Account information retrieved successfully',
                'data': {
                    'user_details': user_serializer.data,
                    'account_stats': account_stats,
                }
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving account info: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve account information',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def patch(self, request):
        """
        Update customer account settings.
        Note: For profile updates, use UserProfileView instead.
        """
        try:
            user = request.user
            
            # Update user basic information
            user_data = {}
            profile_data = {}
            
            # Separate user fields from profile fields
            user_fields = ['first_name', 'last_name', 'phone_number', 'address', 'city']
            profile_fields = []  # No profile fields in simplified model
            
            for field in user_fields:
                if field in request.data:
                    user_data[field] = request.data[field]
            
            for field in profile_fields:
                if field in request.data:
                    profile_data[field] = request.data[field]
            
            # Update user fields
            if user_data:
                user_serializer = UserDetailSerializer(user, data=user_data, partial=True)
                if user_serializer.is_valid():
                    user_serializer.save()
                else:
                    return Response({
                        'success': False,
                        'message': 'Invalid user data',
                        'errors': user_serializer.errors
                    }, status=status.HTTP_400_BAD_REQUEST)
            
            # Update profile fields
            if profile_data:
                UserAccountService.update_profile(user, profile_data)
            
            # Return updated account information
            updated_user = User.objects.get(id=user.id)
            user_serializer = UserDetailSerializer(updated_user)
            
            return Response({
                'success': True,
                'message': 'Account updated successfully',
                'data': user_serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error updating account: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to update account',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class LanguageOptionsView(APIView):
    """
    API view to get available language options.
    Public endpoint - allows anonymous access for login page language selection.
    """
    permission_classes = [permissions.AllowAny]
    
    def get(self, request):
        """
        Get available language options and current user's preference if authenticated.
        """
        try:
            from django.conf import settings
            
            # Get available languages from settings
            languages = [
                {'code': code, 'name': name} 
                for code, name in settings.LANGUAGES
            ]
            
            # Get current user's language preference if authenticated
            current_language = settings.LANGUAGE_CODE  # Default
            if request.user.is_authenticated:
                current_language = request.user.get_language_preference()
            
            serializer = LanguageOptionsSerializer({
                'languages': languages,
                'current_language': current_language
            })
            
            return Response({
                'success': True,
                'message': 'Language options retrieved successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving language options: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve language options',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class UserLanguagePreferenceView(APIView):
    """
    Enhanced API view for authenticated users to get and update their language preference.
    Now provides comprehensive language switching for the entire application.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        """
        Get current user's language preference with comprehensive language context.
        """
        try:
            serializer = LanguagePreferenceSerializer(request.user)
            if serializer.is_valid():
                return Response({   
                'success': True,
                'message': 'Language preference retrieved successfully',
                    'data': serializer.data
                }, status=status.HTTP_200_OK)
            else:
                return Response({
                    'success': False,
                    'message': 'Invalid language preference data',
                    'errors': serializer.errors
                }, status=status.HTTP_400_BAD_REQUEST)
            
            
            
        except Exception as e:
            logger.error(f"Error retrieving language preference: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve language preference',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def patch(self, request):
        """
        Update current user's language preference and activate comprehensive language switching.
        """
        try:
            serializer = LanguagePreferenceSerializer(
                request.user, 
                data=request.data, 
                partial=True
            )
            
            if serializer.is_valid():
                serializer.save()
                
                success_message = 'Language preference updated successfully.'
                
                return Response({
                    'success': True,
                    'message': success_message, 
                    'data': serializer.data
                }, status=status.HTTP_200_OK)
            else:   
                return Response({
                    'success': False,
                    'message': 'Invalid language preference data',
                    'errors': serializer.errors
                }, status=status.HTTP_400_BAD_REQUEST)
                
        except Exception as e:
            logger.error(f"Error updating language preference: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to update language preference',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class ApplicationLanguageView(APIView):
    """
    API view to get comprehensive language information for the entire application.
    Available to all users (authenticated and anonymous).
    """
    permission_classes = [permissions.AllowAny]
    
    def get(self, request):
        """
        Get comprehensive language information including all translatable content.
        """
        try:
            from ..utils import get_translated_choices
            from ..models import (
                User, Category, Author, Book, BorrowRequest, 
                Order, Cart, Payment, DiscountCode, Notification
            )
            
            # Get all translatable choices from models
            translatable_content = {
                'user_types': get_translated_choices(User.USER_TYPE_CHOICES),
                'delivery_statuses': get_translated_choices(User.DELIVERY_STATUS_CHOICES),
                'languages': get_translated_choices(User.LANGUAGE_CHOICES),
                'borrow_statuses': get_translated_choices(BorrowRequest.BorrowStatusChoices.choices),
                'extension_statuses': get_translated_choices(BorrowRequest.ExtensionStatusChoices.choices),
                'fine_statuses': get_translated_choices(BorrowRequest.FineStatusChoices.choices),
                'order_statuses': get_translated_choices(Order.ORDER_STATUS_CHOICES),
                'order_types': get_translated_choices(Order.ORDER_TYPE_CHOICES),
                'payment_statuses': get_translated_choices(Payment.PAYMENT_STATUS_CHOICES),
                'payment_types': get_translated_choices(Payment.PAYMENT_TYPE_CHOICES),
                'notification_priorities': get_translated_choices(Notification.PRIORITY_CHOICES),
                'notification_statuses': get_translated_choices(Notification.STATUS_CHOICES),
            }
            
            # Add credit card types
            try:
                from ..models.payment_model import CreditCardPayment
                translatable_content['credit_card_types'] = get_translated_choices(CreditCardPayment.card_type.field.choices)
            except:
                pass
            
            return Response({
                'success': True,
                'message': 'Application language information retrieved successfully',
                'data': {
                    'translatable_content': translatable_content,
                    'supported_languages': settings.LANGUAGES,
                    'current_language': request.LANGUAGE_CODE,
                    'is_rtl': request.LANGUAGE_CODE == 'ar'
                }
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving application language information: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve application language information',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class LibraryManagerProfileView(APIView):
    """
    Dedicated API view for Library Manager profile updates.
    Provides enhanced validation and specific messaging for library administrators.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        """
        Get Library Manager profile information.
        """
        try:
            user = request.user
            
            # Verify user is a library manager
            if not user.is_library_admin():
                return Response({
                    'success': False,
                    'message': 'Access denied. This endpoint is only for Library Managers.',
                    'errors': {'permission': ['Only Library Managers can access this endpoint']}
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Prepare profile data for the interface
            profile_data = {
                'user_info': {
                    'id': user.id,
                    'email': user.email,
                    'user_type': user.user_type,
                    'user_type_display': user.get_user_type_display(),
                    'date_joined': user.date_joined,
                },
                'registration_data': {
                    'first_name': user.first_name,
                    'last_name': user.last_name,
                },
                'profile_data': {
                    'phone_number': user.profile.phone_number,
                    'address': user.profile.address,
                    'city': user.profile.city,
                    'state': user.profile.state,
                    'zip_code': user.profile.zip_code,
                    'country': user.profile.country,
                    'profile_picture': user.profile.profile_picture.url if user.profile.profile_picture else None,
                    'date_of_birth': user.profile.date_of_birth,
                },
                'profile_stats': {
                    'profile_complete': user.has_complete_profile(),
                    'completion_percentage': user.get_profile_completion_percentage(),
                }
            }
            
            return Response({
                'success': True,
                'message': 'Library Manager profile retrieved successfully',
                'data': profile_data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving Library Manager profile: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve Library Manager profile',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def patch(self, request):
        """
        Update Library Manager profile information with enhanced validation.
        """
        try:
            user = request.user
            
            # Verify user is a library manager
            if not user.is_library_admin():
                return Response({
                    'success': False,
                    'message': 'Access denied. This endpoint is only for Library Managers.',
                    'errors': {'permission': ['Only Library Managers can access this endpoint']}
                }, status=status.HTTP_403_FORBIDDEN)
            
            
            # Filter out empty strings and convert them to None for optional fields
            filtered_data = {}
            for key, value in request.data.items():
                if value == '' and key in ['phone_number', 'address', 'city', 'state', 'zip_code', 'country']:
                    filtered_data[key] = None  # Convert empty strings to None for optional fields
                elif value is not None:  # Only include non-None values
                    filtered_data[key] = value
            
            
            # Check if user is requesting to delete profile picture
            profile_picture_deleted = False
            if 'profile_picture' in filtered_data and filtered_data['profile_picture'] is None:
                profile_picture_deleted = True
            
            # Use ProfileUpdateSerializer for validation
            serializer = ProfileUpdateSerializer(user, data=filtered_data, partial=True)
            
            if serializer.is_valid():
                updated_user = serializer.save()
                
                # Prepare success message with specific handling for date of birth
                updated_fields = list(filtered_data.keys())
                if 'date_of_birth' in updated_fields:
                    if profile_picture_deleted:
                        message = f'Date of birth updated successfully. Updated fields: {", ".join(updated_fields)}. Profile picture has been deleted.'
                    else:
                        message = f'Date of birth updated successfully. Updated fields: {", ".join(updated_fields)}'
                elif profile_picture_deleted:
                    message = f'Library Manager profile updated successfully. Updated fields: {", ".join(updated_fields)}. Profile picture has been deleted.'
                else:
                    message = f'Library Manager profile updated successfully. Updated fields: {", ".join(updated_fields)}'
                
                # Return updated profile data
                profile_data = {
                    'user_info': {
                        'id': updated_user.id,
                        'email': updated_user.email,
                        'user_type': updated_user.user_type,
                        'user_type_display': updated_user.get_user_type_display(),
                    },
                    'registration_data': {
                        'first_name': updated_user.first_name,
                        'last_name': updated_user.last_name,
                    },
                    'profile_data': {
                        'phone_number': updated_user.profile.phone_number,
                        'address': updated_user.profile.address,
                        'city': updated_user.profile.city,
                        'state': updated_user.profile.state,
                        'zip_code': updated_user.profile.zip_code,
                        'country': updated_user.profile.country,
                        'profile_picture': updated_user.profile.profile_picture.url if updated_user.profile.profile_picture else None,
                        'date_of_birth': updated_user.profile.date_of_birth,
                    },
                    'profile_stats': {
                        'profile_complete': updated_user.has_complete_profile(),
                        'completion_percentage': updated_user.get_profile_completion_percentage(),
                    }
                }
                
                return Response({
                    'success': True,
                    'message': message,
                    'data': profile_data
                }, status=status.HTTP_200_OK)
            else:
                logger.warning(f"Library Manager profile update validation failed for user {user.id}: {serializer.errors}")
                return Response({
                    'success': False,
                    'message': 'Invalid profile data',
                    'errors': serializer.errors
                }, status=status.HTTP_400_BAD_REQUEST)
                
        except Exception as e:
            logger.error(f"Error updating Library Manager profile for user {user.id}: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to update Library Manager profile',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class ChangeEmailView(APIView):
    """
    Change user email address.
    Requires current password for security verification.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        """
        Change user's email address.
        """
        try:
            user = request.user
            
            # Debug logging
            logger.info(f"ChangeEmailView: User {user.email} attempting to change email")
            logger.info(f"ChangeEmailView: Request data: {request.data}")
            
            # Create serializer with user context
            serializer = EmailChangeSerializer(
                data=request.data, 
                context={'user': user}
            )
            
            if serializer.is_valid():
                logger.info(f"ChangeEmailView: Serializer validation passed for user {user.email}")
                new_email = serializer.validated_data['new_email']
                
                # Use service to change email
                result = UserAccountService.change_email(user, new_email)
                
                if result['success']:
                    return Response({
                        'success': True,
                        'message': 'Email changed successfully',
                        'data': {
                            'old_email': result['old_email'],
                            'new_email': result['new_email']
                        }
                    }, status=status.HTTP_200_OK)
                else:
                    return Response({
                        'success': False,
                        'message': result['message'],
                        'errors': result.get('errors', 'Unknown error occurred')
                    }, status=status.HTTP_400_BAD_REQUEST)
            else:
                # Debug logging for validation errors
                logger.warning(f"ChangeEmailView: Serializer validation failed for user {user.email}")
                logger.warning(f"ChangeEmailView: Validation errors: {serializer.errors}")
                
                # Extract specific error messages for better user feedback
                error_messages = []
                for field, errors in serializer.errors.items():
                    if isinstance(errors, list):
                        error_messages.extend([f"{field}: {error}" for error in errors])
                    else:
                        error_messages.append(f"{field}: {errors}")
                
                return Response({
                    'success': False,
                    'message': 'Invalid data provided',
                    'errors': serializer.errors,
                    'error_details': '; '.join(error_messages)
                }, status=status.HTTP_400_BAD_REQUEST)
                
        except Exception as e:
            logger.error(f"Error changing email for user {request.user.email}: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to change email',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class ChangePasswordView(APIView):
    """API view for changing user password."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        """
        Change user password.
        Requires current password verification.
        """
        try:
            user = request.user
            serializer = PasswordChangeSerializer(
                data=request.data,
                context={'user': user}
            )
            
            if serializer.is_valid():
                new_password = serializer.validated_data['new_password']
                
                # Update user password
                user.set_password(new_password)
                user.save()
                
                logger.info(f"Password changed successfully for user {user.id}")
                
                return Response({
                    'success': True,
                    'message': 'Password changed successfully'
                }, status=status.HTTP_200_OK)
            else:
                logger.warning(f"Password change validation failed for user {user.id}: {serializer.errors}")
                return Response({
                    'success': False,
                    'message': 'Invalid password data',
                    'errors': serializer.errors
                }, status=status.HTTP_400_BAD_REQUEST)
                
        except Exception as e:
            logger.error(f"Error changing password for user {user.id}: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to change password',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
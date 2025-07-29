from rest_framework import generics, status, permissions
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.views import APIView
from django.contrib.auth import authenticate
from django.shortcuts import get_object_or_404
from django.db import transaction
from django.utils.decorators import method_decorator
from django.views.decorators.csrf import csrf_exempt
from django.contrib.auth.tokens import default_token_generator
from django.utils.encoding import force_bytes, force_str
from django.utils.http import urlsafe_base64_encode, urlsafe_base64_decode
from django.core.mail import send_mail
from django.template.loader import render_to_string
from django.conf import settings
from rest_framework_simplejwt.tokens import RefreshToken
import logging

from ..models import User, UserProfile
from ..serializers import (
    UnifiedRegistrationSerializer,
    UserDetailSerializer,
    UserProfileSerializer,
    ProfileUpdateSerializer,
    UserTypeOptionsSerializer,
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


class LoginView(APIView):
    """
    API view for user authentication and JWT token generation.
    Requires only email and password.
    """
    permission_classes = [permissions.AllowAny]
    
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
                    'message': 'Invalid email or password',
                    'errors': {'credentials': ['Invalid email or password']}
                }, status=status.HTTP_401_UNAUTHORIZED)
                
        except Exception as e:
            logger.error(f"Error in login: {str(e)}")
            return Response({
                'success': False,
                'message': 'Login failed',
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
        Update profile information through the profile interface.
        Allows updating: first_name, last_name, phone_number, address, city, profile_picture.
        Profile picture can be deleted by setting it to null.
        """
        try:
            user = self.get_object()
            
            # Check if user is requesting to delete profile picture
            profile_picture_deleted = False
            if 'profile_picture' in request.data and request.data['profile_picture'] is None:
                profile_picture_deleted = True
            
            serializer = self.get_serializer(user, data=request.data, partial=True)
            
            if serializer.is_valid():
                updated_user = serializer.save()
                
                # Prepare success message
                if profile_picture_deleted:
                    message = 'Profile updated successfully. Profile picture has been deleted.'
                else:
                    message = 'Profile updated successfully'
                
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
                return Response({
                    'success': False,
                    'message': 'Invalid profile data',
                    'errors': serializer.errors
                }, status=status.HTTP_400_BAD_REQUEST)
                
        except Exception as e:
            logger.error(f"Error updating profile: {str(e)}")
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
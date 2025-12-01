from rest_framework import viewsets, status, permissions
from rest_framework.decorators import action
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from django.db.models import Q
import logging

from ..models import DeliveryProfile, User
from ..serializers import (
    DeliveryProfileSerializer,
    DeliveryProfileCreateSerializer,
    DeliveryProfileUpdateSerializer,
    DeliveryProfileLocationUpdateSerializer,
    DeliveryProfileStatusUpdateSerializer,
    DeliveryProfileTrackingUpdateSerializer,
)
from ..services import DeliveryProfileService
from ..utils import format_error_message

logger = logging.getLogger(__name__)


class DeliveryProfileViewSet(viewsets.ModelViewSet):
    """
    ViewSet for managing delivery profiles.
    """
    queryset = DeliveryProfile.objects.all()
    serializer_class = DeliveryProfileSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_serializer_class(self):
        if self.action == 'create':
            return DeliveryProfileCreateSerializer
        elif self.action in ['update', 'partial_update']:
            return DeliveryProfileUpdateSerializer
        elif self.action == 'update_location':
            return DeliveryProfileLocationUpdateSerializer
        elif self.action == 'update_status':
            return DeliveryProfileStatusUpdateSerializer
        elif self.action == 'update_tracking':
            return DeliveryProfileTrackingUpdateSerializer
        return DeliveryProfileSerializer
    
    def get_queryset(self):
        """
        Filter delivery profiles based on user permissions.
        Only shows profiles for delivery administrators.
        """
        user = self.request.user
        
        # If user is admin, they can see all delivery admin profiles
        if user.is_staff or user.is_superuser:
            return DeliveryProfileService.get_delivery_admin_profiles()
        
        # If user is delivery admin, they can see their own profile
        if user.is_delivery_admin():
            return DeliveryProfile.objects.filter(user=user).select_related('user')
        
        # Other users cannot see delivery profiles
        return DeliveryProfile.objects.none()
    
    def get_object(self):
        """
        Get the delivery profile object.
        """
        user = self.request.user
        
        # If user is admin, they can access any profile
        if user.is_staff or user.is_superuser:
            return super().get_object()
        
        # If user is delivery admin, they can only access their own profile
        if user.is_delivery_admin():
            return get_object_or_404(DeliveryProfile, user=user)
        
        # Other users cannot access delivery profiles
        return None
    
    def create(self, request, *args, **kwargs):
        """
        Create a new delivery profile.
        Only delivery administrators can create profiles.
        """
        if not request.user.is_delivery_admin():
            return Response({
                'success': False,
                'message': 'Only delivery administrators can create delivery profiles',
                'error_code': 'PERMISSION_DENIED'
            }, status=status.HTTP_403_FORBIDDEN)
        
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        try:
            delivery_profile = serializer.save()
            response_serializer = DeliveryProfileSerializer(delivery_profile)
            
            return Response({
                'success': True,
                'message': 'Delivery profile created successfully',
                'data': response_serializer.data
            }, status=status.HTTP_201_CREATED)
            
        except Exception as e:
            logger.error(f"Error creating delivery profile: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to create delivery profile',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_400_BAD_REQUEST)
    
    def update(self, request, *args, **kwargs):
        """
        Update a delivery profile.
        """
        try:
            delivery_profile = self.get_object()
            if not delivery_profile:
                return Response({
                    'success': False,
                    'message': 'Delivery profile not found',
                    'error_code': 'NOT_FOUND'
                }, status=status.HTTP_404_NOT_FOUND)
            
            serializer = self.get_serializer(delivery_profile, data=request.data, partial=True)
            serializer.is_valid(raise_exception=True)
            
            updated_profile = serializer.save()
            response_serializer = DeliveryProfileSerializer(updated_profile)
            
            return Response({
                'success': True,
                'message': 'Delivery profile updated successfully',
                'data': response_serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error updating delivery profile: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to update delivery profile',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_400_BAD_REQUEST)
    
    @action(detail=False, methods=['get'])
    def my_profile(self, request):
        """
        Get the current user's delivery profile.
        Automatically resets status to 'online' if user is 'busy' but has no active deliveries.
        """
        if not request.user.is_delivery_admin():
            return Response({
                'success': False,
                'message': 'Only delivery administrators have delivery profiles',
                'error_code': 'PERMISSION_DENIED'
            }, status=status.HTTP_403_FORBIDDEN)
        
        try:
            delivery_profile = DeliveryProfileService.get_or_create_delivery_profile(request.user)
            
            # Automatically reset status if busy but no active deliveries (safety mechanism)
            # This ensures status always reflects reality when profile is fetched
            if delivery_profile.delivery_status == 'busy':
                try:
                    logger.info(f"Delivery manager {request.user.id} status is 'busy', checking for active deliveries...")
                    was_reset = DeliveryProfileService.reset_status_if_no_active_deliveries(request.user)
                    if was_reset:
                        # Refresh the profile to get the updated status
                        delivery_profile.refresh_from_db()
                        logger.info(
                            f"Automatically reset delivery status from 'busy' to '{delivery_profile.delivery_status}' "
                            f"for user {request.user.id} (no active deliveries)"
                        )
                    else:
                        logger.info(
                            f"Delivery manager {request.user.id} status remains 'busy' - active deliveries found"
                        )
                except Exception as reset_error:
                    logger.error(f"Failed to auto-reset status for user {request.user.id}: {str(reset_error)}")
                    # Continue with current status even if reset failed
            
            serializer = DeliveryProfileSerializer(delivery_profile)
            
            return Response({
                'success': True,
                'message': 'Delivery profile retrieved successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving delivery profile: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve delivery profile',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    @action(detail=False, methods=['get'])
    def debug_status(self, request):
        """
        Debug endpoint to help identify status update issues.
        """
        if not request.user.is_delivery_admin():
            return Response({
                'success': False,
                'message': 'Only delivery administrators can access this endpoint',
                'error_code': 'PERMISSION_DENIED'
            }, status=status.HTTP_403_FORBIDDEN)
        
        try:
            delivery_profile = DeliveryProfileService.get_delivery_profile(request.user)
            
            debug_info = {
                'user_id': request.user.id,
                'user_type': request.user.user_type,
                'is_delivery_admin': request.user.is_delivery_admin(),
                'has_delivery_profile': delivery_profile is not None,
                'current_status': delivery_profile.delivery_status if delivery_profile else None,
                'can_change_manually': DeliveryProfileService.can_manually_change_status(request.user),
                'valid_statuses': [choice[0] for choice in DeliveryProfile.DELIVERY_STATUS_CHOICES],
                'expected_request_format': {
                    'delivery_status': 'online'  # or 'offline' or 'busy'
                }
            }
            
            return Response({
                'success': True,
                'message': 'Debug information retrieved',
                'data': debug_info
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error in debug endpoint: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to get debug information',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    @action(detail=False, methods=['post'])
    def reset_status(self, request):
        """
        Reset delivery manager status if no active deliveries.
        This is a safety mechanism to prevent stuck 'busy' status.
        """
        try:
            user = request.user
            
            if not user.is_delivery_admin():
                return Response({
                    'success': False,
                    'message': 'Only delivery administrators can reset status',
                    'error_code': 'INSUFFICIENT_PERMISSIONS'
                }, status=403)
            
            # Get current profile
            delivery_profile = DeliveryProfileService.get_or_create_delivery_profile(user)
            old_status = delivery_profile.delivery_status
            
            # If status is busy, force check for active deliveries
            if delivery_profile.delivery_status == 'busy':
                logger.info(f"Reset endpoint: User {user.id} has 'busy' status, checking for active deliveries...")
                was_reset = DeliveryProfileService.reset_status_if_no_active_deliveries(user)
                
                # Refresh profile to get updated status
                delivery_profile.refresh_from_db()
                
                if was_reset:
                    logger.info(f"Reset endpoint: Successfully reset status from '{old_status}' to '{delivery_profile.delivery_status}' for user {user.id}")
                    return Response({
                        'success': True,
                        'message': 'Status reset to online (no active deliveries)',
                        'data': {
                            'delivery_status': delivery_profile.delivery_status,
                            'was_reset': True,
                            'old_status': old_status
                        }
                    })
                else:
                    # Status is busy but reset didn't happen
                    return Response({
                        'success': True,
                        'message': 'Status remains busy (active deliveries found)',
                        'data': {
                            'delivery_status': delivery_profile.delivery_status,
                            'was_reset': False,
                            'old_status': old_status
                        }
                    })
            else:
                # Status is not busy, no reset needed
                return Response({
                    'success': True,
                    'message': 'No reset needed (status is not busy)',
                    'data': {
                        'delivery_status': delivery_profile.delivery_status,
                        'was_reset': False
                    }
                })
                
        except Exception as e:
            logger.error(f"Error resetting delivery status: {str(e)}", exc_info=True)
            return Response({
                'success': False,
                'message': f'Failed to reset status: {str(e)}',
                'error_code': 'RESET_FAILED'
            }, status=500)
    
    @action(detail=False, methods=['get'])
    def current_status(self, request):
        """
        Get the current user's delivery status only.
        This endpoint is specifically designed for frontend to check status after login.
        Automatically resets status to 'online' if user is 'busy' but has no active deliveries.
        """
        if not request.user.is_delivery_admin():
            return Response({
                'success': False,
                'message': 'Only delivery administrators have delivery status',
                'error_code': 'PERMISSION_DENIED'
            }, status=status.HTTP_403_FORBIDDEN)
        
        try:
            delivery_profile = DeliveryProfileService.get_or_create_delivery_profile(request.user)
            
            # Automatically reset status if busy but no active deliveries (safety mechanism)
            # This ensures status always reflects reality when dashboard loads
            if delivery_profile.delivery_status == 'busy':
                try:
                    was_reset = DeliveryProfileService.reset_status_if_no_active_deliveries(request.user)
                    if was_reset:
                        # Refresh the profile to get the updated status
                        delivery_profile.refresh_from_db()
                    else:
                        # If reset returned False but status is still busy, try force reset as last resort
                        # Force reset - this will reset if truly no active deliveries exist
                        was_force_reset = DeliveryProfileService.reset_status_if_no_active_deliveries(request.user, force_reset=True)
                        if was_force_reset:
                            delivery_profile.refresh_from_db()
                except Exception as reset_error:
                    logger.error(f"Failed to auto-reset status for user {request.user.id}: {str(reset_error)}", exc_info=True)
                    # Continue with current status even if reset failed
            
            return Response({
                'success': True,
                'message': 'Delivery status retrieved successfully',
                'data': {
                    'user_id': request.user.id,
                    'delivery_status': delivery_profile.delivery_status,
                    'can_change_manually': delivery_profile.can_change_status_manually(),
                    'is_tracking_active': delivery_profile.is_tracking_active,
                    'last_updated': delivery_profile.updated_at
                }
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving delivery status: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve delivery status',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    @action(detail=False, methods=['post'])
    def update_location(self, request):
        """
        Update the current user's location.
        """
        if not request.user.is_delivery_admin():
            return Response({
                'success': False,
                'message': 'Only delivery administrators can update location',
                'error_code': 'PERMISSION_DENIED'
            }, status=status.HTTP_403_FORBIDDEN)
        
        try:
            serializer = DeliveryProfileLocationUpdateSerializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            
            delivery_profile = DeliveryProfileService.update_location(
                user=request.user,
                latitude=serializer.validated_data['latitude'],
                longitude=serializer.validated_data['longitude'],
                address=serializer.validated_data.get('address')
            )
            
            response_serializer = DeliveryProfileSerializer(delivery_profile)
            
            return Response({
                'success': True,
                'message': 'Location updated successfully',
                'data': response_serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error updating location: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to update location',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_400_BAD_REQUEST)
    
    @action(detail=False, methods=['post'])
    def update_status(self, request):
        """
        Update the current user's delivery status.
        IMPORTANT: Manual status changes are not allowed when status is 'busy'.
        Only the system can change status from busy to online (after completing delivery).
        """
        if not request.user.is_delivery_admin():
            return Response({
                'success': False,
                'message': 'Only delivery administrators can update status',
                'error_code': 'PERMISSION_DENIED'
            }, status=status.HTTP_403_FORBIDDEN)
        
        try:
            # Log the request data for debugging
            logger.info(f"Update status request data: {request.data}")
            logger.info(f"User: {request.user.id}, User type: {request.user.user_type}")
            
            # Check if user can manually change status (not busy)
            if not DeliveryProfileService.can_manually_change_status(request.user):
                return Response({
                    'success': False,
                    'message': 'Cannot change status manually while busy. Status will automatically change to online when delivery is completed.',
                    'error_code': 'STATUS_CHANGE_NOT_ALLOWED',
                    'current_status': 'busy'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            serializer = DeliveryProfileStatusUpdateSerializer(data=request.data)
            if not serializer.is_valid():
                logger.error(f"Serializer validation errors: {serializer.errors}")
                return Response({
                    'success': False,
                    'message': 'Invalid request data',
                    'errors': serializer.errors
                }, status=status.HTTP_400_BAD_REQUEST)
            
            delivery_profile = DeliveryProfileService.update_delivery_status(
                user=request.user,
                status=serializer.validated_data['delivery_status']
            )
            
            response_serializer = DeliveryProfileSerializer(delivery_profile)
            
            return Response({
                'success': True,
                'message': 'Delivery status updated successfully',
                'data': response_serializer.data,
                'current_status': delivery_profile.delivery_status  # Add for frontend compatibility
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error updating delivery status: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to update delivery status',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_400_BAD_REQUEST)
    
    @action(detail=False, methods=['post'])
    def update_tracking(self, request):
        """
        Update the current user's tracking status.
        """
        if not request.user.is_delivery_admin():
            return Response({
                'success': False,
                'message': 'Only delivery administrators can update tracking',
                'error_code': 'PERMISSION_DENIED'
            }, status=status.HTTP_403_FORBIDDEN)
        
        try:
            serializer = DeliveryProfileTrackingUpdateSerializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            
            delivery_profile = DeliveryProfileService.update_tracking_status(
                user=request.user,
                is_tracking_active=serializer.validated_data['is_tracking_active']
            )
            
            response_serializer = DeliveryProfileSerializer(delivery_profile)
            
            return Response({
                'success': True,
                'message': 'Tracking status updated successfully',
                'data': response_serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error updating tracking status: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to update tracking status',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_400_BAD_REQUEST)
    
    @action(detail=False, methods=['get'])
    def online_managers(self, request):
        """
        Get all online delivery managers.
        """
        if not (request.user.is_staff or request.user.is_superuser):
            return Response({
                'success': False,
                'message': 'Only administrators can view online managers',
                'error_code': 'PERMISSION_DENIED'
            }, status=status.HTTP_403_FORBIDDEN)
        
        try:
            # Get all delivery admin profiles first, then filter for online ones
            delivery_admin_profiles = DeliveryProfileService.get_delivery_admin_profiles()
            online_managers = delivery_admin_profiles.filter(
                delivery_status='online',
                is_tracking_active=True
            )
            serializer = DeliveryProfileSerializer(online_managers, many=True)
            
            return Response({
                'success': True,
                'message': 'Online delivery managers retrieved successfully',
                'data': serializer.data,
                'count': len(serializer.data)
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving online managers: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve online managers',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    @action(detail=False, methods=['get'])
    def available_managers(self, request):
        """
        Get all available delivery managers.
        """
        if not (request.user.is_staff or request.user.is_superuser):
            return Response({
                'success': False,
                'message': 'Only administrators can view available managers',
                'error_code': 'PERMISSION_DENIED'
            }, status=status.HTTP_403_FORBIDDEN)
        
        try:
            # Get all active delivery managers
            delivery_managers = User.objects.filter(
                is_active=True,
                user_type='delivery_admin'
            ).order_by('first_name', 'last_name')
            
            # Format data to match frontend DeliveryAgent model expectations
            response_data = []
            for manager in delivery_managers:
                manager_data = {
                    'id': manager.id,
                    'name': manager.get_full_name(),
                    'email': manager.email,
                    'phone': manager.profile.phone_number if hasattr(manager, 'profile') and manager.profile.phone_number else '',
                    'address': None,
                    'vehicleType': None,
                    'vehicleNumber': None,
                    'status': 'online',  # Set to online to make manager available
                    'rating': None,
                    'totalDeliveries': 0,
                    'completedDeliveries': 0,
                    'activeDeliveries': 0,
                    'createdAt': manager.date_joined.isoformat(),
                    'updatedAt': manager.last_updated.isoformat() if hasattr(manager, 'last_updated') else manager.date_joined.isoformat(),
                    'isAvailable': True,
                    'latitude': None,
                    'longitude': None,
                    'profileImage': None,
                    'notes': None,
                }
                response_data.append(manager_data)
            
            return Response({
                'success': True,
                'message': 'Available delivery managers retrieved successfully',
                'data': response_data,
                'count': len(response_data)
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving available managers: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve available managers',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

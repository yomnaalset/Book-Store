from rest_framework import generics, status, permissions
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.exceptions import ValidationError as DRFValidationError, NotFound
from django.core.exceptions import ValidationError as DjangoValidationError
from django.shortcuts import get_object_or_404
from django.db.models import Q
from django.utils import timezone

from ..models import DeliveryRequest, User, Order, Notification
from ..models.borrowing_model import BorrowRequest, BorrowStatusChoices
from ..models.return_model import ReturnRequest, ReturnStatus
from ..serializers.delivery_serializers import (
    DeliveryRequestListSerializer,
    DeliveryRequestDetailSerializer,
    CustomerDeliveryRequestSerializer,
    AcceptDeliveryRequestSerializer,
    RejectDeliveryRequestSerializer,
    StartDeliverySerializer,
    UpdateLocationSerializer,
    CompleteDeliverySerializer,
    DeliveryNotesSerializer,
    BorrowingOrderSerializer,
    CustomerOrderSerializer,
)
from ..services.delivery_services import DeliveryService
from ..permissions import IsDeliveryAdmin, IsAnyAdmin, IsLibraryAdmin, CustomerOrAdmin, CanManageDeliveryNotes
from ..authentication import CustomJWTAuthentication
from ..utils import format_error_message
import logging

logger = logging.getLogger(__name__)


class DeliveryRequestListView(generics.ListAPIView):
    """
    View for listing delivery requests.
    Supports filtering by type, status, and delivery manager.
    - Delivery managers can see only their assigned requests
    - Admins can see all requests
    """
    serializer_class = DeliveryRequestListSerializer
    authentication_classes = [CustomJWTAuthentication]
    permission_classes = [IsAnyAdmin]  # Only admins and delivery managers can view
    
    def get_queryset(self):
        """Filter delivery requests based on query parameters."""
        # Use select_related to optimize queries for delivery_manager and delivery_profile
        queryset = DeliveryRequest.objects.select_related(
            'delivery_manager',
            'delivery_manager__delivery_profile',
            'customer'
        ).all()
        
        # Get current user
        user = self.request.user
        
        # Filter by delivery type (query parameter: ?type=purchase|borrow|return)
        delivery_type = self.request.query_params.get('type', None)
        if delivery_type:
            if delivery_type not in ['purchase', 'borrow', 'return']:
                raise DRFValidationError("Invalid delivery type. Must be 'purchase', 'borrow', or 'return'.")
            queryset = queryset.filter(delivery_type=delivery_type)
            
            # Ensure DeliveryRequest objects exist for ReturnRequest and BorrowRequest objects
            # This handles cases where ReturnRequest/BorrowRequest exist but DeliveryRequest doesn't
            if delivery_type == 'return':
                self._ensure_return_delivery_requests(user)
            elif delivery_type == 'borrow':
                self._ensure_borrow_delivery_requests(user)
        
        # Filter by status (query parameter: ?status=pending|assigned|accepted|in_delivery|completed|rejected)
        status_filter = self.request.query_params.get('status', None)
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        
        # If user is delivery manager, show ONLY their assigned requests (never pending)
        # Core Principle: Managers never see pending requests - only assigned requests
        if user.is_delivery_admin():
            queryset = queryset.filter(delivery_manager=user)
        
        # Library admins can see all requests (no additional filter needed)
        
        return queryset.order_by('-created_at')
    
    def _ensure_return_delivery_requests(self, user):
        """Ensure DeliveryRequest objects exist for ReturnRequest objects that need them."""
        from django.db import transaction
        
        # Get ReturnRequest objects that should have DeliveryRequest objects
        # ReturnRequest objects that are assigned to a delivery manager or are pending/approved/assigned
        return_requests = ReturnRequest.objects.filter(
            Q(delivery_manager=user) | 
            Q(delivery_manager__isnull=True, status__in=[
                ReturnStatus.PENDING,
                ReturnStatus.APPROVED,
                ReturnStatus.ASSIGNED,
            ])
        ).exclude(
            status=ReturnStatus.COMPLETED
        )
        
        for return_request in return_requests:
            # Check if DeliveryRequest already exists for this ReturnRequest
            if not DeliveryRequest.objects.filter(return_request=return_request).exists():
                try:
                    with transaction.atomic():
                        # CRITICAL: Design rule - if delivery_manager is set, status MUST be 'assigned' or higher
                        # Never create with status='pending' + delivery_manager (invalid design)
                        delivery_manager = return_request.delivery_manager
                        
                        # Determine status based on return_request status and delivery_manager
                        if delivery_manager:
                            # If delivery_manager is assigned, status must be 'assigned' or higher
                            status_mapping = {
                                ReturnStatus.ASSIGNED: 'assigned',
                                ReturnStatus.ACCEPTED: 'accepted',
                                ReturnStatus.IN_PROGRESS: 'in_delivery',
                            }
                            delivery_status = status_mapping.get(return_request.status, 'assigned')
                        else:
                            # No delivery_manager - can be 'pending'
                            status_mapping = {
                                ReturnStatus.PENDING: 'pending',
                                ReturnStatus.APPROVED: 'pending',
                            }
                            delivery_status = status_mapping.get(return_request.status, 'pending')
                        
                        # Get customer from the borrowing request
                        customer = return_request.borrowing.customer
                        
                        # Get delivery address from borrowing request
                        delivery_address = return_request.borrowing.delivery_address
                        
                        # Set assigned_at if delivery_manager is assigned
                        assigned_at = None
                        if delivery_manager and return_request.status in [ReturnStatus.ASSIGNED, ReturnStatus.ACCEPTED]:
                            assigned_at = return_request.accepted_at if return_request.accepted_at else timezone.now()
                        
                        # Create DeliveryRequest for this ReturnRequest
                        DeliveryRequest.objects.create(
                            delivery_type='return',
                            customer=customer,
                            delivery_address=delivery_address,
                            return_request=return_request,
                            delivery_manager=delivery_manager,
                            status=delivery_status,
                            created_at=return_request.created_at,
                            assigned_at=assigned_at,
                        )
                        logger.info(f"Created DeliveryRequest for ReturnRequest {return_request.id}")
                except Exception as e:
                    logger.error(f"Error creating DeliveryRequest for ReturnRequest {return_request.id}: {str(e)}")
    
    def _ensure_borrow_delivery_requests(self, user):
        """Ensure DeliveryRequest objects exist for BorrowRequest objects that need them."""
        from django.db import transaction
        
        # Get BorrowRequest objects that should have DeliveryRequest objects
        # BorrowRequest objects that are assigned to a delivery manager or are approved/pending delivery
        borrow_requests = BorrowRequest.objects.filter(
            Q(delivery_person=user) | 
            Q(delivery_person__isnull=True, status__in=[
                BorrowStatusChoices.APPROVED,
                BorrowStatusChoices.ASSIGNED_TO_DELIVERY,
                BorrowStatusChoices.PENDING_DELIVERY,
                BorrowStatusChoices.AWAITING_PICKUP,
            ])
        ).exclude(
            status__in=[BorrowStatusChoices.DELIVERED, BorrowStatusChoices.RETURNED, BorrowStatusChoices.CANCELLED]
        )
        
        for borrow_request in borrow_requests:
            # Check if DeliveryRequest already exists for this BorrowRequest
            if not DeliveryRequest.objects.filter(borrow_request=borrow_request).exists():
                try:
                    with transaction.atomic():
                        # CRITICAL: Design rule - if delivery_manager is set, status MUST be 'assigned' or higher
                        # Never create with status='pending' + delivery_manager (invalid design)
                        delivery_manager = borrow_request.delivery_person
                        
                        # Determine status based on borrow_request status and delivery_manager
                        if delivery_manager:
                            # If delivery_manager is assigned, status must be 'assigned' or higher
                            status_mapping = {
                                BorrowStatusChoices.ASSIGNED_TO_DELIVERY: 'assigned',
                                BorrowStatusChoices.PENDING_DELIVERY: 'assigned',
                                BorrowStatusChoices.AWAITING_PICKUP: 'assigned',
                                BorrowStatusChoices.OUT_FOR_DELIVERY: 'in_delivery',
                            }
                            delivery_status = status_mapping.get(borrow_request.status, 'assigned')
                        else:
                            # No delivery_manager - can be 'pending'
                            status_mapping = {
                                BorrowStatusChoices.APPROVED: 'pending',
                            }
                            delivery_status = status_mapping.get(borrow_request.status, 'pending')
                        
                        # Set assigned_at if delivery manager is assigned
                        assigned_at = None
                        if delivery_manager and borrow_request.approved_date:
                            assigned_at = borrow_request.approved_date
                        
                        # Create DeliveryRequest for this BorrowRequest
                        DeliveryRequest.objects.create(
                            delivery_type='borrow',
                            customer=borrow_request.customer,
                            delivery_address=borrow_request.delivery_address,
                            borrow_request=borrow_request,
                            delivery_manager=delivery_manager,
                            status=delivery_status,
                            created_at=borrow_request.created_at,
                            assigned_at=assigned_at,
                        )
                        logger.info(f"Created DeliveryRequest for BorrowRequest {borrow_request.id}")
                except Exception as e:
                    logger.error(f"Error creating DeliveryRequest for BorrowRequest {borrow_request.id}: {str(e)}")
    
    def list(self, request, *args, **kwargs):
        """Override list to add custom response format."""
        response = super().list(request, *args, **kwargs)
        
        # Handle paginated response
        if isinstance(response.data, dict) and 'results' in response.data:
            # Already paginated, just add success flag
            response.data['success'] = True
            return response
        
        # Non-paginated response - wrap in standard format
        if isinstance(response.data, list):
            return Response({
                'success': True,
                'count': len(response.data),
                'results': response.data
            }, status=status.HTTP_200_OK)
        
        # Fallback for other formats
        return Response({
            'success': True,
            'count': len(response.data) if isinstance(response.data, list) else 1,
            'results': response.data if isinstance(response.data, list) else [response.data]
        }, status=status.HTTP_200_OK)


class DeliveryRequestDetailView(generics.RetrieveAPIView):
    """
    View for retrieving a single delivery request detail.
    - Delivery managers can see only their assigned requests
    - Admins can see all requests
    """
    serializer_class = DeliveryRequestDetailSerializer
    authentication_classes = [CustomJWTAuthentication]
    permission_classes = [IsAnyAdmin]  # Only admins and delivery managers can view
    queryset = DeliveryRequest.objects.all()
    
    def get_queryset(self):
        """Filter based on user role."""
        user = self.request.user
        # Use select_related to optimize queries for delivery_manager and delivery_profile
        queryset = DeliveryRequest.objects.select_related(
            'delivery_manager',
            'delivery_manager__delivery_profile',
            'customer'
        ).all()
        
        # If user is delivery manager, show ONLY their assigned requests (never pending)
        # Core Principle: Managers never see pending requests - only assigned requests
        if user.is_delivery_admin():
            queryset = queryset.filter(delivery_manager=user)
        
        # Admins can see all requests
        return queryset

    def get_object(self):
        """Override to provide better error messages and use optimized queryset."""
        try:
            pk = self.kwargs.get('pk')
            user = self.request.user
            
            # First, check if the delivery request exists (without filtering)
            # Use select_related for optimization
            try:
                delivery_request = DeliveryRequest.objects.select_related(
                    'delivery_manager',
                    'delivery_manager__delivery_profile',
                    'customer'
                ).get(pk=pk)
            except DeliveryRequest.DoesNotExist:
                raise NotFound(f"Delivery request with ID {pk} does not exist.")
            
            # Then check if user has permission to view it
            # Library admins can see all requests
            if user.user_type == 'library_admin' or user.is_staff or user.is_superuser:
                return delivery_request
            
            # For delivery managers, check if they have access
            if user.is_delivery_admin():
                # Core Principle: Managers never see pending requests - only assigned requests
                if delivery_request.delivery_manager == user:
                    return delivery_request
                else:
                    # Object exists but user doesn't have permission
                    raise NotFound(
                        f"Delivery request {pk} is not assigned to you. "
                        f"Current status: {delivery_request.status}, "
                        f"Assigned to: {delivery_request.delivery_manager.get_full_name() if delivery_request.delivery_manager else 'None'}"
                    )
            
            # If we get here, user doesn't have permission
            raise NotFound(f"You do not have permission to view delivery request {pk}.")
        except NotFound:
            raise
        except Exception as e:
            logger.error(f"Error retrieving delivery request: {str(e)}")
            raise NotFound("Failed to retrieve delivery request.")
    

@api_view(['POST'])
@permission_classes([IsLibraryAdmin])
def assign_delivery_manager(request, delivery_request_id):
    """
    Endpoint for assigning a delivery manager to a delivery request (Admin only).
    POST /delivery-requests/{id}/assign/
    Body: {"delivery_manager_id": <id>}
    """
    try:
        delivery_manager_id = request.data.get('delivery_manager_id')
        if not delivery_manager_id:
            return Response({
                'success': False,
                'error': 'delivery_manager_id is required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        delivery_manager = get_object_or_404(User, id=delivery_manager_id)
        
        if not delivery_manager.is_delivery_admin():
            return Response({
                'success': False,
                'error': 'User must be a delivery manager'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        delivery_request = get_object_or_404(DeliveryRequest, id=delivery_request_id)
        delivery_request = DeliveryService.assign_delivery_manager(
            delivery_request_id=delivery_request.id,
            delivery_manager=delivery_manager
        )
        
        serializer = DeliveryRequestDetailSerializer(delivery_request)
        return Response({
            'success': True,
            'message': 'Delivery manager assigned successfully',
            'data': serializer.data
        }, status=status.HTTP_200_OK)
    
    except (DRFValidationError, DjangoValidationError) as e:
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        logger.error(f"Error assigning delivery manager: {str(e)}")
        return Response({
            'success': False,
            'error': 'Failed to assign delivery manager'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsDeliveryAdmin])
def accept_delivery_request(request, delivery_request_id):
    """
    Endpoint for accepting a delivery request.
    POST /delivery-requests/{id}/accept/
    """
    try:
        serializer = AcceptDeliveryRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        delivery_request = get_object_or_404(DeliveryRequest, id=delivery_request_id)
        delivery_request = DeliveryService.accept_delivery_request(
            delivery_request_id=delivery_request.id,
            delivery_manager=request.user
        )
        
        serializer = DeliveryRequestDetailSerializer(delivery_request)
        return Response({
            'success': True,
            'message': 'Delivery request accepted successfully',
            'data': serializer.data
        }, status=status.HTTP_200_OK)
    
    except (DRFValidationError, DjangoValidationError) as e:
        # Handle both Django and DRF ValidationError
        error_message = str(e)
        if hasattr(e, 'message'):
            error_message = e.message
        elif hasattr(e, 'messages') and e.messages:
            error_message = e.messages[0] if isinstance(e.messages, list) else str(e.messages)
        elif isinstance(e, list):
            error_message = e[0] if e else str(e)
        
        logger.warning(f"Validation error accepting delivery request {delivery_request_id}: {error_message}")
        return Response({
            'success': False,
            'error': error_message,
            'message': error_message
        }, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        logger.error(f"Error accepting delivery request: {str(e)}", exc_info=True)
        return Response({
            'success': False,
            'error': 'Failed to accept delivery request',
            'message': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsDeliveryAdmin])
def reject_delivery_request(request, delivery_request_id):
    """
    Endpoint for rejecting a delivery request.
    POST /delivery-requests/{id}/reject/
    """
    try:
        serializer = RejectDeliveryRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        delivery_request = get_object_or_404(DeliveryRequest, id=delivery_request_id)
        delivery_request = DeliveryService.reject_delivery_request(
            delivery_request_id=delivery_request.id,
            delivery_manager=request.user,
            rejection_reason=serializer.validated_data['rejection_reason']
        )
        
        serializer = DeliveryRequestDetailSerializer(delivery_request)
        return Response({
            'success': True,
            'message': 'Delivery request rejected successfully',
            'data': serializer.data
        }, status=status.HTTP_200_OK)
    
    except (DRFValidationError, DjangoValidationError) as e:
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        logger.error(f"Error rejecting delivery request: {str(e)}")
        return Response({
            'success': False,
            'error': 'Failed to reject delivery request'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsDeliveryAdmin])
def start_delivery(request, delivery_request_id):
    """
    Endpoint for starting delivery.
    POST /delivery-requests/{id}/start/
    """
    try:
        serializer = StartDeliverySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        delivery_request = get_object_or_404(DeliveryRequest, id=delivery_request_id)
        delivery_request = DeliveryService.start_delivery(
            delivery_request_id=delivery_request.id,
            delivery_manager=request.user,
            notes=serializer.validated_data.get('notes')
        )
        
        serializer = DeliveryRequestDetailSerializer(delivery_request)
        return Response({
            'success': True,
            'message': 'Delivery started successfully',
            'data': serializer.data
        }, status=status.HTTP_200_OK)
    
    except (DRFValidationError, DjangoValidationError) as e:
        error_message = str(e)
        logger.warning(f"Validation error starting delivery {delivery_request_id}: {error_message}")
        return Response({
            'success': False,
            'error': error_message,
            'message': error_message
        }, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        logger.error(f"Error starting delivery {delivery_request_id}: {str(e)}", exc_info=True)
        return Response({
            'success': False,
            'error': f'Failed to start delivery: {str(e)}',
            'message': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsDeliveryAdmin])
def update_location(request, delivery_request_id):
    """
    Endpoint for updating delivery location (GPS).
    POST /delivery-requests/{id}/update-location/
    """
    try:
        serializer = UpdateLocationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        delivery_request = get_object_or_404(DeliveryRequest, id=delivery_request_id)
        delivery_request = DeliveryService.update_location(
            delivery_request_id=delivery_request.id,
            delivery_manager=request.user,
            latitude=serializer.validated_data['latitude'],
            longitude=serializer.validated_data['longitude']
        )
        
        serializer = DeliveryRequestDetailSerializer(delivery_request)
        return Response({
            'success': True,
            'message': 'Location updated successfully',
            'data': serializer.data
        }, status=status.HTTP_200_OK)
    
    except (DRFValidationError, DjangoValidationError) as e:
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        logger.error(f"Error updating location: {str(e)}")
        return Response({
            'success': False,
            'error': 'Failed to update location'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsDeliveryAdmin])
def complete_delivery(request, delivery_request_id):
    """
    Endpoint for completing delivery.
    POST /delivery-requests/{id}/complete/
    """
    try:
        serializer = CompleteDeliverySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        delivery_request = get_object_or_404(DeliveryRequest, id=delivery_request_id)
        delivery_request = DeliveryService.complete_delivery(
            delivery_request_id=delivery_request.id,
            delivery_manager=request.user,
            notes=serializer.validated_data.get('notes')
        )
        
        serializer = DeliveryRequestDetailSerializer(delivery_request)
        return Response({
            'success': True,
            'message': 'Delivery completed successfully',
            'data': serializer.data
        }, status=status.HTTP_200_OK)
    
    except (DRFValidationError, DjangoValidationError) as e:
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        logger.error(f"Error completing delivery: {str(e)}")
        return Response({
            'success': False,
            'error': 'Failed to complete delivery'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['PATCH'])
@permission_classes([IsDeliveryAdmin])
def update_payment_status(request, delivery_request_id):
    """
    Endpoint for updating payment status (deposit/fine) for completed deliveries.
    PATCH /delivery-requests/{id}/update-payment-status/
    Body: {"deposit_paid": true/false, "fine_status": "paid"/"unpaid"}
    """
    try:
        delivery_request = get_object_or_404(DeliveryRequest, id=delivery_request_id)
        
        # Only allow updates for completed deliveries
        if delivery_request.status != 'completed':
            return Response({
                'success': False,
                'error': 'Payment status can only be updated for completed deliveries'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Only the assigned delivery manager can update payment status
        if delivery_request.delivery_manager != request.user:
            return Response({
                'success': False,
                'error': 'Only the assigned delivery manager can update payment status'
            }, status=status.HTTP_403_FORBIDDEN)
        
        # Update based on delivery type
        if delivery_request.delivery_type == 'borrow' and delivery_request.borrow_request:
            borrow_request = delivery_request.borrow_request
            
            # Update deposit_paid if provided
            if 'deposit_paid' in request.data:
                deposit_paid = request.data.get('deposit_paid')
                if isinstance(deposit_paid, bool):
                    borrow_request.deposit_paid = deposit_paid
                    logger.info(f"Updated deposit_paid to {deposit_paid} for borrow request {borrow_request.id}")
            
            # Update fine_status if provided
            if 'fine_status' in request.data:
                fine_status = request.data.get('fine_status')
                from ..models.borrowing_model import FineStatusChoices
                if fine_status in [choice[0] for choice in FineStatusChoices.choices]:
                    borrow_request.fine_status = fine_status
                    logger.info(f"Updated fine_status to {fine_status} for borrow request {borrow_request.id}")
            
            borrow_request.save()
            
            serializer = DeliveryRequestDetailSerializer(delivery_request)
            return Response({
                'success': True,
                'message': 'Payment status updated successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
        
        elif delivery_request.delivery_type == 'return' and delivery_request.return_request:
            return_request = delivery_request.return_request
            
            # Update fine payment status if provided
            if 'fine_is_paid' in request.data and hasattr(return_request, 'fine') and return_request.fine:
                fine_is_paid = request.data.get('fine_is_paid')
                if isinstance(fine_is_paid, bool):
                    return_request.fine.is_paid = fine_is_paid
                    if fine_is_paid:
                        from django.utils import timezone
                        return_request.fine.paid_at = timezone.now()
                    return_request.fine.save()
                    logger.info(f"Updated fine is_paid to {fine_is_paid} for return request {return_request.id}")
            
            serializer = DeliveryRequestDetailSerializer(delivery_request)
            return Response({
                'success': True,
                'message': 'Payment status updated successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
        
        return Response({
            'success': False,
            'error': 'Payment status update is only available for borrow and return deliveries'
        }, status=status.HTTP_400_BAD_REQUEST)
    
    except Exception as e:
        logger.error(f"Error updating payment status: {str(e)}")
        return Response({
            'success': False,
            'error': 'Failed to update payment status'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['PUT', 'PATCH', 'DELETE'])
@permission_classes([CanManageDeliveryNotes])
def manage_delivery_notes(request, delivery_request_id):
    """
    Endpoint for managing delivery notes (add, update, or delete).
    PUT/PATCH /delivery-requests/{id}/notes/ - Add or update delivery notes
    DELETE /delivery-requests/{id}/notes/ - Delete delivery notes
    Can be used by admin, customer (for their own deliveries), and delivery manager (for assigned deliveries).
    Notes can only be modified before delivery is completed.
    """
    try:
        delivery_request = get_object_or_404(DeliveryRequest, id=delivery_request_id)
        
        # Check permission using the custom permission class
        if not CanManageDeliveryNotes().has_object_permission(request, None, delivery_request):
            return Response({
                'success': False,
                'error': 'You do not have permission to manage notes for this delivery.'
            }, status=status.HTTP_403_FORBIDDEN)
        
        if request.method == 'DELETE':
            # Delete notes
            delivery_request = DeliveryService.delete_delivery_notes(
                delivery_request_id=delivery_request.id,
                user=request.user
            )
            message = 'Delivery notes deleted successfully'
        else:
            # Add or update notes
            serializer = DeliveryNotesSerializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            
            delivery_request = DeliveryService.update_delivery_notes(
                delivery_request_id=delivery_request.id,
                notes=serializer.validated_data['notes'],
                user=request.user
            )
            message = 'Delivery notes updated successfully'
        
        response_serializer = DeliveryRequestDetailSerializer(delivery_request)
        return Response({
            'success': True,
            'message': message,
            'data': response_serializer.data
        }, status=status.HTTP_200_OK)
    
    except (DRFValidationError, DjangoValidationError) as e:
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        logger.error(f"Error managing delivery notes: {str(e)}")
        return Response({
            'success': False,
            'error': 'Failed to manage delivery notes'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([CustomerOrAdmin])
def log_order_note(request):
    """
    Endpoint for logging order notes (add, edit, or delete).
    POST /delivery/activities/log/note/
    Body: {
        'order_id': <int>,
        'notes_content': <string> (required for add/edit),
        'action': 'add' | 'edit' | 'delete',
        'note_id': <int> (optional, for edit/delete)
    }
    """
    try:
        order_id = request.data.get('order_id')
        if not order_id:
            return Response({
                'success': False,
                'error': 'order_id is required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            order = get_object_or_404(Order, id=int(order_id))
        except (ValueError, TypeError):
            return Response({
                'success': False,
                'error': 'Invalid order_id'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Check permission - customers can only manage notes for their own orders
        if not CustomerOrAdmin().has_object_permission(request, None, order):
            return Response({
                'success': False,
                'error': 'You do not have permission to manage notes for this order.'
            }, status=status.HTTP_403_FORBIDDEN)
        
        action = request.data.get('action', 'add').lower()
        
        if action == 'delete':
            # Delete notes (clear the notes field)
            order.notes = None
            order.save()
            message = 'Order notes deleted successfully'
        elif action == 'edit':
            # Update notes
            notes_content = request.data.get('notes_content', '').strip()
            if not notes_content:
                return Response({
                    'success': False,
                    'error': 'notes_content is required for edit action'
                }, status=status.HTTP_400_BAD_REQUEST)
            order.notes = notes_content
            order.save()
            message = 'Order notes updated successfully'
        elif action == 'add':
            # Add notes (append or replace)
            notes_content = request.data.get('notes_content', '').strip()
            if not notes_content:
                return Response({
                    'success': False,
                    'error': 'notes_content is required for add action'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Format note with author info: "[Author Name (Type)]: Note content"
            author_name = request.user.get_full_name()
            author_type = getattr(request.user, 'user_type', 'customer')
            author_type_display = {
                'customer': 'Customer',
                'library_admin': 'Admin',
                'delivery_admin': 'Delivery Manager'
            }.get(author_type, 'User')
            
            formatted_note = f"[{author_name} ({author_type_display})]: {notes_content}"
            
            # If notes already exist, append with newline; otherwise set
            if order.notes:
                order.notes = f"{order.notes}\n{formatted_note}"
            else:
                order.notes = formatted_note
            order.save()
            message = 'Order notes added successfully'
        else:
            return Response({
                'success': False,
                'error': f'Invalid action: {action}. Must be "add", "edit", or "delete"'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Return updated order
        serializer = CustomerOrderSerializer(order, context={'request': request})
        return Response({
            'success': True,
            'message': message,
            'data': serializer.data
        }, status=status.HTTP_200_OK)
    
    except Exception as e:
        logger.error(f"Error logging order note: {str(e)}")
        return Response({
            'success': False,
            'error': 'Failed to log order note'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class CustomerOrdersView(generics.ListCreateAPIView):
    """
    View for customers to view and create their orders.
    GET /delivery/orders/?order_type=purchase|borrowing&status=pending|confirmed|processing|delivered|cancelled
    POST /delivery/orders/ - Create order from cart checkout
    """
    serializer_class = CustomerOrderSerializer
    authentication_classes = [CustomJWTAuthentication]
    permission_classes = [CustomerOrAdmin]
    
    def get_queryset(self):
        """Filter orders - admins see all, customers see only their own."""
        user = self.request.user
        # Admins can see all orders, customers see only their own
        if user.is_staff or user.is_superuser or user.user_type in ['library_admin', 'delivery_admin']:
            queryset = Order.objects.select_related('payment', 'customer')
        else:
            queryset = Order.objects.filter(customer=user).select_related('payment', 'customer')
        
        # Filter by order type (query parameter: ?order_type=purchase|borrowing)
        order_type = self.request.query_params.get('order_type', None)
        if order_type:
            queryset = queryset.filter(order_type=order_type)
        
        # Filter by status (query parameter: ?status=pending|confirmed|processing|delivered|cancelled)
        status_filter = self.request.query_params.get('status', None)
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        
        # Search functionality (search in order_number, customer name, or book titles)
        search = self.request.query_params.get('search', None)
        if search:
            queryset = queryset.filter(
                Q(order_number__icontains=search) |
                Q(customer__first_name__icontains=search) |
                Q(customer__last_name__icontains=search) |
                Q(customer__email__icontains=search) |
                Q(items__book__name__icontains=search)
            ).distinct()
        
        # Prefetch discount_usages to avoid N+1 queries when serializer accesses discount_code
        return queryset.prefetch_related('discount_usages__discount_code').order_by('-created_at')
    
    def get_serializer_class(self):
        """Return appropriate serializer based on request method."""
        if self.request.method == 'POST':
            from ..serializers.delivery_serializers import OrderCreateSerializer
            return OrderCreateSerializer
        return CustomerOrderSerializer
    
    def list(self, request, *args, **kwargs):
        """Override list to add custom response format."""
        response = super().list(request, *args, **kwargs)
        
        # Handle paginated response
        if isinstance(response.data, dict) and 'results' in response.data:
            # Already paginated, just add success flag
            response.data['success'] = True
            return response
        
        # Non-paginated response - wrap in standard format
        if isinstance(response.data, list):
            return Response({
                'success': True,
                'count': len(response.data),
                'results': response.data
            }, status=status.HTTP_200_OK)
        
        # Fallback for other formats
        return Response({
            'success': True,
            'count': len(response.data) if isinstance(response.data, list) else 1,
            'results': response.data if isinstance(response.data, list) else [response.data]
        }, status=status.HTTP_200_OK)
    
    def create(self, request, *args, **kwargs):
        """Create order from cart checkout.
        Calculates total_price server-side from book prices for security.
        """
        from ..serializers.delivery_serializers import OrderCreateSerializer
        from ..models import Book, Payment, OrderItem, CartItem
        from django.db import transaction
        from decimal import Decimal, ROUND_HALF_UP
        
        serializer = OrderCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        try:
            with transaction.atomic():
                user = request.user
                cart_items_data = serializer.validated_data['cart_items']
                delivery_address = serializer.validated_data.get('address', '')
                payment_method = serializer.validated_data['payment_method']
                delivery_notes = serializer.validated_data.get('delivery_notes', '')
                card_details = serializer.validated_data.get('card_details')
                discount_code = serializer.validated_data.get('discount_code')
                discount_amount = serializer.validated_data.get('discount_amount')
                
                # Extract book IDs and quantities
                book_ids = [item['book_id'] for item in cart_items_data]
                book_quantities = {item['book_id']: item['quantity'] for item in cart_items_data}
                
                # Get books from database
                books = Book.objects.filter(id__in=book_ids)
                
                if books.count() != len(book_ids):
                    missing_ids = set(book_ids) - set(books.values_list('id', flat=True))
                    return Response({
                        'success': False,
                        'message': f'Books not found: {list(missing_ids)}'
                    }, status=status.HTTP_400_BAD_REQUEST)
                
                # Calculate total price server-side using Decimal for precision
                total = Decimal('0.00')
                order_items_data = []
                
                for book in books:
                    quantity = book_quantities[book.id]
                    if not book.price:
                        return Response({
                            'success': False,
                            'message': f'Book {book.name} (ID: {book.id}) has no price'
                        }, status=status.HTTP_400_BAD_REQUEST)
                    
                    item_price = Decimal(str(book.price))
                    item_total = item_price * quantity
                    total += item_total
                    
                    order_items_data.append({
                        'book': book,
                        'quantity': quantity,
                        'price': item_price
                    })
                
                # Round total to 2 decimal places
                subtotal = total.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
                
                # Handle discount if provided
                final_discount_amount = Decimal('0.00')
                if discount_code:
                    # Validate discount code if provided
                    from ..services.discount_services import DiscountValidationService
                    is_valid, discount_result = DiscountValidationService.validate_discount_code(
                        discount_code, user, float(subtotal)
                    )
                    if is_valid:
                        final_discount_amount = Decimal(str(discount_result['discount_amount']))
                        # Record discount usage
                        from ..models.discount_model import DiscountCode
                        try:
                            discount_code_obj = DiscountCode.objects.get(code=discount_code, is_active=True)
                            # Usage will be recorded when order is saved
                        except DiscountCode.DoesNotExist:
                            logger.warning(f"Discount code {discount_code} not found or inactive")
                    else:
                        logger.warning(f"Invalid discount code {discount_code}: {discount_result.get('message', 'Unknown error')}")
                elif discount_amount is not None:
                    # Use provided discount amount if no code validation needed
                    final_discount_amount = Decimal(str(discount_amount))
                
                # Calculate final total after discount
                final_total = subtotal - final_discount_amount
                if final_total < Decimal('0.00'):
                    final_total = Decimal('0.00')
                final_total = final_total.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
                
                # Get or create user's cart for payment reference
                from ..models import Cart
                cart, _ = Cart.objects.get_or_create(customer=user)
                
                # Map payment_method to payment_type
                payment_type_map = {
                    'cash_on_delivery': 'cash_on_delivery',
                    'cash': 'cash_on_delivery',
                    'mastercard': 'credit_card',
                }
                payment_type = payment_type_map.get(payment_method, 'cash_on_delivery')
                
                # Create payment with correct field names
                payment = Payment.objects.create(
                    customer=user,  # Use 'customer' not 'user'
                    amount=final_total,  # Use final total after discount
                    payment_type=payment_type,  # Use 'payment_type' not 'payment_method'
                    cart=cart,  # Required field
                    status='pending' if payment_method == 'cash_on_delivery' or payment_method == 'cash' else 'completed',
                    discount_code_used=discount_code if discount_code else None,
                    discount_amount=final_discount_amount,
                )
                
                # Create order
                order = Order.objects.create(
                    customer=user,
                    order_type='purchase',
                    status='pending',
                    total_amount=final_total,  # Final total after discount
                    delivery_cost=Decimal('0.00'),
                    tax_amount=Decimal('0.00'),
                    discount_amount=final_discount_amount,  # Save actual discount amount
                    delivery_address=delivery_address,
                    notes=delivery_notes,
                    payment=payment
                )
                
                # Record discount usage if discount code was used
                if discount_code and final_discount_amount > Decimal('0.00'):
                    try:
                        from ..models.discount_model import DiscountCode
                        discount_code_obj = DiscountCode.objects.get(code=discount_code, is_active=True)
                        discount_code_obj.use_by_customer(user, order)
                        logger.info(f"Recorded discount code usage: {discount_code} for order {order.id}")
                    except Exception as e:
                        logger.warning(f"Failed to record discount usage: {str(e)}")
                        # Don't fail order creation if discount recording fails
                
                # Create order items using Django ORM (recommended approach)
                for item_data in order_items_data:
                    OrderItem.objects.create(
                        order=order,
                        book=item_data['book'],
                        quantity=item_data['quantity'],
                        price=item_data['price'],  # Price per unit at time of order
                    )
                
                # Optionally clear cart items (if using CartItem model)
                # This is optional - you may want to keep cart items for reference
                try:
                    CartItem.objects.filter(
                        cart__customer=user,
                        book_id__in=book_ids
                    ).delete()
                except Exception as e:
                    logger.warning(f"Could not clear cart items: {str(e)}")
                
                # Create delivery request for purchase order
                try:
                    from ..services.delivery_services import DeliveryService
                    delivery_request = DeliveryService.create_delivery_request(
                        delivery_type='purchase',
                        customer=user,
                        delivery_address=delivery_address,
                        order=order
                    )
                    logger.info(f"Created delivery request {delivery_request.id} for order {order.id}")
                except Exception as e:
                    logger.error(f"Failed to create delivery request for order {order.id}: {str(e)}")
                    # Don't fail the order creation if delivery request creation fails
                
                # Serialize response
                response_serializer = CustomerOrderSerializer(order)
                
                return Response({
                    'success': True,
                    'message': 'Order created successfully',
                    'data': response_serializer.data
                }, status=status.HTTP_201_CREATED)
                
        except (DRFValidationError, DjangoValidationError) as e:
            logger.error(f"Validation error creating order: {e.detail}")
            return Response({
                'success': False,
                'message': 'Failed to create order',
                'errors': e.detail
            }, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error(f"Error creating order: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to create order',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class OrderDetailView(generics.RetrieveAPIView):
    """
    View for retrieving a single order detail.
    GET /delivery/orders/{id}/
    """
    serializer_class = CustomerOrderSerializer
    authentication_classes = [CustomJWTAuthentication]
    permission_classes = [CustomerOrAdmin]
    queryset = Order.objects.all()
    
    def get_queryset(self):
        """Filter orders - admins see all, customers see only their own."""
        user = self.request.user
        if user.is_staff or user.is_superuser or user.user_type in ['library_admin', 'delivery_admin']:
            return Order.objects.select_related('payment', 'customer').prefetch_related('discount_usages__discount_code')
        return Order.objects.filter(customer=user).select_related('payment', 'customer').prefetch_related('discount_usages__discount_code')
    
    def retrieve(self, request, *args, **kwargs):
        """Override retrieve to return order data directly (frontend expects direct order data)."""
        instance = self.get_object()
        serializer = self.get_serializer(instance)
        # Frontend expects the order data directly, not wrapped in a 'data' key
        return Response(serializer.data, status=status.HTTP_200_OK)


@api_view(['PATCH'])
@permission_classes([IsLibraryAdmin])
def approve_order(request, pk):
    """
    Approve an order and assign a delivery manager.
    PATCH /delivery/orders/{id}/approve/
    Body: {"delivery_manager_id": <id>}
    """
    try:
        order = get_object_or_404(Order, id=pk)
        
        # Get delivery manager ID from request
        delivery_manager_id = request.data.get('delivery_manager_id')
        if not delivery_manager_id:
            return Response({
                'success': False,
                'message': 'delivery_manager_id is required',
                'error': 'MISSING_DELIVERY_MANAGER'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Get delivery manager
        delivery_manager = get_object_or_404(User, id=delivery_manager_id)
        if not delivery_manager.is_delivery_admin():
            return Response({
                'success': False,
                'message': 'User must be a delivery manager',
                'error': 'INVALID_DELIVERY_MANAGER'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Check if delivery manager is available - only 'online' (available) managers can be assigned
        from ..models.delivery_profile_model import DeliveryProfile
        delivery_profile, created = DeliveryProfile.objects.get_or_create(
            user=delivery_manager,
            defaults={'delivery_status': 'offline'}
        )
        
        # Only allow assignment if manager is 'online' (available)
        if delivery_profile.delivery_status != 'online':
            status_display = delivery_profile.get_delivery_status_display() if delivery_profile.delivery_status else 'offline'
            return Response({
                'success': False,
                'message': f'Cannot assign order: Delivery manager is {status_display.lower()}. Only available (online) managers can be assigned new requests.',
                'error': 'DELIVERY_MANAGER_NOT_AVAILABLE'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Update order status to confirmed if it's pending
        # If already confirmed, just assign the delivery manager
        if order.status == 'pending':
            order.status = 'confirmed'
            order.save()
        elif order.status not in ['pending', 'confirmed', 'processing']:
            return Response({
                'success': False,
                'message': f'Order cannot be approved. Current status: {order.get_status_display()}',
                'error': 'INVALID_STATUS'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Find or create delivery request for this order
        from ..models import DeliveryRequest
        delivery_request = DeliveryRequest.objects.filter(
            order=order,
            delivery_type='purchase'
        ).first()
        
        if delivery_request:
            # Update existing delivery request
            delivery_request.delivery_manager = delivery_manager
            delivery_request.status = 'assigned'
            delivery_request.assigned_at = timezone.now()
            delivery_request.save()
        else:
            # Create new delivery request directly with status='assigned' and delivery_manager
            # CRITICAL: Never create with status='pending' + delivery_manager (invalid design)
            delivery_request = DeliveryRequest.objects.create(
                delivery_type='purchase',
                customer=order.customer,
                delivery_address=order.delivery_address,
                order=order,
                delivery_manager=delivery_manager,
                status='assigned',
                assigned_at=timezone.now()
            )
        
        # Send notification to delivery manager
        try:
            from ..services.notification_services import NotificationService
            NotificationService.create_notification(
                user_id=delivery_manager.id,
                title="New Delivery Assignment",
                message=f"You have been assigned to deliver order {order.order_number} for {order.customer.get_full_name()}.",
                notification_type="delivery_assignment"
            )
        except Exception as e:
            logger.warning(f"Failed to send notification to delivery manager: {str(e)}")
        
        # Send notification to customer
        try:
            from ..services.notification_services import NotificationService
            NotificationService.create_notification(
                user_id=order.customer.id,
                title="Order Approved",
                message=f"Your order {order.order_number} has been approved and assigned to a delivery manager.",
                notification_type="order_approved"
            )
        except Exception as e:
            logger.warning(f"Failed to send notification to customer: {str(e)}")
        
        # Serialize and return updated order
        serializer = CustomerOrderSerializer(order)
        
        return Response({
            'success': True,
            'message': 'Order approved and delivery manager assigned successfully',
            'order': serializer.data
        }, status=status.HTTP_200_OK)
        
    except (DRFValidationError, DjangoValidationError) as e:
        return Response({
            'success': False,
            'message': 'Validation error',
            'errors': e.detail
        }, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        logger.error(f"Error approving order: {str(e)}")
        return Response({
            'success': False,
            'message': 'Failed to approve order',
            'errors': format_error_message(str(e))
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['PATCH'])
@permission_classes([IsLibraryAdmin])
def reject_order(request, pk):
    """
    Reject/cancel an order.
    PATCH /delivery/orders/{id}/reject/
    Body: {"rejection_reason": "<reason>"}
    """
    try:
        order = get_object_or_404(Order, id=pk)
        
        # Get rejection reason from request
        rejection_reason = request.data.get('rejection_reason', '').strip()
        if not rejection_reason:
            return Response({
                'success': False,
                'message': 'rejection_reason is required',
                'error': 'MISSING_REJECTION_REASON'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Check if order can be rejected (only pending orders can be rejected)
        if order.status not in ['pending', 'confirmed']:
            return Response({
                'success': False,
                'message': f'Order cannot be rejected. Current status: {order.get_status_display()}',
                'error': 'INVALID_STATUS'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Update order status to cancelled
        order.status = 'cancelled'
        order.cancellation_reason = rejection_reason
        order.save()
        
        # If there's a delivery request, update it
        from ..models import DeliveryRequest
        delivery_request = DeliveryRequest.objects.filter(
            order=order,
            delivery_type='purchase'
        ).first()
        
        if delivery_request:
            # Update delivery request status to rejected
            delivery_request.status = 'rejected'
            delivery_request.rejection_reason = rejection_reason
            delivery_request.rejected_at = timezone.now()
            # Clear delivery manager assignment if exists
            if delivery_request.delivery_manager:
                delivery_request.delivery_manager = None
                delivery_request.assigned_at = None
            delivery_request.save()
        
        # Send notification to customer
        try:
            from ..services.notification_services import NotificationService
            NotificationService.create_notification(
                user_id=order.customer.id,
                title="Order Rejected",
                message=f"Your order {order.order_number} has been rejected. Reason: {rejection_reason}",
                notification_type="order_rejected"
            )
        except Exception as e:
            logger.warning(f"Failed to send notification to customer: {str(e)}")
        
        # Send notification to delivery manager if assigned
        if delivery_request and delivery_request.delivery_manager:
            try:
                from ..services.notification_services import NotificationService
                NotificationService.create_notification(
                    user_id=delivery_request.delivery_manager.id,
                    title="Order Assignment Cancelled",
                    message=f"Order {order.order_number} has been rejected and your assignment has been cancelled.",
                    notification_type="order_rejected"
                )
            except Exception as e:
                logger.warning(f"Failed to send notification to delivery manager: {str(e)}")
        
        # Serialize and return updated order
        serializer = CustomerOrderSerializer(order)
        
        return Response({
            'success': True,
            'message': 'Order rejected successfully',
            'order': serializer.data
        }, status=status.HTTP_200_OK)
        
    except (DRFValidationError, DjangoValidationError) as e:
        return Response({
            'success': False,
            'message': 'Validation error',
            'errors': e.detail
        }, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        logger.error(f"Error rejecting order: {str(e)}")
        return Response({
            'success': False,
            'message': 'Failed to reject order',
            'errors': format_error_message(str(e))
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class AvailableDeliveryManagersView(generics.ListAPIView):
    """
    API view to get available delivery managers for order assignment.
    GET /delivery/orders/available_delivery_managers/
    """
    authentication_classes = [CustomJWTAuthentication]
    permission_classes = [IsAnyAdmin]
    
    def list(self, request, *args, **kwargs):
        """Get all delivery managers with their status."""
        try:
            from ..services.borrowing_services import BorrowingService
            from ..serializers.borrowing_serializers import DeliveryManagerSerializer
            
            managers = BorrowingService.get_available_delivery_managers()
            serializer = DeliveryManagerSerializer(managers, many=True)
            
            return Response({
                'success': True,
                'message': 'Delivery managers retrieved successfully',
                'delivery_managers': serializer.data  # Frontend expects 'delivery_managers' key
            }, status=status.HTTP_200_OK)
        except Exception as e:
            logger.error(f"Error retrieving delivery managers: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve delivery managers',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsDeliveryAdmin])
def my_assignments(request):
    """
    Get delivery requests assigned to the current delivery manager.
    GET /delivery/assignments/my-assignments/
    """
    try:
        user = request.user
        # Get all delivery requests assigned to this delivery manager
        queryset = DeliveryRequest.objects.filter(
            delivery_manager=user
        ).order_by('-created_at')
        
        # Filter by status if provided
        status_filter = request.query_params.get('status', None)
        if status_filter:
            statuses = [s.strip() for s in status_filter.split(',')]
            queryset = queryset.filter(status__in=statuses)
        
        serializer = DeliveryRequestListSerializer(queryset, many=True)
        
        return Response({
            'success': True,
            'count': len(serializer.data),
            'results': serializer.data
        }, status=status.HTTP_200_OK)
    except Exception as e:
        logger.error(f"Error fetching my assignments: {str(e)}")
        return Response({
            'success': False,
            'message': 'Failed to fetch assignments',
            'errors': format_error_message(str(e))
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAnyAdmin])
def get_delivery_request_by_return_id(request, return_request_id):
    """
    Get DeliveryRequest ID by ReturnRequest ID.
    This helps frontend resolve the correct DeliveryRequest ID when it only has the ReturnRequest ID.
    GET /delivery/delivery-requests/by-return/{return_request_id}/
    """
    try:
        from ..models.return_model import ReturnRequest
        
        return_request = get_object_or_404(ReturnRequest, id=return_request_id)
        
        # Get the associated DeliveryRequest
        delivery_request = DeliveryRequest.objects.filter(
            return_request=return_request,
            delivery_type='return'
        ).first()
        
        if not delivery_request:
            return Response({
                'success': False,
                'message': f'No DeliveryRequest found for ReturnRequest {return_request_id}. The return request may not be assigned yet.'
            }, status=status.HTTP_404_NOT_FOUND)
        
        # Check permissions
        user = request.user
        if user.is_delivery_admin():
            # Delivery managers can only see their assigned requests
            if delivery_request.delivery_manager != user:
                return Response({
                    'success': False,
                    'message': 'You do not have permission to view this delivery request'
                }, status=status.HTTP_403_FORBIDDEN)
        
        return Response({
            'success': True,
            'delivery_request_id': delivery_request.id,
            'return_request_id': return_request_id,
            'status': delivery_request.status,
            'delivery_manager_id': delivery_request.delivery_manager.id if delivery_request.delivery_manager else None
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"Error getting delivery request by return ID: {str(e)}")
        return Response({
            'success': False,
            'message': 'Failed to get delivery request',
            'errors': format_error_message(str(e))
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsDeliveryAdmin])
def assigned_requests(request):
    """
    Get delivery requests assigned to the current delivery manager.
    GET /delivery/managers/assigned-requests/
    Alias for my-assignments endpoint.
    """
    try:
        user = request.user
        # Get all delivery requests assigned to this delivery manager
        queryset = DeliveryRequest.objects.filter(
            delivery_manager=user
        ).order_by('-created_at')
        
        # Filter by status if provided
        status_filter = request.query_params.get('status', None)
        if status_filter:
            statuses = [s.strip() for s in status_filter.split(',')]
            queryset = queryset.filter(status__in=statuses)
        
        serializer = DeliveryRequestListSerializer(queryset, many=True)
        
        return Response({
            'success': True,
            'count': len(serializer.data),
            'results': serializer.data
        }, status=status.HTTP_200_OK)
    except Exception as e:
        logger.error(f"Error fetching assigned requests: {str(e)}")
        return Response({
            'success': False,
            'message': 'Failed to fetch assigned requests',
            'errors': format_error_message(str(e))
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsDeliveryAdmin])
def delivery_notifications(request):
    """
    Get delivery-related notifications for the current delivery manager.
    GET /delivery/notifications/?limit=10&offset=0
    """
    try:
        from ..serializers.notification_serializers import NotificationSerializer
        
        user = request.user
        logger.info(f"Fetching delivery notifications for user: {user.id} ({user.get_full_name()})")
        
        # Filter notifications by delivery-related types
        delivery_notification_types = [
            'delivery_assignment',
            'delivery_accepted',
            'delivery_rejected',
            'delivery_started',
            'delivery_completed',
            'order_approved',
        ]
        
        # Get query parameters for pagination
        limit = request.query_params.get('limit')
        offset = request.query_params.get('offset')
        
        # Check total notifications for this user (for debugging)
        total_user_notifications = Notification.objects.filter(recipient=user).count()
        logger.info(f"Total notifications for user {user.id}: {total_user_notifications}")
        
        # Check notifications by type (for debugging)
        for notif_type in delivery_notification_types:
            count = Notification.objects.filter(
                recipient=user,
                notification_type__name=notif_type
            ).count()
            if count > 0:
                logger.info(f"Found {count} notifications of type '{notif_type}' for user {user.id}")
        
        # Base queryset: delivery-related notifications for current user
        notifications = Notification.objects.filter(
            recipient=user,
            notification_type__name__in=delivery_notification_types
        ).order_by('-created_at')
        
        notifications_count = notifications.count()
        logger.info(f"Found {notifications_count} delivery-related notifications for user {user.id}")
        
        # Apply pagination if provided
        if limit:
            try:
                limit_int = int(limit)
                if offset:
                    offset_int = int(offset)
                    notifications = notifications[offset_int:offset_int + limit_int]
                else:
                    notifications = notifications[:limit_int]
            except ValueError:
                pass  # Invalid limit/offset, return all
        
        serializer = NotificationSerializer(notifications, many=True)
        
        logger.info(f"Returning {len(serializer.data)} notifications to frontend")
        
        return Response({
            'success': True,
            'notifications': serializer.data,
            'count': len(serializer.data)
        }, status=status.HTTP_200_OK)
    except Exception as e:
        logger.error(f"Error fetching delivery notifications: {str(e)}", exc_info=True)
        return Response({
            'success': False,
            'message': 'Failed to fetch notifications',
            'notifications': [],
            'errors': format_error_message(str(e))
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsDeliveryAdmin])
def delivery_notification_mark_read(request, notification_id):
    """
    Mark a delivery notification as read.
    POST /delivery/notifications/{id}/mark-read/
    """
    try:
        from django.utils import timezone
        
        user = request.user
        notification = get_object_or_404(Notification, id=notification_id, recipient=user)
        
        # Mark as read
        if notification.status != 'read':
            notification.status = 'read'
            notification.read_at = timezone.now()
            notification.save()
        
        return Response({
            'success': True,
            'message': 'Notification marked as read'
        }, status=status.HTTP_200_OK)
    except Exception as e:
        logger.error(f"Error marking notification as read: {str(e)}")
        return Response({
            'success': False,
            'message': 'Failed to mark notification as read',
            'errors': format_error_message(str(e))
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsDeliveryAdmin])
def delivery_notifications_unread_count(request):
    """
    Get unread notification count for delivery-related notifications.
    GET /delivery/notifications/unread-count/
    """
    try:
        user = request.user
        # Filter notifications by delivery-related types
        delivery_notification_types = [
            'delivery_assignment',
            'delivery_accepted',
            'delivery_rejected',
            'delivery_started',
            'delivery_completed',
            'order_approved',
        ]
        
        unread_count = Notification.objects.filter(
            recipient=user,
            status='unread',
            notification_type__name__in=delivery_notification_types
        ).count()
        
        return Response({
            'success': True,
            'unread_count': unread_count
        }, status=status.HTTP_200_OK)
    except Exception as e:
        logger.error(f"Error fetching unread count: {str(e)}")
        return Response({
            'success': False,
            'message': 'Failed to fetch unread count',
            'unread_count': 0,
            'errors': format_error_message(str(e))
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsDeliveryAdmin])
def set_availability(request):
    """
    Endpoint to manually set delivery manager availability.
    POST /delivery/set-availability/
    Body: {"status": "available"|"offline"}
    """
    try:
        user = request.user
        status_value = request.data.get('status')
        
        if not status_value:
            return Response({
                'success': False,
                'error': 'status is required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        if status_value not in ['available', 'offline']:
            return Response({
                'success': False,
                'error': 'Invalid status. Must be "available" or "offline".'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        result = DeliveryService.set_availability_status(user, status_value)
        
        return Response({
            'success': True,
            'message': result['message'],
            'status': status_value
        }, status=status.HTTP_200_OK)
    
    except (DRFValidationError, DjangoValidationError) as e:
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        logger.error(f"Error setting availability: {str(e)}")
        return Response({
            'success': False,
            'error': 'Failed to set availability'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsDeliveryAdmin])
def get_availability(request):
    """
    Get current delivery manager availability status.
    GET /delivery/get-availability/
    Returns: {"status": "available"|"offline"}
    """
    try:
        from ..models.delivery_profile_model import DeliveryProfile
        
        user = request.user
        delivery_profile, created = DeliveryProfile.objects.get_or_create(
            user=user,
            defaults={'delivery_status': 'offline'}
        )
        
        # Map internal status to external status
        internal_status = delivery_profile.delivery_status or 'offline'
        if internal_status == 'online':
            external_status = 'available'
        else:
            external_status = 'offline'  # Only 'online' or 'offline' are valid
        
        return Response({
            'success': True,
            'status': external_status
        }, status=status.HTTP_200_OK)
    
    except Exception as e:
        logger.error(f"Error getting availability: {str(e)}")
        return Response({
            'success': False,
            'error': 'Failed to get availability',
            'status': 'offline'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated, CustomerOrAdmin])
def get_delivery_request_by_borrow_id(request, borrow_request_id):
    """
    Get DeliveryRequest by BorrowRequest ID for customers.
    This endpoint allows customers to view delivery status for their borrow requests.
    Only returns status, delivery manager name, and location (only when in_delivery).
    GET /delivery/delivery-requests/by-borrow/{borrow_request_id}/
    """
    try:
        borrow_request = get_object_or_404(BorrowRequest, id=borrow_request_id)
        
        # Check permissions - customer can only view their own borrow requests
        if (borrow_request.customer != request.user and 
            not request.user.is_library_admin() and 
            not request.user.is_delivery_admin()):
            return Response({
                'success': False,
                'message': 'You do not have permission to view this delivery request'
            }, status=status.HTTP_403_FORBIDDEN)
        
        # Get the associated DeliveryRequest
        delivery_request = DeliveryRequest.objects.filter(
            borrow_request=borrow_request,
            delivery_type='borrow'
        ).select_related(
            'delivery_manager',
            'delivery_manager__delivery_profile'
        ).first()
        
        if not delivery_request:
            return Response({
                'success': False,
                'message': f'No DeliveryRequest found for BorrowRequest {borrow_request_id}. The borrow request may not be assigned to delivery yet.'
            }, status=status.HTTP_404_NOT_FOUND)
        
        # Serialize using customer-facing serializer
        serializer = CustomerDeliveryRequestSerializer(delivery_request)
        
        return Response({
            'success': True,
            'data': serializer.data
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"Error getting delivery request by borrow ID: {str(e)}")
        return Response({
            'success': False,
            'message': 'Failed to get delivery request',
            'errors': format_error_message(str(e))
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated, CustomerOrAdmin])
def get_order_delivery_location(request, order_id):
    """
    Get delivery manager location for a purchase order.
    GET /api/delivery/orders/{order_id}/delivery-location/
    Only available when delivery status is 'in_delivery'.
    """
    try:
        order = get_object_or_404(Order, id=order_id)
        
        # Check permissions - customer can only view their own orders
        if (order.customer != request.user and 
            not request.user.is_library_admin() and 
            not request.user.is_delivery_admin()):
            return Response({
                'success': False,
                'message': 'You do not have permission to view this delivery location'
            }, status=status.HTTP_403_FORBIDDEN)
        
        # Get the associated DeliveryRequest for purchase orders
        delivery_request = DeliveryRequest.objects.filter(
            order=order,
            delivery_type='purchase'
        ).select_related(
            'delivery_manager',
            'delivery_manager__delivery_profile'
        ).first()
        
        if not delivery_request:
            return Response({
                'success': False,
                'message': 'No delivery request found for this order',
                'errors': {'delivery': ['Delivery request not created yet']}
            }, status=status.HTTP_404_NOT_FOUND)
        
        # Check delivery request status - location only available when in_delivery
        if delivery_request.status != 'in_delivery':
            return Response({
                'success': False,
                'message': 'Location tracking is not available for this order',
                'errors': {'status': ['Location tracking is only available when delivery is in progress']},
                'current_delivery_status': delivery_request.status
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Get delivery manager
        delivery_manager = delivery_request.delivery_manager
        if not delivery_manager:
            return Response({
                'success': False,
                'message': 'No delivery manager assigned',
                'errors': {'delivery_manager': ['Delivery manager not assigned']}
            }, status=status.HTTP_404_NOT_FOUND)
        
        # Get current location from delivery profile
        location_data = None
        if hasattr(delivery_manager, 'delivery_profile') and delivery_manager.delivery_profile:
            profile = delivery_manager.delivery_profile
            if profile.latitude is not None and profile.longitude is not None:
                location_data = {
                    'latitude': float(profile.latitude),
                    'longitude': float(profile.longitude),
                    'address': profile.address,
                    'last_updated': profile.location_updated_at.isoformat() if profile.location_updated_at else None,
                    'is_tracking_active': profile.is_tracking_active
                }
        
        # Get latest location from history if profile doesn't have it
        if not location_data:
            from ..models.delivery_model import LocationHistory
            latest_location = LocationHistory.objects.filter(
                delivery_manager=delivery_manager
            ).order_by('-recorded_at').first()
            
            if latest_location:
                location_data = {
                    'latitude': float(latest_location.latitude),
                    'longitude': float(latest_location.longitude),
                    'address': latest_location.address,
                    'last_updated': latest_location.recorded_at.isoformat(),
                    'is_tracking_active': True
                }
        
        if not location_data:
            return Response({
                'success': False,
                'message': 'Location not available',
                'errors': {'location': ['Delivery manager location is not available']}
            }, status=status.HTTP_404_NOT_FOUND)
        
        # Get delivery manager details
        delivery_manager_info = {
            'id': delivery_manager.id,
            'name': delivery_manager.get_full_name(),
            'phone': delivery_manager.phone_number if hasattr(delivery_manager, 'phone_number') else None,
            'email': delivery_manager.email
        }
        
        return Response({
            'success': True,
            'message': 'Delivery location retrieved successfully',
            'data': {
                'order_id': order.id,
                'order_number': order.order_number,
                'delivery_status': delivery_request.status,
                'delivery_manager': delivery_manager_info,
                'location': location_data,
                'tracking_enabled': True,
                'tracking_interval_seconds': 5
            }
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"Error getting order delivery location: {str(e)}")
        return Response({
            'success': False,
            'message': 'Failed to get delivery location',
            'errors': format_error_message(str(e))
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


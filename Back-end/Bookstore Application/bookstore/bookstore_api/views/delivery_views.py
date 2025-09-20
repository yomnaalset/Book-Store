from rest_framework import generics, status, permissions
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.views import APIView
from django.shortcuts import get_object_or_404
from django.utils import timezone
from django.core.exceptions import PermissionDenied
from django.db.models import Q
from django.core.paginator import Paginator
import logging
from datetime import datetime

from ..models import User, DeliveryRequest, Order, DeliveryAssignment, DeliveryStatusHistory
from ..services import NotificationService
from ..serializers.delivery_serializers import (
    OrderListSerializer, OrderDetailSerializer, OrderStatusUpdateSerializer,
    DeliveryRequestCreateSerializer,
    DeliveryRequestListSerializer,
    DeliveryRequestDetailSerializer,
    DeliveryRequestAssignSerializer,
    DeliveryRequestStatusUpdateSerializer,
    DeliveryAssignmentBasicSerializer,
    OrderCreateFromPaymentSerializer,
    DeliveryRequestWithAvailableManagersSerializer,

)   

from ..permissions import IsLibraryAdminReadOnly, IsDeliveryAdmin, IsDeliveryAdminOrLibraryAdmin, IsLibraryAdmin

logger = logging.getLogger(__name__)

class CustomerDeliveryRequestCreateView(generics.CreateAPIView):
    """
    Create a new delivery request.
    Accessible by customers only.
    """
    serializer_class = DeliveryRequestCreateSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def perform_create(self, serializer):
        if not self.request.user.is_customer():
            raise PermissionDenied("Only customers can create delivery requests.")
        return serializer.save()


class CustomerDeliveryRequestListView(generics.ListAPIView):
    """
    List all delivery requests for the current customer.
    """
    serializer_class = DeliveryRequestListSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        user = self.request.user
        
        if not user.is_customer():
            return DeliveryRequest.objects.none()
        
        queryset = DeliveryRequest.objects.filter(customer=user)
        
        # Filter by status
        status_filter = self.request.query_params.get('status')
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        
        return queryset.order_by('-created_at')


class DeliveryRequestDetailView(generics.RetrieveAPIView):
    """
    Retrieve delivery request details.
    Accessible by the request owner, delivery managers, and library admins.
    """
    serializer_class = DeliveryRequestDetailSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        return DeliveryRequest.objects.all()
    
    def get_object(self):
        request = super().get_object()
        user = self.request.user
        
        # Check permissions
        if not (user.is_delivery_admin() or user.is_library_admin() or request.customer == user):
            self.permission_denied(self.request, message="You don't have permission to view this request.")
        
        return request


class DeliveryRequestAssignView(APIView):
    """
    Assign a delivery request to a delivery manager.
    Accessible by system admins only.
    """
    permission_classes = [permissions.IsAuthenticated, permissions.IsAdminUser]
    
    def post(self, request, pk):
        delivery_request = get_object_or_404(DeliveryRequest, pk=pk)
        
        serializer = DeliveryRequestAssignSerializer(data=request.data)
        
        if serializer.is_valid():
            delivery_manager_id = serializer.validated_data['delivery_manager_id']
            notes = serializer.validated_data.get('notes', '')
            
            delivery_manager = get_object_or_404(User, pk=delivery_manager_id)
            
            # Update request
            delivery_request.delivery_manager = delivery_manager
            delivery_request.status = 'in_operation'
            delivery_request.assigned_at = timezone.now()
            delivery_request.save()
            
            response_serializer = DeliveryRequestDetailSerializer(delivery_request)
            return Response(response_serializer.data, status=status.HTTP_200_OK)
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class DeliveryRequestStatusUpdateView(APIView):
    """
    Update delivery request status.
    Accessible by assigned delivery managers only.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def patch(self, request, pk):
        delivery_request = get_object_or_404(DeliveryRequest, pk=pk)
        user = request.user
        
        # Check permissions
        if not (user.is_delivery_admin() and delivery_request.delivery_manager == user):
            return Response({
                'error': "Only the assigned delivery manager can update this request's status.",
                'debug': {
                    'user_id': user.id,
                    'user_type': user.user_type,
                    'is_delivery_admin': user.is_delivery_admin(),
                    'request_delivery_manager_id': delivery_request.delivery_manager.id if delivery_request.delivery_manager else None,
                    'request_status': delivery_request.status
                }
            }, status=status.HTTP_403_FORBIDDEN)
        
        serializer = DeliveryRequestStatusUpdateSerializer(data=request.data)
        
        if serializer.is_valid():
            new_status = serializer.validated_data['status']
            notes = serializer.validated_data.get('notes', '')
            
            # Validate status transition
            current_status = delivery_request.status
            valid_transitions = {
                'pending': ['in_operation'],
                'in_operation': ['delivered'],
                'delivered': []  # Final state
            }
            
            if new_status not in valid_transitions.get(current_status, []):
                return Response({
                    'error': f"Cannot change status from '{current_status}' to '{new_status}'"
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Update request status
            delivery_request.status = new_status
            
            # Set delivered_at timestamp if delivered
            if new_status == 'delivered':
                delivery_request.delivered_at = timezone.now()
                # Update delivery manager status back to online
                if delivery_request.delivery_manager:
                    delivery_request.delivery_manager.delivery_status = 'online'
                    delivery_request.delivery_manager.save()
            
            delivery_request.save()
            
            response_serializer = DeliveryRequestDetailSerializer(delivery_request)
            return Response({
                'message': f'Request status updated from {current_status} to {new_status}',
                'request': response_serializer.data
            }, status=status.HTTP_200_OK)
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class DeliveryManagerAssignedRequestsView(generics.ListAPIView):
    """
    List all delivery requests assigned to the current delivery manager.
    """
    serializer_class = DeliveryRequestListSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        user = self.request.user
        
        if not user.is_delivery_admin():
            return DeliveryRequest.objects.none()
        
        queryset = DeliveryRequest.objects.filter(delivery_manager=user)
        
        # Filter by status
        status_filter = self.request.query_params.get('status')
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        
        return queryset.order_by('-assigned_at')


class LibraryAdminRequestListView(generics.ListAPIView):
    """
    List all delivery requests for library admins with available delivery managers.
    Library admins can see which delivery managers are available to deliver each request.
    """
    serializer_class = DeliveryRequestWithAvailableManagersSerializer
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def get_queryset(self):
        queryset = DeliveryRequest.objects.filter(status='pending')
        
        # Filter by customer
        customer_id = self.request.query_params.get('customer_id')
        if customer_id:
            queryset = queryset.filter(customer_id=customer_id)
        
        return queryset.order_by('-created_at')


class LibraryAdminAssignManagerView(APIView):
    """
    Assign a delivery manager to a delivery request.
    Accessible by library admins only.
    """
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def post(self, request, pk):
        try:
            # Get the delivery request
            delivery_request = get_object_or_404(DeliveryRequest, pk=pk, status='pending')
            
            # Validate request data
            serializer = DeliveryRequestAssignSerializer(data=request.data)
            if not serializer.is_valid():
                return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
            
            delivery_manager_id = serializer.validated_data['delivery_manager_id']
            notes = serializer.validated_data.get('notes', '')
            
            # Get delivery manager
            try:
                delivery_manager = User.objects.get(id=delivery_manager_id, user_type='delivery_admin', is_active=True)
            except User.DoesNotExist:
                return Response({
                    'error': 'Delivery manager not found or is not active'
                }, status=status.HTTP_404_NOT_FOUND)
            
            # Check if delivery manager is available (simplified check)
            # Basic availability: active delivery admin not currently delivering
            if delivery_manager.delivery_status == 'busy':
                active_requests_count = delivery_manager.assigned_requests.filter(status='in_operation').count()
                if active_requests_count > 0:
                    return Response({
                        'error': 'Selected delivery manager is currently busy with another delivery'
                    }, status=status.HTTP_400_BAD_REQUEST)
            
            # Update request
            delivery_request.delivery_manager = delivery_manager
            delivery_request.status = 'in_operation'
            delivery_request.assigned_at = timezone.now()
            delivery_request.assigned_by = request.user  # Record who assigned the manager
            if notes:
                delivery_request.delivery_notes = notes
                
            # Save the delivery request
            delivery_request.save()
            
            # Update delivery manager status to busy
            delivery_manager.delivery_status = 'busy'
            delivery_manager.save()
            
            # Return updated request
            response_serializer = DeliveryRequestDetailSerializer(delivery_request)
            return Response({
                'success': True,
                'message': f'Request assigned to {delivery_manager.get_full_name()}',
                'data': response_serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error assigning delivery manager: {str(e)}")
            return Response({
                'error': 'An error occurred while processing your request'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class OrderListView(generics.ListAPIView):
    serializer_class = OrderListSerializer
    permission_classes = [permissions.IsAuthenticated, IsDeliveryAdminOrLibraryAdmin]
    
    def get_queryset(self):
        queryset = Order.objects.select_related('customer', 'payment').prefetch_related('items__book')
        
        # Filter by status
        status_filter = self.request.query_params.get('status')
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        
        # Filter by customer
        customer_id = self.request.query_params.get('customer_id')
        if customer_id:
            queryset = queryset.filter(customer_id=customer_id)
        
        # Filter by date range
        start_date = self.request.query_params.get('start_date')
        end_date = self.request.query_params.get('end_date')
        if start_date:
            queryset = queryset.filter(created_at__date__gte=start_date)
        if end_date:
            queryset = queryset.filter(created_at__date__lte=end_date)
        
        # Search by order number or customer name
        search = self.request.query_params.get('search')
        if search:
            queryset = queryset.filter(
                Q(order_number__icontains=search) |
                Q(customer__first_name__icontains=search) |
                Q(customer__last_name__icontains=search) |
                Q(customer__email__icontains=search)
            )
        
        return queryset.order_by('-created_at')
    
    def list(self, request, *args, **kwargs):
        """
        Override the default list method to ensure consistent response format.
        """
        queryset = self.get_queryset()
        
        # Apply pagination
        page = self.paginate_queryset(queryset)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)
        
        # If no pagination, return the data directly
        serializer = self.get_serializer(queryset, many=True)
        return Response({
            'results': serializer.data,
            'count': queryset.count(),
            'totalItems': queryset.count(),
        })


class OrderDetailView(generics.RetrieveAPIView):
    serializer_class = OrderDetailSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        return Order.objects.select_related('customer', 'payment').prefetch_related('items__book')
    
    def get_object(self):
        order = super().get_object()
        user = self.request.user
        
        # Check permissions
        if not (user.is_delivery_admin() or user.is_library_admin() or order.customer == user):
            self.permission_denied(self.request, message="You don't have permission to view this order.")
        
        return order


class OrderCreateFromPaymentView(generics.CreateAPIView):
    """
    Create a new order from a completed payment.
    Accessible by authenticated users.
    """
    serializer_class = OrderCreateFromPaymentSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def perform_create(self, serializer):
        # The serializer already handles order creation from payment
        # We just need to ensure the user can only create orders for their own payments
        payment_id = self.request.data.get('payment_id')
        user = self.request.user
        
        # Additional validation can be done here if needed
        return serializer.save()


class OrderStatusUpdateView(APIView):
    """
    Update order status.
    Accessible by delivery admins and system admins.
    """
    permission_classes = [permissions.IsAuthenticated, IsDeliveryAdminOrLibraryAdmin]
    
    def patch(self, request, pk):
        order = get_object_or_404(Order, pk=pk)
        user = request.user
        
        # Library admins can only view, not update
        if user.is_library_admin() and not user.is_staff:
            return Response({
                'error': "Library administrators cannot update order status."
            }, status=status.HTTP_403_FORBIDDEN)
        
        serializer = OrderStatusUpdateSerializer(data=request.data, context={'order': order})
        
        if serializer.is_valid():
            new_status = serializer.validated_data['status']
            notes = serializer.validated_data.get('notes', '')
            
            # Update order status
            old_status = order.status
            order.status = new_status
            
            # Set timestamps based on status
            if new_status == 'confirmed' and not order.confirmed_at:
                order.confirmed_at = timezone.now()
                # Update book quantities when order is confirmed
                order.update_book_quantities()
            elif new_status == 'delivered' and not order.delivered_at:
                order.delivered_at = timezone.now()
            elif new_status == 'cancelled':
                # Restore book quantities when order is cancelled
                order.restore_book_quantities()
            
            order.save()
            
            # Create notifications for status changes
            if new_status == 'confirmed':
                # Create notification for order accepted
                NotificationService.notify_order_accepted(order.id)
            elif new_status == 'delivered':
                # Create notification for order delivered
                NotificationService.notify_order_delivered(order.id)
            
            # Log status change
            logger.info(f"Order #{order.order_number} status changed from {old_status} to {new_status} by {user.email}")
            
            response_serializer = OrderDetailSerializer(order)
            return Response({
                'message': f'Order status updated from {old_status} to {new_status}' ,
                'order': response_serializer.data
            }, status=status.HTTP_200_OK)
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class OrdersReadyForDeliveryView(generics.ListAPIView):
    """
    List orders that are ready for delivery assignment.
    Accessible by delivery admins and system admins.
    """
    serializer_class = OrderListSerializer
    permission_classes = [permissions.IsAuthenticated, IsDeliveryAdminOrLibraryAdmin]
    
    def get_queryset(self):
        # Get orders in 'ready_for_delivery' or 'pending' status without delivery assignments
        # Including 'pending' for testing purposes
        queryset = Order.objects.filter(
            status__in=['pending']
        ).select_related('customer', 'payment').prefetch_related('items__book')
        
        # Exclude orders that already have delivery assignments
        queryset = queryset.exclude(
            id__in=DeliveryAssignment.objects.values_list('order_id', flat=True)
        )
        
        # Filter by date range
        start_date = self.request.query_params.get('start_date')
        end_date = self.request.query_params.get('end_date')
        if start_date:
            queryset = queryset.filter(created_at__date__gte=start_date)
        if end_date:
            queryset = queryset.filter(created_at__date__lte=end_date)
        
        return queryset.order_by('-created_at')


class DeliveryAssignmentListView(generics.ListAPIView):
    """
    List all delivery assignments.
    Accessible by delivery admins and system admins.
    """
    serializer_class = DeliveryAssignmentBasicSerializer
    permission_classes = [permissions.IsAuthenticated, IsDeliveryAdminOrLibraryAdmin]
    
    def get_queryset(self):
        queryset = DeliveryAssignment.objects.select_related('order', 'delivery_manager')
        
        # Filter by status
        status_filter = self.request.query_params.get('status')
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        
        # Filter by delivery manager
        manager_id = self.request.query_params.get('manager_id')
        if manager_id:  
                queryset = queryset.filter(delivery_manager_id=manager_id)
        
        # Filter by date range
        start_date = self.request.query_params.get('start_date')
        end_date = self.request.query_params.get('end_date')
        if start_date:
            queryset = queryset.filter(assigned_at__date__gte=start_date)
        if end_date:
            queryset = queryset.filter(assigned_at__date__lte=end_date)
        
        return queryset.order_by('-assigned_at')


class DeliveryAssignmentDetailView(generics.RetrieveAPIView):
    """
    Retrieve delivery assignment details.
    Accessible by the assigned delivery manager, system admins, and library admins.
    """
    serializer_class = DeliveryAssignmentBasicSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        return DeliveryAssignment.objects.select_related('order', 'delivery_manager')
    
    def get_object(self):
        assignment = super().get_object()
        user = self.request.user
        
        # Check permissions
        if not (user.is_delivery_admin() or user.is_library_admin() or 
                assignment.delivery_manager == user or 
                assignment.order.customer == user):
            self.permission_denied(self.request, message="You don't have permission to view this assignment.")
        
        return assignment


class DeliveryAssignmentCreateView(generics.CreateAPIView):
    """
    Create a new delivery assignment.
    Accessible by system admins only.
    """
    serializer_class = DeliveryAssignmentBasicSerializer
    permission_classes = [permissions.IsAuthenticated, IsDeliveryAdminOrLibraryAdmin]
    
    def get_serializer_class(self):
        from ..serializers.delivery_serializers import DeliveryAssignmentCreateSerializer
        return DeliveryAssignmentCreateSerializer
    
    def perform_create(self, serializer):
        # The serializer already handles order status update
        assignment = serializer.save()
        
        # Create notification for delivery representative assignment
        try:
            NotificationService.notify_delivery_assigned(
                order_id=assignment.order.id,
                delivery_rep_name=f"{assignment.delivery_manager.first_name} {assignment.delivery_manager.last_name}",
                delivery_rep_phone=assignment.contact_phone
            )
        except Exception as e:
            logger.error(f"Failed to create notification for delivery assignment: {str(e)}")
            
        return assignment


class DeliveryAssignmentStatusUpdateView(APIView):
    """
    Update delivery assignment status.
    Accessible by the assigned delivery manager and system admins.
    """
    permission_classes = [permissions.IsAuthenticated, IsDeliveryAdminOrLibraryAdmin]
    
    def patch(self, request, pk):
        assignment = get_object_or_404(DeliveryAssignment, pk=pk)
        user = request.user
        
        # Check permissions
        if not (user.is_staff or assignment.delivery_manager == user):
            return Response({
                'error': "Only the assigned delivery manager or system admin can update this assignment's status."
            }, status=status.HTTP_403_FORBIDDEN)
        
        from ..serializers.delivery_serializers import DeliveryAssignmentStatusUpdateSerializer
        serializer = DeliveryAssignmentStatusUpdateSerializer(data=request.data, context={'assignment': assignment})
        
        if serializer.is_valid():
            new_status = serializer.validated_data['status']
            notes = serializer.validated_data.get('notes', '')
            failure_reason = serializer.validated_data.get('failure_reason', '')
            estimated_delivery_time = serializer.validated_data.get('estimated_delivery_time')
            
            # Update assignment status
            old_status = assignment.status
            assignment.status = new_status
            
            # Check if estimated delivery time was updated
            delivery_time_updated = False
            if estimated_delivery_time and (not assignment.estimated_delivery_time or 
                                           estimated_delivery_time != assignment.estimated_delivery_time):
                assignment.estimated_delivery_time = estimated_delivery_time
                delivery_time_updated = True
                
            # If contact_phone is not set, automatically use the delivery manager's phone from profile
            if not assignment.contact_phone and assignment.delivery_manager:
                try:
                    if hasattr(assignment.delivery_manager, 'profile') and assignment.delivery_manager.profile.phone_number:
                        assignment.contact_phone = assignment.delivery_manager.profile.phone_number
                except Exception as e:
                    logger.error(f"Failed to get delivery manager's phone number: {str(e)}")
            
            # Set timestamps based on status
            if new_status == 'accepted' and not assignment.accepted_at:
                assignment.accepted_at = timezone.now()
            elif new_status == 'picked_up' and not assignment.picked_up_at:
                assignment.picked_up_at = timezone.now()
            elif new_status == 'delivered' and not assignment.delivered_at:
                assignment.delivered_at = timezone.now()
                assignment.actual_delivery_time = timezone.now()
            
            # Set failure reason if status is failed
            if new_status == 'failed' and failure_reason:
                assignment.failure_reason = failure_reason
                
                # Increment retry count if failed
                assignment.retry_count += 1
            
            assignment.save()
            
            # Create status history entry
            DeliveryStatusHistory.objects.create(
                assignment=assignment,
                previous_status=old_status,
                new_status=new_status,
                updated_by=user,
                notes=notes
            )
            
            # Send notification if delivery time was updated
            if delivery_time_updated:
                try:
                    NotificationService.notify_delivery_time_updated(
                        order_id=assignment.order.id,
                        estimated_delivery_time=assignment.estimated_delivery_time
                    )
                except Exception as e:
                    logger.error(f"Failed to create notification for delivery time update: {str(e)}")
            
            # Update order status if delivered
            if new_status == 'delivered':
                order = assignment.order
                order.status = 'delivered'
                order.delivered_at = timezone.now()
                order.save()
                
                # Create notification for order delivered
                try:
                    NotificationService.notify_order_delivered(order.id)
                except Exception as e:
                    logger.error(f"Failed to create notification for order delivery: {str(e)}")
            
            # Log status change
            logger.info(f"Delivery assignment #{assignment.id} status changed from {old_status} to {new_status} by {user.email}")
            
            from ..serializers.delivery_serializers import DeliveryAssignmentDetailSerializer
            response_serializer = DeliveryAssignmentDetailSerializer(assignment)
            return Response({
                'message': f'Assignment status updated from {old_status} to {new_status}',
                    'assignment': response_serializer.data
                }, status=status.HTTP_200_OK)
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class MyDeliveryAssignmentsView(generics.ListAPIView):
    """
    List current user's delivery assignments.
    Accessible by delivery admins only.
    """
    serializer_class = DeliveryAssignmentBasicSerializer
    permission_classes = [permissions.IsAuthenticated, IsDeliveryAdminOrLibraryAdmin]   
    
    def get_queryset(self):
        user = self.request.user
        
        if not user.is_delivery_admin():
            return DeliveryAssignment.objects.none()
        
        queryset = DeliveryAssignment.objects.filter(
            delivery_manager=user
        ).select_related('order__customer')
        
        # Filter by status
        status_filter = self.request.query_params.get('status')
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        
        return queryset.order_by('-assigned_at')


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated, IsDeliveryAdminOrLibraryAdmin])
def available_delivery_managers_view(request):
    """
    Get a list of available delivery managers.
    Accessible by delivery admins, library admins, and system admins.
    """
    # Stats functionality removed
    try:
        # Get all active delivery managers (basic info only)
        delivery_managers = User.objects.filter(
            is_active=True,
            user_type='delivery_admin'
        ).order_by('first_name', 'last_name')
        
        # Serialize the data with minimal information
        from ..serializers.user_serializers import UserBasicInfoSerializer
        serializer = UserBasicInfoSerializer(delivery_managers, many=True)
        
        # Add placeholder assignment counts
        response_data = []
        for manager_data in serializer.data:
            manager_data_dict = dict(manager_data)
            manager_data_dict['active_assignments'] = 0
            manager_data_dict['message'] = 'Statistics functionality has been removed'
            response_data.append(manager_data_dict)
        
        return Response({
            'delivery_managers': response_data
        }, status=status.HTTP_200_OK)
    
    except Exception as e:
        logger.error(f"Error in available_delivery_managers_view: {str(e)}")
        return Response({
            'error': 'An error occurred while processing your request'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)



@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated, IsDeliveryAdminOrLibraryAdmin])
def delivery_dashboard_view(request):
    """
    Get delivery dashboard statistics.
    Accessible by delivery admins, library admins, and system admins.
    """
    # Stats functionality removed
    return Response({
        'date_range': {
            'start_date': request.query_params.get('start_date', ''),
            'end_date': request.query_params.get('end_date', '')
        },
        'message': 'Delivery dashboard statistics functionality has been removed',
        'orders': {
            'total': 0,
            'by_status': {}
        },
        'delivery_assignments': {
            'total': 0, 
            'by_status': {},
            'avg_delivery_time_minutes': 0
        },
        'delivery_requests': {
            'total': 0,
            'by_status': {}
        },
        'top_delivery_managers': []
    }, status=status.HTTP_200_OK)



@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated, IsDeliveryAdminOrLibraryAdmin])
def bulk_assign_orders_view(request):
    """
    Bulk assign orders to delivery managers.
    Accessible by system admins only.
    """
    from django.db import transaction
    
    # Check if user is admin
    if not request.user.is_staff:
        return Response({
            'error': 'Only system administrators can perform bulk assignments'       
        }, status=status.HTTP_403_FORBIDDEN)
    
    # Validate input data
    order_ids = request.data.get('order_ids', [])
    delivery_manager_id = request.data.get('delivery_manager_id')
    delivery_notes = request.data.get('delivery_notes', '')
    estimated_delivery_time = request.data.get('estimated_delivery_time')
    
    if not order_ids:
        return Response({
            'error': 'No order IDs provided'
        }, status=status.HTTP_400_BAD_REQUEST)
    
    if not delivery_manager_id:
        return Response({
            'error': 'Delivery manager ID is required'
        }, status=status.HTTP_400_BAD_REQUEST)
    
    # Validate delivery manager
    try:
        delivery_manager = User.objects.get(id=delivery_manager_id)
        if not delivery_manager.is_delivery_admin():
            return Response({
                'error': 'Selected user is not a delivery administrator'
            }, status=status.HTTP_400_BAD_REQUEST)
    except User.DoesNotExist:
        return Response({
            'error': 'Delivery manager not found'
        }, status=status.HTTP_404_NOT_FOUND)
    
    # Get orders
    orders = Order.objects.filter(id__in=order_ids, status='ready_for_delivery')
    
    # Check if any orders already have assignments
    assigned_orders = orders.filter(delivery_assignment__isnull=False)
    if assigned_orders.exists():
        return Response({
            'error': f'{assigned_orders.count()} orders already have delivery assignments',
            'assigned_order_ids': list(assigned_orders.values_list('id', flat=True))
        }, status=status.HTTP_400_BAD_REQUEST)
    
    # Create assignments in a transaction
    created_assignments = []
    with transaction.atomic():
        for order in orders:
            # Get delivery manager's phone number from profile
            contact_phone = None
            try:
                if hasattr(delivery_manager, 'profile') and delivery_manager.profile.phone_number:
                    contact_phone = delivery_manager.profile.phone_number
            except Exception as e:
                logger.error(f"Failed to get delivery manager's phone number: {str(e)}")
                
            assignment = DeliveryAssignment.objects.create(
                order=order,
                delivery_manager=delivery_manager,
                delivery_notes=delivery_notes,
                estimated_delivery_time=estimated_delivery_time,
                contact_phone=contact_phone
            )
            created_assignments.append(assignment)
            
            # Update order status
            order.status = 'assigned_to_delivery'
            order.save()
    
    # Return response
    return Response({
        'message': f'Successfully assigned {len(created_assignments)} orders to {delivery_manager.get_full_name()}',
        'assigned_order_count': len(created_assignments),
        'assigned_order_ids': [order.id for order in orders]
    }, status=status.HTTP_201_CREATED)


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def customer_orders_view(request):
    """
    Get orders for the current customer.
    Accessible by customers only.
    """
    user = request.user
    
    if not user.is_customer():
        return Response({
            'error': 'Only customers can view their orders'
        }, status=status.HTTP_403_FORBIDDEN)
    
    orders = Order.objects.filter(customer=user).select_related('payment').prefetch_related('items__book')
    
    # Filter by status if provided
    status_filter = request.query_params.get('status')
    if status_filter:
        orders = orders.filter(status=status_filter)
    
    orders = orders.order_by('-created_at')
    
    # Pagination
    page_size = int(request.query_params.get('page_size', 10))
    page_number = int(request.query_params.get('page', 1))
    
    paginator = Paginator(orders, page_size)
    page = paginator.get_page(page_number)
    
    serializer = OrderListSerializer(page.object_list, many=True)
    
    return Response({
        'orders': serializer.data,
        'pagination': {
            'page': page_number,
            'page_size': page_size,
            'total_pages': paginator.num_pages,
            'total_count': paginator.count,
            'has_next': page.has_next(),
            'has_previous': page.has_previous()
        }
    }, status=status.HTTP_200_OK)


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def order_tracking_view(request, order_number):
    """
    Track order status by order number.
    Accessible by order owner and delivery/library admins.
    """
    try:
        order = Order.objects.select_related('customer', 'payment').get(order_number=order_number)
    except Order.DoesNotExist:
        return Response({
            'error': 'Order not found'
        }, status=status.HTTP_404_NOT_FOUND)
    
    user = request.user
    
    # Check permissions
    if not (user.is_delivery_admin() or user.is_library_admin() or order.customer == user):
        return Response({
            'error': "You don't have permission to track this order"
        }, status=status.HTTP_403_FORBIDDEN)
    
    serializer = OrderDetailSerializer(order)
    return Response(serializer.data, status=status.HTTP_200_OK) 


class DeliveryManagerLocationView(APIView):
    """
    Manage delivery manager's location.
    Accessible by delivery managers to update their location.
    Accessible by admins and customers to view delivery manager location.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request, delivery_manager_id=None):
        """
        Get delivery manager's location.
        If delivery_manager_id is provided, get that manager's location.
        Otherwise, get current user's location (if they are a delivery manager).
        """
        try:
            # If delivery_manager_id is provided, get that manager's location
            if delivery_manager_id:
                delivery_manager = get_object_or_404(User, id=delivery_manager_id)
                
                # Check permissions - only admins, customers with orders from this manager, or the manager themselves can view
                user = request.user
                if not (user.is_library_admin() or user.is_staff or 
                       delivery_manager == user or
                       self._user_has_orders_from_manager(user, delivery_manager)):
                    return Response({
                        'error': "You don't have permission to view this delivery manager's location"
                    }, status=status.HTTP_403_FORBIDDEN)
            else:
                # Get current user's location (must be delivery manager)
                delivery_manager = request.user
                if not delivery_manager.is_delivery_admin():
                    return Response({
                        'error': "Only delivery managers can manage their location"
                    }, status=status.HTTP_403_FORBIDDEN)
            
            # Return location data
            location_data = delivery_manager.get_location_dict()
            
            return Response({
                'success': True,
                'delivery_manager': {
                    'id': delivery_manager.id,
                    'name': delivery_manager.get_full_name(),
                    'email': delivery_manager.email
                },
                'location': location_data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error getting delivery manager location: {str(e)}")
            return Response({
                'error': 'An error occurred while retrieving location'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def post(self, request):
        """
        Update delivery manager's location.
        Only accessible by delivery managers.
        """
        try:
            user = request.user
            
            # Check if user is a delivery manager
            if not user.is_delivery_admin():
                return Response({
                    'error': "Only delivery managers can update their location"
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Get location data from request
            latitude = request.data.get('latitude')
            longitude = request.data.get('longitude')
            address = request.data.get('address', '')
            
            # Validate coordinates if provided
            if latitude is not None:
                try:
                    latitude = float(latitude)
                    if not (-90 <= latitude <= 90):
                        return Response({
                            'error': 'Latitude must be between -90 and 90'
                        }, status=status.HTTP_400_BAD_REQUEST)
                except (ValueError, TypeError):
                    return Response({
                        'error': 'Invalid latitude value'
                    }, status=status.HTTP_400_BAD_REQUEST)
            
            if longitude is not None:
                try:
                    longitude = float(longitude)
                    if not (-180 <= longitude <= 180):
                        return Response({
                            'error': 'Longitude must be between -180 and 180'
                        }, status=status.HTTP_400_BAD_REQUEST)
                except (ValueError, TypeError):
                    return Response({
                        'error': 'Invalid longitude value'
                    }, status=status.HTTP_400_BAD_REQUEST)
            
            # Update location
            user.update_location(
                latitude=latitude,
                longitude=longitude,
                address=address
            )
            
            # Return updated location data
            location_data = user.get_location_dict()
            
            return Response({
                'success': True,
                'message': 'Location updated successfully',
                'location': location_data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error updating delivery manager location: {str(e)}")
            return Response({
                'error': 'An error occurred while updating location'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def _user_has_orders_from_manager(self, user, delivery_manager):
        """Check if user has orders assigned to the delivery manager."""
        if not user.is_customer():
            return False
        
        # Check if user has any orders assigned to this delivery manager
        from ..models import DeliveryAssignment
        return DeliveryAssignment.objects.filter(
            order__customer=user,
            delivery_manager=delivery_manager
        ).exists()


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def get_delivery_manager_location_view(request, delivery_manager_id):
    """
    Get a specific delivery manager's location.
    Accessible by admins and customers with orders from this manager.
    """
    try:
        delivery_manager = get_object_or_404(User, id=delivery_manager_id)
        user = request.user
        
        # Check permissions
        if not (user.is_library_admin() or user.is_staff or 
               delivery_manager == user or
               DeliveryManagerLocationView()._user_has_orders_from_manager(user, delivery_manager)):
            return Response({
                'error': "You don't have permission to view this delivery manager's location"
            }, status=status.HTTP_403_FORBIDDEN)
        
        # Return location data
        location_data = delivery_manager.get_location_dict()
        
        return Response({
            'success': True,
            'delivery_manager': {
                'id': delivery_manager.id,
                'name': delivery_manager.get_full_name(),
                'email': delivery_manager.email
            },
            'location': location_data
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"Error getting delivery manager location: {str(e)}")
        return Response({
            'error': 'An error occurred while retrieving location'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def order_delivery_contact_view(request, order_id):
    """
    Get delivery representative contact information for an order.
    Accessible only by the customer who placed the order.
    """
    try:
        # Get the order with its delivery assignment
        order = Order.objects.get(id=order_id)
        
        # Check if user is the order owner
        if order.customer != request.user:
            return Response({
                'error': "You don't have permission to access this order's delivery information"
            }, status=status.HTTP_403_FORBIDDEN)
        
        # Check if order has a delivery assignment
        if not hasattr(order, 'delivery_assignment'):
            return Response({
                'error': "This order doesn't have a delivery assignment yet"
            }, status=status.HTTP_404_NOT_FOUND)
        
        assignment = order.delivery_assignment
        
        # Get delivery manager location
        delivery_manager = assignment.delivery_manager
        location_data = delivery_manager.get_location_dict()
        
        # Return delivery representative contact information with location
        return Response({
            'success': True,
            'delivery_rep': {
                'name': f"{assignment.delivery_manager.first_name} {assignment.delivery_manager.last_name}",
                'contact_phone': assignment.contact_phone or "Not provided",
                'estimated_delivery_time': assignment.estimated_delivery_time,
                'status': assignment.get_status_display(),
                'location': location_data
            }
        }, status=status.HTTP_200_OK)
        
    except Order.DoesNotExist:
        return Response({
            'error': 'Order not found'   
        }, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        logger.error(f"Error getting delivery contact: {str(e)}")
        return Response({
            'error': 'An error occurred while processing your request'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class DeliveryManagerStatusUpdateView(APIView):
    """
    Update delivery manager's status (online/offline).
    Accessible by delivery managers only.
    """
    permission_classes = [permissions.IsAuthenticated, IsDeliveryAdmin]
    
    def post(self, request):
        try:
            # Validate that the user is a delivery manager
            user = request.user
            if not user.is_delivery_admin():
                return Response({
                    'error': 'Only delivery managers can update their status'
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Get the new status from request data
            new_status = request.data.get('status')
            if new_status not in ['online', 'offline', 'busy']:
                return Response({
                    'error': 'Invalid status. Must be "online", "offline", or "busy".'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Check if the delivery manager is currently busy
            if user.delivery_status == 'busy' and new_status == 'offline':
                # Check if they have any active deliveries
                active_requests = DeliveryRequest.objects.filter(
                    delivery_manager=user, 
                    status='in_operation'
                ).exists()
                
                if active_requests:
                    return Response({
                        'error': 'Cannot go offline while you have active deliveries'
                    }, status=status.HTTP_400_BAD_REQUEST)
            
            # Update the status
            user.delivery_status = new_status
            user.save()
            
            return Response({
                'success': True,
                'message': f'Status updated to {new_status}',
                'current_status': new_status
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error updating delivery manager status: {str(e)}")
            return Response({
                'error': 'An error occurred while processing your request'   
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# ==================== LOCATION TRACKING VIEWS ====================

class RealTimeTrackingView(APIView):
    """
    Manage real-time location tracking for delivery managers.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        """
        Get real-time tracking status for the current user.
        """
        try:
            user = request.user
            
            if not user.is_delivery_admin():
                return Response({
                    'error': 'Only delivery managers can access tracking status'
                }, status=status.HTTP_403_FORBIDDEN)
            
            from ..models.delivery_model import RealTimeTracking
            from ..serializers.delivery_serializers import RealTimeTrackingSerializer
            
            try:
                tracking = RealTimeTracking.objects.get(delivery_manager=user)
                serializer = RealTimeTrackingSerializer(tracking)
                return Response(serializer.data, status=status.HTTP_200_OK)
            except RealTimeTracking.DoesNotExist:
                return Response({
                    'error': 'No tracking settings found. Please enable tracking first.'
                }, status=status.HTTP_404_NOT_FOUND)
                
        except Exception as e:
            logger.error(f"Error getting tracking status: {str(e)}")
            return Response({
                'error': 'An error occurred while retrieving tracking status'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def post(self, request):
        """
        Start real-time tracking.
        """
        try:
            user = request.user
            
            if not user.is_delivery_admin():
                return Response({
                    'error': 'Only delivery managers can start tracking'
                }, status=status.HTTP_403_FORBIDDEN)
            
            interval_seconds = request.data.get('interval_seconds', 30)
            
            from ..services.delivery_services import LocationTrackingService
            result = LocationTrackingService.start_real_time_tracking(user, interval_seconds)
            
            if result['success']:
                return Response(result, status=status.HTTP_200_OK)
            else:
                return Response(result, status=status.HTTP_400_BAD_REQUEST)
                
        except Exception as e:
            logger.error(f"Error starting tracking: {str(e)}")
            return Response({
                'error': 'An error occurred while starting tracking'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def delete(self, request):
        """
        Stop real-time tracking.
        """
        try:
            user = request.user
            
            if not user.is_delivery_admin():
                return Response({
                    'error': 'Only delivery managers can stop tracking'
                }, status=status.HTTP_403_FORBIDDEN)
            
            from ..services.delivery_services import LocationTrackingService
            result = LocationTrackingService.stop_real_time_tracking(user)
            
            if result['success']:
                return Response(result, status=status.HTTP_200_OK)
            else:
                return Response(result, status=status.HTTP_400_BAD_REQUEST)
                
        except Exception as e:
            logger.error(f"Error stopping tracking: {str(e)}")
            return Response({
                'error': 'An error occurred while stopping tracking'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class LocationTrackingUpdateView(APIView):
    """
    Update location with real-time tracking data.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        """
        Update location with tracking metadata.
        """
        try:
            user = request.user
            
            if not user.is_delivery_admin():
                return Response({
                    'error': 'Only delivery managers can update tracking location'
                }, status=status.HTTP_403_FORBIDDEN)
            
            from ..serializers.delivery_serializers import LocationTrackingUpdateSerializer
            from ..services.delivery_services import LocationTrackingService
            
            serializer = LocationTrackingUpdateSerializer(data=request.data)
            if not serializer.is_valid():
                return Response({
                    'error': 'Invalid data provided',
                    'details': serializer.errors
                }, status=status.HTTP_400_BAD_REQUEST)
            
            data = serializer.validated_data
            result = LocationTrackingService.update_location_with_tracking(
                delivery_manager=user,
                latitude=data['latitude'],
                longitude=data['longitude'],
                address=data.get('address'),
                tracking_type=data.get('tracking_type', 'gps'),
                accuracy=data.get('accuracy'),
                speed=data.get('speed'),
                heading=data.get('heading'),
                battery_level=data.get('battery_level'),
                network_type=data.get('network_type'),
                delivery_assignment_id=data.get('delivery_assignment_id')
            )
            
            if result['success']:
                return Response(result, status=status.HTTP_200_OK)
            else:
                return Response(result, status=status.HTTP_400_BAD_REQUEST)
                
        except Exception as e:
            logger.error(f"Error updating tracking location: {str(e)}")
            return Response({
                'error': 'An error occurred while updating location'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class LocationHistoryView(APIView):
    """
    Get location history for delivery managers.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        """
        Get location history for the current user or specified delivery manager.
        """
        try:
            user = request.user
            delivery_manager_id = request.query_params.get('delivery_manager_id')
            hours = int(request.query_params.get('hours', 24))
            
            # Determine which delivery manager to get history for
            if delivery_manager_id:
                # Admin or customer requesting specific manager's history
                if not (user.is_library_admin() or user.is_staff):
                    return Response({
                        'error': 'Only admins can view other delivery managers\' history'
                    }, status=status.HTTP_403_FORBIDDEN)
                
                from ..models import User
                try:
                    delivery_manager = User.objects.get(id=delivery_manager_id, user_type='delivery_admin')
                except User.DoesNotExist:
                    return Response({
                        'error': 'Delivery manager not found'
                    }, status=status.HTTP_404_NOT_FOUND)
            else:
                # Current user's history
                if not user.is_delivery_admin():
                    return Response({
                        'error': 'Only delivery managers can view location history'
                    }, status=status.HTTP_403_FORBIDDEN)
                delivery_manager = user
            
            from ..services.delivery_services import LocationTrackingService
            result = LocationTrackingService.get_location_history(delivery_manager, hours)
            
            if result['success']:
                return Response(result, status=status.HTTP_200_OK)
            else:
                return Response(result, status=status.HTTP_400_BAD_REQUEST)
                
        except Exception as e:
            logger.error(f"Error getting location history: {str(e)}")
            return Response({
                'error': 'An error occurred while retrieving location history'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class MovementSummaryView(APIView):
    """
    Get movement summary for delivery managers.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        """
        Get movement summary for the current user or specified delivery manager.
        """
        try:
            user = request.user
            delivery_manager_id = request.query_params.get('delivery_manager_id')
            hours = int(request.query_params.get('hours', 24))
            
            # Determine which delivery manager to get summary for
            if delivery_manager_id:
                # Admin requesting specific manager's summary
                if not (user.is_library_admin() or user.is_staff):
                    return Response({
                        'error': 'Only admins can view other delivery managers\' movement summary'
                    }, status=status.HTTP_403_FORBIDDEN)
                
                from ..models import User
                try:
                    delivery_manager = User.objects.get(id=delivery_manager_id, user_type='delivery_admin')
                except User.DoesNotExist:
                    return Response({
                        'error': 'Delivery manager not found'
                    }, status=status.HTTP_404_NOT_FOUND)
            else:
                # Current user's summary
                if not user.is_delivery_admin():
                    return Response({
                        'error': 'Only delivery managers can view movement summary'
                    }, status=status.HTTP_403_FORBIDDEN)
                delivery_manager = user
            
            from ..services.delivery_services import LocationTrackingService
            result = LocationTrackingService.get_movement_summary(delivery_manager, hours)
            
            if result['success']:
                return Response(result, status=status.HTTP_200_OK)
            else:
                return Response(result, status=status.HTTP_400_BAD_REQUEST)
                
        except Exception as e:
            logger.error(f"Error getting movement summary: {str(e)}")
            return Response({
                'error': 'An error occurred while retrieving movement summary'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class AllTrackingManagersView(APIView):
    """
    Get all delivery managers with their tracking status (Admin only).
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        """
        Get all delivery managers with tracking enabled.
        """
        try:
            user = request.user
            
            if not (user.is_library_admin() or user.is_staff):
                return Response({
                    'error': 'Only library admins can view all tracking managers'
                }, status=status.HTTP_403_FORBIDDEN)
            
            from ..services.delivery_services import LocationTrackingService
            result = LocationTrackingService.get_all_tracking_managers()
            
            if result['success']:
                return Response(result, status=status.HTTP_200_OK)
            else:
                return Response(result, status=status.HTTP_400_BAD_REQUEST)
                
        except Exception as e:
            logger.error(f"Error getting tracking managers: {str(e)}")
            return Response({
                'error': 'An error occurred while retrieving tracking managers'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class RealTimeTrackingSettingsView(APIView):
    """
    Manage real-time tracking settings.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        """
        Get tracking settings for the current user.
        """
        try:
            user = request.user
            
            if not user.is_delivery_admin():
                return Response({
                    'error': 'Only delivery managers can access tracking settings'
                }, status=status.HTTP_403_FORBIDDEN)
            
            from ..models.delivery_model import RealTimeTracking
            from ..serializers.delivery_serializers import RealTimeTrackingSerializer
            
            tracking, created = RealTimeTracking.objects.get_or_create(
                delivery_manager=user,
                defaults={
                    'is_tracking_enabled': False,
                    'tracking_interval': 30,
                }
            )
            
            serializer = RealTimeTrackingSerializer(tracking)
            return Response(serializer.data, status=status.HTTP_200_OK)
                
        except Exception as e:
            logger.error(f"Error getting tracking settings: {str(e)}")
            return Response({
                'error': 'An error occurred while retrieving tracking settings'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def put(self, request):
        """
        Update tracking settings for the current user.
        """
        try:
            user = request.user
            
            if not user.is_delivery_admin():
                return Response({
                    'error': 'Only delivery managers can update tracking settings'
                }, status=status.HTTP_403_FORBIDDEN)
            
            from ..models.delivery_model import RealTimeTracking
            from ..serializers.delivery_serializers import RealTimeTrackingUpdateSerializer
            
            tracking, created = RealTimeTracking.objects.get_or_create(
                delivery_manager=user,
                defaults={
                    'is_tracking_enabled': False,
                    'tracking_interval': 30,
                }
            )
            
            serializer = RealTimeTrackingUpdateSerializer(tracking, data=request.data, partial=True)
            if not serializer.is_valid():
                return Response({
                    'error': 'Invalid data provided',
                    'details': serializer.errors
                }, status=status.HTTP_400_BAD_REQUEST)
            
            serializer.save()
            
            return Response({
                'success': True,
                'message': 'Tracking settings updated successfully',
                'settings': serializer.data
            }, status=status.HTTP_200_OK)
                
        except Exception as e:
            logger.error(f"Error updating tracking settings: {str(e)}")
            return Response({
                'error': 'An error occurred while updating tracking settings'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class DeliveryNotificationsView(APIView):
    """
    Delivery-specific notifications endpoint that proxies to the main notifications API.
    This provides a consistent API for delivery managers to access their notifications.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        """
        Get notifications for the current delivery manager.
        """
        try:
            user = request.user
            
            # Check if user is a delivery manager
            if not user.is_delivery_admin():
                return Response({
                    'error': 'Only delivery managers can access delivery notifications'
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Get query parameters for filtering
            is_read = request.query_params.get('is_read')
            notification_type = request.query_params.get('notification_type')
            limit = request.query_params.get('limit')
            offset = request.query_params.get('offset')
            
            # Convert string parameters to appropriate types
            if is_read is not None:
                is_read = is_read.lower() == 'true'
            
            # Get notifications using the NotificationService
            from ..services.notification_services import NotificationService
            
            notifications = NotificationService.get_user_notifications(
                user_id=user.id,
                is_read=is_read,
                notification_type=notification_type
            )
            
            # Apply pagination if requested
            if limit or offset:
                limit = int(limit) if limit else 20
                offset = int(offset) if offset else 0
                notifications = notifications[offset:offset + limit]
            
            # Serialize notifications
            from ..serializers.notification_serializers import NotificationSerializer
            serializer = NotificationSerializer(notifications, many=True)
            
            return Response({
                'success': True,
                'notifications': serializer.data,
                'count': len(serializer.data)
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error fetching delivery notifications: {str(e)}")
            return Response({
                'error': 'An error occurred while fetching notifications'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def post(self, request):
        """
        Mark notification as read.
        """
        try:
            user = request.user
            
            if not user.is_delivery_admin():
                return Response({
                    'error': 'Only delivery managers can access delivery notifications'
                }, status=status.HTTP_403_FORBIDDEN)
            
            notification_id = request.data.get('notification_id')
            if not notification_id:
                return Response({
                    'error': 'notification_id is required'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            from ..services.notification_services import NotificationService
            
            try:
                notification = NotificationService.mark_notification_as_read(notification_id)
                from ..serializers.notification_serializers import NotificationSerializer
                serializer = NotificationSerializer(notification)
                
                return Response({
                    'success': True,
                    'notification': serializer.data
                }, status=status.HTTP_200_OK)
                
            except ValueError as e:
                return Response({
                    'error': str(e)
                }, status=status.HTTP_404_NOT_FOUND)
                
        except Exception as e:
            logger.error(f"Error marking notification as read: {str(e)}")
            return Response({
                'error': 'An error occurred while updating notification'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


 
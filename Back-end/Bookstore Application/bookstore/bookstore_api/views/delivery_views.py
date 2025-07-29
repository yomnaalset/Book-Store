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

from ..models import User, DeliveryRequest, Order, DeliveryAssignment, DeliveryStatusHistory
from ..serializers.delivery_serializers import (
    OrderListSerializer, OrderDetailSerializer, OrderStatusUpdateSerializer,
    DeliveryRequestCreateSerializer,
    DeliveryRequestListSerializer,
    DeliveryRequestDetailSerializer,
    DeliveryRequestAssignSerializer,
    DeliveryRequestStatusUpdateSerializer,
    DeliveryAssignmentBasicSerializer,
    OrderCreateFromPaymentSerializer,
)   

from ..permissions import IsLibraryAdminReadOnly, IsDeliveryAdmin, IsDeliveryAdminOrLibraryAdmin    

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
        if not user.is_delivery_admin() or delivery_request.delivery_manager != user:
            return Response({
                'error': "Only the assigned delivery manager can update this request's status."
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
    List all delivery requests for library admins (read-only).
    """
    serializer_class = DeliveryRequestListSerializer
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdminReadOnly]
    
    def get_queryset(self):
        queryset = DeliveryRequest.objects.all()
        
        # Filter by status
        status_filter = self.request.query_params.get('status')
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        
        # Filter by customer
        customer_id = self.request.query_params.get('customer_id')
        if customer_id:
            queryset = queryset.filter(customer_id=customer_id)
        
        return queryset.order_by('-created_at') 


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
            elif new_status == 'delivered' and not order.delivered_at:
                order.delivered_at = timezone.now()
            
            order.save()
            
            # Log status change
            logger.info(f"Order #{order.order_number} status changed from {old_status} to {new_status} by {user.email}")
            
            response_serializer = OrderDetailSerializer(order)
            return Response({
                'message': f'Order status updated from {old_status} to {new_status}',
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
        # Get orders in 'ready_for_delivery' status without delivery assignments
        queryset = Order.objects.filter(
            status='ready_for_delivery'
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
    permission_classes = [permissions.IsAuthenticated, permissions.IsAdminUser]
    
    def get_serializer_class(self):
        from ..serializers.delivery_serializers import DeliveryAssignmentCreateSerializer
        return DeliveryAssignmentCreateSerializer
    
    def perform_create(self, serializer):
        # The serializer already handles order status update
        return serializer.save()


class DeliveryAssignmentStatusUpdateView(APIView):
    """
    Update delivery assignment status.
    Accessible by the assigned delivery manager and system admins.
    """
    permission_classes = [permissions.IsAuthenticated]
    
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
            
            # Update assignment status
            old_status = assignment.status
            assignment.status = new_status
            
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
            
            # Update order status if delivered
            if new_status == 'delivered':
                order = assignment.order
                order.status = 'delivered'
                order.delivered_at = timezone.now()
                order.save()
            
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
    permission_classes = [permissions.IsAuthenticated, IsDeliveryAdmin]
    
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
@permission_classes([permissions.IsAuthenticated, IsDeliveryAdmin])
def available_delivery_managers_view(request):
    """
    Get a list of available delivery managers.
    Accessible by delivery admins and system admins.
    """
    # Get all active delivery managers
    delivery_managers = User.objects.filter(
        is_active=True,
        role='delivery_admin'
    ).order_by('first_name', 'last_name')
    
    # Get delivery managers with their current assignment count
    from django.db.models import Count
    managers_with_counts = delivery_managers.annotate(
        active_assignments=Count(
            'delivery_assignments',
            filter=Q(
                delivery_assignments__status__in=[
                    'assigned', 'accepted', 'picked_up', 'in_transit'
                ]
            )
        )
    )
    
    # Serialize the data
    from ..serializers.user_serializers import UserBasicInfoSerializer
    serializer = UserBasicInfoSerializer(managers_with_counts, many=True)
    
    # Add assignment counts to response
    response_data = []
    for idx, manager in enumerate(serializer.data):
        manager_data = dict(manager)
        manager_data['active_assignments'] = managers_with_counts[idx].active_assignments
        response_data.append(manager_data)
    
    return Response({
        'delivery_managers': response_data
    }, status=status.HTTP_200_OK)


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated, IsDeliveryAdmin])
def delivery_manager_statistics_view(request, manager_id=None):
    """
    Get delivery statistics for a specific manager or all managers.
    Accessible by delivery admins and system admins.
    """
    from django.db.models import Count, Avg, F, ExpressionWrapper, FloatField, Q
    from datetime import timedelta
    
    # If manager_id is provided, get statistics for that manager
    # Otherwise, get statistics for the current user (if delivery admin)
    if manager_id:
        try:
            manager = User.objects.get(id=manager_id, role='delivery_admin')
        except User.DoesNotExist:
            return Response({
                'error': 'Delivery manager not found'
            }, status=status.HTTP_404_NOT_FOUND)
    else:
        manager = request.user
        if not manager.is_delivery_admin():
            return Response({
                'error': 'You must be a delivery administrator to view statistics'
            }, status=status.HTTP_403_FORBIDDEN)
    
    # Get all assignments for this manager
    assignments = DeliveryAssignment.objects.filter(delivery_manager=manager)
    
    # Filter by date range if provided
    start_date = request.query_params.get('start_date')
    end_date = request.query_params.get('end_date')
    if start_date:
        assignments = assignments.filter(assigned_at__date__gte=start_date)
    if end_date:
        assignments = assignments.filter(assigned_at__date__lte=end_date)
    
    # Calculate statistics
    total_assignments = assignments.count()
    completed_deliveries = assignments.filter(status='delivered').count()
    pending_assignments = assignments.filter(
        status__in=['assigned', 'accepted', 'picked_up', 'in_transit']
    ).count()
    failed_deliveries = assignments.filter(status='failed').count()
    
    # Calculate average delivery time (in minutes) for completed deliveries
    completed_assignments = assignments.filter(
        status='delivered',
        delivered_at__isnull=False,
        picked_up_at__isnull=False
    )
    
    avg_delivery_time = 0
    if completed_assignments.exists():
        # Calculate average time between pickup and delivery
        delivery_times = []
        for assignment in completed_assignments:
            if assignment.delivered_at and assignment.picked_up_at:
                delivery_time = (assignment.delivered_at - assignment.picked_up_at).total_seconds() / 60
                delivery_times.append(delivery_time)
        
        if delivery_times:
            avg_delivery_time = sum(delivery_times) / len(delivery_times)
    
    # Calculate success rate
    success_rate = 0
    if total_assignments > 0:
        success_rate = (completed_deliveries / total_assignments) * 100
    
    # Prepare response
    from ..serializers.delivery_serializers import DeliveryManagerStatsSerializer
    stats_data = {
        'total_assignments': total_assignments,
        'completed_deliveries': completed_deliveries,
        'pending_assignments': pending_assignments,
        'failed_deliveries': failed_deliveries,
        'average_delivery_time': round(avg_delivery_time, 2),
        'success_rate': round(success_rate, 2)
    }
    
    serializer = DeliveryManagerStatsSerializer(data=stats_data)
    serializer.is_valid()  # This will always be valid as we're constructing the data
    
    # Get recent assignments
    recent_assignments = assignments.order_by('-assigned_at')[:5]
    from ..serializers.delivery_serializers import DeliveryAssignmentBasicSerializer
    recent_serializer = DeliveryAssignmentBasicSerializer(recent_assignments, many=True)
    
    return Response({
        'manager': {
            'id': manager.id,
            'name': manager.get_full_name(),
            'email': manager.email
        },
        'statistics': serializer.data,
        'recent_assignments': recent_serializer.data
    }, status=status.HTTP_200_OK)


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated, IsDeliveryAdminOrLibraryAdmin])
def delivery_dashboard_view(request):
    """
    Get delivery dashboard statistics.
    Accessible by delivery admins, library admins, and system admins.
    """
    from django.db.models import Count, Sum, Avg, F, ExpressionWrapper, FloatField, Q
    from django.utils.timezone import now
    from datetime import timedelta
    
    # Get date range filters
    start_date = request.query_params.get('start_date')
    end_date = request.query_params.get('end_date')
    
    # Default to last 30 days if not provided
    if not start_date:
        start_date = (now() - timedelta(days=30)).date().isoformat()
    if not end_date:
        end_date = now().date().isoformat()
    
    # Get all orders in the date range
    orders = Order.objects.filter(
        created_at__date__gte=start_date,
        created_at__date__lte=end_date
    )
    
    # Get all delivery assignments in the date range
    assignments = DeliveryAssignment.objects.filter(
        assigned_at__date__gte=start_date,
        assigned_at__date__lte=end_date
    )
    
    # Get all delivery requests in the date range
    requests = DeliveryRequest.objects.filter(
        created_at__date__gte=start_date,
        created_at__date__lte=end_date
    )
    
    # Calculate order statistics
    total_orders = orders.count()
    orders_by_status = orders.values('status').annotate(count=Count('id'))
    order_status_counts = {item['status']: item['count'] for item in orders_by_status}
    
    # Calculate delivery assignment statistics
    total_assignments = assignments.count()
    assignments_by_status = assignments.values('status').annotate(count=Count('id'))
    assignment_status_counts = {item['status']: item['count'] for item in assignments_by_status}
    
    # Calculate delivery request statistics
    total_requests = requests.count()
    requests_by_status = requests.values('status').annotate(count=Count('id'))
    request_status_counts = {item['status']: item['count'] for item in requests_by_status}
    
    # Calculate average delivery times
    avg_delivery_time = 0
    completed_assignments = assignments.filter(
        status='delivered',
        delivered_at__isnull=False,
        picked_up_at__isnull=False
    )
    
    if completed_assignments.exists():
        # Calculate average time between pickup and delivery
        delivery_times = []
        for assignment in completed_assignments:
            if assignment.delivered_at and assignment.picked_up_at:
                delivery_time = (assignment.delivered_at - assignment.picked_up_at).total_seconds() / 60
                delivery_times.append(delivery_time)
        
        if delivery_times:
            avg_delivery_time = sum(delivery_times) / len(delivery_times)
    
    # Get top delivery managers
    top_managers = User.objects.filter(
        delivery_assignments__status='delivered',
        delivery_assignments__assigned_at__date__gte=start_date,
        delivery_assignments__assigned_at__date__lte=end_date
    ).annotate(
        completed_count=Count('delivery_assignments', filter=Q(delivery_assignments__status='delivered'))
    ).order_by('-completed_count')[:5]
    
    top_managers_data = []
    for manager in top_managers:
        top_managers_data.append({
            'id': manager.id,
            'name': manager.get_full_name(),
            'completed_deliveries': manager.completed_count
        })
    
    # Prepare response
    return Response({
        'date_range': {
            'start_date': start_date,
            'end_date': end_date
        },
        'orders': {
            'total': total_orders,
            'by_status': order_status_counts
        },
        'delivery_assignments': {
            'total': total_assignments,
            'by_status': assignment_status_counts,
            'avg_delivery_time_minutes': round(avg_delivery_time, 2)
        },
        'delivery_requests': {
            'total': total_requests,
            'by_status': request_status_counts
        },
        'top_delivery_managers': top_managers_data
    }, status=status.HTTP_200_OK)


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated, IsDeliveryAdminOrLibraryAdmin])
def order_statistics_view(request):
    """
    Get order statistics.
    Accessible by delivery admins, library admins, and system admins.
    """
    from django.db.models import Count, Sum, Avg, F, ExpressionWrapper, FloatField, Q
    from django.utils.timezone import now
    from datetime import timedelta
    
    # Get date range filters
    start_date = request.query_params.get('start_date')
    end_date = request.query_params.get('end_date')
    
    # Default to last 30 days if not provided
    if not start_date:
        start_date = (now() - timedelta(days=30)).date().isoformat()
    if not end_date:
        end_date = now().date().isoformat()
    
    # Get all orders in the date range
    orders = Order.objects.filter(
        created_at__date__gte=start_date,
        created_at__date__lte=end_date
    )
    
    # Calculate order statistics
    total_orders = orders.count()
    total_amount = orders.aggregate(total=Sum('total_amount'))['total'] or 0
    
    # Orders by status
    orders_by_status = orders.values('status').annotate(count=Count('id'))
    order_status_counts = {item['status']: item['count'] for item in orders_by_status}
    
    # Orders by day
    from django.db.models.functions import TruncDate
    orders_by_day = orders.annotate(
        day=TruncDate('created_at')
    ).values('day').annotate(
        count=Count('id'),
        total_amount=Sum('total_amount')
    ).order_by('day')
    
    daily_orders = []
    for item in orders_by_day:
        daily_orders.append({
            'date': item['day'].isoformat(),
            'order_count': item['count'],
            'total_amount': float(item['total_amount'])
        })
    
    # Average processing time (from creation to delivery)
    avg_processing_time = 0
    delivered_orders = orders.filter(
        status='delivered',
        delivered_at__isnull=False
    )
    
    if delivered_orders.exists():
        processing_times = []
        for order in delivered_orders:
            if order.delivered_at:
                processing_time = (order.delivered_at - order.created_at).total_seconds() / 3600  # Hours
                processing_times.append(processing_time)
        
        if processing_times:
            avg_processing_time = sum(processing_times) / len(processing_times)
    
    # Prepare response
    return Response({
        'date_range': {
            'start_date': start_date,
            'end_date': end_date
        },
        'summary': {
            'total_orders': total_orders,
            'total_amount': float(total_amount),
            'avg_order_value': float(total_amount / total_orders) if total_orders > 0 else 0,
            'avg_processing_time_hours': round(avg_processing_time, 2)
        },
        'orders_by_status': order_status_counts,
        'daily_orders': daily_orders
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
            assignment = DeliveryAssignment.objects.create(
                order=order,
                delivery_manager=delivery_manager,
                delivery_notes=delivery_notes,
                estimated_delivery_time=estimated_delivery_time
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
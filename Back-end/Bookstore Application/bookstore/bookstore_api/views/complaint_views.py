from rest_framework import generics, status, permissions
from rest_framework.response import Response
from rest_framework.decorators import action
from django.shortcuts import get_object_or_404
from django.db.models import Q
from django.core.paginator import Paginator
from django.utils import timezone
from ..models import Complaint, ComplaintResponse
from ..serializers import (
    ComplaintListSerializer,
    ComplaintDetailSerializer,
    ComplaintCreateSerializer,
    ComplaintUpdateSerializer,
    ComplaintResponseSerializer,
    ComplaintResponseCreateSerializer,
)
from ..permissions import IsLibraryAdmin, IsSystemAdmin, IsDeliveryAdmin


class ComplaintListView(generics.ListCreateAPIView):
    """
    List all complaints or create a new complaint.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get_serializer_class(self):
        if self.request.method == 'POST':
            return ComplaintCreateSerializer
        return ComplaintListSerializer
    
    def get_queryset(self):
        queryset = Complaint.objects.select_related(
            'customer', 'assigned_to', 'related_order', 'related_borrow_request'
        ).prefetch_related('responses')
        
        # Filter by user type
        user = self.request.user
        if user.user_type == 'customer':
            # Customers can only see their own complaints
            queryset = queryset.filter(customer=user)
        elif user.user_type in ['library_admin', 'delivery_admin', 'system_admin']:
            # Admins can see all complaints
            pass
        else:
            # Other user types cannot see complaints
            queryset = queryset.none()
        
        # Apply filters
        search = self.request.query_params.get('search')
        if search:
            queryset = queryset.filter(
                Q(title__icontains=search) |
                Q(description__icontains=search) |
                Q(complaint_id__icontains=search)
            )
        
        status_filter = self.request.query_params.get('status')
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        
        type_filter = self.request.query_params.get('type')
        if type_filter:
            queryset = queryset.filter(complaint_type=type_filter)
        
        priority_filter = self.request.query_params.get('priority')
        if priority_filter:
            queryset = queryset.filter(priority=priority_filter)
        
        return queryset.order_by('-created_at')
    
    def list(self, request, *args, **kwargs):
        queryset = self.get_queryset()
        
        # Pagination
        page = int(request.query_params.get('page', 1))
        limit = int(request.query_params.get('limit', 10))
        
        paginator = Paginator(queryset, limit)
        page_obj = paginator.get_page(page)
        
        serializer = self.get_serializer(page_obj.object_list, many=True)
        
        return Response({
            'data': serializer.data,
            'count': paginator.count,
            'total_pages': paginator.num_pages,
            'current_page': page_obj.number,
            'has_next': page_obj.has_next(),
            'has_previous': page_obj.has_previous(),
        })


class ComplaintDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    Retrieve, update or delete a complaint.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get_serializer_class(self):
        if self.request.method in ['PUT', 'PATCH']:
            return ComplaintUpdateSerializer
        return ComplaintDetailSerializer
    
    def get_queryset(self):
        user = self.request.user
        if user.user_type == 'customer':
            return Complaint.objects.filter(customer=user)
        elif user.user_type in ['library_admin', 'delivery_admin', 'system_admin']:
            return Complaint.objects.all()
        else:
            return Complaint.objects.none()
    
    def get_object(self):
        obj = get_object_or_404(self.get_queryset(), pk=self.kwargs['pk'])
        return obj


class ComplaintStatusUpdateView(generics.UpdateAPIView):
    """
    Update complaint status.
    """
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin | IsSystemAdmin | IsDeliveryAdmin]
    serializer_class = ComplaintUpdateSerializer
    
    def get_queryset(self):
        return Complaint.objects.all()
    
    def patch(self, request, *args, **kwargs):
        complaint = self.get_object()
        serializer = self.get_serializer(complaint, data=request.data, partial=True)
        
        if serializer.is_valid():
            serializer.save()
            return Response({
                'success': True,
                'message': 'Complaint status updated successfully',
                'data': ComplaintDetailSerializer(complaint).data
            })
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class ComplaintAssignView(generics.UpdateAPIView):
    """
    Assign complaint to a staff member.
    """
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin | IsSystemAdmin | IsDeliveryAdmin]
    serializer_class = ComplaintUpdateSerializer
    
    def get_queryset(self):
        return Complaint.objects.all()
    
    def patch(self, request, *args, **kwargs):
        complaint = self.get_object()
        staff_id = request.data.get('assigned_to')
        
        if not staff_id:
            return Response({
                'success': False,
                'message': 'assigned_to field is required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Validate that the assigned user is a staff member
        from ..models import User
        try:
            staff_member = User.objects.get(
                id=staff_id,
                user_type__in=['library_admin', 'delivery_admin', 'system_admin']
            )
        except User.DoesNotExist:
            return Response({
                'success': False,
                'message': 'Invalid staff member ID'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        complaint.assigned_to = staff_member
        complaint.save()
        
        return Response({
            'success': True,
            'message': 'Complaint assigned successfully',
            'data': ComplaintDetailSerializer(complaint).data
        })


class ComplaintResponseCreateView(generics.CreateAPIView):
    """
    Add a response to a complaint.
    """
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = ComplaintResponseCreateSerializer
    
    def perform_create(self, serializer):
        complaint_id = self.kwargs['complaint_id']
        complaint = get_object_or_404(Complaint, id=complaint_id)
        
        # Check permissions
        user = self.request.user
        if user.user_type == 'customer' and complaint.customer != user:
            raise permissions.PermissionDenied("You can only respond to your own complaints")
        
        serializer.save(complaint=complaint, responder=user)


class ComplaintResponseListView(generics.ListAPIView):
    """
    List all responses for a complaint.
    """
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = ComplaintResponseSerializer
    
    def get_queryset(self):
        complaint_id = self.kwargs['complaint_id']
        complaint = get_object_or_404(Complaint, id=complaint_id)
        
        # Check permissions
        user = self.request.user
        if user.user_type == 'customer' and complaint.customer != user:
            raise permissions.PermissionDenied("You can only view responses to your own complaints")
        
        queryset = ComplaintResponse.objects.filter(complaint=complaint)
        
        # Customers can only see non-internal responses
        if user.user_type == 'customer':
            queryset = queryset.filter(is_internal=False)
        
        return queryset.order_by('created_at')


class ComplaintResolveView(generics.UpdateAPIView):
    """
    Resolve a complaint with resolution details.
    """
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin | IsSystemAdmin | IsDeliveryAdmin]
    serializer_class = ComplaintUpdateSerializer
    
    def get_queryset(self):
        return Complaint.objects.all()
    
    def patch(self, request, *args, **kwargs):
        complaint = self.get_object()
        resolution = request.data.get('resolution')
        
        if not resolution:
            return Response({
                'success': False,
                'message': 'resolution field is required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        complaint.status = 'resolved'
        complaint.resolution = resolution
        complaint.resolved_at = timezone.now()
        complaint.save()
        
        return Response({
            'success': True,
            'message': 'Complaint resolved successfully',
            'data': ComplaintDetailSerializer(complaint).data
        })


class ComplaintStatsView(generics.GenericAPIView):
    """
    Get complaint statistics for dashboard.
    """
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin | IsSystemAdmin | IsDeliveryAdmin]
    
    def get(self, request, *args, **kwargs):
        from django.utils import timezone
        from datetime import timedelta
        
        # Get date range
        days = int(request.query_params.get('days', 30))
        end_date = timezone.now()
        start_date = end_date - timedelta(days=days)
        
        # Filter complaints by date range
        complaints = Complaint.objects.filter(created_at__range=[start_date, end_date])
        
        # Calculate statistics
        total_complaints = complaints.count()
        open_complaints = complaints.filter(status='open').count()
        in_progress_complaints = complaints.filter(status='in_progress').count()
        resolved_complaints = complaints.filter(status='resolved').count()
        closed_complaints = complaints.filter(status='closed').count()
        
        # Complaints by type
        complaints_by_type = {}
        for complaint_type, _ in Complaint.COMPLAINT_TYPE_CHOICES:
            count = complaints.filter(complaint_type=complaint_type).count()
            complaints_by_type[complaint_type] = count
        
        # Complaints by priority
        complaints_by_priority = {}
        for priority, _ in Complaint.PRIORITY_CHOICES:
            count = complaints.filter(priority=priority).count()
            complaints_by_priority[priority] = count
        
        return Response({
            'success': True,
            'data': {
                'total_complaints': total_complaints,
                'open_complaints': open_complaints,
                'in_progress_complaints': in_progress_complaints,
                'resolved_complaints': resolved_complaints,
                'closed_complaints': closed_complaints,
                'complaints_by_type': complaints_by_type,
                'complaints_by_priority': complaints_by_priority,
                'resolution_rate': round((resolved_complaints + closed_complaints) / total_complaints * 100, 2) if total_complaints > 0 else 0,
            }
        })

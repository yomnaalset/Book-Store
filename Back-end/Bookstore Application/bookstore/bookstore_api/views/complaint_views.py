from rest_framework import generics, status, permissions
from rest_framework.response import Response
from rest_framework.decorators import action
from django.shortcuts import get_object_or_404
from django.db.models import Q
from django.core.paginator import Paginator
from django.utils import timezone
from ..models import Complaint, ComplaintResponse, User
from ..serializers import (
    ComplaintListSerializer,
    ComplaintDetailSerializer,
    ComplaintCreateSerializer,
    ComplaintUpdateSerializer,
    ComplaintCustomerUpdateSerializer,
    ComplaintResponseSerializer,
    ComplaintResponseCreateSerializer,
)
from ..permissions import IsLibraryAdmin, IsSystemAdmin, IsDeliveryAdmin
from ..services.notification_services import NotificationService


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
            'customer'
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
    
    def create(self, request, *args, **kwargs):
        """
        Create a new complaint and send notification to admins.
        """
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        complaint = serializer.save()
        
        # Send notification to all admins
        try:
            admin_users = User.objects.filter(
                user_type__in=['library_admin', 'system_admin', 'delivery_admin'],
                is_active=True
            )
            
            for admin in admin_users:
                NotificationService.create_notification(
                    user_id=admin.id,
                    title="New Complaint Received",
                    message=f"A customer has submitted a new complaint. Please review it.",
                    notification_type="new_complaint",
                    prevent_duplicates=False  # Allow multiple notifications for different admins
                )
        except Exception as e:
            # Log error but don't fail the complaint creation
            import logging
            logger = logging.getLogger(__name__)
            logger.error(f"Failed to send notification for complaint {complaint.id}: {str(e)}")
        
        headers = self.get_success_headers(serializer.data)
        return Response(
            {
                'success': True,
                'message': 'Complaint created successfully',
                'data': ComplaintDetailSerializer(complaint, context={'request': request}).data
            },
            status=status.HTTP_201_CREATED,
            headers=headers
        )


class ComplaintDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    Retrieve, update or delete a complaint.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get_serializer_class(self):
        if self.request.method in ['PUT', 'PATCH']:
            # Use different serializers based on user type
            user = self.request.user
            if user.user_type == 'customer':
                return ComplaintCustomerUpdateSerializer
            else:
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
    
    def retrieve(self, request, *args, **kwargs):
        """
        Override retrieve to ensure serializer has request context for filtering responses.
        """
        instance = self.get_object()
        serializer = self.get_serializer(instance, context={'request': request})
        return Response(serializer.data)
    
    def update(self, request, *args, **kwargs):
        """
        Override update to return full complaint object.
        """
        partial = kwargs.pop('partial', False)
        instance = self.get_object()
        serializer = self.get_serializer(instance, data=request.data, partial=partial)
        serializer.is_valid(raise_exception=True)
        self.perform_update(serializer)
        
        # Refresh instance from database to get updated data
        instance.refresh_from_db()
        
        # Return full complaint object using ComplaintDetailSerializer
        detail_serializer = ComplaintDetailSerializer(instance, context={'request': request})
        
        return Response({
            'success': True,
            'message': 'Complaint updated successfully',
            'data': detail_serializer.data
        })


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
                'data': ComplaintDetailSerializer(complaint, context={'request': request}).data
            })
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class ComplaintAssignView(generics.UpdateAPIView):
    """
    Assign complaint to a staff member.
    Note: Assignment functionality has been removed. This endpoint is kept for backward compatibility
    but no longer performs assignment operations.
    """
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin | IsSystemAdmin | IsDeliveryAdmin]
    serializer_class = ComplaintUpdateSerializer
    
    def get_queryset(self):
        return Complaint.objects.all()
    
    def patch(self, request, *args, **kwargs):
        complaint = self.get_object()
        
        return Response({
            'success': True,
            'message': 'Assignment functionality has been removed',
            'data': ComplaintDetailSerializer(complaint, context={'request': request}).data
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
        
        response = serializer.save(complaint=complaint, responder=user)
        
        # If admin is responding, update status to "in_progress" (Replied) and notify customer
        if user.user_type in ['library_admin', 'system_admin', 'delivery_admin']:
            # Update complaint status to "in_progress" (which represents "Replied")
            if complaint.status == 'open':
                complaint.status = 'in_progress'
                complaint.save()
            
            # Send notification to customer
            try:
                NotificationService.create_notification(
                    user_id=complaint.customer.id,
                    title="Your complaint has been answered",
                    message="Your complaint has been answered. Please check the details.",
                    notification_type="complaint_replied",
                    prevent_duplicates=False
                )
            except Exception as e:
                import logging
                logger = logging.getLogger(__name__)
                logger.error(f"Failed to send notification for complaint {complaint.id}: {str(e)}")
        
        return response


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
    Resolve a complaint by updating its status to resolved.
    """
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin | IsSystemAdmin | IsDeliveryAdmin]
    serializer_class = ComplaintUpdateSerializer
    
    def get_queryset(self):
        return Complaint.objects.all()
    
    def patch(self, request, *args, **kwargs):
        complaint = self.get_object()
        complaint.status = 'resolved'
        complaint.save()
        
        # Send notification to customer
        try:
            NotificationService.create_notification(
                user_id=complaint.customer.id,
                title="Your complaint has been resolved",
                message="Your complaint has been marked as resolved. Thank you for your patience.",
                notification_type="complaint_resolved",
                prevent_duplicates=False
            )
        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.error(f"Failed to send notification for complaint {complaint.id}: {str(e)}")
        
        return Response({
            'success': True,
            'message': 'Complaint resolved successfully',
            'data': ComplaintDetailSerializer(complaint, context={'request': request}).data
        })


class ComplaintUpdateStatusView(generics.GenericAPIView):
    """
    Update complaint status via POST request.
    Used by the status menu actions.
    """
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin | IsSystemAdmin | IsDeliveryAdmin]
    
    def get_queryset(self):
        return Complaint.objects.all()
    
    def post(self, request, *args, **kwargs):
        complaint = get_object_or_404(self.get_queryset(), pk=self.kwargs['pk'])
        status = request.data.get('status')
        
        if not status:
            return Response({
                'success': False,
                'message': 'status field is required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Validate status
        valid_statuses = [choice[0] for choice in Complaint.STATUS_CHOICES]
        if status not in valid_statuses:
            return Response({
                'success': False,
                'message': f'Invalid status. Must be one of: {", ".join(valid_statuses)}'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        complaint.status = status
        complaint.save()
        
        # Send notification to customer if status changed to resolved or closed
        if status in ['resolved', 'closed']:
            try:
                NotificationService.create_notification(
                    user_id=complaint.customer.id,
                    title=f"Your complaint has been {status}",
                    message=f"Your complaint status has been updated to {status}.",
                    notification_type=f"complaint_{status}",
                    prevent_duplicates=False
                )
            except Exception as e:
                import logging
                logger = logging.getLogger(__name__)
                logger.error(f"Failed to send notification for complaint {complaint.id}: {str(e)}")
        
        return Response({
            'success': True,
            'message': f'Complaint status updated to {status}',
            'data': ComplaintDetailSerializer(complaint, context={'request': request}).data
        })


class ComplaintReplyView(generics.GenericAPIView):
    """
    Send a reply to a complaint.
    Saves the response and updates status to 'in_progress' (replied) if currently 'open'.
    """
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin | IsSystemAdmin | IsDeliveryAdmin]
    
    def get_queryset(self):
        return Complaint.objects.all()
    
    def post(self, request, *args, **kwargs):
        complaint = get_object_or_404(self.get_queryset(), pk=self.kwargs['pk'])
        response_text = request.data.get('response')
        
        if not response_text:
            return Response({
                'success': False,
                'message': 'response field is required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Create complaint response
        response = ComplaintResponse.objects.create(
            complaint=complaint,
            responder=request.user,
            response_text=response_text,
            is_internal=False
        )
        
        # Update status to 'in_progress' (replied) if currently 'open'
        if complaint.status == 'open':
            complaint.status = 'in_progress'
            complaint.save()
        
        # Send notification to customer
        try:
            NotificationService.create_notification(
                user_id=complaint.customer.id,
                title="Your complaint has been answered",
                message="Your complaint has been answered. Please check the details.",
                notification_type="complaint_replied",
                prevent_duplicates=False
            )
        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.error(f"Failed to send notification for complaint {complaint.id}: {str(e)}")
        
        return Response({
            'success': True,
            'message': 'Reply sent successfully',
            'data': ComplaintDetailSerializer(complaint, context={'request': request}).data
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
        return Response({
            'success': True,
            'data': {
                'total_complaints': total_complaints,
                'open_complaints': open_complaints,
                'in_progress_complaints': in_progress_complaints,
                'resolved_complaints': resolved_complaints,
                'closed_complaints': closed_complaints,
                'resolution_rate': round((resolved_complaints + closed_complaints) / total_complaints * 100, 2) if total_complaints > 0 else 0,
            }
        })

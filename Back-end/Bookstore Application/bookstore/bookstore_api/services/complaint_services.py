"""
Complaint Management Services

This module provides business logic services for managing complaints,
including creation, updates, assignment, resolution, and reporting.
"""

from django.db import transaction
from django.utils import timezone
from django.core.paginator import Paginator
from django.db.models import Q, Count, Avg
from typing import Dict, List, Optional, Any, Tuple
from datetime import datetime, timedelta
import logging

from ..models import Complaint, ComplaintResponse, User
from ..serializers import (
    ComplaintListSerializer,
    ComplaintDetailSerializer,
    ComplaintCreateSerializer,
    ComplaintUpdateSerializer,
    ComplaintResponseSerializer,
)

logger = logging.getLogger(__name__)


class ComplaintManagementService:
    """
    Service class for managing complaints and related operations.
    """

    @staticmethod
    def create_complaint(
        user: User,
        title: str,
        description: str,
        complaint_type: str,
        priority: str = 'medium',
        related_order_id: Optional[int] = None,
        related_borrow_request_id: Optional[int] = None,
    ) -> Dict[str, Any]:
        """
        Create a new complaint.
        
        Args:
            user: The user creating the complaint
            title: Complaint title
            description: Detailed description
            complaint_type: Type of complaint
            priority: Priority level
            related_order_id: Optional related order ID
            related_borrow_request_id: Optional related borrow request ID
            
        Returns:
            Dictionary containing success status and complaint data
        """
        try:
            # Validate user can create complaints
            if user.user_type != 'customer':
                return {
                    'success': False,
                    'message': 'Only customers can create complaints',
                    'error_code': 'PERMISSION_DENIED'
                }
            
            # Validate complaint type
            valid_types = [choice[0] for choice in Complaint.COMPLAINT_TYPE_CHOICES]
            if complaint_type not in valid_types:
                return {
                    'success': False,
                    'message': f'Invalid complaint type. Must be one of: {", ".join(valid_types)}',
                    'error_code': 'INVALID_TYPE'
                }
            
            # Validate priority
            valid_priorities = [choice[0] for choice in Complaint.PRIORITY_CHOICES]
            if priority not in valid_priorities:
                return {
                    'success': False,
                    'message': f'Invalid priority. Must be one of: {", ".join(valid_priorities)}',
                    'error_code': 'INVALID_PRIORITY'
                }
            
            with transaction.atomic():
                # Create complaint
                complaint_data = {
                    'customer': user,
                    'title': title,
                    'description': description,
                    'complaint_type': complaint_type,
                    'priority': priority,
                }
                
                # Add related objects if provided
                if related_order_id:
                    from ..models import Order
                    try:
                        order = Order.objects.get(id=related_order_id, customer=user)
                        complaint_data['related_order'] = order
                    except Order.DoesNotExist:
                        return {
                            'success': False,
                            'message': 'Related order not found or does not belong to user',
                            'error_code': 'ORDER_NOT_FOUND'
                        }
                
                if related_borrow_request_id:
                    from ..models import BorrowRequest
                    try:
                        borrow_request = BorrowRequest.objects.get(id=related_borrow_request_id, customer=user)
                        complaint_data['related_borrow_request'] = borrow_request
                    except BorrowRequest.DoesNotExist:
                        return {
                            'success': False,
                            'message': 'Related borrow request not found or does not belong to user',
                            'error_code': 'BORROW_REQUEST_NOT_FOUND'
                        }
                
                complaint = Complaint.objects.create(**complaint_data)
                
                # Log complaint creation
                logger.info(f"Complaint {complaint.complaint_id} created by user {user.email}")
                
                return {
                    'success': True,
                    'message': 'Complaint created successfully',
                    'complaint': ComplaintDetailSerializer(complaint).data
                }
                
        except Exception as e:
            logger.error(f"Error creating complaint: {str(e)}")
            return {
                'success': False,
                'message': 'Failed to create complaint',
                'error_code': 'CREATION_ERROR'
            }

    @staticmethod
    def get_complaints(
        user: User,
        page: int = 1,
        limit: int = 10,
        search: Optional[str] = None,
        status: Optional[str] = None,
        complaint_type: Optional[str] = None,
        priority: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Get complaints with filtering and pagination.
        
        Args:
            user: The user requesting complaints
            page: Page number
            limit: Items per page
            search: Search term
            status: Status filter
            complaint_type: Type filter
            priority: Priority filter
            
        Returns:
            Dictionary containing complaints and pagination info
        """
        try:
            # Build base queryset
            queryset = Complaint.objects.select_related(
                'customer', 'assigned_to', 'related_order', 'related_borrow_request'
            ).prefetch_related('responses')
            
            # Apply user-based filtering
            if user.user_type == 'customer':
                queryset = queryset.filter(customer=user)
            elif user.user_type not in ['library_admin', 'delivery_admin', 'system_admin']:
                return {
                    'success': False,
                    'message': 'Insufficient permissions to view complaints',
                    'error_code': 'PERMISSION_DENIED'
                }
            
            # Apply filters
            if search:
                queryset = queryset.filter(
                    Q(title__icontains=search) |
                    Q(description__icontains=search) |
                    Q(complaint_id__icontains=search)
                )
            
            if status:
                queryset = queryset.filter(status=status)
            
            if complaint_type:
                queryset = queryset.filter(complaint_type=complaint_type)
            
            if priority:
                queryset = queryset.filter(priority=priority)
            
            # Order by creation date (newest first)
            queryset = queryset.order_by('-created_at')
            
            # Pagination
            paginator = Paginator(queryset, limit)
            page_obj = paginator.get_page(page)
            
            # Serialize data
            complaints_data = ComplaintListSerializer(page_obj.object_list, many=True).data
            
            return {
                'success': True,
                'data': complaints_data,
                'pagination': {
                    'count': paginator.count,
                    'total_pages': paginator.num_pages,
                    'current_page': page_obj.number,
                    'has_next': page_obj.has_next(),
                    'has_previous': page_obj.has_previous(),
                }
            }
            
        except Exception as e:
            logger.error(f"Error retrieving complaints: {str(e)}")
            return {
                'success': False,
                'message': 'Failed to retrieve complaints',
                'error_code': 'RETRIEVAL_ERROR'
            }

    @staticmethod
    def get_complaint_detail(user: User, complaint_id: int) -> Dict[str, Any]:
        """
        Get detailed information about a specific complaint.
        
        Args:
            user: The user requesting complaint details
            complaint_id: ID of the complaint
            
        Returns:
            Dictionary containing complaint details
        """
        try:
            # Build base queryset
            queryset = Complaint.objects.select_related(
                'customer', 'assigned_to', 'related_order', 'related_borrow_request'
            ).prefetch_related('responses')
            
            # Apply user-based filtering
            if user.user_type == 'customer':
                queryset = queryset.filter(customer=user)
            elif user.user_type not in ['library_admin', 'delivery_admin', 'system_admin']:
                return {
                    'success': False,
                    'message': 'Insufficient permissions to view complaint details',
                    'error_code': 'PERMISSION_DENIED'
                }
            
            try:
                complaint = queryset.get(id=complaint_id)
            except Complaint.DoesNotExist:
                return {
                    'success': False,
                    'message': 'Complaint not found',
                    'error_code': 'NOT_FOUND'
                }
            
            return {
                'success': True,
                'complaint': ComplaintDetailSerializer(complaint).data
            }
            
        except Exception as e:
            logger.error(f"Error retrieving complaint details: {str(e)}")
            return {
                'success': False,
                'message': 'Failed to retrieve complaint details',
                'error_code': 'RETRIEVAL_ERROR'
            }

    @staticmethod
    def update_complaint_status(
        user: User,
        complaint_id: int,
        status: str,
        resolution: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Update complaint status.
        
        Args:
            user: The user updating the complaint
            complaint_id: ID of the complaint
            status: New status
            resolution: Resolution details (if resolving)
            
        Returns:
            Dictionary containing success status
        """
        try:
            # Check permissions
            if user.user_type not in ['library_admin', 'delivery_admin', 'system_admin']:
                return {
                    'success': False,
                    'message': 'Only administrators can update complaint status',
                    'error_code': 'PERMISSION_DENIED'
                }
            
            # Validate status
            valid_statuses = [choice[0] for choice in Complaint.STATUS_CHOICES]
            if status not in valid_statuses:
                return {
                    'success': False,
                    'message': f'Invalid status. Must be one of: {", ".join(valid_statuses)}',
                    'error_code': 'INVALID_STATUS'
                }
            
            try:
                complaint = Complaint.objects.get(id=complaint_id)
            except Complaint.DoesNotExist:
                return {
                    'success': False,
                    'message': 'Complaint not found',
                    'error_code': 'NOT_FOUND'
                }
            
            with transaction.atomic():
                # Update status
                complaint.status = status
                
                # Set resolution and resolved_at if resolving
                if status == 'resolved' and resolution:
                    complaint.resolution = resolution
                    complaint.resolved_at = timezone.now()
                
                complaint.save()
                
                # Log status update
                logger.info(f"Complaint {complaint.complaint_id} status updated to {status} by {user.email}")
                
                return {
                    'success': True,
                    'message': 'Complaint status updated successfully',
                    'complaint': ComplaintDetailSerializer(complaint).data
                }
                
        except Exception as e:
            logger.error(f"Error updating complaint status: {str(e)}")
            return {
                'success': False,
                'message': 'Failed to update complaint status',
                'error_code': 'UPDATE_ERROR'
            }

    @staticmethod
    def assign_complaint(
        user: User,
        complaint_id: int,
        assigned_to_id: int
    ) -> Dict[str, Any]:
        """
        Assign complaint to a staff member.
        
        Args:
            user: The user assigning the complaint
            complaint_id: ID of the complaint
            assigned_to_id: ID of the staff member to assign to
            
        Returns:
            Dictionary containing success status
        """
        try:
            # Check permissions
            if user.user_type not in ['library_admin', 'delivery_admin', 'system_admin']:
                return {
                    'success': False,
                    'message': 'Only administrators can assign complaints',
                    'error_code': 'PERMISSION_DENIED'
                }
            
            try:
                complaint = Complaint.objects.get(id=complaint_id)
            except Complaint.DoesNotExist:
                return {
                    'success': False,
                    'message': 'Complaint not found',
                    'error_code': 'NOT_FOUND'
                }
            
            try:
                assigned_to = User.objects.get(
                    id=assigned_to_id,
                    user_type__in=['library_admin', 'delivery_admin', 'system_admin']
                )
            except User.DoesNotExist:
                return {
                    'success': False,
                    'message': 'Invalid staff member ID',
                    'error_code': 'INVALID_STAFF'
                }
            
            with transaction.atomic():
                complaint.assigned_to = assigned_to
                complaint.save()
                
                # Log assignment
                logger.info(f"Complaint {complaint.complaint_id} assigned to {assigned_to.email} by {user.email}")
                
                return {
                    'success': True,
                    'message': 'Complaint assigned successfully',
                    'complaint': ComplaintDetailSerializer(complaint).data
                }
                
        except Exception as e:
            logger.error(f"Error assigning complaint: {str(e)}")
            return {
                'success': False,
                'message': 'Failed to assign complaint',
                'error_code': 'ASSIGNMENT_ERROR'
            }

    @staticmethod
    def add_complaint_response(
        user: User,
        complaint_id: int,
        response_text: str,
        is_internal: bool = False
    ) -> Dict[str, Any]:
        """
        Add a response to a complaint.
        
        Args:
            user: The user adding the response
            complaint_id: ID of the complaint
            response_text: Response content
            is_internal: Whether this is an internal note
            
        Returns:
            Dictionary containing success status
        """
        try:
            try:
                complaint = Complaint.objects.get(id=complaint_id)
            except Complaint.DoesNotExist:
                return {
                    'success': False,
                    'message': 'Complaint not found',
                    'error_code': 'NOT_FOUND'
                }
            
            # Check permissions
            if user.user_type == 'customer' and complaint.customer != user:
                return {
                    'success': False,
                    'message': 'You can only respond to your own complaints',
                    'error_code': 'PERMISSION_DENIED'
                }
            
            with transaction.atomic():
                response = ComplaintResponse.objects.create(
                    complaint=complaint,
                    responder=user,
                    response_text=response_text,
                    is_internal=is_internal
                )
                
                # Log response
                logger.info(f"Response added to complaint {complaint.complaint_id} by {user.email}")
                
                return {
                    'success': True,
                    'message': 'Response added successfully',
                    'response': ComplaintResponseSerializer(response).data
                }
                
        except Exception as e:
            logger.error(f"Error adding complaint response: {str(e)}")
            return {
                'success': False,
                'message': 'Failed to add response',
                'error_code': 'RESPONSE_ERROR'
            }

    @staticmethod
    def get_complaint_statistics(
        user: User,
        days: int = 30
    ) -> Dict[str, Any]:
        """
        Get complaint statistics for dashboard.
        
        Args:
            user: The user requesting statistics
            days: Number of days to include in statistics
            
        Returns:
            Dictionary containing complaint statistics
        """
        try:
            # Check permissions
            if user.user_type not in ['library_admin', 'delivery_admin', 'system_admin']:
                return {
                    'success': False,
                    'message': 'Only administrators can view complaint statistics',
                    'error_code': 'PERMISSION_DENIED'
                }
            
            # Calculate date range
            end_date = timezone.now()
            start_date = end_date - timedelta(days=days)
            
            # Filter complaints by date range
            complaints = Complaint.objects.filter(created_at__range=[start_date, end_date])
            
            # Calculate basic statistics
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
            
            # Resolution rate
            resolution_rate = 0
            if total_complaints > 0:
                resolution_rate = round((resolved_complaints + closed_complaints) / total_complaints * 100, 2)
            
            # Average resolution time (for resolved complaints)
            avg_resolution_time = None
            resolved_with_times = complaints.filter(
                status__in=['resolved', 'closed'],
                resolved_at__isnull=False
            )
            if resolved_with_times.exists():
                resolution_times = []
                for complaint in resolved_with_times:
                    if complaint.resolved_at:
                        time_diff = complaint.resolved_at - complaint.created_at
                        resolution_times.append(time_diff.total_seconds() / 3600)  # Convert to hours
                
                if resolution_times:
                    avg_resolution_time = round(sum(resolution_times) / len(resolution_times), 2)
            
            return {
                'success': True,
                'data': {
                    'total_complaints': total_complaints,
                    'open_complaints': open_complaints,
                    'in_progress_complaints': in_progress_complaints,
                    'resolved_complaints': resolved_complaints,
                    'closed_complaints': closed_complaints,
                    'complaints_by_type': complaints_by_type,
                    'complaints_by_priority': complaints_by_priority,
                    'resolution_rate': resolution_rate,
                    'average_resolution_time_hours': avg_resolution_time,
                    'period_days': days,
                }
            }
            
        except Exception as e:
            logger.error(f"Error retrieving complaint statistics: {str(e)}")
            return {
                'success': False,
                'message': 'Failed to retrieve complaint statistics',
                'error_code': 'STATISTICS_ERROR'
            }

    @staticmethod
    def delete_complaint(user: User, complaint_id: int) -> Dict[str, Any]:
        """
        Delete a complaint (soft delete by changing status to closed).
        
        Args:
            user: The user deleting the complaint
            complaint_id: ID of the complaint
            
        Returns:
            Dictionary containing success status
        """
        try:
            # Check permissions
            if user.user_type not in ['library_admin', 'delivery_admin', 'system_admin']:
                return {
                    'success': False,
                    'message': 'Only administrators can delete complaints',
                    'error_code': 'PERMISSION_DENIED'
                }
            
            try:
                complaint = Complaint.objects.get(id=complaint_id)
            except Complaint.DoesNotExist:
                return {
                    'success': False,
                    'message': 'Complaint not found',
                    'error_code': 'NOT_FOUND'
                }
            
            with transaction.atomic():
                # Soft delete by changing status to closed
                complaint.status = 'closed'
                complaint.save()
                
                # Log deletion
                logger.info(f"Complaint {complaint.complaint_id} closed by {user.email}")
                
                return {
                    'success': True,
                    'message': 'Complaint closed successfully'
                }
                
        except Exception as e:
            logger.error(f"Error deleting complaint: {str(e)}")
            return {
                'success': False,
                'message': 'Failed to delete complaint',
                'error_code': 'DELETION_ERROR'
            }

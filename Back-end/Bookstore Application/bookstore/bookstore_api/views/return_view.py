from rest_framework import generics, status, permissions
from rest_framework.response import Response
from rest_framework.views import APIView
from django.shortcuts import get_object_or_404
from django.db.models import Q

from ..models.return_model import ReturnRequest, ReturnStatus
from ..models.borrowing_model import BorrowRequest, BorrowFine, FineStatusChoices
from ..models.user_model import User
from ..serializers.return_serializers import (
    ReturnRequestSerializer,
    ReturnRequestCreateSerializer,
    ReturnRequestApprovalSerializer,
    ReturnRequestAssignSerializer
)
from ..serializers.borrowing_serializers import BorrowFineSerializer
from ..services.return_services import ReturnService
from ..permissions import IsCustomer, IsLibraryAdmin, IsDeliveryAdmin, IsAnyAdmin
from ..utils import format_error_message
import logging

logger = logging.getLogger(__name__)


class ReturnRequestCreateView(generics.CreateAPIView):
    """
    API view for customers to create return requests
    """
    serializer_class = ReturnRequestCreateSerializer
    permission_classes = [permissions.IsAuthenticated, IsCustomer]
    
    def create(self, request, *args, **kwargs):
        try:
            serializer = self.get_serializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            
            return_request = serializer.save()
            response_serializer = ReturnRequestSerializer(return_request)
            
            return Response({
                'success': True,
                'message': 'Return request created successfully',
                'data': response_serializer.data
            }, status=status.HTTP_201_CREATED)
            
        except Exception as e:
            logger.error(f"Error creating return request: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to create return request',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_400_BAD_REQUEST)


class ReturnRequestListView(generics.ListAPIView):
    """
    API view to list return requests
    Admin: all return requests
    Delivery Manager: assigned return requests
    Customer: their own return requests
    """
    serializer_class = ReturnRequestSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        user = self.request.user
        
        if user.user_type == 'library_admin':
            # Admin sees all return requests
            queryset = ReturnRequest.objects.all()
        elif user.user_type == 'delivery_admin':
            # Delivery manager sees only return requests assigned to them
            queryset = ReturnRequest.objects.filter(delivery_manager=user)
        else:
            # Customer sees only their own return requests
            queryset = ReturnRequest.objects.filter(borrowing__customer=user)
        
        # Filter by status if provided
        status_filter = self.request.query_params.get('status', None)
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        
        # Add search filter if provided
        search_query = self.request.query_params.get('search', None)
        if search_query and search_query.strip():
            search_term = search_query.strip()
            queryset = queryset.filter(
                Q(borrowing__customer__first_name__icontains=search_term) |
                Q(borrowing__customer__last_name__icontains=search_term) |
                Q(borrowing__customer__email__icontains=search_term) |
                Q(borrowing__book__name__icontains=search_term) |
                Q(id__icontains=search_term)
            )
        
        return queryset.select_related('borrowing', 'borrowing__customer', 'borrowing__book', 'delivery_manager').order_by('-created_at')
    
    def list(self, request, *args, **kwargs):
        try:
            queryset = self.get_queryset()
            serializer = self.get_serializer(queryset, many=True)
            
            return Response({
                'success': True,
                'message': 'Return requests retrieved successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving return requests: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve return requests',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class ReturnRequestDetailView(generics.RetrieveAPIView):
    """
    API view to get return request details
    """
    serializer_class = ReturnRequestSerializer
    permission_classes = [permissions.IsAuthenticated]
    queryset = ReturnRequest.objects.select_related(
        'borrowing',
        'borrowing__customer',
        'borrowing__customer__profile',
        'borrowing__book',
        'delivery_manager',
        'delivery_manager__profile'
    ).all()
    
    def retrieve(self, request, *args, **kwargs):
        try:
            instance = self.get_object()
            
            # Check permissions
            user = request.user
            if user.user_type == 'customer':
                if instance.borrowing.customer != user:
                    return Response({
                        'success': False,
                        'message': 'You do not have permission to view this return request'
                    }, status=status.HTTP_403_FORBIDDEN)
            elif user.user_type == 'delivery_admin':
                if instance.delivery_manager != user:
                    return Response({
                        'success': False,
                        'message': 'You do not have permission to view this return request'
                    }, status=status.HTTP_403_FORBIDDEN)
            
            serializer = self.get_serializer(instance)
            
            return Response({
                'success': True,
                'message': 'Return request retrieved successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving return request: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve return request',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class ApproveReturnRequestView(APIView):
    """
    API view for admin to approve a return request
    """
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def post(self, request, pk):
        try:
            return_request = get_object_or_404(ReturnRequest, id=pk)
            
            ReturnService.approve_return_request(return_request)
            
            serializer = ReturnRequestSerializer(return_request)
            
            return Response({
                'success': True,
                'message': 'Return request approved successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except ValueError as e:
            return Response({
                'success': False,
                'message': str(e)
            }, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error(f"Error approving return request: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to approve return request',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class AssignDeliveryManagerView(APIView):
    """
    API view for admin to assign a delivery manager to a return request
    """
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def post(self, request, pk):
        try:
            return_request = get_object_or_404(ReturnRequest, id=pk)
            
            serializer = ReturnRequestAssignSerializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            
            delivery_manager_id = serializer.validated_data['delivery_manager_id']
            ReturnService.assign_delivery_manager(return_request, delivery_manager_id)
            
            response_serializer = ReturnRequestSerializer(return_request)
            
            return Response({
                'success': True,
                'message': 'Delivery manager assigned successfully',
                'data': response_serializer.data
            }, status=status.HTTP_200_OK)
            
        except ValueError as e:
            return Response({
                'success': False,
                'message': str(e)
            }, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error(f"Error assigning delivery manager: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to assign delivery manager',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class AcceptReturnRequestView(APIView):
    """
    API view for delivery manager to accept a return request
    """
    permission_classes = [permissions.IsAuthenticated, IsDeliveryAdmin]
    
    def post(self, request, pk):
        try:
            return_request = get_object_or_404(ReturnRequest, id=pk)
            
            # Check if return request is assigned to this delivery manager
            if return_request.delivery_manager != request.user:
                return Response({
                    'success': False,
                    'message': 'This return request is not assigned to you'
                }, status=status.HTTP_403_FORBIDDEN)
            
            ReturnService.accept_return_request(return_request)
            
            serializer = ReturnRequestSerializer(return_request)
            
            return Response({
                'success': True,
                'message': 'Return request accepted successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except ValueError as e:
            return Response({
                'success': False,
                'message': str(e)
            }, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error(f"Error accepting return request: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to accept return request',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class StartReturnProcessView(APIView):
    """
    API view for delivery manager to start the return process
    """
    permission_classes = [permissions.IsAuthenticated, IsDeliveryAdmin]
    
    def post(self, request, pk):
        try:
            return_request = get_object_or_404(ReturnRequest, id=pk)
            
            # Check if return request is assigned to this delivery manager
            if return_request.delivery_manager != request.user:
                return Response({
                    'success': False,
                    'message': 'This return request is not assigned to you'
                }, status=status.HTTP_403_FORBIDDEN)
            
            ReturnService.start_return_process(return_request)
            
            # Refresh from database to ensure we have the latest data including picked_up_at
            return_request.refresh_from_db()
            
            serializer = ReturnRequestSerializer(return_request)
            
            return Response({
                'success': True,
                'message': 'Return process started successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except ValueError as e:
            return Response({
                'success': False,
                'message': str(e)
            }, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error(f"Error starting return process: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to start return process',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class CompleteReturnRequestView(APIView):
    """
    API view for delivery manager to complete the return request
    """
    permission_classes = [permissions.IsAuthenticated, IsDeliveryAdmin]
    
    def post(self, request, pk):
        try:
            return_request = get_object_or_404(ReturnRequest, id=pk)
            
            # Check if return request is assigned to this delivery manager
            if return_request.delivery_manager != request.user:
                return Response({
                    'success': False,
                    'message': 'This return request is not assigned to you'
                }, status=status.HTTP_403_FORBIDDEN)
            
            ReturnService.complete_return_request(return_request)
            
            serializer = ReturnRequestSerializer(return_request)
            
            return Response({
                'success': True,
                'message': 'Return request completed successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except ValueError as e:
            return Response({
                'success': False,
                'message': str(e)
            }, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error(f"Error completing return request: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to complete return request',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class DeliveryManagersListView(APIView):
    """
    API view to get list of delivery managers for assignment
    """
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def get(self, request):
        try:
            delivery_managers = User.objects.filter(
                user_type='delivery_admin',
                is_active=True
            ).select_related('profile', 'delivery_profile')
            
            managers_data = []
            for manager in delivery_managers:
                # Get delivery status from delivery_profile
                delivery_status = 'offline'
                if hasattr(manager, 'delivery_profile') and manager.delivery_profile:
                    delivery_status = manager.delivery_profile.delivery_status or 'offline'
                
                # Determine status display and color
                status_display = delivery_status.capitalize()
                if delivery_status == 'online':
                    status_display = 'Online'
                    status_color = 'green'
                elif delivery_status == 'busy':
                    status_display = 'Busy'
                    status_color = 'orange'
                else:
                    status_display = 'Offline'
                    status_color = 'grey'
                
                # Get phone number from profile
                phone_number = ''
                if hasattr(manager, 'profile') and manager.profile:
                    phone_number = manager.profile.phone_number or ''
                
                managers_data.append({
                    'id': manager.id,
                    'full_name': manager.get_full_name(),
                    'name': manager.get_full_name(),  # Keep for backward compatibility
                    'email': manager.email,
                    'phone': phone_number,
                    'phone_number': phone_number,
                    'status': delivery_status,
                    'status_text': status_display,
                    'status_display': status_display,
                    'status_color': status_color,
                    'is_available': delivery_status in ['online', 'available'],
                })
            
            return Response({
                'success': True,
                'message': 'Delivery managers retrieved successfully',
                'data': managers_data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving delivery managers: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve delivery managers',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# =====================================
# FINE MANAGEMENT VIEWS FOR RETURNS
# =====================================

class BookReturnWithFineView(APIView):
    """
    API view for processing book returns with fines (Delivery Manager)
    POST /api/returns/requests/<return_id>/return-with-fine/
    """
    permission_classes = [permissions.IsAuthenticated, IsDeliveryAdmin]
    
    def post(self, request, pk):
        """
        Process book return when customer returns overdue book
        """
        try:
            return_request = get_object_or_404(ReturnRequest, id=pk)
            
            # Process the return with fine handling
            result = ReturnService.process_return_with_fine(return_request, request.user)
            
            # Refresh return request
            return_request.refresh_from_db()
            serializer = ReturnRequestSerializer(return_request)
            
            return Response({
                'success': True,
                'message': result['message'],
                'data': {
                    'return_request': serializer.data,
                    'fine_amount': result['fine_amount'],
                    'has_fine': result['has_fine'],
                    'deposit_frozen': result['deposit_frozen']
                }
            }, status=status.HTTP_200_OK)
                
        except ValueError as e:
            logger.warning(f"Business logic error processing return with fine {pk}: {str(e)}")
            return Response({
                'success': False,
                'message': str(e),
                'errors': format_error_message(str(e))
            }, status=status.HTTP_400_BAD_REQUEST)
        except ReturnRequest.DoesNotExist:
            return Response({
                'success': False,
                'message': 'Return request not found'
            }, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"Error processing book return: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to process book return',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class FinePaymentView(APIView):
    """
    API view for processing fine payments for return requests (Customer)
    POST /api/returns/requests/<return_id>/pay-fine/
    """
    permission_classes = [permissions.IsAuthenticated, IsCustomer]
    
    def post(self, request, pk):
        """
        Process fine payment for overdue borrowing related to return request
        """
        try:
            return_request = get_object_or_404(ReturnRequest, id=pk)
            
            # Check if user owns this return request
            if return_request.borrowing.customer != request.user:
                return Response({
                    'success': False,
                    'message': 'You can only pay fines for your own return requests'
                }, status=status.HTTP_403_FORBIDDEN)
            
            payment_method = request.data.get('payment_method', 'wallet')
            
            # Process the fine payment using ReturnService
            result = ReturnService.process_fine_payment_for_return(return_request, payment_method)
            
            # Refresh return request
            return_request.refresh_from_db()
            serializer = ReturnRequestSerializer(return_request)
            
            return Response({
                'success': True,
                'message': result['message'],
                'data': {
                    'return_request': serializer.data,
                    'fine_amount': result['fine_amount'],
                    'refund_amount': result['refund_amount'],
                    'deposit_refunded': result['deposit_refunded']
                }
            }, status=status.HTTP_200_OK)
                
        except ValueError as e:
            logger.warning(f"Business logic error processing fine payment for return {pk}: {str(e)}")
            return Response({
                'success': False,
                'message': str(e),
                'errors': format_error_message(str(e))
            }, status=status.HTTP_400_BAD_REQUEST)
        except ReturnRequest.DoesNotExist:
            return Response({
                'success': False,
                'message': 'Return request not found'
            }, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"Error processing fine payment: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to process fine payment',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class CustomerFinesView(generics.ListAPIView):
    """
    API view for customers to view their fines related to return requests
    GET /api/returns/fines/my-fines/
    """
    permission_classes = [permissions.IsAuthenticated, IsCustomer]
    serializer_class = BorrowFineSerializer
    
    def get_queryset(self):
        """Get customer's fines from return requests"""
        user = self.request.user
        
        # Get fines from borrow requests that have return requests
        return BorrowFine.objects.filter(
            borrow_request__customer=user,
            borrow_request__return_requests__isnull=False
        ).select_related('borrow_request', 'borrow_request__book').order_by('-created_at')
    
    def list(self, request, *args, **kwargs):
        try:
            queryset = self.get_queryset()
            serializer = self.get_serializer(queryset, many=True)
            
            # Calculate total unpaid fines
            total_unpaid = sum(
                fine.total_amount for fine in queryset.filter(status=FineStatusChoices.UNPAID)
            )
            
            return Response({
                'success': True,
                'message': 'Fines retrieved successfully',
                'data': serializer.data,
                'summary': {
                    'total_unpaid': float(total_unpaid),
                    'total_fines': queryset.count(),
                    'has_unpaid_fines': total_unpaid > 0
                }
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving fines: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve fines',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class MarkFineAsPaidView(APIView):
    """
    API view for delivery managers to mark fine as paid/not paid for return requests
    POST /api/returns/fines/mark-paid/
    """
    permission_classes = [permissions.IsAuthenticated, IsDeliveryAdmin]
    
    def post(self, request):
        try:
            return_request_id = request.data.get('return_request_id')
            fine_paid = request.data.get('fine_paid', False)
            payment_method = request.data.get('payment_method', '')
            payment_notes = request.data.get('payment_notes', '')
            
            if not return_request_id:
                return Response({
                    'success': False,
                    'message': 'return_request_id is required'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            return_request = get_object_or_404(ReturnRequest, id=return_request_id)
            borrow_request = return_request.borrowing
            
            # Check if delivery manager owns this return request
            if return_request.delivery_manager != request.user:
                return Response({
                    'success': False,
                    'message': 'You can only mark fines for your assigned return requests'
                }, status=status.HTTP_403_FORBIDDEN)
            
            try:
                fine = BorrowFine.objects.get(borrow_request=borrow_request)
            except BorrowFine.DoesNotExist:
                return Response({
                    'success': False,
                    'message': 'No fine found for this return request'
                }, status=status.HTTP_404_NOT_FOUND)
            
            if fine_paid:
                fine.mark_as_paid(request.user)
                message = 'Fine marked as paid successfully'
            else:
                # Mark as unpaid (if needed)
                fine.status = FineStatusChoices.UNPAID
                fine.save()
                message = 'Fine marked as unpaid'
            
            serializer = BorrowFineSerializer(fine)
            
            return Response({
                'success': True,
                'message': message,
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error marking fine as paid: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to mark fine',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class AllFinesView(generics.ListAPIView):
    """
    API view for admins to view all fines related to return requests
    GET /api/returns/fines/all/
    """
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    serializer_class = BorrowFineSerializer
    
    def get_queryset(self):
        """Get all fines from return requests"""
        queryset = BorrowFine.objects.filter(
            borrow_request__return_requests__isnull=False
        ).select_related(
            'borrow_request', 'borrow_request__book', 'borrow_request__customer'
        ).distinct().order_by('-created_at')
        
        # Filter by status if provided
        status_filter = self.request.query_params.get('status', None)
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        
        return queryset
    
    def list(self, request, *args, **kwargs):
        try:
            queryset = self.get_queryset()
            serializer = self.get_serializer(queryset, many=True)
            
            # Calculate summary
            total_fines = queryset.count()
            unpaid_fines = queryset.filter(status=FineStatusChoices.UNPAID).count()
            paid_fines = queryset.filter(status=FineStatusChoices.PAID).count()
            total_amount = sum(float(fine.total_amount) for fine in queryset)
            unpaid_amount = sum(
                float(fine.total_amount) for fine in queryset.filter(status=FineStatusChoices.UNPAID)
            )
            
            return Response({
                'success': True,
                'message': 'Fines retrieved successfully',
                'data': serializer.data,
                'summary': {
                    'total_fines': total_fines,
                    'unpaid_fines': unpaid_fines,
                    'paid_fines': paid_fines,
                    'total_amount': total_amount,
                    'unpaid_amount': unpaid_amount
                }
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving fines: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve fines',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


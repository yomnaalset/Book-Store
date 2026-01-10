from rest_framework import generics, status, permissions
from rest_framework.response import Response
from rest_framework.views import APIView
from django.shortcuts import get_object_or_404
from django.db.models import Q
from django.utils import timezone

from ..models.return_model import ReturnRequest, ReturnStatus, ReturnFine, ReturnFinePaymentMethod
from ..models.borrowing_model import BorrowRequest, FineStatusChoices
from ..models.user_model import User
from ..serializers.return_serializers import (
    ReturnRequestSerializer,
    ReturnRequestCreateSerializer,
    ReturnRequestApprovalSerializer,
    ReturnRequestAssignSerializer,
    ReturnFineSerializer
)
from ..services.return_services import ReturnService
from ..services.notification_services import NotificationService
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
        
        return queryset.select_related(
            'borrowing', 
            'borrowing__customer', 
            'borrowing__customer__profile',  # Prefetch customer profile for phone number
            'borrowing__book', 
            'delivery_manager',
            'delivery_manager__profile'  # Prefetch delivery manager profile for phone number
        ).order_by('-created_at')
    
    def list(self, request, *args, **kwargs):
        try:
            queryset = self.get_queryset()
            # Pass request context to serializer so it can determine user role for delivery_request serialization
            serializer = self.get_serializer(queryset, many=True, context={'request': request})
            
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
            
            # Get borrowing request
            borrow_request = instance.borrowing
            
            # Always recalculate fine based on expected return date vs current date
            # This ensures admin sees the same calculation as customer
            return_fine = ReturnService.get_or_create_return_fine(instance)
            
            # Note: Borrowing never generates fines. Only return requests can have fines.
            # All fines are stored in ReturnFine linked to return_request.
            
            # Pass request context to serializer so it can determine user role for delivery_request serialization
            serializer = self.get_serializer(instance, context={'request': request})
            data = serializer.data
            
            # Calculate if delay exists based on expected return date
            # Use the exact expected_return_date from database, compare with current date
            has_delay = False
            if borrow_request.expected_return_date:
                from django.utils import timezone
                current_date = timezone.now().date()
                expected_date = borrow_request.expected_return_date.date() if hasattr(borrow_request.expected_return_date, 'date') else borrow_request.expected_return_date
                has_delay = current_date > expected_date
            
            # Determine if penalty exists: ReturnFine is the single source of truth
            # Business Rule: No fine record exists if fine_amount = 0
            has_penalty = return_fine is not None and return_fine.fine_amount and float(return_fine.fine_amount) > 0
            
            # Get payment information from ReturnFine
            payment_method = return_fine.payment_method if return_fine else None
            payment_status = 'paid' if (return_fine and return_fine.is_paid) else 'pending' if return_fine else None
            
            # Determine penalty amount and days from ReturnFine
            if has_penalty and return_fine:
                penalty_amount = float(return_fine.fine_amount)
                overdue_days = return_fine.days_late if return_fine.late_return else 0
            else:
                penalty_amount = 0.0
                overdue_days = 0
            
            # Add penalty and payment information to response
            data['penalty_amount'] = penalty_amount if has_penalty else 0.0
            data['overdue_days'] = overdue_days if has_penalty else 0
            data['has_penalty'] = has_penalty
            data['payment_method'] = payment_method if has_penalty else None
            data['payment_status'] = payment_status if has_penalty else None
            data['due_date'] = borrow_request.expected_return_date.isoformat() if borrow_request.expected_return_date else None
            data['is_finalized'] = return_fine.is_finalized if has_penalty else False
            
            # Keep fine details for backward compatibility
            if return_fine:
                data['fine'] = {
                    'id': return_fine.id,
                    'days_late': return_fine.days_late,
                    'fine_amount': str(return_fine.fine_amount),
                    'fine_reason': return_fine.fine_reason,
                    'late_return': return_fine.late_return,
                    'damaged': return_fine.damaged,
                    'lost': return_fine.lost,
                    'payment_method': return_fine.payment_method,
                    'payment_status': 'paid' if return_fine.is_paid else 'pending',
                    'paid_at': return_fine.paid_at.isoformat() if return_fine.paid_at else None,
                    'transaction_id': return_fine.transaction_id
                }
            else:
                data['fine'] = None
            
            return Response({
                'success': True,
                'message': 'Return request retrieved successfully',
                'data': data
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
            
            # Call the service method (which is wrapped in @transaction.atomic)
            # This will commit the transaction at the end
            ReturnService.assign_delivery_manager(return_request, delivery_manager_id)
            
            # IMPORTANT: The transaction has now committed, so we can safely query fresh data
            # Refresh from database to ensure we have the latest data
            return_request.refresh_from_db()
            
            # Debug: Log the state after assignment
            logger.info(f"=== AssignDeliveryManagerView DEBUG ===")
            logger.info(f"  return_request.id: {return_request.id}")
            logger.info(f"  return_request.status: {return_request.status}")
            logger.info(f"  return_request.delivery_manager: {return_request.delivery_manager}")
            logger.info(f"  return_request.delivery_manager_id: {return_request.delivery_manager_id if hasattr(return_request, 'delivery_manager_id') else 'N/A'}")
            
            # Check DeliveryRequest status - query FRESH from DB after transaction commit
            from ..models.delivery_model import DeliveryRequest
            from django.db import connection
            # Force a fresh database query (bypass any connection-level caching)
            with connection.cursor() as cursor:
                cursor.execute(
                    "SELECT id, status, delivery_manager_id FROM delivery_request "
                    "WHERE return_request_id = %s AND delivery_type = 'return'",
                    [return_request.id]
                )
                row = cursor.fetchone()
                if row:
                    delivery_req_id, delivery_req_status, delivery_mgr_id = row
                    logger.info(f"  DeliveryRequest.id: {delivery_req_id}")
                    logger.info(f"  DeliveryRequest.status (from raw SQL): '{delivery_req_status}'")
                    logger.info(f"  DeliveryRequest.delivery_manager_id: {delivery_mgr_id}")
                else:
                    logger.info(f"  DeliveryRequest: NOT FOUND (raw SQL)")
            
            # Also check via ORM for comparison
            delivery_req = DeliveryRequest.objects.filter(
                return_request=return_request,
                delivery_type='return'
            ).first()
            if delivery_req:
                logger.info(f"  DeliveryRequest.id (ORM): {delivery_req.id}")
                logger.info(f"  DeliveryRequest.status (ORM): '{delivery_req.status}'")
                logger.info(f"  DeliveryRequest.delivery_manager (ORM): {delivery_req.delivery_manager}")
            else:
                logger.info(f"  DeliveryRequest: NOT FOUND (ORM)")
            logger.info(f"=== END DEBUG ===")
            
            # Force a completely fresh query to ensure we have the latest DeliveryRequest
            # This ensures the serializer's get_delivery_request_status gets fresh data
            return_request = ReturnRequest.objects.select_related(
                'borrowing',
                'borrowing__customer',
                'borrowing__customer__profile',
                'borrowing__book',
                'delivery_manager',
                'delivery_manager__profile'
            ).prefetch_related().get(id=return_request.id)
            
            response_serializer = ReturnRequestSerializer(return_request, context={'request': request})
            
            # Log what status is being returned
            delivery_status_in_response = response_serializer.data.get('delivery_request_status')
            logger.info(
                f"AssignDeliveryManagerView: Serialized data includes "
                f"delivery_request_status='{delivery_status_in_response}'"
            )
            
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
            
            # Get delivery manager status for consistency validation
            delivery_manager_status = None
            if return_request.delivery_manager:
                try:
                    from ..models.delivery_profile_model import DeliveryProfile
                    delivery_profile = DeliveryProfile.objects.get(user=return_request.delivery_manager)
                    delivery_manager_status = delivery_profile.delivery_status
                except DeliveryProfile.DoesNotExist:
                    pass
            
            serializer = ReturnRequestSerializer(return_request)
            
            return Response({
                'success': True,
                'message': 'Return process started successfully',
                'data': {
                    'return_request': serializer.data,
                    'delivery_manager_status': delivery_manager_status  # Include for frontend validation
                }
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
            
            # Refresh from database to ensure we have the latest data
            return_request.refresh_from_db()
            
            # Get delivery manager status for consistency validation
            # Status should be 'online' if no other active tasks, 'busy' if others exist
            delivery_manager_status = None
            if return_request.delivery_manager:
                try:
                    from ..models.delivery_profile_model import DeliveryProfile
                    delivery_profile = DeliveryProfile.objects.get(user=return_request.delivery_manager)
                    delivery_manager_status = delivery_profile.delivery_status
                except DeliveryProfile.DoesNotExist:
                    pass
            
            serializer = ReturnRequestSerializer(return_request)
            
            return Response({
                'success': True,
                'message': 'Return request completed successfully',
                'data': {
                    'return_request': serializer.data,
                    'delivery_manager_status': delivery_manager_status  # Include for frontend validation
                }
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
    Returns both BorrowFine and ReturnFine objects
    """
    permission_classes = [permissions.IsAuthenticated, IsCustomer]
    serializer_class = ReturnFineSerializer
    
    def list(self, request, *args, **kwargs):
        try:
            user = request.user
            
            # Get all fines for return requests (borrowing never generates fines)
            all_fines = ReturnFine.objects.filter(
                return_request__borrowing__customer=user,
                fine_amount__gt=0
            ).select_related(
                'return_request', 'return_request__borrowing', 'return_request__borrowing__book'
            ).order_by('-created_at')
            
            # Serialize all fines
            serializer = ReturnFineSerializer(all_fines, many=True)
            all_fines_data = serializer.data
            
            # Sort by created_date (most recent first)
            all_fines_data.sort(key=lambda x: x.get('created_date', ''), reverse=True)
            
            # Calculate total unpaid fines
            total_unpaid = sum(
                float(fine.fine_amount) for fine in all_fines.filter(is_paid=False)
            )
            
            return Response({
                'success': True,
                'message': 'Fines retrieved successfully',
                'data': all_fines_data,
                'summary': {
                    'total_unpaid': float(total_unpaid),
                    'total_fines': len(all_fines_data),
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
                fine = ReturnFine.objects.get(return_request=return_request)
            except ReturnFine.DoesNotExist:
                return Response({
                    'success': False,
                    'message': 'No fine found for this return request'
                }, status=status.HTTP_404_NOT_FOUND)
            
            if fine_paid:
                fine.mark_as_paid(request.user)
                message = 'Fine marked as paid successfully'
            else:
                # Mark as unpaid (if needed)
                fine.is_paid = False
                fine.paid_at = None
                fine.paid_by = None
                fine.save()
                message = 'Fine marked as unpaid'
            
            serializer = ReturnFineSerializer(fine)
            
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
    serializer_class = ReturnFineSerializer
    
    def get_queryset(self):
        """Get all fines for return requests (borrowing never generates fines)"""
        queryset = ReturnFine.objects.all().select_related(
            'return_request', 'return_request__borrowing', 'return_request__borrowing__book', 'return_request__borrowing__customer'
        ).order_by('-created_at')
        
        # Filter by payment status if provided
        status_filter = self.request.query_params.get('status', None)
        if status_filter:
            # Map status values to is_paid boolean
            if status_filter.lower() == 'paid':
                queryset = queryset.filter(is_paid=True)
            elif status_filter.lower() == 'unpaid':
                queryset = queryset.filter(is_paid=False)
        
        return queryset
    
    def list(self, request, *args, **kwargs):
        try:
            queryset = self.get_queryset()
            serializer = self.get_serializer(queryset, many=True)
            
            # Calculate summary
            total_fines = queryset.count()
            unpaid_fines = queryset.filter(is_paid=False).count()
            paid_fines = queryset.filter(is_paid=True).count()
            total_amount = sum(float(fine.fine_amount) for fine in queryset)
            unpaid_amount = sum(
                float(fine.fine_amount) for fine in queryset.filter(is_paid=False)
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


class GetReturnDeliveryLocationView(APIView):
    """
    API view to get current delivery manager location for return request tracking
    GET /api/returns/requests/{return_request_id}/delivery-location/
    Visible only during IN_PROGRESS status
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request, pk):
        try:
            return_request = get_object_or_404(ReturnRequest, id=pk)
            
            # Check permissions - customer can see their own, admin can see all
            borrow_request = return_request.borrowing
            if (borrow_request.customer != request.user and 
                not request.user.is_library_admin() and 
                not request.user.is_delivery_admin()):
                return Response({
                    'success': False,
                    'message': 'Permission denied',
                    'errors': {'permission': ['You do not have permission to view this location']}
                }, status=status.HTTP_403_FORBIDDEN)
            
            # UNIFIED DELIVERY STATUS: Location button is VISIBLE only when DeliveryRequest.status = 'in_delivery'
            # Check delivery request status (source of truth) instead of return request status
            from ..models.delivery_model import DeliveryRequest
            delivery_request = DeliveryRequest.objects.filter(
                return_request=return_request,
                delivery_type='return'
            ).select_related(
                'delivery_manager',
                'delivery_manager__delivery_profile'
            ).first()
            
            if not delivery_request:
                return Response({
                    'success': False,
                    'message': 'No delivery request found for this return',
                    'errors': {'delivery': ['Delivery request not created yet']},
                    'current_status': return_request.status,
                    'tracking_available': False
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Check delivery request status (unified approach)
            if delivery_request.status != 'in_delivery':
                return Response({
                    'success': False,
                    'message': 'Location tracking is not available for this request',
                    'errors': {'status': ['Location tracking is only available when delivery is in progress']},
                    'current_delivery_status': delivery_request.status,
                    'current_return_status': return_request.status,
                    'tracking_available': False
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Get delivery manager from delivery request (unified approach)
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
                    'return_request_id': return_request.id,
                    'status': return_request.status,
                    'delivery_manager': delivery_manager_info,
                    'location': location_data,
                    'tracking_enabled': True,
                    'tracking_interval_seconds': 5
                }
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error getting return delivery location: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to get delivery location',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class SelectReturnFinePaymentMethodView(APIView):
    """
    API view for customers to select payment method for return fine
    POST /api/returns/fines/{fine_id}/select-payment-method/
    """
    permission_classes = [permissions.IsAuthenticated, IsCustomer]
    
    def post(self, request, fine_id):
        """
        Select payment method (cash or card) for a return fine
        """
        try:
            # Use raw SQL to avoid column issues with late_return, damaged, lost
            from django.db import connection
            with connection.cursor() as cursor:
                cursor.execute("""
                    SELECT rf.id, rf.return_request_id, rf.is_paid, rf.payment_method,
                           rr.id as return_request_id, br.customer_id
                    FROM return_fine rf
                    JOIN return_request rr ON rf.return_request_id = rr.id
                    JOIN borrow_request br ON rr.borrowing_id = br.id
                    WHERE rf.id = %s
                """, [fine_id])
                row = cursor.fetchone()
            
            if not row:
                return Response({
                    'success': False,
                    'message': 'Fine not found'
                }, status=status.HTTP_404_NOT_FOUND)
            
            fine_data = {
                'id': row[0],
                'return_request_id': row[1],
                'is_paid': bool(row[2]),
                'payment_method': row[3],
                'customer_id': row[5]
            }
            
            # Check if user owns this return request
            if fine_data['customer_id'] != request.user.id:
                return Response({
                    'success': False,
                    'message': 'You can only select payment method for your own return fines'
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Get payment method from request
            payment_method = request.data.get('payment_method', '').lower()
            
            if payment_method not in ['cash', 'card']:
                return Response({
                    'success': False,
                    'message': 'Invalid payment method. Must be "cash" or "card"'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Update fine with payment method and finalize it (lock the amount)
            with connection.cursor() as cursor:
                cursor.execute("""
                    UPDATE return_fine SET payment_method = %s, is_finalized = %s WHERE id = %s
                """, [payment_method, True, fine_id])
                
                # Get the fine amount to sync to borrow request
                cursor.execute("""
                    SELECT rf.fine_amount, rr.borrowing_id
                    FROM return_fine rf
                    JOIN return_request rr ON rf.return_request_id = rr.id
                    WHERE rf.id = %s
                """, [fine_id])
                fine_row = cursor.fetchone()
                
                if fine_row:
                    fine_amount = fine_row[0]
                    borrowing_id = fine_row[1]
                    # Update the borrow request with the finalized fine amount
                    cursor.execute("""
                        UPDATE borrow_request SET fine_amount = %s WHERE id = %s
                    """, [fine_amount, borrowing_id])
            
            return Response({
                'success': True,
                'message': f'Payment method selected: {payment_method}',
                'data': {
                    'fine_id': fine_id,
                    'payment_method': payment_method,
                    'payment_status': 'paid' if fine_data['is_paid'] else 'pending'
                }
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error selecting payment method: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to select payment method',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class CustomerConfirmReturnPickupView(APIView):
    """
    API view for customers to confirm they are ready for return pickup
    POST /api/returns/requests/{return_request_id}/confirm-pickup/
    """
    permission_classes = [permissions.IsAuthenticated, IsCustomer]
    
    def post(self, request, pk):
        """
        Confirm that customer is ready for the delivery manager to pick up the book
        """
        try:
            from django.db import connection
            
            # Get return request and verify ownership
            with connection.cursor() as cursor:
                cursor.execute("""
                    SELECT rr.id, rr.status, br.customer_id, br.id as borrowing_id,
                           rf.id as fine_id, rf.payment_method, rf.is_finalized
                    FROM return_request rr
                    JOIN borrow_request br ON rr.borrowing_id = br.id
                    LEFT JOIN return_fine rf ON rf.return_request_id = rr.id
                    WHERE rr.id = %s
                """, [pk])
                row = cursor.fetchone()
            
            if not row:
                return Response({
                    'success': False,
                    'message': 'Return request not found'
                }, status=status.HTTP_404_NOT_FOUND)
            
            return_request_id = row[0]
            current_status = row[1]
            customer_id = row[2]
            borrowing_id = row[3]
            fine_id = row[4]
            payment_method = row[5]
            is_finalized = bool(row[6]) if row[6] is not None else False
            
            # Check ownership
            if customer_id != request.user.id:
                return Response({
                    'success': False,
                    'message': 'You can only confirm pickup for your own return requests'
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Check if payment method is selected (required before confirming pickup)
            if not payment_method:
                return Response({
                    'success': False,
                    'message': 'Please select a payment method before confirming pickup'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Update return request status to indicate customer is ready for pickup
            with connection.cursor() as cursor:
                cursor.execute("""
                    UPDATE return_request 
                    SET status = 'PENDING', updated_at = NOW()
                    WHERE id = %s
                """, [return_request_id])
                
                # Also update borrow request status
                cursor.execute("""
                    UPDATE borrow_request 
                    SET status = 'pending_return', updated_at = NOW()
                    WHERE id = %s
                """, [borrowing_id])
            
            # Create notification for library admin
            try:
                from ..services.notification_services import NotificationService
                from ..models.user_model import CustomUser
                
                # Get customer name
                customer = CustomUser.objects.get(id=customer_id)
                
                # Notify all library admins
                admins = CustomUser.objects.filter(user_type='admin')
                for admin in admins:
                    NotificationService.create_notification(
                        user_id=admin.id,
                        title="Return Pickup Requested",
                        message=f"Customer {customer.get_full_name()} has confirmed they are ready for book return pickup. Payment method: {payment_method}.",
                        notification_type="return_pickup_requested"
                    )
            except Exception as notif_error:
                logger.warning(f"Could not send notification: {str(notif_error)}")
            
            return Response({
                'success': True,
                'message': 'Return pickup confirmed. The delivery manager will contact you soon.',
                'data': {
                    'return_request_id': return_request_id,
                    'status': 'PENDING',
                    'payment_method': payment_method
                }
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error confirming return pickup: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to confirm return pickup',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class ConfirmCardPaymentView(APIView):
    """
    API view for customers to confirm card payment for return fine
    POST /api/returns/fines/{fine_id}/confirm-card-payment/
    """
    permission_classes = [permissions.IsAuthenticated, IsCustomer]
    
    def post(self, request, fine_id):
        """
        Confirm card payment for a return fine
        """
        try:
            fine = get_object_or_404(ReturnFine, id=fine_id)
            return_request = fine.return_request
            
            # Check if user owns this return request
            if return_request.borrowing.customer != request.user:
                return Response({
                    'success': False,
                    'message': 'You can only confirm payment for your own return fines'
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Check if payment method is card
            if fine.payment_method != ReturnFinePaymentMethod.CARD:
                return Response({
                    'success': False,
                    'message': 'Payment method is not card'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Get card data from request
            card_data = request.data.get('card_data', {})
            transaction_id = request.data.get('transaction_id', f'TXN-{fine.id}-{timezone.now().timestamp()}')
            
            # TODO: Integrate with actual payment gateway here
            # For now, we'll simulate successful payment
            
            # Mark fine as paid
            fine.mark_as_paid(paid_by=request.user, transaction_id=transaction_id)
            
            # Send success notification to customer
            return_request = fine.return_request
            borrow_request = return_request.borrowing
            NotificationService.create_notification(
                user_id=borrow_request.customer.id,
                title="Fine Payment Successful",
                message="Your fine has been successfully paid. You may now borrow books again.",
                notification_type="fine_paid"
            )
            
            return Response({
                'success': True,
                'message': 'Card payment confirmed successfully',
                'data': {
                    'fine_id': fine.id,
                    'payment_status': 'paid' if fine.is_paid else 'pending',
                    'transaction_id': fine.transaction_id,
                    'paid_at': fine.paid_at
                }
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error confirming card payment: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to confirm card payment',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class ConfirmReturnFineView(APIView):
    """
    API view for admin to confirm/finalize a return fine
    POST /api/returns/requests/<return_request_id>/confirm-fine/
    """
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def post(self, request, pk):
        """
        Confirm and finalize a return fine
        Makes the fine permanent and non-modifiable
        """
        try:
            from django.db import connection
            
            return_request = get_object_or_404(ReturnRequest, id=pk)
            return_fine = ReturnService.get_or_create_return_fine(return_request)
            
            if not return_fine:
                return Response({
                    'success': False,
                    'message': 'No fine found for this return request'
                }, status=status.HTTP_404_NOT_FOUND)
            
            # Check if fine is already finalized
            if return_fine.is_finalized:
                return Response({
                    'success': False,
                    'message': 'Fine has already been confirmed'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Finalize the fine using raw SQL (since return_fine may be a minimal object)
            finalized_at = timezone.now()
            with connection.cursor() as cursor:
                cursor.execute("""
                    UPDATE return_fine 
                    SET is_finalized = %s, finalized_at = %s, finalized_by_id = %s, is_paid = %s
                    WHERE id = %s
                """, [True, finalized_at, request.user.id, False, return_fine.id])
                
                # Also update borrow request fine_amount
                cursor.execute("""
                    UPDATE borrow_request 
                    SET fine_amount = %s 
                    WHERE id = %s
                """, [str(return_fine.fine_amount), return_request.borrowing.id])
            
            # Send notification to customer
            borrow_request = return_request.borrowing
            NotificationService.create_notification(
                user_id=borrow_request.customer.id,
                title="A New Fine Has Been Added",
                message="A new fine has been added due to late book return. You must pay the fine to continue using borrowing services.",
                notification_type="fine_added"
            )
            
            serializer = ReturnRequestSerializer(return_request)
            
            return Response({
                'success': True,
                'message': 'Fine has been successfully confirmed',
                'data': {
                    'return_request': serializer.data,
                    'fine_id': return_fine.id,
                    'fine_amount': float(return_fine.fine_amount),
                    'is_finalized': True
                }
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error confirming return fine: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to confirm fine',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class IncreaseReturnFineView(APIView):
    """
    API view for admin to increase a return fine
    POST /api/returns/requests/<return_request_id>/increase-fine/
    """
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def post(self, request, pk):
        """
        Increase the fine amount by an additional amount
        """
        try:
            return_request = get_object_or_404(ReturnRequest, id=pk)
            return_fine = ReturnService.get_or_create_return_fine(return_request)
            
            # Check if fine is finalized
            if return_fine.is_finalized:
                return Response({
                    'success': False,
                    'message': 'Cannot increase a confirmed fine'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Get additional amount from request
            additional_amount = request.data.get('additional_amount')
            if additional_amount is None:
                return Response({
                    'success': False,
                    'message': 'additional_amount is required'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            try:
                additional_amount = float(additional_amount)
                if additional_amount <= 0:
                    return Response({
                        'success': False,
                        'message': 'Additional amount must be greater than 0'
                    }, status=status.HTTP_400_BAD_REQUEST)
            except (ValueError, TypeError):
                return Response({
                    'success': False,
                    'message': 'Invalid additional_amount value'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Increase the fine amount using raw SQL
            from decimal import Decimal
            from django.db import connection
            
            current_amount = Decimal(str(return_fine.fine_amount))
            additional = Decimal(str(additional_amount))
            new_amount = current_amount + additional
            
            with connection.cursor() as cursor:
                cursor.execute("""
                    UPDATE return_fine 
                    SET fine_amount = %s, is_paid = %s 
                    WHERE id = %s
                """, [str(new_amount), False, return_fine.id])
                
                # Also update borrow request fine_amount
                cursor.execute("""
                    UPDATE borrow_request 
                    SET fine_amount = %s 
                    WHERE id = %s
                """, [str(new_amount), return_request.borrowing.id])
            
            # Send notification to customer
            borrow_request = return_request.borrowing
            NotificationService.create_notification(
                user_id=borrow_request.customer.id,
                title="A New Fine Has Been Added",
                message="A new fine has been added due to late book return. You must pay the fine to continue using borrowing services.",
                notification_type="fine_added"
            )
            
            return Response({
                'success': True,
                'message': f'Fine increased by ${additional_amount:.2f}',
                'data': {
                    'return_request_id': return_request.id,
                    'fine_id': return_fine.id,
                    'previous_amount': float(current_amount),
                    'additional_amount': float(additional),
                    'new_fine_amount': float(new_amount)
                }
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error increasing return fine: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to increase fine',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class ConfirmCashPaymentView(APIView):
    """
    API view for delivery managers to confirm cash payment for return fine
    POST /api/returns/fines/{fine_id}/confirm-cash-payment/
    """
    permission_classes = [permissions.IsAuthenticated, IsDeliveryAdmin]
    
    def post(self, request, fine_id):
        """
        Confirm cash payment collected by delivery manager
        """
        try:
            fine = get_object_or_404(ReturnFine, id=fine_id)
            return_request = fine.return_request
            
            # Check if delivery manager is assigned to this return request
            if return_request.delivery_manager != request.user:
                return Response({
                    'success': False,
                    'message': 'You can only confirm cash payment for return requests assigned to you'
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Check if payment method is cash
            if fine.payment_method != ReturnFinePaymentMethod.CASH:
                return Response({
                    'success': False,
                    'message': 'Payment method is not cash'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Mark fine as paid
            fine.mark_as_paid(paid_by=request.user)
            
            # Send success notification to customer
            return_request = fine.return_request
            borrow_request = return_request.borrowing
            NotificationService.create_notification(
                user_id=borrow_request.customer.id,
                title="Fine Payment Successful",
                message="Your fine has been successfully paid. You may now borrow books again.",
                notification_type="fine_paid"
            )
            
            return Response({
                'success': True,
                'message': 'Cash payment confirmed successfully',
                'data': {
                    'fine_id': fine.id,
                    'payment_status': 'paid' if fine.is_paid else 'pending',
                    'paid_at': fine.paid_at,
                    'paid_by': request.user.get_full_name()
                }
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error confirming cash payment: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to confirm cash payment',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
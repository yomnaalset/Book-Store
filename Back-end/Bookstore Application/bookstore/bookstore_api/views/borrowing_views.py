from rest_framework import generics, status, permissions
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.exceptions import ValidationError
from django.shortcuts import get_object_or_404
from django.db.models import Q
from django.utils import timezone, translation
from decimal import Decimal

from ..models import (
    BorrowRequest, BorrowExtension, BorrowStatistics,
    Book, User, BorrowStatusChoices
)
from ..models.return_model import ReturnFine
from ..serializers.return_serializers import ReturnFineSerializer
from ..serializers.borrowing_serializers import (
    BorrowRequestCreateSerializer, BorrowRequestListSerializer, BorrowRequestDetailSerializer,
    AdminBorrowRequestSerializer, BorrowApprovalSerializer, BorrowExtensionCreateSerializer, BorrowExtensionSerializer,
    BorrowRatingSerializer, EarlyReturnSerializer,
    DeliveryUpdateSerializer, MostBorrowedBookSerializer, BorrowingReportSerializer,
    PendingRequestsSerializer, DeliveryReadySerializer, DeliveryManagerSerializer,
    ConfirmPaymentSerializer
)
from ..serializers.delivery_serializers import BorrowingOrderSerializer
from ..services.borrowing_services import (
    BorrowingService, BorrowingNotificationService, BorrowingReportService, LateReturnService
)
from ..services.notification_services import NotificationService
from ..permissions import IsCustomer, IsLibraryAdmin, IsDeliveryAdmin, IsAnyAdmin, CustomerOrAdmin, IsDeliveryAdminOrLibraryAdmin
from ..utils import format_error_message
import logging

logger = logging.getLogger(__name__)


class MostBorrowedBooksView(generics.ListAPIView):
    """
    API view to get most borrowed books
    """
    serializer_class = MostBorrowedBookSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        """Get most borrowed books"""
        return BorrowingService.get_most_borrowed_books(limit=20)
    
    def list(self, request, *args, **kwargs):
        try:
            queryset = self.get_queryset()
            serializer = self.get_serializer(queryset, many=True)
            
            return Response({
                'success': True,
                'message': 'Most borrowed books retrieved successfully',
                'data': serializer.data,
                'pagination': {
                    'page': 1,
                    'per_page': 20,
                    'total': queryset.count(),
                    'total_pages': 1
                }
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving most borrowed books: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve most borrowed books',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class BorrowRequestCreateView(generics.CreateAPIView):
    """
    API view for customers to create borrow requests
    """
    serializer_class = BorrowRequestCreateSerializer
    permission_classes = [permissions.IsAuthenticated, IsCustomer]
    
    def create(self, request, *args, **kwargs):
        try:
            serializer = self.get_serializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            
            book_id = serializer.validated_data['book_id']
            book = get_object_or_404(Book, id=book_id)
            
            borrow_request = BorrowingService.create_borrow_request(
                customer=request.user,
                book=book,
                borrow_period_days=serializer.validated_data['borrow_period_days'],
                delivery_address=serializer.validated_data['delivery_address'],
                additional_notes=serializer.validated_data.get('additional_notes', '')
            )
            
            response_serializer = BorrowRequestDetailSerializer(borrow_request)
            
            return Response({
                'success': True,
                'message': 'Borrowing request submitted successfully',
                'data': response_serializer.data
            }, status=status.HTTP_201_CREATED)
            
        except ValidationError as e:
            # Handle DRF validation errors properly
            logger.error(f"Validation error creating borrow request: {e.detail}")
            return Response({
                'success': False,
                'message': 'Failed to create borrowing request',
                'errors': e.detail  # This is already a properly formatted dict
            }, status=status.HTTP_400_BAD_REQUEST)
        except ValueError as e:
            # Handle business logic errors (like fine blocking)
            logger.error(f"Error creating borrow request: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to create borrowing request',
                'errors': {
                    'non_field_errors': [str(e)]
                }
            }, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error(f"Error creating borrow request: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to create borrowing request',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_400_BAD_REQUEST)


class ConfirmPaymentView(APIView):
    """
    API view for confirming payment for a borrowing request
    POST /api/borrowings/confirm-payment/{id}
    """
    permission_classes = [permissions.IsAuthenticated, IsCustomer]
    
    def post(self, request, pk):
        try:
            # Get the borrow request
            borrow_request = get_object_or_404(BorrowRequest, pk=pk)
            
            # Verify that the request belongs to the current user
            if borrow_request.customer != request.user:
                return Response({
                    'success': False,
                    'message': 'You do not have permission to confirm payment for this request'
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Validate request data
            serializer = ConfirmPaymentSerializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            
            # Prepare card data if payment method is mastercard
            card_data = None
            if serializer.validated_data['payment_method'] == 'mastercard':
                card_data = {
                    'card_number': serializer.validated_data.get('card_number'),
                    'cardholder_name': serializer.validated_data.get('cardholder_name'),
                    'expiry_month': serializer.validated_data.get('expiry_month'),
                    'expiry_year': serializer.validated_data.get('expiry_year'),
                    'cvv': serializer.validated_data.get('cvv')
                }
            
            # Process payment confirmation
            result = BorrowingService.confirm_payment(
                borrow_request=borrow_request,
                payment_method=serializer.validated_data['payment_method'],
                card_data=card_data
            )
            
            if result['success']:
                # Return updated borrow request
                response_serializer = BorrowRequestDetailSerializer(borrow_request)
                return Response({
                    'success': True,
                    'message': result['message'],
                    'data': response_serializer.data,
                    'payment_method': result.get('payment_method'),
                    'transaction_id': result.get('transaction_id')
                }, status=status.HTTP_200_OK)
            else:
                return Response({
                    'success': False,
                    'message': result.get('message', 'Payment confirmation failed'),
                    'error_code': result.get('error_code')
                }, status=status.HTTP_400_BAD_REQUEST)
                
        except ValidationError as e:
            logger.error(f"Validation error confirming payment: {e.detail}")
            return Response({
                'success': False,
                'message': 'Invalid payment data',
                'errors': e.detail
            }, status=status.HTTP_400_BAD_REQUEST)
        except ValueError as e:
            logger.error(f"Error confirming payment: {str(e)}")
            return Response({
                'success': False,
                'message': str(e),
                'errors': {
                    'non_field_errors': [str(e)]
                }
            }, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error(f"Error confirming payment: {str(e)}", exc_info=True)
            return Response({
                'success': False,
                'message': 'Failed to confirm payment',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class CustomerBorrowingsView(generics.ListAPIView):
    """
    API view for customers to view their borrowings
    """
    serializer_class = BorrowRequestListSerializer
    permission_classes = [permissions.IsAuthenticated, CustomerOrAdmin]
    
    def get_queryset(self):
        """Get customer's borrowings"""
        status_filter = self.request.query_params.get('status')
        return BorrowingService.get_customer_borrowings(
            customer=self.request.user,
            status=status_filter
        )
    
    def list(self, request, *args, **kwargs):
        try:
            queryset = self.get_queryset()
            serializer = self.get_serializer(queryset, many=True)
            data = serializer.data
            
            # For each borrow request, always fetch and include the associated DeliveryRequest if it exists
            # According to unified delivery status requirements: delivery_request.status is the source of truth
            from ..models.delivery_model import DeliveryRequest
            from ..serializers.delivery_serializers import CustomerDeliveryRequestSerializer
            
            for i, borrow_data in enumerate(data):
                borrow_id = borrow_data.get('id')
                if borrow_id:
                    try:
                        delivery_request = DeliveryRequest.objects.filter(
                            borrow_request_id=borrow_id,
                            delivery_type='borrow'
                        ).select_related(
                            'delivery_manager',
                            'delivery_manager__delivery_profile'
                        ).first()
                        
                        if delivery_request:
                            delivery_serializer = CustomerDeliveryRequestSerializer(delivery_request)
                            data[i]['delivery_request'] = delivery_serializer.data
                        else:
                            data[i]['delivery_request'] = None
                    except Exception as e:
                        logger.warning(f"Error fetching delivery request for borrow {borrow_id}: {str(e)}")
                        data[i]['delivery_request'] = None
            
            return Response({
                'success': True,
                'message': 'Customer borrowings retrieved successfully',
                'data': data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving customer borrowings: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve borrowings',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class BorrowRequestDetailView(generics.RetrieveAPIView):
    """
    API view for viewing borrow request details.
    Uses AdminBorrowRequestSerializer for admins to include both statuses and location data.
    Uses BorrowRequestDetailSerializer for customers.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get_serializer_class(self):
        """Use admin serializer for admins, regular serializer for customers"""
        if self.request.user.is_library_admin() or self.request.user.is_delivery_admin():
            return AdminBorrowRequestSerializer
        return BorrowRequestDetailSerializer
    
    def get_object(self):
        """Get borrow request object with permission check"""
        borrow_id = self.kwargs.get('pk')
        # Optimize query by selecting related customer, profile, delivery_person, and approved_by
        # Use select_related for ForeignKey relationships to avoid N+1 queries
        borrow_request = get_object_or_404(
            BorrowRequest.objects.select_related(
                'customer', 
                'customer__profile',
                'delivery_person',
                'delivery_person__profile',
                'approved_by',
                'approved_by__profile'
            ).prefetch_related('customer__profile'),
            id=borrow_id
        )
        
        # Ensure customer and profile are accessible
        if borrow_request.customer:
            # Force access to profile to ensure it's loaded
            try:
                _ = borrow_request.customer.profile
            except Exception:
                # Profile doesn't exist, which is okay
                pass
        
        # Check permissions
        if (borrow_request.customer != self.request.user and 
            not self.request.user.is_library_admin() and 
            not self.request.user.is_delivery_admin()):
            raise PermissionError("You don't have permission to view this borrowing")
        
        return borrow_request
    
    def retrieve(self, request, *args, **kwargs):
        try:
            instance = self.get_object()
            serializer = self.get_serializer(instance)
            data = serializer.data
            
            # For non-admin users, always include delivery request if it exists
            # Admin serializer already includes this via AdminBorrowRequestSerializer
            # According to unified delivery status requirements: delivery_request.status is the source of truth
            if not (request.user.is_library_admin() or request.user.is_delivery_admin()):
                from ..models.delivery_model import DeliveryRequest
                from ..serializers.delivery_serializers import CustomerDeliveryRequestSerializer
                
                delivery_request = DeliveryRequest.objects.filter(
                    borrow_request=instance,
                    delivery_type='borrow'
                ).select_related(
                    'delivery_manager',
                    'delivery_manager__delivery_profile'
                ).first()
                
                if delivery_request:
                    delivery_serializer = CustomerDeliveryRequestSerializer(delivery_request)
                    data['delivery_request'] = delivery_serializer.data
                else:
                    data['delivery_request'] = None
            
            # Check if there's a return request and return fine for this borrowing
            from ..models.return_model import ReturnRequest, ReturnFine
            from ..services.return_services import ReturnService
            from django.utils import timezone
            
            # Get the most recent return request for this borrowing
            return_request = ReturnRequest.objects.filter(
                borrowing=instance
            ).order_by('-created_at').first()
            
            if return_request:
                # Get or create return fine (this ensures fine is calculated)
                # Handle case where database columns might not exist yet
                try:
                    return_fine = ReturnService.get_or_create_return_fine(return_request)
                except Exception as fine_error:
                    # If there's an error accessing return fine (e.g., missing columns),
                    # try to get it with only the fields we need, excluding problematic fields
                    error_msg = str(fine_error).lower()
                    if 'late_return' in error_msg or '1054' in error_msg:
                        logger.warning(f"Database schema issue detected, using alternative query: {str(fine_error)}")
                        try:
                            # Use defer to exclude fields that might not exist
                            return_fine = ReturnFine.objects.defer(
                                'late_return', 'damaged', 'lost'
                            ).get(return_request=return_request)
                        except ReturnFine.DoesNotExist:
                            return_fine = None
                        except Exception as e:
                            logger.error(f"Error accessing return fine with defer: {str(e)}")
                            return_fine = None
                    else:
                        # Re-raise if it's a different error
                        raise fine_error
                
                # Add return fine information to the response
                if return_fine and return_fine.fine_amount and float(return_fine.fine_amount) > 0:
                    # Calculate if delay exists
                    has_delay = False
                    if instance.expected_return_date:
                        current_date = timezone.now().date()
                        expected_date = instance.expected_return_date.date() if hasattr(instance.expected_return_date, 'date') else instance.expected_return_date
                        has_delay = current_date > expected_date
                    
                    # Map payment status for frontend compatibility
                    fine_status = 'paid' if return_fine.is_paid else 'pending'
                    
                    # Safely access days_late (might not exist in old database schema)
                    days_late = 0
                    try:
                        days_late = return_fine.days_late if has_delay else 0
                    except AttributeError:
                        # days_late field doesn't exist, use 0
                        days_late = 0
                    
                    # Update fine amount and status in the response
                    data['fine_amount'] = float(return_fine.fine_amount)
                    data['fine_status'] = fine_status
                    data['overdue_days'] = days_late
                    data['payment_method'] = getattr(return_fine, 'payment_method', None)
                    data['is_finalized'] = getattr(return_fine, 'is_finalized', False)
                else:
                    # No fine or fine amount is 0
                    data['fine_amount'] = 0.0
                    data['fine_status'] = None
                    data['overdue_days'] = 0
                    data['payment_method'] = None
                    data['is_finalized'] = False
            
            return Response({
                'success': True,
                'message': 'Borrowing details retrieved successfully',
                'data': data
            }, status=status.HTTP_200_OK)
            
        except PermissionError as e:
            return Response({
                'success': False,
                'message': 'Permission denied',
                'errors': {'permission': [str(e)]}
            }, status=status.HTTP_403_FORBIDDEN)
        except Exception as e:
            logger.error(f"Error retrieving borrowing details: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve borrowing details',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class PendingRequestsView(generics.ListAPIView):
    """
    API view for library managers to view pending requests
    """
    serializer_class = PendingRequestsSerializer
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def get_queryset(self):
        """Get pending borrow requests with optional search"""
        search_query = self.request.query_params.get('search', None)
        return BorrowingService.get_pending_requests(search=search_query)
    
    def list(self, request, *args, **kwargs):
        try:
            queryset = self.get_queryset()
            serializer = self.get_serializer(queryset, many=True)
            
            return Response({
                'success': True,
                'message': 'Pending requests retrieved successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving pending requests: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve pending requests',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class BorrowApprovalView(APIView):
    """
    API view for library managers to approve/reject borrow requests
    """
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def patch(self, request, pk):
        try:
            borrow_request = get_object_or_404(BorrowRequest, id=pk)
            
            if borrow_request.status != BorrowStatusChoices.PENDING:
                return Response({
                    'success': False,
                    'message': 'Only pending requests can be approved/rejected',
                    'errors': {'status': ['Request is not in pending status']}
                }, status=status.HTTP_400_BAD_REQUEST)
            
            serializer = BorrowApprovalSerializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            
            action = serializer.validated_data['action']
            
            if action == 'approve':
                delivery_manager_id = serializer.validated_data.get('delivery_manager_id')
                delivery_manager = None
                
                if delivery_manager_id:
                    delivery_manager = get_object_or_404(User, id=delivery_manager_id)
                
                borrow_request = BorrowingService.approve_borrow_request(
                    borrow_request=borrow_request,
                    approved_by=request.user,
                    delivery_manager=delivery_manager
                )
                message = 'Borrowing request approved successfully'
            else:
                rejection_reason = serializer.validated_data.get('rejection_reason', '')
                borrow_request = BorrowingService.reject_borrow_request(
                    borrow_request=borrow_request,
                    rejection_reason=rejection_reason
                )
                message = 'Borrowing request rejected'
            
            response_serializer = BorrowRequestDetailSerializer(borrow_request)
            
            return Response({
                'success': True,
                'message': message, # TODO: translate this message  
                'data': response_serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error processing approval: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to process request',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_400_BAD_REQUEST)


class DeliveryManagerSelectionView(generics.ListAPIView):
    """
    API view for library admins to get ALL delivery managers for assignment.
    Returns all delivery managers (online, busy, offline) with their status information.
    The frontend will display all managers but only allow selection of online ones.
    """
    serializer_class = DeliveryManagerSerializer
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def get_queryset(self):
        """Get ALL delivery managers with their status (online, busy, offline) - no filtering"""
        return BorrowingService.get_available_delivery_managers()
    
    def list(self, request, *args, **kwargs):
        try:
            queryset = self.get_queryset()
            
            # Force evaluation of queryset to ensure we get all managers
            managers_list = list(queryset)
            logger.info(f"DeliveryManagerSelectionView: Total managers in queryset: {len(managers_list)}")
            logger.info(f"DeliveryManagerSelectionView: Queryset count (before list): {queryset.count()}")
            
            # Log each manager BEFORE serialization
            for manager in managers_list:
                try:
                    has_profile = hasattr(manager, 'delivery_profile')
                    profile = manager.delivery_profile if has_profile else None
                    delivery_status_value = profile.delivery_status if profile else None
                    status_display = profile.get_delivery_status_display() if profile and delivery_status_value else None
                    
                    logger.info(
                        f"Manager {manager.id} ({manager.get_full_name()}): "
                        f"has_profile={has_profile}, delivery_status={delivery_status_value}, status_display={status_display}, "
                        f"is_active={manager.is_active}, user_type={manager.user_type}"
                    )
                except Exception as e:
                    logger.warning(f"Error logging manager {manager.id}: {str(e)}")
            
            # Serialize the managers
            serializer = self.get_serializer(managers_list, many=True)
            
            # Also log the serialized data for debugging
            logger.info(f"DeliveryManagerSelectionView: Serialized data count: {len(serializer.data)}")
            if serializer.data:
                logger.info(f"Serialized data sample (first item): {serializer.data[0]}")
                # Log all delivery_status values with ALL possible fields
                for idx, item in enumerate(serializer.data):
                    logger.info(f"Item {idx}: id={item.get('id')}, name={item.get('name')}, full_name={item.get('full_name')}, "
                              f"delivery_status={item.get('delivery_status')}, status={item.get('status')}, "
                              f"delivery_status_lower={item.get('delivery_status_lower')}, "
                              f"status_display={item.get('status_display')}, status_text={item.get('status_text')}, "
                              f"is_available={item.get('is_available')}, status_color={item.get('status_color')}")
                    # Log full item structure for debugging
                    logger.debug(f"Full item {idx} structure: {item}")
            else:
                logger.warning("No delivery managers found in serialized data")
            
            # Return response with both nested and flat structure for compatibility
            response_data = {
                'success': True,
                'message': 'Delivery managers retrieved successfully',
                'data': serializer.data
            }
            
            # Log the full response structure
            logger.info(f"Response structure keys: {list(response_data.keys())}")
            logger.info(f"Response data count: {len(serializer.data)}")
            
            return Response(response_data, status=status.HTTP_200_OK)
            
        except Exception as e:
            import traceback
            logger.error(f"Error retrieving delivery managers: {str(e)}")
            logger.error(f"Traceback: {traceback.format_exc()}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve delivery managers',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class DeliveryReadyView(generics.ListAPIView):
    """
    API view for delivery managers to view ready for delivery orders
    """
    serializer_class = DeliveryReadySerializer
    permission_classes = [permissions.IsAuthenticated, IsDeliveryAdmin]
    
    def get_queryset(self):
        """Get orders ready for delivery"""
        return BorrowingService.get_ready_for_delivery()
    
    def list(self, request, *args, **kwargs):
        try:
            queryset = self.get_queryset()
            serializer = self.get_serializer(queryset, many=True)
            
            return Response({
                'success': True,
                'message': 'Ready for delivery orders retrieved successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving delivery orders: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve delivery orders',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class DeliveryPickupView(APIView):
    """
    API view for delivery managers to mark books as picked up
    """
    permission_classes = [permissions.IsAuthenticated, IsDeliveryAdmin]
    
    def patch(self, request, pk):
        try:
            borrow_request = get_object_or_404(BorrowRequest, id=pk)
            
            if borrow_request.status != BorrowStatusChoices.APPROVED:
                return Response({
                    'success': False,
                    'message': 'Only approved requests can be picked up',
                    'errors': {'status': ['Request is not approved']}
                }, status=status.HTTP_400_BAD_REQUEST)
            
            borrow_request = BorrowingService.start_delivery(
                borrow_request=borrow_request,
                delivery_person=request.user
            )
            
            response_serializer = BorrowRequestDetailSerializer(borrow_request)
            
            return Response({
                'success': True,
                'message': 'Book picked up for delivery',
                'data': response_serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error processing pickup: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to process pickup',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_400_BAD_REQUEST)


class BorrowingDeliveryOrdersView(generics.ListAPIView):
    """
    API view for delivery managers to view borrowing delivery orders
    Returns orders assigned to the delivery manager OR unassigned pending orders
    """
    serializer_class = BorrowingOrderSerializer
    permission_classes = [permissions.IsAuthenticated, IsDeliveryAdmin]
    
    def get_queryset(self):
        """
        Get ALL borrowing delivery orders assigned to the DM's 'Borrow Requests' list.
        Once a request is assigned to a delivery manager, it remains visible regardless of status.
        This ensures delivery managers can see their complete history of assigned requests.
        Supports optional status filtering via query parameter.
        """
        from ..models import Order
        from ..models.borrowing_model import BorrowStatusChoices
        from django.db.models import Q
        
        user = self.request.user
        
        logger.info(f"BorrowingDeliveryOrdersView: Getting all orders for DM {user.id}")
        
        # 1. Base Query: Only Borrowing type orders
        base_queryset = Order.objects.filter(
            order_type='borrowing'
        )
        
        # 2. Filter: Orders Assigned to THIS DM (regardless of status)
        # Once assigned to a delivery manager, requests remain visible forever
        # This includes all statuses: pending, in-progress, delivered, active, returned, etc.
        assigned_orders_filter = Q(
            # Must be explicitly assigned to the current DM (using the BorrowRequest link)
            borrow_request__delivery_person=user
            # No status filter - show ALL assigned requests
        )
        
        # 3. Apply status filter if provided
        status_filter = self.request.query_params.get('status')
        if status_filter and status_filter.lower() != 'all':
            # Map frontend status values to backend BorrowRequest status values
            status_mapping = {
                'pending': BorrowStatusChoices.PENDING,
                'confirmed': BorrowStatusChoices.ASSIGNED_TO_DELIVERY,  # Orders assigned but not yet accepted
                'in_delivery': BorrowStatusChoices.OUT_FOR_DELIVERY,  # Delivery in progress
                'delivered': BorrowStatusChoices.DELIVERED,  # Delivery completed
                'active': BorrowStatusChoices.ACTIVE,  # Book is actively borrowed
                'returned': BorrowStatusChoices.RETURNED,  # Book has been returned
            }
            
            backend_status = status_mapping.get(status_filter.lower())
            if backend_status:
                assigned_orders_filter = assigned_orders_filter & Q(
                    borrow_request__status=backend_status
                )
                logger.info(f"BorrowingDeliveryOrdersView: Filtering by status: {status_filter} -> {backend_status}")
            else:
                # If no mapping found, try direct match (case-insensitive)
                assigned_orders_filter = assigned_orders_filter & Q(
                    borrow_request__status__iexact=status_filter
                )
                logger.info(f"BorrowingDeliveryOrdersView: Using direct status filter (case-insensitive): {status_filter}")
        
        # 4. Final Query: Apply the assigned filter and status filter
        queryset = base_queryset.filter(
            assigned_orders_filter
        ).select_related(
            'customer', 
            'borrow_request', 
            'borrow_request__book', 
            'borrow_request__delivery_person'
            # Add other necessary select_related/prefetch_related fields here
        ).distinct()
        
        logger.info(f"BorrowingDeliveryOrdersView: Final queryset count for DM {user.id}: {queryset.count()}")
        
        # Log the actual statuses retrieved for immediate debugging
        for order in queryset[:5]:  # Log first 5 to avoid spam
            logger.info(f"Fetched Order {order.id} with BR Status: {order.borrow_request.status}")
        
        return queryset
    
    def list(self, request, *args, **kwargs):
        try:
            queryset = self.get_queryset()
            queryset_list = list(queryset)
            logger.info(f"BorrowingDeliveryOrdersView: Queryset evaluated, {len(queryset_list)} orders found")
            
            # Try to serialize each order individually to catch any serialization errors
            serialized_data = []
            for order in queryset_list:
                try:
                    serializer = self.get_serializer(order)
                    serialized_data.append(serializer.data)
                except Exception as e:
                    logger.error(f"BorrowingDeliveryOrdersView: Error serializing order {order.order_number} (ID: {order.id}): {str(e)}")
                    import traceback
                    logger.error(f"BorrowingDeliveryOrdersView: Traceback: {traceback.format_exc()}")
                    # Continue with other orders even if one fails
            
            logger.info(f"BorrowingDeliveryOrdersView: Successfully serialized {len(serialized_data)} orders")
            if serialized_data:
                logger.info(f"BorrowingDeliveryOrdersView: First order sample: {serialized_data[0]}")
            
            return Response({
                'success': True,
                'message': 'Borrowing delivery orders retrieved successfully',
                'data': serialized_data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving borrowing delivery orders: {str(e)}")
            import traceback
            logger.error(f"BorrowingDeliveryOrdersView: Full traceback: {traceback.format_exc()}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve delivery orders',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class AcceptDeliveryRequestView(APIView):
    """
    Step 3.1: API view for delivery managers to accept request
    Updates status to "Preparing"
    """
    permission_classes = [permissions.IsAuthenticated, IsDeliveryAdmin]
    
    def patch(self, request, borrow_id):
        try:
            borrow_request = get_object_or_404(BorrowRequest, id=borrow_id)
            
            if borrow_request.status != BorrowStatusChoices.ASSIGNED_TO_DELIVERY:
                return Response({
                    'success': False,
                    'message': 'Request must be assigned to delivery before acceptance',
                    'errors': {'status': ['Request is not in assigned_to_delivery status']}
                }, status=status.HTTP_400_BAD_REQUEST)
            
            if borrow_request.delivery_person != request.user:
                return Response({
                    'success': False,
                    'message': 'Only the assigned delivery manager can accept this request',
                    'errors': {'permission': ['You are not assigned to this request']}
                }, status=status.HTTP_403_FORBIDDEN)
            
            borrow_request = BorrowingService.accept_delivery_request(
                borrow_request=borrow_request,
                delivery_person=request.user
            )
            
            response_serializer = BorrowRequestDetailSerializer(borrow_request)
            
            return Response({
                'success': True,
                'message': 'Delivery request accepted successfully. Status: Preparing',
                'data': response_serializer.data
            }, status=status.HTTP_200_OK)
            
        except ValueError as e:
            return Response({
                'success': False,
                'message': str(e),
                'errors': {'validation': [str(e)]}
            }, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error(f"Error accepting delivery request: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to accept delivery request',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_400_BAD_REQUEST)


class RejectDeliveryRequestView(APIView):
    """
    API view for delivery managers to reject delivery assignment
    Unassigns the delivery manager from the request
    """
    permission_classes = [permissions.IsAuthenticated, IsDeliveryAdmin]
    
    def post(self, request, borrow_id):
        try:
            borrow_request = get_object_or_404(BorrowRequest, id=borrow_id)
            
            if borrow_request.status != BorrowStatusChoices.ASSIGNED_TO_DELIVERY:
                return Response({
                    'success': False,
                    'message': 'Request must be assigned to delivery before rejection',
                    'errors': {'status': ['Request is not in assigned_to_delivery status']}
                }, status=status.HTTP_400_BAD_REQUEST)
            
            if borrow_request.delivery_person != request.user:
                return Response({
                    'success': False,
                    'message': 'Only the assigned delivery manager can reject this request',
                    'errors': {'permission': ['You are not assigned to this request']}
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Get rejection reason from request
            rejection_reason = request.data.get('rejection_reason', 'No reason provided')
            if not rejection_reason or rejection_reason.strip() == '':
                return Response({
                    'success': False,
                    'message': 'Rejection reason is required',
                    'errors': {'rejection_reason': ['Please provide a reason for rejection']}
                }, status=status.HTTP_400_BAD_REQUEST)
            
            borrow_request = BorrowingService.reject_delivery_request(
                borrow_request=borrow_request,
                delivery_person=request.user,
                rejection_reason=rejection_reason.strip()
            )
            
            response_serializer = BorrowRequestDetailSerializer(borrow_request)
            
            return Response({
                'success': True,
                'message': 'Delivery request rejected successfully. The request has been unassigned and will be reassigned to another delivery manager.',
                'data': response_serializer.data
            }, status=status.HTTP_200_OK)
            
        except ValueError as e:
            return Response({
                'success': False,
                'message': str(e),
                'errors': {'validation': [str(e)]}
            }, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error(f"Error rejecting delivery request: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to reject delivery request',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_400_BAD_REQUEST)


class StartDeliveryView(APIView):
    """
    Step 3.2: API view for delivery managers to start delivery
    Updates status to "Out for Delivery"
    """
    permission_classes = [permissions.IsAuthenticated, IsDeliveryAdmin]
    
    def patch(self, request, borrow_id):
        try:
            borrow_request = get_object_or_404(BorrowRequest, id=borrow_id)
            
            if borrow_request.status != BorrowStatusChoices.PREPARING:
                return Response({
                    'success': False,
                    'message': 'Request must be in Preparing status before starting delivery',
                    'errors': {'status': ['Request is not in preparing status']}
                }, status=status.HTTP_400_BAD_REQUEST)
            
            if borrow_request.delivery_person != request.user:
                return Response({
                    'success': False,
                    'message': 'Only the assigned delivery manager can start delivery',
                    'errors': {'permission': ['You are not assigned to this request']}
                }, status=status.HTTP_403_FORBIDDEN)
            
            borrow_request = BorrowingService.start_delivery(
                borrow_request=borrow_request,
                delivery_person=request.user
            )
            
            response_serializer = BorrowRequestDetailSerializer(borrow_request)
            
            return Response({
                'success': True,
                'message': 'Delivery started successfully. Status: Out for Delivery. Location tracking is now active.',
                'data': response_serializer.data
            }, status=status.HTTP_200_OK)
            
        except ValueError as e:
            return Response({
                'success': False,
                'message': str(e),
                'errors': {'validation': [str(e)]}
            }, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error(f"Error starting delivery: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to start delivery',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_400_BAD_REQUEST)


class RejectDeliveryOrderView(APIView):
    """
    API view for delivery managers to reject delivery assignment (via order)
    Unassigns the delivery manager from the request
    """
    permission_classes = [permissions.IsAuthenticated, IsDeliveryAdmin]
    
    def post(self, request, order_id):
        try:
            from ..models import Order
            order = get_object_or_404(Order, id=order_id, order_type='borrowing')
            
            # Get borrow request
            borrow_request = order.borrow_request
            if not borrow_request:
                return Response({
                    'success': False,
                    'message': 'Borrow request not found for this order',
                    'errors': {'order': ['This order does not have an associated borrow request']}
                }, status=status.HTTP_400_BAD_REQUEST)
            
            if borrow_request.status != BorrowStatusChoices.ASSIGNED_TO_DELIVERY:
                return Response({
                    'success': False,
                    'message': 'Request must be assigned to delivery before rejection',
                    'errors': {'status': ['Request is not in assigned_to_delivery status']}
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Check if the request is assigned to this delivery manager
            # If delivery_person is None, it means it was previously rejected and unassigned
            if borrow_request.delivery_person is None:
                logger.warning(
                    f"RejectDeliveryOrderView: Order {order_id} (BR {borrow_request.id}) "
                    f"has no delivery_person assigned. Current user: {request.user.id}"
                )
                return Response({
                    'success': False,
                    'message': 'This request is not currently assigned to any delivery manager',
                    'errors': {'assignment': ['The request has already been unassigned']}
                }, status=status.HTTP_400_BAD_REQUEST)
            
            if borrow_request.delivery_person != request.user:
                logger.warning(
                    f"RejectDeliveryOrderView: Order {order_id} (BR {borrow_request.id}) "
                    f"is assigned to delivery_person {borrow_request.delivery_person.id}, "
                    f"but current user is {request.user.id}"
                )
                return Response({
                    'success': False,
                    'message': 'Only the assigned delivery manager can reject this request',
                    'errors': {'permission': ['You are not assigned to this request']}
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Get rejection reason from request
            rejection_reason = request.data.get('rejection_reason', '')
            if not rejection_reason or rejection_reason.strip() == '':
                return Response({
                    'success': False,
                    'message': 'Rejection reason is required',
                    'errors': {'rejection_reason': ['Please provide a reason for rejection']}
                }, status=status.HTTP_400_BAD_REQUEST)
            
            borrow_request = BorrowingService.reject_delivery_request(
                borrow_request=borrow_request,
                delivery_person=request.user,
                rejection_reason=rejection_reason.strip()
            )
            
            response_serializer = BorrowRequestDetailSerializer(borrow_request)
            
            return Response({
                'success': True,
                'message': 'Delivery request rejected successfully. The request has been unassigned and will be reassigned to another delivery manager.',
                'data': response_serializer.data
            }, status=status.HTTP_200_OK)
            
        except ValueError as e:
            return Response({
                'success': False,
                'message': str(e),
                'errors': {'validation': [str(e)]}
            }, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error(f"Error rejecting delivery request: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to reject delivery request',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_400_BAD_REQUEST)


class StartDeliveryOrderView(APIView):
    """
    Legacy API view for delivery managers to start delivery (via order)
    """
    permission_classes = [permissions.IsAuthenticated, IsDeliveryAdmin]
    
    def patch(self, request, order_id):
        try:
            from ..models import Order
            order = get_object_or_404(Order, id=order_id, order_type='borrowing')
            
            # Get borrow request to check actual status
            borrow_request = order.borrow_request
            if not borrow_request:
                return Response({
                    'success': False,
                    'message': 'Borrow request not found for this order',
                    'errors': {'order': ['This order does not have an associated borrow request']}
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Check borrow_request status (this is the source of truth)
            # Accept orders that are ready for delivery to start
            # out_for_delivery means "ready to start" - delivery manager can begin actual delivery
            valid_statuses = [
                BorrowStatusChoices.ASSIGNED_TO_DELIVERY,
                BorrowStatusChoices.PENDING_DELIVERY,
                BorrowStatusChoices.PREPARING,
                BorrowStatusChoices.OUT_FOR_DELIVERY,  # Allow starting delivery when status is out_for_delivery
                'pending',
                'confirmed',
                'assigned',
                'assigned_to_delivery',
                'out_for_delivery',  # String version for compatibility
            ]
            
            if borrow_request.status not in valid_statuses:
                return Response({
                    'success': False,
                    'message': 'Order is not ready for delivery',
                    'errors': {'status': [f'Borrow request status must be one of: {", ".join(valid_statuses)}. Current status: {borrow_request.status}']}
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Update order status to delivered (indicates delivery has started, awaiting final confirmation)
            order.status = 'delivered'
            order.save()
            
            # Update borrow request status
            # If already out_for_delivery, keep it as out_for_delivery (delivery has started)
            # Otherwise, set to OUT_FOR_DELIVERY (first time starting delivery)
            if borrow_request.status != BorrowStatusChoices.OUT_FOR_DELIVERY and borrow_request.status != 'out_for_delivery':
                # First time starting delivery - set to OUT_FOR_DELIVERY
                borrow_request.status = BorrowStatusChoices.OUT_FOR_DELIVERY
            
            # If already out_for_delivery, keep it as is (delivery is now actively in progress)
            # The order status 'in_delivery' indicates active delivery
            
            borrow_request.delivery_person = request.user
            if not borrow_request.pickup_date:
                borrow_request.pickup_date = timezone.now()
            borrow_request.save()
            
            # Update delivery manager status to busy when they start delivery
            # This is critical - always update status when starting delivery
            # Do this BEFORE saving the order/borrow_request to ensure status is set
            try:
                from ..services.delivery_profile_services import DeliveryProfileService
                from ..models.delivery_profile_model import DeliveryProfile
                
                logger.info(f"Attempting to update delivery manager {request.user.id} status to busy...")
                
                # Get or create delivery profile first
                delivery_profile = DeliveryProfileService.get_or_create_delivery_profile(request.user)
                old_status = delivery_profile.delivery_status
                logger.info(f"Delivery manager {request.user.id} current status: {old_status}")
                
                # Update status to busy
                result = DeliveryProfileService.start_delivery_task(request.user)
                logger.info(f"DeliveryProfileService.start_delivery_task returned: {result} for user {request.user.id}")
                
                # Force refresh from database to get actual status
                delivery_profile.refresh_from_db()
                actual_status = delivery_profile.delivery_status
                logger.info(f"Verified delivery manager {request.user.id} status after update: {actual_status}")
                
                # If status is still not busy, force it
                if actual_status != 'busy':
                    logger.error(f"CRITICAL: Delivery manager {request.user.id} status is NOT 'busy' after start_delivery_task! Current status: {actual_status}")
                    # Force update using direct database update to ensure it happens
                    DeliveryProfile.objects.filter(user=request.user).update(delivery_status='busy')
                    delivery_profile.refresh_from_db()
                    if delivery_profile.delivery_status == 'busy':
                        logger.info(f"Successfully force-updated delivery manager {request.user.id} status to 'busy'")
                    else:
                        logger.error(f"FAILED to force-update status for user {request.user.id}")
                else:
                    logger.info(f"Successfully updated delivery manager {request.user.id} status from '{old_status}' to 'busy'")
                    
            except Exception as e:
                # Log error with full traceback
                import traceback
                logger.error(f"Failed to update delivery manager {request.user.id} status to busy: {str(e)}")
                logger.error(f"Traceback: {traceback.format_exc()}")
                # Try to force update status directly as last resort
                try:
                    from ..models.delivery_profile_model import DeliveryProfile
                    updated = DeliveryProfile.objects.filter(user=request.user).update(delivery_status='busy')
                    logger.info(f"Force-updated delivery manager {request.user.id} status to 'busy' via direct DB update (rows updated: {updated})")
                except Exception as e2:
                    logger.error(f"CRITICAL: Failed to force-update status via direct DB update: {str(e2)}")
            
            # Send notification to customer
            NotificationService.create_notification(
                user_id=borrow_request.customer.id,
                title="Delivery Started",
                message=f"Your book '{borrow_request.book.name}' is now being delivered to you.",
                notification_type="delivery_started"
            )
            
            response_serializer = BorrowRequestDetailSerializer(borrow_request)
            
            # Get the actual delivery manager status for the response
            delivery_manager_status = 'online'
            try:
                if hasattr(request.user, 'delivery_profile'):
                    request.user.delivery_profile.refresh_from_db()
                    delivery_manager_status = request.user.delivery_profile.delivery_status
            except Exception as e:
                logger.warning(f"Could not get delivery manager status for response: {str(e)}")
            
            return Response({
                'success': True,
                'message': 'Delivery started successfully',
                'data': response_serializer.data,
                'delivery_manager_status': delivery_manager_status,
                'order_status': order.status
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error starting delivery: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to start delivery',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_400_BAD_REQUEST)


class GetDeliveryLocationView(APIView):
    """
    Step 3.4: API view to get current delivery manager location for real-time tracking
    GET /api/borrowings/{borrow_id}/delivery-location/
    Visible only during OUT_FOR_DELIVERY or OUT_FOR_RETURN_PICKUP status
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request, borrow_id):
        try:
            borrow_request = get_object_or_404(BorrowRequest, id=borrow_id)
            
            # Check permissions - customer can see their own, admin can see all
            if (borrow_request.customer != request.user and 
                not request.user.is_library_admin() and 
                not request.user.is_delivery_admin()):
                return Response({
                    'success': False,
                    'message': 'Permission denied',
                    'errors': {'permission': ['You do not have permission to view this location']}
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Step 3.4: Location button is VISIBLE only when DeliveryRequest status is 'in_delivery'
            # Check DeliveryRequest status (preferred) or fallback to BorrowRequest status
            from ..models.delivery_model import DeliveryRequest
            delivery_request = DeliveryRequest.objects.filter(
                borrow_request=borrow_request,
                delivery_type='borrow'
            ).first()
            
            # Check if delivery is active based on DeliveryRequest status
            is_delivery_active = False
            if delivery_request:
                # DeliveryRequest status 'in_delivery' means delivery is actively in progress
                is_delivery_active = delivery_request.status == 'in_delivery'
            else:
                # Fallback: Check BorrowRequest status for backward compatibility
                is_delivery_active = borrow_request.status in [
                    BorrowStatusChoices.OUT_FOR_DELIVERY, 
                    BorrowStatusChoices.OUT_FOR_RETURN_PICKUP
                ]
            
            if not is_delivery_active:
                return Response({
                    'success': False,
                    'message': 'Location tracking is not available for this request',
                    'errors': {'status': ['Location tracking is only available when delivery is in progress']},
                    'current_status': borrow_request.status,
                    'delivery_request_status': delivery_request.status if delivery_request else None,
                    'tracking_available': False
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Get delivery manager
            delivery_manager = borrow_request.delivery_person
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
            
            # Get delivery manager details (Step 2.3: DM Details Display)
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
                    'borrow_request_id': borrow_request.id,
                    'status': borrow_request.status,
                    'delivery_manager': delivery_manager_info,
                    'location': location_data,
                    'tracking_enabled': True,
                    'tracking_interval_seconds': 5  # Step 3.3: Every 5 seconds
                }
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error getting delivery location: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to get delivery location',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class CompleteDeliveryView(APIView):
    """
    API view for delivery managers and library admins to complete delivery
    """
    permission_classes = [permissions.IsAuthenticated, IsDeliveryAdminOrLibraryAdmin]
    
    def patch(self, request, order_id):
        try:
            from ..models import Order
            order = get_object_or_404(Order, id=order_id, order_type='borrowing')
            
            # Get borrow request to check actual status
            borrow_request = order.borrow_request
            if not borrow_request:
                return Response({
                    'success': False,
                    'message': 'Borrow request not found for this order',
                    'errors': {'order': ['This order does not have an associated borrow request']}
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Check borrow_request status - must be OUT_FOR_DELIVERY (delivery_started) to complete
            if borrow_request.status != BorrowStatusChoices.OUT_FOR_DELIVERY and borrow_request.status != 'out_for_delivery':
                return Response({
                    'success': False,
                    'message': 'Delivery must be started before completion',
                    'errors': {'status': [f'Borrow request status must be OUT_FOR_DELIVERY (delivery_started). Current status: {borrow_request.status}']}
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Update order status to delivered
            order.status = 'delivered'
            order.save()
            
            # Automatically update payment status to 'completed' for cash on delivery orders
            if order.payment:
                from ..models import Payment
                # Get fresh payment instance from database with select_for_update for transaction safety
                payment = Payment.objects.select_for_update().get(id=order.payment.id)
                logger.info(f"Checking payment {payment.id} for borrowing order {order.id}: payment_type='{payment.payment_type}', status='{payment.status}'")
                
                # Check if payment method is cash on delivery and status is pending or processing
                if payment.payment_type == 'cash_on_delivery' and payment.status in ['pending', 'processing']:
                    old_status = payment.status
                    payment.status = 'completed'
                    payment.completed_at = timezone.now()
                    payment.save(update_fields=['status', 'completed_at', 'updated_at'])
                    
                    # Verify the update was saved by refreshing from database
                    payment.refresh_from_db()
                    logger.info(f"SUCCESS: Updated payment {payment.id} status from '{old_status}' to '{payment.status}' for cash on delivery borrowing order {order.id}")
                    
                    # Refresh the order's payment relationship to ensure it reflects the updated payment
                    order.refresh_from_db()
                    # Force reload of payment relationship
                    if hasattr(order, '_payment_cache'):
                        delattr(order, '_payment_cache')
                else:
                    logger.warning(f"Payment {payment.id} not updated: payment_type='{payment.payment_type}' (expected 'cash_on_delivery'), status='{payment.status}' (expected 'pending' or 'processing')")
            else:
                logger.warning(f"Borrowing order {order.id} has no payment associated")
            
            # Update borrow request status to DELIVERED (as per workflow requirements)
            borrow_request.status = BorrowStatusChoices.DELIVERED
            borrow_request.delivery_date = timezone.now()
            borrow_request.final_return_date = borrow_request.expected_return_date
            borrow_request.save()
            
            # Set delivery manager status back to Online when delivery is completed
            # This is critical - always update status when completing delivery
            if borrow_request.delivery_person:
                try:
                    from ..services.delivery_profile_services import DeliveryProfileService
                    DeliveryProfileService.complete_delivery_task(borrow_request.delivery_person, completed_order_id=order.id)
                    logger.info(f"Updated delivery manager {borrow_request.delivery_person.id} status to online after completing delivery")
                except Exception as e:
                    # Log error but don't fail the request - status update is important but shouldn't block completion
                    logger.error(f"Failed to update delivery manager {borrow_request.delivery_person.id} status to online: {str(e)}")
                    # Still continue with the delivery completion process
            
            # Stop location tracking when delivery is completed
            try:
                from ..models.delivery_model import RealTimeTracking
                tracking = RealTimeTracking.objects.filter(delivery_manager=borrow_request.delivery_person).first()
                if tracking:
                    tracking.is_delivering = False
                    tracking.current_delivery_assignment = None
                    tracking.save()
                    logger.info(f"Stopped location tracking for delivery manager {borrow_request.delivery_person.id}")
            except Exception as e:
                logger.warning(f"Failed to stop location tracking: {str(e)}")
            
            # Send notification to customer
            NotificationService.create_notification(
                user_id=borrow_request.customer.id,
                title="Book Delivered Successfully",
                message=f"Your book '{borrow_request.book.name}' has been delivered. Loan period starts today. Return date: {borrow_request.final_return_date.strftime('%Y-%m-%d')}",
                notification_type="delivery_completed"
            )
            
            response_serializer = BorrowRequestDetailSerializer(borrow_request)
            
            return Response({
                'success': True,
                'message': 'Delivery completed successfully',
                'data': response_serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error completing delivery: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to complete delivery',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_400_BAD_REQUEST)


class BorrowingExtensionView(APIView):
    """
    API view for customers to request borrowing extensions
    """
    permission_classes = [permissions.IsAuthenticated, IsCustomer]
    
    def post(self, request, pk):
        try:
            borrow_request = get_object_or_404(BorrowRequest, id=pk, customer=request.user)
            
            serializer = BorrowExtensionCreateSerializer(
                data=request.data,
                context={'borrow_request': borrow_request}
            )
            serializer.is_valid(raise_exception=True)
            
            extension = BorrowingService.request_extension(
                borrow_request=borrow_request,
                additional_days=serializer.validated_data['additional_days']
            )
            
            response_serializer = BorrowRequestDetailSerializer(borrow_request)
            
            return Response({
                'success': True,
                'message': 'Borrowing extension requested successfully',
                'data': response_serializer.data
            }, status=status.HTTP_200_OK)
            
        except ValueError as e:
            return Response({
                'success': False,
                'message': 'Extension not allowed',
                'errors': {'extension': [str(e)]}
            }, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error(f"Error requesting extension: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to request extension',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_400_BAD_REQUEST)


class EarlyReturnView(APIView):
    """
    API view for customers to request early return
    """
    permission_classes = [permissions.IsAuthenticated, IsCustomer]
    
    def post(self, request, pk):
        try:
            borrow_request = get_object_or_404(BorrowRequest, id=pk, customer=request.user)
            
            if borrow_request.status not in [BorrowStatusChoices.ACTIVE, BorrowStatusChoices.EXTENDED]:
                return Response({
                    'success': False,
                    'message': 'Early return not available',
                    'errors': {'status': ['Book is not currently active']}
                }, status=status.HTTP_400_BAD_REQUEST)
            
            serializer = EarlyReturnSerializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            
            return_reason = serializer.validated_data.get('return_reason', '')
            
            borrow_request = BorrowingService.request_early_return(
                borrow_request=borrow_request,
                return_reason=return_reason
            )
            
            response_serializer = BorrowRequestDetailSerializer(borrow_request)
            
            return Response({
                'success': True,
                'message': 'Early return requested successfully',
                'data': response_serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error requesting early return: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to request early return',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_400_BAD_REQUEST)


class BookCollectionView(APIView):
    """
    API view for delivery managers to collect returned books
    """
    permission_classes = [permissions.IsAuthenticated, IsDeliveryAdmin]
    
    def patch(self, request, pk):
        try:
            borrow_request = get_object_or_404(BorrowRequest, id=pk)
            
            if borrow_request.status != BorrowStatusChoices.RETURN_REQUESTED:
                return Response({
                    'success': False,
                    'message': 'Book collection not available',
                    'errors': {'status': ['Early return not requested']}
                }, status=status.HTTP_400_BAD_REQUEST)
            
            serializer = DeliveryUpdateSerializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            
            collection_notes = serializer.validated_data.get('collection_notes', '')
            
            borrow_request = BorrowingService.complete_return(
                borrow_request=borrow_request,
                collection_notes=collection_notes
            )
            
            response_serializer = BorrowRequestDetailSerializer(borrow_request)
            
            return Response({
                'success': True,
                'message': 'Book collected for early return',
                'data': response_serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error collecting book: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to collect book',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_400_BAD_REQUEST)


class BorrowRatingView(APIView):
    """
    API view for customers to rate borrowing experience
    """
    permission_classes = [permissions.IsAuthenticated, IsCustomer]
    
    def post(self, request, pk):
        try:
            borrow_request = get_object_or_404(BorrowRequest, id=pk, customer=request.user)
            
            serializer = BorrowRatingSerializer(
                data=request.data,
                context={'borrow_request': borrow_request}
            )
            serializer.is_valid(raise_exception=True)
            
            borrow_request = BorrowingService.add_rating(
                borrow_request=borrow_request,
                rating=serializer.validated_data['rating'],
                comment=serializer.validated_data.get('comment', '')
            )
            
            response_serializer = BorrowRequestDetailSerializer(borrow_request)
            
            return Response({
                'success': True,
                'message': 'Rating submitted successfully',
                'data': response_serializer.data
            }, status=status.HTTP_200_OK)
            
        except ValueError as e:
            return Response({
                'success': False,
                'message': 'Rating not allowed',
                'errors': {'rating': [str(e)]}
            }, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error(f"Error submitting rating: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to submit rating',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_400_BAD_REQUEST)


class BorrowCancelView(APIView):
    """
    API view for customers to cancel pending requests
    """
    permission_classes = [permissions.IsAuthenticated, IsCustomer]
    
    def delete(self, request, pk):
        try:
            borrow_request = get_object_or_404(BorrowRequest, id=pk, customer=request.user)
            
            borrow_request = BorrowingService.cancel_request(borrow_request)
            
            response_serializer = BorrowRequestDetailSerializer(borrow_request)
            
            return Response({
                'success': True,
                'message': 'Borrowing request cancelled successfully',
                'data': response_serializer.data
            }, status=status.HTTP_200_OK)
            
        except ValueError as e:
            return Response({
                'success': False,
                'message': 'Cannot cancel request',
                'errors': {'status': [str(e)]}
            }, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error(f"Error cancelling request: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to cancel request',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_400_BAD_REQUEST)


class AllBorrowingRequestsView(generics.ListAPIView):
    """
    API view for library managers to view all borrowing requests with proper nested structure.
    Uses AdminBorrowRequestSerializer to include both borrow_status and delivery_status separately.
    """
    serializer_class = AdminBorrowRequestSerializer
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def get_queryset(self):
        """Get all borrowing requests with optional status filter and search"""
        status_filter = self.request.query_params.get('status', None)
        search_query = self.request.query_params.get('search', None)
        return BorrowingService.get_all_borrowing_requests(status=status_filter, search=search_query)
    
    def list(self, request, *args, **kwargs):
        try:
            queryset = self.get_queryset()
            serializer = self.get_serializer(queryset, many=True)
            data = serializer.data
            
            return Response({
                'success': True,
                'message': 'All borrowing requests retrieved successfully',
                'data': data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving all borrowing requests: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve borrowing requests',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class OverdueBorrowingsView(generics.ListAPIView):
    """
    API view for library managers to view overdue borrowings
    """
    serializer_class = BorrowRequestListSerializer
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def get_queryset(self):
        """Get overdue borrowings"""
        return BorrowingService.get_overdue_borrowings()
    
    def list(self, request, *args, **kwargs):
        try:
            queryset = self.get_queryset()
            serializer = self.get_serializer(queryset, many=True)
            
            return Response({
                'success': True,
                'message': 'Overdue borrowings retrieved successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving overdue borrowings: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve overdue borrowings',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class BorrowFineDetailView(generics.RetrieveAPIView):
    """
    API view for viewing fine details (now using unified ReturnFine model)
    """
    serializer_class = ReturnFineSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_object(self):
        """Get fine object with permission check"""
        borrow_id = self.kwargs.get('pk')
        borrow_request = get_object_or_404(BorrowRequest, id=borrow_id)
        
        # Check permissions
        if (borrow_request.customer != self.request.user and 
            not self.request.user.is_library_admin()):
            raise PermissionError("You don't have permission to view this fine")
        
        try:
            fine = ReturnFine.objects.get(borrow_request=borrow_request, fine_type='borrow')
            return fine
        except ReturnFine.DoesNotExist:
            # Return None if no fine exists - this is handled in retrieve method
            return None
    
    def retrieve(self, request, *args, **kwargs):
        try:
            instance = self.get_object()
            
            # Handle case where no fine exists
            if instance is None:
                return Response({
                    'success': False,
                    'message': 'No fine found for this borrowing',
                    'errors': {'fine': ['This borrowing does not have any fines. The book was likely returned on time.']}
                }, status=status.HTTP_404_NOT_FOUND)
            
            serializer = self.get_serializer(instance)
            
            return Response({
                'success': True,
                'message': 'Fine details retrieved successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except PermissionError as e:
            return Response({
                'success': False,
                'message': 'Permission denied',
                'errors': {'permission': [str(e)]}
            }, status=status.HTTP_403_FORBIDDEN)
        except Exception as e:
            logger.error(f"Error retrieving fine details: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve fine details',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class BorrowingReportView(APIView):
    """
    API view for library managers to view borrowing reports
    """
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def get(self, request):
        try:
            statistics = BorrowingReportService.get_borrowing_statistics()
            recent_ratings = BorrowingReportService.get_recent_ratings()
            
            recent_ratings_data = BorrowRequestListSerializer(recent_ratings, many=True).data
            
            report_data = {
                **statistics,
                'recent_ratings': recent_ratings_data
            }
            
            serializer = BorrowingReportSerializer(data=report_data)
            serializer.is_valid()
            
            return Response({
                'success': True,
                'message': 'Borrowing report retrieved successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error generating borrowing report: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to generate report',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class BorrowStatisticsView(APIView):
    """
    API view to get borrowing statistics for the current user
    """
    permission_classes = [permissions.IsAuthenticated, CustomerOrAdmin]
    
    def get(self, request):
        try:
            user = request.user
            
            # Get user's borrowing statistics
            total_borrowings = BorrowRequest.objects.filter(customer=user).count()
            active_borrowings = BorrowRequest.objects.filter(
                customer=user, 
                status__in=['approved', 'delivered']
            ).count()
            overdue_borrowings = BorrowRequest.objects.filter(
                customer=user,
                status='delivered',
                expected_return_date__lt=timezone.now()
            ).count()
            pending_requests = BorrowRequest.objects.filter(
                customer=user,
                status='pending'
            ).count()
            
            statistics = {
                'total': total_borrowings,
                'active': active_borrowings,
                'overdue': overdue_borrowings,
                'pending': pending_requests
            }
            
            return Response({
                'success': True,
                'message': 'Borrowing statistics retrieved successfully',
                'data': statistics
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error getting borrowing statistics: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to get statistics',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class BorrowExtensionsListView(generics.ListAPIView):
    """
    API view for library managers to view all borrowing extensions
    """
    serializer_class = BorrowExtensionSerializer
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def get_queryset(self):
        """Get all borrowing extensions with optional filtering"""
        queryset = BorrowExtension.objects.select_related(
            'borrow_request__customer',
            'borrow_request__book'
        ).order_by('-created_at')
        
        # Filter by status if provided
        status_filter = self.request.query_params.get('status')
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        
        return queryset
    
    def list(self, request, *args, **kwargs):
        try:
            queryset = self.get_queryset()
            
            # Apply pagination
            page = int(request.query_params.get('page', 1))
            limit = int(request.query_params.get('limit', 10))
            
            start = (page - 1) * limit
            end = start + limit
            
            paginated_queryset = queryset[start:end]
            serializer = self.get_serializer(paginated_queryset, many=True)
            
            return Response({
                'success': True,
                'message': 'Borrowing extensions retrieved successfully',
                'data': serializer.data,
                'pagination': {
                    'page': page,
                    'limit': limit,
                    'total': queryset.count(),
                    'has_next': end < queryset.count(),
                    'has_previous': page > 1
                }
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving borrowing extensions: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve borrowing extensions',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class BorrowFinesListView(generics.ListAPIView):
    """
    API view for library managers to view all borrowing fines (now using unified ReturnFine model)
    """
    serializer_class = ReturnFineSerializer
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def get_queryset(self):
        """Get all borrowing fines with optional filtering"""
        queryset = ReturnFine.objects.filter(
            fine_type='borrow'
        ).select_related(
            'borrow_request__customer',
            'borrow_request__book'
        ).order_by('-created_at')
        
        # Filter by status if provided
        status_filter = self.request.query_params.get('status')
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        
        return queryset
    
    def list(self, request, *args, **kwargs):
        try:
            queryset = self.get_queryset()
            
            # Apply pagination
            page = int(request.query_params.get('page', 1))
            limit = int(request.query_params.get('limit', 10))
            
            start = (page - 1) * limit
            end = start + limit
            
            paginated_queryset = queryset[start:end]
            serializer = self.get_serializer(paginated_queryset, many=True)
            
            return Response({
                'success': True,
                'message': 'Borrowing fines retrieved successfully',
                'data': serializer.data,
                'pagination': {
                    'page': page,
                    'limit': limit,
                    'total': queryset.count(),
                    'has_next': end < queryset.count(),
                    'has_previous': page > 1
                }
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving borrowing fines: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve borrowing fines',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class LateReturnProcessView(APIView):
    """
    API view for processing late return scenarios
    """
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def post(self, request, borrow_request_id):
        """
        Process late return scenario for a specific borrowing
        """
        try:
            borrow_request = BorrowRequest.objects.get(id=borrow_request_id)
            
            # Process the late return scenario
            result = LateReturnService.process_late_return_scenario(borrow_request)
            
            if result['success']:
                return Response({
                    'success': True,
                    'message': result['message'],
                    'data': {
                        'fine_amount': result['fine_amount'],
                        'days_overdue': result['days_overdue'],
                        'status': borrow_request.status
                    }
                }, status=status.HTTP_200_OK)
            else:
                return Response({
                    'success': False,
                    'message': result['message']
                }, status=status.HTTP_400_BAD_REQUEST)
                
        except BorrowRequest.DoesNotExist:
            return Response({
                'success': False,
                'message': 'Borrow request not found'
            }, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"Error processing late return: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to process late return',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class LateReturnSummaryView(APIView):
    """
    API view for getting late return summary
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request, borrow_request_id):
        """
        Get comprehensive summary of late return status
        """
        try:
            borrow_request = BorrowRequest.objects.get(id=borrow_request_id)
            
            # Check permissions
            if borrow_request.customer != request.user and request.user.user_type not in ['library_admin', 'delivery_admin']:
                return Response({
                    'success': False,
                    'message': 'You do not have permission to view this information'
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Get late return summary
            summary = LateReturnService.get_late_return_summary(borrow_request)
            
            return Response({
                'success': True,
                'message': 'Late return summary retrieved successfully',
                'data': summary
            }, status=status.HTTP_200_OK)
                
        except BorrowRequest.DoesNotExist:
            return Response({
                'success': False,
                'message': 'Borrow request not found'
            }, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"Error retrieving late return summary: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve late return summary',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class ProcessOverdueBorrowingsView(APIView):
    """
    API view for library managers to manually process overdue borrowings
    """
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def post(self, request):
        try:
            # Process overdue borrowings and create fines
            BorrowingNotificationService.process_overdue_borrowings()
            
            # Send return reminders
            BorrowingNotificationService.send_return_reminders()
            
            return Response({
                'success': True,
                'message': 'Overdue borrowings processed successfully'
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error processing overdue borrowings: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to process overdue borrowings',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class DepositManagementView(APIView):
    """
    API view for managing deposits
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request, borrow_request_id):
        """
        Set deposit amount for a borrowing request
        """
        try:
            borrow_request = BorrowRequest.objects.get(id=borrow_request_id)
            
            # Only library admins can set deposit amounts
            if request.user.user_type != 'library_admin':
                return Response({
                    'success': False,
                    'message': 'Only library administrators can set deposit amounts'
                }, status=status.HTTP_403_FORBIDDEN)
            
            deposit_amount = request.data.get('deposit_amount')
            if not deposit_amount:
                return Response({
                    'success': False,
                    'message': 'Deposit amount is required'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Set deposit amount
            borrow_request.set_deposit_amount(Decimal(deposit_amount))
            
            return Response({
                'success': True,
                'message': 'Deposit amount set successfully',
                'data': {
                    'deposit_amount': borrow_request.deposit_amount,
                    'deposit_paid': borrow_request.deposit_paid
                }
            }, status=status.HTTP_200_OK)
                
        except BorrowRequest.DoesNotExist:
            return Response({
                'success': False,
                'message': 'Borrow request not found'
            }, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"Error setting deposit amount: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to set deposit amount',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def patch(self, request, borrow_request_id):
        """
        Mark deposit as paid
        """
        try:
            borrow_request = BorrowRequest.objects.get(id=borrow_request_id)
            
            # Check if user owns this borrowing request
            if borrow_request.customer != request.user:
                return Response({
                    'success': False,
                    'message': 'You can only pay deposits for your own borrowings'
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Mark deposit as paid
            borrow_request.mark_deposit_paid()
            
            return Response({
                'success': True,
                'message': 'Deposit marked as paid successfully',
                'data': {
                    'deposit_amount': borrow_request.deposit_amount,
                    'deposit_paid': borrow_request.deposit_paid
                }
            }, status=status.HTTP_200_OK)
                
        except BorrowRequest.DoesNotExist:
            return Response({
                'success': False,
                'message': 'Borrow request not found'
            }, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"Error marking deposit as paid: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to mark deposit as paid',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


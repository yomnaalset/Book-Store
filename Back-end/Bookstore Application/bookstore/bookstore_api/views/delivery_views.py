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
        queryset = DeliveryRequest.objects.all()
        
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
        
        # If user is delivery manager, show their assigned requests OR unassigned pending requests
        # This matches the logic in DeliveryRequestDetailView
        if user.is_delivery_admin():
            queryset = queryset.filter(
                Q(delivery_manager=user) | 
                Q(delivery_manager__isnull=True, status='pending')
            )
        
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
                        # Map ReturnRequest status to DeliveryRequest status
                        status_mapping = {
                            ReturnStatus.PENDING: 'pending',
                            ReturnStatus.APPROVED: 'pending',
                            ReturnStatus.ASSIGNED: 'assigned',
                            ReturnStatus.ACCEPTED: 'accepted',
                            ReturnStatus.IN_PROGRESS: 'in_delivery',
                        }
                        delivery_status = status_mapping.get(return_request.status, 'pending')
                        
                        # Get customer from the borrowing request
                        customer = return_request.borrowing.customer
                        
                        # Get delivery address from borrowing request
                        delivery_address = return_request.borrowing.delivery_address
                        
                        # Set assigned_at if status is assigned or accepted
                        assigned_at = None
                        if return_request.status in [ReturnStatus.ASSIGNED, ReturnStatus.ACCEPTED] and return_request.accepted_at:
                            assigned_at = return_request.accepted_at
                        
                        # Create DeliveryRequest for this ReturnRequest
                        DeliveryRequest.objects.create(
                            delivery_type='return',
                            customer=customer,
                            delivery_address=delivery_address,
                            return_request=return_request,
                            delivery_manager=return_request.delivery_manager,
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
                        # Map BorrowRequest status to DeliveryRequest status
                        status_mapping = {
                            BorrowStatusChoices.APPROVED: 'pending',
                            BorrowStatusChoices.ASSIGNED_TO_DELIVERY: 'assigned',
                            BorrowStatusChoices.PENDING_DELIVERY: 'assigned',
                            BorrowStatusChoices.AWAITING_PICKUP: 'assigned',
                            BorrowStatusChoices.OUT_FOR_DELIVERY: 'in_delivery',
                        }
                        delivery_status = status_mapping.get(borrow_request.status, 'pending')
                        
                        # Set assigned_at if delivery manager is assigned and approved_date exists
                        assigned_at = None
                        if borrow_request.delivery_person and borrow_request.approved_date:
                            assigned_at = borrow_request.approved_date
                        
                        # Create DeliveryRequest for this BorrowRequest
                        DeliveryRequest.objects.create(
                            delivery_type='borrow',
                            customer=borrow_request.customer,
                            delivery_address=borrow_request.delivery_address,
                            borrow_request=borrow_request,
                            delivery_manager=borrow_request.delivery_person,
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
        return Response({
            'success': True,
            'count': len(response.data),
            'results': response.data
        })


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
        queryset = DeliveryRequest.objects.all()
        
        # If user is delivery manager, show their assigned requests OR unassigned requests
        if user.is_delivery_admin():
            queryset = queryset.filter(
                Q(delivery_manager=user) | 
                Q(delivery_manager__isnull=True, status='pending')
            )
        
        # Admins can see all requests
        return queryset

    def get_object(self):
        """Override to provide better error messages."""
        try:
            # First check if the object exists at all
            pk = self.kwargs.get('pk')
            try:
                delivery_request = DeliveryRequest.objects.get(pk=pk)
            except DeliveryRequest.DoesNotExist:
                raise NotFound(f"Delivery request with ID {pk} does not exist.")
            
            # Then check if user has permission to view it
            user = self.request.user
            
            # Library admins can see all requests
            if user.user_type == 'library_admin' or user.is_staff or user.is_superuser:
                return delivery_request
            
            # For delivery managers, check if they have access
            if user.is_delivery_admin():
                # Can see if assigned to them OR unassigned and pending
                if (delivery_request.delivery_manager == user or 
                    (delivery_request.delivery_manager is None and delivery_request.status == 'pending')):
                    return delivery_request
                else:
                    # Object exists but user doesn't have permission
                    raise NotFound(
                        f"Delivery request {pk} is not assigned to you or is not available for viewing. "
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
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        logger.error(f"Error starting delivery: {str(e)}")
        return Response({
            'success': False,
            'error': 'Failed to start delivery'
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
            queryset = Order.objects.all()
        else:
            queryset = Order.objects.filter(customer=user)
        
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
        
        return queryset.order_by('-created_at')
    
    def get_serializer_class(self):
        """Return appropriate serializer based on request method."""
        if self.request.method == 'POST':
            from ..serializers.delivery_serializers import OrderCreateSerializer
            return OrderCreateSerializer
        return CustomerOrderSerializer
    
    def list(self, request, *args, **kwargs):
        """Override list to add custom response format."""
        response = super().list(request, *args, **kwargs)
        return Response({
            'success': True,
            'count': len(response.data),
            'results': response.data
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
                total = total.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
                
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
                    amount=total,
                    payment_type=payment_type,  # Use 'payment_type' not 'payment_method'
                    cart=cart,  # Required field
                    status='pending' if payment_method == 'cash_on_delivery' or payment_method == 'cash' else 'completed'
                )
                
                # Create order
                order = Order.objects.create(
                    customer=user,
                    order_type='purchase',
                    status='pending',
                    total_amount=total,
                    delivery_cost=Decimal('0.00'),
                    tax_amount=Decimal('0.00'),
                    discount_amount=Decimal('0.00'),
                    delivery_address=delivery_address,
                    notes=delivery_notes,
                    payment=payment
                )
                
                # Create order items
                # Database has both 'price' and 'unit_price' columns
                # Use raw SQL to set both fields at once
                from django.db import connection
                for item_data in order_items_data:
                    unit_price = item_data['price']
                    item_total = unit_price * item_data['quantity']
                    with connection.cursor() as cursor:
                        cursor.execute(
                            """
                            INSERT INTO order_item (order_id, book_id, quantity, price, unit_price, total_price, created_at)
                            VALUES (%s, %s, %s, %s, %s, %s, NOW())
                            """,
                            [
                                order.id,
                                item_data['book'].id,
                                item_data['quantity'],
                                str(unit_price),  # price column (convert Decimal to string)
                                str(unit_price),  # unit_price column (same value)
                                str(item_total),  # total_price (convert Decimal to string)
                            ]
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
            return Order.objects.all()
        return Order.objects.filter(customer=user)
    
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
            # Create new delivery request
            from ..services.delivery_services import DeliveryService
            delivery_request = DeliveryService.create_delivery_request(
                delivery_type='purchase',
                customer=order.customer,
                delivery_address=order.delivery_address,
                order=order
            )
            delivery_request.delivery_manager = delivery_manager
            delivery_request.status = 'assigned'
            delivery_request.assigned_at = timezone.now()
            delivery_request.save()
        
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
        
        # Base queryset: delivery-related notifications for current user
        notifications = Notification.objects.filter(
            recipient=user,
            notification_type__name__in=delivery_notification_types
        ).order_by('-created_at')
        
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
        
        return Response({
            'success': True,
            'notifications': serializer.data,
            'count': len(serializer.data)
        }, status=status.HTTP_200_OK)
    except Exception as e:
        logger.error(f"Error fetching delivery notifications: {str(e)}")
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


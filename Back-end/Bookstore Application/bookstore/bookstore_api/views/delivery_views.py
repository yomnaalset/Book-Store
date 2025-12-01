from rest_framework import generics, status, permissions, viewsets
from bookstore_api.authentication import CustomJWTAuthentication
from rest_framework.decorators import api_view, permission_classes, action
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.pagination import PageNumberPagination
from django.shortcuts import get_object_or_404
from django.utils import timezone
from django.core.exceptions import PermissionDenied, ValidationError
from django.db.models import Q
from django.core.paginator import Paginator
import logging
from datetime import datetime

from ..models import User, DeliveryRequest, Order, DeliveryAssignment, DeliveryStatusHistory, OrderItem, CartItem
from ..models.library_model import Book
from ..services import NotificationService
from ..serializers.delivery_serializers import (
    OrderListSerializer, OrderDetailSerializer, OrderStatusUpdateSerializer,
    DeliveryRequestCreateSerializer,
    DeliveryRequestListSerializer,
    DeliveryRequestDetailSerializer,
    BorrowingOrderSerializer,
    DeliveryRequestAssignSerializer,
    DeliveryRequestStatusUpdateSerializer,
    DeliveryAssignmentBasicSerializer,
    OrderCreateFromPaymentSerializer,
    OrderCreateSerializer,
    DeliveryRequestWithAvailableManagersSerializer,
    OrderApprovalSerializer,
    DeliveryManagerAssignmentSerializer,
    DeliveryStartSerializer,
    DeliveryCompletionSerializer,
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
            
            # Create notification for delivery manager
            try:
                from ..services.notification_services import NotificationService
                request_type = delivery_request.request_type.title()
                order_info = ""
                if delivery_request.order:
                    order_info = f" for order #{delivery_request.order.order_number}"
                NotificationService.create_notification(
                    user_id=delivery_manager.id,
                    title=f"New {request_type} Request Assigned",
                    message=f"You have been assigned a {delivery_request.request_type} request{order_info}. Delivery address: {delivery_request.delivery_address}.",
                    notification_type="delivery_request_assigned",
                    related_order_id=delivery_request.order.id if delivery_request.order else None
                )
            except Exception as e:
                logger.error(f"Failed to create notification for delivery request assignment: {str(e)}")
            
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
                # Set delivery manager status back to Online when delivery is completed
                if delivery_request.delivery_manager:
                    try:
                        from ..services.delivery_profile_services import DeliveryProfileService
                        DeliveryProfileService.complete_delivery_task(delivery_request.delivery_manager)
                    except Exception as e:
                        logger.warning(f"Failed to update delivery manager status to online: {str(e)}")
            
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
    serializer_class = DeliveryRequestListSerializer
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    pagination_class = PageNumberPagination
    
    def get_queryset(self):
        # Get delivery requests with order information
        queryset = DeliveryRequest.objects.select_related('customer', 'delivery_manager', 'assigned_by', 'order', 'order__customer', 'order__payment').prefetch_related('order__items__book').all()
        
        # Filter by status
        status_filter = self.request.query_params.get('status')
        if status_filter:
            if status_filter == 'pending':
                queryset = queryset.filter(status='pending')
            elif status_filter == 'assigned':
                queryset = queryset.filter(status='assigned')
            elif status_filter == 'in_progress':
                queryset = queryset.filter(status='in_progress')
            elif status_filter == 'completed':
                queryset = queryset.filter(status='completed')
        
        # Filter by customer
        customer_id = self.request.query_params.get('customer_id')
        if customer_id:
            queryset = queryset.filter(customer_id=customer_id)
        
        # Search functionality
        search = self.request.query_params.get('search')
        if search:
            from django.db.models import Q
            queryset = queryset.filter(
                Q(id__icontains=search) |
                Q(customer__first_name__icontains=search) |
                Q(customer__last_name__icontains=search) |
                Q(customer__email__icontains=search) |
                Q(delivery_address__icontains=search) |
                Q(delivery_city__icontains=search) |
                Q(notes__icontains=search) |
                Q(status__icontains=search)
            )
        
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
            from ..models.delivery_profile_model import DeliveryProfile
            try:
                delivery_profile = DeliveryProfile.objects.get(user=delivery_manager)
                if delivery_profile.delivery_status == 'busy':
                    active_requests_count = delivery_manager.assigned_requests.filter(status='in_operation').count()
                    if active_requests_count > 0:
                        return Response({
                            'error': 'Selected delivery manager is currently busy with another delivery'
                        }, status=status.HTTP_400_BAD_REQUEST)
            except DeliveryProfile.DoesNotExist:
                pass  # No profile exists, allow assignment
            
            # Update request
            delivery_request.delivery_manager = delivery_manager
            delivery_request.status = 'in_operation'
            delivery_request.assigned_at = timezone.now()
            delivery_request.assigned_by = request.user  # Record who assigned the manager
            if notes:
                delivery_request.delivery_notes = notes
                
            # Save the delivery request
            delivery_request.save()
            
            # Do not change delivery_manager.delivery_status here
            # Keep the manager "Online" until they accept the task
            
            # Create notification for delivery manager
            try:
                from ..services.notification_services import NotificationService
                request_type = delivery_request.request_type.title()
                order_info = ""
                if delivery_request.order:
                    order_info = f" for order #{delivery_request.order.order_number}"
                NotificationService.create_notification(
                    user_id=delivery_manager.id,
                    title=f"New {request_type} Request Assigned",
                    message=f"You have been assigned a {delivery_request.request_type} request{order_info}. Delivery address: {delivery_request.delivery_address}. Notes: {delivery_request.notes or 'None'}",
                    notification_type="delivery_request_assigned",
                    related_order_id=delivery_request.order.id if delivery_request.order else None
                )
            except Exception as e:
                logger.error(f"Failed to create notification for delivery request assignment: {str(e)}")
            
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
        
        # Filter by order type (purchase, borrowing, return_collection)
        # Default to 'purchase' for admin views to avoid mixing purchase and borrowing orders
        order_type = self.request.query_params.get('order_type')
        if order_type:
            queryset = queryset.filter(order_type=order_type)
        else:
            # Default to purchase orders for admin/delivery manager views
            user = self.request.user
            if user.is_library_admin() or user.is_staff or user.is_delivery_admin():
                queryset = queryset.filter(order_type='purchase')
        
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
        
        # Search by order number, customer name, email, or delivery address
        search = self.request.query_params.get('search')
        if search:
            queryset = queryset.filter(
                Q(order_number__icontains=search) |
                Q(customer__first_name__icontains=search) |
                Q(customer__last_name__icontains=search) |
                Q(customer__email__icontains=search) |
                Q(delivery_address__icontains=search) |
                Q(delivery_city__icontains=search) |
                Q(delivery_notes__icontains=search) |
                Q(items__book__name__icontains=search) |
                Q(items__book__author__name__icontains=search)
            ).distinct()
        
        return queryset.order_by('-created_at')
    
    def list(self, request, *args, **kwargs):
        """
        Override the default list method to ensure consistent response format.
        """
        queryset = self.get_queryset()
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
        return Order.objects.select_related('customer', 'payment').prefetch_related('items__book', 'notes__author')
    
    def get_object(self):
        order = super().get_object()
        user = self.request.user
        
        # Check permissions
        if not (user.is_delivery_admin() or user.is_library_admin() or order.customer == user):
            self.permission_denied(self.request, message="You don't have permission to view this order.")
        
        return order
    
    def get_serializer_context(self):
        """Ensure request context is passed to serializer"""
        context = super().get_serializer_context()
        context['request'] = self.request
        return context


class OrderViewSet(viewsets.ModelViewSet):
    """
    Complete Order management system for the purchase flow.
    Handles order creation, approval, assignment, and tracking.
    """
    queryset = Order.objects.select_related('customer', 'payment').prefetch_related('items__book', 'notes__author')
    permission_classes = [permissions.IsAuthenticated]
    authentication_classes = [CustomJWTAuthentication]
    
    def get_serializer_context(self):
        """Ensure request context is passed to serializer"""
        context = super().get_serializer_context()
        context['request'] = self.request
        return context
    
    def get_serializer_class(self):
        if self.action == 'create':
            return OrderCreateFromPaymentSerializer
        elif self.action in ['update', 'partial_update']:
            return OrderStatusUpdateSerializer
        elif self.action == 'approve':
            return OrderApprovalSerializer
        elif self.action == 'assign_delivery_manager':
            return DeliveryManagerAssignmentSerializer
        elif self.action == 'start_delivery':
            return DeliveryStartSerializer
        elif self.action == 'complete_delivery':
            return DeliveryCompletionSerializer
        return OrderDetailSerializer
    
    def get_queryset(self):
        user = self.request.user
        
        # Base queryset - prefetch notes with authors for efficient loading
        queryset = Order.objects.select_related('customer', 'payment').prefetch_related('items__book', 'notes__author')
        
        # Apply user-based filtering
        if user.is_customer():
            queryset = queryset.filter(customer=user)
        elif user.is_delivery_admin():
            # Delivery managers can see orders assigned to them
            # Include 'waiting_for_delivery_manager' status so they can see new orders waiting for their confirmation
            queryset = queryset.filter(
                Q(delivery_assignment__delivery_manager=user, status='waiting_for_delivery_manager') |
                Q(delivery_assignment__delivery_manager=user, status='assigned_to_delivery') |
                Q(delivery_assignment__delivery_manager=user, status='in_delivery') |
                Q(delivery_assignment__delivery_manager=user, status='delivery_in_progress') |
                Q(delivery_assignment__delivery_manager=user, status='in_progress') |
                Q(delivery_assignment__delivery_manager=user, status='delivered') |
                Q(delivery_assignment__delivery_manager=user, status='completed')
            ).distinct()
        elif user.is_library_admin() or user.is_staff:
            # Library admins and staff can see all orders
            pass
        else:
            return Order.objects.none()
        
        # Apply additional filters
        # Filter by order type (purchase, borrowing, return_collection)
        # Default to 'purchase' for admin and delivery manager views to avoid mixing purchase and borrowing orders
        order_type = self.request.query_params.get('order_type')
        if order_type:
            queryset = queryset.filter(order_type=order_type)
        elif user.is_library_admin() or user.is_staff or user.is_delivery_admin():
            # For admin and delivery manager views, default to purchase orders unless explicitly requesting borrowing
            # This prevents purchase and borrowing orders from being mixed up
            queryset = queryset.filter(order_type='purchase')
        
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
        
        # Search by order number, customer name, email, or delivery address
        search = self.request.query_params.get('search')
        if search:
            queryset = queryset.filter(
                Q(order_number__icontains=search) |
                Q(customer__first_name__icontains=search) |
                Q(customer__last_name__icontains=search) |
                Q(customer__email__icontains=search) |
                Q(delivery_address__icontains=search) |
                Q(delivery_city__icontains=search) |
                Q(delivery_notes__icontains=search) |
                Q(items__book__name__icontains=search) |
                Q(items__book__author__name__icontains=search)
            ).distinct()
        
        return queryset.order_by('-created_at')
    
    def create(self, request):
        """
        Create a new order from cart items.
        This handles the customer purchase flow.
        """
        try:
            user = request.user
            
            # Debug authentication
            logger.info(f"Request user: {user}")
            logger.info(f"Request user type: {type(user)}")
            logger.info(f"Request user ID: {user.id if user else 'None'}")
            logger.info(f"Request user is_authenticated: {user.is_authenticated if user else 'None'}")
            logger.info(f"Request headers: {dict(request.headers)}")
            logger.info(f"Request META: {dict(request.META)}")
            
            if not user:
                return Response({
                    'error': 'Authentication required. Please log in to place an order.'
                }, status=status.HTTP_401_UNAUTHORIZED)
            
            if not user.is_customer():
                return Response({
                    'error': 'Only customers can create orders'
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Get cart items - can be either IDs or direct item data
            cart_items = request.data.get('cart_items', [])
            total_price = request.data.get('total_price', 0)
            address = request.data.get('address', '')
            city = request.data.get('city', 'Unknown')
            payment_method = request.data.get('payment_method', 'cash')
            card_details = request.data.get('card_details')
            
            if not cart_items:
                return Response({
                    'error': 'Cart is empty'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Validate payment method and card details
            if payment_method == 'mastercard':
                if not card_details:
                    return Response({
                        'error': 'Card details are required for Mastercard payment'
                    }, status=status.HTTP_400_BAD_REQUEST)
                
                # Validate required card fields
                required_fields = ['card_number', 'cardholder_name', 'expiry_date', 'cvv']
                for field in required_fields:
                    if not card_details.get(field):
                        return Response({
                            'error': f'Card {field.replace("_", " ")} is required'
                        }, status=status.HTTP_400_BAD_REQUEST)
                
                # Basic card number validation
                card_number = card_details.get('card_number', '').replace(' ', '').replace('-', '')
                if len(card_number) < 13 or len(card_number) > 19:
                    return Response({
                        'error': 'Invalid card number format'
                    }, status=status.HTTP_400_BAD_REQUEST)
                
                # Basic CVV validation
                cvv = card_details.get('cvv', '')
                if not cvv.isdigit() or len(cvv) < 3 or len(cvv) > 4:
                    return Response({
                        'error': 'Invalid CVV format'
                    }, status=status.HTTP_400_BAD_REQUEST)
            
            logger.info(f"User object: {user}")
            logger.info(f"User ID: {user.id}")
            logger.info(f"User ID type: {type(user.id)}")
            
            # Calculate subtotal, tax, and delivery cost from cart items
            from decimal import Decimal
            TAX_RATE = Decimal('0.08')  # 8% tax rate
            DELIVERY_RATE = Decimal('0.04')  # 4% delivery cost rate
            
            subtotal = Decimal('0.00')
            for item_data in cart_items:
                if isinstance(item_data, dict):
                    book_id = item_data.get('book_id')
                    quantity = item_data.get('quantity', 1)
                    price = Decimal(str(item_data.get('price', 0)))
                    subtotal += price * quantity
                else:
                    try:
                        cart_item = CartItem.objects.get(id=item_data, cart__customer=user)
                        subtotal += cart_item.book.price * cart_item.quantity
                    except CartItem.DoesNotExist:
                        continue
            
            # Calculate tax
            tax_amount = subtotal * TAX_RATE
            
            # Get discount amount from request if available
            discount_amount = Decimal(str(request.data.get('discount_amount', 0)))
            
            # Calculate final invoice value (subtotal + tax - discount)
            final_invoice_value = subtotal + tax_amount - discount_amount
            
            # Calculate delivery cost (4% of final invoice value)
            delivery_cost = final_invoice_value * DELIVERY_RATE
            
            # Create order with pending status
            order_data = {
                'customer': user.id,
                'total_amount': total_price,
                'delivery_address': address,
                'delivery_city': city,
                'status': 'pending',
                'order_type': 'purchase'
            }
            
            logger.info(f"Order data: {order_data}")
            logger.info(f"Customer in order_data: {order_data.get('customer')}")
            logger.info(f"Customer type: {type(order_data.get('customer'))}")
            
            # Create order directly without serializer
            order = Order.objects.create(
                customer=user,
                total_amount=total_price,
                delivery_address=address,
                delivery_city=city,
                status='pending',  # Status: "Pending Review" as per scenario
                order_type='purchase',
                payment_method=payment_method,
                delivery_cost=delivery_cost,
                discount_amount=discount_amount if discount_amount > 0 else Decimal('0.00')
            )
            
            # Send notification to all admins about new purchase request
            from ..services.notification_services import NotificationService
            admin_users = User.objects.filter(
                user_type__in=['library_admin', 'system_admin'],
                is_active=True
            )
            for admin in admin_users:
                try:
                    NotificationService.create_notification(
                        user_id=admin.id,
                        title="New Purchase Request",
                        message=f"A new order #{order.order_number} has been placed and requires your review.",
                        notification_type="new_order",
                        related_order_id=order.id
                    )
                except Exception as e:
                    logger.warning(f"Failed to notify admin {admin.id} about new order: {str(e)}")
            
            # Create order items from cart
            for item_data in cart_items:
                    try:
                        # Handle both ID-based and direct data cart items
                        if isinstance(item_data, dict):
                            # Direct cart item data from frontend
                            book_id = item_data.get('book_id')
                            quantity = item_data.get('quantity', 1)
                            price = item_data.get('price', 0)
                            
                            if book_id:
                                try:
                                    book = Book.objects.get(id=book_id)
                                    OrderItem.objects.create(
                                        order=order,
                                        book=book,
                                        quantity=quantity,
                                        unit_price=price,
                                        total_price=price * quantity
                                    )
                                except Book.DoesNotExist:
                                    continue
                        else:
                            # ID-based cart item (existing behavior)
                            cart_item = CartItem.objects.get(id=item_data, cart__customer=user)
                            OrderItem.objects.create(
                                order=order,
                                book=cart_item.book,
                                quantity=cart_item.quantity,
                                unit_price=cart_item.book.price,
                                total_price=cart_item.book.price * cart_item.quantity
                            )
                    except CartItem.DoesNotExist:
                        continue
            
            # Create delivery request for the order
            try:
                from ..models.delivery_model import DeliveryRequest
                from django.utils import timezone
                from datetime import timedelta
                
                # Calculate preferred delivery time (24 hours from now)
                preferred_delivery_time = timezone.now() + timedelta(hours=24)
                
                delivery_request = DeliveryRequest.objects.create(
                    customer=user,
                    order=order,
                    request_type='delivery',
                    delivery_address=address,
                    delivery_city=city,
                    preferred_pickup_time=timezone.now() + timedelta(hours=1),  # 1 hour from now
                    preferred_delivery_time=preferred_delivery_time,
                    status='pending',
                    notes=f'Delivery request for order #{order.order_number}'
                )
                
                logger.info(f"Created delivery request {delivery_request.id} for order {order.id}")
                
            except Exception as e:
                logger.error(f"Failed to create delivery request for order {order.id}: {str(e)}")
                # Don't fail the order creation if delivery request creation fails
                pass
            
            # Send notification to admin
            NotificationService.create_notification(
                user_id=1,  # Admin user ID
                title="New Order Pending Approval",
                message=f"Customer {user.get_full_name()} has placed a new order (#{order.order_number})",
                notification_type="order_pending",
                related_order_id=order.id
            )
            
            # Clear cart after successful order creation
            user.cart.clear()
            
            return Response({
                    'success': True,
                    'message': 'Order created successfully',
                    'order': OrderDetailSerializer(order).data
                }, status=status.HTTP_201_CREATED)
            
            return Response({
                'error': 'Invalid order data',
                'details': serializer.errors
            }, status=status.HTTP_400_BAD_REQUEST)
            
        except Exception as e:
            logger.error(f"Error creating order: {str(e)}")
            logger.error(f"Exception type: {type(e)}")
            import traceback
            logger.error(f"Traceback: {traceback.format_exc()}")
            return Response({
                'error': 'An error occurred while creating the order',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    @action(detail=True, methods=['patch'])
    def approve(self, request, pk=None):
        """
        Approve an order and assign delivery manager.
        Accessible by library admins and system admins.
        """
        try:
            order = self.get_object()
            user = request.user
            
            if not (user.is_library_admin() or user.is_staff):
                return Response({
                    'error': 'Only administrators can approve orders'
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Validate request data with serializer
            serializer = self.get_serializer(data=request.data)
            if not serializer.is_valid():
                return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
            
            if order.status != 'pending':
                return Response({
                    'error': f'Order is not in pending status. Current status: {order.status}'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            delivery_manager_id = serializer.validated_data.get('delivery_manager_id')
            if not delivery_manager_id:
                return Response({
                    'error': 'Delivery manager ID is required'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            try:
                delivery_manager = User.objects.get(
                    id=delivery_manager_id,
                    user_type='delivery_admin'
                )
            except User.DoesNotExist:
                return Response({
                    'error': 'Invalid delivery manager'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Check if delivery manager is available
            if hasattr(delivery_manager, 'delivery_profile') and delivery_manager.delivery_profile:
                if delivery_manager.delivery_profile.delivery_status != 'online':
                    return Response({
                        'error': 'Selected delivery manager is not available'
                    }, status=status.HTTP_400_BAD_REQUEST)
            
            # Calculate estimated delivery time (default: 24 hours from now)
            from datetime import timedelta
            estimated_delivery_time = timezone.now() + timedelta(hours=24)
            
            # Check if delivery assignment already exists for this order
            # Since DeliveryAssignment has OneToOneField with Order, we need to handle existing assignments
            delivery_assignment = None
            try:
                delivery_assignment = DeliveryAssignment.objects.get(order=order)
                # Update existing assignment
                delivery_assignment.delivery_manager = delivery_manager
                delivery_assignment.status = 'assigned'
                delivery_assignment.assigned_by = user
                delivery_assignment.assigned_at = timezone.now()
                delivery_assignment.estimated_delivery_time = estimated_delivery_time
                delivery_assignment.save()
            except DeliveryAssignment.DoesNotExist:
                # Create new delivery assignment
                delivery_assignment = DeliveryAssignment.objects.create(
                    order=order,
                    delivery_manager=delivery_manager,
                    status='assigned',
                    assigned_by=user,
                    estimated_delivery_time=estimated_delivery_time
                )
            
            # Update order status to 'waiting_for_delivery_manager' (as per scenario)
            order.status = 'waiting_for_delivery_manager'
            order.save()
            
            # Send notifications
            NotificationService.create_notification(
                user_id=order.customer.id,
                title="Order Approved",
                message=f"Your order #{order.order_number} has been approved by admin and is waiting for delivery manager confirmation.",
                notification_type="order_approved",
                related_order_id=order.id
            )
            
            NotificationService.create_notification(
                user_id=delivery_manager.id,
                title="New Delivery Assignment",
                message=f"You have been assigned order #{order.order_number} for delivery. Please review and confirm.",
                notification_type="delivery_assigned",
                related_order_id=order.id
            )
            
            return Response({
                'success': True,
                'message': 'Order approved and delivery manager assigned',
                'order': OrderDetailSerializer(order).data,
                'delivery_assignment': DeliveryAssignmentBasicSerializer(delivery_assignment).data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error approving order: {str(e)}")
            return Response({
                'error': 'An error occurred while approving the order'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    @action(detail=True, methods=['patch'])
    def reject(self, request, pk=None):
        """
        Reject an order.
        Accessible by library admins and system admins.
        """
        try:
            order = self.get_object()
            user = request.user
            
            if not (user.is_library_admin() or user.is_staff):
                return Response({
                    'error': 'Only administrators can reject orders'
                }, status=status.HTTP_403_FORBIDDEN)
            
            if order.status != 'pending':
                return Response({
                    'error': 'Order is not in pending status'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            rejection_reason = request.data.get('rejection_reason', 'No reason provided')
            
            # Update order status to 'rejected_by_admin' (as per scenario)
            order.status = 'rejected_by_admin'
            order.cancellation_reason = rejection_reason
            # Restore book quantities when order is rejected
            order.restore_book_quantities()
            order.save()
            
            # Send notification to customer
            try:
                NotificationService.create_notification(
                    user_id=order.customer.id,
                    title="Order Rejected by Admin",
                    message=f"Your order #{order.order_number} has been rejected by admin. Reason: {rejection_reason}",
                    notification_type="order_rejected",
                    related_order_id=order.id
                )
            except Exception as notification_error:
                logger.warning(f"Failed to create notification for order rejection: {str(notification_error)}")
                # Continue with the response even if notification fails
            
            # Try to serialize the order, but don't fail if it doesn't work
            try:
                order_data = OrderDetailSerializer(order).data
            except Exception as serializer_error:
                logger.warning(f"Failed to serialize order data: {str(serializer_error)}")
                order_data = {
                    'id': order.id,
                    'order_number': order.order_number,
                    'status': order.status,
                    'total_amount': str(order.total_amount),
                }
            
            return Response({
                'success': True,
                'message': 'Order rejected successfully',
                'order': order_data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error rejecting order: {str(e)}")
            return Response({
                'error': 'An error occurred while rejecting the order'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    @action(detail=True, methods=['patch'])
    def start_delivery(self, request, pk=None):
        """
        Start delivery tracking for an assigned order.
        Accessible by assigned delivery managers.
        """
        try:
            order = self.get_object()
            user = request.user
            
            if not user.is_delivery_admin():
                return Response({
                    'error': 'Only delivery managers can start delivery'
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Check if order is assigned to this delivery manager
            delivery_assignment = DeliveryAssignment.objects.filter(
                order=order,
                delivery_manager=user,
            ).first()
            
            if not delivery_assignment:
                return Response({
                    'error': 'Order is not assigned to you'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Check if assignment is accepted (can only start delivery after acceptance)
            if delivery_assignment.status not in ['accepted', 'assigned']:
                return Response({
                    'error': f'Cannot start delivery. Assignment status is {delivery_assignment.status}'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Update delivery assignment status to 'in_transit'
            delivery_assignment.status = 'in_transit'
            delivery_assignment.started_at = timezone.now()
            delivery_assignment.save()
            
            # Update order status to 'in_progress' when delivery starts
            order.status = 'in_progress'
            order.save()
            
            # Set delivery manager status to 'busy' when starting delivery
            try:
                from ..services.delivery_profile_services import DeliveryProfileService
                DeliveryProfileService.start_delivery_task(user)
                logger.info(f"Delivery manager {user.email} status updated to busy when starting delivery")
            except Exception as e:
                logger.error(f"Failed to update delivery person status: {str(e)}")
            
            # Start real-time tracking
            if hasattr(user, 'real_time_tracking'):
                user.real_time_tracking.is_tracking_enabled = True
                user.real_time_tracking.is_delivering = True
                user.real_time_tracking.current_delivery_assignment = delivery_assignment
                user.real_time_tracking.save()
            
            # Send notifications
            NotificationService.create_notification(
                user_id=order.customer.id,
                title="Delivery Started",
                message=f"Your order #{order.order_number} is now out for delivery",
                notification_type="delivery_started",
                related_order_id=order.id
            )
            
            return Response({
                'success': True,
                'message': 'Delivery started successfully',
                'order': OrderDetailSerializer(order).data,
                'tracking_enabled': True
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error starting delivery: {str(e)}")
            return Response({
                'error': 'An error occurred while starting delivery'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    @action(detail=True, methods=['patch'])
    def complete_delivery(self, request, pk=None):
        """
        Complete delivery and mark order as delivered.
        Accessible by assigned delivery managers.
        """
        try:
            order = self.get_object()
            user = request.user
            
            if not user.is_delivery_admin():
                return Response({
                    'error': 'Only delivery managers can complete delivery'
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Check if order is in delivery status (as per scenario requirement)
            if order.status != 'in_delivery':
                return Response({
                    'error': f"Order must be in 'in_delivery' status to complete delivery. Current status: {order.status}"
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Check if order is assigned to this delivery manager
            # Accept multiple statuses since assignment can be in different states
            delivery_assignment = DeliveryAssignment.objects.filter(
                order=order,
                delivery_manager=user,
                status__in=['assigned', 'accepted', 'in_progress', 'in_transit']
            ).first()
            
            if not delivery_assignment:
                return Response({
                    'error': 'Order is not assigned to you or not ready for completion'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Update order status to 'completed' (as per scenario)
            order.status = 'completed'
            order.save()
            
            # Update delivery assignment
            delivery_assignment.status = 'completed'
            delivery_assignment.completed_at = timezone.now()
            delivery_assignment.save()
            
            # Reset delivery manager status to 'online' when delivery is completed
            try:
                from ..services.delivery_profile_services import DeliveryProfileService
                DeliveryProfileService.complete_delivery_task(user, completed_order_id=order.id)
                logger.info(f"Delivery manager {user.email} status updated after delivery completion")
            except Exception as e:
                logger.error(f"Failed to reset delivery person status: {str(e)}")
            
            # Stop real-time tracking immediately when delivery ends (as per scenario)
            try:
                if hasattr(user, 'real_time_tracking'):
                    user.real_time_tracking.is_tracking_enabled = False
                    user.real_time_tracking.is_delivering = False
                    user.real_time_tracking.current_delivery_assignment = None
                    user.real_time_tracking.save()
                
                # Update delivery profile - stop tracking
                from ..models.delivery_profile_model import DeliveryProfile
                delivery_profile = DeliveryProfile.objects.get(user=user)
                delivery_profile.is_tracking_active = False
                delivery_profile.save()
                
                # Automatically change delivery manager status from busy to online (as per scenario)
                # Only if there are no other active deliveries
                from ..services.delivery_profile_services import DeliveryProfileService
                try:
                    status_changed = DeliveryProfileService.complete_delivery_task(user, completed_order_id=order.id)
                    if status_changed:
                        logger.info(f"Delivery manager {user.email} status automatically changed to online after completing order {order.order_number}")
                    else:
                        # Fallback: Try reset_status_if_no_active_deliveries as a safety check
                        logger.info(f"complete_delivery_task returned False, trying reset_status_if_no_active_deliveries as fallback")
                        try:
                            DeliveryProfileService.reset_status_if_no_active_deliveries(user)
                            logger.info(f"Delivery manager {user.email} status reset to online via fallback method")
                        except Exception as fallback_error:
                            logger.warning(f"Fallback reset also failed: {str(fallback_error)}")
                except Exception as e:
                    logger.warning(f"Failed to change delivery manager status to online: {str(e)}")
                    # Try fallback method
                    try:
                        DeliveryProfileService.reset_status_if_no_active_deliveries(user)
                        logger.info(f"Delivery manager {user.email} status reset to online via fallback method after error")
                    except Exception as fallback_error:
                        logger.error(f"Fallback reset failed: {str(fallback_error)}")
                
                logger.info(f"GPS tracking stopped for delivery manager {user.email} after completing order {order.order_number}")
            except Exception as e:
                logger.error(f"Failed to stop GPS tracking: {str(e)}")
            
            # Send notifications
            NotificationService.create_notification(
                user_id=order.customer.id,
                title="Order Delivered",
                message=f"Your order #{order.order_number} has been successfully delivered!",
                notification_type="order_delivered",
                related_order_id=order.id
            )
            
            # Notify admins
            admin_users = User.objects.filter(
                user_type__in=['library_admin', 'system_admin']
            )
            for admin in admin_users:
                NotificationService.create_notification(
                    user_id=admin.id,
                    title="Order Delivered",
                    message=f"Order #{order.order_number} has been successfully delivered by {user.get_full_name()}",
                    notification_type="order_delivered_admin",
                    related_order_id=order.id
                )
            
            return Response({
                'success': True,
                'message': 'Delivery completed successfully',
                'order': OrderDetailSerializer(order).data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error completing delivery: {str(e)}")
            return Response({
                'error': 'An error occurred while completing delivery'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    @action(detail=True, methods=['patch'])
    def assign_delivery_manager(self, request, pk=None):
        """
        Assign a delivery manager to a confirmed order that doesn't have one yet.
        Accessible by library admins and system admins.
        """
        try:
            order = self.get_object()
            user = request.user
            
            if not (user.is_library_admin() or user.is_staff):
                return Response({
                    'error': 'Only administrators can assign delivery managers'
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Validate request data with serializer
            serializer = self.get_serializer(data=request.data)
            if not serializer.is_valid():
                return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
            
            # Check if order is confirmed (approved)
            if order.status != 'confirmed':
                return Response({
                    'error': f'Order must be confirmed before assigning delivery manager. Current status: {order.status}'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Check if order already has a delivery assignment
            if hasattr(order, 'delivery_assignment') and order.delivery_assignment:
                return Response({
                    'error': 'Order already has a delivery manager assigned'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            delivery_manager_id = serializer.validated_data.get('delivery_manager_id')
            if not delivery_manager_id:
                return Response({
                    'error': 'Delivery manager ID is required'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            try:
                delivery_manager = User.objects.get(
                    id=delivery_manager_id,
                    user_type='delivery_admin'
                )
            except User.DoesNotExist:
                return Response({
                    'error': 'Invalid delivery manager'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Check if delivery manager is available
            if hasattr(delivery_manager, 'delivery_profile') and delivery_manager.delivery_profile:
                if delivery_manager.delivery_profile.delivery_status != 'online':
                    return Response({
                        'error': 'Selected delivery manager is not available'
                    }, status=status.HTTP_400_BAD_REQUEST)
            
            # Calculate estimated delivery time (default: 24 hours from now)
            from datetime import timedelta
            estimated_delivery_time = timezone.now() + timedelta(hours=24)
            
            # Create delivery assignment
            delivery_assignment = DeliveryAssignment.objects.create(
                order=order,
                delivery_manager=delivery_manager,
                status='assigned',
                assigned_by=user,
                estimated_delivery_time=estimated_delivery_time
            )
            
            # Update order status to 'assigned_to_delivery'
            order.status = 'assigned_to_delivery'
            order.save()
            
            # Send notifications
            NotificationService.create_notification(
                user_id=order.customer.id,
                title="Delivery Manager Assigned",
                message=f"A delivery manager has been assigned to your order #{order.order_number}",
                notification_type="delivery_assigned",
                related_order_id=order.id
            )
            
            NotificationService.create_notification(
                user_id=delivery_manager.id,
                title="New Delivery Assignment",
                message=f"You have been assigned order #{order.order_number} for delivery",
                notification_type="delivery_assigned",
                related_order_id=order.id
            )
            
            return Response({
                'success': True,
                'message': 'Delivery manager assigned successfully',
                'order': OrderDetailSerializer(order).data,
                'delivery_assignment': DeliveryAssignmentBasicSerializer(delivery_assignment).data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error assigning delivery manager: {str(e)}")
            return Response({
                'error': 'An error occurred while assigning delivery manager',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    @action(detail=False, methods=['get'])
    def pending_approval(self, request):
        """
        Get orders pending approval.
        Accessible by library admins and system admins.
        """
        try:
            user = request.user
            
            if not (user.is_library_admin() or user.is_staff):
                return Response({
                    'error': 'Only administrators can view pending orders'
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Filter by order_type to separate purchase and borrowing orders
            pending_orders = Order.objects.filter(
                status='pending',
                order_type='purchase'  # Only show purchase orders for approval
            ).order_by('-created_at')
            serializer = OrderListSerializer(pending_orders, many=True)
            
            return Response({
                'success': True,
                'orders': serializer.data,
                'count': pending_orders.count()
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error getting pending orders: {str(e)}")
            return Response({
                'error': 'An error occurred while retrieving pending orders'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    @action(detail=False, methods=['get'])
    def available_delivery_managers(self, request):
        """
        Get available delivery managers for assignment.
        Accessible by library admins and system admins.
        """
        try:
            user = request.user
            
            if not (user.is_library_admin() or user.is_staff):
                return Response({
                    'error': 'Only administrators can view delivery managers'
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Get delivery managers with their status
            delivery_managers = User.objects.filter(user_type='delivery_admin').select_related('delivery_profile')
            
            managers_data = []
            for manager in delivery_managers:
                delivery_status = 'offline'
                if hasattr(manager, 'delivery_profile'):
                    delivery_status = manager.delivery_profile.delivery_status
                
                managers_data.append({
                    'id': manager.id,
                    'name': manager.get_full_name(),
                    'email': manager.email,
                    'phone': manager.profile.phone_number if hasattr(manager, 'profile') and manager.profile.phone_number else '',
                    'status': delivery_status,
                    'is_available': delivery_status in ['online', 'available']
                })
            
            return Response({
                'success': True,
                'delivery_managers': managers_data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error getting delivery managers: {str(e)}")
            return Response({
                'error': 'An error occurred while retrieving delivery managers'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


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
                # Reset delivery manager status to 'online' when order is delivered
                try:
                    if hasattr(order, 'delivery_assignment') and order.delivery_assignment:
                        from ..services.delivery_profile_services import DeliveryProfileService
                        DeliveryProfileService.complete_delivery_task(
                            order.delivery_assignment.delivery_manager,
                            completed_order_id=order.id
                        )
                        logger.info(f"Delivery manager status updated after order {order.order_number} was marked as delivered")
                except Exception as e:
                    logger.error(f"Failed to reset delivery person status: {str(e)}")
            elif new_status == 'completed':
                # Reset delivery manager status to 'online' when order is completed
                try:
                    if hasattr(order, 'delivery_assignment') and order.delivery_assignment:
                        from ..services.delivery_profile_services import DeliveryProfileService
                        DeliveryProfileService.complete_delivery_task(
                            order.delivery_assignment.delivery_manager,
                            completed_order_id=order.id
                        )
                        logger.info(f"Delivery manager status updated after order {order.order_number} was marked as completed")
                except Exception as e:
                    logger.error(f"Failed to reset delivery person status: {str(e)}")
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
            
            response_serializer = OrderDetailSerializer(order, context={'request': request})
            return Response({
                'message': f'Order status updated from {old_status} to {new_status}' ,
                'order': response_serializer.data
            }, status=status.HTTP_200_OK)
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


# ==================== DELIVERY ACTIVITY VIEWS ====================
# ------------------------------------------------------------
# 📝 1. Order Notes
# ------------------------------------------------------------
class NoteActivityView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        """
        Add, edit, or delete delivery notes for an order.
        Supports the new OrderNote model with author tracking.
        
        Request body:
        - order_id (required): ID of the order
        - notes_content (optional): Content of the note (for add/edit)
        - note_id (optional): ID of existing note (for edit/delete)
        - action (optional): 'add', 'edit', or 'delete' (defaults to 'add' if note_id not provided)
        """
        user = request.user
        order_id = request.data.get('order_id')
        notes_content = (request.data.get('notes_content') or '').strip()
        note_id = request.data.get('note_id')
        action = request.data.get('action', 'add').lower()

        if not order_id:
            return Response({'error': 'order_id is required'}, status=status.HTTP_400_BAD_REQUEST)

        order = get_object_or_404(Order, id=order_id)

        from ..models.delivery_model import OrderNote
        
        # Determine action based on note_id and action parameter
        note = None
        activity_type = None
        message = None
        
        if note_id:
            # Edit or delete existing note - check if user is the author
            try:
                note = OrderNote.objects.get(id=note_id, order=order, is_deleted=False)
                
                # Only the author can edit or delete their own note
                if note.author != user:
                    return Response({
                        'error': 'You can only edit or delete your own notes'
                    }, status=status.HTTP_403_FORBIDDEN)
                
                if action == 'delete' or (not notes_content and action != 'edit'):
                    # Delete note (soft delete)
                    note.is_deleted = True
                    note.save()
                    activity_type = 'delete_notes'
                    message = 'Note deleted successfully'
                else:
                    # Edit note
                    old_content = note.content
                    note.content = notes_content
                    note.save()
                    activity_type = 'edit_notes'
                    message = 'Note updated successfully'
                    
            except OrderNote.DoesNotExist:
                return Response({
                    'error': 'Note not found'
                }, status=status.HTTP_404_NOT_FOUND)
        else:
            # Add new note - check if user has permission to add notes to this order
            has_permission = False
            
            # Customers can add notes to their own orders
            if user.is_customer() and order.customer == user:
                has_permission = True
            # Admins (library_admin, delivery_admin) can add notes to any order
            elif user.user_type in ['library_admin', 'delivery_admin']:
                has_permission = True
            
            if not has_permission:
                return Response({
                    'error': 'You are not authorized to add notes to this order'
                }, status=status.HTTP_403_FORBIDDEN)
            
            if not notes_content:
                return Response({
                    'error': 'notes_content is required for adding a new note'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            note = OrderNote.objects.create(
                order=order,
                author=user,
                content=notes_content
            )
            activity_type = 'add_notes'
            message = 'Note added successfully'

        # Log activity for admins (delivery admins and library admins)
        # Note: DeliveryActivity model has limit_choices_to for delivery_admin, but we can still
        # assign library admins programmatically. If this causes issues, we may need to update the model.
        if note and (user.is_delivery_admin() or user.is_library_admin()):
            from ..models.delivery_model import DeliveryActivity
            try:
                # For library admins, we still assign them as delivery_manager
                # The limit_choices_to is only for admin interface, not programmatic assignment
                DeliveryActivity.objects.create(
                    delivery_manager=user,
                    order=order,
                    activity_type=activity_type,
                    activity_data={
                        'note_id': note.id,
                        'order_number': order.order_number,
                        'modified_by': user.get_full_name() or user.email,
                        'user_type': user.user_type,
                    },
                    ip_address=request.META.get('REMOTE_ADDR'),
                    user_agent=request.META.get('HTTP_USER_AGENT', ''),
                )
            except Exception as e:
                # Log error but don't fail the request
                logger.warning(f"Failed to log delivery activity: {str(e)}")

        return Response({
            'success': True,
            'message': message,
            'data': OrderDetailSerializer(order, context={'request': request}).data
        }, status=status.HTTP_200_OK)

# ------------------------------------------------------------
# ☎️ 2. Log Customer Contact
# ------------------------------------------------------------
class ContactActivityView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsDeliveryAdminOrLibraryAdmin]

    def post(self, request):
        user = request.user
        order_id = request.data.get('order_id')
        contact_method = request.data.get('contact_method', 'app')

        if not order_id:
            return Response({'error': 'order_id is required'}, status=status.HTTP_400_BAD_REQUEST)

        order = get_object_or_404(Order, id=order_id)

        from ..models.delivery_model import DeliveryActivity
        activity = DeliveryActivity.objects.create(
            delivery_manager=user,
            order=order,
            activity_type='contact_customer',
            activity_data={
                'contact_method': contact_method,
                'order_number': order.order_number,
                'customer_name': order.customer.get_full_name() if order.customer else 'Unknown'
            },
            ip_address=request.META.get('REMOTE_ADDR'),
            user_agent=request.META.get('HTTP_USER_AGENT', ''),
        )

        return Response({
            'success': True,
            'message': 'Customer contact logged successfully',
            'data': {'activity_id': activity.id}
        }, status=status.HTTP_201_CREATED)

# ------------------------------------------------------------
# 📍 3. Update Delivery Location
# ------------------------------------------------------------
class LocationActivityView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsDeliveryAdminOrLibraryAdmin]

    def post(self, request):
        user = request.user
        order_id = request.data.get('order_id')
        latitude = request.data.get('latitude')
        longitude = request.data.get('longitude')

        if not order_id or latitude is None or longitude is None:
            return Response({'error': 'order_id, latitude, and longitude are required'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            latitude = float(latitude)
            longitude = float(longitude)
        except ValueError:
            return Response({'error': 'Invalid coordinates'}, status=status.HTTP_400_BAD_REQUEST)

        order = get_object_or_404(Order, id=order_id)

        from ..models.delivery_model import DeliveryActivity
        activity = DeliveryActivity.objects.create(
            delivery_manager=user,
            order=order,
            activity_type='update_location',
            activity_data={
                'latitude': latitude,
                'longitude': longitude,
                'order_number': order.order_number
            },
            ip_address=request.META.get('REMOTE_ADDR'),
            user_agent=request.META.get('HTTP_USER_AGENT', ''),
        )

        return Response({'success': True, 'message': 'Location updated successfully'}, status=status.HTTP_201_CREATED)

# ------------------------------------------------------------
# 🚗 4. Log Route Viewing
# ------------------------------------------------------------
class RouteActivityView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsDeliveryAdminOrLibraryAdmin]

    def post(self, request):
        user = request.user
        order_id = request.data.get('order_id')
        route_source = request.data.get('route_source', 'app')

        if not order_id:
            return Response({'error': 'order_id is required'}, status=status.HTTP_400_BAD_REQUEST)

        order = get_object_or_404(Order, id=order_id)

        from ..models.delivery_model import DeliveryActivity
        DeliveryActivity.objects.create(
            delivery_manager=user,
            order=order,
            activity_type='view_route',
            activity_data={
                'route_source': route_source,
                'order_number': order.order_number
            },
            ip_address=request.META.get('REMOTE_ADDR'),
            user_agent=request.META.get('HTTP_USER_AGENT', ''),
        )

        return Response({'success': True, 'message': 'Route viewing logged successfully'}, status=status.HTTP_201_CREATED)

# ------------------------------------------------------------
# ⏱️ 5. Update Estimated Delivery Time (ETA)
# ------------------------------------------------------------
class ETAActivityView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsDeliveryAdminOrLibraryAdmin]

    def post(self, request):
        user = request.user
        order_id = request.data.get('order_id')
        estimated_delivery_time = request.data.get('estimated_delivery_time')

        if not order_id or not estimated_delivery_time:
            return Response({'error': 'order_id and estimated_delivery_time are required'}, status=status.HTTP_400_BAD_REQUEST)

        from datetime import datetime
        from django.utils import timezone
        try:
            # Parse the ISO string and ensure it's timezone-aware
            eta_str = estimated_delivery_time.replace('Z', '+00:00')
            eta = datetime.fromisoformat(eta_str)
            # Ensure the datetime is timezone-aware
            if eta.tzinfo is None:
                eta = timezone.make_aware(eta)
        except ValueError:
            return Response({'error': 'Invalid datetime format, please use ISO format'}, status=status.HTTP_400_BAD_REQUEST)

        order = get_object_or_404(Order, id=order_id)
        delivery_assignment, _ = DeliveryAssignment.objects.get_or_create(order=order, defaults={'delivery_manager': user})
        delivery_assignment.estimated_delivery_time = eta
        delivery_assignment.save()

        from ..models.delivery_model import DeliveryActivity
        DeliveryActivity.objects.create(
            delivery_manager=user,
            order=order,
            activity_type='update_eta',
            activity_data={'eta': eta.isoformat(), 'order_number': order.order_number},
        )

        return Response({'success': True, 'message': 'Estimated delivery time updated successfully'}, status=status.HTTP_201_CREATED)

# ------------------------------------------------------------
# 📦 6. Start or Complete Delivery
# ------------------------------------------------------------
class DeliveryActivityView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsDeliveryAdminOrLibraryAdmin]

    def post(self, request):
        user = request.user
        order_id = request.data.get('order_id')
        delivery_status = request.data.get('status')

        if not order_id or delivery_status not in ['start_delivery', 'complete_delivery']:
            return Response({'error': 'order_id is required and status must be "start_delivery" or "complete_delivery"'}, status=status.HTTP_400_BAD_REQUEST)

        order = get_object_or_404(Order, id=order_id)
        delivery_assignment = DeliveryAssignment.objects.filter(order=order).first()

        if not delivery_assignment:
            return Response({'error': 'No delivery assignment found for this order'}, status=status.HTTP_404_NOT_FOUND)

        if delivery_status == 'start_delivery':
            order.status = 'in_delivery'
            delivery_assignment.status = 'in_progress'
            delivery_assignment.started_at = timezone.now()
            message = f"Started delivery for order {order.order_number}"
            
            # Ensure delivery person status is 'busy' when starting delivery
            try:
                from ..services.delivery_profile_services import DeliveryProfileService
                DeliveryProfileService.start_delivery_task(user)
                logger.info(f"Delivery manager {user.email} status updated to busy when starting delivery")
            except Exception as e:
                logger.error(f"Failed to update delivery person status: {str(e)}")
        else:
            order.status = 'delivered'
            delivery_assignment.status = 'completed'
            delivery_assignment.completed_at = timezone.now()
            message = f"Completed delivery for order {order.order_number}"
            
            # Reset delivery person status to 'online' when delivery is completed
            try:
                from ..services.delivery_profile_services import DeliveryProfileService
                DeliveryProfileService.complete_delivery_task(user, completed_order_id=order.id)
                logger.info(f"Delivery manager {user.email} status updated after delivery completion")
            except Exception as e:
                logger.error(f"Failed to reset delivery person status: {str(e)}")

        order.save()
        delivery_assignment.save()

        from ..models.delivery_model import DeliveryActivity
        DeliveryActivity.objects.create(
            delivery_manager=user,
            order=order,
            activity_type=delivery_status,
            activity_data={'order_number': order.order_number},
        )

        return Response({'success': True, 'message': message}, status=status.HTTP_201_CREATED)

# ------------------------------------------------------------
# 🚀 Start Delivery Endpoint (Automatic Status Update)
# ------------------------------------------------------------
class StartDeliveryView(APIView):
    """
    POST /api/delivery/start_delivery/
    
    When the delivery manager starts delivering an order:
    - Automatically changes delivery manager status to "busy"
    - Updates order status to "in_delivery"
    
    Request body:
    {
        "delivery_manager_id": <int>,
        "order_id": <int>
    }
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        try:
            delivery_manager_id = request.data.get('delivery_manager_id')
            order_id = request.data.get('order_id')
            
            # Validate required fields
            if not delivery_manager_id:
                return Response({
                    'error': 'delivery_manager_id is required'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            if not order_id:
                return Response({
                    'error': 'order_id is required'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Fetch the delivery manager
            try:
                delivery_manager = User.objects.get(
                    id=delivery_manager_id,
                    user_type='delivery_admin'
                )
            except User.DoesNotExist:
                return Response({
                    'error': 'Delivery manager not found or invalid'
                }, status=status.HTTP_404_NOT_FOUND)
            
            # Verify user is a delivery admin
            if not delivery_manager.is_delivery_admin():
                return Response({
                    'error': 'User is not a delivery manager'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Security check: Ensure authenticated user matches delivery_manager_id (unless admin)
            authenticated_user = request.user
            if (authenticated_user.id != delivery_manager_id and 
                not authenticated_user.is_library_admin()):
                return Response({
                    'error': 'You can only start delivery for your own account'
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Fetch the order
            try:
                order = Order.objects.get(id=order_id)
            except Order.DoesNotExist:
                return Response({
                    'error': 'Order not found'
                }, status=status.HTTP_404_NOT_FOUND)
            
            # Check if order is assigned to this delivery manager
            delivery_assignment = DeliveryAssignment.objects.filter(
                order=order,
                delivery_manager=delivery_manager
            ).first()
            
            if not delivery_assignment:
                return Response({
                    'error': 'Order is not assigned to this delivery manager'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Update delivery manager status to "busy" (automatic)
            try:
                from ..services.delivery_profile_services import DeliveryProfileService
                DeliveryProfileService.start_delivery_task(delivery_manager)
                logger.info(f"Automatically changed delivery manager {delivery_manager.id} status to busy when starting delivery")
            except Exception as e:
                logger.error(f"Failed to update delivery manager status to busy: {str(e)}")
                return Response({
                    'error': f'Failed to update delivery manager status: {str(e)}'
                }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
            
            # Update order status to "in_delivery"
            order.status = 'in_delivery'
            order.save()
            
            # Update delivery assignment status if it exists
            if delivery_assignment:
                delivery_assignment.status = 'in_transit'
                delivery_assignment.started_at = timezone.now()
                delivery_assignment.save()
            
            # If this is a borrowing order, also update the borrow request status
            if order.order_type == 'borrowing' and order.borrow_request:
                from ..models.borrowing_model import BorrowRequest, BorrowStatusChoices
                borrow_request = order.borrow_request
                borrow_request.status = BorrowStatusChoices.OUT_FOR_DELIVERY
                borrow_request.delivery_person = delivery_manager
                if not borrow_request.pickup_date:
                    borrow_request.pickup_date = timezone.now()
                borrow_request.save()
                logger.info(f"Updated borrow request {borrow_request.id} status to OUT_FOR_DELIVERY")
            
            # Create delivery activity log
            try:
                from ..models.delivery_model import DeliveryActivity
                DeliveryActivity.objects.create(
                    delivery_manager=delivery_manager,
                    order=order,
                    activity_type='start_delivery',
                    activity_data={'order_number': order.order_number},
                )
            except Exception as e:
                logger.warning(f"Failed to create delivery activity log: {str(e)}")
            
            return Response({
                'success': True,
                'message': 'Delivery started successfully. Delivery manager status automatically changed to busy.',
                'order_id': order.id,
                'order_status': order.status,
                'delivery_manager_id': delivery_manager.id,
                'delivery_manager_status': 'busy'
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error starting delivery: {str(e)}")
            return Response({
                'error': f'Failed to start delivery: {str(e)}'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

# ------------------------------------------------------------
# 📋 7. Get Order Activities (for Admin View)
# ------------------------------------------------------------
class OrderActivitiesView(APIView):
    """
    Retrieve all activities (comments, additions, edits, deletions) for a specific order.
    Accessible by library admins and delivery admins.
    """
    permission_classes = [permissions.IsAuthenticated, IsDeliveryAdminOrLibraryAdmin]

    def get(self, request, order_id):
        """
        Get all activities for a specific order.
        """
        try:
            # Get the order
            order = get_object_or_404(Order, id=order_id)
            
            # Check if user has permission to view this order
            user = request.user
            if user.is_customer() and order.customer != user:
                return Response({
                    'error': 'You do not have permission to view activities for this order'
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Get all delivery activities for this order
            from ..models.delivery_model import DeliveryActivity
            from ..serializers.delivery_serializers import DeliveryActivitySerializer
            
            activities = DeliveryActivity.objects.filter(
                order=order
            ).select_related('delivery_manager', 'order').order_by('-timestamp')
            
            # Filter by activity type if provided
            activity_type = request.query_params.get('activity_type')
            if activity_type:
                activities = activities.filter(activity_type=activity_type)
            
            # Serialize activities
            serializer = DeliveryActivitySerializer(activities, many=True)
            
            return Response({
                'success': True,
                'count': activities.count(),
                'order_id': order.id,
                'order_number': order.order_number,
                'activities': serializer.data
            }, status=status.HTTP_200_OK)
            
        except Order.DoesNotExist:
            return Response({
                'error': 'Order not found'
            }, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"Error retrieving order activities: {str(e)}")
            return Response({
                'error': 'An error occurred while retrieving activities',
                'detail': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        
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
        # Filter by order_type to separate purchase and borrowing orders
        queryset = Order.objects.filter(
            status__in=['pending'],
            order_type='purchase'  # Only show purchase orders, borrowing orders have separate endpoint
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
                
            # Set timestamps based on status
            if new_status == 'accepted' and not assignment.accepted_at:
                assignment.accepted_at = timezone.now()
                # Update order status to 'in_delivery' when delivery manager accepts (as per scenario)
                order = assignment.order
                order.status = 'in_delivery'
                order.save()
                
                # Enable GPS tracking for the delivery manager (as per scenario requirement)
                try:
                    from ..models.delivery_model import RealTimeTracking
                    from ..models.delivery_profile_model import DeliveryProfile
                    
                    # Get or create real-time tracking
                    real_time_tracking, created = RealTimeTracking.objects.get_or_create(
                        delivery_manager=assignment.delivery_manager,
                        defaults={
                            'is_tracking_enabled': True,
                            'is_delivering': True,
                            'current_delivery_assignment': assignment,
                        }
                    )
                    if not created:
                        real_time_tracking.is_tracking_enabled = True
                        real_time_tracking.is_delivering = True
                        real_time_tracking.current_delivery_assignment = assignment
                        real_time_tracking.save()
                    
                    # Update delivery profile
                    from ..services.delivery_profile_services import DeliveryProfileService
                    delivery_profile = DeliveryProfile.objects.get(user=assignment.delivery_manager)
                    DeliveryProfileService.start_delivery_task(assignment.delivery_manager)
                    delivery_profile.is_tracking_active = True
                    delivery_profile.save()
                    
                    logger.info(f"GPS tracking enabled for delivery manager {assignment.delivery_manager.email} for order {order.order_number}")
                except Exception as e:
                    logger.error(f"Failed to enable GPS tracking: {str(e)}")
                
                # Send notification to customer and admin
                NotificationService.create_notification(
                    user_id=order.customer.id,
                    title="Delivery Confirmed",
                    message=f"Your order #{order.order_number} has been confirmed by delivery manager. Delivery is in progress!",
                    notification_type="delivery_confirmed",
                    related_order_id=order.id
                )
                
                # Notify admins
                admin_users = User.objects.filter(
                    user_type__in=['library_admin', 'system_admin'],
                    is_active=True
                )
                for admin in admin_users:
                    NotificationService.create_notification(
                        user_id=admin.id,
                        title="Delivery Confirmed",
                        message=f"Order #{order.order_number} has been confirmed by delivery manager {assignment.delivery_manager.get_full_name()}.",
                        notification_type="delivery_confirmed_admin",
                        related_order_id=order.id
                    )
            elif new_status == 'picked_up' and not assignment.picked_up_at:
                assignment.picked_up_at = timezone.now()
            elif new_status == 'in_transit':
                # Update order status to 'in_progress' when delivery starts
                order = assignment.order
                order.status = 'in_progress'
                order.save()
            elif new_status == 'delivered' and not assignment.delivered_at:
                assignment.delivered_at = timezone.now()
                assignment.actual_delivery_time = timezone.now()
            
            # Handle rejected status (as per scenario)
            if new_status == 'rejected' or new_status == 'cancelled':
                # Update order status to 'rejected_by_delivery_manager' (as per scenario)
                order = assignment.order
                order.status = 'rejected_by_delivery_manager'
                if failure_reason:
                    order.cancellation_reason = failure_reason
                # Restore book quantities when order is rejected
                order.restore_book_quantities()
                order.save()
                
                # Send notifications to customer and admin (as per scenario)
                NotificationService.create_notification(
                    user_id=order.customer.id,
                    title="Delivery Rejected by Delivery Manager",
                    message=f"Your order #{order.order_number} has been rejected by the delivery manager. Reason: {failure_reason or 'No reason provided'}",
                    notification_type="delivery_rejected",
                    related_order_id=order.id
                )
                
                # Notify admins
                admin_users = User.objects.filter(
                    user_type__in=['library_admin', 'system_admin'],
                    is_active=True
                )
                for admin in admin_users:
                    NotificationService.create_notification(
                        user_id=admin.id,
                        title="Delivery Rejected",
                        message=f"Order #{order.order_number} has been rejected by delivery manager {assignment.delivery_manager.get_full_name()}. Reason: {failure_reason or 'No reason provided'}",
                        notification_type="delivery_rejected_admin",
                        related_order_id=order.id
                    )
            
            # Set failure reason if status is failed
            if new_status == 'failed' and failure_reason:
                assignment.failure_reason = failure_reason
                
                # Increment retry count if failed
                assignment.retry_count += 1
            
            assignment.save()
            
            # Create status history entry
            DeliveryStatusHistory.objects.create(
                delivery_assignment=assignment,
                status=new_status,
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
            
            # Update order status if delivered (as per scenario: status should be "completed")
            if new_status == 'delivered':
                order = assignment.order
                order.status = 'completed'  # As per scenario: status → "Completed"
                order.delivered_at = timezone.now()
                order.save()
                
                # Stop GPS tracking immediately when delivery ends (as per scenario)
                try:
                    if hasattr(assignment.delivery_manager, 'real_time_tracking'):
                        real_time_tracking = assignment.delivery_manager.real_time_tracking
                        real_time_tracking.is_tracking_enabled = False
                        real_time_tracking.is_delivering = False
                        real_time_tracking.current_delivery_assignment = None
                        real_time_tracking.save()
                    
                    # Update delivery profile
                    from ..models.delivery_profile_model import DeliveryProfile
                    delivery_profile = DeliveryProfile.objects.get(user=assignment.delivery_manager)
                    delivery_profile.is_tracking_active = False
                    delivery_profile.save()
                    
                    logger.info(f"GPS tracking stopped for delivery manager {assignment.delivery_manager.email} after completing order {order.order_number}")
                except Exception as e:
                    logger.error(f"Failed to stop GPS tracking: {str(e)}")
                
                # Reset delivery person status to 'online' when order is delivered
                try:
                    from ..services.delivery_profile_services import DeliveryProfileService
                    DeliveryProfileService.complete_delivery_task(assignment.delivery_manager, completed_order_id=order.id)
                    logger.info(f"Delivery manager {assignment.delivery_manager.email} status updated after delivery completion")
                except Exception as e:
                    logger.error(f"Failed to reset delivery person status: {str(e)}")
                
                # Create notification for order delivered
                try:
                    NotificationService.notify_order_delivered(order.id)
                except Exception as e:
                    logger.error(f"Failed to create notification for order delivery: {str(e)}")
            
            # Create notification for delivery manager about status change (if updated by admin)
            if user != assignment.delivery_manager and new_status != old_status:
                try:
                    status_messages = {
                        'accepted': f"Your delivery assignment for order #{assignment.order.order_number} has been accepted.",
                        'picked_up': f"Order #{assignment.order.order_number} has been marked as picked up.",
                        'in_transit': f"Delivery for order #{assignment.order.order_number} is now in transit.",
                        'delivered': f"Order #{assignment.order.order_number} has been delivered successfully.",
                        'completed': f"Delivery assignment for order #{assignment.order.order_number} has been completed.",
                        'failed': f"Delivery for order #{assignment.order.order_number} has been marked as failed.",
                    }
                    
                    if new_status in status_messages:
                        NotificationService.create_notification(
                            user_id=assignment.delivery_manager.id,
                            title=f"Delivery Status Update: {new_status.replace('_', ' ').title()}",
                            message=status_messages[new_status],
                            notification_type="delivery_status_update",
                            related_order_id=assignment.order.id
                        )
                except Exception as e:
                    logger.error(f"Failed to create notification for delivery status update: {str(e)}")
            
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
    Get a list of available delivery managers with their status information.
    Accessible by delivery admins, library admins, and system admins.
    """
    try:
        # Get all active delivery managers with their delivery profiles
        delivery_managers = User.objects.filter(
            is_active=True,
            user_type='delivery_admin'
        ).select_related('delivery_profile').order_by('first_name', 'last_name')
        
        # Serialize the data with delivery status information
        from ..serializers.borrowing_serializers import DeliveryManagerSerializer
        serializer = DeliveryManagerSerializer(delivery_managers, many=True)
        
        # Format response data for frontend compatibility
        response_data = []
        for manager_data in serializer.data:
            manager_data_dict = dict(manager_data)
            # Map status fields for frontend compatibility
            manager_data_dict['status'] = manager_data_dict.get('status_display', 'Offline')
            manager_data_dict['delivery_status'] = manager_data_dict.get('delivery_status', 'offline')
            # Add phone number if available from profile
            if 'phone' not in manager_data_dict:
                try:
                    user = User.objects.get(id=manager_data_dict['id'])
                    if hasattr(user, 'profile') and user.profile.phone_number:
                        manager_data_dict['phone'] = user.profile.phone_number
                    else:
                        manager_data_dict['phone'] = ''
                except:
                    manager_data_dict['phone'] = ''
            response_data.append(manager_data_dict)
        
        return Response({
            'success': True,
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
    
    serializer = OrderListSerializer(orders, many=True)
    
    return Response({
        'orders': serializer.data,
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
def get_order_delivery_location_view(request, order_id):
    """
    Get real-time delivery location for an order.
    Accessible by order owner (customer), admin, and assigned delivery manager.
    Only available when order status is 'in_delivery'.
    """
    try:
        order = Order.objects.select_related('delivery_assignment__delivery_manager').get(id=order_id)
        user = request.user
        
        # Check permissions
        if not (user.is_delivery_admin() or user.is_library_admin() or order.customer == user):
            return Response({
                'error': "You don't have permission to view this order's delivery location"
            }, status=status.HTTP_403_FORBIDDEN)
        
        # Check if order is in delivery status (as per scenario requirement)
        if order.status != 'in_delivery':
            return Response({
                'error': f"Delivery location is only available when order status is 'in_delivery'. Current status: {order.status}",
                'order_status': order.status
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Check if order has a delivery assignment
        if not hasattr(order, 'delivery_assignment') or not order.delivery_assignment:
            return Response({
                'error': "This order doesn't have a delivery assignment yet"
            }, status=status.HTTP_404_NOT_FOUND)
        
        assignment = order.delivery_assignment
        delivery_manager = assignment.delivery_manager
        
        # Get delivery manager location
        location_data = delivery_manager.get_location_dict()
        
        # Check if GPS tracking is active
        is_tracking_active = False
        if hasattr(delivery_manager, 'real_time_tracking'):
            is_tracking_active = delivery_manager.real_time_tracking.is_tracking_enabled
        
        # Get latest location from location history if available
        from ..models.delivery_model import LocationHistory
        latest_location = LocationHistory.objects.filter(
            delivery_manager=delivery_manager,
            delivery_assignment=assignment
        ).order_by('-recorded_at').first()
        
        if latest_location:
            location_data = {
                'latitude': float(latest_location.latitude),
                'longitude': float(latest_location.longitude),
                'address': latest_location.address,
                'recorded_at': latest_location.recorded_at.isoformat(),
                'accuracy': latest_location.accuracy,
                'speed': latest_location.speed,
                'heading': latest_location.heading,
            }
        
        return Response({
            'success': True,
            'order_id': order.id,
            'order_number': order.order_number,
            'order_status': order.status,
            'is_tracking_active': is_tracking_active,
            'delivery_manager': {
                'id': delivery_manager.id,
                'name': delivery_manager.get_full_name(),
                'email': delivery_manager.email,
            },
            'location': location_data,
            'last_updated': latest_location.recorded_at.isoformat() if latest_location else None,
        }, status=status.HTTP_200_OK)
        
    except Order.DoesNotExist:
        return Response({
            'error': 'Order not found'
        }, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        logger.error(f"Error getting order delivery location: {str(e)}")
        return Response({
            'error': 'An error occurred while retrieving delivery location'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


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
            from ..models.delivery_profile_model import DeliveryProfile
            try:
                delivery_profile = DeliveryProfile.objects.get(user=user)
                if delivery_profile.delivery_status == 'busy' and new_status == 'offline':
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
                delivery_profile.delivery_status = new_status
                delivery_profile.save()
            except DeliveryProfile.DoesNotExist:
                return Response({
                    'error': 'Delivery profile not found'
                }, status=status.HTTP_404_NOT_FOUND)
            
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
                delivery_assignment_id=data.get('delivery_assignment_id'),
                borrow_request_id=data.get('borrow_request_id')
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


def get_delivery_notification_types():
    """
    Get the list of all delivery-related notification types.
    This ensures consistency across all delivery notification filtering.
    """
    return [
        'order_delivered',
        'order_accepted', 
        'delivery_assigned',
        'delivery_assignment',  # Used in borrowing service
        'delivery_time_updated',
        'delivery_request',
        'delivery_request_assigned',  # When delivery request is assigned
        'delivery_status_update',
        'delivery_started',
        'delivery_started_admin',
        'delivery_confirmed',
        'delivery_confirmed_admin',
        'delivery_rejected',
        'delivery_rejected_admin',
        'delivery_completed',
        'delivery_accepted',
        'delivery_accepted_admin',
        'delivery_task_created',  # For other delivery managers
    ]


class DeliveryNotificationsView(APIView):
    """
    View for managing delivery-related notifications
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        """
        Get delivery-related notifications for the current user
        """
        try:
            from ..services.notification_services import NotificationService
            
            # Get query parameters for filtering
            is_read = request.query_params.get('is_read')
            notification_type = request.query_params.get('notification_type')
            search = request.query_params.get('search')
            
            # Convert is_read parameter to boolean if provided
            if is_read is not None:
                is_read = is_read.lower() == 'true'
            
            # Get notifications for the current user
            notifications = NotificationService.get_user_notifications(
                user_id=request.user.id,
                is_read=is_read,
                notification_type=notification_type,
                search=search
            )
            
            # Filter for delivery-related notifications
            # Include all notification types that are created for delivery managers
            delivery_types = get_delivery_notification_types()
            
            delivery_notifications = notifications.filter(
                notification_type__name__in=delivery_types
            ).order_by('-created_at')
            
            # Calculate unread count for delivery notifications only
            # This ensures the count matches what's actually shown in the list
            unread_delivery_notifications = delivery_notifications.filter(status='unread')
            unread_count = unread_delivery_notifications.count()
            
            # Serialize the notifications
            from ..serializers.notification_serializers import NotificationSerializer
            serializer = NotificationSerializer(delivery_notifications, many=True)
            
            return Response({
                'success': True,
                'notifications': serializer.data,
                'count': delivery_notifications.count(),
                'unread_count': unread_count
            }, status=status.HTTP_200_OK)
            
        except ValueError as e:
            return Response({
                'error': str(e)
            }, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error(f"Error getting delivery notifications: {str(e)}")
            return Response({
                'error': 'An error occurred while fetching notifications'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def post(self, request):
        """
        Mark delivery notifications as read
        """
        try:
            from ..services.notification_services import NotificationService
            
            notification_id = request.data.get('notification_id')
            mark_all = request.data.get('mark_all', False)
            
            if mark_all:
                # Mark all delivery notifications as read (only delivery-related types)
                from ..models.notification_model import Notification
                from django.utils import timezone
                
                delivery_types = get_delivery_notification_types()
                
                # Get unread delivery notifications and mark them as read
                unread_delivery_notifications = Notification.objects.filter(
                    recipient=request.user,
                    status='unread',
                    notification_type__name__in=delivery_types
                )
                count = unread_delivery_notifications.count()
                
                unread_delivery_notifications.update(
                    status='read',
                    read_at=timezone.now()
                )
                
                return Response({
                    'success': True,
                    'message': f'{count} delivery notifications marked as read'
                }, status=status.HTTP_200_OK)
            
            elif notification_id:
                # Mark specific notification as read
                notification = NotificationService.mark_notification_as_read(notification_id)
                from ..serializers.notification_serializers import NotificationSerializer
                serializer = NotificationSerializer(notification)
                
                return Response({
                    'success': True,
                    'message': 'Notification marked as read',
                    'notification': serializer.data
                }, status=status.HTTP_200_OK)
            
            else:
                return Response({
                    'error': 'Either notification_id or mark_all must be provided'
                }, status=status.HTTP_400_BAD_REQUEST)
                
        except ValueError as e:
            return Response({
                'error': str(e)
            }, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"Error updating notification status: {str(e)}")
            return Response({
                'error': 'An error occurred while updating notification status'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def delete(self, request):
        """
        Delete delivery notifications
        """
        try:
            from ..services.notification_services import NotificationService
            
            notification_id = request.data.get('notification_id')
            
            if not notification_id:
                return Response({
                    'error': 'notification_id is required'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Delete the notification
            NotificationService.delete_notification(notification_id)
            
            return Response({
                'success': True,
                'message': 'Notification deleted successfully'
            }, status=status.HTTP_200_OK)
            
        except ValueError as e:
            return Response({
                'error': str(e)
            }, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"Error deleting notification: {str(e)}")
            return Response({
                'error': 'An error occurred while deleting notification'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class DeliveryNotificationMarkReadView(APIView):
    """
    View for marking a specific delivery notification as read
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request, notification_id):
        """
        Mark a specific notification as read
        """
        try:
            from ..services.notification_services import NotificationService
            from ..models.notification_model import Notification
            
            # First, get the notification to check permissions
            try:
                notification = Notification.objects.get(id=notification_id)
            except Notification.DoesNotExist:
                return Response({
                    'error': f'Notification with ID {notification_id} does not exist'
                }, status=status.HTTP_404_NOT_FOUND)
            
            # Verify the notification belongs to the current user
            if notification.recipient != request.user and not (request.user.is_staff or request.user.is_superuser):
                return Response({
                    'error': 'You do not have permission to mark this notification as read'
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Mark the notification as read
            notification = NotificationService.mark_notification_as_read(notification_id)
            
            from ..serializers.notification_serializers import NotificationSerializer
            serializer = NotificationSerializer(notification)
            
            return Response({
                'success': True,
                'message': 'Notification marked as read',
                'notification': serializer.data
            }, status=status.HTTP_200_OK)
                
        except ValueError as e:
            return Response({
                'error': str(e)
            }, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"Error marking notification as read: {str(e)}")
            return Response({
                'error': 'An error occurred while marking notification as read'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class DeliveryNotificationsUnreadCountView(APIView):
    """
    View for getting the unread count of delivery-related notifications
    This ensures the count matches what's shown in the delivery notifications list
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        """
        Get the count of unread delivery-related notifications for the current user
        """
        try:
            from ..services.notification_services import NotificationService
            from ..models.notification_model import Notification
            
            # Get all unread notifications for the user
            notifications = NotificationService.get_user_notifications(
                user_id=request.user.id,
                is_read=False
            )
            
            # Filter for delivery-related notifications only
            # This matches the same filtering logic used in DeliveryNotificationsView
            delivery_types = get_delivery_notification_types()
            
            unread_delivery_count = notifications.filter(
                notification_type__name__in=delivery_types
            ).count()
            
            return Response({
                'success': True,
                'unread_count': unread_delivery_count
            }, status=status.HTTP_200_OK)
            
        except ValueError as e:
            return Response({
                'error': str(e)
            }, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error(f"Error getting delivery unread count: {str(e)}")
            return Response({
                'error': 'An error occurred while fetching unread count'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class TaskETAUpdateView(APIView):
    """
    View for updating ETA for specific delivery tasks/assignments
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def patch(self, request, task_id):
        """
        Update the estimated delivery time for a specific delivery task/assignment
        """
        try:
            from ..models.delivery_model import DeliveryAssignment
            from ..services.notification_services import NotificationService
            
            # Get the delivery assignment (task)
            try:
                assignment = DeliveryAssignment.objects.get(id=task_id)
            except DeliveryAssignment.DoesNotExist:
                return Response({
                    'error': 'Delivery task not found'
                }, status=status.HTTP_404_NOT_FOUND)
            
            # Get request data
            estimated_delivery_time = request.data.get('estimated_delivery_time')
            reason = request.data.get('reason', 'manual_update')
            notes = request.data.get('notes', '')
            
            if not estimated_delivery_time:
                return Response({
                    'error': 'estimated_delivery_time is required'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Parse and validate the ETA
            try:
                from datetime import datetime
                from django.utils import timezone
                # Parse the ISO string and ensure it's timezone-aware
                eta_str = estimated_delivery_time.replace('Z', '+00:00')
                eta_datetime = datetime.fromisoformat(eta_str)
                # Ensure the datetime is timezone-aware
                if eta_datetime.tzinfo is None:
                    eta_datetime = timezone.make_aware(eta_datetime)
                
                # Validate that ETA is in the future
                if eta_datetime <= timezone.now():
                    return Response({
                        'error': 'ETA must be in the future'
                    }, status=status.HTTP_400_BAD_REQUEST)
                
            except ValueError:
                return Response({
                    'error': 'Invalid datetime format. Use ISO format (YYYY-MM-DDTHH:MM:SS)'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Store old ETA for comparison
            old_eta = assignment.estimated_delivery_time
            
            # Update the assignment ETA
            assignment.estimated_delivery_time = eta_datetime
            if notes:
                assignment.delivery_notes = notes
            assignment.save()
            
            # Create delivery activity record
            from ..models.delivery_model import DeliveryActivity
            
            activity_data = {
                'estimated_delivery_time': eta_datetime.isoformat(),
                'eta_reason': reason,
                'previous_eta': old_eta.isoformat() if old_eta else None,
                'order_number': assignment.order.order_number,
                'customer_name': assignment.order.customer.get_full_name() if assignment.order.customer else 'Unknown',
                'delivery_manager': assignment.delivery_manager.get_full_name() if assignment.delivery_manager else 'Unknown',
                'operation_description': f"Updated ETA for delivery task {task_id} to {eta_datetime.strftime('%Y-%m-%d %H:%M')}",
                'notes': notes,
            }
            
            activity = DeliveryActivity.objects.create(
                delivery_manager=request.user,
                order=assignment.order,
                activity_type='update_eta',
                activity_data=activity_data,
                ip_address=request.META.get('REMOTE_ADDR'),
                user_agent=request.META.get('HTTP_USER_AGENT', '')
            )
            
            # Send notification to customer about ETA update
            try:
                NotificationService.notify_delivery_time_updated(
                    order_id=assignment.order.id,
                    estimated_delivery_time=eta_datetime
                )
            except Exception as e:
                logger.error(f"Failed to create notification for ETA update: {str(e)}")
            
            # Return success response
            return Response({
                'success': True,
                'message': 'Task ETA updated successfully',
                'task_id': task_id,
                'assignment_id': assignment.id,
                'order_number': assignment.order.order_number,
                'old_eta': old_eta.isoformat() if old_eta else None,
                'new_eta': eta_datetime.isoformat(),
                'updated_by': request.user.get_full_name(),
                'updated_at': activity.timestamp.isoformat(),
                'reason': reason,
                'notes': notes
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error in TaskETAUpdateView: {str(e)}")
            return Response({
                'error': 'An error occurred while updating task ETA'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def get(self, request, task_id):
        """
        Get current ETA information for a specific delivery task/assignment
        """
        try:
            from ..models.delivery_model import DeliveryAssignment
            
            # Get the delivery assignment (task)
            try:
                assignment = DeliveryAssignment.objects.get(id=task_id)
            except DeliveryAssignment.DoesNotExist:
                return Response({
                    'error': 'Delivery task not found'
                }, status=status.HTTP_404_NOT_FOUND)
            
            # Return current ETA information
            return Response({
                'success': True,
                'task_id': task_id,
                'assignment_id': assignment.id,
                'order_number': assignment.order.order_number,
                'current_eta': assignment.estimated_delivery_time.isoformat() if assignment.estimated_delivery_time else None,
                'actual_delivery_time': assignment.actual_delivery_time.isoformat() if assignment.actual_delivery_time else None,
                'status': assignment.status,
                'delivery_manager': assignment.delivery_manager.get_full_name() if assignment.delivery_manager else None,
                'assigned_at': assignment.assigned_at.isoformat(),
                'delivery_notes': assignment.delivery_notes,
                'is_overdue': assignment.is_overdue() if hasattr(assignment, 'is_overdue') else False
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error in TaskETAUpdateView GET: {str(e)}")
            return Response({
                'error': 'An error occurred while fetching task ETA information'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)



from rest_framework import generics, status, permissions
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.views import APIView
from django.shortcuts import get_object_or_404
from django.db import transaction
from django.utils.decorators import method_decorator
from django.views.decorators.csrf import csrf_exempt
from django.utils import timezone
import logging

from ..models import DiscountCode, DiscountUsage, User, Cart, BookDiscount, BookDiscountUsage, Book
from ..serializers import (
    DiscountCodeSerializer,
    DiscountCodeCreateSerializer,
    DiscountCodeUpdateSerializer,
    DiscountCodeListSerializer,
    DiscountCodeValidationSerializer,
    DiscountApplicationSerializer,
    DiscountUsageSerializer,
    CustomerDiscountUsageSerializer,
    BookDiscountSerializer,
    BookDiscountCreateSerializer,
    BookDiscountUpdateSerializer,
    BookDiscountListSerializer,
    BookDiscountValidationSerializer,
    BookDiscountApplicationSerializer,
    BookDiscountUsageSerializer,
    CustomerBookDiscountUsageSerializer,
    AvailableBooksSerializer,
)
from ..services import (
    DiscountCodeService,
    DiscountValidationService,
    BookDiscountService,
    BookDiscountValidationService,
)
from ..permissions import IsOwnerOrAdmin
from ..utils import format_error_message

logger = logging.getLogger(__name__)


class DiscountCodeListCreateView(generics.ListCreateAPIView):
    """
    API view for listing and creating discount codes.
    Only library admins can access this endpoint.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get_serializer_class(self):
        if self.request.method == 'POST':
            return DiscountCodeCreateSerializer
        return DiscountCodeListSerializer
    
    def get_queryset(self):
        """
        Return discount codes. Only library admins can see all codes.
        """
        if not (self.request.user.is_authenticated and 
                self.request.user.user_type == 'library_admin'):
            return DiscountCode.objects.none()
        
        # Support both include_inactive and is_active parameters
        include_inactive = self.request.query_params.get('include_inactive', 'false').lower() == 'true'
        is_active_param = self.request.query_params.get('is_active')
        
        queryset = DiscountCode.objects.all()
        
        if is_active_param is not None:
            # If is_active parameter is provided, use it for filtering
            is_active_bool = is_active_param.lower() in ['true', '1', 'yes']
            queryset = queryset.filter(is_active=is_active_bool)
        elif not include_inactive:
            # If no is_active parameter but include_inactive is false, show only active
            queryset = queryset.filter(is_active=True)
        # If include_inactive is true and no is_active parameter, show all codes
        
        return queryset.order_by('-created_at')
    
    def get(self, request, *args, **kwargs):
        """
        List all discount codes with categorization.
        """
        # Check permissions
        if not (request.user.is_authenticated and request.user.user_type == 'library_admin'):
            return Response(
                {'error': 'Only library administrators can access discount codes.'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        try:
            # Support both include_inactive and is_active parameters
            include_inactive = request.query_params.get('include_inactive', 'false').lower() == 'true'
            is_active_param = request.query_params.get('is_active')
            search = request.query_params.get('search')
            
            # Convert is_active parameter to boolean or None
            is_active = None
            if is_active_param is not None:
                if is_active_param.lower() in ['true', '1', 'yes']:
                    is_active = True
                elif is_active_param.lower() in ['false', '0', 'no']:
                    is_active = False
                # If is_active_param is 'null' or any other value, keep is_active as None (show all)
            
            # If is_active is None (show all), set include_inactive to True
            if is_active is None:
                include_inactive = True
            
            logger.info(f"Discount API - include_inactive: {include_inactive}, is_active_param: {is_active_param}, is_active: {is_active}, search: {search}")
            
            result = DiscountCodeService.get_discount_codes(
                include_inactive=include_inactive,
                is_active=is_active,
                search=search
            )
            
            if result['success']:
                return Response(result['data'], status=status.HTTP_200_OK)
            else:
                return Response(
                    {'error': result.get('error', 'Unknown error')},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )
                
        except Exception as e:
            logger.error(f"Error in DiscountCodeListCreateView.get: {str(e)}")
            return Response(
                {'error': 'An unexpected error occurred.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
    
    def post(self, request, *args, **kwargs):
        """
        Create a new discount code.
        """
        # Check permissions
        if not (request.user.is_authenticated and request.user.user_type == 'library_admin'):
            return Response(
                {'error': 'Only library administrators can create discount codes.'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        try:
            success, result = DiscountCodeService.create_discount_code(request.data)
            
            if success:
                return Response(result, status=status.HTTP_201_CREATED)
            else:
                return Response(result, status=status.HTTP_400_BAD_REQUEST)
                
        except Exception as e:
            logger.error(f"Error in DiscountCodeListCreateView.post: {str(e)}")
            return Response(
                {'error': 'An unexpected error occurred while creating the discount code.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class DiscountCodeDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    API view for retrieving, updating, and deleting individual discount codes.
    Only library admins can access this endpoint.
    """
    queryset = DiscountCode.objects.all()
    permission_classes = [permissions.IsAuthenticated]
    
    def get_serializer_class(self):
        if self.request.method in ['PUT', 'PATCH']:
            return DiscountCodeUpdateSerializer
        return DiscountCodeListSerializer
    
    def get_object(self):
        """
        Check permissions before returning object.
        """
        if not (self.request.user.is_authenticated and 
                self.request.user.user_type == 'library_admin'):
            from django.core.exceptions import PermissionDenied
            raise PermissionDenied("Only library administrators can access discount codes.")
        
        return super().get_object()
    
    def put(self, request, *args, **kwargs):
        """
        Update a discount code.
        """
        try:
            discount_code_id = kwargs.get('pk')
            success, result = DiscountCodeService.update_discount_code(discount_code_id, request.data)
            
            if success:
                return Response(result, status=status.HTTP_200_OK)
            else:
                return Response(result, status=status.HTTP_400_BAD_REQUEST)
                
        except Exception as e:
            logger.error(f"Error in DiscountCodeDetailView.put: {str(e)}")
            return Response(
                {'error': 'An unexpected error occurred while updating the discount code.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
    
    def patch(self, request, *args, **kwargs):
        """
        Partially update a discount code.
        """
        return self.put(request, *args, **kwargs)
    
    def delete(self, request, *args, **kwargs):
        """
        Delete a discount code.
        """
        try:
            discount_code_id = kwargs.get('pk')
            success, result = DiscountCodeService.delete_discount_code(discount_code_id)
            
            if success:
                return Response(result, status=status.HTTP_200_OK)
            else:
                return Response(result, status=status.HTTP_400_BAD_REQUEST)
                
        except Exception as e:
            logger.error(f"Error in DiscountCodeDetailView.delete: {str(e)}")
            return Response(
                {'error': 'An unexpected error occurred while deleting the discount code.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class DiscountCodeValidationView(APIView):
    """
    API view for validating discount codes during checkout.
    Customers use this to check if a code is valid before applying it.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        """
        Validate a discount code for the current user.
        """
        # Only customers can validate codes for purchase
        if request.user.user_type != 'customer':
            return Response(
                {'error': 'Only customers can validate discount codes for purchases.'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        try:
            serializer = DiscountCodeValidationSerializer(data=request.data)
            if not serializer.is_valid():
                return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
            
            code = serializer.validated_data['code']
            cart_total = serializer.validated_data['cart_total']
            
            is_valid, validation_data = DiscountValidationService.validate_discount_code(
                code, request.user, cart_total
            )
            
            if is_valid:
                # Remove the discount_code object from response (not serializable)
                response_data = validation_data.copy()
                response_data.pop('discount_code', None)
                return Response(response_data, status=status.HTTP_200_OK)
            else:
                return Response(validation_data, status=status.HTTP_400_BAD_REQUEST)
                
        except Exception as e:
            logger.error(f"Error in DiscountCodeValidationView.post: {str(e)}")
            return Response(
                {'error': 'An unexpected error occurred while validating the discount code.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class DiscountCodeApplicationView(APIView):
    """
    API view for applying discount codes during order creation.
    This records the usage of the discount code.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        """
        Apply a discount code and record its usage.
        """
        # Only customers can apply codes for purchase
        if request.user.user_type != 'customer':
            return Response(
                {'error': 'Only customers can apply discount codes for purchases.'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        try:
            # Extract data from request
            code = request.data.get('code', '').strip()
            order_amount = request.data.get('order_amount')
            payment_reference = request.data.get('payment_reference', '')
            
            if not code:
                return Response(
                    {'error': ('Discount code is required.')   },
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            if not order_amount or order_amount <= 0:
                return Response(
                    {'error': ('Valid order amount is required.')},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            success, result = DiscountValidationService.apply_discount_code(
                code, request.user, order_amount, payment_reference
            )
            
            if success:
                return Response(result, status=status.HTTP_201_CREATED)
            else:
                return Response(result, status=status.HTTP_400_BAD_REQUEST)
                
        except Exception as e:
            logger.error(f"Error in DiscountCodeApplicationView.post: {str(e)}")
            return Response(
                {'error': 'An unexpected error occurred while applying the discount code.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )





class DiscountCodeRemovalView(APIView):
    """
    API view for removing applied discount codes from cart.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        """
        Remove any applied discount code from the user's cart.
        """
        # Only customers can remove discount codes
        if request.user.user_type != 'customer':
            return Response(
                {'error': 'Only customers can remove discount codes.'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        try:
            success, result = DiscountValidationService.remove_discount_code(request.user)
            
            if success:
                return Response(result, status=status.HTTP_200_OK)
            else:
                return Response(result, status=status.HTTP_400_BAD_REQUEST)
                
        except Exception as e:
            logger.error(f"Error in DiscountCodeRemovalView.post: {str(e)}")
            return Response(
                {'error': 'An unexpected error occurred while removing the discount code.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class DiscountCodeCleanupView(APIView):
    """
    API view for library admins to clean up expired, unused discount codes.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        """
        Clean up expired, unused discount codes.
        """
        # Only library admins can perform cleanup
        if not (request.user.is_authenticated and request.user.user_type == 'library_admin'):
            return Response(
                {'error': 'Only library administrators can perform discount code cleanup.'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        try:
            result = DiscountCodeService.cleanup_expired_codes()
            
            if result['success']:
                return Response(result, status=status.HTTP_200_OK)
            else:
                return Response(
                    {'error': result.get('error', 'Unknown error')},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )
                
        except Exception as e:
            logger.error(f"Error in DiscountCodeCleanupView.post: {str(e)}")
            return Response(
                {'error': 'An unexpected error occurred during cleanup.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


# Additional utility views for specific discount operations

@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def get_user_available_codes(request):
    """
    API endpoint to get discount codes that a specific user can still use.
    """
    if request.user.user_type != 'customer':
        return Response(
            {'error': 'Only customers can check available discount codes.'},
            status=status.HTTP_403_FORBIDDEN
        )
    
    try:
        # Get all valid codes
        valid_codes = DiscountCode.objects.get_valid_codes()
        available_codes = []
        
        for code in valid_codes:
            can_use, message = code.can_be_used_by(request.user)
            if can_use:
                available_codes.append({
                    'code': code.code,
                    'discount_percentage': float(code.discount_percentage),
                    'remaining_uses': code.usage_limit_per_customer - code.get_usage_count_for_user(request.user),
                    'expiration_date': code.expiration_date,
                })
        
        return Response({
            'available_codes': available_codes,
            'total_available': len(available_codes)
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"Error in get_user_available_codes: {str(e)}")
        return Response(
            {'error': 'An unexpected error occurred while retrieving available codes.'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def quick_code_check(request):
    """
    Quick validation endpoint that just checks if a code exists and is valid.
    """
    if request.user.user_type != 'customer':
        return Response(
            {'error': 'Only customers can validate discount codes.'},
            status=status.HTTP_403_FORBIDDEN
        )
    
    try:
        code = request.data.get('code', '').strip().upper()
        
        if not code:
            return Response(
                {'valid': False, 'message': 'Code is required.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            discount_code = DiscountCode.objects.get(code=code)
            can_use, message = discount_code.can_be_used_by(request.user)
            
            return Response({
                'valid': can_use,
                'code': code,
                'discount_percentage': float(discount_code.discount_percentage) if can_use else None,
                'message': message
            }, status=status.HTTP_200_OK)
            
        except DiscountCode.DoesNotExist:
            return Response({
                'valid': False,
                'message': 'Invalid discount code.'
            }, status=status.HTTP_200_OK)
            
    except Exception as e:
        logger.error(f"Error in quick_code_check: {str(e)}")
        return Response(
            {'error': 'An unexpected error occurred while checking the code.'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


# Book Discount Views

class BookDiscountListCreateView(generics.ListCreateAPIView):
    """
    API view for listing and creating book discounts.
    Only library admins can access this endpoint.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get_serializer_class(self):
        if self.request.method == 'POST':
            return BookDiscountCreateSerializer
        return BookDiscountListSerializer
    
    def get_queryset(self):
        """
        Return book discounts. Only library admins can see all discounts.
        """
        if not (self.request.user.is_authenticated and 
                self.request.user.user_type == 'library_admin'):
            return BookDiscount.objects.none()
        
        # Support both include_inactive and is_active parameters
        include_inactive = self.request.query_params.get('include_inactive', 'false').lower() == 'true'
        is_active_param = self.request.query_params.get('is_active')
        
        queryset = BookDiscount.objects.all()
        
        if is_active_param is not None:
            # If is_active parameter is provided, use it for filtering
            is_active_bool = is_active_param.lower() in ['true', '1', 'yes']
            queryset = queryset.filter(is_active=is_active_bool)
        elif not include_inactive:
            # If no is_active parameter but include_inactive is false, show only active
            queryset = queryset.filter(is_active=True)
        # If include_inactive is true and no is_active parameter, show all discounts
        
        return queryset.order_by('-created_at')
    
    def get(self, request, *args, **kwargs):
        """
        List all book discounts with categorization.
        """
        # Check permissions
        if not (request.user.is_authenticated and request.user.user_type == 'library_admin'):
            return Response(
                {'error': 'Only library administrators can access book discounts.'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        try:
            # Support both include_inactive and is_active parameters
            include_inactive = request.query_params.get('include_inactive', 'false').lower() == 'true'
            is_active_param = request.query_params.get('is_active')
            search = request.query_params.get('search')
            
            # Convert is_active parameter to boolean or None
            is_active = None
            if is_active_param is not None:
                if is_active_param.lower() in ['true', '1', 'yes']:
                    is_active = True
                elif is_active_param.lower() in ['false', '0', 'no']:
                    is_active = False
                # If is_active_param is 'null' or any other value, keep is_active as None (show all)
            
            # If is_active is None (show all), set include_inactive to True
            if is_active is None:
                include_inactive = True
            
            logger.info(f"BookDiscount API - include_inactive: {include_inactive}, is_active_param: {is_active_param}, is_active: {is_active}, search: {search}")
            
            result = BookDiscountService.get_book_discounts(
                include_inactive=include_inactive,
                is_active=is_active,
                search=search
            )
            
            if result['success']:
                return Response(result['data'], status=status.HTTP_200_OK)
            else:
                return Response(
                    {'error': result.get('error', 'Unknown error')},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )
                
        except Exception as e:
            logger.error(f"Error in BookDiscountListCreateView.get: {str(e)}")
            return Response(
                {'error': 'An unexpected error occurred.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
    
    def post(self, request, *args, **kwargs):
        """
        Create a new book discount.
        """
        # Check permissions
        if not (request.user.is_authenticated and request.user.user_type == 'library_admin'):
            return Response(
                {'error': 'Only library administrators can create book discounts.'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        try:
            success, result = BookDiscountService.create_book_discount(request.data, request.user)
            
            if success:
                return Response(result, status=status.HTTP_201_CREATED)
            else:
                return Response(result, status=status.HTTP_400_BAD_REQUEST)
                
        except Exception as e:
            logger.error(f"Error in BookDiscountListCreateView.post: {str(e)}")
            return Response(
                {'error': 'An unexpected error occurred while creating the book discount.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class BookDiscountDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    API view for retrieving, updating, and deleting individual book discounts.
    Only library admins can access this endpoint.
    """
    queryset = BookDiscount.objects.all()
    permission_classes = [permissions.IsAuthenticated]
    
    def get_serializer_class(self):
        if self.request.method in ['PUT', 'PATCH']:
            return BookDiscountUpdateSerializer
        return BookDiscountListSerializer
    
    def get_object(self):
        """
        Check permissions before returning object.
        """
        if not (self.request.user.is_authenticated and 
                self.request.user.user_type == 'library_admin'):
            from django.core.exceptions import PermissionDenied
            raise PermissionDenied("Only library administrators can access book discounts.")
        
        return super().get_object()
    
    def put(self, request, *args, **kwargs):
        """
        Update a book discount.
        """
        try:
            book_discount_id = kwargs.get('pk')
            success, result = BookDiscountService.update_book_discount(book_discount_id, request.data)
            
            if success:
                return Response(result, status=status.HTTP_200_OK)
            else:
                return Response(result, status=status.HTTP_400_BAD_REQUEST)
                
        except Exception as e:
            logger.error(f"Error in BookDiscountDetailView.put: {str(e)}")
            return Response(
                {'error': 'An unexpected error occurred while updating the book discount.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
    
    def patch(self, request, *args, **kwargs):
        """
        Partially update a book discount.
        """
        return self.put(request, *args, **kwargs)
    
    def delete(self, request, *args, **kwargs):
        """
        Delete a book discount.
        """
        try:
            book_discount_id = kwargs.get('pk')
            success, result = BookDiscountService.delete_book_discount(book_discount_id)
            
            if success:
                return Response(result, status=status.HTTP_200_OK)
            else:
                return Response(result, status=status.HTTP_400_BAD_REQUEST)
                
        except Exception as e:
            logger.error(f"Error in BookDiscountDetailView.delete: {str(e)}")
            return Response(
                {'error': 'An unexpected error occurred while deleting the book discount.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class AvailableBooksView(APIView):
    """
    API view for getting available books for discount creation.
    Only library admins can access this endpoint.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        """
        Get all available books for discount creation.
        """
        # Check permissions
        if not (request.user.is_authenticated and request.user.user_type == 'library_admin'):
            return Response(
                {'error': 'Only library administrators can access available books.'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        try:
            result = BookDiscountService.get_available_books()
            
            if result['success']:
                return Response(result['data'], status=status.HTTP_200_OK)
            else:
                return Response(
                    {'error': result.get('error', 'Unknown error')},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )
                
        except Exception as e:
            logger.error(f"Error in AvailableBooksView.get: {str(e)}")
            return Response(
                {'error': 'An unexpected error occurred while retrieving available books.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class BookDiscountValidationView(APIView):
    """
    API view for validating book discount codes during checkout.
    Customers use this to check if a code is valid before applying it.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        """
        Validate a book discount code for the current user.
        """
        # Only customers can validate codes for purchase
        if request.user.user_type != 'customer':
            return Response(
                {'error': 'Only customers can validate book discount codes for purchases.'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        try:
            serializer = BookDiscountValidationSerializer(data=request.data)
            if not serializer.is_valid():
                return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
            
            code = serializer.validated_data['code']
            book_id = serializer.validated_data['book_id']
            
            is_valid, validation_data = BookDiscountValidationService.validate_book_discount_code(
                code, book_id, request.user
            )
            
            if is_valid:
                # Remove the book_discount object from response (not serializable)
                response_data = validation_data.copy()
                response_data.pop('book_discount', None)
                return Response(response_data, status=status.HTTP_200_OK)
            else:
                return Response(validation_data, status=status.HTTP_400_BAD_REQUEST)
                
        except Exception as e:
            logger.error(f"Error in BookDiscountValidationView.post: {str(e)}")
            return Response(
                {'error': 'An unexpected error occurred while validating the book discount code.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class BookDiscountApplicationView(APIView):
    """
    API view for applying book discount codes during order creation.
    This records the usage of the book discount code.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        """
        Apply a book discount code and record its usage.
        """
        # Only customers can apply codes for purchase
        if request.user.user_type != 'customer':
            return Response(
                {'error': 'Only customers can apply book discount codes for purchases.'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        try:
            # Extract data from request
            code = request.data.get('code', '').strip()
            book_id = request.data.get('book_id')
            order_amount = request.data.get('order_amount')
            order_id = request.data.get('order_id')
            
            if not code:
                return Response(
                    {'error': 'Book discount code is required.'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            if not book_id:
                return Response(
                    {'error': 'Book ID is required.'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            if not order_amount or order_amount <= 0:
                return Response(
                    {'error': 'Valid order amount is required.'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Get order object if order_id is provided
            order = None
            if order_id:
                try:
                    from ..models import Order
                    order = Order.objects.get(id=order_id)
                except Order.DoesNotExist:
                    return Response(
                        {'error': 'Order not found.'},
                        status=status.HTTP_400_BAD_REQUEST
                    )
            
            success, result = BookDiscountValidationService.apply_book_discount_code(
                code, book_id, request.user, order_amount, order
            )
            
            if success:
                # Serialize the usage record for response
                usage_record = result['usage_record']
                result['usage_record'] = BookDiscountUsageSerializer(usage_record).data
                return Response(result, status=status.HTTP_201_CREATED)
            else:
                return Response(result, status=status.HTTP_400_BAD_REQUEST)
                
        except Exception as e:
            logger.error(f"Error in BookDiscountApplicationView.post: {str(e)}")
            return Response(
                {'error': 'An unexpected error occurred while applying the book discount code.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class BookDiscountCleanupView(APIView):
    """
    API view for library admins to clean up expired, unused book discounts.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        """
        Clean up expired, unused book discounts.
        """
        # Only library admins can perform cleanup
        if not (request.user.is_authenticated and request.user.user_type == 'library_admin'):
            return Response(
                {'error': 'Only library administrators can perform book discount cleanup.'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        try:
            result = BookDiscountService.cleanup_expired_discounts()
            
            if result['success']:
                return Response(result, status=status.HTTP_200_OK)
            else:
                return Response(
                    {'error': result.get('error', 'Unknown error')},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )
                
        except Exception as e:
            logger.error(f"Error in BookDiscountCleanupView.post: {str(e)}")
            return Response(
                {'error': 'An unexpected error occurred during cleanup.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def get_user_available_book_discounts(request):
    """
    API endpoint to get book discount codes that a specific user can still use.
    """
    if request.user.user_type != 'customer':
        return Response(
            {'error': 'Only customers can check available book discount codes.'},
            status=status.HTTP_403_FORBIDDEN
        )
    
    try:
        # Get all valid book discounts
        valid_discounts = BookDiscount.objects.get_active_discounts()
        available_discounts = []
        
        for discount in valid_discounts:
            can_use, message = discount.can_be_used_by(request.user)
            if can_use:
                available_discounts.append({
                    'code': discount.code,
                    'book_id': discount.book.id,
                    'book_name': discount.book.name,
                    'discount_type': discount.discount_type,
                    'discount_percentage': float(discount.discount_percentage) if discount.discount_percentage else None,
                    'discounted_price': float(discount.discounted_price) if discount.discounted_price else None,
                    'original_price': float(discount.book.price) if discount.book.price else None,
                    'final_price': float(discount.get_final_price(discount.book.price)) if discount.book.price else None,
                    'remaining_uses': discount.usage_limit_per_customer - discount.usages.filter(customer=request.user).count(),
                    'start_date': discount.start_date,
                    'end_date': discount.end_date,
                })
        
        return Response({
            'available_discounts': available_discounts,
            'total_available': len(available_discounts)
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"Error in get_user_available_book_discounts: {str(e)}")
        return Response(
            {'error': 'An unexpected error occurred while retrieving available book discount codes.'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def quick_book_discount_check(request):
    """
    Quick validation endpoint that just checks if a book discount code exists and is valid.
    """
    if request.user.user_type != 'customer':
        return Response(
            {'error': 'Only customers can validate book discount codes.'},
            status=status.HTTP_403_FORBIDDEN
        )
    
    try:
        code = request.data.get('code', '').strip().upper()
        book_id = request.data.get('book_id')
        
        if not code:
            return Response(
                {'valid': False, 'message': 'Code is required.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if not book_id:
            return Response(
                {'valid': False, 'message': 'Book ID is required.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            book_discount = BookDiscount.objects.get(code=code, book_id=book_id)
            can_use, message = book_discount.can_be_used_by(request.user)
            
            return Response({
                'valid': can_use,
                'code': code,
                'book_id': book_id,
                'book_name': book_discount.book.name,
                'discount_type': book_discount.discount_type,
                'discount_percentage': float(book_discount.discount_percentage) if book_discount.discount_percentage else None,
                'discounted_price': float(book_discount.discounted_price) if book_discount.discounted_price else None,
                'message': message
            }, status=status.HTTP_200_OK)
            
        except BookDiscount.DoesNotExist:
            return Response({
                'valid': False,
                'message': 'Invalid book discount code for this book.'
            }, status=status.HTTP_200_OK)
            
    except Exception as e:
        logger.error(f"Error in quick_book_discount_check: {str(e)}")
        return Response(
            {'error': 'An unexpected error occurred while checking the book discount code.'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


class DiscountListActiveView(APIView):
    """
    API view for getting only active discount codes.
    Used by advertisement forms to populate discount code dropdowns.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        """
        Get all active discount codes.
        """
        # Check permissions
        if not (request.user.is_authenticated and request.user.user_type == 'library_admin'):
            return Response(
                {'error': 'Only library administrators can access discount codes.'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        try:
            today = timezone.now().date()
            discounts = DiscountCode.objects.filter(
                is_active=True, 
                expiration_date__gte=timezone.now()
            ).order_by('-created_at')
            
            serializer = DiscountCodeSerializer(discounts, many=True)
            return Response(serializer.data, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error in DiscountListActiveView.get: {str(e)}")
            return Response(
                {'error': 'An unexpected error occurred while retrieving active discount codes.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def get_discounted_books(request):
    """
    API endpoint to get books with active discounts for the customer home page.
    """
    if request.user.user_type != 'customer':
        return Response(
            {'error': 'Only customers can view discounted books.'},
            status=status.HTTP_403_FORBIDDEN
        )
    
    try:
        # Get limit from query parameters (default to 10)
        limit = int(request.query_params.get('limit', 10))
        
        # Get active and upcoming book discounts
        now = timezone.now()
        active_discounts = BookDiscount.objects.filter(
            is_active=True,
            end_date__gt=now  # Only exclude expired discounts
        ).select_related(
            'book', 'book__author', 'book__category'
        ).prefetch_related('book__images').order_by('start_date')[:limit]
        
        discounted_books = []
        
        for discount in active_discounts:
            book = discount.book
            
            # Get book thumbnail
            thumbnail_url = None
            try:
                primary_image = book.images.filter(is_primary=True).first()
                if primary_image:
                    request_obj = request
                    if request_obj:
                        thumbnail_url = request_obj.build_absolute_uri(primary_image.image.url)
                    else:
                        thumbnail_url = primary_image.image.url
            except:
                pass
            
            # Calculate prices
            original_price = float(book.price) if book.price else 0
            final_price = float(discount.get_final_price(original_price))
            discount_amount = original_price - final_price
            
            # Check if user can use this discount
            can_use, _ = discount.can_be_used_by(request.user)
            
            # Determine discount status
            is_active = discount.start_date <= now and discount.end_date > now
            is_upcoming = discount.start_date.date() > now.date()
            
            discounted_books.append({
                'id': book.id,
                'title': book.name,
                'description': book.description,  # Add description field
                'author': book.author.name if book.author else 'Unknown Author',
                'category': book.category.name if book.category else 'Uncategorized',
                'thumbnail_url': thumbnail_url,
                'original_price': original_price,
                'final_price': final_price,
                'discount_amount': discount_amount,
                'discount_percentage': (discount_amount / original_price * 100) if original_price > 0 else None,
                'discount_type': discount.discount_type,
                'discount_code': discount.code,
                'can_use': can_use,
                'expires_at': discount.end_date,
                'starts_at': discount.start_date,
                'is_active': is_active,
                'is_upcoming': is_upcoming,
                'is_expiring_soon': discount.end_date <= timezone.now() + timezone.timedelta(days=3),
                'is_available_for_purchase': book.can_purchase,
                'is_available_for_borrow': book.can_borrow,
            })
        
        return Response({
            'discounted_books': discounted_books,
            'total_count': len(discounted_books),
            'message': f'Found {len(discounted_books)} discounted books'
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"Error in get_discounted_books: {str(e)}")
        return Response(
            {'error': 'An unexpected error occurred while retrieving discounted books.'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
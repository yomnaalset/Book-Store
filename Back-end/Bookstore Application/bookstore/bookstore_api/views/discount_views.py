from rest_framework import generics, status, permissions
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.views import APIView
from django.shortcuts import get_object_or_404
from django.db import transaction
from django.utils.decorators import method_decorator
from django.views.decorators.csrf import csrf_exempt
import logging

from ..models import DiscountCode, DiscountUsage, User, Cart
from ..serializers import (
    DiscountCodeSerializer,
    DiscountCodeCreateSerializer,
    DiscountCodeUpdateSerializer,
    DiscountCodeListSerializer,
    DiscountCodeValidationSerializer,
    DiscountApplicationSerializer,
    DiscountUsageSerializer,
    CustomerDiscountUsageSerializer,
)
from ..services import (
    DiscountCodeService,
    DiscountValidationService,  
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
            
            logger.info(f"Discount API - include_inactive: {include_inactive}, is_active_param: {is_active_param}, is_active: {is_active}")
            
            result = DiscountCodeService.get_discount_codes(
                include_inactive=include_inactive,
                is_active=is_active
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
                # Serialize the usage record for response
                usage_record = result['usage_record']
                result['usage_record'] = DiscountUsageSerializer(usage_record).data
                return Response(result, status=status.HTTP_201_CREATED)
            else:
                return Response(result, status=status.HTTP_400_BAD_REQUEST)
                
        except Exception as e:
            logger.error(f"Error in DiscountCodeApplicationView.post: {str(e)}")
            return Response(
                {'error': 'An unexpected error occurred while applying the discount code.'},
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
            can_use, message = code.can_be_used_by_user(request.user)
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
            can_use, message = discount_code.can_be_used_by_user(request.user)
            
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
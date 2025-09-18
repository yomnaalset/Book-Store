from django.db import transaction
from django.core.exceptions import ValidationError
from django.utils import timezone
from typing import Dict, Any, Optional, Tuple
import logging

from ..models import DiscountCode, DiscountUsage, User, Cart
from ..serializers import (
    DiscountCodeCreateSerializer,
    DiscountCodeUpdateSerializer,
    DiscountCodeListSerializer,
    DiscountUsageCreateSerializer,
)
from ..utils import format_error_message

logger = logging.getLogger(__name__)


class DiscountCodeService:
    """
    Service class for handling discount code management operations.
    """
    
    @staticmethod
    def create_discount_code(data: Dict[str, Any]) -> Tuple[bool, Dict[str, Any]]:
        """
        Create a new discount code.
        
        Args:
            data: Dictionary containing discount code data
            
        Returns:
            Tuple of (success, result_data)
        """
        try:
            serializer = DiscountCodeCreateSerializer(data=data)
            if serializer.is_valid():
                with transaction.atomic():
                    discount_code = serializer.save()
                    logger.info(f"Discount code created: {discount_code.code}")
                    
                    return True, {
                        'discount_code': DiscountCodeListSerializer(discount_code).data,
                        'message': f'Discount code "{discount_code.code}" created successfully.'
                    }
            else:
                return False, {
                    'errors': serializer.errors,
                    'message': 'Failed to create discount code due to validation errors.'
                }
                
        except Exception as e:
            logger.error(f"Error creating discount code: {str(e)}")
            return False, {
                'error': str(e),
                'message': 'An unexpected error occurred while creating the discount code.'
            }
    
    @staticmethod
    def update_discount_code(discount_code_id: int, data: Dict[str, Any]) -> Tuple[bool, Dict[str, Any]]:
        """
        Update an existing discount code.
        Only certain fields can be updated as per requirements.
        
        Args:
            discount_code_id: ID of the discount code to update
            data: Dictionary containing updated data
            
        Returns:
            Tuple of (success, result_data)
        """
        try:
            discount_code = DiscountCode.objects.get(id=discount_code_id)
            
            # Check if the code has been used and restrictions apply
            usage_count = discount_code.usages.count()
            if usage_count > 0:
                # Some restrictions might apply for codes that have been used
                logger.info(f"Updating discount code {discount_code.code} that has {usage_count} uses")
            
            serializer = DiscountCodeUpdateSerializer(discount_code, data=data, partial=True)
            if serializer.is_valid():
                with transaction.atomic():
                    updated_code = serializer.save()
                    logger.info(f"Discount code updated: {updated_code.code}")
                    
                    return True, {
                        'discount_code': DiscountCodeListSerializer(updated_code).data,
                        'message': f'Discount code "{updated_code.code}" updated successfully.'
                    }
            else:
                return False, {
                    'errors': serializer.errors,
                    'message': 'Failed to update discount code due to validation errors.'
                }
                
        except DiscountCode.DoesNotExist:
            return False, {
                'error': 'Discount code not found',
                'message': 'The specified discount code does not exist.'
            }
        except Exception as e:
            logger.error(f"Error updating discount code: {str(e)}")
            return False, {
                'error': str(e),
                'message': 'An unexpected error occurred while updating the discount code.'
            }
    
    @staticmethod
    def delete_discount_code(discount_code_id: int) -> Tuple[bool, Dict[str, Any]]:
        """
        Delete a discount code.
        Can only be deleted if it has not been used or when it expires.
        
        Args:
            discount_code_id: ID of the discount code to delete
            
        Returns:
            Tuple of (success, result_data)
        """
        try:
            discount_code = DiscountCode.objects.get(id=discount_code_id)
            
            # Check if the code has been used
            usage_count = discount_code.usages.count()
            is_expired = discount_code.expiration_date <= timezone.now()
            
            if usage_count > 0 and not is_expired:
                return False, {
                    'error': 'Cannot delete used discount code',
                    'message': f'This discount code has been used {usage_count} times and cannot be deleted until it expires.'
                }
            
            code_name = discount_code.code
            with transaction.atomic():
                discount_code.delete()
                logger.info(f"Discount code deleted: {code_name}")
                
            return True, {
                'message': f'Discount code "{code_name}" deleted successfully.'
            }
                
        except DiscountCode.DoesNotExist:
            return False, {
                'error': 'Discount code not found',
                'message': 'The specified discount code does not exist.'
            }
        except Exception as e:
            logger.error(f"Error deleting discount code: {str(e)}")
            return False, {
                'error': str(e),
                'message': 'An unexpected error occurred while deleting the discount code.'
            }
    
    @staticmethod
    def get_discount_codes(include_inactive: bool = False, is_active: Optional[bool] = None) -> Dict[str, Any]:
        """
        Get all discount codes with optional filtering.
        
        Args:
            include_inactive: Whether to include inactive codes (legacy parameter)
            is_active: Filter by active status (True=active only, False=inactive only, None=all)
            
        Returns:
            Dictionary containing discount codes and metadata
        """
        try:
            queryset = DiscountCode.objects.all()
            logger.info(f"DiscountService - Initial queryset count: {queryset.count()}")
            
            # Handle is_active parameter (takes precedence over include_inactive)
            if is_active is not None:
                queryset = queryset.filter(is_active=is_active)
                logger.info(f"DiscountService - After is_active filter ({is_active}): {queryset.count()}")
            elif include_inactive:
                # If include_inactive is True, show all (no filtering)
                logger.info(f"DiscountService - include_inactive=True, showing all: {queryset.count()}")
            else:
                # Default behavior: show only active
                queryset = queryset.filter(is_active=True)
                logger.info(f"DiscountService - Default behavior, showing only active: {queryset.count()}")
            
            # Add ordering and additional filtering
            queryset = queryset.order_by('-created_at')
            
            # Categorize codes
            active_codes = []
            expired_codes = []
            inactive_codes = []
            
            for code in queryset:
                code_data = DiscountCodeListSerializer(code).data
                
                if not code.is_active:
                    inactive_codes.append(code_data)
                elif code.expiration_date <= timezone.now():
                    expired_codes.append(code_data)
                else:
                    active_codes.append(code_data)
            
            total_count = len(active_codes) + len(expired_codes) + len(inactive_codes)
            logger.info(f"DiscountService - Final counts - Active: {len(active_codes)}, Expired: {len(expired_codes)}, Inactive: {len(inactive_codes)}, Total: {total_count}")
            
            return {
                'success': True,
                'data': {
                    'active_codes': active_codes,
                    'expired_codes': expired_codes,
                    'inactive_codes': inactive_codes,
                    'total_count': total_count,
                    'active_count': len(active_codes),
                    'expired_count': len(expired_codes),
                    'inactive_count': len(inactive_codes)
                }
            }
            
        except Exception as e:
            logger.error(f"Error retrieving discount codes: {str(e)}")
            return {
                'success': False,
                'error': str(e),
                'message': 'An error occurred while retrieving discount codes.'
            }
    
    @staticmethod
    def cleanup_expired_codes() -> Dict[str, Any]:
        """
        Clean up expired discount codes that haven't been used.
        
        Returns:
            Dictionary containing cleanup results
        """
        try:
            count = DiscountCode.objects.cleanup_expired_codes()
            logger.info(f"Cleaned up {count} expired unused discount codes")
            
            return {
                'success': True,
                'cleaned_count': count,
                'message': f'Successfully cleaned up {count} expired unused discount codes.'
            }
            
        except Exception as e:
            logger.error(f"Error cleaning up expired codes: {str(e)}")
            return {
                'success': False,
                'error': str(e),
                'message': 'An error occurred while cleaning up expired codes.'
            }


class DiscountValidationService:
    """
    Service class for validating and applying discount codes during checkout.
    """
    
    @staticmethod
    def validate_discount_code(code: str, user: User, cart_total: float) -> Tuple[bool, Dict[str, Any]]:
        """
        Validate a discount code for a specific user and cart total.
        
        Args:
            code: The discount code to validate
            user: The user attempting to use the code
            cart_total: Total cart amount before discount
            
        Returns:
            Tuple of (is_valid, validation_data)
        """
        try:
            # Clean the code
            code = code.upper().strip()
            
            # Basic validation
            if not code:
                return False, {
                    'error': 'empty_code',
                    'message': 'Discount code cannot be empty.'
                }
            
            if cart_total <= 0:
                return False, {
                    'error': 'invalid_cart_total',
                    'message': 'Cart total must be greater than 0 to apply discount.'
                }
            
            # Find the discount code
            try:
                discount_code = DiscountCode.objects.get(code=code)
            except DiscountCode.DoesNotExist:
                return False, {
                    'error': 'code_not_found',
                    'message': 'Invalid discount code.'
                }
            
            # Check if code is valid
            if not discount_code.is_valid():
                if not discount_code.is_active:
                    return False, {
                        'error': 'code_inactive',
                        'message': 'This discount code is no longer active.'
                    }
                elif discount_code.expiration_date <= timezone.now():
                    return False, {
                        'error': 'code_expired',
                        'message': 'This discount code has expired.'
                    }
            
            # Check if user can use this code
            can_use, usage_message = discount_code.can_be_used_by_user(user)
            if not can_use:
                return False, {
                    'error': 'usage_limit_exceeded',
                    'message': usage_message
                }
            
            # Calculate discount
            discount_amount = discount_code.calculate_discount_amount(cart_total)
            final_amount = cart_total - discount_amount
            
            return True, {
                'discount_code': discount_code,
                'original_amount': cart_total,
                'discount_amount': discount_amount,
                'final_amount': final_amount,
                'discount_percentage': discount_code.discount_percentage,
                'message': f'Discount code applied successfully! You save ${discount_amount:.2f}'
            }
            
        except Exception as e:
            logger.error(f"Error validating discount code: {str(e)}")
            return False, {
                'error': 'validation_error',
                'message': 'An error occurred while validating the discount code.'
            }
    
    @staticmethod
    def apply_discount_code(code: str, user: User, order_amount: float, payment_reference: str = None) -> Tuple[bool, Dict[str, Any]]:
        """
        Apply a discount code and record its usage.
        
        Args:
            code: The discount code to apply
            user: The user applying the code
            order_amount: Original order amount
            payment_reference: Reference to the payment/order
            
        Returns:
            Tuple of (success, application_data)
        """
        try:
            # First validate the code
            is_valid, validation_data = DiscountValidationService.validate_discount_code(
                code, user, order_amount
            )
            
            if not is_valid:
                return False, validation_data
            
            discount_code = validation_data['discount_code']
            discount_amount = validation_data['discount_amount']
            final_amount = validation_data['final_amount']
            
            # Create usage record
            usage_data = {
                'discount_code': discount_code.id,
                'user': user.id,
                'order_amount': order_amount,
                'discount_amount': discount_amount,
                'final_amount': final_amount,
                'payment_reference': payment_reference
            }
            
            serializer = DiscountUsageCreateSerializer(data=usage_data)
            if serializer.is_valid():
                with transaction.atomic():
                    usage_record = serializer.save()
                    logger.info(f"Discount applied: {code} by {user.email} - ${discount_amount} off")
                    
                    return True, {
                        'usage_record': usage_record,
                        'original_amount': order_amount,
                        'discount_amount': discount_amount,
                        'final_amount': final_amount,
                        'discount_percentage': discount_code.discount_percentage,
                        'message': f'Discount applied successfully! You saved ${discount_amount:.2f}'
                    }
            else:
                return False, {
                    'errors': serializer.errors,
                    'message': 'Failed to apply discount due to validation errors.'
                }
                
        except Exception as e:
            logger.error(f"Error applying discount code: {str(e)}")
            return False, {
                'error': str(e),
                'message': 'An unexpected error occurred while applying the discount code.'
            }


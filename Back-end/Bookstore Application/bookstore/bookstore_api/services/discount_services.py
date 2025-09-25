from django.db import transaction, models
from django.core.exceptions import ValidationError
from django.utils import timezone
from typing import Dict, Any, Optional, Tuple
import logging

from ..models import DiscountCode, DiscountUsage, User, Cart, BookDiscount, BookDiscountUsage, Book
from ..serializers import (
    DiscountCodeCreateSerializer,
    DiscountCodeUpdateSerializer,
    DiscountCodeListSerializer,
    DiscountUsageCreateSerializer,
    BookDiscountCreateSerializer,
    BookDiscountUpdateSerializer,
    BookDiscountListSerializer,
    BookDiscountUsageCreateSerializer,
    AvailableBooksSerializer,
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
    def get_discount_codes(include_inactive: bool = False, is_active: Optional[bool] = None, search: Optional[str] = None) -> Dict[str, Any]:
        """
        Get all discount codes with optional filtering and search.
        
        Args:
            include_inactive: Whether to include inactive codes (legacy parameter)
            is_active: Filter by active status (True=active only, False=inactive only, None=all)
            search: Search term to filter discount codes by code or description
            
        Returns:
            Dictionary containing discount codes and metadata
        """
        try:
            queryset = DiscountCode.objects.all()
            logger.info(f"DiscountService - Initial queryset count: {queryset.count()}")
            
            # Handle search parameter
            if search and search.strip():
                search_term = search.strip()
                queryset = queryset.filter(
                    models.Q(code__icontains=search_term)
                )
                logger.info(f"DiscountService - After search filter ('{search_term}'): {queryset.count()}")
            
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


class BookDiscountService:
    """
    Service class for handling book discount management operations.
    """
    
    @staticmethod
    def create_book_discount(data: Dict[str, Any], created_by: User) -> Tuple[bool, Dict[str, Any]]:
        """
        Create a new book discount.
        
        Args:
            data: Dictionary containing book discount data
            created_by: User creating the discount
            
        Returns:
            Tuple of (success, result_data)
        """
        try:
            # Add created_by to data
            data['created_by'] = created_by.id
            
            serializer = BookDiscountCreateSerializer(data=data)
            if serializer.is_valid():
                with transaction.atomic():
                    book_discount = serializer.save()
                    logger.info(f"Book discount created: {book_discount.code} for book {book_discount.book.name}")
                    
                    return True, {
                        'book_discount': BookDiscountListSerializer(book_discount).data,
                        'message': f'Book discount "{book_discount.code}" created successfully for "{book_discount.book.name}".'
                    }
            else:
                return False, {
                    'errors': serializer.errors,
                    'message': 'Failed to create book discount due to validation errors.'
                }
                
        except Exception as e:
            logger.error(f"Error creating book discount: {str(e)}")
            return False, {
                'error': str(e),
                'message': 'An unexpected error occurred while creating the book discount.'
            }
    
    @staticmethod
    def update_book_discount(book_discount_id: int, data: Dict[str, Any]) -> Tuple[bool, Dict[str, Any]]:
        """
        Update an existing book discount.
        
        Args:
            book_discount_id: ID of the book discount to update
            data: Dictionary containing updated data
            
        Returns:
            Tuple of (success, result_data)
        """
        try:
            book_discount = BookDiscount.objects.get(id=book_discount_id)
            
            # Check if the discount has been used and restrictions apply
            usage_count = book_discount.usages.count()
            if usage_count > 0:
                logger.info(f"Updating book discount {book_discount.code} that has {usage_count} uses")
            
            serializer = BookDiscountUpdateSerializer(book_discount, data=data, partial=True)
            if serializer.is_valid():
                with transaction.atomic():
                    updated_discount = serializer.save()
                    logger.info(f"Book discount updated: {updated_discount.code}")
                    
                    return True, {
                        'book_discount': BookDiscountListSerializer(updated_discount).data,
                        'message': f'Book discount "{updated_discount.code}" updated successfully.'
                    }
            else:
                return False, {
                    'errors': serializer.errors,
                    'message': 'Failed to update book discount due to validation errors.'
                }
                
        except BookDiscount.DoesNotExist:
            return False, {
                'error': 'Book discount not found',
                'message': 'The specified book discount does not exist.'
            }
        except Exception as e:
            logger.error(f"Error updating book discount: {str(e)}")
            return False, {
                'error': str(e),
                'message': 'An unexpected error occurred while updating the book discount.'
            }
    
    @staticmethod
    def delete_book_discount(book_discount_id: int) -> Tuple[bool, Dict[str, Any]]:
        """
        Delete a book discount.
        
        Args:
            book_discount_id: ID of the book discount to delete
            
        Returns:
            Tuple of (success, result_data)
        """
        try:
            book_discount = BookDiscount.objects.get(id=book_discount_id)
            
            # Check if the discount has been used
            usage_count = book_discount.usages.count()
            is_expired = book_discount.end_date <= timezone.now()
            
            if usage_count > 0 and not is_expired:
                return False, {
                    'error': 'Cannot delete used book discount',
                    'message': f'This book discount has been used {usage_count} times and cannot be deleted until it expires.'
                }
            
            code_name = book_discount.code
            book_name = book_discount.book.name
            with transaction.atomic():
                book_discount.delete()
                logger.info(f"Book discount deleted: {code_name} for {book_name}")
                
            return True, {
                'message': f'Book discount "{code_name}" for "{book_name}" deleted successfully.'
            }
                
        except BookDiscount.DoesNotExist:
            return False, {
                'error': 'Book discount not found',
                'message': 'The specified book discount does not exist.'
            }
        except Exception as e:
            logger.error(f"Error deleting book discount: {str(e)}")
            return False, {
                'error': str(e),
                'message': 'An unexpected error occurred while deleting the book discount.'
            }
    
    @staticmethod
    def get_book_discounts(include_inactive: bool = False, is_active: Optional[bool] = None, search: Optional[str] = None) -> Dict[str, Any]:
        """
        Get all book discounts with optional filtering and search.
        
        Args:
            include_inactive: Whether to include inactive discounts (legacy parameter)
            is_active: Filter by active status (True=active only, False=inactive only, None=all)
            search: Search term to filter book discounts by code, book name, or description
            
        Returns:
            Dictionary containing book discounts and metadata
        """
        try:
            queryset = BookDiscount.objects.select_related('book').all()
            logger.info(f"BookDiscountService - Initial queryset count: {queryset.count()}")
            
            # Handle search parameter
            if search and search.strip():
                search_term = search.strip()
                queryset = queryset.filter(
                    models.Q(code__icontains=search_term) |
                    models.Q(book__name__icontains=search_term)
                )
                logger.info(f"BookDiscountService - After search filter ('{search_term}'): {queryset.count()}")
            
            # Handle is_active parameter (takes precedence over include_inactive)
            if is_active is not None:
                queryset = queryset.filter(is_active=is_active)
                logger.info(f"BookDiscountService - After is_active filter ({is_active}): {queryset.count()}")
            elif include_inactive:
                # If include_inactive is True, show all (no filtering)
                logger.info(f"BookDiscountService - include_inactive=True, showing all: {queryset.count()}")
            else:
                # Default behavior: show only active
                queryset = queryset.filter(is_active=True)
                logger.info(f"BookDiscountService - Default behavior, showing only active: {queryset.count()}")
            
            # Add ordering and additional filtering
            queryset = queryset.order_by('-created_at')
            
            # Categorize discounts
            active_discounts = []
            expired_discounts = []
            inactive_discounts = []
            not_started_discounts = []
            
            for discount in queryset:
                discount_data = BookDiscountListSerializer(discount).data
                
                if not discount.is_active:
                    inactive_discounts.append(discount_data)
                elif discount.is_not_started():
                    not_started_discounts.append(discount_data)
                elif discount.is_expired():
                    expired_discounts.append(discount_data)
                else:
                    active_discounts.append(discount_data)
            
            total_count = len(active_discounts) + len(expired_discounts) + len(inactive_discounts) + len(not_started_discounts)
            logger.info(f"BookDiscountService - Final counts - Active: {len(active_discounts)}, Expired: {len(expired_discounts)}, Inactive: {len(inactive_discounts)}, Not Started: {len(not_started_discounts)}, Total: {total_count}")
            
            return {
                'success': True,
                'data': {
                    'active_discounts': active_discounts,
                    'expired_discounts': expired_discounts,
                    'inactive_discounts': inactive_discounts,
                    'not_started_discounts': not_started_discounts,
                    'total_count': total_count,
                    'active_count': len(active_discounts),
                    'expired_count': len(expired_discounts),
                    'inactive_count': len(inactive_discounts),
                    'not_started_count': len(not_started_discounts)
                }
            }
            
        except Exception as e:
            logger.error(f"Error retrieving book discounts: {str(e)}")
            return {
                'success': False,
                'error': str(e),
                'message': 'An error occurred while retrieving book discounts.'
            }
    
    @staticmethod
    def get_available_books() -> Dict[str, Any]:
        """
        Get all available books for discount creation.
        
        Returns:
            Dictionary containing available books
        """
        try:
            books = Book.objects.filter(is_available=True).select_related('author', 'category').prefetch_related('images')
            
            serializer = AvailableBooksSerializer(books, many=True, context={'request': None})
            
            return {
                'success': True,
                'data': {
                    'books': serializer.data,
                    'total_count': len(serializer.data)
                }
            }
            
        except Exception as e:
            logger.error(f"Error retrieving available books: {str(e)}")
            return {
                'success': False,
                'error': str(e),
                'message': 'An error occurred while retrieving available books.'
            }
    
    @staticmethod
    def cleanup_expired_discounts() -> Dict[str, Any]:
        """
        Clean up expired book discounts.
        
        Returns:
            Dictionary containing cleanup results
        """
        try:
            count = BookDiscount.objects.cleanup_expired_discounts()
            logger.info(f"Cleaned up {count} expired book discounts")
            
            return {
                'success': True,
                'cleaned_count': count,
                'message': f'Successfully cleaned up {count} expired book discounts.'
            }
            
        except Exception as e:
            logger.error(f"Error cleaning up expired book discounts: {str(e)}")
            return {
                'success': False,
                'error': str(e),
                'message': 'An error occurred while cleaning up expired book discounts.'
            }


class BookDiscountValidationService:
    """
    Service class for validating and applying book discount codes during checkout.
    """
    
    @staticmethod
    def validate_book_discount_code(code: str, book_id: int, user: User) -> Tuple[bool, Dict[str, Any]]:
        """
        Validate a book discount code for a specific user and book.
        
        Args:
            code: The discount code to validate
            book_id: ID of the book to apply discount to
            user: The user attempting to use the code
            
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
            
            # Find the book
            try:
                book = Book.objects.get(id=book_id)
            except Book.DoesNotExist:
                return False, {
                    'error': 'book_not_found',
                    'message': 'Book not found.'
                }
            
            # Find the book discount
            try:
                book_discount = BookDiscount.objects.get(code=code, book=book)
            except BookDiscount.DoesNotExist:
                return False, {
                    'error': 'code_not_found',
                    'message': 'Invalid discount code for this book.'
                }
            
            # Check if discount is valid
            if not book_discount.is_valid():
                if not book_discount.is_active:
                    return False, {
                        'error': 'discount_inactive',
                        'message': 'This discount is no longer active.'
                    }
                elif book_discount.is_not_started():
                    return False, {
                        'error': 'discount_not_started',
                        'message': 'This discount has not started yet.'
                    }
                elif book_discount.is_expired():
                    return False, {
                        'error': 'discount_expired',
                        'message': 'This discount has expired.'
                    }
            
            # Check if user can use this discount
            can_use, usage_message = book_discount.can_be_used_by(user)
            if not can_use:
                return False, {
                    'error': 'usage_limit_exceeded',
                    'message': usage_message
                }
            
            # Calculate discount
            original_price = book.price or 0
            discount_amount = book_discount.get_discount_amount(original_price)
            final_price = book_discount.get_final_price(original_price)
            
            return True, {
                'book_discount': book_discount,
                'book': book,
                'original_price': original_price,
                'discount_amount': discount_amount,
                'final_price': final_price,
                'discount_type': book_discount.discount_type,
                'message': f'Discount code applied successfully! You save ${discount_amount:.2f}'
            }
            
        except Exception as e:
            logger.error(f"Error validating book discount code: {str(e)}")
            return False, {
                'error': 'validation_error',
                'message': 'An error occurred while validating the discount code.'
            }
    
    @staticmethod
    def apply_book_discount_code(code: str, book_id: int, user: User, order_amount: float, order=None) -> Tuple[bool, Dict[str, Any]]:
        """
        Apply a book discount code and record its usage.
        
        Args:
            code: The discount code to apply
            book_id: ID of the book to apply discount to
            user: The user applying the code
            order_amount: Original order amount
            order: Order object (optional)
            
        Returns:
            Tuple of (success, application_data)
        """
        try:
            # First validate the code
            is_valid, validation_data = BookDiscountValidationService.validate_book_discount_code(
                code, book_id, user
            )
            
            if not is_valid:
                return False, validation_data
            
            book_discount = validation_data['book_discount']
            book = validation_data['book']
            original_price = validation_data['original_price']
            discount_amount = validation_data['discount_amount']
            final_price = validation_data['final_price']
            
            # Create usage record
            usage_data = {
                'book_discount': book_discount.id,
                'customer': user.id,
                'order': order.id if order else None,
                'original_price': original_price,
                'discount_amount': discount_amount,
                'final_price': final_price
            }
            
            serializer = BookDiscountUsageCreateSerializer(data=usage_data)
            if serializer.is_valid():
                with transaction.atomic():
                    usage_record = serializer.save()
                    logger.info(f"Book discount applied: {code} by {user.email} for book {book.name} - ${discount_amount} off")
                    
                    return True, {
                        'usage_record': usage_record,
                        'book': book,
                        'original_price': original_price,
                        'discount_amount': discount_amount,
                        'final_price': final_price,
                        'discount_type': book_discount.discount_type,
                        'message': f'Book discount applied successfully! You saved ${discount_amount:.2f} on "{book.name}"'
                    }
            else:
                return False, {
                    'errors': serializer.errors,
                    'message': 'Failed to apply book discount due to validation errors.'
                }
                
        except Exception as e:
            logger.error(f"Error applying book discount code: {str(e)}")
            return False, {
                'error': str(e),
                'message': 'An unexpected error occurred while applying the book discount code.'
            }


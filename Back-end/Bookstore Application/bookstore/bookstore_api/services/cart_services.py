from django.db import transaction
from typing import Dict, Any, Optional, List
import logging

from ..models import Cart, CartItem, Book, User

logger = logging.getLogger(__name__)

class CartService:
    """
    Service for managing shopping cart operations.
    """
    
    @staticmethod
    def get_or_create_cart(user: User) -> Cart:
        """Get or create a cart for the user."""
        cart, created = Cart.objects.get_or_create(user=user)
        return cart
    
    @staticmethod
    @transaction.atomic
    def add_to_cart(user: User, book_id: int, quantity: int = 1) -> Dict[str, Any]:
        """
        Add a book to the user's cart or increase quantity if already in cart.
        """
        try:
            # Get or create user's cart
            cart = CartService.get_or_create_cart(user)
            
            # Get the book
            try:
                book = Book.objects.get(id=book_id)
            except Book.DoesNotExist:
                return {
                    'success': False,
                    'message': 'Book not found',
                    'error_code': 'BOOK_NOT_FOUND'
                }
            
            # Check if book is available
            if not book.is_available:
                return {
                    'success': False,
                    'message': 'This book is not available for purchase',
                    'error_code': 'BOOK_UNAVAILABLE'
                }
            
            # Check if book already in cart
            cart_item, item_created = CartItem.objects.get_or_create(
                cart=cart,
                book=book,
                defaults={'quantity': quantity}
            )
            
            # If item already existed, update quantity
            if not item_created:
                cart_item.quantity += quantity
                cart_item.save()
                message = f"Increased quantity of {book.name} in your cart to {cart_item.quantity}"
            else:
                message = f"Added {book.name} to your cart"
            
            return {
                'success': True,
                'message': message,
                'cart': cart
            }
            
        except Exception as e:
            logger.error(f"Error adding to cart: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to add item to cart: {str(e)}",
                'error_code': 'ADD_TO_CART_ERROR'
            }
    
    @staticmethod
    @transaction.atomic
    def update_cart_item(user: User, item_id: int, quantity: int) -> Dict[str, Any]:
        """
        Update the quantity of a specific item in the cart.
        """
        try:
            # Get the cart item
            try:
                cart_item = CartItem.objects.get(
                    id=item_id,
                    cart__user=user
                )
            except CartItem.DoesNotExist:
                return {
                    'success': False,
                    'message': 'Item not found in your cart',
                    'error_code': 'ITEM_NOT_FOUND'
                }
            
            # Update quantity
            cart_item.quantity = quantity
            cart_item.save()
            
            return {
                'success': True,
                'message': f"Updated quantity of {cart_item.book.name} to {cart_item.quantity}",
                'cart': cart_item.cart
            }
            
        except Exception as e:
            logger.error(f"Error updating cart item: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to update cart item: {str(e)}",
                'error_code': 'UPDATE_CART_ITEM_ERROR'
            }
    
    @staticmethod
    @transaction.atomic
    def remove_cart_item(user: User, item_id: int) -> Dict[str, Any]:
        """
        Remove an item from the cart.
        """
        try:
            # Get the cart item
            try:
                cart_item = CartItem.objects.get(
                    id=item_id,
                    cart__user=user
                )
            except CartItem.DoesNotExist:
                return {
                    'success': False,
                    'message': 'Item not found in your cart',
                    'error_code': 'ITEM_NOT_FOUND'
                }
            
            book_name = cart_item.book.name
            cart = cart_item.cart
            
            # Delete the item
            cart_item.delete()
            
            return {
                'success': True,
                'message': f"Removed {book_name} from your cart",
                'cart': cart
            }
            
        except Exception as e:
            logger.error(f"Error removing cart item: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to remove item from cart: {str(e)}",
                'error_code': 'REMOVE_CART_ITEM_ERROR'
            }
    
    @staticmethod
    @transaction.atomic
    def empty_cart(user: User) -> Dict[str, Any]:
        """
        Remove all items from the user's cart.
        """
        try:
            # Get user's cart
            try:
                cart = Cart.objects.get(user=user)
            except Cart.DoesNotExist:
                return {
                    'success': True,
                    'message': 'Cart is already empty'
                }
            
            # Clear the cart
            cart.clear()
            
            return {
                'success': True,
                'message': 'Cart emptied successfully',
                'cart': cart
            }
            
        except Exception as e:
            logger.error(f"Error emptying cart: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to empty cart: {str(e)}",
                'error_code': 'EMPTY_CART_ERROR'
            }
    
    @staticmethod
    def get_cart(user: User) -> Dict[str, Any]:
        """
        Get the current user's cart contents.
        """
        try:
            # Get or create user's cart
            cart = CartService.get_or_create_cart(user)
            
            return {
                'success': True,
                'message': 'Cart retrieved successfully',
                'cart': cart
            }
            
        except Exception as e:
            logger.error(f"Error retrieving cart: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to retrieve cart: {str(e)}",
                'error_code': 'GET_CART_ERROR'
            }

from rest_framework import status, permissions
from rest_framework.views import APIView
from rest_framework.response import Response
import logging

from ..models import Cart, CartItem, Book
from ..serializers import (
    CartSerializer, CartItemSerializer,
    AddToCartSerializer, UpdateCartItemSerializer
)
from ..utils import format_error_message

logger = logging.getLogger(__name__)

class CartAddView(APIView):
    """
    Add a book to the user's cart or increase quantity if already in cart.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        try:
            # Validate request data
            serializer = AddToCartSerializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            
            # Get validated data
            book_id = serializer.validated_data['book_id']
            quantity = serializer.validated_data['quantity']
            
            # Get or create user's cart
            cart, created = Cart.objects.get_or_create(customer=request.user)
            
            # Get the book
            book = Book.objects.get(id=book_id)
            
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
            
            # Return updated cart data
            cart_serializer = CartSerializer(cart)
            
            return Response({
                'success': True,
                'message': message,
                'data': cart_serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error adding to cart: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to add item to cart',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_400_BAD_REQUEST)


class CartListView(APIView):
    """
    Get the current user's cart contents.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        try:
            # Get or create user's cart
            cart, created = Cart.objects.get_or_create(customer=request.user)
            
            # Serialize cart data
            serializer = CartSerializer(cart)
            
            return Response({
                'success': True,
                'message': 'Cart retrieved successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving cart: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve cart',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class CartItemUpdateView(APIView):
    """
    Update the quantity of a specific item in the cart.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def patch(self, request, item_id):
        try:
            # Validate request data
            serializer = UpdateCartItemSerializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            
            # Get the cart item
            try:
                cart_item = CartItem.objects.get(
                    id=item_id,
                    cart__customer=request.user
                )
            except CartItem.DoesNotExist:
                return Response({
                    'success': False,
                    'message': 'Item not found in your cart',
                    'error_code': 'ITEM_NOT_FOUND'
                }, status=status.HTTP_404_NOT_FOUND)
            
            # Update quantity
            cart_item.quantity = serializer.validated_data['quantity']
            cart_item.save()
            
            # Return updated cart data
            cart_serializer = CartSerializer(cart_item.cart)
            
            return Response({
                'success': True,
                'message': f"Updated quantity of {cart_item.book.name} to {cart_item.quantity}",
                'data': cart_serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error updating cart item: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to update cart item',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_400_BAD_REQUEST)


class CartItemDeleteView(APIView):
    """
    Remove an item from the cart.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def delete(self, request, item_id):
        try:
            # Get the cart item
            try:
                cart_item = CartItem.objects.get(
                    id=item_id,
                    cart__customer=request.user
                )
            except CartItem.DoesNotExist:
                return Response({
                    'success': False,
                    'message': 'Item not found in your cart',
                    'error_code': 'ITEM_NOT_FOUND'
                }, status=status.HTTP_404_NOT_FOUND)
            
            book_name = cart_item.book.name
            
            # Delete the item
            cart_item.delete()
            
            # Get updated cart
            cart = Cart.objects.get(customer=request.user)
            cart_serializer = CartSerializer(cart)
            
            return Response({
                'success': True,
                'message': f"Removed {book_name} from your cart",
                'data': cart_serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error removing cart item: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to remove item from cart',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_400_BAD_REQUEST)


class CartEmptyView(APIView):
    """
    Remove all items from the user's cart.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def delete(self, request):
        try:
            # Get user's cart
            try:
                cart = Cart.objects.get(customer=request.user)
            except Cart.DoesNotExist:
                return Response({
                    'success': True,
                    'message': 'Cart is already empty',
                }, status=status.HTTP_200_OK)
            
            # Clear the cart
            cart.clear()
            
            return Response({
                'success': True,
                'message': 'Cart emptied successfully',
                'data': {
                    'item_count': 0,
                    'total_quantity': 0,
                    'total_price': 0
                }
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error emptying cart: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to empty cart',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

from rest_framework import serializers
from ..models import Cart, CartItem, Book
from .library_serializers import BookSerializer

class CartItemSerializer(serializers.ModelSerializer):
    """
    Serializer for cart items, including book details.
    """
    book_details = BookSerializer(source='book', read_only=True)
    subtotal = serializers.DecimalField(
        source='get_total_price',
        read_only=True,
        max_digits=10,
        decimal_places=2
    )
    
    class Meta:
        model = CartItem
        fields = [
            'id', 'book', 'book_details', 'quantity', 
            'subtotal', 'added_at', 'updated_at'
        ]
        read_only_fields = ['id', 'added_at', 'updated_at']
    
    def validate_quantity(self, value):
        """Validate quantity is at least 1."""
        if value < 1:
            raise serializers.ValidationError("Quantity must be at least 1.")
        return value
    
    def validate_book(self, value):
        """Validate the book is available."""
        if not value.is_available:
            raise serializers.ValidationError("This book is not available for purchase.")
        return value


class CartSerializer(serializers.ModelSerializer):
    """
    Serializer for user's shopping cart with all items.
    """
    items = CartItemSerializer(many=True, read_only=True)
    total_price = serializers.DecimalField(
        source='get_total_price',
        read_only=True,
        max_digits=10,
        decimal_places=2
    )
    item_count = serializers.IntegerField(
        source='get_total_items',
        read_only=True
    )
    total_quantity = serializers.IntegerField(
        source='get_total_items',
        read_only=True
    )
    
    class Meta:
        model = Cart
        fields = [
            'id', 'customer', 'items', 'total_price', 
            'item_count', 'total_quantity',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'customer', 'created_at', 'updated_at']


class AddToCartSerializer(serializers.Serializer):
    """
    Serializer for adding items to cart.
    """
    book_id = serializers.IntegerField(required=True)
    quantity = serializers.IntegerField(required=False, default=1)
    
    def validate_quantity(self, value):
        """Validate quantity is at least 1."""
        if value < 1:
            raise serializers.ValidationError("Quantity must be at least 1.")
        return value
    
    def validate_book_id(self, value):
        """Validate the book exists and is available."""
        try:
            book = Book.objects.get(id=value)
            if not book.is_available:
                raise serializers.ValidationError("This book is not available for purchase.")
        except Book.DoesNotExist:
            raise serializers.ValidationError("Book not found.")
        return value


class UpdateCartItemSerializer(serializers.Serializer):
    """
    Serializer for updating cart item quantity.
    """
    quantity = serializers.IntegerField(required=True)
    
    def validate_quantity(self, value):
        """Validate quantity is at least 1."""
        if value < 1:
            raise serializers.ValidationError("Quantity must be at least 1.")
        return value

from django.db import models
from .user_model import User
from .library_model import Book

class Cart(models.Model):
    """
    Shopping cart model to store user's selected books.
    Each user has one cart that contains multiple cart items.
    """
    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name='cart',
        help_text="User who owns this cart"
    )
    
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When the cart was created"
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="When the cart was last updated"
    )
    
    class Meta:
        db_table = 'cart'
        verbose_name = 'Cart'
        verbose_name_plural = 'Carts'
    
    def __str__(self):
        return f"Cart for {self.user.email}"
    
    def get_total_price(self):
        """Calculate the total price of all items in the cart."""
        return sum(item.get_subtotal() for item in self.items.all())
    
    def get_item_count(self):
        """Get the total number of items in the cart."""
        return self.items.count()
    
    def get_total_quantity(self):
        """Get the total quantity of all items in the cart."""
        return sum(item.quantity for item in self.items.all())
    
    def clear(self):
        """Remove all items from the cart."""
        self.items.all().delete()


class CartItem(models.Model):
    """
    Individual item in a user's shopping cart.
    Each item relates to a specific book with a quantity.
    """
    cart = models.ForeignKey(
        Cart,
        on_delete=models.CASCADE,
        related_name='items',
        help_text="Cart this item belongs to"
    )
    
    book = models.ForeignKey(
        Book,
        on_delete=models.CASCADE,
        related_name='cart_items',
        help_text="Book added to cart"
    )
    
    quantity = models.PositiveIntegerField(
        default=1,
        help_text="Quantity of the book"
    )
    
    added_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When the item was added to the cart"
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="When the item was last updated"
    )
    
    class Meta:
        db_table = 'cart_item'
        verbose_name = 'Cart Item'
        verbose_name_plural = 'Cart Items'
        unique_together = ['cart', 'book']  # Prevent duplicate books in cart
    
    def __str__(self):
        return f"{self.quantity} x {self.book.name} in {self.cart}"
    
    def get_subtotal(self):
        """Calculate the subtotal for this item (price * quantity)."""
        return self.book.price * self.quantity


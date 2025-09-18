from django.db import models
from django.core.validators import MinValueValidator
from .user_model import User
from .library_model import Book


class Cart(models.Model):
    """
    Shopping cart for customers to add books before checkout.
    """
    customer = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name='cart',
        limit_choices_to={'user_type': 'customer'},
        help_text="Customer who owns this cart"
    )
    
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When the cart was created"
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="When the cart was last updated"
    )
    
    is_active = models.BooleanField(
        default=True,
        help_text="Whether the cart is currently active"
    )
    
    class Meta:
        db_table = 'cart'
        verbose_name = 'Cart'
        verbose_name_plural = 'Carts'
        ordering = ['-updated_at']
    
    def __str__(self):
        return f"Cart for {self.customer.get_full_name()}"
    
    def get_total_items(self):
        """Get the total number of items in the cart."""
        return sum(item.quantity for item in self.items.all())
    
    def get_total_price(self):
        """Calculate the total price of all items in the cart."""
        return sum(item.get_total_price() for item in self.items.all())
    
    def get_total_borrow_price(self):
        """Calculate the total borrow price of all items in the cart."""
        return sum(item.get_total_borrow_price() for item in self.items.all())
    
    def is_empty(self):
        """Check if the cart is empty."""
        return not self.items.exists()
    
    def clear(self):
        """Remove all items from the cart."""
        self.items.all().delete()
        self.save()
    
    def get_cart_summary(self):
        """Get a summary of the cart contents."""
        items = self.items.all()
        total_items = sum(item.quantity for item in items)
        total_price = sum(item.get_total_price() for item in items)
        total_borrow_price = sum(item.get_total_borrow_price() for item in items)
        
        return {
            'total_items': total_items,
            'total_price': total_price,
            'total_borrow_price': total_borrow_price,
            'items_count': items.count(),
        }
    
    @classmethod
    def get_or_create_cart(cls, customer):
        """Get existing cart or create a new one for the customer."""
        cart, created = cls.objects.get_or_create(
            customer=customer,
            defaults={'is_active': True}
        )
        return cart


class CartItem(models.Model):
    """
    Individual items in the shopping cart.
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
        help_text="Book in the cart"
    )
    
    quantity = models.PositiveIntegerField(
        default=1,
        validators=[MinValueValidator(1)],
        help_text="Quantity of the book"
    )
    
    item_type = models.CharField(
        max_length=20,
        choices=[
            ('purchase', 'Purchase'),
            ('borrow', 'Borrow'),
        ],
        default='purchase',
        help_text="Whether this item is for purchase or borrowing"
    )
    
    added_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When this item was added to the cart"
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="When this item was last updated"
    )
    
    class Meta:
        db_table = 'cart_item'
        verbose_name = 'Cart Item'
        verbose_name_plural = 'Cart Items'
        unique_together = ['cart', 'book', 'item_type']
        ordering = ['-added_at']
    
    def __str__(self):
        return f"{self.quantity}x {self.book.name} ({self.get_item_type_display()}) in {self.cart}"
    
    def get_total_price(self):
        """Calculate the total price for this item (for purchase)."""
        if self.item_type == 'purchase' and self.book.price:
            return self.book.price * self.quantity
        return 0
    
    def get_total_borrow_price(self):
        """Calculate the total borrow price for this item."""
        if self.item_type == 'borrow':
            return self.book.borrow_price * self.quantity
        return 0
    
    def can_increase_quantity(self):
        """Check if quantity can be increased."""
        if self.item_type == 'purchase':
            # For purchase, check if book is available
            return self.book.is_available and self.book.quantity >= (self.quantity + 1)
        else:
            # For borrowing, check if book can be borrowed
            return self.book.is_available_for_borrow and self.book.available_copies >= (self.quantity + 1)
    
    def can_decrease_quantity(self):
        """Check if quantity can be decreased."""
        return self.quantity > 1
    
    def increase_quantity(self, amount=1):
        """Increase the quantity of this item."""
        if self.can_increase_quantity():
            self.quantity += amount
            self.save()
            return True
        return False
    
    def decrease_quantity(self, amount=1):
        """Decrease the quantity of this item."""
        if self.can_decrease_quantity():
            new_quantity = max(1, self.quantity - amount)
            if new_quantity == 1:
                # Remove item if quantity becomes 1
                self.delete()
            else:
                self.quantity = new_quantity
                self.save()
            return True
        return False
    
    def get_availability_status(self):
        """Get availability status for this item."""
        if self.item_type == 'purchase':
            if not self.book.is_available:
                return "Not Available for Purchase"
            elif self.book.quantity < self.quantity:
                return "Insufficient Stock"
            else:
                return "Available for Purchase"
        else:
            if not self.book.is_available_for_borrow:
                return "Not Available for Borrowing"
            elif self.book.available_copies < self.quantity:
                return "Insufficient Copies for Borrowing"
            else:
                return "Available for Borrowing"
    
    def is_available(self):
        """Check if this item is available for the requested action."""
        if self.item_type == 'purchase':
            return self.book.is_available and self.book.quantity >= self.quantity
        else:
            return self.book.is_available_for_borrow and self.book.available_copies >= self.quantity
    
    @classmethod
    def get_cart_items_by_type(cls, cart, item_type):
        """Get cart items of a specific type."""
        return cls.objects.filter(cart=cart, item_type=item_type)
    
    @classmethod
    def get_cart_stats(cls, cart):
        """
        Get statistics about the cart.
        """
        purchase_items = cls.objects.filter(cart=cart, item_type='purchase')
        borrow_items = cls.objects.filter(cart=cart, item_type='borrow')
        
        purchase_total = sum(item.get_total_price() for item in purchase_items)
        borrow_total = sum(item.get_total_borrow_price() for item in borrow_items)
        
        return {
            'purchase_items_count': purchase_items.count(),
            'borrow_items_count': borrow_items.count(),
            'purchase_total': purchase_total,
            'borrow_total': borrow_total,
            'total_items': purchase_items.count() + borrow_items.count(),
        }


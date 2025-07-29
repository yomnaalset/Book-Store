from django.urls import path
from bookstore_api.views.cart_views import (
    CartAddView, CartListView, CartItemUpdateView,
    CartItemDeleteView, CartEmptyView
)

# Cart URLs configuration
cart_urls = [
    # Add to cart
    path('add/', CartAddView.as_view(), name='cart_add'),
    # Get cart contents
    path('', CartListView.as_view(), name='cart_list'),
    # Update cart item
    path('item/<int:item_id>/update/', CartItemUpdateView.as_view(), name='cart_item_update'),
    # Delete cart item
    path('item/<int:item_id>/delete/', CartItemDeleteView.as_view(), name='cart_item_delete'),
    # Empty cart
    path('empty/', CartEmptyView.as_view(), name='cart_empty'),
]

from django.urls import path
from bookstore_api.views.discount_views import (
    DiscountCodeListCreateView,
    DiscountCodeDetailView,
    DiscountCodeValidationView,
    DiscountCodeApplicationView,
    DiscountCodeRemovalView,
    DiscountCodeCleanupView,
    DiscountListActiveView,
    get_user_available_codes,
    quick_code_check,
    # Book discount views
    BookDiscountListCreateView,
    BookDiscountDetailView,
    AvailableBooksView,
    BookDiscountValidationView,
    BookDiscountApplicationView,
    BookDiscountCleanupView,
    get_user_available_book_discounts,
    quick_book_discount_check,
    get_discounted_books,
)

# URL patterns for discount code management
urlpatterns = [
    # Admin endpoints for discount code management
    path('admin/codes/', DiscountCodeListCreateView.as_view(), name='discount_code_list_create'),
    path('admin/codes/<int:pk>/', DiscountCodeDetailView.as_view(), name='discount_code_detail'),
    path('admin/cleanup/', DiscountCodeCleanupView.as_view(), name='discount_code_cleanup'),
    
    # Customer endpoints for using discount codes
    path('validate/', DiscountCodeValidationView.as_view(), name='discount_code_validate'),
    path('apply/', DiscountCodeApplicationView.as_view(), name='discount_code_apply'),
    path('remove/', DiscountCodeRemovalView.as_view(), name='discount_code_remove'),
    path('available/', get_user_available_codes, name='user_available_codes'),
    path('quick-check/', quick_code_check, name='quick_code_check'),
    
    # Active discount codes endpoint for advertisement forms
    path('active/', DiscountListActiveView.as_view(), name='discount-active'),
    
    # Admin endpoints for book discount management
    path('admin/book-discounts/', BookDiscountListCreateView.as_view(), name='book_discount_list_create'),
    path('admin/book-discounts/<int:pk>/', BookDiscountDetailView.as_view(), name='book_discount_detail'),
    path('admin/book-discounts/cleanup/', BookDiscountCleanupView.as_view(), name='book_discount_cleanup'),
    path('admin/available-books/', AvailableBooksView.as_view(), name='available_books'),
    
    # Customer endpoints for using book discount codes
    path('book-discounts/validate/', BookDiscountValidationView.as_view(), name='book_discount_validate'),
    path('book-discounts/apply/', BookDiscountApplicationView.as_view(), name='book_discount_apply'),
    path('book-discounts/available/', get_user_available_book_discounts, name='user_available_book_discounts'),
    path('book-discounts/quick-check/', quick_book_discount_check, name='quick_book_discount_check'),
    path('book-discounts/discounted-books/', get_discounted_books, name='get_discounted_books'),
]
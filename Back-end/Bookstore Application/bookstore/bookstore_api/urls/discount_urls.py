from django.urls import path
from bookstore_api.views.discount_views import (
    DiscountCodeListCreateView,
    DiscountCodeDetailView,
    DiscountCodeValidationView,
    DiscountCodeApplicationView,
    CustomerDiscountUsageHistoryView,
    DiscountUsageReportView,
    DiscountCodeCleanupView,
    get_user_available_codes,
    quick_code_check,
)

# URL patterns for discount code management
discount_urls = [
    # Admin endpoints for discount code management
    path('admin/codes/', DiscountCodeListCreateView.as_view(), name='discount_code_list_create'),
    path('admin/codes/<int:pk>/', DiscountCodeDetailView.as_view(), name='discount_code_detail'),
    path('admin/reports/', DiscountUsageReportView.as_view(), name='discount_usage_reports'),
    path('admin/cleanup/', DiscountCodeCleanupView.as_view(), name='discount_code_cleanup'),
    
    # Customer endpoints for using discount codes
    path('validate/', DiscountCodeValidationView.as_view(), name='discount_code_validate'),
    path('apply/', DiscountCodeApplicationView.as_view(), name='discount_code_apply'),
    path('my-usage/', CustomerDiscountUsageHistoryView.as_view(), name='customer_discount_history'),
    path('available/', get_user_available_codes, name='user_available_codes'),
    path('quick-check/', quick_code_check, name='quick_code_check'),
]
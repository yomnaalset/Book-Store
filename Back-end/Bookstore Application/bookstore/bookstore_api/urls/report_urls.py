from django.urls import path


from ..views.report_views import (
    DashboardStatsView, SalesReportView, UserReportView,
    BookReportView, OrderReportView, AuthorReportView,
    CategoryReportView, RatingReportView, FinesReportView, 
    BorrowingReportView, DeliveryReportView
)

report_urls = [
    # Report data endpoints
    path('dashboard/', DashboardStatsView.as_view(), name='dashboard-stats'),
    path('sales/', SalesReportView.as_view(), name='sales-report'),
    path('users/', UserReportView.as_view(), name='user-report'),
    path('books/', BookReportView.as_view(), name='book-report'),
    path('orders/', OrderReportView.as_view(), name='order-report'),
    path('authors/', AuthorReportView.as_view(), name='author-report'),
    path('categories/', CategoryReportView.as_view(), name='category-report'),
    path('ratings/', RatingReportView.as_view(), name='rating-report'),
    path('fines/', FinesReportView.as_view(), name='fines-report'),
    path('borrowing/', BorrowingReportView.as_view(), name='borrowing-report'),
    path('delivery/', DeliveryReportView.as_view(), name='delivery-report'),
]

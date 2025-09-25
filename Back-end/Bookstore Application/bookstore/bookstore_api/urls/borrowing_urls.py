from django.urls import path
from bookstore_api.views.borrowing_views import (
    # Book discovery
    MostBorrowedBooksView,
    
    # Customer views
    BorrowRequestCreateView,
    CustomerBorrowingsView,
    BorrowRequestDetailView,
    BorrowingExtensionView,
    EarlyReturnView,
    BorrowRatingView,
    BorrowCancelView,
    BorrowFineDetailView,
    BorrowStatisticsView,
    
    # Library Manager views
    PendingRequestsView,
    BorrowApprovalView,
    OverdueBorrowingsView,
    BorrowingReportView,
    BorrowExtensionsListView,
    BorrowFinesListView,
    
    # Delivery Manager views
    DeliveryReadyView,
    DeliveryPickupView,
    DeliveryCompleteView,
    BookCollectionView,
)

# Borrowing URLs configuration
borrowing_urls = [
    # =====================================
    # BOOK DISCOVERY ENDPOINTS
    # =====================================
    # Most borrowed books (All authenticated users)
    path('books/most-borrowed/', MostBorrowedBooksView.as_view(), name='most_borrowed_books'),
    
    # =====================================
    # CUSTOMER ENDPOINTS
    # =====================================
    # Customer borrow request management
    path('requests/', BorrowRequestCreateView.as_view(), name='borrow_request_create'),
    path('my-borrowings/', CustomerBorrowingsView.as_view(), name='customer_borrowings'),
    path('borrowings/<int:pk>/', BorrowRequestDetailView.as_view(), name='borrow_request_detail'),
    
    # Customer borrowing actions
    path('borrowings/<int:pk>/extend/', BorrowingExtensionView.as_view(), name='borrowing_extension'),
    path('borrowings/<int:pk>/early-return/', EarlyReturnView.as_view(), name='early_return'),
    path('borrowings/<int:pk>/rate/', BorrowRatingView.as_view(), name='borrow_rating'),
    path('requests/<int:pk>/cancel/', BorrowCancelView.as_view(), name='borrow_cancel'),
    
    # Customer fine management
    path('borrowings/<int:pk>/fine/', BorrowFineDetailView.as_view(), name='borrow_fine_detail'),
    
    # Customer statistics
    path('statistics/', BorrowStatisticsView.as_view(), name='borrow_statistics'),
    
    # =====================================
    # LIBRARY MANAGER ENDPOINTS
    # =====================================
    # Library manager borrow management
    path('requests/pending/', PendingRequestsView.as_view(), name='pending_requests'),
    path('requests/<int:pk>/approve/', BorrowApprovalView.as_view(), name='borrow_approval'),
    path('requests/<int:pk>/reject/', BorrowApprovalView.as_view(), name='borrow_rejection'),
    
    # Library manager monitoring
    path('borrowings/overdue/', OverdueBorrowingsView.as_view(), name='overdue_borrowings'),
    path('ratings/report/', BorrowingReportView.as_view(), name='borrowing_report'),
    
    # Library manager extension and fine management
    path('extensions/', BorrowExtensionsListView.as_view(), name='borrowing_extensions_list'),
    path('fines/', BorrowFinesListView.as_view(), name='borrowing_fines_list'),
    
    # =====================================
    # DELIVERY MANAGER ENDPOINTS
    # =====================================
    # Delivery management
    path('deliveries/ready/', DeliveryReadyView.as_view(), name='delivery_ready'),
    path('deliveries/<int:pk>/pickup/', DeliveryPickupView.as_view(), name='delivery_pickup'),
    path('deliveries/<int:pk>/delivered/', DeliveryCompleteView.as_view(), name='delivery_complete'),
    path('deliveries/<int:pk>/collect/', BookCollectionView.as_view(), name='book_collection'),
]

urlpatterns = borrowing_urls
from django.urls import path
from bookstore_api.views.borrowing_views import (
    # Book discovery
    MostBorrowedBooksView,
    
    # Customer views
    BorrowRequestCreateView,
    ConfirmPaymentView,
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
    AllBorrowingRequestsView,
    BorrowApprovalView,
    DeliveryManagerSelectionView,
    OverdueBorrowingsView,
    BorrowingReportView,
    BorrowExtensionsListView,
    BorrowFinesListView,
    
    # Delivery Manager views
    DeliveryReadyView,
    DeliveryPickupView,
    CompleteDeliveryView,
    BookCollectionView,
    BorrowingDeliveryOrdersView,
    StartDeliveryView,
    AcceptDeliveryRequestView,
    RejectDeliveryRequestView,
    RejectDeliveryOrderView,
    StartDeliveryOrderView,
    
    # Location Tracking views
    GetDeliveryLocationView,
    
    # Late Return Management views
    LateReturnProcessView,
    LateReturnSummaryView,
    DepositManagementView,
    ProcessOverdueBorrowingsView,
    
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
    path('confirm-payment/<int:pk>/', ConfirmPaymentView.as_view(), name='confirm_payment'),
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
    path('requests/all/', AllBorrowingRequestsView.as_view(), name='all_borrowing_requests'),
    path('requests/<int:pk>/approve/', BorrowApprovalView.as_view(), name='borrow_approval'),
    path('requests/<int:pk>/reject/', BorrowApprovalView.as_view(), name='borrow_rejection'),
    path('delivery-managers/', DeliveryManagerSelectionView.as_view(), name='delivery_manager_selection'),
    
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
    path('deliveries/<int:pk>/delivered/', CompleteDeliveryView.as_view(), name='delivery_complete'),
    path('deliveries/<int:pk>/collect/', BookCollectionView.as_view(), name='book_collection'),
    
    # New borrowing delivery workflow
    path('delivery/orders/', BorrowingDeliveryOrdersView.as_view(), name='borrowing_delivery_orders'),
    path('delivery/orders/<int:order_id>/start/', StartDeliveryOrderView.as_view(), name='start_delivery_order'),
    path('delivery/orders/<int:order_id>/reject/', RejectDeliveryOrderView.as_view(), name='reject_delivery_order'),
    path('delivery/orders/<int:order_id>/complete/', CompleteDeliveryView.as_view(), name='complete_delivery'),
    
    # Step 3.1 & 3.2: New delivery workflow endpoints
    path('borrowings/<int:borrow_id>/accept/', AcceptDeliveryRequestView.as_view(), name='accept_delivery_request'),
    path('borrowings/<int:borrow_id>/reject/', RejectDeliveryRequestView.as_view(), name='reject_delivery_request'),
    path('borrowings/<int:borrow_id>/start-delivery/', StartDeliveryView.as_view(), name='start_delivery'),
    
    # Step 3.4: Real-time location tracking endpoint
    path('borrowings/<int:borrow_id>/delivery-location/', GetDeliveryLocationView.as_view(), name='get_delivery_location'),
    
    # =====================================
    # LATE RETURN MANAGEMENT ENDPOINTS
    # =====================================
    # Late return processing (Library Manager)
    path('borrowings/<int:borrow_request_id>/late-return/', LateReturnProcessView.as_view(), name='late_return_process'),
    
    
    # Late return summary (All authenticated users with permissions)
    path('borrowings/<int:borrow_request_id>/late-return-summary/', LateReturnSummaryView.as_view(), name='late_return_summary'),
    
    # Deposit management
    path('borrowings/<int:borrow_request_id>/deposit/', DepositManagementView.as_view(), name='deposit_management'),
    
    # Process overdue borrowings (Library Manager)
    path('process-overdue/', ProcessOverdueBorrowingsView.as_view(), name='process_overdue_borrowings'),
    
]

urlpatterns = borrowing_urls
from django.urls import path
from bookstore_api.views.return_view import (
    ReturnRequestCreateView,
    ReturnRequestListView,
    ReturnRequestDetailView,
    ApproveReturnRequestView,
    AssignDeliveryManagerView,
    AcceptReturnRequestView,
    StartReturnProcessView,
    CompleteReturnRequestView,
    DeliveryManagersListView,
    BookReturnWithFineView,
    FinePaymentView,
    CustomerFinesView,
    MarkFineAsPaidView,
    AllFinesView,
    GetReturnDeliveryLocationView,
    SelectReturnFinePaymentMethodView,
    ConfirmCardPaymentView,
    ConfirmCashPaymentView,
    ConfirmReturnFineView,
    IncreaseReturnFineView,
)

# Return Request URLs configuration
return_urls = [
    # Customer endpoints
    path('requests/', ReturnRequestCreateView.as_view(), name='return_request_create'),
    
    # List and detail endpoints (role-based filtering)
    path('requests/list/', ReturnRequestListView.as_view(), name='return_request_list'),
    path('requests/<int:pk>/', ReturnRequestDetailView.as_view(), name='return_request_detail'),
    
    # Admin endpoints
    path('requests/<int:pk>/approve/', ApproveReturnRequestView.as_view(), name='approve_return_request'),
    path('requests/<int:pk>/assign/', AssignDeliveryManagerView.as_view(), name='assign_delivery_manager'),
    path('delivery-managers/', DeliveryManagersListView.as_view(), name='delivery_managers_list'),
    
    # Delivery manager endpoints
    path('requests/<int:pk>/accept/', AcceptReturnRequestView.as_view(), name='accept_return_request'),
    path('requests/<int:pk>/start/', StartReturnProcessView.as_view(), name='start_return_process'),
    path('requests/<int:pk>/complete/', CompleteReturnRequestView.as_view(), name='complete_return_request'),
    path('requests/<int:pk>/delivery-location/', GetReturnDeliveryLocationView.as_view(), name='get_return_delivery_location'),
    
    # Fine Management endpoints for returns
    path('requests/<int:pk>/return-with-fine/', BookReturnWithFineView.as_view(), name='book_return_with_fine'),
    path('requests/<int:pk>/pay-fine/', FinePaymentView.as_view(), name='fine_payment'),
    path('fines/my-fines/', CustomerFinesView.as_view(), name='customer_fines'),
    path('fines/mark-paid/', MarkFineAsPaidView.as_view(), name='mark_fine_paid'),
    path('fines/all/', AllFinesView.as_view(), name='all_fines'),
    
    # Return Fine Payment Method endpoints
    path('fines/<int:fine_id>/select-payment-method/', SelectReturnFinePaymentMethodView.as_view(), name='select_return_fine_payment_method'),
    path('fines/<int:fine_id>/confirm-card-payment/', ConfirmCardPaymentView.as_view(), name='confirm_card_payment'),
    path('fines/<int:fine_id>/confirm-cash-payment/', ConfirmCashPaymentView.as_view(), name='confirm_cash_payment'),
    
    # Admin Fine Management endpoints
    path('requests/<int:pk>/confirm-fine/', ConfirmReturnFineView.as_view(), name='confirm_return_fine'),
    path('requests/<int:pk>/increase-fine/', IncreaseReturnFineView.as_view(), name='increase_return_fine'),
]

urlpatterns = return_urls


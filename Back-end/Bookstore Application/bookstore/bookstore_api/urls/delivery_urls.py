from django.urls import path
from ..views.delivery_views import (
    DeliveryRequestListView,
    DeliveryRequestDetailView,
    CustomerOrdersView,
    OrderDetailView,
    AvailableDeliveryManagersView,
    approve_order,
    assign_delivery_manager,
    accept_delivery_request,
    reject_delivery_request,
    start_delivery,
    update_location,
    complete_delivery,
    manage_delivery_notes,
    my_assignments,
    assigned_requests,
    delivery_notifications,
    delivery_notification_mark_read,
    delivery_notifications_unread_count,
)

app_name = 'delivery'

urlpatterns = [
    # Customer orders endpoint
    # GET /orders/?order_type=purchase|borrowing&status=pending|confirmed|processing|delivered|cancelled
    # POST /orders/ - Create order from cart checkout
    path('orders/', CustomerOrdersView.as_view(), name='customer-orders-list'),
    
    # Order detail endpoint
    # GET /orders/{id}/ - Get order detail
    path('orders/<int:pk>/', OrderDetailView.as_view(), name='customer-orders-detail'),
    
    # Approve order endpoint
    # PATCH /orders/{id}/approve/ - Approve order and assign delivery manager
    path('orders/<int:pk>/approve/', approve_order, name='approve-order'),
    
    # Available delivery managers endpoint
    # GET /orders/available_delivery_managers/
    path('orders/available_delivery_managers/', AvailableDeliveryManagersView.as_view(), name='available-delivery-managers'),
    
    # List delivery requests (with query parameters for filtering)
    # GET /delivery-requests/?type=purchase|borrow|return&status=pending|assigned|accepted|in_delivery|completed|rejected
    path('delivery-requests/', DeliveryRequestListView.as_view(), name='delivery-request-list'),
    
    # Get delivery request detail
    # GET /delivery-requests/{id}/
    path('delivery-requests/<int:pk>/', DeliveryRequestDetailView.as_view(), name='delivery-request-detail'),
    
    # Assign delivery manager (Admin only)
    # POST /delivery-requests/{id}/assign/
    path('delivery-requests/<int:delivery_request_id>/assign/', assign_delivery_manager, name='assign-delivery-manager'),
    
    # Accept delivery request
    # POST /delivery-requests/{id}/accept/
    path('delivery-requests/<int:delivery_request_id>/accept/', accept_delivery_request, name='accept-delivery-request'),
    
    # Reject delivery request
    # POST /delivery-requests/{id}/reject/
    path('delivery-requests/<int:delivery_request_id>/reject/', reject_delivery_request, name='reject-delivery-request'),
    
    # Start delivery
    # POST /delivery-requests/{id}/start/
    path('delivery-requests/<int:delivery_request_id>/start/', start_delivery, name='start-delivery'),
    
    # Update location (GPS)
    # POST /delivery-requests/{id}/update-location/
    path('delivery-requests/<int:delivery_request_id>/update-location/', update_location, name='update-location'),
    
    # Complete delivery
    # POST /delivery-requests/{id}/complete/
    path('delivery-requests/<int:delivery_request_id>/complete/', complete_delivery, name='complete-delivery'),
    
    # Manage delivery notes
    # PUT/PATCH /delivery-requests/{id}/notes/ - Add or update delivery notes
    # DELETE /delivery-requests/{id}/notes/ - Delete delivery notes
    path('delivery-requests/<int:delivery_request_id>/notes/', manage_delivery_notes, name='manage-delivery-notes'),
    
    # Delivery manager assignments
    # GET /assignments/my-assignments/ - Get delivery requests assigned to current delivery manager
    path('assignments/my-assignments/', my_assignments, name='my-assignments'),
    
    # Delivery manager assigned requests (alias)
    # GET /managers/assigned-requests/ - Get delivery requests assigned to current delivery manager
    path('managers/assigned-requests/', assigned_requests, name='assigned-requests'),
    
    # Delivery notifications
    # GET /notifications/ - Get delivery-related notifications
    path('notifications/', delivery_notifications, name='delivery-notifications'),
    
    # Mark delivery notification as read
    # POST /notifications/{id}/mark-read/ - Mark a delivery notification as read
    path('notifications/<int:notification_id>/mark-read/', delivery_notification_mark_read, name='delivery-notification-mark-read'),
    
    # Delivery notifications unread count
    # GET /notifications/unread-count/ - Get unread count for delivery notifications
    path('notifications/unread-count/', delivery_notifications_unread_count, name='delivery-notifications-unread-count'),
]


from django.urls import path, include
from rest_framework.routers import DefaultRouter
from ..views.delivery_views import (   
    # Order management views
    OrderListView,  
    OrderDetailView,
    OrderCreateFromPaymentView,
    OrderStatusUpdateView,
    OrdersReadyForDeliveryView,
    OrderViewSet,
    
    # New Activity Views
    NoteActivityView,
    ContactActivityView,
    LocationActivityView,
    RouteActivityView,
    ETAActivityView,
    DeliveryActivityView,
    
    # Delivery assignment views
    DeliveryAssignmentListView,
    DeliveryAssignmentDetailView,
    DeliveryAssignmentCreateView,
    DeliveryAssignmentStatusUpdateView,
    MyDeliveryAssignmentsView,
    
    # Delivery manager views
    available_delivery_managers_view,
    DeliveryManagerStatusUpdateView,
    DeliveryManagerLocationView,
    get_delivery_manager_location_view,
    
    # Bulk operations
    bulk_assign_orders_view,
    
    # Customer views
    customer_orders_view,
    order_tracking_view,
    order_delivery_contact_view,
    
    # Delivery request views
    CustomerDeliveryRequestCreateView,
    CustomerDeliveryRequestListView,
    DeliveryRequestDetailView,
    DeliveryRequestAssignView,
    DeliveryRequestStatusUpdateView,
    DeliveryManagerAssignedRequestsView,
    LibraryAdminRequestListView,
    LibraryAdminAssignManagerView,
    
    # Location tracking views
    RealTimeTrackingView,
    LocationTrackingUpdateView,
    LocationHistoryView,
    MovementSummaryView,
    AllTrackingManagersView,
    RealTimeTrackingSettingsView,
    
    # Notifications views
    DeliveryNotificationsView,
    
    # Task management views
    TaskETAUpdateView,
)

app_name = 'delivery'

# Router for OrderViewSet
router = DefaultRouter()
router.register(r'orders', OrderViewSet, basename='order')

urlpatterns = [
    # Include router URLs
    path('', include(router.urls)),
    
    # ----------------------------
    # 🧾 Order management endpoints (legacy)
    # ----------------------------
    path('orders-legacy/', OrderListView.as_view(), name='order-list'),
    path('orders-legacy/<int:pk>/', OrderDetailView.as_view(), name='order-detail'),
    path('orders-legacy/create-from-payment/', OrderCreateFromPaymentView.as_view(), name='order-create-from-payment'),
    path('orders-legacy/<int:pk>/update-status/', OrderStatusUpdateView.as_view(), name='order-update-status'),
    path('orders-legacy/ready-for-delivery/', OrdersReadyForDeliveryView.as_view(), name='orders-ready-for-delivery'),
    
    # -----------------------------------------------------
    # 📝 New Activity Logging Endpoints (Unified & Updated)
    # -----------------------------------------------------
    path('activities/log/', NoteActivityView.as_view(), name='delivery-activity-log'),  # legacy compatibility
    path('activities/log/note/', NoteActivityView.as_view(), name='note-activity'),
    path('activities/log/contact/', ContactActivityView.as_view(), name='contact-activity'),
    path('activities/log/location/', LocationActivityView.as_view(), name='location-activity'),
    path('activities/log/route/', RouteActivityView.as_view(), name='route-activity'),
    path('activities/log/eta/', ETAActivityView.as_view(), name='eta-activity'),
    path('activities/log/delivery/', DeliveryActivityView.as_view(), name='delivery-activity'),
    
    # ---------------------------------------
    # 🚚 Delivery Assignment Endpoints
    # ---------------------------------------
    path('assignments/', DeliveryAssignmentListView.as_view(), name='assignment-list'),
    path('assignments/<int:pk>/', DeliveryAssignmentDetailView.as_view(), name='assignment-detail'),
    path('assignments/create/', DeliveryAssignmentCreateView.as_view(), name='assignment-create'),
    path('assignments/<int:pk>/update-status/', DeliveryAssignmentStatusUpdateView.as_view(), name='assignment-update-status'),
    path('assignments/my-assignments/', MyDeliveryAssignmentsView.as_view(), name='my-assignments'),
    path('assignments/bulk-assign/', bulk_assign_orders_view, name='bulk-assign-orders'),
    
    # ---------------------------------------
    # 👨‍💼 Delivery Manager Endpoints
    # ---------------------------------------
    path('managers/available/', available_delivery_managers_view, name='available-delivery-managers'),
    path('managers/update-status/', DeliveryManagerStatusUpdateView.as_view(), name='update-manager-status'),
    
    # ---------------------------------------
    # 🧍‍♂️ Customer Endpoints
    # ---------------------------------------
    path('customer/orders/', customer_orders_view, name='customer-orders'),
    path('customer/orders/track/<str:order_number>/', order_tracking_view, name='order-tracking'),
    path('customer/orders/<int:order_id>/delivery-contact/', order_delivery_contact_view, name='order-delivery-contact'),
    
    # ---------------------------------------
    # 📦 Customer Delivery Request Endpoints
    # ---------------------------------------
    path('requests/create/', CustomerDeliveryRequestCreateView.as_view(), name='request-create'),
    path('requests/my-requests/', CustomerDeliveryRequestListView.as_view(), name='my-requests'),
    path('requests/<int:pk>/', DeliveryRequestDetailView.as_view(), name='request-detail'),
    path('requests/<int:pk>/track/', DeliveryRequestDetailView.as_view(), name='request-tracking'),
    
    # Delivery Manager Request Control
    path('requests/<int:pk>/assign/', DeliveryRequestAssignView.as_view(), name='request-assign'),
    path('requests/<int:pk>/update-status/', DeliveryRequestStatusUpdateView.as_view(), name='request-update-status'),
    path('managers/assigned-requests/', DeliveryManagerAssignedRequestsView.as_view(), name='manager-assigned-requests'),
    
    # ---------------------------------------
    # 📚 Library Admin Endpoints
    # ---------------------------------------
    path('requests/', LibraryAdminRequestListView.as_view(), name='request-list'),
    path('requests/<int:pk>/assign-manager/', LibraryAdminAssignManagerView.as_view(), name='assign-manager'),
    
    # ---------------------------------------
    # 📍 Location Management Endpoints
    # ---------------------------------------
    path('location/', DeliveryManagerLocationView.as_view(), name='location-manage'),
    path('location/<int:delivery_manager_id>/', get_delivery_manager_location_view, name='location-get'),
    
    # ---------------------------------------
    # 🛰️ Real-Time Tracking Endpoints
    # ---------------------------------------
    path('tracking/', RealTimeTrackingView.as_view(), name='real-time-tracking'),
    path('tracking/update-location/', LocationTrackingUpdateView.as_view(), name='update-tracking-location'),
    path('tracking/history/', LocationHistoryView.as_view(), name='location-history'),
    path('tracking/movement-summary/', MovementSummaryView.as_view(), name='movement-summary'),
    path('tracking/all-managers/', AllTrackingManagersView.as_view(), name='all-tracking-managers'),
    path('tracking/settings/', RealTimeTrackingSettingsView.as_view(), name='tracking-settings'),
    
    # ---------------------------------------
    # 🔔 Notifications Endpoints
    # ---------------------------------------
    path('notifications/', DeliveryNotificationsView.as_view(), name='delivery-notifications'),
    
    # ---------------------------------------
    # ⏱️ Task Management Endpoints
    # ---------------------------------------
    path('tasks/<int:task_id>/eta/', TaskETAUpdateView.as_view(), name='task-update-eta'),
]
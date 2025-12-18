from django.urls import path
from ..views.complaint_views import (
    ComplaintListView,
    ComplaintDetailView,
    ComplaintStatusUpdateView,
    ComplaintAssignView,
    ComplaintResponseCreateView,
    ComplaintResponseListView,
    ComplaintResolveView,
    ComplaintUpdateStatusView,
    ComplaintReplyView,
    ComplaintStatsView,
)

# Complaints URLs configuration
complaint_urls = [
    # =====================================
    # COMPLAINT MANAGEMENT ENDPOINTS
    # =====================================
    # List and create complaints
    path('', ComplaintListView.as_view(), name='complaint_list'),
    
    # Complaint detail, update, and delete
    path('<int:pk>/', ComplaintDetailView.as_view(), name='complaint_detail'),
    
    # Update complaint status
    path('<int:pk>/status/', ComplaintStatusUpdateView.as_view(), name='complaint_status_update'),
    
    # Assign complaint to staff member
    path('<int:pk>/assign/', ComplaintAssignView.as_view(), name='complaint_assign'),
    
    # Resolve complaint
    path('<int:pk>/resolve/', ComplaintResolveView.as_view(), name='complaint_resolve'),
    
    # Update complaint status (for status menu)
    path('<int:pk>/update_status/', ComplaintUpdateStatusView.as_view(), name='complaint_update_status'),
    
    # Send reply to complaint
    path('<int:pk>/reply/', ComplaintReplyView.as_view(), name='complaint_reply'),
    
    # =====================================
    # COMPLAINT RESPONSE ENDPOINTS
    # =====================================
    # Add response to complaint
    path('<int:complaint_id>/responses/', ComplaintResponseCreateView.as_view(), name='complaint_response_create'),
    
    # List responses for a complaint
    path('<int:complaint_id>/responses/list/', ComplaintResponseListView.as_view(), name='complaint_response_list'),
    
    # =====================================
    # COMPLAINT STATISTICS ENDPOINTS
    # =====================================
    # Get complaint statistics
    path('stats/', ComplaintStatsView.as_view(), name='complaint_stats'),
]

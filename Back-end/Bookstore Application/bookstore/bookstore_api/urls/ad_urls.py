from django.urls import path
from ..views import ad_views

app_name = 'advertisements'

urlpatterns = [
    # Advertisement CRUD operations
    path('', ad_views.list_advertisements, name='list_advertisements'),
    path('create/', ad_views.create_advertisement, name='create_advertisement'),
    path('<int:ad_id>/', ad_views.get_advertisement, name='get_advertisement'),
    path('<int:ad_id>/update/', ad_views.update_advertisement, name='update_advertisement'),
    path('<int:ad_id>/delete/', ad_views.delete_advertisement, name='delete_advertisement'),
    
    # Advertisement status management
    path('<int:ad_id>/status/', ad_views.update_advertisement_status, name='update_advertisement_status'),
    path('bulk-status/', ad_views.bulk_update_status, name='bulk_update_status'),
    
    # Advertisement scheduling
    path('<int:ad_id>/schedule/', ad_views.schedule_advertisement, name='schedule_advertisement'),
    path('<int:ad_id>/activate/', ad_views.activate_advertisement, name='activate_advertisement'),
    path('<int:ad_id>/pause/', ad_views.pause_advertisement, name='pause_advertisement'),
    # Frontend compatibility endpoints
    path('<int:ad_id>/publish/', ad_views.publish_advertisement, name='publish_advertisement'),
    path('<int:ad_id>/unpublish/', ad_views.unpublish_advertisement, name='unpublish_advertisement'),
    
    # Advertisement filtering and listing
    path('active/', ad_views.get_active_advertisements, name='get_active_advertisements'),
    path('scheduled/', ad_views.get_scheduled_advertisements, name='get_scheduled_advertisements'),
    path('ending-soon/', ad_views.get_advertisements_ending_soon, name='get_advertisements_ending_soon'),
    
    # Advertisement analytics and statistics
    path('stats/', ad_views.get_overall_stats, name='get_overall_stats'),
    path('<int:ad_id>/stats/', ad_views.get_advertisement_stats, name='get_advertisement_stats'),
    
    # Public endpoints (for frontend display)
    path('public/', ad_views.get_public_advertisements, name='get_public_advertisements'),
    path('public/<int:ad_id>/', ad_views.get_public_advertisement_details, name='get_public_advertisement_details'),
]

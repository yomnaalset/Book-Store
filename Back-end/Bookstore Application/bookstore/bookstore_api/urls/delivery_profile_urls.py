from django.urls import path, include
from rest_framework.routers import DefaultRouter
from ..views import DeliveryProfileViewSet

router = DefaultRouter()
router.register(r'delivery-profiles', DeliveryProfileViewSet, basename='delivery-profiles')

urlpatterns = [
    path('', include(router.urls)),
    # Additional endpoints for delivery profiles
    path('available_managers/', DeliveryProfileViewSet.as_view({'get': 'available_managers'}), name='available-managers'),
    path('online_managers/', DeliveryProfileViewSet.as_view({'get': 'online_managers'}), name='online-managers'),
    path('update_status/', DeliveryProfileViewSet.as_view({'post': 'update_status'}), name='update-status'),
    path('update_location/', DeliveryProfileViewSet.as_view({'post': 'update_location'}), name='update-location'),
    path('update_tracking/', DeliveryProfileViewSet.as_view({'post': 'update_tracking'}), name='update-tracking'),
]

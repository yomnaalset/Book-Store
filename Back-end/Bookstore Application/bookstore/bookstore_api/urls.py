from django.urls import path, include
from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
)
from bookstore_api.urls.user_urls import user_urls
from bookstore_api.urls.library_urls import library_urls
from bookstore_api.urls.cart_urls import cart_urls
from bookstore_api.urls.payment_urls import payment_urls
from bookstore_api.urls.delivery_urls import urlpatterns as delivery_urls
from bookstore_api.urls.borrowing_urls import borrowing_urls
from bookstore_api.urls.complaint_urls import complaint_urls
from bookstore_api.urls.report_urls import urlpatterns as report_urls
from bookstore_api.views.user_views import LoginView        
from bookstore_api.urls.notification_urls import urlpatterns as notification_urls   
from bookstore_api.urls.discount_urls import urlpatterns as discount_urls
from bookstore_api.urls.user_preferences_urls import user_preferences_urls 
from bookstore_api.urls.ad_urls import urlpatterns as ad_urls
from bookstore_api.urls.delivery_profile_urls import urlpatterns as delivery_profile_urls

urlpatterns = [
    # User management endpoints
    path('users/', include(user_urls)),
    # Library management endpoints  
    path('library/', include(library_urls)),
    # Cart management endpoints
    path('cart/', include(cart_urls)),
    # Payment management endpoints
    path('payment/', include(payment_urls)),
    # Delivery management endpoints
    path('delivery/', include(delivery_urls)),
    # Borrowing management endpoints
    path('borrow/', include(borrowing_urls)),
    # Discount management endpoints
    path('discounts/', include(discount_urls)),
    # Complaints management endpoints
    path('complaints/', include(complaint_urls)),
    # Reports management endpoints
    path('reports/', include(report_urls)),
    # Notification management endpoints
    path('notifications/', include(notification_urls)),
    # User preferences endpoints (replaces manager settings)
    path('preferences/', include(user_preferences_urls)),
    # Advertisement management endpoints
    path('ads/', include(ad_urls)),
    # Delivery profiles management endpoints
    path('delivery-profiles/', include(delivery_profile_urls)),
    # JWT token endpoints
    path('token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    # Direct login endpoint
    path('login/', LoginView.as_view(), name='direct_login'),
    
]
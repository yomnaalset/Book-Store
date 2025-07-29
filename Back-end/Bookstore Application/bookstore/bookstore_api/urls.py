from django.urls import path, include
from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
)
from bookstore_api.urls.user_urls import user_urls
from bookstore_api.urls.library_urls import library_urls
from bookstore_api.urls.cart_urls import cart_urls
from bookstore_api.urls.payment_urls import payment_urls
from bookstore_api.views.user_views import LoginView    

urlpatterns = [
    # User management endpoints
    path('users/', include(user_urls)),
    # Library management endpoints  
    path('library/', include(library_urls)),
    # Cart management endpoints
    path('cart/', include(cart_urls)),
    # Payment management endpoints
    path('payment/', include(payment_urls)),
    # JWT token endpoints
    path('token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    # Direct login endpoint
    path('login/', LoginView.as_view(), name='direct_login'),
]
from django.urls import path, include

from .user_urls import user_urls
from .library_urls import library_urls
from .cart_urls import cart_urls
from .payment_urls import payment_urls
from .delivery_urls import urlpatterns as delivery_urls

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
]
    
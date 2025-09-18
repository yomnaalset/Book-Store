from django.urls import path, include

from .user_urls import user_urls
from .library_urls import library_urls
from .cart_urls import cart_urls
from .payment_urls import payment_urls
from .delivery_urls import urlpatterns as delivery_urls
from .notification_urls import urlpatterns as notification_urls
from .borrowing_urls import borrowing_urls
from .discount_urls import discount_urls
from .complaint_urls import complaint_urls
from .report_urls import report_urls
from .ad_urls import urlpatterns as ad_urls
from .user_preferences_urls import user_preferences_urls

urlpatterns = [
    # User management endpoints
    path('users/', include(user_urls)),
    # Library management endpoints (includes evaluation endpoints)
    path('library/', include(library_urls)),
    # Cart management endpoints
    path('cart/', include(cart_urls)),
    # Payment management endpoints
    path('payment/', include(payment_urls)),
    # Delivery management endpoints
    path('delivery/', include(delivery_urls)),
    # Notification endpoints
    path('notifications/', include(notification_urls)),
    # Borrowing management endpoints
    path('borrowing/', include(borrowing_urls)),
    # Discount management endpoints
    path('discounts/', include(discount_urls)),
    # Complaints management endpoints
    path('complaints/', include(complaint_urls)),
    # Reports management endpoints
    path('reports/', include(report_urls)),
    # Advertisement management endpoints
    path('ads/', include(ad_urls)),
    # User preferences endpoints (replaces manager settings)
    path('preferences/', include(user_preferences_urls)),
    ]   
    
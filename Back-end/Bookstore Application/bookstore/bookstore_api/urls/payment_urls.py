from django.urls import path
from bookstore_api.views.payment_views import (
    PaymentInitView, CreditCardPaymentView, CashOnDeliveryPaymentView
)

# Payment URLs configuration
payment_urls = [
    # Initialize payment
    path('init/', PaymentInitView.as_view(), name='payment_init'),
    # Process credit card payment
    path('<int:payment_id>/credit-card/', CreditCardPaymentView.as_view(), name='credit_card_payment'),
    # Process cash on delivery payment
    path('<int:payment_id>/cash-on-delivery/', CashOnDeliveryPaymentView.as_view(), name='cash_on_delivery_payment'),
]

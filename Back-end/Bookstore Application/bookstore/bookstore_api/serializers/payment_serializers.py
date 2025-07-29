from rest_framework import serializers
from ..models.payment_model import Payment, CreditCardPayment, CashOnDeliveryPayment
from ..models.user_model import User
from ..models.cart_model import Cart

class PaymentSerializer(serializers.ModelSerializer):
    """
    Serializer for payment information.
    """
    payment_method_display = serializers.CharField(
        source='get_payment_method_display',
        read_only=True
    )
    status_display = serializers.CharField(
        source='get_status_display',
        read_only=True
    )
    
    class Meta:
        model = Payment
        fields = [
            'id', 'user', 'amount', 'payment_method', 'payment_method_display',
            'status', 'status_display', 'transaction_id', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'user', 'transaction_id', 'created_at', 'updated_at', 'status']


class CreditCardPaymentSerializer(serializers.ModelSerializer):
    """
    Serializer for credit card payment details.
    """
    payment = PaymentSerializer(read_only=True)
    # For write operations, we need the full card number
    card_number = serializers.CharField(
        write_only=True,
        help_text="Full credit card number (will not be stored)"
    )
    cvv = serializers.CharField(
        write_only=True,
        help_text="CVV code (will not be stored)"
    )
    
    class Meta:
        model = CreditCardPayment
        fields = [
            'id', 'payment', 'card_holder_name', 'card_number_last_four',
         'expiry_month', 'expiry_year', 'card_number', 'cvv'
        ]
        read_only_fields = ['id', 'payment', 'card_number_last_four']


class CashOnDeliveryPaymentSerializer(serializers.ModelSerializer):
    """
    Serializer for cash on delivery payment details.
    """
    payment = PaymentSerializer(read_only=True)
    
    class Meta:
        model = CashOnDeliveryPayment
        fields = [
            'id', 'payment', 'delivery_address', 'contact_phone', 'notes'
        ]
        read_only_fields = ['id', 'payment']


class PaymentStatusUpdateSerializer(serializers.ModelSerializer):
    """
    Serializer for updating payment status.
    """
    class Meta:
        model = Payment
        fields = ['status']


class PaymentInitSerializer(serializers.Serializer):
    """
    Serializer for initializing a payment.
    """
    payment_method = serializers.ChoiceField(
        choices=Payment.PAYMENT_METHOD_CHOICES,
        help_text="Payment method to use"
    )


class CreditCardPaymentCreateSerializer(serializers.Serializer):
    """
    Serializer for creating a credit card payment.
    """
    card_holder_name = serializers.CharField(max_length=100)
    card_number = serializers.CharField(max_length=16)
    expiry_month = serializers.IntegerField(min_value=1, max_value=12)
    expiry_year = serializers.IntegerField(min_value=2000)
    cvv = serializers.CharField(max_length=4)


class CashOnDeliveryPaymentCreateSerializer(serializers.Serializer):
    """
    Serializer for creating a cash on delivery payment.
    """
    delivery_address = serializers.CharField(max_length=255)
    contact_phone = serializers.CharField(max_length=20)
    notes = serializers.CharField(max_length=255, required=False, allow_blank=True)


class PaymentBasicSerializer(serializers.ModelSerializer):
    """
    Basic payment information serializer for foreign key relationships.
    """
    payment_method_display = serializers.CharField(source='get_payment_method_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    
    class Meta:
        model = Payment
        fields = ['id', 'amount', 'payment_method', 'payment_method_display', 'status', 'status_display', 'created_at']
        read_only_fields = ['id', 'amount', 'payment_method', 'payment_method_display', 'status', 'status_display', 'created_at']


from django.db import transaction
from typing import Dict, Any, Optional, List
import logging
import uuid

from ..models import Payment, CreditCardPayment, CashOnDeliveryPayment, Cart, User

logger = logging.getLogger(__name__)

class PaymentService:
    """
    Service for managing payment operations.
    """
    
    @staticmethod
    def get_cart_total(user: User) -> Dict[str, Any]:
        """
        Get the total amount from the user's cart.
        """
        try:
            # Get user's cart
            try:
                cart = Cart.objects.get(user=user)
            except Cart.DoesNotExist:
                return {
                    'success': False,
                    'message': 'Cart not found',
                    'error_code': 'CART_NOT_FOUND'
                }
            
            # Calculate total amount
            total_amount = cart.get_total_price()
            
            return {
                'success': True,
                'message': 'Cart total retrieved successfully',
                'total_amount': total_amount,
                'cart': cart
            }
            
        except Exception as e:
            logger.error(f"Error getting cart total: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to get cart total: {str(e)}",
                'error_code': 'GET_CART_TOTAL_ERROR'
            }
    
    @staticmethod
    @transaction.atomic
    def initialize_payment(user: User, payment_method: str) -> Dict[str, Any]:
        """
        Initialize a payment based on the user's cart total.
        """
        try:
            # Get cart total
            cart_result = PaymentService.get_cart_total(user)
            if not cart_result['success']:
                return cart_result
            
            total_amount = cart_result['total_amount']
            cart = cart_result['cart']
            
            # Check if cart is empty
            if cart.get_item_count() == 0:
                return {
                    'success': False,
                    'message': 'Cannot create payment for an empty cart',
                    'error_code': 'EMPTY_CART'
                }
            
            # Create payment
            payment = Payment.objects.create(
                user=user,
                amount=total_amount,
                payment_method=payment_method,
                status='pending'
            )
            
            return {
                'success': True,
                'message': f'Payment initialized successfully with {payment.get_payment_method_display()}',
                'payment': payment,
                'cart': cart
            }
            
        except Exception as e:
            logger.error(f"Error initializing payment: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to initialize payment: {str(e)}",
                'error_code': 'INITIALIZE_PAYMENT_ERROR'
            }
    
    @staticmethod
    @transaction.atomic
    def process_credit_card_payment(payment: Payment, card_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Process a credit card payment.
        """
        try:
            # Check if payment method is credit card
            if payment.payment_method != 'credit_card':
                return {
                    'success': False,
                    'message': 'Payment method is not credit card',
                    'error_code': 'INVALID_PAYMENT_METHOD'
                }
            
            # Check if payment is already processed
            if payment.status != 'pending':
                return {
                    'success': False,
                    'message': f'Payment is already {payment.get_status_display()}',
                    'error_code': 'PAYMENT_ALREADY_PROCESSED'
                }
            
            # In a real system, you would call a payment gateway API here
            # For demo purposes, we'll simulate a successful payment
            
            # Generate a fake transaction ID
            transaction_id = str(uuid.uuid4())
            
            # Update payment status
            payment.status = 'completed'
            payment.transaction_id = transaction_id
            payment.save()
            
            # Save credit card details (last 4 digits only)
            card_number = card_data['card_number'].replace(' ', '').replace('-', '')
            card_type = PaymentService._detect_card_type(card_number)
            
            CreditCardPayment.objects.create(
                payment=payment,
                card_holder_name=card_data['card_holder_name'],
                card_number_last_four=card_number[-4:],
                card_type=card_type,
                expiry_month=card_data['expiry_month'],
                expiry_year=card_data['expiry_year']
            )
            
            return {
                'success': True,
                'message': 'Credit card payment processed successfully',
                'payment': payment,
                'transaction_id': transaction_id
            }
            
        except Exception as e:
            logger.error(f"Error processing credit card payment: {str(e)}")
            # Update payment status to failed
            payment.status = 'failed'
            payment.save()
            
            return {
                'success': False,
                'message': f"Failed to process credit card payment: {str(e)}",
                'error_code': 'PROCESS_CREDIT_CARD_ERROR'
            }
    
    @staticmethod
    @transaction.atomic
    def process_cash_on_delivery_payment(payment: Payment, delivery_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Process a cash on delivery payment.
        """
        try:
            # Check if payment method is cash on delivery
            if payment.payment_method != 'cash_on_delivery':
                return {
                    'success': False,
                    'message': 'Payment method is not cash on delivery',
                    'error_code': 'INVALID_PAYMENT_METHOD'
                }
            
            # Check if payment is already processed
            if payment.status != 'pending':
                return {
                    'success': False,
                    'message': f'Payment is already {payment.get_status_display()}',
                    'error_code': 'PAYMENT_ALREADY_PROCESSED'
                }
            
            # Update payment status
            payment.status = 'processing'  # For COD, payment is only completed after delivery
            payment.save()
            
            # Save cash on delivery details
            CashOnDeliveryPayment.objects.create(
                payment=payment,
                delivery_address=delivery_data['delivery_address'],
                contact_phone=delivery_data['contact_phone'],
                notes=delivery_data.get('notes', '')
            )
            
            return {
                'success': True,
                'message': 'Cash on delivery payment processed successfully',
                'payment': payment
            }
            
        except Exception as e:
            logger.error(f"Error processing cash on delivery payment: {str(e)}")
            # Update payment status to failed
            payment.status = 'failed'
            payment.save()
            
            return {
                'success': False,
                'message': f"Failed to process cash on delivery payment: {str(e)}",
                'error_code': 'PROCESS_CASH_ON_DELIVERY_ERROR'
            }
    
    @staticmethod
    @transaction.atomic
    def update_payment_status(payment: Payment, new_status: str) -> Dict[str, Any]:
        """
        Update the status of a payment.
        """
        try:
            # Check if status is valid
            if new_status not in dict(Payment.PAYMENT_STATUS_CHOICES):
                return {
                    'success': False,
                    'message': f'Invalid payment status: {new_status}',
                    'error_code': 'INVALID_PAYMENT_STATUS'
                }
            
            # Update payment status
            payment.status = new_status
            payment.save()
            
            return {
                'success': True,
                'message': f'Payment status updated to {payment.get_status_display()}',
                'payment': payment
            }
            
        except Exception as e:
            logger.error(f"Error updating payment status: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to update payment status: {str(e)}",
                'error_code': 'UPDATE_PAYMENT_STATUS_ERROR'
            }
    
    @staticmethod
    def get_payment_details(payment_id: int, user: User = None) -> Dict[str, Any]:
        """
        Get details of a specific payment.
        """
        try:
            # Get payment
            try:
                if user:
                    payment = Payment.objects.get(id=payment_id, user=user)
                else:
                    payment = Payment.objects.get(id=payment_id)
            except Payment.DoesNotExist:
                return {
                    'success': False,
                    'message': 'Payment not found',
                    'error_code': 'PAYMENT_NOT_FOUND'
                }
            
            return {
                'success': True,
                'message': 'Payment details retrieved successfully',
                'payment': payment
            }
            
        except Exception as e:
            logger.error(f"Error getting payment details: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to get payment details: {str(e)}",
                'error_code': 'GET_PAYMENT_DETAILS_ERROR'
            }
    
    @staticmethod
    def get_user_payments(user: User) -> Dict[str, Any]:
        """
        Get all payments for a user.
        """
        try:
            # Get payments
            payments = Payment.objects.filter(user=user).order_by('-created_at')
            
            return {
                'success': True,
                'message': 'User payments retrieved successfully',
                'payments': payments
            }
            
        except Exception as e:
            logger.error(f"Error getting user payments: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to get user payments: {str(e)}",
                'error_code': 'GET_USER_PAYMENTS_ERROR'
            }
    
    @staticmethod
    def _detect_card_type(card_number: str) -> str:
        """
        Detect the type of credit card based on the card number.
        """
        # Remove spaces and dashes
        card_number = card_number.replace(' ', '').replace('-', '')
        
        # Visa: Starts with 4
        if card_number.startswith('4'):
            return 'Visa'
        
        # Mastercard: Starts with 51-55 or 2221-2720
        if card_number.startswith(('51', '52', '53', '54', '55')) or \
           (2221 <= int(card_number[:4]) <= 2720):
            return 'MasterCard'
        
        # American Express: Starts with 34 or 37
        if card_number.startswith(('34', '37')):
            return 'American Express'
        
        # Discover: Starts with 6011, 622126-622925, 644-649, or 65
        if card_number.startswith('6011') or \
           (622126 <= int(card_number[:6]) <= 622925) or \
           card_number.startswith(('644', '645', '646', '647', '648', '649', '65')):
            return 'Discover'
        
        # Default
        return 'Unknown'



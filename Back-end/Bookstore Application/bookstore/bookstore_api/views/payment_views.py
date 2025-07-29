from rest_framework import status, permissions
from rest_framework.views import APIView
from rest_framework.response import Response
import logging

from ..models import Payment
from ..serializers import (
    PaymentSerializer, CreditCardPaymentSerializer, CashOnDeliveryPaymentSerializer,
    PaymentInitSerializer, CreditCardPaymentCreateSerializer,
    CashOnDeliveryPaymentCreateSerializer, PaymentStatusUpdateSerializer
)
from ..services.payment_services import PaymentService
from ..utils import format_error_message

logger = logging.getLogger(__name__)

class PaymentInitView(APIView):
    """
    Initialize a payment based on the user's cart total.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        try:
            # Validate request data
            serializer = PaymentInitSerializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            
            # Get payment method
            payment_method = serializer.validated_data['payment_method']
            
            # Initialize payment
            result = PaymentService.initialize_payment(
                user=request.user,
                payment_method=payment_method
            )
            
            if result['success']:
                # Return payment data
                payment_serializer = PaymentSerializer(result['payment'])
                
                return Response({
                    'success': True,
                    'message': result['message'],
                    'data': payment_serializer.data
                }, status=status.HTTP_200_OK)
            else:
                return Response({
                    'success': False,
                    'message': result['message'],
                    'error_code': result.get('error_code')
                }, status=status.HTTP_400_BAD_REQUEST)
            
        except Exception as e:
            logger.error(f"Error initializing payment: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to initialize payment',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class CreditCardPaymentView(APIView):
    """
    Process a credit card payment.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request, payment_id):
        try:
            # Validate request data
            serializer = CreditCardPaymentCreateSerializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            
            # Get payment
            payment_result = PaymentService.get_payment_details(
                payment_id=payment_id,
                user=request.user
            )
            
            if not payment_result['success']:
                return Response({
                    'success': False,
                    'message': payment_result['message'],
                    'error_code': payment_result.get('error_code')
                }, status=status.HTTP_404_NOT_FOUND)
            
            payment = payment_result['payment']
            
            # Process credit card payment
            result = PaymentService.process_credit_card_payment(
                payment=payment,
                card_data=serializer.validated_data
            )
            
            if result['success']:
                # Return payment data
                payment_serializer = PaymentSerializer(result['payment'])
                
                return Response({
                    'success': True,
                    'message': result['message'],
                    'data': {
                        'payment': payment_serializer.data,
                        'transaction_id': result['transaction_id']
                    }
                }, status=status.HTTP_200_OK)
            else:
                return Response({
                    'success': False,
                    'message': result['message'],
                    'error_code': result.get('error_code')
                }, status=status.HTTP_400_BAD_REQUEST)
            
        except Exception as e:
            logger.error(f"Error processing credit card payment: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to process credit card payment',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class CashOnDeliveryPaymentView(APIView):
    """
    Process a cash on delivery payment.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request, payment_id):
        try:
            # Validate request data
            serializer = CashOnDeliveryPaymentCreateSerializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            
            # Get payment
            payment_result = PaymentService.get_payment_details(
                payment_id=payment_id,
                user=request.user
            )
            
            if not payment_result['success']:
                return Response({
                    'success': False,
                    'message': payment_result['message'],
                    'error_code': payment_result.get('error_code')
                }, status=status.HTTP_404_NOT_FOUND)
            
            payment = payment_result['payment']
            
            # Process cash on delivery payment
            result = PaymentService.process_cash_on_delivery_payment(
                payment=payment,
                delivery_data=serializer.validated_data
            )
            
            if result['success']:
                # Return payment data
                payment_serializer = PaymentSerializer(result['payment'])
                
                return Response({
                    'success': True,
                    'message': result['message'],
                    'data': payment_serializer.data
                }, status=status.HTTP_200_OK)
            else:
                return Response({
                    'success': False,
                    'message': result['message'],
                    'error_code': result.get('error_code')
                }, status=status.HTTP_400_BAD_REQUEST)
            
        except Exception as e:
            logger.error(f"Error processing cash on delivery payment: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to process cash on delivery payment',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

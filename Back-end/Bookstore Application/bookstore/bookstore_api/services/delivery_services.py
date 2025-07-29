from django.db import transaction, models
from django.utils import timezone
from django.core.exceptions import ValidationError
from typing import Dict, Any, List, Optional
import logging
from datetime import datetime, timedelta

from ..models import Order, OrderItem, DeliveryAssignment, DeliveryStatusHistory, User, Payment, Cart, CartItem, Book

logger = logging.getLogger(__name__)


class OrderService:
    """
    Service for managing order operations.
    """
    
    @staticmethod
    @transaction.atomic
    def create_order_from_payment(payment: Payment, delivery_data: Dict[str, Any] = None) -> Dict[str, Any]:
        """
        Create an order from a completed payment.
        """
        try:
            # Validate payment
            if payment.status != 'completed':
                return {
                    'success': False,
                    'message': 'Payment must be completed to create order',
                    'error_code': 'PAYMENT_NOT_COMPLETED'
                }
            
            # Check if order already exists
            if hasattr(payment, 'order'):
                return {
                    'success': False,
                    'message': 'Order already exists for this payment',
                    'error_code': 'ORDER_ALREADY_EXISTS'
                }
            
            # Get user's cart
            try:
                cart = payment.user.cart
            except Cart.DoesNotExist:
                return {
                    'success': False,
                    'message': 'User cart not found',
                    'error_code': 'CART_NOT_FOUND'
                }
            
            # Check if cart has items
            if cart.get_item_count() == 0:
                return {
                    'success': False,
                    'message': 'Cannot create order from empty cart',
                    'error_code': 'EMPTY_CART'
                }
            
            # Prepare delivery information
            delivery_info = {}
            if hasattr(payment, 'cash_on_delivery_details'):
                cod_details = payment.cash_on_delivery_details
                delivery_info = {
                    'delivery_address': cod_details.delivery_address,
                    'contact_phone': cod_details.contact_phone,
                    'delivery_notes': cod_details.notes or ''
                }
            
            # Override with provided delivery data
            if delivery_data:
                delivery_info.update(delivery_data)
            
            # Create order
            order = Order.objects.create(
                customer=payment.user,
                payment=payment,
                total_amount=payment.amount,
                **delivery_info
            )
            
            # Create order items from cart
            for cart_item in cart.items.all():
                OrderItem.objects.create(
                    order=order,
                    book=cart_item.book,
                    book_name=cart_item.book.title,
                    book_price=cart_item.book.price,
                    quantity=cart_item.quantity
                )
            
            # Clear cart after order creation
            cart.clear()
            
            return {
                'success': True,
                'message': 'Order created successfully',
                'order': order
            }
            
        except Exception as e:
            logger.error(f"Error creating order from payment: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to create order: {str(e)}",
                'error_code': 'ORDER_CREATION_ERROR'
            }
    
    @staticmethod
    def get_orders_by_status(status: str = None, customer: User = None) -> Dict[str, Any]:
        """
        Get orders filtered by status and/or customer.
        """
        try:
            queryset = Order.objects.select_related('customer', 'payment').prefetch_related('items__book')
            
            if status:
                queryset = queryset.filter(status=status)
            
            if customer:
                queryset = queryset.filter(customer=customer)
            
            orders = queryset.order_by('-created_at')
            
            return {
                'success': True,
                'orders': orders,
                'total_count': orders.count()
            }
            
        except Exception as e:
            logger.error(f"Error getting orders by status: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to get orders: {str(e)}",
                'error_code': 'GET_ORDERS_ERROR'
            }
    
    @staticmethod
    @transaction.atomic
    def update_order_status(order: Order, new_status: str, updated_by: User, notes: str = None) -> Dict[str, Any]:
        """
        Update order status with validation and timestamps.
        """
        try:
            old_status = order.status
            
            # Validate status transition
            valid_transitions = {
                'pending': ['confirmed', 'cancelled'],
                'confirmed': ['delivered'],
                'delivered': [],  # Final state
            }
            
            if new_status not in valid_transitions.get(old_status, []):
                return {
                    'success': False,
                    'message': f"Cannot change status from '{old_status}' to '{new_status}'",
                    'error_code': 'INVALID_STATUS_TRANSITION'
                }
            
            # Update order status
            order.status = new_status
            
            # Set special timestamps
            if new_status == 'confirmed':
                order.confirmed_at = timezone.now()
            elif new_status == 'delivered':
                order.delivered_at = timezone.now()
                # Also update payment status for COD
                if order.payment.payment_method == 'cash_on_delivery':
                    order.payment.status = 'completed'
                    order.payment.save()
            
            order.save()
            
            return {
                'success': True,
                'message': f'Order status updated from {old_status} to {new_status}',
                'order': order,
                'old_status': old_status,
                'new_status': new_status
            }
            
        except Exception as e:
            logger.error(f"Error updating order status: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to update order status: {str(e)}",
                'error_code': 'UPDATE_ORDER_STATUS_ERROR'
            }
    
    @staticmethod
    def get_order_statistics() -> Dict[str, Any]:
        """
        Get order statistics for dashboard.
        """
        try:
            total_orders = Order.objects.count()
            pending_orders = Order.objects.filter(status='pending').count()
            confirmed_orders = Order.objects.filter(status='confirmed').count()
            delivered_orders = Order.objects.filter(status='delivered').count()
            
            # Today's orders
            today = timezone.now().date()
            today_orders = Order.objects.filter(created_at__date=today).count()
            
            # Revenue stats
            total_revenue = Order.objects.filter(status='delivered').aggregate(
                total=models.Sum('total_amount')
            )['total'] or 0
            
            today_revenue = Order.objects.filter(
                created_at__date=today,
                status='delivered'
            ).aggregate(total=models.Sum('total_amount'))['total'] or 0
            
            return {
                'success': True,
                'statistics': {
                    'total_orders': total_orders,
                    'pending_orders': pending_orders,
                    'confirmed_orders': confirmed_orders,
                    'delivered_orders': delivered_orders,
                    'today_orders': today_orders,
                    'total_revenue': float(total_revenue),
                    'today_revenue': float(today_revenue)
                }
            }
            
        except Exception as e:
            logger.error(f"Error getting order statistics: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to get order statistics: {str(e)}",
                'error_code': 'GET_ORDER_STATS_ERROR'
            }


class DeliveryService:
    """
    Service for managing delivery assignments and tracking.
    """
    
    @staticmethod
    @transaction.atomic
    def assign_order_for_delivery(order: Order, delivery_manager: User, estimated_delivery_time: datetime = None, notes: str = None) -> Dict[str, Any]:
        """
        Assign an order to a delivery manager.
        """
        try:
            # Validate order status
            if order.status != 'ready_for_delivery':
                return {
                    'success': False,
                    'message': 'Order must be in ready_for_delivery status',
                    'error_code': 'INVALID_ORDER_STATUS'
                }
            
            # Check if already assigned
            if hasattr(order, 'delivery_assignment'):
                return {
                    'success': False,
                    'message': 'Order already has a delivery assignment',
                    'error_code': 'ALREADY_ASSIGNED'
                }
            
            # Validate delivery manager
            if not delivery_manager.is_delivery_admin():
                return {
                    'success': False,
                    'message': 'User must be a delivery administrator',
                    'error_code': 'INVALID_DELIVERY_MANAGER'
                }
            
            if not delivery_manager.is_active:
                return {
                    'success': False,
                    'message': 'Delivery manager account is not active',
                    'error_code': 'INACTIVE_DELIVERY_MANAGER'
                }
            
            # Create delivery assignment
            assignment = DeliveryAssignment.objects.create(
                order=order,
                delivery_manager=delivery_manager,
                estimated_delivery_time=estimated_delivery_time,
                delivery_notes=notes or ''
            )
            
            # Update order status
            order.status = 'assigned_to_delivery'
            order.save()
            
            return {
                'success': True,
                'message': f'Order assigned to {delivery_manager.get_full_name()}',
                'assignment': assignment
            }
            
        except Exception as e:
            logger.error(f"Error assigning order for delivery: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to assign order: {str(e)}",
                'error_code': 'ASSIGNMENT_ERROR'
            }
    
    @staticmethod
    @transaction.atomic
    def update_delivery_status(assignment: DeliveryAssignment, new_status: str, updated_by: User, notes: str = None, failure_reason: str = None) -> Dict[str, Any]:
        """
        Update delivery assignment status with validation and history tracking.
        """
        try:
            old_status = assignment.status
            
            # Validate status transition
            valid_transitions = {
                'assigned': ['accepted', 'failed'],
                'accepted': ['picked_up', 'failed'],
                'picked_up': ['in_transit', 'failed'],
                'in_transit': ['delivered', 'failed'],
                'delivered': [],  # Final state
                'failed': ['assigned'],  # Can be reassigned
                'returned': [],   # Final state
            }
            
            if new_status not in valid_transitions.get(old_status, []):
                return {
                    'success': False,
                    'message': f"Cannot change status from '{old_status}' to '{new_status}'",
                    'error_code': 'INVALID_STATUS_TRANSITION'
                }
            
            # Validate failure reason for failed status
            if new_status == 'failed' and not failure_reason:
                return {
                    'success': False,
                    'message': 'Failure reason is required when marking as failed',
                    'error_code': 'FAILURE_REASON_REQUIRED'
                }
            
            # Update assignment status and timestamps
            assignment.status = new_status
            
            if new_status == 'accepted':
                assignment.accepted_at = timezone.now()
            elif new_status == 'picked_up':
                assignment.picked_up_at = timezone.now()
            elif new_status == 'delivered':
                assignment.delivered_at = timezone.now()
                assignment.actual_delivery_time = timezone.now()
                # Update order status
                assignment.order.status = 'delivered'
                assignment.order.delivered_at = timezone.now()
                assignment.order.save()
                # Update payment status for COD
                if assignment.order.payment.payment_method == 'cash_on_delivery':
                    assignment.order.payment.status = 'completed'
                    assignment.order.payment.save()
            elif new_status == 'failed':
                assignment.failure_reason = failure_reason
                assignment.retry_count += 1
                # Update order status back to ready_for_delivery
                assignment.order.status = 'ready_for_delivery'
                assignment.order.save()
            
            if notes:
                assignment.delivery_notes = notes
            
            assignment.save()
            
            # Create status history
            DeliveryStatusHistory.objects.create(
                assignment=assignment,
                previous_status=old_status,
                new_status=new_status,
                updated_by=updated_by,
                notes=notes or ''
            )
            
            # Update order status based on delivery status
            if new_status == 'in_transit':
                assignment.order.status = 'out_for_delivery'
                assignment.order.save()
            
            return {
                'success': True,
                'message': f'Delivery status updated from {old_status} to {new_status}',
                'assignment': assignment,
                'old_status': old_status,
                'new_status': new_status
            }
            
        except Exception as e:
            logger.error(f"Error updating delivery status: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to update delivery status: {str(e)}",
                'error_code': 'UPDATE_DELIVERY_STATUS_ERROR'
            }
    
    @staticmethod
    def get_delivery_assignments(delivery_manager: User = None, status: str = None) -> Dict[str, Any]:
        """
        Get delivery assignments filtered by manager and/or status.
        """
        try:
            queryset = DeliveryAssignment.objects.select_related(
                'order__customer', 'order__payment', 'delivery_manager'
            ).prefetch_related('order__items__book')
            
            if delivery_manager:
                if not delivery_manager.is_delivery_admin():
                    return {
                        'success': False,
                        'message': 'User must be a delivery administrator',
                        'error_code': 'INVALID_DELIVERY_MANAGER'
                    }
                queryset = queryset.filter(delivery_manager=delivery_manager)
            
            if status:
                queryset = queryset.filter(status=status)
            
            assignments = queryset.order_by('-assigned_at')
            
            return {
                'success': True,
                'assignments': assignments,
                'total_count': assignments.count()
            }
            
        except Exception as e:
            logger.error(f"Error getting delivery assignments: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to get delivery assignments: {str(e)}",
                'error_code': 'GET_ASSIGNMENTS_ERROR'
            }
    
    @staticmethod
    def get_available_delivery_managers() -> Dict[str, Any]:
        """
        Get list of active delivery managers with their current workload.
        """
        try:
            delivery_managers = User.objects.filter(
                user_type='delivery_admin',
                is_active=True
            ).annotate(
                active_assignments=models.Count(
                    'delivery_assignments',
                    filter=models.Q(delivery_assignments__status__in=['assigned', 'accepted', 'picked_up', 'in_transit'])
                )
            ).order_by('active_assignments', 'first_name')
            
            return {
                'success': True,
                'delivery_managers': delivery_managers
            }
            
        except Exception as e:
            logger.error(f"Error getting delivery managers: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to get delivery managers: {str(e)}",
                'error_code': 'GET_DELIVERY_MANAGERS_ERROR'
            }
    
    @staticmethod
    def get_delivery_manager_statistics(delivery_manager: User, days: int = 30) -> Dict[str, Any]:
        """
        Get statistics for a specific delivery manager.
        """
        try:
            if not delivery_manager.is_delivery_admin():
                return {
                    'success': False,
                    'message': 'User must be a delivery administrator',
                    'error_code': 'INVALID_DELIVERY_MANAGER'
                }
            
            # Date range
            end_date = timezone.now()
            start_date = end_date - timedelta(days=days)
            
            # Get assignments in date range
            assignments = DeliveryAssignment.objects.filter(
                delivery_manager=delivery_manager,
                assigned_at__gte=start_date
            )
            
            total_assignments = assignments.count()
            completed_deliveries = assignments.filter(status='delivered').count()
            failed_deliveries = assignments.filter(status='failed').count()
            pending_assignments = assignments.filter(
                status__in=['assigned', 'accepted', 'picked_up', 'in_transit']
            ).count()
            
            # Calculate success rate
            success_rate = 0
            if total_assignments > 0:
                success_rate = (completed_deliveries / total_assignments) * 100
            
            # Calculate average delivery time
            completed_assignments = assignments.filter(
                status='delivered',
                picked_up_at__isnull=False,
                delivered_at__isnull=False
            )
            
            average_delivery_time = 0
            if completed_assignments.exists():
                delivery_times = []
                for assignment in completed_assignments:
                    duration = assignment.delivered_at - assignment.picked_up_at
                    delivery_times.append(duration.total_seconds() / 60)  # Convert to minutes
                
                if delivery_times:
                    average_delivery_time = sum(delivery_times) / len(delivery_times)
            
            return {
                'success': True,
                'statistics': {
                    'total_assignments': total_assignments,
                    'completed_deliveries': completed_deliveries,
                    'pending_assignments': pending_assignments,
                    'failed_deliveries': failed_deliveries,
                    'success_rate': round(success_rate, 2),
                    'average_delivery_time': round(average_delivery_time, 2),  # in minutes
                    'period_days': days
                }
            }
            
        except Exception as e:
            logger.error(f"Error getting delivery manager statistics: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to get delivery statistics: {str(e)}",
                'error_code': 'GET_DELIVERY_STATS_ERROR'
            }
    
    @staticmethod
    def get_delivery_dashboard_stats() -> Dict[str, Any]:
        """
        Get delivery dashboard statistics.
        """
        try:
            # Assignment counts by status
            total_assignments = DeliveryAssignment.objects.count()
            assigned_count = DeliveryAssignment.objects.filter(status='assigned').count()
            in_progress_count = DeliveryAssignment.objects.filter(
                status__in=['accepted', 'picked_up', 'in_transit']
            ).count()
            delivered_count = DeliveryAssignment.objects.filter(status='delivered').count()
            failed_count = DeliveryAssignment.objects.filter(status='failed').count()
            
            # Today's deliveries
            today = timezone.now().date()
            today_deliveries = DeliveryAssignment.objects.filter(
                delivered_at__date=today
            ).count()
            
            # Orders ready for delivery
            orders_ready = Order.objects.filter(status='ready_for_delivery').count()
            
            # Active delivery managers
            active_managers = User.objects.filter(
                user_type='delivery_admin',
                is_active=True
            ).count()
            
            return {
                'success': True,
                'statistics': {
                    'total_assignments': total_assignments,
                    'assigned_count': assigned_count,
                    'in_progress_count': in_progress_count,
                    'delivered_count': delivered_count,
                    'failed_count': failed_count,
                    'today_deliveries': today_deliveries,
                    'orders_ready': orders_ready,
                    'active_managers': active_managers
                }
            }
            
        except Exception as e:
            logger.error(f"Error getting delivery dashboard stats: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to get delivery dashboard stats: {str(e)}",
                'error_code': 'GET_DELIVERY_DASHBOARD_STATS_ERROR'
            } 
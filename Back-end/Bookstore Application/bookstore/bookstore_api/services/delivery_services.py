from django.db import transaction, models
from django.utils import timezone
from django.core.exceptions import ValidationError
from typing import Dict, Any, List, Optional
import logging
from datetime import datetime, timedelta
from decimal import Decimal

from ..models import (
    Order, OrderItem, DeliveryAssignment, DeliveryStatusHistory, 
    User, Payment, Cart, CartItem, Book, BorrowRequest
)


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
            
            # Get discount information from payment if available
            discount_info = {}
            if payment.discount_code_used:
                discount_info = {
                    'original_amount': payment.original_amount or payment.amount,
                    'discount_code': payment.discount_code_used,
                    'discount_amount': payment.discount_amount,
                    'discount_percentage': payment.discount_percentage,
                }
            
            # Calculate delivery cost from payment if available, otherwise calculate from cart
            delivery_cost = payment.delivery_cost if hasattr(payment, 'delivery_cost') and payment.delivery_cost else Decimal('0.00')
            if delivery_cost == 0:
                # Calculate delivery cost from cart
                TAX_RATE = Decimal('0.08')  # 8% tax rate
                DELIVERY_RATE = Decimal('0.04')  # 4% delivery cost rate
                
                subtotal = cart.get_total_price()
                tax_amount = subtotal * TAX_RATE
                discount_amount = payment.discount_amount if payment.discount_amount else Decimal('0.00')
                final_invoice_value = subtotal + tax_amount - discount_amount
                delivery_cost = final_invoice_value * DELIVERY_RATE
            
            # Create order
            order = Order.objects.create(
                customer=payment.user,
                payment=payment,
                total_amount=payment.amount,
                delivery_cost=delivery_cost,
                **discount_info,
                **delivery_info
            )
            
            # Create order items from cart
            for cart_item in cart.items.all():
                OrderItem.objects.create(
                    order=order,
                    book=cart_item.book,
                    quantity=cart_item.quantity,
                    unit_price=cart_item.book.price,
                    total_price=cart_item.book.price * cart_item.quantity
                )
            
            # Clear cart after order creation
            cart.clear()
            
            # Create delivery request for the order
            try:
                from ..models.delivery_model import DeliveryRequest
                from django.utils import timezone
                from datetime import timedelta
                
                # Calculate preferred delivery time (24 hours from now)
                preferred_delivery_time = timezone.now() + timedelta(hours=24)
                
                delivery_request = DeliveryRequest.objects.create(
                    customer=payment.user,
                    order=order,
                    request_type='delivery',
                    delivery_address=delivery_info.get('delivery_address', ''),
                    delivery_city=delivery_info.get('delivery_city', 'Unknown'),
                    preferred_pickup_time=timezone.now() + timedelta(hours=1),  # 1 hour from now
                    preferred_delivery_time=preferred_delivery_time,
                    status='pending',
                    notes=f'Delivery request for order #{order.order_number}'
                )
                
                logger.info(f"Created delivery request {delivery_request.id} for order {order.id}")
                
            except Exception as e:
                logger.error(f"Failed to create delivery request for order {order.id}: {str(e)}")
                # Don't fail the order creation if delivery request creation fails
                pass
            
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
            
            # Get delivery manager's phone number from profile
            contact_phone = None
            try:
                if hasattr(delivery_manager, 'profile') and delivery_manager.profile.phone_number:
                    contact_phone = delivery_manager.profile.phone_number
            except Exception as e:
                logger.error(f"Failed to get delivery manager's phone number: {str(e)}")
            
            # Create delivery assignment
            assignment = DeliveryAssignment.objects.create(
                order=order,
                delivery_manager=delivery_manager,
                estimated_delivery_time=estimated_delivery_time,
                delivery_notes=notes or '',
                contact_phone=contact_phone
            )
            
            # Update order status
            order.status = 'assigned_to_delivery'
            order.save()
            
            # Create notification for delivery manager
            try:
                from ..services.notification_services import NotificationService
                NotificationService.create_notification(
                    user_id=delivery_manager.id,
                    title="New Delivery Assigned",
                    message=f"You have been assigned to deliver order #{order.order_number} to {order.customer.get_full_name()}. Delivery address: {order.delivery_address}",
                    notification_type="delivery_assigned",
                    related_order_id=order.id
                )
            except Exception as e:
                logger.error(f"Failed to create notification for delivery assignment: {str(e)}")
            
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
            
            # Allow any status change - no validation restrictions
            # This gives maximum flexibility to delivery managers
            
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
            elif new_status == 'in_transit':
                assignment.started_at = timezone.now()
                # Automatically change delivery manager status to busy when starting delivery
                try:
                    from ..services.delivery_profile_services import DeliveryProfileService
                    DeliveryProfileService.start_delivery_task(assignment.delivery_manager)
                except Exception as e:
                    logger.warning(f"Failed to update delivery manager status to busy: {str(e)}")
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
                # Automatically change delivery manager status to online when completing delivery
                try:
                    from ..services.delivery_profile_services import DeliveryProfileService
                    DeliveryProfileService.complete_delivery_task(
                        assignment.delivery_manager,
                        completed_order_id=assignment.order.id
                    )
                except Exception as e:
                    logger.warning(f"Failed to update delivery manager status to online: {str(e)}")
            elif new_status == 'completed':
                assignment.completed_at = timezone.now()
                # Update order status to completed
                assignment.order.status = 'delivered'  # Keep order as delivered, completion is for delivery assignment
                assignment.order.save()
                # Automatically change delivery manager status to online when completing delivery
                try:
                    from ..services.delivery_profile_services import DeliveryProfileService
                    DeliveryProfileService.complete_delivery_task(
                        assignment.delivery_manager,
                        completed_order_id=assignment.order.id
                    )
                except Exception as e:
                    logger.warning(f"Failed to update delivery manager status to online: {str(e)}")
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
                delivery_assignment=assignment,
                status=new_status,
                notes=notes or ''
            )
            
            # Update order status based on delivery status
            if new_status == 'in_transit':
                assignment.order.status = 'in_delivery'
                assignment.order.save()
            
            # Create notifications for important status changes
            try:
                from ..services.notification_services import NotificationService
                
                # Notify delivery manager about status updates (if updated by admin/system)
                if updated_by != assignment.delivery_manager:
                    status_messages = {
                        'accepted': f"Your delivery assignment for order #{assignment.order.order_number} has been accepted.",
                        'picked_up': f"Order #{assignment.order.order_number} has been marked as picked up.",
                        'in_transit': f"Delivery for order #{assignment.order.order_number} is now in transit.",
                        'delivered': f"Order #{assignment.order.order_number} has been delivered successfully.",
                        'completed': f"Delivery assignment for order #{assignment.order.order_number} has been completed.",
                        'failed': f"Delivery for order #{assignment.order.order_number} has been marked as failed. Reason: {failure_reason or 'Not specified'}",
                    }
                    
                    if new_status in status_messages:
                        NotificationService.create_notification(
                            user_id=assignment.delivery_manager.id,
                            title=f"Delivery Status Update: {new_status.title()}",
                            message=status_messages[new_status],
                            notification_type="delivery_status_update",
                            related_order_id=assignment.order.id
                        )
            except Exception as e:
                logger.error(f"Failed to create notification for delivery status update: {str(e)}")
            
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
            
            # Stats functionality removed
            return {
                'success': True,
                'statistics': {
                    'message': 'Delivery manager statistics functionality has been removed',
                    'total_assignments': 0,
                    'completed_deliveries': 0,
                    'pending_assignments': 0,
                    'failed_deliveries': 0,
                    'success_rate': 0,
                    'average_delivery_time': 0,
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
            # Stats functionality removed
            return {
                'success': True,
                'statistics': {
                    'message': 'Delivery dashboard statistics functionality has been removed',
                    'total_assignments': 0,
                    'assigned_count': 0,
                    'in_progress_count': 0,
                    'delivered_count': 0,
                    'failed_count': 0,
                    'today_deliveries': 0,
                    'orders_ready': 0,
                    'active_managers': 0
                }
            }
            
        except Exception as e:
            logger.error(f"Error getting delivery dashboard stats: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to get delivery dashboard stats: {str(e)}",
                'error_code': 'GET_DELIVERY_DASHBOARD_STATS_ERROR'
            }
    
    @staticmethod
    def update_delivery_manager_location(delivery_manager: User, latitude: float = None, longitude: float = None, address: str = None) -> Dict[str, Any]:
        """
        Update delivery manager's location.
        """
        try:
            if not delivery_manager.is_delivery_admin():
                return {
                    'success': False,
                    'message': 'User must be a delivery administrator',
                    'error_code': 'INVALID_DELIVERY_MANAGER'
                }
            
            # Validate coordinates if provided
            if latitude is not None and not (-90 <= latitude <= 90):
                return {
                    'success': False,
                    'message': 'Latitude must be between -90 and 90',
                    'error_code': 'INVALID_LATITUDE'
                }
            
            if longitude is not None and not (-180 <= longitude <= 180):
                return {
                    'success': False,
                    'message': 'Longitude must be between -180 and 180',
                    'error_code': 'INVALID_LONGITUDE'
                }
            
            # Update location
            delivery_manager.update_location(
                latitude=latitude,
                longitude=longitude,
                address=address
            )
            
            return {
                'success': True,
                'message': 'Location updated successfully',
                'location': delivery_manager.get_location_dict()
            }
            
        except Exception as e:
            logger.error(f"Error updating delivery manager location: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to update location: {str(e)}",
                'error_code': 'UPDATE_LOCATION_ERROR'
            }
    
    @staticmethod
    def get_delivery_manager_location(delivery_manager: User) -> Dict[str, Any]:
        """
        Get delivery manager's location.
        """
        try:
            if not delivery_manager.is_delivery_admin():
                return {
                    'success': False,
                    'message': 'User must be a delivery administrator',
                    'error_code': 'INVALID_DELIVERY_MANAGER'
                }
            
            return {
                'success': True,
                'location': delivery_manager.get_location_dict()
            }
            
        except Exception as e:
            logger.error(f"Error getting delivery manager location: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to get location: {str(e)}",
                'error_code': 'GET_LOCATION_ERROR'
            }
    
    @staticmethod
    def get_delivery_managers_with_locations() -> Dict[str, Any]:
        """
        Get all delivery managers with their location data.
        """
        try:
            delivery_managers = User.objects.filter(
                user_type='delivery_admin',
                is_active=True
            ).exclude(
                latitude__isnull=True,
                longitude__isnull=True,
                address__isnull=True
            ).exclude(
                latitude='',
                longitude='',
                address=''
            )
            
            managers_data = []
            for manager in delivery_managers:
                managers_data.append({
                    'id': manager.id,
                    'name': manager.get_full_name(),
                    'email': manager.email,
                    'location': manager.get_location_dict()
                })
            
            return {
                'success': True,
                'delivery_managers': managers_data,
                'total_count': len(managers_data)
            }
            
        except Exception as e:
            logger.error(f"Error getting delivery managers with locations: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to get delivery managers: {str(e)}",
                'error_code': 'GET_DELIVERY_MANAGERS_ERROR'
            }


class LocationTrackingService:
    """
    Service for managing real-time location tracking and history.
    """
    
    @staticmethod
    def start_real_time_tracking(delivery_manager: User, interval_seconds: int = 30) -> Dict[str, Any]:
        """
        Start real-time location tracking for a delivery manager.
        """
        try:
            if not delivery_manager.is_delivery_admin():
                return {
                    'success': False,
                    'message': 'Only delivery managers can start real-time tracking',
                    'error_code': 'INVALID_USER_TYPE'
                }
            
            # Start tracking
            success, message = delivery_manager.start_real_time_tracking(interval_seconds)
            
            if success:
                # Create or update RealTimeTracking record
                from ..models.delivery_model import RealTimeTracking
                tracking, created = RealTimeTracking.objects.get_or_create(
                    delivery_manager=delivery_manager,
                    defaults={
                        'is_tracking_enabled': True,
                        'tracking_interval': interval_seconds,
                    }
                )
                
                if not created:
                    tracking.is_tracking_enabled = True
                    tracking.tracking_interval = interval_seconds
                    tracking.save()
                
                return {
                    'success': True,
                    'message': 'Real-time tracking started successfully',
                    'tracking_settings': {
                        'is_tracking_enabled': True,
                        'tracking_interval': interval_seconds,
                        'delivery_manager_id': delivery_manager.id
                    }
                }
            else:
                return {
                    'success': False,
                    'message': message,
                    'error_code': 'TRACKING_START_FAILED'
                }
                
        except Exception as e:
            logger.error(f"Error starting real-time tracking: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to start tracking: {str(e)}",
                'error_code': 'TRACKING_START_ERROR'
            }
    
    @staticmethod
    def stop_real_time_tracking(delivery_manager: User) -> Dict[str, Any]:
        """
        Stop real-time location tracking for a delivery manager.
        """
        try:
            if not delivery_manager.is_delivery_admin():
                return {
                    'success': False,
                    'message': 'Only delivery managers can stop real-time tracking',
                    'error_code': 'INVALID_USER_TYPE'
                }
            
            # Stop tracking
            success, message = delivery_manager.stop_real_time_tracking()
            
            if success:
                # Update RealTimeTracking record
                from ..models.delivery_model import RealTimeTracking
                try:
                    tracking = RealTimeTracking.objects.get(delivery_manager=delivery_manager)
                    tracking.is_tracking_enabled = False
                    tracking.is_delivering = False
                    tracking.current_delivery_assignment = None
                    tracking.save()
                except RealTimeTracking.DoesNotExist:
                    pass  # No tracking record exists
                
                return {
                    'success': True,
                    'message': 'Real-time tracking stopped successfully'
                }
            else:
                return {
                    'success': False,
                    'message': message,
                    'error_code': 'TRACKING_STOP_FAILED'
                }
                
        except Exception as e:
            logger.error(f"Error stopping real-time tracking: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to stop tracking: {str(e)}",
                'error_code': 'TRACKING_STOP_ERROR'
            }
    
    @staticmethod
    def update_location_with_tracking(
        delivery_manager: User,
        latitude: float,
        longitude: float,
        address: str = None,
        tracking_type: str = 'gps',
        accuracy: float = None,
        speed: float = None,
        heading: float = None,
        battery_level: int = None,
        network_type: str = None,
        delivery_assignment_id: int = None,
        borrow_request_id: int = None
    ) -> Dict[str, Any]:
        """
        Step 3.3: Update location with real-time tracking data.
        Called every 5 seconds when delivery is active.
        """
        try:
            if not delivery_manager.is_delivery_admin():
                return {
                    'success': False,
                    'message': 'Only delivery managers can update tracking location',
                    'error_code': 'INVALID_USER_TYPE'
                }
            
            # Get delivery assignment if provided
            delivery_assignment = None
            if delivery_assignment_id:
                from ..models.delivery_model import DeliveryAssignment
                try:
                    delivery_assignment = DeliveryAssignment.objects.get(id=delivery_assignment_id)
                except DeliveryAssignment.DoesNotExist:
                    return {
                        'success': False,
                        'message': 'Delivery assignment not found',
                        'error_code': 'DELIVERY_ASSIGNMENT_NOT_FOUND'
                    }
            
            # If borrow_request_id is provided, try to find the delivery assignment
            if borrow_request_id and not delivery_assignment:
                from ..models.delivery_model import DeliveryAssignment, Order
                from ..models.borrowing_model import BorrowRequest
                try:
                    borrow_request = BorrowRequest.objects.get(id=borrow_request_id)
                    order = Order.objects.filter(
                        borrow_request=borrow_request,
                        order_type='borrowing'
                    ).first()
                    if order:
                        delivery_assignment = DeliveryAssignment.objects.filter(order=order).first()
                except BorrowRequest.DoesNotExist:
                    pass
            
            # Update location with tracking data
            success, message = delivery_manager.update_tracking_location(
                latitude=latitude,
                longitude=longitude,
                address=address,
                tracking_type=tracking_type,
                accuracy=accuracy,
                speed=speed,
                heading=heading,
                battery_level=battery_level,
                network_type=network_type,
                delivery_assignment=delivery_assignment
            )
            
            if success:
                # Update RealTimeTracking last_location_update
                from ..models.delivery_model import RealTimeTracking
                try:
                    tracking = RealTimeTracking.objects.get(delivery_manager=delivery_manager)
                    tracking.last_location_update = timezone.now()
                    tracking.save(update_fields=['last_location_update'])
                except RealTimeTracking.DoesNotExist:
                    pass
                
                return {
                    'success': True,
                    'message': 'Location updated with tracking data',
                    'location': delivery_manager.get_location_dict(),
                    'timestamp': timezone.now().isoformat()
                }
            else:
                return {
                    'success': False,
                    'message': message,
                    'error_code': 'LOCATION_UPDATE_FAILED'
                }
                
        except Exception as e:
            logger.error(f"Error updating tracking location: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to update location: {str(e)}",
                'error_code': 'LOCATION_UPDATE_ERROR'
            }
    
    @staticmethod
    def get_location_for_borrow_request(borrow_request_id: int) -> Dict[str, Any]:
        """
        Step 3.4: Get current location for a specific borrow request.
        Used for real-time tracking display.
        """
        try:
            from ..models.borrowing_model import BorrowRequest, BorrowStatusChoices
            
            borrow_request = BorrowRequest.objects.get(id=borrow_request_id)
            
            # Only available during OUT_FOR_DELIVERY or OUT_FOR_RETURN_PICKUP
            if borrow_request.status not in [BorrowStatusChoices.OUT_FOR_DELIVERY, BorrowStatusChoices.OUT_FOR_RETURN_PICKUP]:
                return {
                    'success': False,
                    'message': 'Location tracking not available for this request',
                    'error_code': 'TRACKING_NOT_AVAILABLE',
                    'current_status': borrow_request.status
                }
            
            delivery_manager = borrow_request.delivery_person
            if not delivery_manager:
                return {
                    'success': False,
                    'message': 'No delivery manager assigned',
                    'error_code': 'NO_DELIVERY_MANAGER'
                }
            
            # Get location from delivery profile
            location_data = None
            if hasattr(delivery_manager, 'delivery_profile') and delivery_manager.delivery_profile:
                profile = delivery_manager.delivery_profile
                if profile.latitude is not None and profile.longitude is not None:
                    location_data = {
                        'latitude': float(profile.latitude),
                        'longitude': float(profile.longitude),
                        'address': profile.address,
                        'last_updated': profile.location_updated_at.isoformat() if profile.location_updated_at else None,
                        'is_tracking_active': profile.is_tracking_active
                    }
            
            # Get latest location from history if profile doesn't have it
            if not location_data:
                from ..models.delivery_model import LocationHistory
                latest_location = LocationHistory.objects.filter(
                    delivery_manager=delivery_manager
                ).order_by('-recorded_at').first()
                
                if latest_location:
                    location_data = {
                        'latitude': float(latest_location.latitude),
                        'longitude': float(latest_location.longitude),
                        'address': latest_location.address,
                        'last_updated': latest_location.recorded_at.isoformat(),
                        'is_tracking_active': True
                    }
            
            if not location_data:
                return {
                    'success': False,
                    'message': 'Location not available',
                    'error_code': 'LOCATION_NOT_AVAILABLE'
                }
            
            return {
                'success': True,
                'location': location_data,
                'delivery_manager': {
                    'id': delivery_manager.id,
                    'name': delivery_manager.get_full_name(),
                    'phone': delivery_manager.phone_number if hasattr(delivery_manager, 'phone_number') else None
                },
                'borrow_request_id': borrow_request_id,
                'status': borrow_request.status
            }
            
        except BorrowRequest.DoesNotExist:
            return {
                'success': False,
                'message': 'Borrow request not found',
                'error_code': 'BORROW_REQUEST_NOT_FOUND'
            }
        except Exception as e:
            logger.error(f"Error getting location for borrow request: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to get location: {str(e)}",
                'error_code': 'GET_LOCATION_ERROR'
            }
    
    @staticmethod
    def get_location_history(delivery_manager: User, hours: int = 24) -> Dict[str, Any]:
        """
        Get location history for a delivery manager.
        """
        try:
            if not delivery_manager.is_delivery_admin():
                return {
                    'success': False,
                    'message': 'Only delivery managers can view location history',
                    'error_code': 'INVALID_USER_TYPE'
                }
            
            # Get location history
            history = delivery_manager.get_location_history(hours)
            
            return {
                'success': True,
                'location_history': [
                    {
                        'id': location.id,
                        'latitude': float(location.latitude),
                        'longitude': float(location.longitude),
                        'address': location.address,
                        'tracking_type': location.tracking_type,
                        'accuracy': location.accuracy,
                        'speed': location.speed,
                        'heading': location.heading,
                        'recorded_at': location.recorded_at,
                        'battery_level': location.battery_level,
                        'network_type': location.network_type,
                    }
                    for location in history
                ],
                'total_points': history.count(),
                'hours_analyzed': hours
            }
            
        except Exception as e:
            logger.error(f"Error getting location history: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to get location history: {str(e)}",
                'error_code': 'HISTORY_GET_ERROR'
            }
    
    @staticmethod
    def get_movement_summary(delivery_manager: User, hours: int = 24) -> Dict[str, Any]:
        """
        Get movement summary for a delivery manager.
        """
        try:
            if not delivery_manager.is_delivery_admin():
                return {
                    'success': False,
                    'message': 'Only delivery managers can view movement summary',
                    'error_code': 'INVALID_USER_TYPE'
                }
            
            # Get movement summary
            summary = delivery_manager.get_movement_summary(hours)
            summary['hours_analyzed'] = hours
            
            return {
                'success': True,
                'movement_summary': summary
            }
            
        except Exception as e:
            logger.error(f"Error getting movement summary: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to get movement summary: {str(e)}",
                'error_code': 'SUMMARY_GET_ERROR'
            }
    
    @staticmethod
    def get_all_tracking_managers() -> Dict[str, Any]:
        """
        Get all delivery managers with their tracking status.
        """
        try:
            from ..models.delivery_model import RealTimeTracking
            
            # Get all delivery managers with tracking enabled
            tracking_managers = RealTimeTracking.objects.filter(
                is_tracking_enabled=True
            ).select_related('delivery_manager', 'current_delivery_assignment')
            
            managers_data = []
            for tracking in tracking_managers:
                manager = tracking.delivery_manager
                managers_data.append({
                    'id': manager.id,
                    'name': manager.get_full_name(),
                    'email': manager.email,
                    'is_online': tracking.last_location_update and 
                               (timezone.now() - tracking.last_location_update).total_seconds() < 300,  # 5 minutes
                    'is_delivering': tracking.is_delivering,
                    'current_delivery_assignment': tracking.current_delivery_assignment.id if tracking.current_delivery_assignment else None,
                    'last_location_update': tracking.last_location_update,
                    'tracking_interval': tracking.tracking_interval,
                    'location': manager.get_location_dict() if manager.has_location() else None
                })
            
            return {
                'success': True,
                'tracking_managers': managers_data,
                'total_count': len(managers_data)
            }
            
        except Exception as e:
            logger.error(f"Error getting tracking managers: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to get tracking managers: {str(e)}",
                'error_code': 'TRACKING_MANAGERS_ERROR'
            }


class BorrowingDeliveryService:
    """
    Service for managing borrowing-related deliveries and returns
    """
    
    @staticmethod
    @transaction.atomic
    def create_delivery_for_borrow(borrow_request):
        """
        Create a delivery order for a borrowing request as specified in requirements
        """
        from ..models.delivery_model import Order, OrderItem, DeliveryAssignment
        
        try:
            # Create the delivery order
            # When delivery manager is assigned, set status to 'assigned' (not 'assigned_to_delivery')
            # This ensures the request appears in DM's Borrowing Requests list immediately
            delivery_order = Order.objects.create(
                order_number=f"BR{borrow_request.id:06d}",
                customer=borrow_request.customer,
                payment=None,  # Borrowing doesn't require payment upfront
                total_amount=0.00,
                order_type='borrowing',
                borrow_request=borrow_request,
                delivery_address=borrow_request.delivery_address,
                delivery_city="Customer City",  # Could be extracted from address
                delivery_notes=borrow_request.additional_notes or "",
                status='assigned' if borrow_request.delivery_person else 'pending_assignment'
            )
            
            logger.info(f"Created delivery order {delivery_order.id} for borrow request {borrow_request.id}")
            
            # Create order item for the borrowed book
            OrderItem.objects.create(
                order=delivery_order,
                book=borrow_request.book,
                quantity=1,
                unit_price=0.00,
                total_price=0.00
            )
            
            # If delivery manager is assigned to borrow request, create delivery assignment
            if borrow_request.delivery_person:
                # Check if assignment already exists (prevent duplicates)
                if not DeliveryAssignment.objects.filter(order=delivery_order).exists():
                    assignment = DeliveryAssignment.objects.create(
                        order=delivery_order,
                        delivery_manager=borrow_request.delivery_person,
                        estimated_delivery_time=borrow_request.expected_return_date,
                        delivery_notes=f"Borrowing delivery for {borrow_request.book.name}",
                        status='assigned',  # Explicitly set status
                        assigned_by=borrow_request.approved_by  # Set who assigned it
                    )
                    logger.info(f"Created delivery assignment {assignment.id} for order {delivery_order.id}, assigned to manager {borrow_request.delivery_person.id}")
                else:
                    logger.warning(f"Delivery assignment already exists for order {delivery_order.id}")
            else:
                logger.info(f"No delivery manager assigned to borrow request {borrow_request.id}, order status set to pending_assignment")
            
            return delivery_order
            
        except Exception as e:
            logger.error(f"Error creating delivery for borrow request {borrow_request.id}: {str(e)}", exc_info=True)
            raise  # Re-raise to ensure transaction rollback
    
    @staticmethod
    @transaction.atomic
    def create_borrowing_delivery_order(borrow_request: BorrowRequest, payment: Payment) -> Dict[str, Any]:
        """
        Create a delivery order for a borrowing request
        """
        try:
            # Generate order number
            order_number = f"BR{borrow_request.id:06d}"
            
            # Create delivery order
            order = Order.objects.create(
                order_number=order_number,
                customer=borrow_request.customer,
                payment=payment,
                total_amount=payment.amount,
                order_type='borrowing',
                borrow_request=borrow_request,
                delivery_address=borrow_request.customer.profile.address if hasattr(borrow_request.customer, 'profile') else '',
                contact_phone=borrow_request.customer.profile.phone_number if hasattr(borrow_request.customer, 'profile') else ''
            )
            
            # Create order item for the borrowed book
            OrderItem.objects.create(
                order=order,
                book=borrow_request.book,
                quantity=1,
                unit_price=borrow_request.book.borrow_price,
                total_price=borrow_request.book.borrow_price
            )
            
            # Create delivery request for the borrowing order
            try:
                from ..models.delivery_model import DeliveryRequest
                from django.utils import timezone
                from datetime import timedelta
                
                # Calculate preferred delivery time (24 hours from now)
                preferred_delivery_time = timezone.now() + timedelta(hours=24)
                
                delivery_request = DeliveryRequest.objects.create(
                    customer=borrow_request.customer,
                    order=order,
                    request_type='delivery',
                    delivery_address=borrow_request.customer.profile.address if hasattr(borrow_request.customer, 'profile') else '',
                    delivery_city=borrow_request.customer.profile.city if hasattr(borrow_request.customer, 'profile') and hasattr(borrow_request.customer.profile, 'city') else 'Unknown',
                    preferred_pickup_time=timezone.now() + timedelta(hours=1),  # 1 hour from now
                    preferred_delivery_time=preferred_delivery_time,
                    status='pending',
                    notes=f'Borrowing delivery request for order #{order.order_number} - Book: {borrow_request.book.name}'
                )
                
                logger.info(f"Created borrowing delivery request {delivery_request.id} for order {order.id}")
                
            except Exception as e:
                logger.error(f"Failed to create delivery request for borrowing order {order.id}: {str(e)}")
                # Don't fail the order creation if delivery request creation fails
                pass
            
            return {
                'success': True,
                'message': 'Borrowing delivery order created successfully',
                'order': order
            }
            
        except Exception as e:
            logger.error(f"Error creating borrowing delivery order: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to create borrowing delivery order: {str(e)}",
                'error_code': 'CREATE_BORROWING_ORDER_ERROR'
            }
    
    @staticmethod
    @transaction.atomic
    def create_return_collection_order(borrow_request: BorrowRequest) -> Dict[str, Any]:
        """
        Create a collection order for book return
        """
        try:
            # Generate order number
            order_number = f"RC{borrow_request.id:06d}"
            
            # Create collection order
            order = Order.objects.create(
                order_number=order_number,
                customer=borrow_request.customer,
                payment=None,  # No payment for collection
                total_amount=0.00,
                order_type='return_collection',
                borrow_request=borrow_request,
                is_return_collection=True,
                delivery_address=borrow_request.customer.profile.address if hasattr(borrow_request.customer, 'profile') else '',
                contact_phone=borrow_request.customer.profile.phone_number if hasattr(borrow_request.customer, 'profile') else ''
            )
            
            # Create order item for the book to be collected
            OrderItem.objects.create(
                order=order,
                book=borrow_request.book,
                quantity=1,
                unit_price=0.00,
                total_price=0.00
            )
            
            return {
                'success': True,
                'message': 'Return collection order created successfully',
                'order': order
            }
            
        except Exception as e:
            logger.error(f"Error creating return collection order: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to create return collection order: {str(e)}",
                'error_code': 'CREATE_COLLECTION_ORDER_ERROR'
            }
    
    @staticmethod
    def get_borrowing_deliveries(delivery_manager: User = None) -> Dict[str, Any]:
        """
        Get pending borrowing deliveries
        """
        try:
            queryset = Order.objects.filter(
                order_type='borrowing',
                status='pending'
            ).select_related('customer', 'borrow_request', 'borrow_request__book')
            
            if delivery_manager:
                # Filter by assigned delivery manager
                queryset = queryset.filter(
                    delivery_assignment__delivery_manager=delivery_manager
                )
            
            orders = []
            for order in queryset:
                orders.append({
                    'order_id': order.id,
                    'order_number': order.order_number,
                    'customer_name': order.customer.get_full_name(),
                    'customer_phone': order.contact_phone,
                    'book_title': order.borrow_request.book.title,
                    'delivery_address': order.delivery_address,
                    'created_at': order.created_at,
                    'borrow_request_id': order.borrow_request.id
                })
            
            return {
                'success': True,
                'deliveries': orders
            }
            
        except Exception as e:
            logger.error(f"Error getting borrowing deliveries: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to get borrowing deliveries: {str(e)}",
                'error_code': 'GET_BORROWING_DELIVERIES_ERROR'
            }
    
    @staticmethod
    def get_return_collections(delivery_manager: User = None) -> Dict[str, Any]:
        """
        Get pending return collections
        """
        try:
            queryset = Order.objects.filter(
                order_type='return_collection',
                status='pending'
            ).select_related('customer', 'borrow_request', 'borrow_request__book')
            
            if delivery_manager:
                # Filter by assigned delivery manager
                queryset = queryset.filter(
                    delivery_assignment__delivery_manager=delivery_manager
                )
            
            orders = []
            for order in queryset:
                orders.append({
                    'order_id': order.id,
                    'order_number': order.order_number,
                    'customer_name': order.customer.get_full_name(),
                    'customer_phone': order.contact_phone,
                    'book_title': order.borrow_request.book.title,
                    'collection_address': order.delivery_address,
                    'created_at': order.created_at,
                    'borrow_request_id': order.borrow_request.id
                })
            
            return {
                'success': True,
                'collections': orders
            }
            
        except Exception as e:
            logger.error(f"Error getting return collections: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to get return collections: {str(e)}",
                'error_code': 'GET_RETURN_COLLECTIONS_ERROR'
            }
    
    @staticmethod
    @transaction.atomic
    def assign_borrowing_delivery(order: Order, delivery_manager: User) -> Dict[str, Any]:
        """
        Assign a borrowing delivery to a delivery manager
        """
        try:
            # Create delivery assignment
            assignment = DeliveryAssignment.objects.create(
                order=order,
                delivery_manager=delivery_manager,
                status='assigned'
            )
            
            return {
                'success': True,
                'message': 'Borrowing delivery assigned successfully',
                'assignment': assignment
            }
            
        except Exception as e:
            logger.error(f"Error assigning borrowing delivery: {str(e)}")
            return {
                'success': False,
                'message': f"Failed to assign borrowing delivery: {str(e)}",
                'error_code': 'ASSIGN_BORROWING_DELIVERY_ERROR'
            }
 
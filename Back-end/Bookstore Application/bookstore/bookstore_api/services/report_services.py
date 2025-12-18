from django.db.models import Count, Sum, Q, F, Avg
from django.utils import timezone
from django.db import models
from datetime import datetime, timedelta
from decimal import Decimal
import logging

from ..models.report_model import Report, ReportTemplate
from ..models.library_model import Book, Library, Author, Category, BookEvaluation
from ..models.user_model import User
from ..models.delivery_model import Order
from ..models.borrowing_model import BorrowRequest, BorrowStatusChoices, FineStatusChoices
from ..models.return_model import ReturnFine
from ..models.delivery_model import DeliveryRequest
from ..models.payment_model import Payment

logger = logging.getLogger(__name__)


class ReportManagementService:
    """
    Service class for managing reports and analytics
    """
    
    @staticmethod
    def get_dashboard_statistics():
        """
        Get comprehensive dashboard statistics
        """
        try:
            # Basic counts
            total_books = Book.objects.count()
            available_books = Book.objects.filter(is_available=True).count()
            total_users = User.objects.filter(is_active=True).count()
            
            # Author and Category counts
            total_authors = Author.objects.filter(is_active=True).count()
            total_categories = Category.objects.filter(is_active=True).count()
            
            # Book ratings statistics
            total_ratings = BookEvaluation.objects.count()
            avg_rating = BookEvaluation.objects.aggregate(
                avg_rating=Avg('rating')
            )['avg_rating'] or 0.0
            
            # Active users (logged in within last 30 days)
            active_users = User.objects.filter(
                is_active=True,
                last_login__gte=timezone.now() - timedelta(days=30)
            ).count()
            
            # Order statistics
            total_orders = Order.objects.count()
            pending_orders = Order.objects.filter(status='pending').count()
            completed_orders = Order.objects.filter(status='completed').count()
            
            # Revenue calculations
            total_revenue = Order.objects.filter(
                status='completed'
            ).aggregate(total=Sum('total_amount'))['total'] or Decimal('0.00')
            
            # Monthly revenue (last 30 days)
            monthly_revenue = Order.objects.filter(
                status='completed',
                created_at__gte=timezone.now() - timedelta(days=30)
            ).aggregate(total=Sum('total_amount'))['total'] or Decimal('0.00')
            
            # Borrowing statistics
            overdue_books = BorrowRequest.objects.filter(
                status='overdue'
            ).count()
            active_borrowings = BorrowRequest.objects.filter(
                status__in=['approved', 'borrowed']
            ).count()
            pending_requests = BorrowRequest.objects.filter(
                status='pending'
            ).count()
            
            # Calculate trends
            book_trend = ReportManagementService._calculate_book_trend()
            user_trend = ReportManagementService._calculate_user_trend()
            order_trend = ReportManagementService._calculate_order_trend()
            revenue_trend = ReportManagementService._calculate_revenue_trend()
            author_trend = ReportManagementService._calculate_author_trend()
            category_trend = ReportManagementService._calculate_category_trend()
            
            return {
                'total_books': total_books,
                'available_books': available_books,
                'total_users': total_users,
                'active_users': active_users,
                'total_orders': total_orders,
                'pending_orders': pending_orders,
                'completed_orders': completed_orders,
                'total_revenue': total_revenue,
                'monthly_revenue': monthly_revenue,
                'overdue_books': overdue_books,
                'active_borrowings': active_borrowings,
                'pending_requests': pending_requests,
                'total_authors': total_authors,
                'total_categories': total_categories,
                'total_ratings': total_ratings,
                'avg_rating': round(avg_rating, 2),
                'book_trend': book_trend,
                'user_trend': user_trend,
                'order_trend': order_trend,
                'revenue_trend': revenue_trend,
                'author_trend': author_trend,
                'category_trend': category_trend,
            }
            
        except Exception as e:
            logger.error(f"Error getting dashboard statistics: {str(e)}")
            raise e
    
    @staticmethod
    def get_sales_report(start_date=None, end_date=None, period='monthly'):
        """
        Get sales report data
        """
        try:
            # Set date range based on period
            if not start_date or not end_date:
                if period == 'daily':
                    start_date = timezone.now().date()
                    end_date = timezone.now().date()
                elif period == 'weekly':
                    start_date = timezone.now().date() - timedelta(days=7)
                    end_date = timezone.now().date()
                elif period == 'monthly':
                    start_date = timezone.now().date() - timedelta(days=30)
                    end_date = timezone.now().date()
                elif period == 'yearly':
                    start_date = timezone.now().date() - timedelta(days=365)
                    end_date = timezone.now().date()
            
            # Convert to datetime if needed
            if isinstance(start_date, str):
                try:
                    # Try ISO format first
                    start_date = datetime.fromisoformat(start_date.replace('Z', '+00:00')).date()
                except ValueError:
                    # Fallback to date format
                    start_date = datetime.strptime(start_date, '%Y-%m-%d').date()
            if isinstance(end_date, str):
                try:
                    # Try ISO format first
                    end_date = datetime.fromisoformat(end_date.replace('Z', '+00:00')).date()
                except ValueError:
                    # Fallback to date format
                    end_date = datetime.strptime(end_date, '%Y-%m-%d').date()
            
            # Calculate revenue
            orders = Order.objects.filter(
                status='completed',
                created_at__date__range=[start_date, end_date]
            )
            
            total_revenue = orders.aggregate(total=Sum('total_amount'))['total'] or Decimal('0.00')
            
            # Monthly revenue (last 30 days)
            monthly_orders = Order.objects.filter(
                status='completed',
                created_at__gte=timezone.now() - timedelta(days=30)
            )
            monthly_revenue = monthly_orders.aggregate(total=Sum('total_amount'))['total'] or Decimal('0.00')
            
            # Calculate trend
            revenue_trend = ReportManagementService._calculate_revenue_trend()
            
            # Generate trend data
            trend_data = ReportManagementService._generate_revenue_trend_data(start_date, end_date)
            
            return {
                'total_revenue': total_revenue,
                'monthly_revenue': monthly_revenue,
                'revenue_trend': revenue_trend['trend'],
                'revenue_trend_value': revenue_trend['value'],
                'trend': trend_data,
                'period': period,
                'start_date': start_date.isoformat() if start_date else None,
                'end_date': end_date.isoformat() if end_date else None,
            }
            
        except Exception as e:
            logger.error(f"Error getting sales report: {str(e)}")
            raise e
    
    @staticmethod
    def get_user_report(start_date=None, end_date=None):
        """
        Get user report data
        """
        try:
            # Get user statistics
            total_users = User.objects.filter(is_active=True).count()
            active_users = User.objects.filter(
                is_active=True,
                last_login__gte=timezone.now() - timedelta(days=30)
            ).count()
            
            # New users in date range
            if start_date and end_date:
                new_users = User.objects.filter(
                    date_joined__date__range=[start_date, end_date]
                ).count()
            else:
                new_users = User.objects.filter(
                    date_joined__gte=timezone.now() - timedelta(days=30)
                ).count()
            
            # Calculate trend
            user_trend = ReportManagementService._calculate_user_trend()
            
            # Generate growth data
            growth_data = ReportManagementService._generate_user_growth_data()
            
            return {
                'total_users': total_users,
                'active_users': active_users,
                'new_users': new_users,
                'user_trend': user_trend['trend'],
                'user_trend_value': user_trend['value'],
                'growth': growth_data,
            }
            
        except Exception as e:
            logger.error(f"Error getting user report: {str(e)}")
            raise e
    
    @staticmethod
    def get_book_report():
        """
        Get comprehensive book report data for Book Popularity Report
        """
        try:
            # Get basic book statistics
            total_books = Book.objects.count()
            # Available books should be those that can actually be borrowed (available_copies > 0)
            available_books = Book.objects.filter(available_copies__gt=0).count()
            
            # Calculate borrowed books (books where some copies are currently borrowed)
            borrowed_books = Book.objects.filter(
                available_copies__lt=models.F('quantity')
            ).count()
            
            # Debug logging
            logger.info(f"Book Report Debug - Total books: {total_books}")
            logger.info(f"Book Report Debug - Available books (available_copies > 0): {available_books}")
            logger.info(f"Book Report Debug - Borrowed books (available_copies < quantity): {borrowed_books}")
            
            # Additional debugging - check individual books
            all_books = Book.objects.all()
            logger.info(f"Book Report Debug - All books details:")
            for book in all_books:
                logger.info(f"  - Book: {book.name}, Quantity: {book.quantity}, Available: {book.available_copies}, Is Available: {book.is_available}")
            
            # Debug borrow requests and orders
            total_borrow_requests = BorrowRequest.objects.count()
            total_orders = Order.objects.count()
            logger.info(f"Book Report Debug - Total borrow requests: {total_borrow_requests}")
            logger.info(f"Book Report Debug - Total orders: {total_orders}")
            
            # Check if there are any borrow requests
            if total_borrow_requests > 0:
                logger.info(f"Book Report Debug - Borrow request statuses:")
                for status in ['pending', 'approved', 'borrowed', 'returned']:
                    count = BorrowRequest.objects.filter(status=status).count()
                    logger.info(f"  - {status}: {count}")
            
            # Calculate trend
            book_trend = ReportManagementService._calculate_book_trend()
            
            # Get most borrowed books (by borrow requests)
            most_borrowed = BorrowRequest.objects.filter(
                status__in=['approved', 'borrowed', 'returned']
            ).values(
                'book__name', 'book__author__name', 'book__id'
            ).annotate(
                borrow_count=Count('id')
            ).order_by('-borrow_count')[:10]
            
            most_borrowed_data = []
            for item in most_borrowed:
                if item['book__name']:  # Only include books with valid names
                    most_borrowed_data.append({
                        'title': item['book__name'],
                        'author': item['book__author__name'] or 'Unknown Author',
                        'book_id': item['book__id'],
                        'borrow_count': item['borrow_count']
                    })
            
            # Get best sellers (books most requested via orders)
            best_sellers = Order.objects.filter(
                status='completed'
            ).values(
                'items__book__name', 'items__book__author__name', 'items__book__id'
            ).annotate(
                request_count=Count('id')
            ).order_by('-request_count')[:10]
            
            best_sellers_data = []
            for item in best_sellers:
                if item['items__book__name']:  # Only include books with valid names
                    best_sellers_data.append({
                        'title': item['items__book__name'],
                        'author': item['items__book__author__name'] or 'Unknown Author',
                        'book_id': item['items__book__id'],
                        'request_count': item['request_count']
                    })
            
            # Calculate book trends (growth in availability/borrowing)
            current_month_borrows = BorrowRequest.objects.filter(
                created_at__gte=timezone.now() - timedelta(days=30)
            ).count()
            previous_month_borrows = BorrowRequest.objects.filter(
                created_at__gte=timezone.now() - timedelta(days=60),
                created_at__lt=timezone.now() - timedelta(days=30)
            ).count()
            
            if previous_month_borrows > 0:
                borrowing_trend_value = ((current_month_borrows - previous_month_borrows) / previous_month_borrows) * 100
                borrowing_trend = 'up' if borrowing_trend_value > 0 else 'down'
            elif current_month_borrows > 0:
                # If there are current borrows but no previous borrows, it's a positive trend
                borrowing_trend_value = 100.0
                borrowing_trend = 'up'
            else:
                borrowing_trend_value = 0
                borrowing_trend = 'stable'
            
            result = {
                'total_books': total_books,
                'available_books': available_books,
                'borrowed_books': borrowed_books,
                'book_trend': book_trend['trend'],
                'book_trend_value': book_trend['value'],
                'most_borrowed_books': most_borrowed_data,
                'best_sellers': best_sellers_data,
                'borrowing_trend': borrowing_trend,
                'borrowing_trend_value': round(borrowing_trend_value, 2),
            }
            
            # Debug logging
            logger.info(f"Book Report Debug - Final result: {result}")
            
            return result
            
        except Exception as e:
            logger.error(f"Error getting book report: {str(e)}")
            raise e
    
    @staticmethod
    def get_fines_report(start_date=None, end_date=None):
        """
        Get comprehensive fines report data
        """
        try:
            # Set date range if not provided
            if not start_date:
                start_date = timezone.now().date() - timedelta(days=30)
            if not end_date:
                end_date = timezone.now().date()
            
            # Convert to datetime if needed
            if isinstance(start_date, str):
                start_date = datetime.fromisoformat(start_date.replace('Z', '+00:00')).date()
            if isinstance(end_date, str):
                end_date = datetime.fromisoformat(end_date.replace('Z', '+00:00')).date()
            
            # Late Book Statistics
            total_overdue_books = BorrowRequest.objects.filter(
                status=BorrowStatusChoices.LATE,
                expected_return_date__lt=timezone.now()
            ).count()
            
            overdue_books_with_fines = BorrowRequest.objects.filter(
                status=BorrowStatusChoices.LATE,
                expected_return_date__lt=timezone.now(),
                fine_amount__gt=0
            ).count()
            
            avg_days_overdue = BorrowRequest.objects.filter(
                status=BorrowStatusChoices.LATE,
                expected_return_date__lt=timezone.now()
            ).aggregate(
                avg_days=models.Avg(
                    models.F('expected_return_date') - timezone.now()
                )
            )['avg_days']
            
            # Convert timedelta to days if it exists
            if avg_days_overdue:
                avg_days_overdue = avg_days_overdue.days
            else:
                avg_days_overdue = 0
            
            # Fine Collection Data (using unified ReturnFine model)
            total_fines_issued = ReturnFine.objects.count()
            total_fine_amount = ReturnFine.objects.aggregate(
                total=models.Sum('fine_amount')
            )['total'] or Decimal('0.00')
            
            unpaid_fines = ReturnFine.objects.filter(
                is_paid=False
            ).count()
            
            paid_fines = ReturnFine.objects.filter(
                is_paid=True
            ).count()
            
            # Fine Payment Status
            total_unpaid_amount = ReturnFine.objects.filter(
                is_paid=False
            ).aggregate(
                total=models.Sum('fine_amount')
            )['total'] or Decimal('0.00')
            
            total_paid_amount = ReturnFine.objects.filter(
                is_paid=True
            ).aggregate(
                total=models.Sum('fine_amount')
            )['total'] or Decimal('0.00')
            
            payment_rate = 0.0
            if total_fine_amount > 0:
                payment_rate = (total_paid_amount / total_fine_amount) * 100
            
            # Historical Fine Trends
            current_month_fines = ReturnFine.objects.filter(
                created_at__gte=timezone.now() - timedelta(days=30)
            ).count()
            
            previous_month_fines = ReturnFine.objects.filter(
                created_at__gte=timezone.now() - timedelta(days=60),
                created_at__lt=timezone.now() - timedelta(days=30)
            ).count()
            
            if previous_month_fines > 0:
                fine_trend_value = ((current_month_fines - previous_month_fines) / previous_month_fines) * 100
                fine_trend = 'up' if fine_trend_value > 0 else 'down'
            else:
                fine_trend_value = 0
                fine_trend = 'stable'
            
            # Recent fines data for trends
            recent_fines = ReturnFine.objects.filter(
                created_at__gte=timezone.now() - timedelta(days=7)
            ).order_by('-created_at')[:10]
            
            recent_fines_data = []
            for fine in recent_fines:
                # Get book and customer info from return request
                if fine.return_request and fine.return_request.borrowing:
                    book_title = fine.return_request.borrowing.book.name
                    customer_name = fine.return_request.borrowing.customer.get_full_name()
                else:
                    book_title = "Unknown"
                    customer_name = "Unknown"
                
                recent_fines_data.append({
                    'id': fine.id,
                    'amount': float(fine.fine_amount),
                    'status': fine.payment_status,
                    'reason': fine.reason or "Late return",
                    'book_title': book_title,
                    'customer_name': customer_name,
                    'created_at': fine.created_at.isoformat(),
                })
            
            return {
                # Late Book Statistics
                'total_overdue_books': total_overdue_books,
                'overdue_books_with_fines': overdue_books_with_fines,
                'avg_days_overdue': round(avg_days_overdue, 1),
                
                # Fine Collection Data
                'total_fines_issued': total_fines_issued,
                'total_fine_amount': float(total_fine_amount),
                'unpaid_fines': unpaid_fines,
                'paid_fines': paid_fines,
                
                # Fine Payment Status
                'total_unpaid_amount': float(total_unpaid_amount),
                'total_paid_amount': float(total_paid_amount),
                'payment_rate': round(payment_rate, 2),
                
                # Historical Fine Trends
                'fine_trend': fine_trend,
                'fine_trend_value': round(fine_trend_value, 2),
                'current_month_fines': current_month_fines,
                'previous_month_fines': previous_month_fines,
                'recent_fines': recent_fines_data,
            }
            
        except Exception as e:
            logger.error(f"Error getting fines report: {str(e)}")
            raise e
    
    @staticmethod
    def get_order_report(start_date=None, end_date=None, status=None):
        """
        Get order report data
        """
        try:
            # Set date range
            if not start_date:
                start_date = timezone.now().date() - timedelta(days=30)
            if not end_date:
                end_date = timezone.now().date()
            
            # Convert to datetime if needed
            if isinstance(start_date, str):
                try:
                    # Try ISO format first
                    start_date = datetime.fromisoformat(start_date.replace('Z', '+00:00')).date()
                except ValueError:
                    # Fallback to date format
                    start_date = datetime.strptime(start_date, '%Y-%m-%d').date()
            if isinstance(end_date, str):
                try:
                    # Try ISO format first
                    end_date = datetime.fromisoformat(end_date.replace('Z', '+00:00')).date()
                except ValueError:
                    # Fallback to date format
                    end_date = datetime.strptime(end_date, '%Y-%m-%d').date()
            
            # Get order statistics
            orders = Order.objects.filter(created_at__date__range=[start_date, end_date])
            
            if status:
                orders = orders.filter(status=status)
            
            total_orders = orders.count()
            pending_orders = orders.filter(status='pending').count()
            completed_orders = orders.filter(status='completed').count()
            cancelled_orders = orders.filter(status='cancelled').count()
            
            # Calculate trend
            order_trend = ReportManagementService._calculate_order_trend()
            
            # Get status distribution
            status_distribution = orders.values('status').annotate(
                count=Count('id')
            ).order_by('-count')
            
            status_data = {}
            for item in status_distribution:
                status_data[item['status']] = item['count']
            
            return {
                'total_orders': total_orders,
                'pending_orders': pending_orders,
                'completed_orders': completed_orders,
                'cancelled_orders': cancelled_orders,
                'order_trend': order_trend['trend'],
                'order_trend_value': order_trend['value'],
                'status_distribution': status_data,
                'start_date': start_date.isoformat() if start_date else None,
                'end_date': end_date.isoformat() if end_date else None,
            }
            
        except Exception as e:
            logger.error(f"Error getting order report: {str(e)}")
            raise e
    
    @staticmethod
    def get_borrowing_report(start_date=None, end_date=None, period='monthly'):
        """
        Get comprehensive borrowing report data for Borrowing Report
        """
        try:
            # Set date range
            if not start_date or not end_date:
                if period == 'daily':
                    start_date = timezone.now().date()
                    end_date = timezone.now().date()
                elif period == 'weekly':
                    start_date = timezone.now().date() - timedelta(days=7)
                    end_date = timezone.now().date()
                elif period == 'monthly':
                    start_date = timezone.now().date() - timedelta(days=30)
                    end_date = timezone.now().date()
                elif period == 'yearly':
                    start_date = timezone.now().date() - timedelta(days=365)
                    end_date = timezone.now().date()
            
            # Convert to datetime if needed
            if isinstance(start_date, str):
                try:
                    # Try ISO format first
                    start_date = datetime.fromisoformat(start_date.replace('Z', '+00:00')).date()
                except ValueError:
                    # Fallback to date format
                    start_date = datetime.strptime(start_date, '%Y-%m-%d').date()
            if isinstance(end_date, str):
                try:
                    # Try ISO format first
                    end_date = datetime.fromisoformat(end_date.replace('Z', '+00:00')).date()
                except ValueError:
                    # Fallback to date format
                    end_date = datetime.strptime(end_date, '%Y-%m-%d').date()
            
            # Get borrowing statistics
            borrow_requests = BorrowRequest.objects.filter(
                request_date__date__range=[start_date, end_date]
            )
            
            # Basic statistics
            total_requests = borrow_requests.count()
            approved_requests = borrow_requests.filter(status=BorrowStatusChoices.APPROVED).count()
            pending_requests = borrow_requests.filter(status=BorrowStatusChoices.PENDING).count()
            
            # Late requests (overdue)
            late_requests = borrow_requests.filter(
                status__in=[BorrowStatusChoices.APPROVED, BorrowStatusChoices.ACTIVE],
                expected_return_date__lt=timezone.now()
            ).count()
            
            # Returned requests
            returned_requests = borrow_requests.filter(
                status=BorrowStatusChoices.RETURNED
            ).count()
            
            # Get most borrowed books (top 10)
            most_borrowed = borrow_requests.values(
                'book__name', 'book__author__name', 'book__id'
            ).annotate(
                borrow_count=Count('id')
            ).order_by('-borrow_count')[:10]
            
            most_borrowed_data = []
            for item in most_borrowed:
                most_borrowed_data.append({
                    'book_id': item['book__id'],
                    'title': item['book__name'],
                    'author': item['book__author__name'],
                    'borrow_count': item['borrow_count']
                })
            
            # Period analysis - calculate trends
            current_period_requests = borrow_requests.count()
            
            # Previous period comparison
            if period == 'daily':
                previous_period_requests = BorrowRequest.objects.filter(
                    request_date__date=start_date - timedelta(days=1)
                ).count()
            elif period == 'weekly':
                previous_period_requests = BorrowRequest.objects.filter(
                    request_date__date__range=[
                        start_date - timedelta(days=7),
                        start_date - timedelta(days=1)
                    ]
                ).count()
            elif period == 'monthly':
                previous_period_requests = BorrowRequest.objects.filter(
                    request_date__date__range=[
                        start_date - timedelta(days=30),
                        start_date - timedelta(days=1)
                    ]
                ).count()
            elif period == 'yearly':
                previous_period_requests = BorrowRequest.objects.filter(
                    request_date__date__range=[
                        start_date - timedelta(days=365),
                        start_date - timedelta(days=1)
                    ]
                ).count()
            else:
                previous_period_requests = 0
            
            # Calculate trend
            if previous_period_requests > 0:
                trend_value = float(((current_period_requests - previous_period_requests) / previous_period_requests) * 100)
                trend = 'up' if trend_value > 0 else 'down'
            else:
                trend_value = 0.0
                trend = 'stable'
            
            # Calculate approval rate
            approval_rate = float((approved_requests / total_requests * 100)) if total_requests > 0 else 0.0
            
            # Calculate return rate
            return_rate = float((returned_requests / total_requests * 100)) if total_requests > 0 else 0.0
            
            return {
                # Basic borrowing statistics
                'total_requests': total_requests,
                'approved_requests': approved_requests,
                'pending_requests': pending_requests,
                'late_requests': late_requests,
                'returned_requests': returned_requests,
                
                # Most borrowed books
                'most_borrowed_books': most_borrowed_data,
                'top_books_count': len(most_borrowed_data),
                
                # Period analysis
                'period': period,
                'trend': trend,
                'trend_value': round(trend_value, 2),
                'current_period_requests': current_period_requests,
                'previous_period_requests': previous_period_requests,
                
                # Performance metrics
                'approval_rate': round(approval_rate, 2),
                'return_rate': round(return_rate, 2),
                
                # Period information
                'start_date': start_date.isoformat() if start_date else None,
                'end_date': end_date.isoformat() if end_date else None,
            }
            
        except Exception as e:
            logger.error(f"Error getting borrowing report: {str(e)}")
            raise e
    
    @staticmethod
    def get_delivery_report(start_date=None, end_date=None, period='monthly'):
        """
        Get comprehensive delivery report data for Delivery Report
        """
        try:
            # Set date range
            if not start_date or not end_date:
                if period == 'daily':
                    start_date = timezone.now().date()
                    end_date = timezone.now().date()
                elif period == 'weekly':
                    start_date = timezone.now().date() - timedelta(days=7)
                    end_date = timezone.now().date()
                elif period == 'monthly':
                    start_date = timezone.now().date() - timedelta(days=30)
                    end_date = timezone.now().date()
                elif period == 'yearly':
                    start_date = timezone.now().date() - timedelta(days=365)
                    end_date = timezone.now().date()
            
            # Convert to datetime if needed
            if isinstance(start_date, str):
                try:
                    # Try ISO format first
                    start_date = datetime.fromisoformat(start_date.replace('Z', '+00:00')).date()
                except ValueError:
                    # Fallback to date format
                    start_date = datetime.strptime(start_date, '%Y-%m-%d').date()
            if isinstance(end_date, str):
                try:
                    # Try ISO format first
                    end_date = datetime.fromisoformat(end_date.replace('Z', '+00:00')).date()
                except ValueError:
                    # Fallback to date format
                    end_date = datetime.strptime(end_date, '%Y-%m-%d').date()
            
            # Get delivery statistics from DeliveryRequest
            deliveries = DeliveryRequest.objects.filter(
                assigned_at__date__range=[start_date, end_date]
            )
            
            total_deliveries = deliveries.count()
            completed_deliveries = deliveries.filter(actual_delivery_time__isnull=False).count()
            pending_deliveries = deliveries.filter(
                actual_delivery_time__isnull=True,
                estimated_delivery_time__gt=timezone.now()
            ).count()
            in_progress_deliveries = deliveries.filter(
                actual_delivery_time__isnull=True,
                estimated_delivery_time__lte=timezone.now()
            ).count()
            failed_deliveries = deliveries.filter(
                actual_delivery_time__isnull=True,
                estimated_delivery_time__lt=timezone.now() - timedelta(days=1)
            ).count()
            
            # Get delivery performance by agent (top 10)
            agent_performance = deliveries.filter(
                delivery_manager__isnull=False
            ).values(
                'delivery_manager__first_name', 'delivery_manager__last_name', 'delivery_manager__id'
            ).annotate(
                delivery_count=Count('id'),
                completed_count=Count('id', filter=Q(actual_delivery_time__isnull=False))
            ).order_by('-delivery_count')[:10]
            
            agent_data = []
            for item in agent_performance:
                completion_rate = (item['completed_count'] / item['delivery_count'] * 100) if item['delivery_count'] > 0 else 0
                first_name = item.get('delivery_manager__first_name') or ''
                last_name = item.get('delivery_manager__last_name') or ''
                agent_name = f"{first_name} {last_name}".strip() or 'Unknown Agent'
                agent_data.append({
                    'agent_id': item['delivery_manager__id'],
                    'agent_name': agent_name,
                    'delivery_count': item['delivery_count'],
                    'completed_count': item['completed_count'],
                    'completion_rate': round(completion_rate, 2)
                })
            
            # Calculate overall completion rate
            overall_completion_rate = (completed_deliveries / total_deliveries * 100) if total_deliveries > 0 else 0
            
            # Calculate delivery trends
            current_month_deliveries = DeliveryRequest.objects.filter(
                assigned_at__gte=timezone.now() - timedelta(days=30)
            ).count()
            
            previous_month_deliveries = DeliveryRequest.objects.filter(
                assigned_at__gte=timezone.now() - timedelta(days=60),
                assigned_at__lt=timezone.now() - timedelta(days=30)
            ).count()
            
            if previous_month_deliveries > 0:
                delivery_trend_value = ((current_month_deliveries - previous_month_deliveries) / previous_month_deliveries) * 100
                delivery_trend = 'up' if delivery_trend_value > 0 else 'down'
            else:
                delivery_trend_value = 0
                delivery_trend = 'stable'
            
            return {
                # Basic delivery statistics
                'total_deliveries': total_deliveries,
                'completed_deliveries': completed_deliveries,
                'pending_deliveries': pending_deliveries,
                'in_progress_deliveries': in_progress_deliveries,
                'failed_deliveries': failed_deliveries,
                
                # Agent performance data
                'agent_performance': agent_data,
                'top_agents_count': len(agent_data),
                
                # Performance metrics
                'overall_completion_rate': round(overall_completion_rate, 2),
                'delivery_trend': delivery_trend,
                'delivery_trend_value': round(delivery_trend_value, 2),
                
                # Period information
                'period': period,
                'start_date': start_date.isoformat() if start_date else None,
                'end_date': end_date.isoformat() if end_date else None,
            }
            
        except Exception as e:
            logger.error(f"Error getting delivery report: {str(e)}")
            raise e
    
    @staticmethod
    def create_report(report_type, title, description, start_date=None, end_date=None, created_by=None):
        """
        Create a new report
        """
        try:
            report = Report.objects.create(
                report_type=report_type,
                title=title,
                description=description,
                start_date=start_date,
                end_date=end_date,
                created_by=created_by
            )
            
            # Generate report data based on type
            if report_type == 'dashboard':
                report.data = ReportManagementService.get_dashboard_statistics()
            elif report_type == 'sales':
                report.data = ReportManagementService.get_sales_report(start_date, end_date)
            elif report_type == 'users':
                report.data = ReportManagementService.get_user_report(start_date, end_date)
            elif report_type == 'books':
                report.data = ReportManagementService.get_book_report()
            elif report_type == 'orders':
                report.data = ReportManagementService.get_order_report(start_date, end_date)
            elif report_type == 'borrowing':
                report.data = ReportManagementService.get_borrowing_report(start_date, end_date)
            elif report_type == 'delivery':
                report.data = ReportManagementService.get_delivery_report(start_date, end_date)
            
            report.is_generated = True
            report.save()
            
            return report
            
        except Exception as e:
            logger.error(f"Error creating report: {str(e)}")
            raise e
    
    
    # Helper methods for trend calculations
    @staticmethod
    def _calculate_book_trend():
        """Calculate book trend"""
        try:
            # Simplified trend calculation
            current_month = Book.objects.filter(
                created_at__gte=timezone.now() - timedelta(days=30)
            ).count()
            previous_month = Book.objects.filter(
                created_at__gte=timezone.now() - timedelta(days=60),
                created_at__lt=timezone.now() - timedelta(days=30)
            ).count()
            
            if previous_month > 0:
                trend_value = ((current_month - previous_month) / previous_month) * 100
                trend = 'up' if trend_value > 0 else 'down'
            elif current_month > 0:
                # If there are current books but no previous books, it's a positive trend
                trend_value = 100.0
                trend = 'up'
            else:
                trend_value = 0
                trend = 'stable'
            
            return {'trend': trend, 'value': round(trend_value, 2)}
        except:
            return {'trend': 'stable', 'value': 0}
    
    @staticmethod
    def _calculate_user_trend():
        """Calculate user trend"""
        try:
            current_month = User.objects.filter(
                date_joined__gte=timezone.now() - timedelta(days=30)
            ).count()
            previous_month = User.objects.filter(
                date_joined__gte=timezone.now() - timedelta(days=60),
                date_joined__lt=timezone.now() - timedelta(days=30)
            ).count()
            
            if previous_month > 0:
                trend_value = ((current_month - previous_month) / previous_month) * 100
                trend = 'up' if trend_value > 0 else 'down'
            else:
                trend_value = 0
                trend = 'stable'
            
            return {'trend': trend, 'value': round(trend_value, 2)}
        except:
            return {'trend': 'stable', 'value': 0}
    
    @staticmethod
    def _calculate_order_trend():
        """Calculate order trend"""
        try:
            current_month = Order.objects.filter(
                created_at__gte=timezone.now() - timedelta(days=30)
            ).count()
            previous_month = Order.objects.filter(
                created_at__gte=timezone.now() - timedelta(days=60),
                created_at__lt=timezone.now() - timedelta(days=30)
            ).count()
            
            if previous_month > 0:
                trend_value = ((current_month - previous_month) / previous_month) * 100
                trend = 'up' if trend_value > 0 else 'down'
            else:
                trend_value = 0
                trend = 'stable'
            
            return {'trend': trend, 'value': round(trend_value, 2)}
        except:
            return {'trend': 'stable', 'value': 0}
    
    @staticmethod
    def _calculate_revenue_trend():
        """Calculate revenue trend"""
        try:
            current_month = Order.objects.filter(
                status='completed',
                created_at__gte=timezone.now() - timedelta(days=30)
            ).aggregate(total=Sum('total_amount'))['total'] or Decimal('0.00')
            
            previous_month = Order.objects.filter(
                status='completed',
                created_at__gte=timezone.now() - timedelta(days=60),
                created_at__lt=timezone.now() - timedelta(days=30)
            ).aggregate(total=Sum('total_amount'))['total'] or Decimal('0.00')
            
            if previous_month > 0:
                trend_value = ((current_month - previous_month) / previous_month) * 100
                trend = 'up' if trend_value > 0 else 'down'
            else:
                trend_value = 0
                trend = 'stable'
            
            return {'trend': trend, 'value': round(trend_value, 2)}
        except:
            return {'trend': 'stable', 'value': 0}
    
    @staticmethod
    def _calculate_author_trend():
        """Calculate author trend"""
        try:
            current_month = Author.objects.filter(
                created_at__gte=timezone.now() - timedelta(days=30)
            ).count()
            previous_month = Author.objects.filter(
                created_at__gte=timezone.now() - timedelta(days=60),
                created_at__lt=timezone.now() - timedelta(days=30)
            ).count()
            
            if previous_month > 0:
                trend_value = ((current_month - previous_month) / previous_month) * 100
                trend = 'up' if trend_value > 0 else 'down'
            else:
                trend_value = 0
                trend = 'stable'
            
            return {'trend': trend, 'value': round(trend_value, 2)}
        except:
            return {'trend': 'stable', 'value': 0}
    
    @staticmethod
    def _calculate_category_trend():
        """Calculate category trend"""
        try:
            current_month = Category.objects.filter(
                created_at__gte=timezone.now() - timedelta(days=30)
            ).count()
            previous_month = Category.objects.filter(
                created_at__gte=timezone.now() - timedelta(days=60),
                created_at__lt=timezone.now() - timedelta(days=30)
            ).count()
            
            if previous_month > 0:
                trend_value = ((current_month - previous_month) / previous_month) * 100
                trend = 'up' if trend_value > 0 else 'down'
            else:
                trend_value = 0
                trend = 'stable'
            
            return {'trend': trend, 'value': round(trend_value, 2)}
        except:
            return {'trend': 'stable', 'value': 0}
    
    @staticmethod
    def _generate_revenue_trend_data(start_date, end_date):
        """Generate revenue trend data for charts"""
        try:
            trend_data = []
            current_date = start_date
            
            while current_date <= end_date:
                daily_revenue = Order.objects.filter(
                    status='completed',
                    created_at__date=current_date
                ).aggregate(total=Sum('total_amount'))['total'] or Decimal('0.00')
                
                trend_data.append({
                    'date': current_date.isoformat(),
                    'revenue': float(daily_revenue)
                })
                
                current_date += timedelta(days=1)
            
            return trend_data
        except:
            return []
    
    @staticmethod
    def _generate_user_growth_data():
        """Generate user growth data for charts"""
        try:
            growth_data = []
            
            for i in range(12):  # Last 12 months
                month_start = timezone.now().date().replace(day=1) - timedelta(days=30*i)
                month_end = month_start + timedelta(days=30)
                
                monthly_users = User.objects.filter(
                    date_joined__date__range=[month_start, month_end]
                ).count()
                
                growth_data.append({
                    'month': month_start.strftime('%Y-%m'),
                    'users': monthly_users
                })
            
            return growth_data
        except:
            return []

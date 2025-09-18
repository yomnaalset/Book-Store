from rest_framework import generics, status, permissions
from rest_framework.views import APIView
from rest_framework.response import Response
from django.db.models import Count, Sum, Q, F, Max
from django.utils import timezone
from datetime import datetime, timedelta
from decimal import Decimal

from ..models.report_model import Report, ReportTemplate
from ..models.library_model import Book, Library
from ..models.user_model import User
from ..models.delivery_model import Order
from ..models.borrowing_model import BorrowRequest
from ..serializers.report_serializers import (
    ReportSerializer, ReportCreateSerializer, ReportUpdateSerializer,
    ReportListSerializer, ReportTemplateSerializer, ReportTemplateCreateSerializer,
    DashboardStatsSerializer, SalesReportSerializer, UserReportSerializer,
    BookReportSerializer, OrderReportSerializer
)
from ..services.report_services import ReportManagementService
from ..permissions import IsLibraryAdmin
from ..utils import format_error_message
import logging

logger = logging.getLogger(__name__)


class ReportListView(generics.ListCreateAPIView):
    """List and create reports"""
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def get_serializer_class(self):
        if self.request.method == 'POST':
            return ReportCreateSerializer
        return ReportListSerializer
    
    def get_queryset(self):
        return Report.objects.filter(created_by=self.request.user).order_by('-created_at')
    
    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)


class ReportDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Retrieve, update, or delete a report"""
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    serializer_class = ReportSerializer
    
    def get_queryset(self):
        return Report.objects.filter(created_by=self.request.user)


class ReportTemplateListView(generics.ListCreateAPIView):
    """List and create report templates"""
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def get_serializer_class(self):
        if self.request.method == 'POST':
            return ReportTemplateCreateSerializer
        return ReportTemplateSerializer
    
    def get_queryset(self):
        return ReportTemplate.objects.filter(
            Q(created_by=self.request.user) | Q(is_public=True)
        ).order_by('-created_at')
    
    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)


class DashboardStatsView(APIView):
    """Get dashboard statistics"""
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def get(self, request):
        try:
            # Use the service layer
            stats = ReportManagementService.get_dashboard_statistics()
            
            serializer = DashboardStatsSerializer(data=stats)
            serializer.is_valid()
            
            return Response({
                'success': True,
                'message': 'Dashboard statistics retrieved successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error getting dashboard stats: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve dashboard statistics',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class SalesReportView(APIView):
    """Get sales report data"""
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def get(self, request):
        try:
            start_date = request.GET.get('start_date')
            end_date = request.GET.get('end_date')
            period = request.GET.get('period', 'monthly')
            
            # Use the service layer
            data = ReportManagementService.get_sales_report(start_date, end_date, period)
            
            serializer = SalesReportSerializer(data=data)
            serializer.is_valid()
            
            return Response({
                'success': True,
                'message': 'Sales report retrieved successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error getting sales report: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve sales report',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class UserReportView(APIView):
    """Get user report data"""
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def get(self, request):
        try:
            start_date = request.GET.get('start_date')
            end_date = request.GET.get('end_date')
            
            # Use the service layer
            data = ReportManagementService.get_user_report(start_date, end_date)
            
            serializer = UserReportSerializer(data=data)
            serializer.is_valid()
            
            return Response({
                'success': True,
                'message': 'User report retrieved successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error getting user report: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve user report',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class BookReportView(APIView):
    """Get book report data"""
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def get(self, request):
        try:
            # Use the service layer
            data = ReportManagementService.get_book_report()
            
            serializer = BookReportSerializer(data=data)
            serializer.is_valid()
            
            return Response({
                'success': True,
                'message': 'Book report retrieved successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error getting book report: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve book report',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class OrderReportView(APIView):
    """Get order report data"""
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def get(self, request):
        try:
            start_date = request.GET.get('start_date')
            end_date = request.GET.get('end_date')
            status_filter = request.GET.get('status')
            
            # Use the service layer
            data = ReportManagementService.get_order_report(start_date, end_date, status_filter)
            
            serializer = OrderReportSerializer(data=data)
            serializer.is_valid()
            
            return Response({
                'success': True,
                'message': 'Order report retrieved successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error getting order report: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve order report',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class AuthorReportView(APIView):
    """Get author report data"""
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def get(self, request):
        try:
            # Get author statistics from dashboard data
            dashboard_data = ReportManagementService.get_dashboard_statistics()
            
            author_data = {
                'total_authors': dashboard_data.get('total_authors', 0),
                'author_trend': dashboard_data.get('author_trend', {}).get('trend', 'stable'),
                'author_trend_value': dashboard_data.get('author_trend', {}).get('value', 0),
            }
            
            return Response({
                'success': True,
                'data': author_data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error getting author report: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to get author report',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class CategoryReportView(APIView):
    """Get category report data"""
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def get(self, request):
        try:
            # Get category statistics from dashboard data
            dashboard_data = ReportManagementService.get_dashboard_statistics()
            
            category_data = {
                'total_categories': dashboard_data.get('total_categories', 0),
                'category_trend': dashboard_data.get('category_trend', {}).get('trend', 'stable'),
                'category_trend_value': dashboard_data.get('category_trend', {}).get('value', 0),
            }
            
            return Response({
                'success': True,
                'data': category_data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error getting category report: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to get category report',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class RatingReportView(APIView):
    """Get rating report data"""
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def get(self, request):
        try:
            # Get rating statistics from dashboard data
            dashboard_data = ReportManagementService.get_dashboard_statistics()
            
            rating_data = {
                'total_ratings': dashboard_data.get('total_ratings', 0),
                'avg_rating': dashboard_data.get('avg_rating', 0.0),
            }
            
            return Response({
                'success': True,
                'data': rating_data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error getting rating report: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to get rating report',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class FinesReportView(APIView):
    """Get fines report data"""
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def get(self, request):
        try:
            start_date = request.GET.get('start_date')
            end_date = request.GET.get('end_date')
            
            # Convert string dates to datetime objects
            if start_date:
                start_date = datetime.fromisoformat(start_date.replace('Z', '+00:00')).date()
            if end_date:
                end_date = datetime.fromisoformat(end_date.replace('Z', '+00:00')).date()
            
            report_data = ReportManagementService.get_fines_report(start_date, end_date)
            
            return Response({
                'success': True,
                'data': report_data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error getting fines report: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to get fines report',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class BorrowingReportView(APIView):
    """Get borrowing report data"""
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def get(self, request):
        try:
            start_date = request.GET.get('start_date')
            end_date = request.GET.get('end_date')
            period = request.GET.get('period', 'monthly')
            
            # Convert string dates to datetime objects
            if start_date:
                start_date = datetime.fromisoformat(start_date.replace('Z', '+00:00')).date()
            if end_date:
                end_date = datetime.fromisoformat(end_date.replace('Z', '+00:00')).date()
            
            report_data = ReportManagementService.get_borrowing_report(start_date, end_date, period)
            
            return Response({
                'success': True,
                'data': report_data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error getting borrowing report: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to get borrowing report',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class DeliveryReportView(APIView):
    """Get delivery report data"""
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def get(self, request):
        try:
            start_date = request.GET.get('start_date')
            end_date = request.GET.get('end_date')
            
            # Convert string dates to datetime objects
            if start_date:
                start_date = datetime.fromisoformat(start_date.replace('Z', '+00:00')).date()
            if end_date:
                end_date = datetime.fromisoformat(end_date.replace('Z', '+00:00')).date()
            
            report_data = ReportManagementService.get_delivery_report(start_date, end_date)
            
            return Response({
                'success': True,
                'data': report_data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error getting delivery report: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to get delivery report',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
from rest_framework import serializers
from ..models.report_model import Report, ReportTemplate


class ReportSerializer(serializers.ModelSerializer):
    """Serializer for Report model"""
    created_by_name = serializers.CharField(source='created_by.get_full_name', read_only=True)
    report_type_display = serializers.CharField(source='get_report_type_display', read_only=True)
    is_expired = serializers.BooleanField(read_only=True)
    
    class Meta:
        model = Report
        fields = [
            'id', 'report_type', 'title', 'description', 'start_date', 'end_date',
            'data', 'created_by_name', 'created_at', 'updated_at', 'is_generated',
            'report_type_display', 'is_expired'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'created_by_name']


class ReportCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating reports"""
    
    class Meta:
        model = Report
        fields = [
            'report_type', 'title', 'description', 'start_date', 'end_date'
        ]
    
    def validate(self, data):
        start_date = data.get('start_date')
        end_date = data.get('end_date')
        
        if start_date and end_date and start_date > end_date:
            raise serializers.ValidationError("Start date cannot be after end date")
        
        return data


class ReportUpdateSerializer(serializers.ModelSerializer):
    """Serializer for updating reports"""
    
    class Meta:
        model = Report
        fields = ['title', 'description', 'is_generated']


class ReportListSerializer(serializers.ModelSerializer):
    """Simplified serializer for report lists"""
    created_by_name = serializers.CharField(source='created_by.get_full_name', read_only=True)
    report_type_display = serializers.CharField(source='get_report_type_display', read_only=True)
    
    class Meta:
        model = Report
        fields = [
            'id', 'report_type', 'title', 'start_date', 'end_date',
            'created_by_name', 'created_at', 'is_generated', 'report_type_display'
        ]


class ReportTemplateSerializer(serializers.ModelSerializer):
    """Serializer for ReportTemplate model"""
    created_by_name = serializers.CharField(source='created_by.get_full_name', read_only=True)
    report_type_display = serializers.CharField(source='get_report_type_display', read_only=True)
    
    class Meta:
        model = ReportTemplate
        fields = [
            'id', 'name', 'description', 'report_type', 'template_config',
            'created_by_name', 'created_at', 'updated_at', 'is_active', 'is_public',
            'report_type_display'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'created_by_name']


class ReportTemplateCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating report templates"""
    
    class Meta:
        model = ReportTemplate
        fields = ['name', 'description', 'report_type', 'template_config', 'is_public']


class DashboardStatsSerializer(serializers.Serializer):
    """Serializer for dashboard statistics"""
    total_books = serializers.IntegerField()
    available_books = serializers.IntegerField()
    total_users = serializers.IntegerField()
    active_users = serializers.IntegerField()
    total_orders = serializers.IntegerField()
    pending_orders = serializers.IntegerField()
    completed_orders = serializers.IntegerField()
    total_revenue = serializers.DecimalField(max_digits=10, decimal_places=2)
    monthly_revenue = serializers.DecimalField(max_digits=10, decimal_places=2)
    overdue_books = serializers.IntegerField()
    active_borrowings = serializers.IntegerField()
    pending_requests = serializers.IntegerField()
    total_authors = serializers.IntegerField()
    total_categories = serializers.IntegerField()
    total_ratings = serializers.IntegerField()
    avg_rating = serializers.FloatField()
    
    # Trend data
    book_trend = serializers.CharField(allow_null=True)
    book_trend_value = serializers.FloatField(allow_null=True)
    user_trend = serializers.CharField(allow_null=True)
    user_trend_value = serializers.FloatField(allow_null=True)
    order_trend = serializers.CharField(allow_null=True)
    order_trend_value = serializers.FloatField(allow_null=True)
    revenue_trend = serializers.CharField(allow_null=True)
    revenue_trend_value = serializers.FloatField(allow_null=True)
    author_trend = serializers.CharField(allow_null=True)
    author_trend_value = serializers.FloatField(allow_null=True)
    category_trend = serializers.CharField(allow_null=True)
    category_trend_value = serializers.FloatField(allow_null=True)


class SalesReportSerializer(serializers.Serializer):
    """Serializer for sales report data"""
    total_revenue = serializers.DecimalField(max_digits=10, decimal_places=2)
    monthly_revenue = serializers.DecimalField(max_digits=10, decimal_places=2)
    revenue_trend = serializers.CharField(allow_null=True)
    revenue_trend_value = serializers.FloatField(allow_null=True)
    trend = serializers.ListField(child=serializers.DictField())


class UserReportSerializer(serializers.Serializer):
    """Serializer for user report data"""
    total_users = serializers.IntegerField()
    active_users = serializers.IntegerField()
    user_trend = serializers.CharField(allow_null=True)
    user_trend_value = serializers.FloatField(allow_null=True)
    growth = serializers.ListField(child=serializers.DictField())


class BookReportSerializer(serializers.Serializer):
    """Serializer for book report data"""
    total_books = serializers.IntegerField()
    available_books = serializers.IntegerField()
    book_trend = serializers.CharField(allow_null=True)
    book_trend_value = serializers.FloatField(allow_null=True)
    top_selling = serializers.ListField(child=serializers.DictField())
    top_borrowing = serializers.ListField(child=serializers.DictField())


class OrderReportSerializer(serializers.Serializer):
    """Serializer for order report data"""
    total_orders = serializers.IntegerField()
    pending_orders = serializers.IntegerField()
    order_trend = serializers.CharField(allow_null=True)
    order_trend_value = serializers.FloatField(allow_null=True)
    status_distribution = serializers.DictField()

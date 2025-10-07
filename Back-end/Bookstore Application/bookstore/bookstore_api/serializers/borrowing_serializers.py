from rest_framework import serializers
from django.utils import timezone
from datetime import timedelta
from decimal import Decimal
from ..models import (
    BorrowRequest, BorrowExtension, BorrowFine, BorrowStatistics,
    Book, User, BorrowStatusChoices, ExtensionStatusChoices, FineStatusChoices
)


class BorrowRequestCreateSerializer(serializers.ModelSerializer):
    """
    Serializer for creating borrow requests
    """
    book_id = serializers.IntegerField()
    borrow_period_days = serializers.IntegerField(min_value=1, max_value=30)
    delivery_address = serializers.CharField(max_length=500, required=False, allow_blank=True)
    additional_notes = serializers.CharField(required=False, allow_blank=True, max_length=1000)
    
    class Meta:
        model = BorrowRequest
        fields = ['book_id', 'borrow_period_days', 'delivery_address', 'additional_notes']
    
    def validate_book_id(self, value):
        """Validate book exists and is available"""
        try:
            book = Book.objects.get(id=value)
        except Book.DoesNotExist:
            raise serializers.ValidationError("Book not found")
        
        # Check if book has available copies
        current_borrows = BorrowRequest.objects.filter(
            book=book,
            status__in=[
                BorrowStatusChoices.APPROVED,
                BorrowStatusChoices.PENDING_DELIVERY,
                BorrowStatusChoices.ACTIVE,
                BorrowStatusChoices.EXTENDED
            ]
        ).count()
        
        if current_borrows >= book.available_copies:
            raise serializers.ValidationError("No copies available for borrowing")
        
        return value
    
    def validate(self, data):
        """Validate customer hasn't already borrowed this book and has address"""
        customer = self.context['request'].user
        book_id = data['book_id']
        
        # Check if customer has an active borrow for this book
        active_borrow = BorrowRequest.objects.filter(
            customer=customer,
            book_id=book_id,
            status__in=[
                BorrowStatusChoices.PENDING,
                BorrowStatusChoices.APPROVED,
                BorrowStatusChoices.PENDING_DELIVERY,
                BorrowStatusChoices.ACTIVE,
                BorrowStatusChoices.EXTENDED,
                BorrowStatusChoices.RETURN_REQUESTED
            ]
        ).exists()
        
        if active_borrow:
            raise serializers.ValidationError("You already have an active borrow request for this book")
        
        # Validate that customer has an address in their profile
        if not customer.profile.address or customer.profile.address.strip() == '':
            raise serializers.ValidationError("You must add an address to your profile before submitting a borrow request.")
        
        return data
    
    def create(self, validated_data):
        book_id = validated_data.pop('book_id')
        book = Book.objects.get(id=book_id)
        customer = self.context['request'].user
        
        # Automatically populate delivery address from user's profile
        validated_data['delivery_address'] = customer.profile.address
        
        borrow_request = BorrowRequest.objects.create(
            customer=customer,
            book=book,
            **validated_data
        )
        
        return borrow_request


class BookBasicSerializer(serializers.ModelSerializer):
    """Basic book info for borrowing contexts"""
    author_name = serializers.CharField(source='author.name', read_only=True)
    
    class Meta:
        model = Book
        fields = ['id', 'name', 'author_name', 'category']


class CustomerBasicSerializer(serializers.ModelSerializer):
    """Basic customer info for borrowing contexts"""
    full_name = serializers.CharField(source='get_full_name', read_only=True)
    
    class Meta:
        model = User
        fields = ['id', 'email', 'full_name']


class BorrowRequestListSerializer(serializers.ModelSerializer):
    """
    Serializer for listing borrow requests
    """
    book = BookBasicSerializer(read_only=True)
    customer = CustomerBasicSerializer(read_only=True)
    book_title = serializers.CharField(source='book.name', read_only=True)
    customer_name = serializers.CharField(source='customer.get_full_name', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    days_remaining = serializers.ReadOnlyField()
    days_overdue = serializers.ReadOnlyField()
    can_extend = serializers.ReadOnlyField()
    can_rate = serializers.ReadOnlyField()
    
    class Meta:
        model = BorrowRequest
        fields = [
            'id', 'book', 'book_title', 'customer', 'customer_name', 'status', 'status_display',
            'borrow_period_days', 'delivery_address', 'additional_notes',
            'request_date', 'expected_return_date', 'final_return_date', 
            'delivery_date', 'actual_return_date', 'days_remaining', 
            'days_overdue', 'can_extend', 'can_rate'
        ]


class BorrowRequestDetailSerializer(BorrowRequestListSerializer):
    """
    Detailed serializer for borrow requests
    """
    approved_by = CustomerBasicSerializer(read_only=True)
    delivery_person = CustomerBasicSerializer(read_only=True)
    timeline = serializers.SerializerMethodField()
    
    class Meta(BorrowRequestListSerializer.Meta):
        fields = BorrowRequestListSerializer.Meta.fields + [
            'approved_by', 'approved_date', 'rejection_reason',
            'pickup_date', 'delivery_person', 'delivery_notes',
            'timeline'
        ]
    
    def get_timeline(self, obj):
        """Generate timeline of borrow request events"""
        timeline = []
        
        # Request submitted
        timeline.append({
            'status': 'pending',
            'date': obj.request_date,
            'description': 'Request submitted'
        })
        
        # Approval/Rejection
        if obj.approved_date:
            timeline.append({
                'status': 'approved',
                'date': obj.approved_date,
                'description': f'Approved by {obj.approved_by.get_full_name() if obj.approved_by else "Library Manager"}'
            })
        elif obj.status == BorrowStatusChoices.REJECTED:
            timeline.append({
                'status': 'rejected',
                'date': obj.updated_at,
                'description': 'Request rejected'
            })
        
        # Pickup
        if obj.pickup_date:
            timeline.append({
                'status': 'on_delivery',
                'date': obj.pickup_date,
                'description': 'Book picked up for delivery'
            })
        
        # Delivery
        if obj.delivery_date:
            timeline.append({
                'status': 'active',
                'date': obj.delivery_date,
                'description': 'Book delivered to customer'
            })
        
        # Extension
        if obj.status == BorrowStatusChoices.EXTENDED:
            timeline.append({
                'status': 'extended',
                'date': obj.updated_at,
                'description': 'Borrowing extended'
            })
        
        # Actual return
        if obj.actual_return_date:
            timeline.append({
                'status': 'returned',
                'date': obj.actual_return_date,
                'description': 'Book returned'
            })
        
        return timeline


class BorrowApprovalSerializer(serializers.Serializer):
    """
    Serializer for approving/rejecting borrow requests
    """
    action = serializers.ChoiceField(choices=['approve', 'reject'])
    rejection_reason = serializers.CharField(required=False, allow_blank=True)
    delivery_manager_id = serializers.IntegerField(required=False, allow_null=True)
    
    def validate(self, data):
        if data['action'] == 'reject' and not data.get('rejection_reason'):
            raise serializers.ValidationError({
                'rejection_reason': 'Rejection reason is required when rejecting a request'
            })
        
        if data['action'] == 'approve' and not data.get('delivery_manager_id'):
            raise serializers.ValidationError({
                'delivery_manager_id': 'Delivery manager must be selected when approving a request'
            })
        
        # Validate delivery manager if provided
        if data.get('delivery_manager_id'):
            from ..models import User
            try:
                delivery_manager = User.objects.get(
                    id=data['delivery_manager_id'],
                    user_type='delivery_admin',
                    is_active=True
                )
                # Check if delivery manager is available (online)
                if hasattr(delivery_manager, 'delivery_profile'):
                    if delivery_manager.delivery_profile.delivery_status not in ['online']:
                        raise serializers.ValidationError({
                            'delivery_manager_id': 'Selected delivery manager is not available (must be online)'
                        })
                else:
                    raise serializers.ValidationError({
                        'delivery_manager_id': 'Selected delivery manager does not have a delivery profile'
                    })
            except User.DoesNotExist:
                raise serializers.ValidationError({
                    'delivery_manager_id': 'Invalid delivery manager selected'
                })
        
        return data


class BorrowExtensionCreateSerializer(serializers.ModelSerializer):
    """
    Serializer for creating extension requests
    """
    additional_days = serializers.IntegerField(min_value=Decimal('1'), max_value=Decimal('14'))
    
    class Meta:
        model = BorrowExtension
        fields = ['additional_days']
    
    def validate(self, data):
        borrow_request = self.context['borrow_request']
        
        # Check if borrow can be extended
        if not borrow_request.can_extend:
            raise serializers.ValidationError("This borrowing cannot be extended")
        
        return data
    
    def create(self, validated_data):
        borrow_request = self.context['borrow_request']
        
        extension = BorrowExtension.objects.create(
            borrow_request=borrow_request,
            **validated_data
        )
        
        # Update borrow request
        borrow_request.status = BorrowStatusChoices.EXTENDED
        borrow_request.save()
        
        return extension


class BorrowExtensionSerializer(serializers.ModelSerializer):
    """
    Serializer for extension details
    """
    borrow_request = BorrowRequestListSerializer(read_only=True)
    approved_by = CustomerBasicSerializer(read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    
    class Meta:
        model = BorrowExtension
        fields = [
            'id', 'borrow_request', 'additional_days', 'status', 'status_display',
            'request_date', 'approved_by', 'approved_date', 'rejection_reason'
        ]


class BorrowFineSerializer(serializers.ModelSerializer):
    """
    Serializer for fine details
    """
    borrow_request = BorrowRequestListSerializer(read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    
    class Meta:
        model = BorrowFine
        fields = [
            'id', 'borrow_request', 'daily_rate', 'days_overdue', 'total_amount',
            'status', 'status_display', 'created_date', 'paid_date', 'payment_reference'
        ]


class BorrowRatingSerializer(serializers.Serializer):
    """
    Serializer for rating borrowing experience
    """
    rating = serializers.IntegerField(min_value=Decimal('1'), max_value=Decimal('5'))
    comment = serializers.CharField(required=False, allow_blank=True, max_length=1000)
    
    def validate(self, data):
        borrow_request = self.context['borrow_request']
        
        if not borrow_request.can_rate:
            raise serializers.ValidationError("This borrowing experience cannot be rated")
        
        return data


class EarlyReturnSerializer(serializers.Serializer):
    """
    Serializer for early return requests
    """
    return_reason = serializers.CharField(required=False, allow_blank=True, max_length=500)


class DeliveryUpdateSerializer(serializers.Serializer):
    """
    Serializer for delivery status updates
    """
    delivery_notes = serializers.CharField(required=False, allow_blank=True, max_length=500)
    collection_notes = serializers.CharField(required=False, allow_blank=True, max_length=500)


class BorrowStatisticsSerializer(serializers.ModelSerializer):
    """
    Serializer for borrowing statistics
    """
    book = BookBasicSerializer(read_only=True)
    
    class Meta:
        model = BorrowStatistics
        fields = [
            'id', 'book', 'total_borrows', 'current_borrows',
            'average_rating', 'total_ratings', 'last_borrowed'
        ]


class MostBorrowedBookSerializer(serializers.ModelSerializer):
    """
    Serializer for most borrowed books
    """
    author_name = serializers.CharField(source='author.name', read_only=True)
    borrow_count = serializers.IntegerField(source='borrow_stats.total_borrows', read_only=True)
    available_copies = serializers.SerializerMethodField()
    is_available = serializers.SerializerMethodField()
    average_rating = serializers.DecimalField(
        source='borrow_stats.average_rating',
        max_digits=3,
        decimal_places=2,
        read_only=True
    )
    
    class Meta:
        model = Book
        fields = [
            'id', 'name', 'author_name', 'quantity',
            'borrow_count', 'available_copies', 'is_available',
            'average_rating', 'description'
        ]
    
    def get_available_copies(self, obj):
        """Calculate available copies"""
        current_borrows = BorrowRequest.objects.filter(
            book=obj,
            status__in=[
                BorrowStatusChoices.APPROVED,
                BorrowStatusChoices.PENDING_DELIVERY,
                BorrowStatusChoices.ACTIVE,
                BorrowStatusChoices.EXTENDED
            ]
        ).count()
        return max(0, obj.quantity - current_borrows)
    
    def get_is_available(self, obj):
        """Check if book is available for borrowing"""
        return self.get_available_copies(obj) > 0


class BorrowingReportSerializer(serializers.Serializer):
    """
    Serializer for borrowing reports
    """
    total_borrows = serializers.IntegerField()
    active_borrows = serializers.IntegerField()
    overdue_borrows = serializers.IntegerField()
    average_rating = serializers.DecimalField(max_digits=3, decimal_places=2)
    total_ratings = serializers.IntegerField()
    rating_distribution = serializers.DictField()
    total_fines = serializers.DecimalField(max_digits=10, decimal_places=2)
    paid_fines = serializers.DecimalField(max_digits=10, decimal_places=2)
    unpaid_fines = serializers.DecimalField(max_digits=10, decimal_places=2)


class PendingRequestsSerializer(serializers.ModelSerializer):
    """
    Serializer for library manager's pending requests view
    """
    book_title = serializers.CharField(source='book.name', read_only=True)
    customer_name = serializers.CharField(source='customer.get_full_name', read_only=True)
    customer_email = serializers.CharField(source='customer.email', read_only=True)
    
    class Meta:
        model = BorrowRequest
        fields = [
            'id', 'book_title', 'customer_name', 'customer_email',
            'request_date', 'borrow_period_days', 'expected_return_date', 'status'
        ]


class DeliveryReadySerializer(serializers.ModelSerializer):
    """
    Serializer for delivery manager's ready for delivery view
    """
    book_title = serializers.CharField(source='book.name', read_only=True)
    customer_name = serializers.CharField(source='customer.get_full_name', read_only=True)
    customer_address = serializers.SerializerMethodField()
    pickup_location = serializers.CharField(default="Main Library", read_only=True)
    
    class Meta:
        model = BorrowRequest
        fields = [
            'id', 'book_title', 'customer_name', 'customer_address',
            'pickup_location', 'approved_date', 'expected_return_date', 'status'
        ]
    
    def get_customer_address(self, obj):
        """Get customer address from profile"""
        profile = getattr(obj.customer, 'profile', None)
        if profile and profile.address:
            return f"{profile.address}, {profile.city or ''}"
        return "Address not provided"


class DeliveryManagerSerializer(serializers.ModelSerializer):
    """
    Serializer for delivery manager selection in admin approval
    """
    full_name = serializers.CharField(source='get_full_name', read_only=True)
    delivery_status = serializers.CharField(source='delivery_profile.delivery_status', read_only=True)
    status_display = serializers.CharField(source='delivery_profile.get_delivery_status_display', read_only=True)
    is_available = serializers.SerializerMethodField()
    status_color = serializers.SerializerMethodField()
    
    class Meta:
        model = User
        fields = [
            'id', 'full_name', 'email', 'delivery_status', 
            'status_display', 'is_available', 'status_color'
        ]
    
    def get_is_available(self, obj):
        """Check if delivery manager is available for assignment"""
        if hasattr(obj, 'delivery_profile'):
            return obj.delivery_profile.delivery_status == 'online'
        return False
    
    def get_status_color(self, obj):
        """Get color code for delivery manager status"""
        if hasattr(obj, 'delivery_profile'):
            status = obj.delivery_profile.delivery_status
            if status == 'online':
                return 'green'
            elif status == 'busy':
                return 'orange'
            elif status == 'offline':
                return 'red'
        return 'gray'
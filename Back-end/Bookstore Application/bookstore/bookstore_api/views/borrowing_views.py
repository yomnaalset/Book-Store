from rest_framework import generics, status, permissions
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from django.shortcuts import get_object_or_404
from django.db.models import Q
from django.utils import timezone, translation

from ..models import (
    BorrowRequest, BorrowExtension, BorrowFine, BorrowStatistics,
    Book, User, BorrowStatusChoices
)
from ..serializers.borrowing_serializers import (
    BorrowRequestCreateSerializer, BorrowRequestListSerializer, BorrowRequestDetailSerializer,
    BorrowApprovalSerializer, BorrowExtensionCreateSerializer, BorrowExtensionSerializer,
    BorrowFineSerializer, BorrowRatingSerializer, EarlyReturnSerializer,
    DeliveryUpdateSerializer, MostBorrowedBookSerializer, BorrowingReportSerializer,
    PendingRequestsSerializer, DeliveryReadySerializer
)
from ..services.borrowing_services import (
    BorrowingService, BorrowingNotificationService, BorrowingReportService
)
from ..permissions import IsCustomer, IsLibraryAdmin, IsDeliveryAdmin, IsAnyAdmin, CustomerOrAdmin
from ..utils import format_error_message
import logging

logger = logging.getLogger(__name__)


class MostBorrowedBooksView(generics.ListAPIView):
    """
    API view to get most borrowed books
    """
    serializer_class = MostBorrowedBookSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        """Get most borrowed books"""
        return BorrowingService.get_most_borrowed_books(limit=20)
    
    def list(self, request, *args, **kwargs):
        try:
            queryset = self.get_queryset()
            serializer = self.get_serializer(queryset, many=True)
            
            return Response({
                'success': True,
                'message': 'Most borrowed books retrieved successfully',
                'data': serializer.data,
                'pagination': {
                    'page': 1,
                    'per_page': 20,
                    'total': queryset.count(),
                    'total_pages': 1
                }
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving most borrowed books: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve most borrowed books',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class BorrowRequestCreateView(generics.CreateAPIView):
    """
    API view for customers to create borrow requests
    """
    serializer_class = BorrowRequestCreateSerializer
    permission_classes = [permissions.IsAuthenticated, IsCustomer]
    
    def create(self, request, *args, **kwargs):
        try:
            serializer = self.get_serializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            
            book_id = serializer.validated_data['book_id']
            book = get_object_or_404(Book, id=book_id)
            
            borrow_request = BorrowingService.create_borrow_request(
                customer=request.user,
                book=book,
                borrow_period_days=serializer.validated_data['borrow_period_days']
            )
            
            response_serializer = BorrowRequestDetailSerializer(borrow_request)
            
            return Response({
                'success': True,
                'message': 'Borrowing request submitted successfully',
                'data': response_serializer.data
            }, status=status.HTTP_201_CREATED)
            
        except Exception as e:
            logger.error(f"Error creating borrow request: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to create borrowing request',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_400_BAD_REQUEST)


class CustomerBorrowingsView(generics.ListAPIView):
    """
    API view for customers to view their borrowings
    """
    serializer_class = BorrowRequestListSerializer
    permission_classes = [permissions.IsAuthenticated, CustomerOrAdmin]
    
    def get_queryset(self):
        """Get customer's borrowings"""
        status_filter = self.request.query_params.get('status')
        return BorrowingService.get_customer_borrowings(
            customer=self.request.user,
            status=status_filter
        )
    
    def list(self, request, *args, **kwargs):
        try:
            queryset = self.get_queryset()
            serializer = self.get_serializer(queryset, many=True)
            
            return Response({
                'success': True,
                'message': 'Customer borrowings retrieved successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving customer borrowings: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve borrowings',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class BorrowRequestDetailView(generics.RetrieveAPIView):
    """
    API view for viewing borrow request details
    """
    serializer_class = BorrowRequestDetailSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_object(self):
        """Get borrow request object with permission check"""
        borrow_id = self.kwargs.get('pk')
        borrow_request = get_object_or_404(BorrowRequest, id=borrow_id)
        
        # Check permissions
        if (borrow_request.customer != self.request.user and 
            not self.request.user.is_library_admin() and 
            not self.request.user.is_delivery_admin()):
            raise PermissionError("You don't have permission to view this borrowing")
        
        return borrow_request
    
    def retrieve(self, request, *args, **kwargs):
        try:
            instance = self.get_object()
            serializer = self.get_serializer(instance)
            
            return Response({
                'success': True,
                'message': 'Borrowing details retrieved successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except PermissionError as e:
            return Response({
                'success': False,
                'message': 'Permission denied',
                'errors': {'permission': [str(e)]}
            }, status=status.HTTP_403_FORBIDDEN)
        except Exception as e:
            logger.error(f"Error retrieving borrowing details: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve borrowing details',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class PendingRequestsView(generics.ListAPIView):
    """
    API view for library managers to view pending requests
    """
    serializer_class = PendingRequestsSerializer
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def get_queryset(self):
        """Get pending borrow requests with optional search"""
        search_query = self.request.query_params.get('search', None)
        return BorrowingService.get_pending_requests(search=search_query)
    
    def list(self, request, *args, **kwargs):
        try:
            queryset = self.get_queryset()
            serializer = self.get_serializer(queryset, many=True)
            
            return Response({
                'success': True,
                'message': 'Pending requests retrieved successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving pending requests: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve pending requests',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class BorrowApprovalView(APIView):
    """
    API view for library managers to approve/reject borrow requests
    """
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def patch(self, request, pk):
        try:
            borrow_request = get_object_or_404(BorrowRequest, id=pk)
            
            if borrow_request.status != BorrowStatusChoices.PENDING:
                return Response({
                    'success': False,
                    'message': 'Only pending requests can be approved/rejected',
                    'errors': {'status': ['Request is not in pending status']}
                }, status=status.HTTP_400_BAD_REQUEST)
            
            serializer = BorrowApprovalSerializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            
            action = serializer.validated_data['action']
            
            if action == 'approve':
                borrow_request = BorrowingService.approve_borrow_request(
                    borrow_request=borrow_request,
                    approved_by=request.user
                )
                message = 'Borrowing request approved successfully'
            else:
                rejection_reason = serializer.validated_data.get('rejection_reason', '')
                borrow_request = BorrowingService.reject_borrow_request(
                    borrow_request=borrow_request,
                    rejection_reason=rejection_reason
                )
                message = 'Borrowing request rejected'
            
            response_serializer = BorrowRequestDetailSerializer(borrow_request)
            
            return Response({
                'success': True,
                'message': message, # TODO: translate this message  
                'data': response_serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error processing approval: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to process request',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_400_BAD_REQUEST)


class DeliveryReadyView(generics.ListAPIView):
    """
    API view for delivery managers to view ready for delivery orders
    """
    serializer_class = DeliveryReadySerializer
    permission_classes = [permissions.IsAuthenticated, IsDeliveryAdmin]
    
    def get_queryset(self):
        """Get orders ready for delivery"""
        return BorrowingService.get_ready_for_delivery()
    
    def list(self, request, *args, **kwargs):
        try:
            queryset = self.get_queryset()
            serializer = self.get_serializer(queryset, many=True)
            
            return Response({
                'success': True,
                'message': 'Ready for delivery orders retrieved successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving delivery orders: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve delivery orders',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class DeliveryPickupView(APIView):
    """
    API view for delivery managers to mark books as picked up
    """
    permission_classes = [permissions.IsAuthenticated, IsDeliveryAdmin]
    
    def patch(self, request, pk):
        try:
            borrow_request = get_object_or_404(BorrowRequest, id=pk)
            
            if borrow_request.status != BorrowStatusChoices.APPROVED:
                return Response({
                    'success': False,
                    'message': 'Only approved requests can be picked up',
                    'errors': {'status': ['Request is not approved']}
                }, status=status.HTTP_400_BAD_REQUEST)
            
            borrow_request = BorrowingService.start_delivery(
                borrow_request=borrow_request,
                delivery_person=request.user
            )
            
            response_serializer = BorrowRequestDetailSerializer(borrow_request)
            
            return Response({
                'success': True,
                'message': 'Book picked up for delivery',
                'data': response_serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error processing pickup: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to process pickup',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_400_BAD_REQUEST)


class DeliveryCompleteView(APIView):
    """
    API view for delivery managers to mark books as delivered
    """
    permission_classes = [permissions.IsAuthenticated, IsDeliveryAdmin]
    
    def patch(self, request, pk):
        try:
            borrow_request = get_object_or_404(BorrowRequest, id=pk)
            
            if borrow_request.status != BorrowStatusChoices.ON_DELIVERY:
                return Response({
                    'success': False,
                    'message': 'Only books on delivery can be marked as delivered',
                    'errors': {'status': ['Book is not on delivery']}
                }, status=status.HTTP_400_BAD_REQUEST)
            
            serializer = DeliveryUpdateSerializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            
            delivery_notes = serializer.validated_data.get('delivery_notes', '')
            
            borrow_request = BorrowingService.mark_delivered(
                borrow_request=borrow_request,
                delivery_notes=delivery_notes
            )
            
            response_serializer = BorrowRequestDetailSerializer(borrow_request)
            
            return Response({
                'success': True,
                'message': 'Book delivered successfully',
                'data': response_serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error completing delivery: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to complete delivery',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_400_BAD_REQUEST)


class BorrowingExtensionView(APIView):
    """
    API view for customers to request borrowing extensions
    """
    permission_classes = [permissions.IsAuthenticated, IsCustomer]
    
    def post(self, request, pk):
        try:
            borrow_request = get_object_or_404(BorrowRequest, id=pk, customer=request.user)
            
            serializer = BorrowExtensionCreateSerializer(
                data=request.data,
                context={'borrow_request': borrow_request}
            )
            serializer.is_valid(raise_exception=True)
            
            extension = BorrowingService.request_extension(
                borrow_request=borrow_request,
                additional_days=serializer.validated_data['additional_days']
            )
            
            response_serializer = BorrowRequestDetailSerializer(borrow_request)
            
            return Response({
                'success': True,
                'message': 'Borrowing extension requested successfully',
                'data': response_serializer.data
            }, status=status.HTTP_200_OK)
            
        except ValueError as e:
            return Response({
                'success': False,
                'message': 'Extension not allowed',
                'errors': {'extension': [str(e)]}
            }, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error(f"Error requesting extension: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to request extension',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_400_BAD_REQUEST)


class EarlyReturnView(APIView):
    """
    API view for customers to request early return
    """
    permission_classes = [permissions.IsAuthenticated, IsCustomer]
    
    def post(self, request, pk):
        try:
            borrow_request = get_object_or_404(BorrowRequest, id=pk, customer=request.user)
            
            if borrow_request.status not in [BorrowStatusChoices.ACTIVE, BorrowStatusChoices.EXTENDED]:
                return Response({
                    'success': False,
                    'message': 'Early return not available',
                    'errors': {'status': ['Book is not currently active']}
                }, status=status.HTTP_400_BAD_REQUEST)
            
            serializer = EarlyReturnSerializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            
            return_reason = serializer.validated_data.get('return_reason', '')
            
            borrow_request = BorrowingService.request_early_return(
                borrow_request=borrow_request,
                return_reason=return_reason
            )
            
            response_serializer = BorrowRequestDetailSerializer(borrow_request)
            
            return Response({
                'success': True,
                'message': 'Early return requested successfully',
                'data': response_serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error requesting early return: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to request early return',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_400_BAD_REQUEST)


class BookCollectionView(APIView):
    """
    API view for delivery managers to collect returned books
    """
    permission_classes = [permissions.IsAuthenticated, IsDeliveryAdmin]
    
    def patch(self, request, pk):
        try:
            borrow_request = get_object_or_404(BorrowRequest, id=pk)
            
            if borrow_request.status != BorrowStatusChoices.RETURN_REQUESTED:
                return Response({
                    'success': False,
                    'message': 'Book collection not available',
                    'errors': {'status': ['Early return not requested']}
                }, status=status.HTTP_400_BAD_REQUEST)
            
            serializer = DeliveryUpdateSerializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            
            collection_notes = serializer.validated_data.get('collection_notes', '')
            
            borrow_request = BorrowingService.complete_return(
                borrow_request=borrow_request,
                collection_notes=collection_notes
            )
            
            response_serializer = BorrowRequestDetailSerializer(borrow_request)
            
            return Response({
                'success': True,
                'message': 'Book collected for early return',
                'data': response_serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error collecting book: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to collect book',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_400_BAD_REQUEST)


class BorrowRatingView(APIView):
    """
    API view for customers to rate borrowing experience
    """
    permission_classes = [permissions.IsAuthenticated, IsCustomer]
    
    def post(self, request, pk):
        try:
            borrow_request = get_object_or_404(BorrowRequest, id=pk, customer=request.user)
            
            serializer = BorrowRatingSerializer(
                data=request.data,
                context={'borrow_request': borrow_request}
            )
            serializer.is_valid(raise_exception=True)
            
            borrow_request = BorrowingService.add_rating(
                borrow_request=borrow_request,
                rating=serializer.validated_data['rating'],
                comment=serializer.validated_data.get('comment', '')
            )
            
            response_serializer = BorrowRequestDetailSerializer(borrow_request)
            
            return Response({
                'success': True,
                'message': 'Rating submitted successfully',
                'data': response_serializer.data
            }, status=status.HTTP_200_OK)
            
        except ValueError as e:
            return Response({
                'success': False,
                'message': 'Rating not allowed',
                'errors': {'rating': [str(e)]}
            }, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error(f"Error submitting rating: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to submit rating',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_400_BAD_REQUEST)


class BorrowCancelView(APIView):
    """
    API view for customers to cancel pending requests
    """
    permission_classes = [permissions.IsAuthenticated, IsCustomer]
    
    def delete(self, request, pk):
        try:
            borrow_request = get_object_or_404(BorrowRequest, id=pk, customer=request.user)
            
            borrow_request = BorrowingService.cancel_request(borrow_request)
            
            response_serializer = BorrowRequestDetailSerializer(borrow_request)
            
            return Response({
                'success': True,
                'message': 'Borrowing request cancelled successfully',
                'data': response_serializer.data
            }, status=status.HTTP_200_OK)
            
        except ValueError as e:
            return Response({
                'success': False,
                'message': 'Cannot cancel request',
                'errors': {'status': [str(e)]}
            }, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error(f"Error cancelling request: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to cancel request',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_400_BAD_REQUEST)


class OverdueBorrowingsView(generics.ListAPIView):
    """
    API view for library managers to view overdue borrowings
    """
    serializer_class = BorrowRequestListSerializer
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def get_queryset(self):
        """Get overdue borrowings"""
        return BorrowingService.get_overdue_borrowings()
    
    def list(self, request, *args, **kwargs):
        try:
            queryset = self.get_queryset()
            serializer = self.get_serializer(queryset, many=True)
            
            return Response({
                'success': True,
                'message': 'Overdue borrowings retrieved successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving overdue borrowings: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve overdue borrowings',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class BorrowFineDetailView(generics.RetrieveAPIView):
    """
    API view for viewing fine details
    """
    serializer_class = BorrowFineSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_object(self):
        """Get fine object with permission check"""
        borrow_id = self.kwargs.get('pk')
        borrow_request = get_object_or_404(BorrowRequest, id=borrow_id)
        
        # Check permissions
        if (borrow_request.customer != self.request.user and 
            not self.request.user.is_library_admin()):
            raise PermissionError("You don't have permission to view this fine")
        
        try:
            fine = BorrowFine.objects.get(borrow_request=borrow_request)
            return fine
        except BorrowFine.DoesNotExist:
            # Return None if no fine exists - this is handled in retrieve method
            return None
    
    def retrieve(self, request, *args, **kwargs):
        try:
            instance = self.get_object()
            
            # Handle case where no fine exists
            if instance is None:
                return Response({
                    'success': False,
                    'message': 'No fine found for this borrowing',
                    'errors': {'fine': ['This borrowing does not have any fines. The book was likely returned on time.']}
                }, status=status.HTTP_404_NOT_FOUND)
            
            serializer = self.get_serializer(instance)
            
            return Response({
                'success': True,
                'message': 'Fine details retrieved successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except PermissionError as e:
            return Response({
                'success': False,
                'message': 'Permission denied',
                'errors': {'permission': [str(e)]}
            }, status=status.HTTP_403_FORBIDDEN)
        except Exception as e:
            logger.error(f"Error retrieving fine details: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve fine details',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class BorrowingReportView(APIView):
    """
    API view for library managers to view borrowing reports
    """
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def get(self, request):
        try:
            statistics = BorrowingReportService.get_borrowing_statistics()
            recent_ratings = BorrowingReportService.get_recent_ratings()
            
            recent_ratings_data = BorrowRequestListSerializer(recent_ratings, many=True).data
            
            report_data = {
                **statistics,
                'recent_ratings': recent_ratings_data
            }
            
            serializer = BorrowingReportSerializer(data=report_data)
            serializer.is_valid()
            
            return Response({
                'success': True,
                'message': 'Borrowing report retrieved successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error generating borrowing report: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to generate report',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class BorrowStatisticsView(APIView):
    """
    API view to get borrowing statistics for the current user
    """
    permission_classes = [permissions.IsAuthenticated, CustomerOrAdmin]
    
    def get(self, request):
        try:
            user = request.user
            
            # Get user's borrowing statistics
            total_borrowings = BorrowRequest.objects.filter(customer=user).count()
            active_borrowings = BorrowRequest.objects.filter(
                customer=user, 
                status__in=['approved', 'delivered']
            ).count()
            overdue_borrowings = BorrowRequest.objects.filter(
                customer=user,
                status='delivered',
                expected_return_date__lt=timezone.now()
            ).count()
            pending_requests = BorrowRequest.objects.filter(
                customer=user,
                status='pending'
            ).count()
            
            statistics = {
                'total': total_borrowings,
                'active': active_borrowings,
                'overdue': overdue_borrowings,
                'pending': pending_requests
            }
            
            return Response({
                'success': True,
                'message': 'Borrowing statistics retrieved successfully',
                'data': statistics
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error getting borrowing statistics: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to get statistics',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class BorrowExtensionsListView(generics.ListAPIView):
    """
    API view for library managers to view all borrowing extensions
    """
    serializer_class = BorrowExtensionSerializer
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def get_queryset(self):
        """Get all borrowing extensions with optional filtering"""
        queryset = BorrowExtension.objects.select_related(
            'borrow_request__customer',
            'borrow_request__book'
        ).order_by('-created_at')
        
        # Filter by status if provided
        status_filter = self.request.query_params.get('status')
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        
        return queryset
    
    def list(self, request, *args, **kwargs):
        try:
            queryset = self.get_queryset()
            
            # Apply pagination
            page = int(request.query_params.get('page', 1))
            limit = int(request.query_params.get('limit', 10))
            
            start = (page - 1) * limit
            end = start + limit
            
            paginated_queryset = queryset[start:end]
            serializer = self.get_serializer(paginated_queryset, many=True)
            
            return Response({
                'success': True,
                'message': 'Borrowing extensions retrieved successfully',
                'data': serializer.data,
                'pagination': {
                    'page': page,
                    'limit': limit,
                    'total': queryset.count(),
                    'has_next': end < queryset.count(),
                    'has_previous': page > 1
                }
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving borrowing extensions: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve borrowing extensions',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class BorrowFinesListView(generics.ListAPIView):
    """
    API view for library managers to view all borrowing fines
    """
    serializer_class = BorrowFineSerializer
    permission_classes = [permissions.IsAuthenticated, IsLibraryAdmin]
    
    def get_queryset(self):
        """Get all borrowing fines with optional filtering"""
        queryset = BorrowFine.objects.select_related(
            'borrow_request__customer',
            'borrow_request__book'
        ).order_by('-created_at')
        
        # Filter by status if provided
        status_filter = self.request.query_params.get('status')
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        
        return queryset
    
    def list(self, request, *args, **kwargs):
        try:
            queryset = self.get_queryset()
            
            # Apply pagination
            page = int(request.query_params.get('page', 1))
            limit = int(request.query_params.get('limit', 10))
            
            start = (page - 1) * limit
            end = start + limit
            
            paginated_queryset = queryset[start:end]
            serializer = self.get_serializer(paginated_queryset, many=True)
            
            return Response({
                'success': True,
                'message': 'Borrowing fines retrieved successfully',
                'data': serializer.data,
                'pagination': {
                    'page': page,
                    'limit': limit,
                    'total': queryset.count(),
                    'has_next': end < queryset.count(),
                    'has_previous': page > 1
                }
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving borrowing fines: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve borrowing fines',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.pagination import PageNumberPagination
from django.core.exceptions import ValidationError, PermissionDenied
from django.db.models import Q
import logging

from ..models.ad_model import Advertisement, AdvertisementStatusChoices
from ..serializers.ad_serializers import (
    AdvertisementCreateSerializer,
    AdvertisementUpdateSerializer,
    AdvertisementDetailSerializer,
    AdvertisementListSerializer,
    AdvertisementStatusUpdateSerializer,
    AdvertisementStatsSerializer,
    AdvertisementPublicSerializer,
    AdvertisementBulkStatusUpdateSerializer
)
from ..services.ad_services import (
    AdvertisementManagementService,
    AdvertisementStatusService,
    AdvertisementAnalyticsService,
    AdvertisementSchedulingService
)
from ..permissions import IsLibraryAdmin, IsSystemAdmin

logger = logging.getLogger(__name__)


class AdvertisementPagination(PageNumberPagination):
    """Custom pagination for advertisements"""
    page_size = 20
    page_size_query_param = 'page_size'
    max_page_size = 100


@api_view(['POST'])
@permission_classes([IsAuthenticated, IsLibraryAdmin])
def create_advertisement(request):
    """
    Create a new advertisement
    POST /ads/create/
    """
    try:
        logger.info(f"Creating advertisement with data: {request.data}")
        serializer = AdvertisementCreateSerializer(data=request.data)
        if serializer.is_valid():
            advertisement = AdvertisementManagementService.create_advertisement(
                serializer.validated_data, 
                request.user
            )
            
            response_serializer = AdvertisementDetailSerializer(
                advertisement, 
                context={'request': request}
            )
            
            logger.info(f"Advertisement '{advertisement.title}' created by {request.user.username}")
            return Response(response_serializer.data, status=status.HTTP_201_CREATED)
        
        logger.error(f"Advertisement creation validation failed: {serializer.errors}")
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        
    except PermissionDenied as e:
        return Response({'error': str(e)}, status=status.HTTP_403_FORBIDDEN)
    except ValidationError as e:
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        logger.error(f"Error creating advertisement: {str(e)}")
        return Response(
            {'error': 'Failed to create advertisement'}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsLibraryAdmin])
def list_advertisements(request):
    """
    List all advertisements with optional filtering
    GET /ads/
    """
    try:
        # Get query parameters
        status_filter = request.query_params.get('status')
        created_by = request.query_params.get('created_by')
        search = request.query_params.get('search')
        ordering = request.query_params.get('ordering', '-created_at')
        
        # Get advertisements
        advertisements = AdvertisementManagementService.list_advertisements(
            user=request.user,
            status=status_filter,
            created_by=created_by,
            search=search,
            ordering=ordering
        )
        
        # Apply pagination
        paginator = AdvertisementPagination()
        page = paginator.paginate_queryset(advertisements, request)
        
        if page is not None:
            serializer = AdvertisementListSerializer(
                page, 
                many=True, 
                context={'request': request}
            )
            return paginator.get_paginated_response(serializer.data)
        
        serializer = AdvertisementListSerializer(
            advertisements, 
            many=True, 
            context={'request': request}
        )
        return Response(serializer.data)
        
    except Exception as e:
        logger.error(f"Error listing advertisements: {str(e)}")
        return Response(
            {'error': 'Failed to list advertisements'}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsLibraryAdmin])
def get_advertisement(request, ad_id):
    """
    Get a specific advertisement
    GET /ads/<id>/
    """
    try:
        advertisement = AdvertisementManagementService.get_advertisement(ad_id, request.user)
        serializer = AdvertisementDetailSerializer(
            advertisement, 
            context={'request': request}
        )
        return Response(serializer.data)
        
    except ValidationError as e:
        return Response({'error': str(e)}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        logger.error(f"Error getting advertisement {ad_id}: {str(e)}")
        return Response(
            {'error': 'Failed to get advertisement'}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['PUT', 'PATCH'])
@permission_classes([IsAuthenticated, IsLibraryAdmin])
def update_advertisement(request, ad_id):
    """
    Update an existing advertisement
    PUT/PATCH /ads/<id>/
    """
    try:
        advertisement = AdvertisementManagementService.get_advertisement(ad_id, request.user)
        
        # Use partial update for PATCH
        partial = request.method == 'PATCH'
        serializer = AdvertisementUpdateSerializer(
            advertisement, 
            data=request.data, 
            partial=partial,
            context={'request': request}
        )
        
        if serializer.is_valid():
            updated_advertisement = AdvertisementManagementService.update_advertisement(
                ad_id, 
                serializer.validated_data, 
                request.user
            )
            
            response_serializer = AdvertisementDetailSerializer(
                updated_advertisement, 
                context={'request': request}
            )
            
            logger.info(f"Advertisement '{updated_advertisement.title}' updated by {request.user.username}")
            return Response(response_serializer.data)
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        
    except PermissionDenied as e:
        return Response({'error': str(e)}, status=status.HTTP_403_FORBIDDEN)
    except ValidationError as e:
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        logger.error(f"Error updating advertisement {ad_id}: {str(e)}")
        return Response(
            {'error': 'Failed to update advertisement'}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['DELETE'])
@permission_classes([IsAuthenticated, IsLibraryAdmin])
def delete_advertisement(request, ad_id):
    """
    Delete an advertisement
    DELETE /ads/<id>/
    """
    try:
        AdvertisementManagementService.delete_advertisement(ad_id, request.user)
        
        logger.info(f"Advertisement {ad_id} deleted by {request.user.username}")
        return Response(
            {'message': 'Advertisement deleted successfully'}, 
            status=status.HTTP_204_NO_CONTENT
        )
        
    except PermissionDenied as e:
        return Response({'error': str(e)}, status=status.HTTP_403_FORBIDDEN)
    except ValidationError as e:
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        logger.error(f"Error deleting advertisement {ad_id}: {str(e)}")
        return Response(
            {'error': 'Failed to delete advertisement'}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['PATCH'])
@permission_classes([IsAuthenticated, IsLibraryAdmin])
def update_advertisement_status(request, ad_id):
    """
    Update advertisement status
    PATCH /ads/<id>/status/
    """
    try:
        serializer = AdvertisementStatusUpdateSerializer(data=request.data)
        if serializer.is_valid():
            advertisement = AdvertisementStatusService.update_status(
                ad_id, 
                serializer.validated_data['status'], 
                request.user
            )
            
            response_serializer = AdvertisementDetailSerializer(
                advertisement, 
                context={'request': request}
            )
            
            logger.info(f"Advertisement {ad_id} status updated to {serializer.validated_data['status']} by {request.user.username}")
            return Response(response_serializer.data)
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        
    except PermissionDenied as e:
        return Response({'error': str(e)}, status=status.HTTP_403_FORBIDDEN)
    except ValidationError as e:
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        logger.error(f"Error updating advertisement status {ad_id}: {str(e)}")
        return Response(
            {'error': 'Failed to update advertisement status'}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated, IsLibraryAdmin])
def bulk_update_status(request):
    """
    Bulk update advertisement status
    POST /ads/bulk-status/
    """
    try:
        serializer = AdvertisementBulkStatusUpdateSerializer(data=request.data)
        if serializer.is_valid():
            updated_count = AdvertisementStatusService.bulk_update_status(
                serializer.validated_data['advertisement_ids'],
                serializer.validated_data['status'],
                request.user
            )
            
            logger.info(f"Bulk status update: {updated_count} advertisements updated by {request.user.username}")
            return Response({
                'message': f'Successfully updated {updated_count} advertisements',
                'updated_count': updated_count
            })
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        
    except PermissionDenied as e:
        return Response({'error': str(e)}, status=status.HTTP_403_FORBIDDEN)
    except ValidationError as e:
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        logger.error(f"Error in bulk status update: {str(e)}")
        return Response(
            {'error': 'Failed to update advertisement statuses'}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsLibraryAdmin])
def get_advertisement_stats(request, ad_id):
    """
    Get statistics for a specific advertisement
    GET /ads/<id>/stats/
    """
    try:
        stats = AdvertisementAnalyticsService.get_advertisement_stats(ad_id)
        return Response(stats)
        
    except ValidationError as e:
        return Response({'error': str(e)}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        logger.error(f"Error getting advertisement stats {ad_id}: {str(e)}")
        return Response(
            {'error': 'Failed to get advertisement statistics'}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsLibraryAdmin])
def get_overall_stats(request):
    """
    Get overall advertisement statistics
    GET /ads/stats/
    """
    try:
        stats = AdvertisementAnalyticsService.get_overall_stats()
        return Response(stats)
        
    except Exception as e:
        logger.error(f"Error getting overall stats: {str(e)}")
        return Response(
            {'error': 'Failed to get overall statistics'}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsLibraryAdmin])
def get_active_advertisements(request):
    """
    Get all currently active advertisements
    GET /ads/active/
    """
    try:
        advertisements = AdvertisementManagementService.get_active_advertisements()
        serializer = AdvertisementListSerializer(
            advertisements, 
            many=True, 
            context={'request': request}
        )
        return Response(serializer.data)
        
    except Exception as e:
        logger.error(f"Error getting active advertisements: {str(e)}")
        return Response(
            {'error': 'Failed to get active advertisements'}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsLibraryAdmin])
def get_scheduled_advertisements(request):
    """
    Get all scheduled advertisements
    GET /ads/scheduled/
    """
    try:
        advertisements = AdvertisementSchedulingService.get_scheduled_advertisements()
        serializer = AdvertisementListSerializer(
            advertisements, 
            many=True, 
            context={'request': request}
        )
        return Response(serializer.data)
        
    except Exception as e:
        logger.error(f"Error getting scheduled advertisements: {str(e)}")
        return Response(
            {'error': 'Failed to get scheduled advertisements'}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsLibraryAdmin])
def get_advertisements_ending_soon(request):
    """
    Get advertisements ending within 7 days
    GET /ads/ending-soon/
    """
    try:
        days = int(request.query_params.get('days', 7))
        advertisements = AdvertisementSchedulingService.get_advertisements_ending_soon(days)
        serializer = AdvertisementListSerializer(
            advertisements, 
            many=True, 
            context={'request': request}
        )
        return Response(serializer.data)
        
    except ValueError:
        return Response({'error': 'Invalid days parameter'}, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        logger.error(f"Error getting advertisements ending soon: {str(e)}")
        return Response(
            {'error': 'Failed to get advertisements ending soon'}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


# Public endpoints (for frontend display)
@api_view(['GET'])
def get_public_advertisements(request):
    """
    Get advertisements for public display (active only)
    GET /ads/public/
    """
    try:
        advertisements = AdvertisementManagementService.get_public_advertisements()
        serializer = AdvertisementPublicSerializer(
            advertisements, 
            many=True, 
            context={'request': request}
        )
        return Response(serializer.data)
        
    except Exception as e:
        logger.error(f"Error getting public advertisements: {str(e)}")
        return Response(
            {'error': 'Failed to get public advertisements'}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )




# Scheduling endpoints
@api_view(['POST'])
@permission_classes([IsAuthenticated, IsLibraryAdmin])
def schedule_advertisement(request, ad_id):
    """
    Schedule an advertisement for future activation
    POST /ads/<id>/schedule/
    """
    try:
        advertisement = AdvertisementSchedulingService.schedule_advertisement(ad_id, request.user)
        serializer = AdvertisementDetailSerializer(
            advertisement, 
            context={'request': request}
        )
        
        logger.info(f"Advertisement {ad_id} scheduled by {request.user.username}")
        return Response(serializer.data)
        
    except PermissionDenied as e:
        return Response({'error': str(e)}, status=status.HTTP_403_FORBIDDEN)
    except ValidationError as e:
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        logger.error(f"Error scheduling advertisement {ad_id}: {str(e)}")
        return Response(
            {'error': 'Failed to schedule advertisement'}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated, IsLibraryAdmin])
def activate_advertisement(request, ad_id):
    """
    Activate an advertisement immediately
    POST /ads/<id>/activate/
    """
    try:
        advertisement = AdvertisementSchedulingService.activate_advertisement(ad_id, request.user)
        serializer = AdvertisementDetailSerializer(
            advertisement, 
            context={'request': request}
        )
        
        logger.info(f"Advertisement {ad_id} activated by {request.user.username}")
        return Response(serializer.data)
        
    except PermissionDenied as e:
        return Response({'error': str(e)}, status=status.HTTP_403_FORBIDDEN)
    except ValidationError as e:
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        logger.error(f"Error activating advertisement {ad_id}: {str(e)}")
        return Response(
            {'error': 'Failed to activate advertisement'}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated, IsLibraryAdmin])
def pause_advertisement(request, ad_id):
    """
    Pause an active advertisement
    POST /ads/<id>/pause/
    """
    try:
        advertisement = AdvertisementSchedulingService.pause_advertisement(ad_id, request.user)
        serializer = AdvertisementDetailSerializer(
            advertisement, 
            context={'request': request}
        )
        
        logger.info(f"Advertisement {ad_id} paused by {request.user.username}")
        return Response(serializer.data)
        
    except PermissionDenied as e:
        return Response({'error': str(e)}, status=status.HTTP_403_FORBIDDEN)
    except ValidationError as e:
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        logger.error(f"Error pausing advertisement {ad_id}: {str(e)}")
        return Response(
            {'error': 'Failed to pause advertisement'}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


# Additional endpoints for frontend compatibility
@api_view(['POST'])
@permission_classes([IsAuthenticated, IsLibraryAdmin])
def publish_advertisement(request, ad_id):
    """
    Publish an advertisement (alias for activate)
    POST /ads/<id>/publish/
    """
    try:
        advertisement = AdvertisementSchedulingService.activate_advertisement(ad_id, request.user)
        serializer = AdvertisementDetailSerializer(
            advertisement, 
            context={'request': request}
        )
        
        logger.info(f"Advertisement {ad_id} published by {request.user.username}")
        return Response(serializer.data)
        
    except PermissionDenied as e:
        return Response({'error': str(e)}, status=status.HTTP_403_FORBIDDEN)
    except ValidationError as e:
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        logger.error(f"Error publishing advertisement {ad_id}: {str(e)}")
        return Response(
            {'error': 'Failed to publish advertisement'}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated, IsLibraryAdmin])
def unpublish_advertisement(request, ad_id):
    """
    Unpublish an advertisement (alias for pause)
    POST /ads/<id>/unpublish/
    """
    try:
        advertisement = AdvertisementSchedulingService.pause_advertisement(ad_id, request.user)
        serializer = AdvertisementDetailSerializer(
            advertisement, 
            context={'request': request}
        )
        
        logger.info(f"Advertisement {ad_id} unpublished by {request.user.username}")
        return Response(serializer.data)
        
    except PermissionDenied as e:
        return Response({'error': str(e)}, status=status.HTTP_403_FORBIDDEN)
    except ValidationError as e:
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        logger.error(f"Error unpublishing advertisement {ad_id}: {str(e)}")
        return Response(
            {'error': 'Failed to unpublish advertisement'}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

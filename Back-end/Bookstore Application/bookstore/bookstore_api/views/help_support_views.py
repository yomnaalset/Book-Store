from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, permissions
from ..models import FAQ, UserGuide, TroubleshootingGuide, SupportContact
from ..serializers import (
    FAQSerializer, UserGuideSerializer, TroubleshootingGuideSerializer, 
    SupportContactSerializer, HelpSupportDataSerializer
)
import logging

logger = logging.getLogger(__name__)


class HelpSupportDataView(APIView):
    """Get all help and support data in one request"""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        try:
            # Get all active FAQs
            faqs = FAQ.objects.filter(is_active=True).order_by('order', 'created_at')
            
            # Get all active user guides
            user_guides = UserGuide.objects.filter(is_active=True).order_by('section', 'order', 'created_at')
            
            # Get all active troubleshooting guides
            troubleshooting_guides = TroubleshootingGuide.objects.filter(is_active=True).order_by('category', 'order', 'created_at')
            
            # Get support contacts (filter by admin status)
            is_admin = request.user.is_staff or request.user.is_superuser
            support_contacts = SupportContact.objects.filter(
                is_available=True,
                is_admin_only=is_admin
            ).order_by('order', 'contact_type')
            
            data = {
                'faqs': FAQSerializer(faqs, many=True).data,
                'user_guides': UserGuideSerializer(user_guides, many=True).data,
                'troubleshooting_guides': TroubleshootingGuideSerializer(troubleshooting_guides, many=True).data,
                'support_contacts': SupportContactSerializer(support_contacts, many=True).data,
            }
            
            return Response({
                'success': True,
                'message': 'Help and support data retrieved successfully',
                'data': data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving help and support data for user {request.user.id}: {e}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve help and support data',
                'errors': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class FAQListView(APIView):
    """Get FAQs by category"""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        try:
            category = request.query_params.get('category', None)
            
            faqs = FAQ.objects.filter(is_active=True)
            if category:
                faqs = faqs.filter(category=category)
            
            faqs = faqs.order_by('order', 'created_at')
            
            serializer = FAQSerializer(faqs, many=True)
            return Response({
                'success': True,
                'message': 'FAQs retrieved successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving FAQs for user {request.user.id}: {e}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve FAQs',
                'errors': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class UserGuideListView(APIView):
    """Get user guides by section"""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        try:
            section = request.query_params.get('section', None)
            
            user_guides = UserGuide.objects.filter(is_active=True)
            if section:
                user_guides = user_guides.filter(section=section)
            
            user_guides = user_guides.order_by('section', 'order', 'created_at')
            
            serializer = UserGuideSerializer(user_guides, many=True)
            return Response({
                'success': True,
                'message': 'User guides retrieved successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving user guides for user {request.user.id}: {e}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve user guides',
                'errors': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class TroubleshootingGuideListView(APIView):
    """Get troubleshooting guides by category"""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        try:
            category = request.query_params.get('category', None)
            
            guides = TroubleshootingGuide.objects.filter(is_active=True)
            if category:
                guides = guides.filter(category=category)
            
            guides = guides.order_by('category', 'order', 'created_at')
            
            serializer = TroubleshootingGuideSerializer(guides, many=True)
            return Response({
                'success': True,
                'message': 'Troubleshooting guides retrieved successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving troubleshooting guides for user {request.user.id}: {e}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve troubleshooting guides',
                'errors': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class SupportContactListView(APIView):
    """Get support contacts (filtered by admin status)"""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        try:
            is_admin = request.user.is_staff or request.user.is_superuser
            
            contacts = SupportContact.objects.filter(
                is_available=True,
                is_admin_only=is_admin
            ).order_by('order', 'contact_type')
            
            serializer = SupportContactSerializer(contacts, many=True)
            return Response({
                'success': True,
                'message': 'Support contacts retrieved successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving support contacts for user {request.user.id}: {e}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve support contacts',
                'errors': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

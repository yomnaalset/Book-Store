from rest_framework import viewsets, status, permissions
from rest_framework.response import Response
from rest_framework.decorators import action
from django.shortcuts import get_object_or_404

from ..models import Notification
from ..serializers import (
    NotificationSerializer,
    NotificationCreateSerializer,
    NotificationUpdateSerializer
)
from ..services import NotificationService
from ..permissions import IsOwnerOrAdmin


class NotificationViewSet(viewsets.ModelViewSet):
    """
    ViewSet for managing user notifications
    """
    queryset = Notification.objects.all()
    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated, IsOwnerOrAdmin]
    
    def get_serializer_class(self):
        if self.action == 'create':
            return NotificationCreateSerializer
        elif self.action in ['update', 'partial_update', 'mark_as_read']:
            return NotificationUpdateSerializer
        return NotificationSerializer
    
    def get_queryset(self):
        """
        Filter notifications to only show those belonging to the current user
        unless the user is an admin
        """
        user = self.request.user
        
        # If user is admin, they can see all notifications
        if user.is_staff or user.is_superuser:
            return Notification.objects.all()
        
        # Otherwise, only show notifications for the current user
        return Notification.objects.filter(user=user)
    
    def list(self, request, *args, **kwargs):
        """
        List all notifications for the current user with optional filters
        """
        is_read = request.query_params.get('is_read')
        notification_type = request.query_params.get('notification_type')
        
        if is_read is not None:
            is_read = is_read.lower() == 'true'
        
        try:
            notifications = NotificationService.get_user_notifications(
                user_id=request.user.id,
                is_read=is_read,
                notification_type=notification_type
            )
            
            serializer = self.get_serializer(notifications, many=True)
            return Response(serializer.data)
        except ValueError as e:
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)
    
    def retrieve(self, request, *args, **kwargs):
        """
        Retrieve a single notification and mark it as read
        """
        notification = self.get_object()
        
        # Mark notification as read when it's retrieved
        if not notification.is_read:
            notification.is_read = True
            notification.save()
        
        serializer = self.get_serializer(notification)
        return Response(serializer.data)
    
    @action(detail=True, methods=['post'])
    def mark_as_read(self, request, pk=None):
        """
        Mark a notification as read
        """
        try:
            notification = NotificationService.mark_notification_as_read(pk)
            serializer = self.get_serializer(notification)
            return Response(serializer.data)
        except ValueError as e:
            return Response({"error": str(e)}, status=status.HTTP_404_NOT_FOUND)
    
    @action(detail=False, methods=['post'])
    def mark_all_as_read(self, request):
        """
        Mark all notifications as read for the current user
        """
        try:
            count = NotificationService.mark_all_as_read(request.user.id)
            return Response({"message": f"{count} notifications marked as read"})
        except ValueError as e:
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)
    
    @action(detail=False, methods=['get'])
    def unread_count(self, request):
        """
        Get the count of unread notifications for the current user
        """
        try:
            notifications = NotificationService.get_user_notifications(
                user_id=request.user.id,
                is_read=False
            )
            return Response({"unread_count": notifications.count()})
        except ValueError as e:
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)
from django.db import transaction
from django.utils import timezone
from django.core.exceptions import ValidationError, PermissionDenied
from django.db.models import Q, Count, Avg
from datetime import timedelta
import logging

from ..models.ad_model import Advertisement, AdvertisementStatusChoices
from ..models.user_model import User

logger = logging.getLogger(__name__)


class AdvertisementManagementService:
    """Service for managing advertisement operations"""
    
    @staticmethod
    def create_advertisement(ad_data, user):
        """
        Create a new advertisement
        
        Args:
            ad_data (dict): Advertisement data
            user (User): User creating the advertisement
            
        Returns:
            Advertisement: Created advertisement instance
            
        Raises:
            PermissionDenied: If user is not a library admin
            ValidationError: If advertisement data is invalid
        """
        if user.user_type != 'library_admin':
            raise PermissionDenied("Only library administrators can create advertisements.")
        
        try:
            with transaction.atomic():
                # Set the created_by field
                ad_data['created_by'] = user
                
                # Create the advertisement
                advertisement = Advertisement.objects.create(**ad_data)
                
                logger.info(f"Advertisement '{advertisement.title}' created by {user.username}")
                return advertisement
                
        except Exception as e:
            logger.error(f"Error creating advertisement: {str(e)}")
            raise ValidationError(f"Failed to create advertisement: {str(e)}")
    
    @staticmethod
    def update_advertisement(advertisement_id, ad_data, user):
        """
        Update an existing advertisement
        
        Args:
            advertisement_id (int): ID of the advertisement to update
            ad_data (dict): Updated advertisement data
            user (User): User updating the advertisement
            
        Returns:
            Advertisement: Updated advertisement instance
            
        Raises:
            PermissionDenied: If user is not authorized
            ValidationError: If advertisement data is invalid
            Advertisement.DoesNotExist: If advertisement not found
        """
        if user.user_type != 'library_admin':
            raise PermissionDenied("Only library administrators can update advertisements.")
        
        try:
            advertisement = Advertisement.objects.get(id=advertisement_id)
            
            # Check if user can update this advertisement
            if advertisement.created_by != user and user.user_type != 'system_admin':
                raise PermissionDenied("You can only update advertisements you created.")
            
            with transaction.atomic():
                # Update fields
                for field, value in ad_data.items():
                    if hasattr(advertisement, field):
                        setattr(advertisement, field, value)
                
                # Save the advertisement (this will trigger status updates)
                advertisement.save()
                
                logger.info(f"Advertisement '{advertisement.title}' updated by {user.username}")
                return advertisement
                
        except Advertisement.DoesNotExist:
            raise ValidationError("Advertisement not found.")
        except Exception as e:
            logger.error(f"Error updating advertisement {advertisement_id}: {str(e)}")
            raise ValidationError(f"Failed to update advertisement: {str(e)}")
    
    @staticmethod
    def delete_advertisement(advertisement_id, user):
        """
        Delete an advertisement
        
        Args:
            advertisement_id (int): ID of the advertisement to delete
            user (User): User deleting the advertisement
            
        Returns:
            bool: True if deleted successfully
            
        Raises:
            PermissionDenied: If user is not authorized
            ValidationError: If advertisement not found
        """
        if user.user_type != 'library_admin':
            raise PermissionDenied("Only library administrators can delete advertisements.")
        
        try:
            advertisement = Advertisement.objects.get(id=advertisement_id)
            
            # Check if user can delete this advertisement
            if advertisement.created_by != user and user.user_type != 'system_admin':
                raise PermissionDenied("You can only delete advertisements you created.")
            
            with transaction.atomic():
                advertisement_title = advertisement.title
                advertisement.delete()
                
                logger.info(f"Advertisement '{advertisement_title}' deleted by {user.username}")
                return True
                
        except Advertisement.DoesNotExist:
            raise ValidationError("Advertisement not found.")
        except Exception as e:
            logger.error(f"Error deleting advertisement {advertisement_id}: {str(e)}")
            raise ValidationError(f"Failed to delete advertisement: {str(e)}")
    
    @staticmethod
    def get_advertisement(advertisement_id, user):
        """
        Get a specific advertisement
        
        Args:
            advertisement_id (int): ID of the advertisement
            user (User): User requesting the advertisement
            
        Returns:
            Advertisement: Advertisement instance
            
        Raises:
            ValidationError: If advertisement not found
        """
        try:
            return Advertisement.objects.get(id=advertisement_id)
        except Advertisement.DoesNotExist:
            raise ValidationError("Advertisement not found.")
    
    @staticmethod
    def list_advertisements(user, status=None, created_by=None, search=None, ordering='-created_at'):
        """
        List advertisements with optional filtering
        
        Args:
            user (User): User requesting the list
            status (str, optional): Filter by status
            created_by (int, optional): Filter by creator ID
            search (str, optional): Search in title and content
            ordering (str): Ordering field
            
        Returns:
            QuerySet: Filtered advertisements
        """
        queryset = Advertisement.objects.all()
        
        # Apply filters
        if status:
            queryset = queryset.filter(status=status)
        
        if created_by:
            queryset = queryset.filter(created_by_id=created_by)
        
        if search:
            queryset = queryset.filter(
                Q(title__icontains=search) | Q(content__icontains=search)
            )
        
        # Apply ordering
        queryset = queryset.order_by(ordering)
        
        return queryset
    
    @staticmethod
    def get_active_advertisements():
        """
        Get all currently active advertisements
        
        Returns:
            QuerySet: Active advertisements
        """
        now = timezone.now()
        return Advertisement.objects.filter(
            status=AdvertisementStatusChoices.ACTIVE,
            start_date__lte=now,
            end_date__gt=now
        ).order_by('-created_at')
    
    @staticmethod
    def get_public_advertisements():
        """
        Get advertisements for public display (active only)
        
        Returns:
            QuerySet: Public advertisements
        """
        return AdvertisementManagementService.get_active_advertisements()


class AdvertisementStatusService:
    """Service for managing advertisement status operations"""
    
    @staticmethod
    def update_status(advertisement_id, new_status, user):
        """
        Update advertisement status
        
        Args:
            advertisement_id (int): ID of the advertisement
            new_status (str): New status
            user (User): User updating the status
            
        Returns:
            Advertisement: Updated advertisement instance
            
        Raises:
            PermissionDenied: If user is not authorized
            ValidationError: If status change is invalid
        """
        if user.user_type != 'library_admin':
            raise PermissionDenied("Only library administrators can update advertisement status.")
        
        try:
            advertisement = Advertisement.objects.get(id=advertisement_id)
            
            # Check if user can update this advertisement
            if advertisement.created_by != user and user.user_type != 'system_admin':
                raise PermissionDenied("You can only update advertisements you created.")
            
            # Validate status transition
            current_status = advertisement.status
            
            if current_status == AdvertisementStatusChoices.EXPIRED:
                raise ValidationError("Cannot change status of expired advertisements.")
            
            # Auto-activate scheduled ads if start date has passed
            if (new_status == AdvertisementStatusChoices.SCHEDULED and 
                advertisement.start_date and 
                advertisement.start_date <= timezone.now()):
                new_status = AdvertisementStatusChoices.ACTIVE
            
            with transaction.atomic():
                advertisement.status = new_status
                advertisement.save()
                
                logger.info(f"Advertisement '{advertisement.title}' status changed to {new_status} by {user.username}")
                return advertisement
                
        except Advertisement.DoesNotExist:
            raise ValidationError("Advertisement not found.")
        except Exception as e:
            logger.error(f"Error updating advertisement status {advertisement_id}: {str(e)}")
            raise ValidationError(f"Failed to update advertisement status: {str(e)}")
    
    @staticmethod
    def bulk_update_status(advertisement_ids, new_status, user):
        """
        Update status of multiple advertisements
        
        Args:
            advertisement_ids (list): List of advertisement IDs
            new_status (str): New status
            user (User): User updating the status
            
        Returns:
            int: Number of advertisements updated
            
        Raises:
            PermissionDenied: If user is not authorized
            ValidationError: If any advertisement not found or invalid status
        """
        if user.user_type != 'library_admin':
            raise PermissionDenied("Only library administrators can update advertisement status.")
        
        try:
            advertisements = Advertisement.objects.filter(id__in=advertisement_ids)
            
            if not advertisements.exists():
                raise ValidationError("No advertisements found.")
            
            # Check permissions for each advertisement
            for ad in advertisements:
                if ad.created_by != user and user.user_type != 'system_admin':
                    raise PermissionDenied(f"You can only update advertisements you created. (Ad: {ad.title})")
            
            updated_count = 0
            with transaction.atomic():
                for advertisement in advertisements:
                    current_status = advertisement.status
                    
                    if current_status == AdvertisementStatusChoices.EXPIRED:
                        continue  # Skip expired advertisements
                    
                    # Auto-activate scheduled ads if start date has passed
                    status_to_set = new_status
                    if (new_status == AdvertisementStatusChoices.SCHEDULED and 
                        advertisement.start_date and 
                        advertisement.start_date <= timezone.now()):
                        status_to_set = AdvertisementStatusChoices.ACTIVE
                    
                    advertisement.status = status_to_set
                    advertisement.save()
                    updated_count += 1
                
                logger.info(f"Bulk status update: {updated_count} advertisements updated to {new_status} by {user.username}")
                return updated_count
                
        except Exception as e:
            logger.error(f"Error in bulk status update: {str(e)}")
            raise ValidationError(f"Failed to update advertisement statuses: {str(e)}")
    
    @staticmethod
    def auto_update_expired_advertisements():
        """
        Automatically update expired advertisements
        This should be called by a scheduled task
        
        Returns:
            int: Number of advertisements updated
        """
        try:
            now = timezone.now()
            expired_ads = Advertisement.objects.filter(
                status__in=[AdvertisementStatusChoices.ACTIVE, AdvertisementStatusChoices.SCHEDULED],
                end_date__lte=now
            )
            
            updated_count = 0
            with transaction.atomic():
                for ad in expired_ads:
                    ad.status = AdvertisementStatusChoices.EXPIRED
                    ad.save()
                    updated_count += 1
                
                if updated_count > 0:
                    logger.info(f"Auto-updated {updated_count} expired advertisements")
                
                return updated_count
                
        except Exception as e:
            logger.error(f"Error auto-updating expired advertisements: {str(e)}")
            return 0


class AdvertisementAnalyticsService:
    """Service for advertisement analytics and reporting"""
    
    @staticmethod
    def get_advertisement_stats(advertisement_id):
        """
        Get statistics for a specific advertisement
        
        Args:
            advertisement_id (int): ID of the advertisement
            
        Returns:
            dict: Advertisement statistics
            
        Raises:
            ValidationError: If advertisement not found
        """
        try:
            advertisement = Advertisement.objects.get(id=advertisement_id)
            
            return {
                'id': advertisement.id,
                'title': advertisement.title,
                'status': advertisement.status,
                'duration_days': advertisement.get_duration_days(),
                'remaining_days': advertisement.get_remaining_days(),
                'created_at': advertisement.created_at,
                'start_date': advertisement.start_date,
                'end_date': advertisement.end_date,
            }
            
        except Advertisement.DoesNotExist:
            raise ValidationError("Advertisement not found.")
    
    @staticmethod
    def get_overall_stats():
        """
        Get overall advertisement statistics
        
        Returns:
            dict: Overall statistics
        """
        total_ads = Advertisement.objects.count()
        active_ads = Advertisement.objects.filter(status=AdvertisementStatusChoices.ACTIVE).count()
        scheduled_ads = Advertisement.objects.filter(status=AdvertisementStatusChoices.SCHEDULED).count()
        expired_ads = Advertisement.objects.filter(status=AdvertisementStatusChoices.EXPIRED).count()
        inactive_ads = Advertisement.objects.filter(status=AdvertisementStatusChoices.INACTIVE).count()
        
        return {
            'total_advertisements': total_ads,
            'active_advertisements': active_ads,
            'scheduled_advertisements': scheduled_ads,
            'expired_advertisements': expired_ads,
            'inactive_advertisements': inactive_ads,
        }
    


class AdvertisementSchedulingService:
    """Service for advertisement scheduling operations"""
    
    @staticmethod
    def schedule_advertisement(advertisement_id, user):
        """
        Schedule an advertisement for future activation
        
        Args:
            advertisement_id (int): ID of the advertisement
            user (User): User scheduling the advertisement
            
        Returns:
            Advertisement: Updated advertisement instance
        """
        return AdvertisementStatusService.update_status(
            advertisement_id, 
            AdvertisementStatusChoices.SCHEDULED, 
            user
        )
    
    @staticmethod
    def activate_advertisement(advertisement_id, user):
        """
        Activate an advertisement immediately
        
        Args:
            advertisement_id (int): ID of the advertisement
            user (User): User activating the advertisement
            
        Returns:
            Advertisement: Updated advertisement instance
        """
        return AdvertisementStatusService.update_status(
            advertisement_id, 
            AdvertisementStatusChoices.ACTIVE, 
            user
        )
    
    @staticmethod
    def pause_advertisement(advertisement_id, user):
        """
        Pause an active advertisement
        
        Args:
            advertisement_id (int): ID of the advertisement
            user (User): User pausing the advertisement
            
        Returns:
            Advertisement: Updated advertisement instance
        """
        return AdvertisementStatusService.update_status(
            advertisement_id, 
            AdvertisementStatusChoices.INACTIVE, 
            user
        )
    
    @staticmethod
    def get_scheduled_advertisements():
        """
        Get all scheduled advertisements
        
        Returns:
            QuerySet: Scheduled advertisements
        """
        return Advertisement.objects.filter(
            status=AdvertisementStatusChoices.SCHEDULED
        ).order_by('start_date')
    
    @staticmethod
    def get_advertisements_ending_soon(days=7):
        """
        Get advertisements ending within specified days
        
        Args:
            days (int): Number of days to look ahead
            
        Returns:
            QuerySet: Advertisements ending soon
        """
        end_date = timezone.now() + timedelta(days=days)
        return Advertisement.objects.filter(
            status=AdvertisementStatusChoices.ACTIVE,
            end_date__lte=end_date,
            end_date__gt=timezone.now()
        ).order_by('end_date')

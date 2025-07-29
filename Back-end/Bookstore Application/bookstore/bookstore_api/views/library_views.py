from rest_framework import generics, status, permissions
from rest_framework.response import Response
from rest_framework.views import APIView
from django.shortcuts import get_object_or_404
from django.core.exceptions import PermissionDenied
import logging

from ..models import Library, Book, BookImage, Category, Author
from ..serializers import (
    LibraryCreateSerializer,
    LibraryUpdateSerializer,
    LibraryDetailSerializer,
    LibraryListSerializer,
    LibraryStatsSerializer,
    # Book serializers
    BookCreateSerializer,
    BookUpdateSerializer,
    BookDetailSerializer,
    BookListSerializer,
    BookSearchSerializer,
    BookStatsSerializer,
    # Category serializers
    CategoryCreateSerializer,
    CategoryUpdateSerializer,
    CategoryDetailSerializer,
    CategoryListSerializer,
    CategoryStatsSerializer,
    CategoryChoiceSerializer,
    # Author serializers
    AuthorCreateSerializer,
    AuthorUpdateSerializer,
    AuthorDetailSerializer,
    AuthorListSerializer,
    AuthorStatsSerializer,
    AuthorChoiceSerializer,
    AuthorWithBooksSerializer,
)
from ..services import LibraryManagementService, LibraryAccessService, BookManagementService, BookAccessService
from ..utils import format_error_message
from ..permissions import IsSystemAdmin

logger = logging.getLogger(__name__)


class LibraryAdminRequiredMixin:
    """
    Mixin to ensure only library administrators can access certain views.
    """
    
    def dispatch(self, request, *args, **kwargs):
        if not request.user.is_authenticated:
            return Response({
                'success': False,
                'message': 'Authentication required',
                'error_code': 'AUTHENTICATION_REQUIRED'
            }, status=status.HTTP_401_UNAUTHORIZED)
        
        if not request.user.is_library_admin():
            return Response({
                'success': False,
                'message': 'Only library administrators can perform this action',
                'error_code': 'PERMISSION_DENIED'
            }, status=status.HTTP_403_FORBIDDEN)
        
        return super().dispatch(request, *args, **kwargs)


# Keep the old name for backward compatibility
class SystemAdminRequiredMixin(LibraryAdminRequiredMixin):
    """
    Deprecated: Use LibraryAdminRequiredMixin instead.
    """
    pass


class LibraryCreateView(generics.CreateAPIView):
    """
    Create a new library.
    Only library administrators can create libraries.
    Only one library can exist at a time.
    """
    serializer_class = LibraryCreateSerializer
    permission_classes = [permissions.IsAuthenticated, IsSystemAdmin]
    
    def create(self, request, *args, **kwargs):
        """
        Create a new library with the provided data.
        """
        try:
            # Check if a library can be created (single library constraint)
            if not Library.can_create_library():
                existing_library = Library.get_current_library()
                return Response({
                    'success': False,
                    'message': f"Only one library can exist at a time. Please delete the existing library '{existing_library.name}' first.",
                    'error_code': 'LIBRARY_EXISTS'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Handle case-insensitive field names for form-data
            data = request.data.copy()
            normalized_data = {}
            for key, value in data.items():
                normalized_data[key.lower()] = value
            
            # Create serializer with normalized data
            serializer = self.get_serializer(data=normalized_data)
            serializer.is_valid(raise_exception=True)
            
            # Save the new library
            library = serializer.save()
            
            # Return response with library data
            response_serializer = LibraryDetailSerializer(library)
            
            logger.info(f"Library '{library.name}' created by {request.user.email}")
            
            return Response({
                'success': True,
                'message': 'Library created successfully',
                'data': response_serializer.data
            }, status=status.HTTP_201_CREATED)
                
        except Exception as e:
            logger.error(f"Error creating library: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to create library',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class LibraryDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    Retrieve, update, or delete the current library.
    Library administrators can perform all operations.
    Other authenticated users can only view library details.
    """
    serializer_class = LibraryDetailSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_object(self):
        """
        Get the current active library.
        """
        library = Library.get_current_library()
        if not library:
            return None
        return library
    
    def get(self, request, *args, **kwargs):
        """
        Retrieve current library details.
        Available to all authenticated users.
        """
        try:
            library = self.get_object()
            if not library:
                return Response({
                    'success': False,
                    'message': 'No active library found',
                    'error_code': 'NO_LIBRARY_FOUND'
                }, status=status.HTTP_404_NOT_FOUND)
            
            serializer = self.get_serializer(library)
            return Response({
                'success': True,
                'message': 'Library details retrieved successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving library: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve library details',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def patch(self, request, *args, **kwargs):
        """
        Update library details.
        Only library administrators can update libraries.
        """
        # Check library admin permission
        if not request.user.is_library_admin():
            return Response({
                'success': False,
                'message': 'Only library administrators can update libraries',
                'error_code': 'PERMISSION_DENIED'
            }, status=status.HTTP_403_FORBIDDEN)
        
        try:
            library = self.get_object()
            if not library:
                return Response({
                    'success': False,
                    'message': 'No active library found to update',
                    'error_code': 'NO_LIBRARY_FOUND'
                }, status=status.HTTP_404_NOT_FOUND)
            
            # Use service to update library
            result = LibraryManagementService.update_library(
                user=request.user,
                library_id=library.id,
                update_data=request.data
            )
            
            if result['success']:
                return Response({
                    'success': True,
                    'message': result['message'],
                    'data': result['library_data']
                }, status=status.HTTP_200_OK)
            else:
                return Response({
                    'success': False,
                    'message': result['message'],
                    'errors': result.get('errors', {})
                }, status=status.HTTP_400_BAD_REQUEST)
                
        except PermissionDenied as e:
            return Response({
                'success': False,
                'message': str(e),
                'error_code': 'PERMISSION_DENIED'
            }, status=status.HTTP_403_FORBIDDEN)
        except Exception as e:
            logger.error(f"Error updating library: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to update library',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def delete(self, request, *args, **kwargs):
        """
        Delete the current library.
        Only library administrators can delete libraries.
        """
        # Check library admin permission
        if not request.user.is_library_admin():
            return Response({
                'success': False,
                'message': 'Only library administrators can delete libraries',
                'error_code': 'PERMISSION_DENIED'
            }, status=status.HTTP_403_FORBIDDEN)
        
        try:
            library = self.get_object()
            if not library:
                return Response({
                    'success': False,
                    'message': 'No active library found to delete',
                    'error_code': 'NO_LIBRARY_FOUND'
                }, status=status.HTTP_404_NOT_FOUND)
            
            # Use service to delete library
            result = LibraryManagementService.delete_library(
                user=request.user,
                library_id=library.id
            )
            
            if result['success']:
                return Response({
                    'success': True,
                    'message': result['message']
                }, status=status.HTTP_204_NO_CONTENT)
            else:
                return Response({
                    'success': False,
                    'message': result['message'],
                    'errors': result.get('errors', {})
                }, status=status.HTTP_400_BAD_REQUEST)
                
        except PermissionDenied as e:
            return Response({
                'success': False,
                'message': str(e),
                'error_code': 'PERMISSION_DENIED'
            }, status=status.HTTP_403_FORBIDDEN)
        except Exception as e:
            logger.error(f"Error deleting library: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to delete library',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class LibraryManagementView(APIView):
    """
    Library management view for library administrators.
    Provides comprehensive library management operations.
    """
    permission_classes = [permissions.IsAuthenticated, IsSystemAdmin]
    
    def get(self, request):
        """
        Get library management dashboard data.
        """
        try:
            # Get library statistics
            stats = LibraryAccessService.get_library_stats()
            
            # Get current library if exists
            current_library = Library.get_current_library()
            library_data = None
            if current_library:
                serializer = LibraryDetailSerializer(current_library)
                library_data = serializer.data
            
            return Response({
                'success': True,
                'message': 'Library management data retrieved successfully',
                'data': {
                    'statistics': stats,
                    'current_library': library_data,
                    'can_create_library': Library.can_create_library(),
                }
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving library management data: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve library management data',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class LibraryUpdateView(generics.UpdateAPIView):
    """
    Update library information.
    Only library administrators can update libraries.
    """
    serializer_class = LibraryUpdateSerializer
    permission_classes = [permissions.IsAuthenticated, IsSystemAdmin]
    
    def get_object(self):
        """
        Get the current active library.
        """
        library = Library.get_current_library()
        if not library:
            from rest_framework.exceptions import NotFound
            raise NotFound("No active library found to update")
        return library
    
    def update(self, request, *args, **kwargs):
        """
        Update library with the provided data.
        """
        try:
            # Handle case-insensitive field names for form-data
            data = request.data.copy()
            normalized_data = {}
            for key, value in data.items():
                normalized_data[key.lower()] = value
            
            # Get the library instance
            instance = self.get_object()
            
            # Create serializer with normalized data
            serializer = self.get_serializer(instance, data=normalized_data, partial=True)
            serializer.is_valid(raise_exception=True)
            
            # Save the updated library
            updated_library = serializer.save()
            
            # Return response with library data
            response_serializer = LibraryDetailSerializer(updated_library)
            
            return Response({
                'success': True,
                'message': 'Library updated successfully',
                'data': response_serializer.data
            }, status=status.HTTP_200_OK)
                
        except Exception as e:
            logger.error(f"Error updating library: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to update library',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class LibraryDeleteView(generics.DestroyAPIView):
    """
    Delete the current library.
    Only library administrators can delete libraries.
    """
    permission_classes = [permissions.IsAuthenticated, IsSystemAdmin]
    
    def get_object(self):
        """
        Get the current active library.
        """
        library = Library.get_current_library()
        if not library:
            from rest_framework.exceptions import NotFound
            raise NotFound("No active library found to delete")
        return library
    
    def delete(self, request, *args, **kwargs):
        """
        Delete the current library.
        """
        try:
            # Get the library instance
            instance = self.get_object()
            library_name = instance.name
            
            # Perform the delete
            instance.delete()
            
            logger.info(f"Library '{library_name}' deleted by {request.user.email}")
            
            return Response({
                'success': True,
                'message': f"Library '{library_name}' deleted successfully. You can now create a new library.",
                'can_create_new': True
            }, status=status.HTTP_200_OK)
                
        except Exception as e:
            logger.error(f"Error deleting library: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to delete library',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class LibraryPublicView(generics.RetrieveAPIView):
    """
    Public view for library information.
    Available to all users (no authentication required).
    """
    serializer_class = LibraryListSerializer
    permission_classes = [permissions.AllowAny]
    
    def get(self, request):
        """
        Get public library information.
        """
        try:
            # Get current library
            library = Library.get_current_library()
            
            if not library:
                return Response({
                    'success': False,
                    'message': 'No library information available',
                    'error_code': 'NO_LIBRARY_FOUND'
                }, status=status.HTTP_404_NOT_FOUND)
            
            # Get public library data
            result = LibraryAccessService.get_public_library_info()
            
            if result['success']:
                return Response({
                    'success': True,
                    'message': result['message'],
                    'data': result['library_data']
                }, status=status.HTTP_200_OK)
            else:
                return Response({
                    'success': False,
                    'message': result['message']
                }, status=status.HTTP_404_NOT_FOUND)
                
        except Exception as e:
            logger.error(f"Error retrieving public library info: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve library information',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# =====================================
# BOOK MANAGEMENT VIEWS
# =====================================

class BookCreateView(generics.CreateAPIView):
    """
    Create a new book.
    Only library administrators can create books.
    Books belong to the current active library.
    """
    serializer_class = BookCreateSerializer
    permission_classes = [permissions.IsAuthenticated, IsSystemAdmin]
    
    def create(self, request, *args, **kwargs):
        """
        Create a new book with the provided data.
        """
        try:
            # Check if library exists
            library = Library.get_current_library()
            if not library:
                return Response({
                    'success': False,
                    'message': 'No active library found. Please create a library first.',
                    'error_code': 'NO_LIBRARY'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Handle case-insensitive field names for form-data
            data = request.data.copy()
            normalized_data = {}
            
            # Debug logging for images
            logger.info(f"Original request.data keys: {list(request.data.keys())}")
            if 'images' in request.data:
                logger.info(f"Images in request.data: {request.data['images']}")
                logger.info(f"Type of images: {type(request.data['images'])}")
            
            # Check if getlist is available and what it returns
            if hasattr(request.data, 'getlist'):
                images_list = request.data.getlist('images')
                logger.info(f"Images from getlist: {images_list}")
                logger.info(f"Length of images list: {len(images_list) if images_list else 0}")
            
            for key, value in data.items():
                if key.lower() == 'images':
                    # Handle multiple image uploads from Postman
                    if hasattr(request.data, 'getlist'):
                        # Get all files with the 'images' key
                        images_list = request.data.getlist('images')
                        normalized_data[key.lower()] = [img for img in images_list if img]
                        logger.info(f"Final normalized images: {len(normalized_data[key.lower()])} images")
                    elif isinstance(value, list):
                        normalized_data[key.lower()] = value
                    else:
                        # Convert single image to list
                        normalized_data[key.lower()] = [value] if value else []
                else:
                    normalized_data[key.lower()] = value
            
            # Create serializer with normalized data
            serializer = self.get_serializer(data=normalized_data)
            serializer.is_valid(raise_exception=True)
            
            # Save the new book
            book = serializer.save()
            
            # Return response with book data
            response_serializer = BookDetailSerializer(book)
            
            logger.info(f"Book '{book.name}' created by {request.user.email}")
            
            return Response({
                'success': True,
                'message': 'Book created successfully',
                'data': response_serializer.data
            }, status=status.HTTP_201_CREATED)
                
        except Exception as e:
            logger.error(f"Error creating book: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to create book',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class BookListView(generics.ListAPIView):
    """
    List all books in the current library.
    Available to all authenticated users.
    """
    serializer_class = BookListSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        """Get books filtered by current library and search parameters."""
        # Get current library
        library = Library.get_current_library()
        if not library:
            return Book.objects.none()
        
        queryset = Book.objects.filter(library=library)
        
        # Handle search parameters
        query = self.request.query_params.get('search', None)
        is_available = self.request.query_params.get('is_available', None)
        is_new = self.request.query_params.get('is_new', None)
        author = self.request.query_params.get('author', None)
        category = self.request.query_params.get('category', None)
        min_price = self.request.query_params.get('min_price', None)
        max_price = self.request.query_params.get('max_price', None)
        new_books_days = self.request.query_params.get('new_books_days', None)
        ordering = self.request.query_params.get('ordering', None)
        
        # Search by name or author
        if query:
            from django.db.models import Q
            queryset = queryset.filter(
                Q(name__icontains=query) | Q(author__icontains=query)
            )
        
        # Filter by availability
        if is_available is not None:
            is_available_bool = is_available.lower() in ['true', '1', 'yes']
            queryset = queryset.filter(is_available=is_available_bool)
        
        # Filter by new books
        if is_new is not None:
            is_new_bool = is_new.lower() in ['true', '1', 'yes']
            if is_new_bool:
                # Show books marked as new OR created within specified days
                days = 30  # default
                if new_books_days:
                    try:
                        days = int(new_books_days)
                    except (ValueError, TypeError):
                        days = 30
                
                from django.utils import timezone
                from datetime import timedelta
                cutoff_date = timezone.now() - timedelta(days=days)
                
                queryset = queryset.filter(
                    Q(is_new=True) | Q(created_at__gte=cutoff_date)
                )
            else:
                queryset = queryset.filter(is_new=False)
        
        # Filter by author
        if author:
            queryset = queryset.filter(author__icontains=author)
        
        # Filter by category
        if category:
            try:
                category_id = int(category)
                queryset = queryset.filter(category_id=category_id)
            except (ValueError, TypeError):
                pass  # Ignore invalid category values
        
        # Filter by price range
        if min_price:
            try:
                min_price_decimal = float(min_price)
                queryset = queryset.filter(price__gte=min_price_decimal)
            except (ValueError, TypeError):
                pass  # Ignore invalid price values
        
        if max_price:
            try:
                max_price_decimal = float(max_price)
                queryset = queryset.filter(price__lte=max_price_decimal)
            except (ValueError, TypeError):
                pass  # Ignore invalid price values
        
        # Handle ordering/sorting
        if ordering:
            valid_orderings = {
                'newest': '-created_at',
                'oldest': 'created_at',
                'name_asc': 'name',
                'name_desc': '-name',
                'author_asc': 'author',
                'author_desc': '-author',
                'price_asc': 'price',
                'price_desc': '-price',
            }
            if ordering in valid_orderings:
                queryset = queryset.order_by(valid_orderings[ordering])
            else:
                queryset = queryset.order_by('-created_at')  # default newest first
        else:
            queryset = queryset.order_by('-created_at')  # default newest first
        
        return queryset
    
    def list(self, request, *args, **kwargs):
        """List books with pagination and search."""
        try:
            queryset = self.get_queryset()
            
            # Check if library exists
            if not Library.get_current_library():
                return Response({
                    'success': False,
                    'message': 'No active library found',
                    'error_code': 'NO_LIBRARY'
                }, status=status.HTTP_404_NOT_FOUND)
            
            # Pagination
            page = self.paginate_queryset(queryset)
            if page is not None:
                serializer = self.get_serializer(page, many=True)
                return self.get_paginated_response({
                    'success': True,
                    'message': 'Books retrieved successfully',
                    'data': serializer.data
                })
            
            serializer = self.get_serializer(queryset, many=True)
            return Response({
                'success': True,
                'message': 'Books retrieved successfully',
                'data': serializer.data,
                'count': queryset.count()
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving books: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve books',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class BookDetailView(generics.RetrieveAPIView):
    """
    Retrieve detailed information about a specific book.
    Available to all authenticated users.
    """
    serializer_class = BookDetailSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_object(self):
        """Get book by ID."""
        book_id = self.kwargs.get('pk')
        try:
            return Book.objects.get(id=book_id)
        except Book.DoesNotExist:
            from rest_framework.exceptions import NotFound
            raise NotFound("Book not found")
    
    def retrieve(self, request, *args, **kwargs):
        """Retrieve book details."""
        try:
            book = self.get_object()
            serializer = self.get_serializer(book)
            
            return Response({
                'success': True,
                'message': 'Book details retrieved successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving book: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve book details',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class BookUpdateView(generics.UpdateAPIView):
    """
    Update book information.
    Only library administrators can update books.
    """
    serializer_class = BookUpdateSerializer
    permission_classes = [permissions.IsAuthenticated, IsSystemAdmin]
    
    def get_object(self):
        """Get book by ID."""
        book_id = self.kwargs.get('pk')
        try:
            return Book.objects.get(id=book_id)
        except Book.DoesNotExist:
            from rest_framework.exceptions import NotFound
            raise NotFound("Book not found")
    
    def update(self, request, *args, **kwargs):
        """Update book with the provided data."""
        try:
            # Handle case-insensitive field names for form-data
            data = request.data.copy()
            normalized_data = {}
            for key, value in data.items():
                if key.lower() == 'new_images':
                    # Handle multiple new image uploads from Postman
                    if hasattr(request.data, 'getlist'):
                        # Get all files with the 'new_images' key
                        new_images_list = request.data.getlist('new_images')
                        normalized_data[key.lower()] = [img for img in new_images_list if img]
                    elif isinstance(value, list):
                        normalized_data[key.lower()] = value
                    else:
                        normalized_data[key.lower()] = [value] if value else []
                elif key.lower() == 'remove_images':
                    # Handle image removal IDs
                    if isinstance(value, list):
                        normalized_data[key.lower()] = value
                    else:
                        # Convert single ID to list
                        try:
                            normalized_data[key.lower()] = [int(value)] if value else []
                        except (ValueError, TypeError):
                            normalized_data[key.lower()] = []
                else:
                    normalized_data[key.lower()] = value
            
            # Get the book instance
            instance = self.get_object()
            
            # Create serializer with normalized data
            serializer = self.get_serializer(instance, data=normalized_data, partial=True)
            serializer.is_valid(raise_exception=True)
            
            # Save the updated book
            updated_book = serializer.save()
            
            # Return response with book data
            response_serializer = BookDetailSerializer(updated_book)
            
            return Response({
                'success': True,
                'message': 'Book updated successfully',
                'data': response_serializer.data
            }, status=status.HTTP_200_OK)
                
        except Exception as e:
            logger.error(f"Error updating book: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to update book',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class BookDeleteView(generics.DestroyAPIView):
    """
    Delete a book.
    Only library administrators can delete books.
    """
    permission_classes = [permissions.IsAuthenticated, IsSystemAdmin]
    
    def get_object(self):
        """Get book by ID."""
        book_id = self.kwargs.get('pk')
        try:
            return Book.objects.get(id=book_id)
        except Book.DoesNotExist:
            from rest_framework.exceptions import NotFound
            raise NotFound("Book not found")
    
    def delete(self, request, *args, **kwargs):
        """Delete the specified book."""
        try:
            # Get the book instance
            instance = self.get_object()
            book_name = instance.name
            book_author = instance.author
            
            # Perform the delete
            instance.delete()
            
            logger.info(f"Book '{book_name}' by {book_author} deleted by {request.user.email}")
            
            return Response({
                'success': True,
                'message': f"Book '{book_name}' by {book_author} deleted successfully."
            }, status=status.HTTP_200_OK)
                
        except Exception as e:
            logger.error(f"Error deleting book: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to delete book',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class BookManagementView(APIView):
    """
    Book management dashboard for library administrators.
    Provides comprehensive book management operations and statistics.
    """
    permission_classes = [permissions.IsAuthenticated, IsSystemAdmin]
    
    def get(self, request):
        """Get book management dashboard data."""
        try:
            # Check if library exists
            library = Library.get_current_library()
            if not library:
                return Response({
                    'success': False,
                    'message': 'No active library found',
                    'error_code': 'NO_LIBRARY'
                }, status=status.HTTP_404_NOT_FOUND)
            
            # Get book statistics
            stats = BookManagementService.get_book_stats(library)
            
            # Serialize recent books
            recent_books_serializer = BookListSerializer(stats['recent_books'], many=True)
            
            return Response({
                'success': True,
                'message': 'Book management data retrieved successfully',
                'data': {
                    'library': {
                        'id': library.id,
                        'name': library.name,
                    },
                    'statistics': {
                        'total_books': stats['total_books'],
                        'available_books': stats['available_books'],
                        'unavailable_books': stats['unavailable_books'],
                        'total_authors': stats['total_authors'],
                        'books_with_images': stats['books_with_images'],
                    },
                    'recent_books': recent_books_serializer.data,
                }
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving book management data: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve book management data',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# =====================================
# ADVANCED BOOK FILTERING VIEWS
# =====================================

class NewBooksView(generics.ListAPIView):
    """
    Get only new books (marked as new or created within specified days).
    Available to all authenticated users.
    """
    serializer_class = BookListSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        """Get new books."""
        library = Library.get_current_library()
        if not library:
            return Book.objects.none()
        
        # Get days parameter (default 30 days)
        days = self.request.query_params.get('days', 30)
        try:
            days = int(days)
        except (ValueError, TypeError):
            days = 30
        
        # Use the Book model method
        queryset = Book.get_new_books(library=library, days=days)
        
        # Apply additional filters if provided
        is_available = self.request.query_params.get('is_available', None)
        if is_available is not None:
            is_available_bool = is_available.lower() in ['true', '1', 'yes']
            queryset = queryset.filter(is_available=is_available_bool)
        
        return queryset.order_by('-created_at')
    
    def list(self, request, *args, **kwargs):
        """List new books."""
        try:
            queryset = self.get_queryset()
            
            # Check if library exists
            if not Library.get_current_library():
                return Response({
                    'success': False,
                    'message': 'No active library found',
                    'error_code': 'NO_LIBRARY'
                }, status=status.HTTP_404_NOT_FOUND)
            
            # Pagination
            page = self.paginate_queryset(queryset)
            if page is not None:
                serializer = self.get_serializer(page, many=True)
                return self.get_paginated_response({
                    'success': True,
                    'message': 'New books retrieved successfully',
                    'data': serializer.data
                })
            
            serializer = self.get_serializer(queryset, many=True)
            days = self.request.query_params.get('days', 30)
            
            return Response({
                'success': True,
                'message': f'New books retrieved successfully (within {days} days)',
                'data': serializer.data,
                'count': queryset.count(),
                'filter_criteria': {
                    'days': days,
                    'criteria': 'Books marked as new OR created within the specified days'
                }
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving new books: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve new books',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class BooksByCategoryView(generics.ListAPIView):
    """
    Get books by specific category.
    Available to all authenticated users.
    """
    serializer_class = BookListSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        """Get books by category."""
        library = Library.get_current_library()
        if not library:
            return Book.objects.none()
        
        category_id = self.kwargs.get('category_id')
        if not category_id:
            return Book.objects.none()
        
        # Use the Book model method
        queryset = Book.get_books_by_category(category_id=category_id, library=library)
        
        # Apply additional filters if provided
        is_available = self.request.query_params.get('is_available', None)
        if is_available is not None:
            is_available_bool = is_available.lower() in ['true', '1', 'yes']
            queryset = queryset.filter(is_available=is_available_bool)
        
        # Handle ordering
        ordering = self.request.query_params.get('ordering', 'newest')
        valid_orderings = {
            'newest': '-created_at',
            'oldest': 'created_at',
            'name_asc': 'name',
            'name_desc': '-name',
            'author_asc': 'author',
            'author_desc': '-author',
            'price_asc': 'price',
            'price_desc': '-price',
        }
        if ordering in valid_orderings:
            queryset = queryset.order_by(valid_orderings[ordering])
        else:
            queryset = queryset.order_by('-created_at')
        
        return queryset
    
    def list(self, request, *args, **kwargs):
        """List books by category."""
        try:
            category_id = self.kwargs.get('category_id')
            
            # Check if category exists
            try:
                category = Category.objects.get(id=category_id)
            except Category.DoesNotExist:
                return Response({
                    'success': False,
                    'message': 'Category not found',
                    'error_code': 'CATEGORY_NOT_FOUND'
                }, status=status.HTTP_404_NOT_FOUND)
            
            queryset = self.get_queryset()
            
            # Check if library exists
            if not Library.get_current_library():
                return Response({
                    'success': False,
                    'message': 'No active library found',
                    'error_code': 'NO_LIBRARY'
                }, status=status.HTTP_404_NOT_FOUND)
            
            # Pagination
            page = self.paginate_queryset(queryset)
            if page is not None:
                serializer = self.get_serializer(page, many=True)
                return self.get_paginated_response({
                    'success': True,
                    'message': f'Books in category "{category.name}" retrieved successfully',
                    'data': serializer.data,
                    'category': {
                        'id': category.id,
                        'name': category.name,
                        'description': category.description
                    }
                })
            
            serializer = self.get_serializer(queryset, many=True)
            
            return Response({
                'success': True,
                'message': f'Books in category "{category.name}" retrieved successfully',
                'data': serializer.data,
                'count': queryset.count(),
                'category': {
                    'id': category.id,
                    'name': category.name,
                    'description': category.description,
                    'is_active': category.is_active
                }
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving books by category: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve books by category',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class BooksByAuthorView(generics.ListAPIView):
    """
    Get books by specific author.
    Available to all authenticated users.
    """
    serializer_class = BookListSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        """Get books by author."""
        library = Library.get_current_library()
        if not library:
            return Book.objects.none()
        
        author = self.request.query_params.get('author', '')
        if not author:
            return Book.objects.none()
        
        # Use the Book model method
        queryset = Book.get_books_by_author(author=author, library=library)
        
        # Apply additional filters if provided
        is_available = self.request.query_params.get('is_available', None)
        if is_available is not None:
            is_available_bool = is_available.lower() in ['true', '1', 'yes']
            queryset = queryset.filter(is_available=is_available_bool)
        
        category = self.request.query_params.get('category', None)
        if category:
            try:
                category_id = int(category)
                queryset = queryset.filter(category_id=category_id)
            except (ValueError, TypeError):
                pass
        
        # Handle ordering
        ordering = self.request.query_params.get('ordering', 'newest')
        valid_orderings = {
            'newest': '-created_at',
            'oldest': 'created_at',
            'name_asc': 'name',
            'name_desc': '-name',
            'price_asc': 'price',
            'price_desc': '-price',
        }
        if ordering in valid_orderings:
            queryset = queryset.order_by(valid_orderings[ordering])
        else:
            queryset = queryset.order_by('-created_at')
        
        return queryset
    
    def list(self, request, *args, **kwargs):
        """List books by author."""
        try:
            author = self.request.query_params.get('author', '')
            if not author:
                return Response({
                    'success': False,
                    'message': 'Author parameter is required',
                    'error_code': 'MISSING_AUTHOR'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            queryset = self.get_queryset()
            
            # Check if library exists
            if not Library.get_current_library():
                return Response({
                    'success': False,
                    'message': 'No active library found',
                    'error_code': 'NO_LIBRARY'
                }, status=status.HTTP_404_NOT_FOUND)
            
            # Pagination
            page = self.paginate_queryset(queryset)
            if page is not None:
                serializer = self.get_serializer(page, many=True)
                return self.get_paginated_response({
                    'success': True,
                    'message': f'Books by author "{author}" retrieved successfully',
                    'data': serializer.data,
                    'author': author
                })
            
            serializer = self.get_serializer(queryset, many=True)
            
            return Response({
                'success': True,
                'message': f'Books by author "{author}" retrieved successfully',
                'data': serializer.data,
                'count': queryset.count(),
                'author': author
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving books by author: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve books by author',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class BooksByPriceRangeView(generics.ListAPIView):
    """
    Get books within a specific price range.
    Available to all authenticated users.
    """
    serializer_class = BookListSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        """Get books within price range."""
        library = Library.get_current_library()
        if not library:
            return Book.objects.none()
        
        min_price = self.request.query_params.get('min_price', None)
        max_price = self.request.query_params.get('max_price', None)
        
        # Convert to decimal
        min_price_decimal = None
        max_price_decimal = None
        
        if min_price:
            try:
                min_price_decimal = float(min_price)
            except (ValueError, TypeError):
                pass
        
        if max_price:
            try:
                max_price_decimal = float(max_price)
            except (ValueError, TypeError):
                pass
        
        # Use the Book model method
        queryset = Book.get_books_by_price_range(
            min_price=min_price_decimal, 
            max_price=max_price_decimal, 
            library=library
        )
        
        # Apply additional filters if provided
        is_available = self.request.query_params.get('is_available', None)
        if is_available is not None:
            is_available_bool = is_available.lower() in ['true', '1', 'yes']
            queryset = queryset.filter(is_available=is_available_bool)
        
        category = self.request.query_params.get('category', None)
        if category:
            try:
                category_id = int(category)
                queryset = queryset.filter(category_id=category_id)
            except (ValueError, TypeError):
                pass
        
        # Handle ordering
        ordering = self.request.query_params.get('ordering', 'price_asc')
        valid_orderings = {
            'newest': '-created_at',
            'oldest': 'created_at',
            'name_asc': 'name',
            'name_desc': '-name',
            'author_asc': 'author',
            'author_desc': '-author',
            'price_asc': 'price',
            'price_desc': '-price',
        }
        if ordering in valid_orderings:
            queryset = queryset.order_by(valid_orderings[ordering])
        else:
            queryset = queryset.order_by('price')
        
        return queryset
    
    def list(self, request, *args, **kwargs):
        """List books within price range."""
        try:
            min_price = self.request.query_params.get('min_price', None)
            max_price = self.request.query_params.get('max_price', None)
            
            if not min_price and not max_price:
                return Response({
                    'success': False,
                    'message': 'At least one price parameter (min_price or max_price) is required',
                    'error_code': 'MISSING_PRICE_PARAMS'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            queryset = self.get_queryset()
            
            # Check if library exists
            if not Library.get_current_library():
                return Response({
                    'success': False,
                    'message': 'No active library found',
                    'error_code': 'NO_LIBRARY'
                }, status=status.HTTP_404_NOT_FOUND)
            
            # Pagination
            page = self.paginate_queryset(queryset)
            if page is not None:
                serializer = self.get_serializer(page, many=True)
                return self.get_paginated_response({
                    'success': True,
                    'message': 'Books within price range retrieved successfully',
                    'data': serializer.data,
                    'price_range': {
                        'min_price': min_price,
                        'max_price': max_price
                    }
                })
            
            serializer = self.get_serializer(queryset, many=True)
            
            return Response({
                'success': True,
                'message': 'Books within price range retrieved successfully',
                'data': serializer.data,
                'count': queryset.count(),
                'price_range': {
                    'min_price': min_price,
                    'max_price': max_price
                }
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving books by price range: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve books by price range',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# =====================================
# CATEGORY MANAGEMENT VIEWS
# =====================================

class CategoryCreateView(generics.CreateAPIView):
    """
    Create a new category.
    Only library administrators can create categories.
    """
    serializer_class = CategoryCreateSerializer
    permission_classes = [permissions.IsAuthenticated, IsSystemAdmin]
    
    def create(self, request, *args, **kwargs):
        """Create a new category with the provided data."""
        try:
            # Handle case-insensitive field names for form-data
            data = request.data.copy()
            normalized_data = {}
            for key, value in data.items():
                normalized_data[key.lower()] = value
            
            # Create serializer with normalized data
            serializer = self.get_serializer(data=normalized_data)
            serializer.is_valid(raise_exception=True)
            
            # Save the new category
            category = serializer.save()
            
            # Return response with category data
            response_serializer = CategoryDetailSerializer(category)
            
            logger.info(f"Category '{category.name}' created by {request.user.email}")
            
            return Response({
                'success': True,
                'message': 'Category created successfully',
                'data': response_serializer.data
            }, status=status.HTTP_201_CREATED)
                
        except Exception as e:
            logger.error(f"Error creating category: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to create category',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class CategoryListView(generics.ListAPIView):
    """
    List all categories.
    Available to all authenticated users.
    """
    serializer_class = CategoryListSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        """Get categories filtered by status."""
        queryset = Category.objects.all()
        
        # Handle filtering parameters
        is_active = self.request.query_params.get('is_active', None)
        search = self.request.query_params.get('search', None)
        
        if is_active is not None:
            is_active_bool = is_active.lower() in ['true', '1', 'yes']
            queryset = queryset.filter(is_active=is_active_bool)
        
        if search:
            from django.db.models import Q
            queryset = queryset.filter(
                Q(name__icontains=search) | Q(description__icontains=search)
            )
        
        return queryset.order_by('name')
    
    def list(self, request, *args, **kwargs):
        """List categories with filtering and search."""
        try:
            queryset = self.get_queryset()
            
            # Pagination
            page = self.paginate_queryset(queryset)
            if page is not None:
                serializer = self.get_serializer(page, many=True)
                return self.get_paginated_response({
                    'success': True,
                    'message': 'Categories retrieved successfully',
                    'data': serializer.data
                })
            
            serializer = self.get_serializer(queryset, many=True)
            return Response({
                'success': True,
                'message': 'Categories retrieved successfully',
                'data': serializer.data,
                'count': queryset.count()
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving categories: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve categories',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class CategoryDetailView(generics.RetrieveAPIView):
    """
    Retrieve detailed information about a specific category.
    Available to all authenticated users.
    """
    serializer_class = CategoryDetailSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_object(self):
        """Get category by ID."""
        category_id = self.kwargs.get('pk')
        try:
            return Category.objects.get(id=category_id)
        except Category.DoesNotExist:
            from rest_framework.exceptions import NotFound
            raise NotFound("Category not found")
    
    def retrieve(self, request, *args, **kwargs):
        """Retrieve category details."""
        try:
            category = self.get_object()
            serializer = self.get_serializer(category)
            
            return Response({
                'success': True,
                'message': 'Category details retrieved successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving category: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve category details',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class CategoryUpdateView(generics.UpdateAPIView):
    """
    Update category information.
    Only library administrators can update categories.
    """
    serializer_class = CategoryUpdateSerializer
    permission_classes = [permissions.IsAuthenticated, IsSystemAdmin]
    
    def get_object(self):
        """Get category by ID."""
        category_id = self.kwargs.get('pk')
        try:
            return Category.objects.get(id=category_id)
        except Category.DoesNotExist:
            from rest_framework.exceptions import NotFound
            raise NotFound("Category not found")
    
    def update(self, request, *args, **kwargs):
        """Update category with the provided data."""
        try:
            # Handle case-insensitive field names for form-data
            data = request.data.copy()
            normalized_data = {}
            for key, value in data.items():
                normalized_data[key.lower()] = value
            
            # Get the category instance
            instance = self.get_object()
            
            # Create serializer with normalized data
            serializer = self.get_serializer(instance, data=normalized_data, partial=True)
            serializer.is_valid(raise_exception=True)
            
            # Save the updated category
            updated_category = serializer.save()
            
            # Return response with category data
            response_serializer = CategoryDetailSerializer(updated_category)
            
            return Response({
                'success': True,
                'message': 'Category updated successfully',
                'data': response_serializer.data
            }, status=status.HTTP_200_OK)
                
        except Exception as e:
            logger.error(f"Error updating category: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to update category',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class CategoryDeleteView(generics.DestroyAPIView):
    """
    Delete a category.
    Only library administrators can delete categories.
    """
    permission_classes = [permissions.IsAuthenticated, IsSystemAdmin]
    
    def get_object(self):
        """Get category by ID."""
        category_id = self.kwargs.get('pk')
        try:
            return Category.objects.get(id=category_id)
        except Category.DoesNotExist:
            from rest_framework.exceptions import NotFound
            raise NotFound("Category not found")
    
    def delete(self, request, *args, **kwargs):
        """Delete the specified category."""
        try:
            # Get the category instance
            instance = self.get_object()
            category_name = instance.name
            books_count = instance.get_books_count()
            
            # Check if category has books assigned
            if books_count > 0:
                return Response({
                    'success': False,
                    'message': f"Cannot delete category '{category_name}' because it has {books_count} book(s) assigned to it. Please reassign or remove these books first.",
                    'error_code': 'CATEGORY_HAS_BOOKS'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Perform the delete
            instance.delete()
            
            logger.info(f"Category '{category_name}' deleted by {request.user.email}")
            
            return Response({
                'success': True,
                'message': f"Category '{category_name}' deleted successfully."
            }, status=status.HTTP_200_OK)
                
        except Exception as e:
            logger.error(f"Error deleting category: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to delete category',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class CategoryManagementView(APIView):
    """
    Category management dashboard for library administrators.
    Provides comprehensive category management operations and statistics.
    """
    permission_classes = [permissions.IsAuthenticated, IsSystemAdmin]
    
    def get(self, request):
        """Get category management dashboard data."""
        try:
            # Get category statistics
            stats = Category.get_category_stats()
            
            # Get all categories
            categories = Category.objects.all().order_by('name')
            categories_serializer = CategoryListSerializer(categories, many=True)
            
            return Response({
                'success': True,
                'message': 'Category management data retrieved successfully',
                'data': {
                    'statistics': stats,
                    'categories': categories_serializer.data,
                }
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving category management data: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve category management data',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class CategoryChoicesView(generics.ListAPIView):
    """
    Get active categories for dropdown/choice selection.
    Available to all authenticated users.
    """
    serializer_class = CategoryChoiceSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        """Get only active categories."""
        return Category.get_active_categories()
    
    def list(self, request, *args, **kwargs):
        """List active categories for choices."""
        try:
            queryset = self.get_queryset()
            serializer = self.get_serializer(queryset, many=True)
            
            return Response({
                'success': True,
                'message': 'Active categories retrieved successfully',
                'data': serializer.data,
                'count': queryset.count()
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving category choices: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve category choices',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# =====================================
# AUTHOR MANAGEMENT VIEWS
# =====================================

class AuthorCreateView(generics.CreateAPIView):
    """
    Create a new author.
    Only library administrators can create authors.
    """
    serializer_class = AuthorCreateSerializer
    permission_classes = [permissions.IsAuthenticated, IsSystemAdmin]
    
    def create(self, request, *args, **kwargs):
        """Create a new author with the provided data."""
        try:
            # Handle case-insensitive field names for form-data
            data = request.data.copy()
            normalized_data = {}
            for key, value in data.items():
                normalized_data[key.lower()] = value
            
            # Create serializer with normalized data
            serializer = self.get_serializer(data=normalized_data)
            serializer.is_valid(raise_exception=True)
            
            # Save the new author
            author = serializer.save()
            
            # Return response with author data
            response_serializer = AuthorDetailSerializer(author)
            
            logger.info(f"Author '{author.name}' created by {request.user.email}")
            
            return Response({
                'success': True,
                'message': 'Author created successfully',
                'data': response_serializer.data
            }, status=status.HTTP_201_CREATED)
                
        except Exception as e:
            logger.error(f"Error creating author: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to create author',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class AuthorListView(generics.ListAPIView):
    """
    List all authors.
    Available to all authenticated users.
    """
    serializer_class = AuthorListSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        """Get authors filtered by status and search parameters."""
        queryset = Author.objects.all()
        
        # Handle filtering parameters
        is_active = self.request.query_params.get('is_active', None)
        search = self.request.query_params.get('search', None)
        nationality = self.request.query_params.get('nationality', None)
        has_photo = self.request.query_params.get('has_photo', None)
        is_alive = self.request.query_params.get('is_alive', None)
        
        if is_active is not None:
            is_active_bool = is_active.lower() in ['true', '1', 'yes']
            queryset = queryset.filter(is_active=is_active_bool)
        
        if search:
            queryset = Author.search_authors(search)
        
        if nationality:
            queryset = queryset.filter(nationality__icontains=nationality)
        
        if has_photo is not None:
            has_photo_bool = has_photo.lower() in ['true', '1', 'yes']
            if has_photo_bool:
                queryset = queryset.filter(photo__isnull=False)
            else:
                queryset = queryset.filter(photo__isnull=True)
        
        if is_alive is not None:
            is_alive_bool = is_alive.lower() in ['true', '1', 'yes']
            if is_alive_bool:
                queryset = queryset.filter(death_date__isnull=True)
            else:
                queryset = queryset.filter(death_date__isnull=False)
        
        return queryset.order_by('name')
    
    def list(self, request, *args, **kwargs):
        """List authors with filtering and search."""
        try:
            queryset = self.get_queryset()
            
            # Pagination
            page = self.paginate_queryset(queryset)
            if page is not None:
                serializer = self.get_serializer(page, many=True)
                return self.get_paginated_response({
                    'success': True,
                    'message': 'Authors retrieved successfully',
                    'data': serializer.data
                })
            
            serializer = self.get_serializer(queryset, many=True)
            return Response({
                'success': True,
                'message': 'Authors retrieved successfully',
                'data': serializer.data,
                'count': queryset.count()
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving authors: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve authors',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class AuthorDetailView(generics.RetrieveAPIView):
    """
    Retrieve detailed information about a specific author.
    Available to all authenticated users.
    """
    serializer_class = AuthorDetailSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_object(self):
        """Get author by ID."""
        author_id = self.kwargs.get('pk')
        try:
            return Author.objects.get(id=author_id)
        except Author.DoesNotExist:
            from rest_framework.exceptions import NotFound
            raise NotFound("Author not found")
    
    def retrieve(self, request, *args, **kwargs):
        """Retrieve author details."""
        try:
            author = self.get_object()
            serializer = self.get_serializer(author)
            
            return Response({
                'success': True,
                'message': 'Author details retrieved successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving author: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve author details',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class AuthorWithBooksView(generics.RetrieveAPIView):
    """
    Retrieve author details with all their books.
    Available to all authenticated users.
    """
    serializer_class = AuthorWithBooksSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_object(self):
        """Get author by ID."""
        author_id = self.kwargs.get('pk')
        try:
            return Author.objects.get(id=author_id)
        except Author.DoesNotExist:
            from rest_framework.exceptions import NotFound
            raise NotFound("Author not found")
    
    def retrieve(self, request, *args, **kwargs):
        """Retrieve author details with books."""
        try:
            author = self.get_object()
            serializer = self.get_serializer(author)
            
            return Response({
                'success': True,
                'message': 'Author details with books retrieved successfully',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving author with books: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve author details with books',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class AuthorUpdateView(generics.UpdateAPIView):
    """
    Update author information.
    Only library administrators can update authors.
    """
    serializer_class = AuthorUpdateSerializer
    permission_classes = [permissions.IsAuthenticated, IsSystemAdmin]
    
    def get_object(self):
        """Get author by ID."""
        author_id = self.kwargs.get('pk')
        try:
            return Author.objects.get(id=author_id)
        except Author.DoesNotExist:
            from rest_framework.exceptions import NotFound
            raise NotFound("Author not found")
    
    def update(self, request, *args, **kwargs):
        """Update author with the provided data."""
        try:
            # Handle case-insensitive field names for form-data
            data = request.data.copy()
            normalized_data = {}
            for key, value in data.items():
                normalized_data[key.lower()] = value
            
            # Get the author instance
            instance = self.get_object()
            
            # Create serializer with normalized data
            serializer = self.get_serializer(instance, data=normalized_data, partial=True)
            serializer.is_valid(raise_exception=True)
            
            # Save the updated author
            updated_author = serializer.save()
            
            # Return response with author data
            response_serializer = AuthorDetailSerializer(updated_author)
            
            return Response({
                'success': True,
                'message': 'Author updated successfully',
                'data': response_serializer.data
            }, status=status.HTTP_200_OK)
                
        except Exception as e:
            logger.error(f"Error updating author: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to update author',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class AuthorDeleteView(generics.DestroyAPIView):
    """
    Delete an author.
    Only library administrators can delete authors.
    """
    permission_classes = [permissions.IsAuthenticated, IsSystemAdmin]
    
    def get_object(self):
        """Get author by ID."""
        author_id = self.kwargs.get('pk')
        try:
            return Author.objects.get(id=author_id)
        except Author.DoesNotExist:
            from rest_framework.exceptions import NotFound
            raise NotFound("Author not found")
    
    def delete(self, request, *args, **kwargs):
        """Delete the specified author."""
        try:
            # Get the author instance
            instance = self.get_object()
            author_name = instance.name
            books_count = instance.get_books_count()
            
            # Check if author has books assigned
            if books_count > 0:
                return Response({
                    'success': False,
                    'message': f"Cannot delete author '{author_name}' because they have {books_count} book(s) in the library. Please reassign or remove these books first.",
                    'error_code': 'AUTHOR_HAS_BOOKS'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Perform the delete
            instance.delete()
            
            logger.info(f"Author '{author_name}' deleted by {request.user.email}")
            
            return Response({
                'success': True,
                'message': f"Author '{author_name}' deleted successfully."
            }, status=status.HTTP_200_OK)
                
        except Exception as e:
            logger.error(f"Error deleting author: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to delete author',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class AuthorManagementView(APIView):
    """
    Author management dashboard for library administrators.
    Provides comprehensive author management operations and statistics.
    """
    permission_classes = [permissions.IsAuthenticated, IsSystemAdmin]
    
    def get(self, request):
        """Get author management dashboard data."""
        try:
            # Get author statistics
            stats = Author.get_author_stats()
            
            # Get all authors
            authors = Author.objects.all().order_by('name')
            authors_serializer = AuthorListSerializer(authors, many=True)
            
            return Response({
                'success': True,
                'message': 'Author management data retrieved successfully',
                'data': {
                    'statistics': stats,
                    'authors': authors_serializer.data,
                }
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving author management data: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve author management data',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class AuthorChoicesView(generics.ListAPIView):
    """
    Get active authors for dropdown/choice selection.
    Available to all authenticated users.
    """
    serializer_class = AuthorChoiceSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        """Get only active authors."""
        return Author.get_active_authors()
    
    def list(self, request, *args, **kwargs):
        """List active authors for choices."""
        try:
            queryset = self.get_queryset()
            serializer = self.get_serializer(queryset, many=True)
            
            return Response({
                'success': True,
                'message': 'Active authors retrieved successfully',
                'data': serializer.data,
                'count': queryset.count()
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error retrieving author choices: {str(e)}")
            return Response({
                'success': False,
                'message': 'Failed to retrieve author choices',
                'errors': format_error_message(str(e))
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR) 
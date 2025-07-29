"""
Library Management Services

This module provides services for managing library operations.
All operations are restricted to library administrators.
The system supports only one active library at a time.
"""

from django.core.exceptions import ValidationError, PermissionDenied
from django.db import transaction
from typing import Dict, Any, Optional
import logging

from ..models import Library, User, Book, BookImage, Category

logger = logging.getLogger(__name__)


class LibraryManagementService:
    """
    Service class for library management operations.
    Only library administrators can perform these operations.
    """
    
    @staticmethod
    def validate_library_admin(user: User) -> Dict[str, Any]:
        """
        Validate that the user is a library administrator.
        
        Args:
            user: User instance to validate
            
        Returns:
            Dict containing validation result
        """
        if not user or not user.is_authenticated:
            return {
                'is_valid': False,
                'message': 'User must be authenticated'
            }
        
        if not user.is_library_admin():
            return {
                'is_valid': False,
                'message': 'Only library administrators can perform this action'
            }
        
        return {'is_valid': True}

    # Keep old method for backward compatibility (deprecated)
    @staticmethod
    def validate_system_admin(user: User) -> Dict[str, Any]:
        """
        Validate that the user is a library administrator (deprecated - use validate_library_admin).
        
        Args:
            user: User instance to validate
            
        Returns:
            Dict containing validation result
        """
        return LibraryManagementService.validate_library_admin(user)
    
    @staticmethod
    @transaction.atomic
    def create_library(user: User, library_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Create a new library.
        
        Args:
            user: The user attempting to create the library
            library_data: Dictionary containing library information
            
        Returns:
            Dictionary with success status and library data or error message
        """
        try:
            # Validate user permissions
            validation_result = LibraryManagementService.validate_library_admin(user)
            if not validation_result.get('is_valid', False):
                return {
                    'success': False,
                    'message': validation_result.get('message', 'Permission denied'),
                    'error_code': 'PERMISSION_DENIED'
                }
            
            # Check if a library can be created
            if not Library.can_create_library():
                existing_library = Library.get_current_library()
                return {
                    'success': False,
                    'message': f"Only one library can exist at a time. "
                              f"Please delete the existing library '{existing_library.name}' first.",
                    'error_code': 'LIBRARY_EXISTS'
                }
            
            # Create the library
            library = Library.objects.create(
                name=library_data.get('name'),
                logo=library_data.get('logo'),
                details=library_data.get('details'),
                created_by=user,
                last_updated_by=user
            )
            
            logger.info(f"Library '{library.name}' created by {user.email}")
            
            # Prepare library data for response
            library_data = {
                'id': library.id,
                'name': library.name,
                'details': library.details,
                'logo': library.logo.url if library.logo else None,
                'created_by': {
                    'id': user.id,
                    'email': user.email,
                    'first_name': user.first_name,
                    'last_name': user.last_name
                },
                'created_at': library.created_at.isoformat(),
                'updated_at': library.updated_at.isoformat(),
                'is_active': library.is_active
            }
            
            return {
                'success': True,
                'message': 'Library created successfully',
                'library_data': library_data
            }
            
        except ValidationError as e:
            logger.error(f"Validation error creating library: {str(e)}")
            return {
                'success': False,
                'message': str(e),
                'error_code': 'VALIDATION_ERROR'
            }
        except Exception as e:
            logger.error(f"Error creating library: {str(e)}")
            return {
                'success': False,
                'message': 'Failed to create library',
                'error_code': 'CREATION_ERROR'
            }
    
    @staticmethod
    @transaction.atomic
    def update_library(user: User, library_id: int, update_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Update an existing library.
        
        Args:
            user: The user attempting to update the library
            library_id: ID of the library to update
            update_data: Dictionary containing updated library information
            
        Returns:
            Dictionary with success status and library data or error message
        """
        try:
            # Validate user permissions
            validation_result = LibraryManagementService.validate_library_admin(user)
            if not validation_result.get('is_valid', False):
                return {
                    'success': False,
                    'message': validation_result.get('message', 'Permission denied'),
                    'error_code': 'PERMISSION_DENIED'
                }
            
            # Get the library
            try:
                library = Library.objects.get(id=library_id, is_active=True)
            except Library.DoesNotExist:
                return {
                    'success': False,
                    'message': 'Library not found or is not active',
                    'error_code': 'LIBRARY_NOT_FOUND'
                }
            
            # Update library fields
            for field, value in update_data.items():
                if hasattr(library, field):
                    if field == 'logo' and value is None:
                        # Handle logo deletion
                        if library.logo:
                            library.logo.delete(save=False)
                    setattr(library, field, value)
            
            # Set last updated by
            library.last_updated_by = user
            library.save()
            
            logger.info(f"Library '{library.name}' updated by {user.email}")
            
            # Prepare library data for response
            library_data = {
                'id': library.id,
                'name': library.name,
                'details': library.details,
                'logo': library.logo.url if library.logo else None,
                'created_by': {
                    'id': library.created_by.id,
                    'email': library.created_by.email,
                    'first_name': library.created_by.first_name,
                    'last_name': library.created_by.last_name
                },
                'last_updated_by': {
                    'id': user.id,
                    'email': user.email,
                    'first_name': user.first_name,
                    'last_name': user.last_name
                },
                'created_at': library.created_at.isoformat(),
                'updated_at': library.updated_at.isoformat(),
                'is_active': library.is_active
            }
            
            return {
                'success': True,
                'message': 'Library updated successfully',
                'library_data': library_data
            }
            
        except ValidationError as e:
            logger.error(f"Validation error updating library: {str(e)}")
            return {
                'success': False,
                'message': str(e),
                'error_code': 'VALIDATION_ERROR'
            }
        except Exception as e:
            logger.error(f"Error updating library {library_id}: {str(e)}")
            return {
                'success': False,
                'message': 'Failed to update library',
                'error_code': 'UPDATE_ERROR'
            }
    
    @staticmethod
    @transaction.atomic
    def delete_library(user: User, library_id: int) -> Dict[str, Any]:
        """
        Delete a library.
        
        Args:
            user: The user attempting to delete the library
            library_id: ID of the library to delete
            
        Returns:
            Dictionary with success status and message
        """
        try:
            # Validate user permissions
            validation_result = LibraryManagementService.validate_library_admin(user)
            if not validation_result.get('is_valid', False):
                return {
                    'success': False,
                    'message': validation_result.get('message', 'Permission denied'),
                    'error_code': 'PERMISSION_DENIED'
                }
            
            # Get the library
            try:
                library = Library.objects.get(id=library_id)
            except Library.DoesNotExist:
                return {
                    'success': False,
                    'message': 'Library not found',
                    'error_code': 'LIBRARY_NOT_FOUND'
                }
            
            library_name = library.name
            
            # Delete the library (this will also delete the logo file)
            library.delete()
            
            logger.info(f"Library '{library_name}' deleted by {user.email}")
            
            return {
                'success': True,
                'message': f"Library '{library_name}' deleted successfully. You can now create a new library.",
                'can_create_new': True
            }
            
        except Exception as e:
            logger.error(f"Error deleting library {library_id}: {str(e)}")
            return {
                'success': False,
                'message': 'Failed to delete library',
                'error_code': 'DELETION_ERROR'
            }
    
    @staticmethod
    def get_current_library() -> Optional[Library]:
        """
        Get the current active library.
        
        Returns:
            Library instance or None if no active library exists
        """
        return Library.get_current_library()
    
    @staticmethod
    def get_library_stats() -> Dict[str, Any]:
        """
        Get library statistics.
        
        Returns:
            Dictionary containing library statistics
        """
        stats = Library.get_library_stats()
        current_library = Library.get_current_library()
        
        return {
            **stats,
            'current_library': current_library
        }
    
    @staticmethod
    def can_user_manage_library(user: User) -> bool:
        """
        Check if a user can manage library operations.
        
        Args:
            user: User to check
            
        Returns:
            Boolean indicating if user can manage libraries
        """
        return user.is_authenticated and user.is_library_admin()


class LibraryAccessService:
    """
    Service class for handling library access and information retrieval.
    These operations can be performed by any authenticated user.
    """
    
    @staticmethod
    def get_library_info() -> Dict[str, Any]:
        """
        Get public library information that any user can view.
        
        Returns:
            Dictionary containing public library information
        """
        current_library = Library.get_current_library()
        
        if not current_library:
            return {
                'has_library': False,
                'message': 'No library is currently configured'
            }
        
        return {
            'has_library': True,
            'library': {
                'id': current_library.id,
                'name': current_library.name,
                'details': current_library.details,
                'logo_url': current_library.get_logo_url(),
                'has_logo': current_library.has_logo(),
                'created_at': current_library.created_at
            }
        }
    
    @staticmethod
    def get_public_library_info() -> Dict[str, Any]:
        """
        Get public library information for external access.
        
        Returns:
            Dictionary containing public library information
        """
        current_library = Library.get_current_library()
        
        if not current_library:
            return {
                'success': False,
                'message': 'No library information available'
            }
        
        return {
            'success': True,
            'message': 'Library information retrieved successfully',
            'library_data': {
                'id': current_library.id,
                'name': current_library.name,
                'details': current_library.details,
                'logo_url': current_library.get_logo_url(),
                'has_logo': current_library.has_logo(),
                'created_at': current_library.created_at.isoformat(),
                'updated_at': current_library.updated_at.isoformat()
            }
        }
    
    @staticmethod
    def is_library_available() -> bool:
        """
        Check if a library is currently available.
        
        Returns:
            Boolean indicating if a library exists and is active
        """
        return Library.objects.filter(is_active=True).exists()


# =====================================
# BOOK MANAGEMENT SERVICES
# =====================================

class BookManagementService:
    """
    Service class for book management operations.
    Only library administrators can perform these operations.
    """
    
    @staticmethod
    def validate_library_admin(user: User) -> Dict[str, Any]:
        """
        Validate that the user is a library administrator.
        
        Args:
            user: User instance to validate
            
        Returns:
            Dict containing validation result
        """
        if not user or not user.is_authenticated:
            return {
                'is_valid': False,
                'message': 'User must be authenticated'
            }
        
        if not user.is_library_admin():
            return {
                'is_valid': False,
                'message': 'Only library administrators can perform this action'
            }
        
        return {'is_valid': True}
    
    @staticmethod
    @transaction.atomic
    def create_book(user: User, book_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Create a new book.
        
        Args:
            user: The user attempting to create the book
            book_data: Dictionary containing book information
            
        Returns:
            Dictionary with success status and book data or error message
        """
        try:
            # Validate user permissions
            validation_result = BookManagementService.validate_library_admin(user)
            if not validation_result.get('is_valid', False):
                return {
                    'success': False,
                    'message': validation_result.get('message', 'Permission denied'),
                    'error_code': 'PERMISSION_DENIED'
                }
            
            # Check if library exists
            library = Library.get_current_library()
            if not library:
                return {
                    'success': False,
                    'message': 'No active library found. Please create a library first.',
                    'error_code': 'NO_LIBRARY'
                }
            
            # Extract images data
            images_data = book_data.pop('images', [])
            
            # Create the book
            book = Book.objects.create(
                library=library,
                created_by=user,
                last_updated_by=user,
                **book_data
            )
            
            # Create book images
            for i, image_data in enumerate(images_data):
                BookImage.objects.create(
                    book=book,
                    image=image_data,
                    is_primary=(i == 0),  # First image is primary
                    uploaded_by=user,
                    alt_text=f"Image {i+1} for {book.name}"
                )
            
            logger.info(f"Book '{book.name}' created by {user.email}")
            
            # Prepare book data for response
            book_data = {
                'id': book.id,
                'name': book.name,
                'description': book.description,
                'author': book.author,
                'price': str(book.price) if book.price else None,
                'is_available': book.is_available,
                'library_name': library.name,
                'image_count': book.get_image_count(),
                'primary_image_url': book.get_primary_image_url(),
                'created_by': {
                    'id': user.id,
                    'email': user.email,
                    'first_name': user.first_name,
                    'last_name': user.last_name
                },
                'created_at': book.created_at.isoformat(),
                'updated_at': book.updated_at.isoformat(),
            }
            
            return {
                'success': True,
                'message': 'Book created successfully',
                'book_data': book_data
            }
            
        except ValidationError as e:
            logger.error(f"Validation error creating book: {str(e)}")
            return {
                'success': False,
                'message': str(e),
                'error_code': 'VALIDATION_ERROR'
            }
        except Exception as e:
            logger.error(f"Error creating book: {str(e)}")
            return {
                'success': False,
                'message': 'Failed to create book',
                'error_code': 'CREATION_ERROR'
            }
    
    @staticmethod
    @transaction.atomic
    def update_book(user: User, book_id: int, update_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Update an existing book.
        
        Args:
            user: The user attempting to update the book
            book_id: ID of the book to update
            update_data: Dictionary containing updated book information
            
        Returns:
            Dictionary with success status and book data or error message
        """
        try:
            # Validate user permissions
            validation_result = BookManagementService.validate_library_admin(user)
            if not validation_result.get('is_valid', False):
                return {
                    'success': False,
                    'message': validation_result.get('message', 'Permission denied'),
                    'error_code': 'PERMISSION_DENIED'
                }
            
            # Get the book
            try:
                book = Book.objects.get(id=book_id)
            except Book.DoesNotExist:
                return {
                    'success': False,
                    'message': 'Book not found',
                    'error_code': 'BOOK_NOT_FOUND'
                }
            
            # Extract image operations data
            new_images_data = update_data.pop('new_images', [])
            remove_images_ids = update_data.pop('remove_images', [])
            
            # Update book fields
            for field, value in update_data.items():
                if hasattr(book, field):
                    setattr(book, field, value)
            
            # Set last updated by
            book.last_updated_by = user
            book.save()
            
            # Remove specified images
            if remove_images_ids:
                BookImage.objects.filter(
                    book=book,
                    id__in=remove_images_ids
                ).delete()
            
            # Add new images
            existing_image_count = book.images.count()
            for i, image_data in enumerate(new_images_data):
                BookImage.objects.create(
                    book=book,
                    image=image_data,
                    is_primary=(existing_image_count == 0 and i == 0),
                    uploaded_by=user,
                    alt_text=f"New image for {book.name}"
                )
            
            logger.info(f"Book '{book.name}' updated by {user.email}")
            
            # Prepare book data for response
            book_data = {
                'id': book.id,
                'name': book.name,
                'description': book.description,
                'author': book.author,
                'price': str(book.price) if book.price else None,
                'is_available': book.is_available,
                'library_name': book.library.name,
                'image_count': book.get_image_count(),
                'primary_image_url': book.get_primary_image_url(),
                'created_by': {
                    'id': book.created_by.id,
                    'email': book.created_by.email,
                    'first_name': book.created_by.first_name,
                    'last_name': book.created_by.last_name
                },
                'last_updated_by': {
                    'id': user.id,
                    'email': user.email,
                    'first_name': user.first_name,
                    'last_name': user.last_name
                },
                'created_at': book.created_at.isoformat(),
                'updated_at': book.updated_at.isoformat(),
            }
            
            return {
                'success': True,
                'message': 'Book updated successfully',
                'book_data': book_data
            }
            
        except ValidationError as e:
            logger.error(f"Validation error updating book: {str(e)}")
            return {
                'success': False,
                'message': str(e),
                'error_code': 'VALIDATION_ERROR'
            }
        except Exception as e:
            logger.error(f"Error updating book {book_id}: {str(e)}")
            return {
                'success': False,
                'message': 'Failed to update book',
                'error_code': 'UPDATE_ERROR'
            }
    
    @staticmethod
    @transaction.atomic
    def delete_book(user: User, book_id: int) -> Dict[str, Any]:
        """
        Delete a book.
        
        Args:
            user: The user attempting to delete the book
            book_id: ID of the book to delete
            
        Returns:
            Dictionary with success status and message
        """
        try:
            # Validate user permissions
            validation_result = BookManagementService.validate_library_admin(user)
            if not validation_result.get('is_valid', False):
                return {
                    'success': False,
                    'message': validation_result.get('message', 'Permission denied'),
                    'error_code': 'PERMISSION_DENIED'
                }
            
            # Get the book
            try:
                book = Book.objects.get(id=book_id)
            except Book.DoesNotExist:
                return {
                    'success': False,
                    'message': 'Book not found',
                    'error_code': 'BOOK_NOT_FOUND'
                }
            
            book_name = book.name
            book_author = book.author
            
            # Delete the book (this will also delete related images)
            book.delete()
            
            logger.info(f"Book '{book_name}' by {book_author} deleted by {user.email}")
            
            return {
                'success': True,
                'message': f"Book '{book_name}' by {book_author} deleted successfully."
            }
            
        except Exception as e:
            logger.error(f"Error deleting book {book_id}: {str(e)}")
            return {
                'success': False,
                'message': 'Failed to delete book',
                'error_code': 'DELETION_ERROR'
            }
    
    @staticmethod
    def get_book_stats(library: Library = None) -> Dict[str, Any]:
        """
        Get book statistics.
        
        Args:
            library: Optional library to filter stats
            
        Returns:
            Dictionary containing book statistics
        """
        queryset = Book.objects.all()
        if library:
            queryset = queryset.filter(library=library)
        
        total_books = queryset.count()
        available_books = queryset.filter(is_available=True).count()
        unavailable_books = total_books - available_books
        
        # Get unique authors count
        total_authors = queryset.values('author').distinct().count()
        
        # Get books with images count
        books_with_images = queryset.filter(images__isnull=False).distinct().count()
        
        # Get recent books (last 10)
        recent_books = queryset.order_by('-created_at')[:10]
        
        return {
            'total_books': total_books,
            'available_books': available_books,
            'unavailable_books': unavailable_books,
            'total_authors': total_authors,
            'books_with_images': books_with_images,
            'recent_books': recent_books,
        }


class BookAccessService:
    """
    Service class for handling book access and information retrieval.
    These operations can be performed by any authenticated user.
    """
    
    @staticmethod
    def get_available_books(library: Library = None) -> Dict[str, Any]:
        """
        Get available books for public access.
        
        Args:
            library: Optional library to filter books
            
        Returns:
            Dictionary containing available books
        """
        books = Book.get_available_books(library)
        
        return {
            'success': True,
            'books': books,
            'count': books.count()
        }
    
    @staticmethod
    def search_books(query: str, library: Library = None) -> Dict[str, Any]:
        """
        Search books by name or author.
        
        Args:
            query: Search query
            library: Optional library to filter books
            
        Returns:
            Dictionary containing search results
        """
        books = Book.search_books(query, library)
        
        return {
            'success': True,
            'books': books,
            'count': books.count(),
            'query': query
        }
    
    @staticmethod
    def get_book_detail(book_id: int) -> Dict[str, Any]:
        """
        Get detailed information about a specific book.
        
        Args:
            book_id: ID of the book
            
        Returns:
            Dictionary containing book details
        """
        try:
            book = Book.objects.get(id=book_id)
            return {
                'success': True,
                'book': book
            }
        except Book.DoesNotExist:
            return {
                'success': False,
                'message': 'Book not found'
            }


# =====================================
# CATEGORY MANAGEMENT SERVICES
# =====================================

class CategoryManagementService:
    """
    Service class for category management operations.
    Only library administrators can perform these operations.
    """
    
    @staticmethod
    def validate_library_admin(user: User) -> Dict[str, Any]:
        """
        Validate that the user is a library administrator.
        
        Args:
            user: User instance to validate
            
        Returns:
            Dict containing validation result
        """
        if not user or not user.is_authenticated:
            return {
                'is_valid': False,
                'message': 'User must be authenticated'
            }
        
        if not user.is_library_admin():
            return {
                'is_valid': False,
                'message': 'Only library administrators can perform this action'
            }
        
        return {'is_valid': True}
    
    @staticmethod
    @transaction.atomic
    def create_category(user: User, category_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Create a new category.
        
        Args:
            user: The user attempting to create the category
            category_data: Dictionary containing category information
            
        Returns:
            Dictionary with success status and category data or error message
        """
        try:
            # Validate user permissions
            validation_result = CategoryManagementService.validate_library_admin(user)
            if not validation_result.get('is_valid', False):
                return {
                    'success': False,
                    'message': validation_result.get('message', 'Permission denied'),
                    'error_code': 'PERMISSION_DENIED'
                }
            
            # Check for duplicate category name (case-insensitive)
            category_name = category_data.get('name', '').strip()
            if Category.objects.filter(name__iexact=category_name).exists():
                return {
                    'success': False,
                    'message': f"A category with the name '{category_name}' already exists.",
                    'error_code': 'DUPLICATE_CATEGORY_NAME'
                }
            
            # Create the category
            category = Category.objects.create(
                created_by=user,
                last_updated_by=user,
                **category_data
            )
            
            logger.info(f"Category '{category.name}' created by {user.email}")
            
            # Prepare category data for response
            category_data = {
                'id': category.id,
                'name': category.name,
                'description': category.description,
                'is_active': category.is_active,
                'books_count': category.get_books_count(),
                'available_books_count': category.get_available_books_count(),
                'created_by': {
                    'id': user.id,
                    'email': user.email,
                    'first_name': user.first_name,
                    'last_name': user.last_name
                },
                'created_at': category.created_at.isoformat(),
                'updated_at': category.updated_at.isoformat(),
            }
            
            return {
                'success': True,
                'message': 'Category created successfully',
                'category_data': category_data
            }
            
        except ValidationError as e:
            logger.error(f"Validation error creating category: {str(e)}")
            return {
                'success': False,
                'message': str(e),
                'error_code': 'VALIDATION_ERROR'
            }
        except Exception as e:
            logger.error(f"Error creating category: {str(e)}")
            return {
                'success': False,
                'message': 'Failed to create category',
                'error_code': 'CREATION_ERROR'
            }
    
    @staticmethod
    @transaction.atomic
    def update_category(user: User, category_id: int, update_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Update an existing category.
        
        Args:
            user: The user attempting to update the category
            category_id: ID of the category to update
            update_data: Dictionary containing updated category information
            
        Returns:
            Dictionary with success status and category data or error message
        """
        try:
            # Validate user permissions
            validation_result = CategoryManagementService.validate_library_admin(user)
            if not validation_result.get('is_valid', False):
                return {
                    'success': False,
                    'message': validation_result.get('message', 'Permission denied'),
                    'error_code': 'PERMISSION_DENIED'
                }
            
            # Get the category
            try:
                category = Category.objects.get(id=category_id)
            except Category.DoesNotExist:
                return {
                    'success': False,
                    'message': 'Category not found',
                    'error_code': 'CATEGORY_NOT_FOUND'
                }
            
            # Check for duplicate category name (case-insensitive), excluding current category
            if 'name' in update_data:
                category_name = update_data.get('name', '').strip()
                existing_category = Category.objects.filter(
                    name__iexact=category_name
                ).exclude(pk=category.pk).first()
                if existing_category:
                    return {
                        'success': False,
                        'message': f"A category with the name '{category_name}' already exists.",
                        'error_code': 'DUPLICATE_CATEGORY_NAME'
                    }
            
            # Update category fields
            for field, value in update_data.items():
                if hasattr(category, field):
                    setattr(category, field, value)
            
            # Set last updated by
            category.last_updated_by = user
            category.save()
            
            logger.info(f"Category '{category.name}' updated by {user.email}")
            
            # Prepare category data for response
            category_data = {
                'id': category.id,
                'name': category.name,
                'description': category.description,
                'is_active': category.is_active,
                'books_count': category.get_books_count(),
                'available_books_count': category.get_available_books_count(),
                'created_by': {
                    'id': category.created_by.id,
                    'email': category.created_by.email,
                    'first_name': category.created_by.first_name,
                    'last_name': category.created_by.last_name
                },
                'last_updated_by': {
                    'id': user.id,
                    'email': user.email,
                    'first_name': user.first_name,
                    'last_name': user.last_name
                },
                'created_at': category.created_at.isoformat(),
                'updated_at': category.updated_at.isoformat(),
            }
            
            return {
                'success': True,
                'message': 'Category updated successfully',
                'category_data': category_data
            }
            
        except ValidationError as e:
            logger.error(f"Validation error updating category: {str(e)}")
            return {
                'success': False,
                'message': str(e),
                'error_code': 'VALIDATION_ERROR'
            }
        except Exception as e:
            logger.error(f"Error updating category {category_id}: {str(e)}")
            return {
                'success': False,
                'message': 'Failed to update category',
                'error_code': 'UPDATE_ERROR'
            }
    
    @staticmethod
    @transaction.atomic
    def delete_category(user: User, category_id: int) -> Dict[str, Any]:
        """
        Delete a category.
        
        Args:
            user: The user attempting to delete the category
            category_id: ID of the category to delete
            
        Returns:
            Dictionary with success status and message
        """
        try:
            # Validate user permissions
            validation_result = CategoryManagementService.validate_library_admin(user)
            if not validation_result.get('is_valid', False):
                return {
                    'success': False,
                    'message': validation_result.get('message', 'Permission denied'),
                    'error_code': 'PERMISSION_DENIED'
                }
            
            # Get the category
            try:
                category = Category.objects.get(id=category_id)
            except Category.DoesNotExist:
                return {
                    'success': False,
                    'message': 'Category not found',
                    'error_code': 'CATEGORY_NOT_FOUND'
                }
            
            category_name = category.name
            books_count = category.get_books_count()
            
            # Check if category has books assigned
            if books_count > 0:
                return {
                    'success': False,
                    'message': f"Cannot delete category '{category_name}' because it has {books_count} book(s) assigned to it. Please reassign or remove these books first.",
                    'error_code': 'CATEGORY_HAS_BOOKS'
                }
            
            # Delete the category
            category.delete()
            
            logger.info(f"Category '{category_name}' deleted by {user.email}")
            
            return {
                'success': True,
                'message': f"Category '{category_name}' deleted successfully."
            }
            
        except Exception as e:
            logger.error(f"Error deleting category {category_id}: {str(e)}")
            return {
                'success': False,
                'message': 'Failed to delete category',
                'error_code': 'DELETION_ERROR'
            }
    
    @staticmethod
    def get_category_stats() -> Dict[str, Any]:
        """
        Get category statistics.
        
        Returns:
            Dictionary containing category statistics
        """
        return Category.get_category_stats()


class CategoryAccessService:
    """
    Service class for handling category access and information retrieval.
    These operations can be performed by any authenticated user.
    """
    
    @staticmethod
    def get_all_categories(include_inactive: bool = False) -> Dict[str, Any]:
        """
        Get all categories.
        
        Args:
            include_inactive: Whether to include inactive categories
            
        Returns:
            Dictionary containing categories
        """
        if include_inactive:
            categories = Category.objects.all()
        else:
            categories = Category.get_active_categories()
        
        return {
            'success': True,
            'categories': categories,
            'count': categories.count()
        }
    
    @staticmethod
    def get_active_categories() -> Dict[str, Any]:
        """
        Get all active categories.
        
        Returns:
            Dictionary containing active categories
        """
        categories = Category.get_active_categories()
        
        return {
            'success': True,
            'categories': categories,
            'count': categories.count()
        }
    
    @staticmethod
    def search_categories(query: str, include_inactive: bool = False) -> Dict[str, Any]:
        """
        Search categories by name or description.
        
        Args:
            query: Search query
            include_inactive: Whether to include inactive categories
            
        Returns:
            Dictionary containing search results
        """
        from django.db.models import Q
        
        queryset = Category.objects.filter(
            Q(name__icontains=query) | Q(description__icontains=query)
        )
        
        if not include_inactive:
            queryset = queryset.filter(is_active=True)
        
        return {
            'success': True,
            'categories': queryset,
            'count': queryset.count(),
            'query': query
        }
    
    @staticmethod
    def get_category_detail(category_id: int) -> Dict[str, Any]:
        """
        Get detailed information about a specific category.
        
        Args:
            category_id: ID of the category
            
        Returns:
            Dictionary containing category details
        """
        try:
            category = Category.objects.get(id=category_id)
            return {
                'success': True,
                'category': category
            }
        except Category.DoesNotExist:
            return {
                'success': False,
                'message': 'Category not found'
            }
    
    @staticmethod
    def get_books_by_category(category_id: int, available_only: bool = False) -> Dict[str, Any]:
        """
        Get all books in a specific category.
        
        Args:
            category_id: ID of the category
            available_only: Whether to include only available books
            
        Returns:
            Dictionary containing books in the category
        """
        try:
            category = Category.objects.get(id=category_id)
            books = category.books.all()
            
            if available_only:
                books = books.filter(is_available=True)
            
            return {
                'success': True,
                'category': category,
                'books': books,
                'count': books.count()
            }
        except Category.DoesNotExist:
            return {
                'success': False,
                'message': 'Category not found'
            } 
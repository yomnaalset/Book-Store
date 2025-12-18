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

from ..models import Library, User, Book, BookImage, Category, BookEvaluation, Favorite

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
        # Stats functionality removed
        return {
            'message': 'Library statistics functionality has been removed'
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
        # Stats functionality removed
        return {
            'message': 'Book statistics functionality has been removed',
            'total_books': 0,
            'available_books': 0,
            'unavailable_books': 0,
            'total_authors': 0,
            'books_with_images': 0,
            'recent_books': [],
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
        # Stats functionality removed
        return {
            'message': 'Category statistics functionality has been removed'
        }


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


# =====================================
# EVALUATION MANAGEMENT SERVICES
# =====================================

class EvaluationManagementService:
    """
    Service class for evaluation management operations.
    Library administrators can view all evaluations.
    Customers can create, update, and delete their own evaluations.
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
    def validate_customer(user: User) -> Dict[str, Any]:
        """
        Validate that the user is a customer.
        
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
        
        if not user.is_customer():
            return {
                'is_valid': False,
                'message': 'Only customers can create evaluations'
            }
        
        return {'is_valid': True}
    
    @staticmethod
    @transaction.atomic
    def create_evaluation(user: User, evaluation_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Create a new book evaluation.
        
        Args:
            user: The customer creating the evaluation
            evaluation_data: Dictionary containing evaluation information
            
        Returns:
            Dictionary with success status and evaluation data or error message
        """
        try:
            # Validate user permissions
            validation_result = EvaluationManagementService.validate_customer(user)
            if not validation_result.get('is_valid', False):
                return {
                    'success': False,
                    'message': validation_result.get('message', 'Permission denied'),
                    'error_code': 'PERMISSION_DENIED'
                }
            
            # Get the book
            book_id = evaluation_data.get('book_id')
            try:
                book = Book.objects.get(id=book_id, is_available=True)
            except Book.DoesNotExist:
                return {
                    'success': False,
                    'message': 'Book not found or not available for evaluation',
                    'error_code': 'BOOK_NOT_FOUND'
                }
            
            # Check if user already has an evaluation for this book
            if BookEvaluation.objects.filter(book=book, user=user).exists():
                return {
                    'success': False,
                    'message': 'You have already evaluated this book. You can update your existing evaluation.',
                    'error_code': 'EVALUATION_EXISTS'
                }
            
            # Create the evaluation
            evaluation = BookEvaluation.objects.create(
                book=book,
                user=user,
                rating=evaluation_data.get('rating'),
                comment=evaluation_data.get('comment', '')
            )
            
            logger.info(f"Evaluation created for book '{book.name}' by {user.email}")
            
            # Prepare evaluation data for response
            evaluation_data = {
                'id': evaluation.id,
                'rating': evaluation.rating,
                'book': {
                    'id': book.id,
                    'name': book.name,
                    'author_name': book.author.name if book.author else None
                },
                'user': {
                    'id': user.id,
                    'email': user.email,
                    'first_name': user.first_name,
                    'last_name': user.last_name
                },
                'created_at': evaluation.created_at.isoformat(),
                'updated_at': evaluation.updated_at.isoformat()
            }
            
            return {
                'success': True,
                'message': 'Evaluation created successfully',
                'evaluation_data': evaluation_data
            }
            
        except ValidationError as e:
            logger.error(f"Validation error creating evaluation: {str(e)}")
            return {
                'success': False,
                'message': str(e),
                'error_code': 'VALIDATION_ERROR'
            }
        except Exception as e:
            logger.error(f"Error creating evaluation: {str(e)}")
            return {
                'success': False,
                'message': 'Failed to create evaluation',
                'error_code': 'CREATION_ERROR'
            }
    
    @staticmethod
    @transaction.atomic
    def update_evaluation(user: User, evaluation_id: int, update_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Update an existing evaluation.
        
        Args:
            user: The user attempting to update the evaluation
            evaluation_id: ID of the evaluation to update
            update_data: Dictionary containing updated evaluation information
            
        Returns:
            Dictionary with success status and evaluation data or error message
        """
        try:
            # Get the evaluation
            try:
                evaluation = BookEvaluation.objects.get(id=evaluation_id)
            except BookEvaluation.DoesNotExist:
                return {
                    'success': False,
                    'message': 'Evaluation not found',
                    'error_code': 'EVALUATION_NOT_FOUND'
                }
            
            # Check if user owns this evaluation
            if evaluation.user != user:
                return {
                    'success': False,
                    'message': 'You can only update your own evaluations',
                    'error_code': 'PERMISSION_DENIED'
                }
            
            # If user is customer, validate customer permissions
            if evaluation.user == user:
                validation_result = EvaluationManagementService.validate_customer(user)
                if not validation_result.get('is_valid', False):
                    return {
                        'success': False,
                        'message': validation_result.get('message', 'Permission denied'),
                        'error_code': 'PERMISSION_DENIED'
                    }
            
            # Update evaluation fields
            for field, value in update_data.items():
                if hasattr(evaluation, field) and field in ['rating', 'comment']:
                    setattr(evaluation, field, value)
            
            evaluation.save()
            
            logger.info(f"Evaluation {evaluation.id} updated by {user.email}")
            
            # Prepare evaluation data for response
            evaluation_data = {
                'id': evaluation.id,
                'rating': evaluation.rating,
                'book': {
                    'id': evaluation.book.id,
                    'name': evaluation.book.name,
                    'author_name': evaluation.book.author.name if evaluation.book.author else None
                },
                'user': {
                    'id': evaluation.user.id,
                    'email': evaluation.user.email,
                    'first_name': evaluation.user.first_name,
                    'last_name': evaluation.user.last_name
                },
                'created_at': evaluation.created_at.isoformat(),
                'updated_at': evaluation.updated_at.isoformat()
            }
            
            return {
                'success': True,
                'message': 'Evaluation updated successfully',
                'evaluation_data': evaluation_data
            }
            
        except ValidationError as e:
            logger.error(f"Validation error updating evaluation: {str(e)}")
            return {
                'success': False,
                'message': str(e),
                'error_code': 'VALIDATION_ERROR'
            }
        except Exception as e:
            logger.error(f"Error updating evaluation {evaluation_id}: {str(e)}")
            return {
                'success': False,
                'message': 'Failed to update evaluation',
                'error_code': 'UPDATE_ERROR'
            }
    
    @staticmethod
    @transaction.atomic
    def delete_evaluation(user: User, evaluation_id: int) -> Dict[str, Any]:
        """
        Delete an evaluation.
        
        Args:
            user: The user attempting to delete the evaluation
            evaluation_id: ID of the evaluation to delete
            
        Returns:
            Dictionary with success status and message
        """
        try:
            # Get the evaluation
            try:
                evaluation = BookEvaluation.objects.get(id=evaluation_id)
            except BookEvaluation.DoesNotExist:
                return {
                    'success': False,
                    'message': 'Evaluation not found',
                    'error_code': 'EVALUATION_NOT_FOUND'
                }
            
            # Check if user owns this evaluation
            if evaluation.user != user:
                return {
                    'success': False,
                    'message': 'You can only delete your own evaluations',
                    'error_code': 'PERMISSION_DENIED'
                }
            
            book_name = evaluation.book.name
            user_email = evaluation.user.email
            
            # Delete the evaluation
            evaluation.delete()
            
            logger.info(f"Evaluation for book '{book_name}' by {user_email} deleted by {user.email}")
            
            return {
                'success': True,
                'message': 'Evaluation deleted successfully'
            }
            
        except Exception as e:
            logger.error(f"Error deleting evaluation {evaluation_id}: {str(e)}")
            return {
                'success': False,
                'message': 'Failed to delete evaluation',
                'error_code': 'DELETION_ERROR'
            }
    
    @staticmethod
    def get_all_evaluations(user: User, book_id: Optional[int] = None) -> Dict[str, Any]:
        """
        Get all evaluations (for library administrators) or book-specific evaluations.
        
        Args:
            user: The user requesting evaluations
            book_id: Optional book ID to filter evaluations
            
        Returns:
            Dictionary containing evaluations
        """
        try:
            # Validate user permissions for admin access
            validation_result = EvaluationManagementService.validate_library_admin(user)
            if not validation_result.get('is_valid', False):
                return {
                    'success': False,
                    'message': validation_result.get('message', 'Permission denied'),
                    'error_code': 'PERMISSION_DENIED'
                }
            
            queryset = BookEvaluation.objects.all()
            
            if book_id:
                queryset = queryset.filter(book_id=book_id)
            
            evaluations = queryset.select_related('book', 'user', 'book__author').order_by('-created_at')
            
            return {
                'success': True,
                'evaluations': evaluations,
                'count': evaluations.count()
            }
            
        except Exception as e:
            logger.error(f"Error retrieving evaluations: {str(e)}")
            return {
                'success': False,
                'message': 'Failed to retrieve evaluations',
                'error_code': 'RETRIEVAL_ERROR'
            }
    
    @staticmethod
    def get_user_evaluations(user: User) -> Dict[str, Any]:
        """
        Get evaluations created by a specific user.
        
        Args:
            user: The user whose evaluations to retrieve
            
        Returns:
            Dictionary containing user's evaluations
        """
        try:
            # Validate user is authenticated
            if not user or not user.is_authenticated:
                return {
                    'success': False,
                    'message': 'User must be authenticated',
                    'error_code': 'AUTHENTICATION_REQUIRED'
                }
            
            evaluations = BookEvaluation.objects.filter(
                user=user
            ).select_related('book', 'book__author').order_by('-created_at')
            
            return {
                'success': True,
                'evaluations': evaluations,
                'count': evaluations.count()
            }
            
        except Exception as e:
            logger.error(f"Error retrieving user evaluations: {str(e)}")
            return {
                'success': False,
                'message': 'Failed to retrieve evaluations',
                'error_code': 'RETRIEVAL_ERROR'
            }


class EvaluationAccessService:
    """
    Service class for handling evaluation access and information retrieval.
    These operations can be performed by any authenticated user.
    """
    
    @staticmethod
    def get_book_evaluations(book_id: int) -> Dict[str, Any]:
        """
        Get all evaluations for a specific book.
        
        Args:
            book_id: ID of the book
            
        Returns:
            Dictionary containing book evaluations
        """
        try:
            # Check if book exists
            try:
                book = Book.objects.get(id=book_id)
            except Book.DoesNotExist:
                return {
                    'success': False,
                    'message': 'Book not found',
                    'error_code': 'BOOK_NOT_FOUND'
                }
            
            evaluations = BookEvaluation.objects.filter(
                book=book
            ).select_related('user').order_by('-created_at')
            
            # Calculate statistics
            total_evaluations = evaluations.count()
            average_rating = book.get_average_rating()
            
            return {
                'success': True,
                'book': {
                    'id': book.id,
                    'name': book.name,
                    'author_name': book.author.name if book.author else None
                },
                'evaluations': evaluations,
                'count': total_evaluations,
                'average_rating': average_rating,
                'statistics': {
                    'total_evaluations': total_evaluations,
                    'average_rating': average_rating,
                    'rating_distribution': EvaluationAccessService._get_rating_distribution(evaluations)
                }
            }
            
        except Exception as e:
            error_message = str(e) if e else 'Unknown error'
            logger.error(f"Error retrieving book evaluations: {error_message}", exc_info=True)
            return {
                'success': False,
                'message': f'Failed to retrieve book evaluations: {error_message}',
                'error_code': 'RETRIEVAL_ERROR'
            }
    
    @staticmethod
    def _get_rating_distribution(evaluations) -> Dict[int, int]:
        """
        Calculate rating distribution for evaluations.
        
        Args:
            evaluations: QuerySet of evaluations
            
        Returns:
            Dictionary with rating counts
        """
        distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
        for evaluation in evaluations:
            # Only count evaluations with ratings (rating can be None now)
            if evaluation.rating is not None:
                distribution[evaluation.rating] += 1        # Count the number of evaluations for each rating
        return distribution
    
    @staticmethod
    def get_evaluation_detail(evaluation_id: int, user: User) -> Dict[str, Any]:
        """
        Get detailed information about a specific evaluation.
        
        Args:
            evaluation_id: ID of the evaluation
            user: User requesting the evaluation
            
        Returns:
            Dictionary containing evaluation details
        """
        try:
            evaluation = BookEvaluation.objects.select_related(
                'book', 'user', 'book__author'
            ).get(id=evaluation_id)
            
            # Check if user can view this evaluation
            # Library admins can view all, customers can view all evaluations but only edit their own
            if not user.is_authenticated:
                return {
                    'success': False,
                    'message': 'Authentication required',
                    'error_code': 'AUTHENTICATION_REQUIRED'
                }
            
            return {
                'success': True,
                'evaluation': evaluation,
                'can_edit': evaluation.user == user or user.is_library_admin(),
                'can_delete': evaluation.user == user or user.is_library_admin()
            }
            
        except BookEvaluation.DoesNotExist:
            return {
                'success': False,
                'message': 'Evaluation not found',
                'error_code': 'EVALUATION_NOT_FOUND'
            }
        except Exception as e:
            logger.error(f"Error retrieving evaluation detail: {str(e)}")
            return {
                'success': False,
                'message': 'Failed to retrieve evaluation',
                'error_code': 'RETRIEVAL_ERROR'
            }


# =====================================
# FAVORITES SERVICES
# =====================================

class FavoriteManagementService:
    """
    Service class for managing customer favorites operations.
    Only customers can manage their own favorites.
    """
    
    @staticmethod
    def validate_customer(user: User) -> Dict[str, Any]:
        """
        Validate that the user is a customer and can manage favorites.
        """
        if not user or not user.is_authenticated:
            return {
                'success': False,
                'message': 'Authentication required',
                'error_code': 'AUTHENTICATION_REQUIRED'
            }
        
        if not user.is_active:
            return {
                'success': False,
                'message': 'Account is inactive',
                'error_code': 'ACCOUNT_INACTIVE'
            }
        
        if user.user_type != 'customer':
            return {
                'success': False,
                'message': 'Only customers can manage favorites',
                'error_code': 'INVALID_USER_TYPE'
            }
        
        return {'success': True}
    
    @staticmethod
    @transaction.atomic
    def add_to_favorites(user: User, book_id: int) -> Dict[str, Any]:
        """
        Add a book to user's favorites.
        """
        try:
            # Validate user permissions
            validation_result = FavoriteManagementService.validate_customer(user)
            if not validation_result['success']:
                return validation_result
            
            # Check if book exists
            try:
                book = Book.objects.get(id=book_id)
            except Book.DoesNotExist:
                return {
                    'success': False,
                    'message': 'Book not found',
                    'error_code': 'BOOK_NOT_FOUND'
                }
            
            # Allow favoriting unavailable books - users might want to be notified when available
            
            # Check if already favorited
            if Favorite.objects.filter(user=user, book=book).exists():
                return {
                    'success': False,
                    'message': 'Book is already in your favorites',
                    'error_code': 'ALREADY_FAVORITED'
                }
            
            # Create favorite
            favorite = Favorite.objects.create(user=user, book=book)
            
            logger.info(f"User {user.email} added book '{book.name}' to favorites")
            
            return {
                'success': True,
                'favorite': favorite,
                'message': 'Book added to favorites successfully'
            }
            
        except Exception as e:
            logger.error(f"Error adding book to favorites: {str(e)}")
            return {
                'success': False,
                'message': 'Failed to add book to favorites',
                'error_code': 'ADD_FAVORITE_ERROR'
            }
    
    @staticmethod
    @transaction.atomic
    def remove_from_favorites(user: User, favorite_id: int) -> Dict[str, Any]:
        """
        Remove a book from user's favorites.
        """
        try:
            # Validate user permissions
            validation_result = FavoriteManagementService.validate_customer(user)
            if not validation_result['success']:
                return validation_result
            
            # Get favorite and verify ownership
            try:
                favorite = Favorite.objects.get(id=favorite_id, user=user)
            except Favorite.DoesNotExist:
                return {
                    'success': False,
                    'message': 'Favorite not found or you do not have permission to remove it',
                    'error_code': 'FAVORITE_NOT_FOUND'
                }
            
            book_name = favorite.book.name
            favorite.delete()
            
            logger.info(f"User {user.email} removed book '{book_name}' from favorites")
            
            return {
                'success': True,
                'message': 'Book removed from favorites successfully'
            }
            
        except Exception as e:
            logger.error(f"Error removing book from favorites: {str(e)}")
            return {
                'success': False,
                'message': 'Failed to remove book from favorites',
                'error_code': 'REMOVE_FAVORITE_ERROR'
            }
    

    
    @staticmethod
    def get_user_favorites(user: User) -> Dict[str, Any]:
        """
        Get all favorites for a specific user.
        """
        try:
            # Validate user permissions
            validation_result = FavoriteManagementService.validate_customer(user)
            if not validation_result['success']:
                return validation_result
            
            # Get user's favorites with related book data
            favorites = Favorite.objects.filter(user=user).select_related(
                'book', 'book__author', 'book__category', 'book__library'
            ).prefetch_related('book__images').order_by('-created_at')
            
            return {
                'success': True,
                'favorites': favorites,
                'count': favorites.count()
            }
            
        except Exception as e:
            logger.error(f"Error retrieving user favorites: {str(e)}")
            return {
                'success': False,
                'message': 'Failed to retrieve favorites',
                'error_code': 'RETRIEVAL_ERROR'
            }
    



class FavoriteAccessService:
    """
    Service class for accessing favorites information.
    """
    
    @staticmethod
    def is_book_favorited(user: User, book_id: int) -> Dict[str, Any]:
        """
        Check if a book is favorited by a specific user.
        Used for heart icon state in frontend.
        """
        try:
            if not user or not user.is_authenticated:
                return {
                    'success': True,
                    'is_favorited': False,
                    'favorites_count': 0
                }
            
            is_favorited = False
            if user.user_type == 'customer':
                is_favorited = Favorite.objects.filter(user=user, book_id=book_id).exists()
            
            # Get total favorites count for this book
            favorites_count = Favorite.objects.filter(book_id=book_id).count()
            
            return {
                'success': True,
                'book_id': book_id,
                'is_favorited': is_favorited,
                'favorites_count': favorites_count
            }
            
        except Exception as e:
            logger.error(f"Error checking if book is favorited: {str(e)}")
            return {
                'success': False,
                'message': 'Failed to check favorite status',
                'error_code': 'CHECK_FAVORITE_ERROR'
            }
    
    @staticmethod
    def get_favorite_detail(user: User, favorite_id: int) -> Dict[str, Any]:
        """
        Get detailed information about a specific favorite.
        """
        try:
            # Validate user permissions
            validation_result = FavoriteManagementService.validate_customer(user)
            if not validation_result['success']:
                return validation_result
            
            # Get favorite with related data
            try:
                favorite = Favorite.objects.select_related(
                    'book', 'book__author', 'book__category', 'book__library'
                ).prefetch_related('book__images').get(id=favorite_id, user=user)
            except Favorite.DoesNotExist:
                return {
                    'success': False,
                    'message': 'Favorite not found or you do not have permission to view it',
                    'error_code': 'FAVORITE_NOT_FOUND'
                }
            
            return {
                'success': True,
                'favorite': favorite
            }
            
        except Exception as e:
            logger.error(f"Error retrieving favorite detail: {str(e)}")
            return {
                'success': False,
                'message': 'Failed to retrieve favorite',
                'error_code': 'RETRIEVAL_ERROR'
            }
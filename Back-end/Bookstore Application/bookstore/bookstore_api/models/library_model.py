from django.db import models
from django.core.exceptions import ValidationError
from django.core.validators import MinValueValidator, MaxValueValidator
from django.utils import timezone
from datetime import timedelta

from .user_model import User


class Library(models.Model):
    """
    Library model for managing a single library in the bookstore system.
    Only library administrators can create, edit, or delete the library.
    Only one library can exist at a time.
    """
    
    # Basic library information
    name = models.CharField(
        max_length=200, 
        help_text="Name of the library"
    )
    
    logo = models.ImageField(
        upload_to='library_logos/', 
        null=True, 
        blank=True,
        help_text="Library logo image"
    )
    
    details = models.TextField(
        help_text="Detailed description of the library"
    )
    
    # Metadata
    created_by = models.ForeignKey(
        User, 
        on_delete=models.PROTECT,
        related_name='created_libraries',
        limit_choices_to={'user_type': 'library_admin'},
        help_text="Library administrator who created this library"
    )
    
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="Date and time when library was created"
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="Date and time when library was last updated"
    )
    
    last_updated_by = models.ForeignKey(
        User,
        on_delete=models.PROTECT,
        related_name='updated_libraries',
        limit_choices_to={'user_type': 'library_admin'},
        help_text="Library administrator who last updated this library"
    )
    
    # Status
    is_active = models.BooleanField(
        default=True,
        help_text="Whether the library is currently active"
    )
    
    class Meta:
        db_table = 'library'
        verbose_name = 'Library'
        verbose_name_plural = 'Libraries'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['name']),
            models.Index(fields=['is_active']),
            models.Index(fields=['created_at']),
        ]
    
    def __str__(self):
        return self.name
    
    def clean(self):
        """
        Custom validation for the library.
        """
        if not self.name or not self.name.strip():
            raise ValidationError("Library name is required.")
        
        if not self.details or not self.details.strip():
            raise ValidationError("Library details are required.")
    
    def save(self, *args, **kwargs):
        """Override save to ensure only one active library exists."""
        if self.is_active:
            # Deactivate all other libraries
            Library.objects.exclude(pk=self.pk).update(is_active=False)
        super().save(*args, **kwargs)
    
    @classmethod
    def get_current_library(cls):
        """
        Get the current active library.
        Only one library can be active at a time.
        
        Returns:
            Library instance or None if no active library exists
        """
        return cls.objects.filter(is_active=True).first()
    
    @classmethod
    def can_create_library(cls):
        """
        Check if a new library can be created.
        Only one library can exist at a time.
        
        Returns:
            Boolean indicating if a new library can be created
        """
        return not cls.objects.filter(is_active=True).exists()
    
    def get_logo_url(self):
        """
        Get the URL of the library logo.
        
        Returns:
            String URL of the logo or None if no logo exists
        """
        if self.logo:
            try:
                return str(self.logo.url)
            except Exception:
                return None
        return None
    
    def has_logo(self):
        """
        Check if the library has a logo.
        
        Returns:
            Boolean indicating if the library has a logo
        """
        try:
            return bool(self.logo)
        except Exception:
            return False
    
    @classmethod
    def get_library_stats(cls):
        """
        Get statistics about the library system.
        """
        current_library = cls.objects.filter(is_active=True).first()
        
        return {
            'total_libraries': cls.objects.count(),
            'active_library': current_library,
            'can_create_new': not current_library,
        }


class Category(models.Model):
    """
    Category model for organizing books into different categories.
    Only library administrators can create, edit, or delete categories.
    Categories can be active or inactive.
    """
    
    # Basic category information
    name = models.CharField(
        max_length=100,
        unique=True,
        help_text="Name of the category"
    )
    
    description = models.TextField(
        blank=True,
        help_text="Description of the category (optional)"
    )
    
    is_active = models.BooleanField(
        default=True,
        help_text="Whether the category is active and can be used"
    )
    
    # Metadata
    created_by = models.ForeignKey(
        User, 
        on_delete=models.PROTECT,
        related_name='created_categories',
        limit_choices_to={'user_type': 'library_admin'},
        help_text="Library administrator who created this category"
    )
    
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="Date and time when category was created"
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="Date and time when category was last updated"
    )
    
    last_updated_by = models.ForeignKey(
        User,
        on_delete=models.PROTECT,
        related_name='updated_categories',
        limit_choices_to={'user_type': 'library_admin'},
        help_text="Library administrator who last updated this category"
    )
    
    class Meta:
        db_table = 'category'
        verbose_name = 'Category'
        verbose_name_plural = 'Categories'  
        ordering = ['name']
        indexes = [
            models.Index(fields=['name']),
            models.Index(fields=['is_active']),
            models.Index(fields=['created_at']),
        ]
    
    def __str__(self):
        return self.name
    
    def get_books_count(self):
        """Get the total number of books in this category."""
        return self.books.count()
    
    def get_available_books_count(self):
        """Get the number of available books in this category."""
        return self.books.filter(is_available=True).count()
    
    def get_borrowable_books_count(self):
        """Get the number of books available for borrowing in this category."""
        return self.books.filter(is_available_for_borrow=True).count()
    
    @classmethod
    def get_active_categories(cls):
        """Get all active categories."""
        return cls.objects.filter(is_active=True)
    
    @classmethod
    def get_category_stats(cls):
        """
        Get statistics about categories.
        """
        total_categories = cls.objects.count()
        active_categories = cls.objects.filter(is_active=True).count()
        inactive_categories = total_categories - active_categories
        
        return {
            'total_categories': total_categories,
            'active_categories': active_categories,
            'inactive_categories': inactive_categories,
        }


class Author(models.Model):
    """
    Author model for managing book authors in the library.
    Only library administrators can create, edit, or delete authors.
    Authors can have detailed information and photos.
    """
    
    # Basic author information
    name = models.CharField(
        max_length=200,
        unique=True,
        help_text="Full name of the author"
    )
    
    bio = models.TextField(
        help_text="Detailed biography and information about the author",
        blank=True
    )
    
    photo = models.ImageField(
        upload_to='author_photos/',
        null=True,
        blank=True,
        help_text="Author's photograph"
    )
    
    birth_date = models.DateField(
        null=True,
        blank=True,
        help_text="Author's birth date"
    )
    
    death_date = models.DateField(
        null=True,
        blank=True,
        help_text="Author's death date (if applicable)"
    )
    
    nationality = models.CharField(
        max_length=100,
        blank=True,
        help_text="Author's nationality"
    )
    
    is_active = models.BooleanField(
        default=True,
        help_text="Whether the author is active and can be assigned to books"
    )
    
    # Metadata
    created_by = models.ForeignKey(
        User, 
        on_delete=models.PROTECT,
        related_name='created_authors',
        limit_choices_to={'user_type': 'library_admin'},
        help_text="Library administrator who created this author"
    )
    
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="Date and time when author was created"
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="Date and time when author was last updated"
    )
    
    last_updated_by = models.ForeignKey(
        User,
        on_delete=models.PROTECT,
        related_name='updated_authors',
        limit_choices_to={'user_type': 'library_admin'},
        help_text="Library administrator who last updated this author"
    )
    
    class Meta:
        db_table = 'author'
        verbose_name = 'Author'
        verbose_name_plural = 'Authors'
        ordering = ['name']
        indexes = [
            models.Index(fields=['name']),
            models.Index(fields=['is_active']),
            models.Index(fields=['created_at']),
        ]
    
    def __str__(self):
        return self.name
    
    def get_books_count(self):
        """Get the total number of books by this author."""
        return self.books.count()
    
    def get_available_books_count(self):
        """Get the number of available books by this author."""
        return self.books.filter(is_available=True).count()
    
    def get_borrowable_books_count(self):
        """Get the number of books available for borrowing by this author."""
        return self.books.filter(is_available_for_borrow=True).count()
    
    @classmethod
    def get_active_authors(cls):
        """Get all active authors."""
        return cls.objects.filter(is_active=True)
    
    @classmethod
    def get_author_stats(cls):
        """
        Get statistics about authors.
        """
        total_authors = cls.objects.count()
        active_authors = cls.objects.filter(is_active=True).count()
        inactive_authors = total_authors - active_authors
        
        return {
            'total_authors': total_authors,
            'active_authors': active_authors,
            'inactive_authors': inactive_authors,
        }
    
    @classmethod
    def search_authors(cls, search_term):
        """
        Search authors by name, biography, or nationality.
        """
        from django.db.models import Q
        return cls.objects.filter(
            Q(name__icontains=search_term) |
            Q(bio__icontains=search_term) |
            Q(nationality__icontains=search_term)
        )

    def delete(self, *args, **kwargs):
        """
        Prevent deletion if author has books.
        """
        if self.books.exists():
            raise ValidationError(
                "Cannot delete author with existing books. Please remove or reassign all books first."
            )
        super().delete(*args, **kwargs)


class Book(models.Model):
    """
    Book model for managing books in the library.
    Only library administrators can create, edit, or delete books.
    Books belong to a library and can be assigned to a category.
    """
    
    # Basic book information
    name = models.CharField(
        max_length=300, 
        help_text="Name of the book"
    )
    
    description = models.TextField(
        help_text="Description of the book"
    )
    
    # Relationships
    library = models.ForeignKey(
        Library,
        on_delete=models.CASCADE,
        related_name='books',
        help_text="Library this book belongs to"
    )
    
    category = models.ForeignKey(
        Category,
        on_delete=models.PROTECT,
        related_name='books',
        help_text="Category this book belongs to"
    )
    
    author = models.ForeignKey(
        Author,
        on_delete=models.PROTECT,
        related_name='books',
        help_text="Author of the book"
    )
    
    # Pricing information
    price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        help_text="Purchase price of the book",
        null=True,
        blank=True
    )
    
    borrow_price = models.DecimalField(
        max_digits=8,
        decimal_places=2,
        default=10.00,
        help_text="Price to borrow the book"
    )
    
    # Availability and inventory
    is_available = models.BooleanField(
        default=True,
        help_text="Whether the book is available for purchase"
    )
    
    is_available_for_borrow = models.BooleanField(
        default=True,
        help_text="Whether the book is available for borrowing"
    )
    
    quantity = models.PositiveIntegerField(
        default=1,
        help_text="Total number of copies available"
    )
    
    available_copies = models.PositiveIntegerField(
        default=1,
        help_text="Number of copies currently available for borrowing"
    )
    
    borrow_count = models.PositiveIntegerField(
        default=0,
        help_text="Total number of times this book has been borrowed"
    )
    
    is_new = models.BooleanField(
        default=True,
        help_text="Whether this is a new book"
    )
    
    # Metadata
    created_by = models.ForeignKey(
        User, 
        on_delete=models.PROTECT,
        related_name='created_books',
        limit_choices_to={'user_type': 'library_admin'},
        help_text="Library administrator who created this book"
    )
    
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="Date and time when book was created"
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="Date and time when book was last updated"
    )
    
    last_updated_by = models.ForeignKey(
        User,
        on_delete=models.PROTECT,
        related_name='updated_books',
        limit_choices_to={'user_type': 'library_admin'},
        help_text="Library administrator who last updated this book"
    )
    
    class Meta:
        db_table = 'book'
        verbose_name = 'Book'
        verbose_name_plural = 'Books'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['name']),
            models.Index(fields=['author']),
            models.Index(fields=['is_available']),
            models.Index(fields=['is_available_for_borrow']),
            models.Index(fields=['is_new']),
            models.Index(fields=['created_at']),
            models.Index(fields=['price']),
            models.Index(fields=['borrow_price']),
            models.Index(fields=['category']),
            models.Index(fields=['borrow_count']),
            models.Index(fields=['available_copies']),
        ]
        unique_together = ['library', 'name', 'author']  # Prevent duplicate books in same library
    
    def __str__(self):
        return self.name
    
    def save(self, *args, **kwargs):
        """Override save to ensure data consistency"""
        # Ensure available_copies doesn't exceed quantity
        if self.available_copies > self.quantity:
            self.available_copies = self.quantity
            
        super().save(*args, **kwargs)
    
    def get_image_count(self):
        """Get the number of images for this book."""
        return self.images.count()
    
    def get_primary_image(self):
        """Get the primary image for this book."""
        return self.images.filter(is_primary=True).first()
    
    def get_primary_image_url(self):
        """Get the URL of the primary image or None if no image exists."""
        primary_image = self.get_primary_image()
        if primary_image:
            return primary_image.image.url
        return None
    
    # Borrowing-related methods
    def is_available_for_borrowing(self):
        """Check if the book is available for borrowing."""
        return (
            self.is_available_for_borrow and 
            self.available_copies > 0 and
            self.is_available
        )
    
    def can_be_borrowed(self):
        """Check if the book can be borrowed (same as is_available_for_borrowing)."""
        return self.is_available_for_borrowing()
    
    @property
    def can_borrow(self):
        """Property to check if the book can be borrowed."""
        return self.is_available_for_borrowing()
    
    @property
    def can_purchase(self):
        """Property to check if the book can be purchased."""
        return self.is_available and self.quantity > 0
    
    def get_borrowing_options(self):
        """Get borrowing options for this book."""
        return {
            'can_borrow': self.can_borrow,
            'can_purchase': self.can_purchase,
            'available_copies': self.available_copies,
            'borrow_price': float(self.borrow_price) if self.borrow_price else None,
            'purchase_price': float(self.price) if self.price else None,
        }
    
    def get_average_rating(self):
        """Get the average rating for this book."""
        from django.db.models import Avg
        avg_rating = self.evaluations.aggregate(avg_rating=Avg('rating'))['avg_rating']
        return round(avg_rating, 2) if avg_rating else 0.0
    
    def get_evaluations_count(self):
        """Get the number of evaluations for this book."""
        return self.evaluations.count()
    
    def borrow_copy(self):
        """Mark one copy as borrowed."""
        if self.available_copies > 0:
            self.available_copies -= 1
            self.borrow_count += 1
            self.save()
            return True
        return False
    
    def return_copy(self):
        """Mark one copy as returned."""
        if self.available_copies < self.quantity:
            self.available_copies += 1
            self.save()
            return True
        return False
    
    def get_availability_status(self):
        """Get a human-readable availability status."""
        if not self.is_available and not self.is_available_for_borrow:
            return "Not Available"
        elif self.available_copies == 0:
            return "Out of Stock"
        elif self.available_copies <= 3:
            return "Limited Stock"
        else:
            return "In Stock"
    
    @classmethod
    def get_available_books(cls, library=None):
        """Get all available books."""
        queryset = cls.objects.filter(is_available=True)
        if library:
            queryset = queryset.filter(library=library)
        return queryset
    
    @classmethod
    def get_borrowable_books(cls):
        """Get all books available for borrowing."""
        return cls.objects.filter(is_available_for_borrow=True, available_copies__gt=0)
    
    @classmethod
    def get_new_books(cls):
        """Get all new books."""
        return cls.objects.filter(is_new=True)
    
    def get_average_rating(self):
        """
        Get the average rating for this book.
        
        Returns:
            Float representing the average rating or 0.0 if no ratings exist
        """
        from django.db.models import Avg
        result = self.evaluations.aggregate(avg_rating=Avg('rating'))
        return result['avg_rating'] or 0.0
    
    @classmethod
    def search_books(cls, query, library=None):
        """
        Search books by name, author, description, or category.
        
        Args:
            query: Search query string
            library: Optional library to filter books
            
        Returns:
            QuerySet of matching books
        """
        from django.db.models import Q
        
        queryset = cls.objects.filter(
            Q(name__icontains=query) | 
            Q(author__name__icontains=query) |
            Q(description__icontains=query) |
            Q(category__name__icontains=query)
        )
        
        if library:
            queryset = queryset.filter(library=library)
            
        return queryset
    
    @classmethod
    def get_book_stats(cls):
        """
        Get statistics about books.
        """
        total_books = cls.objects.count()
        available_books = cls.objects.filter(is_available=True).count()
        borrowable_books = cls.objects.filter(is_available_for_borrow=True).count()
        new_books = cls.objects.filter(is_new=True).count()
        
        return {
            'total_books': total_books,
            'available_books': available_books,
            'borrowable_books': borrowable_books,
            'new_books': new_books,
        }
    
    @classmethod
    def get_books_by_category(cls, category_id, library):
        """
        Get books by specific category and library.
        """
        return cls.objects.filter(
            category_id=category_id,
            library=library,
            is_available=True
        )
    
    @classmethod
    def get_books_by_author(cls, author, library):
        """
        Get books by specific author and library.
        """
        return cls.objects.filter(
            author__name__icontains=author,
            library=library,
            is_available=True
        )


class BookImage(models.Model):
    """
    Image model for book pictures.
    Each book can have multiple images.
    """
    
    book = models.ForeignKey(
        Book,
        on_delete=models.CASCADE,
        related_name='images',
        help_text="Book this image belongs to"
    )
    
    image = models.ImageField(
        upload_to='book_images/',
        help_text="Book image"
    )
    
    is_primary = models.BooleanField(
        default=False,
        help_text="Whether this is the primary image for the book"
    )
    
    alt_text = models.CharField(
        max_length=200,
        blank=True,
        help_text="Alternative text for the image"
    )
    
    uploaded_at = models.DateTimeField(
        auto_now_add=True,
        help_text="Date and time when image was uploaded"
    )
    
    uploaded_by = models.ForeignKey(
        User,
        on_delete=models.PROTECT,
        related_name='uploaded_book_images',
        help_text="User who uploaded this image"
    )
    
    class Meta:
        db_table = 'book_image'
        verbose_name = 'Book Image'
        verbose_name_plural = 'Book Images'
        ordering = ['-is_primary', 'uploaded_at']
        indexes = [
            models.Index(fields=['book']),
            models.Index(fields=['is_primary']),
            models.Index(fields=['uploaded_at']),
        ]
    
    def __str__(self):
        return f"Image for {self.book.name}"
    
    def delete(self, *args, **kwargs):
        """Override delete to handle image file deletion."""
        # Delete the image file
        self.image.delete(save=False)
        super().delete(*args, **kwargs)
    
    def save(self, *args, **kwargs):
        """Override save to ensure only one primary image per book."""
        if self.is_primary:
            # Set all other images of this book to not primary
            BookImage.objects.filter(book=self.book, is_primary=True).exclude(pk=self.pk).update(is_primary=False)
        super().save(*args, **kwargs)


class BookEvaluation(models.Model):
    """
    Book evaluation model for storing user ratings for books.
    Customers can add, update, and delete their own evaluations.
    Library administrators can view all evaluations.
    """
    
    # Rating (1-5 stars) - Optional
    rating = models.IntegerField(
        null=True,
        blank=True,
        validators=[
            MinValueValidator(1),
            MaxValueValidator(5)
        ],
        help_text="Rating from 1 to 5 stars (optional)"
    )
    
    # Comment/Review text
    comment = models.TextField(
        blank=True,
        null=True,
        help_text="Optional comment or review text"
    )
    
    # Relationships
    book = models.ForeignKey(
        Book,
        on_delete=models.CASCADE,
        related_name='evaluations',
        help_text="Book being evaluated"
    )
    
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='book_evaluations',
        help_text="User who created the evaluation"
    )
    
    # Metadata
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="Date and time when evaluation was created"
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="Date and time when evaluation was last updated"
    )
    
    class Meta:
        db_table = 'book_evaluation'
        verbose_name = 'Book Evaluation'
        verbose_name_plural = 'Book Evaluations'
        ordering = ['-updated_at']
        indexes = [
            models.Index(fields=['book']),
            models.Index(fields=['user']),
            models.Index(fields=['rating']),
            models.Index(fields=['created_at']),
        ]
        # Ensure a user can only have one evaluation per book
        unique_together = ['book', 'user']
    
    def __str__(self):
        rating_text = f"{self.rating}-star" if self.rating else "evaluation"
        return f"{self.user.email}'s {rating_text} for '{self.book.name}'"


class Like(models.Model):
    """
    Unified model for storing likes on reviews and replies.
    Merges review_like and reply_like into a single table with target_type.
    """
    
    TARGET_TYPE_CHOICES = [
        ('review', 'Review'),
        ('reply', 'Reply'),
    ]
    
    # Target type to distinguish between review and reply likes
    target_type = models.CharField(
        max_length=10,
        choices=TARGET_TYPE_CHOICES,
        help_text="Type of target being liked (review or reply)"
    )
    
    # Relationships - one of these will be set based on target_type
    review = models.ForeignKey(
        BookEvaluation,
        on_delete=models.CASCADE,
        related_name='likes',
        null=True,
        blank=True,
        help_text="Review that was liked (for target_type='review')"
    )
    
    reply = models.ForeignKey(
        'ReviewReply',
        on_delete=models.CASCADE,
        related_name='likes',
        null=True,
        blank=True,
        help_text="Reply that was liked (for target_type='reply')"
    )
    
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='likes',
        help_text="User who liked the target"
    )
    
    # Metadata
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="Date and time when like was created"
    )
    
    class Meta:
        db_table = 'like'
        verbose_name = 'Like'
        verbose_name_plural = 'Likes'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['target_type', 'review']),
            models.Index(fields=['target_type', 'reply']),
            models.Index(fields=['user']),
            models.Index(fields=['created_at']),
        ]
        # Ensure a user can only like a target once
        # Note: MySQL doesn't support conditional unique constraints, so we enforce at application level
    
    def clean(self):
        """
        Validate that the correct target is set based on target_type.
        """
        from django.core.exceptions import ValidationError
        
        if self.target_type == 'review':
            if not self.review:
                raise ValidationError("review is required when target_type is 'review'")
            if self.reply:
                raise ValidationError("reply must be null when target_type is 'review'")
        elif self.target_type == 'reply':
            if not self.reply:
                raise ValidationError("reply is required when target_type is 'reply'")
            if self.review:
                raise ValidationError("review must be null when target_type is 'reply'")
        else:
            raise ValidationError(f"Invalid target_type: {self.target_type}")
    
    def save(self, *args, **kwargs):
        """Override save to validate before saving."""
        self.full_clean()
        super().save(*args, **kwargs)
    
    def __str__(self):
        if self.target_type == 'review' and self.review:
            return f"{self.user.email} liked {self.review.user.email}'s review"
        elif self.target_type == 'reply' and self.reply:
            return f"{self.user.email} liked {self.reply.user.email}'s reply"
        return f"{self.user.email} liked {self.target_type}"


# NOTE: These models will be removed after migration runs.
# Keeping for backward compatibility during migration.
class ReviewLike(models.Model):
    """
    DEPRECATED: This model is being merged into Like.
    Will be removed after migration.
    """
    review = models.ForeignKey(
        BookEvaluation,
        on_delete=models.CASCADE,
        related_name='legacy_likes',
        help_text="Review that was liked"
    )
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='legacy_review_likes',
        help_text="User who liked the review"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        db_table = 'review_like'
        managed = False  # Don't manage this model - it will be deleted by migration


class ReviewReply(models.Model):
    """
    Model for storing replies to book reviews.
    Users can reply to reviews.
    """
    
    # Content
    content = models.TextField(
        help_text="Reply content"
    )
    
    # Relationships
    review = models.ForeignKey(
        BookEvaluation,
        on_delete=models.CASCADE,
        related_name='replies',
        help_text="Review being replied to"
    )
    
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='review_replies',
        help_text="User who wrote the reply"
    )
    
    # Metadata
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="Date and time when reply was created"
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="Date and time when reply was last updated"
    )
    
    class Meta:
        db_table = 'review_reply'
        verbose_name = 'Review Reply'
        verbose_name_plural = 'Review Replies'
        ordering = ['created_at']
        indexes = [
            models.Index(fields=['review']),
            models.Index(fields=['user']),
            models.Index(fields=['created_at']),
        ]
    
    def __str__(self):
        return f"{self.user.email}'s reply to {self.review.user.email}'s review"


# NOTE: This model will be removed after migration runs.
# Keeping for backward compatibility during migration.
class ReplyLike(models.Model):
    """
    DEPRECATED: This model is being merged into Like.
    Will be removed after migration.
    """
    reply = models.ForeignKey(
        ReviewReply,
        on_delete=models.CASCADE,
        related_name='legacy_likes',
        help_text="Reply that was liked"
    )
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='legacy_reply_likes',
        help_text="User who liked the reply"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        db_table = 'reply_like'
        managed = False  # Don't manage this model - it will be deleted by migration


class Favorite(models.Model):
    """
    Favorite model for storing customer's favorite books.
    Only customers can add/remove books from their favorites.
    Customers can view their own favorites list.
    """
    
    # Relationships
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='favorites',
        limit_choices_to={'user_type': 'customer'},
        help_text="Customer who favorited the book"
    )
    
    book = models.ForeignKey(
        Book,
        on_delete=models.CASCADE,
        related_name='favorited_by',
        help_text="Book that was favorited"
    )
    
    # Metadata
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="Date and time when book was added to favorites"
    )
    
    class Meta:
        db_table = 'favorite'
        verbose_name = 'Favorite'
        verbose_name_plural = 'Favorites'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user']),
            models.Index(fields=['book']),
            models.Index(fields=['created_at']),
        ]
        # Ensure a user can only favorite a book once
        unique_together = ['user', 'book']
    
    def __str__(self):
        return f"{self.user.get_full_name()} ♥ {self.book.name}"
    
    def clean(self):
        """
        Validate that only customers can create favorites.
        """
        if self.user and self.user.user_type != 'customer':
            raise ValidationError(
                "Only customers can add books to favorites."
            )
    
    def save(self, *args, **kwargs):
        """Override save to run validation."""
        self.clean()
        super().save(*args, **kwargs)
    
    @classmethod
    def is_book_favorited(cls, user, book):
        """Check if a book is favorited by a specific user."""
        return cls.objects.filter(user=user, book=book).exists()
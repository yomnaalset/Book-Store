from django.db import models
from django.core.exceptions import ValidationError
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
            models.Index(fields=['is_active']),
            models.Index(fields=['created_at']),
        ]
    
    def __str__(self):
        return f"{self.name}"
    
    def clean(self):
        """
        Validate that only one active library exists at a time.
        """
        # Check if this is a new library or an existing one being updated
        if not self.pk:  # New library
            existing_library = Library.objects.filter(is_active=True).first()
            if existing_library:
                raise ValidationError(
                    "Only one active library can exist at a time. "
                    f"Please delete or deactivate the existing library '{existing_library.name}' first."
                )
        else:  # Existing library being updated
            if self.is_active:
                existing_library = Library.objects.filter(
                    is_active=True
                ).exclude(pk=self.pk).first()
                if existing_library:
                    raise ValidationError(
                        "Only one active library can exist at a time. "
                        f"Please deactivate the existing library '{existing_library.name}' first."
                    )
    
    def save(self, *args, **kwargs):
        """
        Override save to ensure validation is called.
        """
        self.clean()
        super().save(*args, **kwargs)
    
    def delete(self, *args, **kwargs):
        """
        Override delete to handle logo file deletion.
        """
        # Delete the logo file if it exists
        if self.logo:
            self.logo.delete(save=False)
        super().delete(*args, **kwargs)
    
    def get_logo_url(self):
        """
        Get the URL of the library logo.
        """
        if self.logo:
            return self.logo.url
        return None
    
    def has_logo(self):
        """
        Check if the library has a logo.
        """
        return bool(self.logo)
    
    @classmethod
    def get_current_library(cls):
        """
        Get the current active library.
        """
        return cls.objects.filter(is_active=True).first()
    
    @classmethod
    def can_create_library(cls):
        """
        Check if a new library can be created (no active library exists).
        """
        return not cls.objects.filter(is_active=True).exists()
    
    @classmethod
    def get_library_stats(cls):
        """
        Get statistics about libraries.
        """
        return {
            'total_libraries': cls.objects.count(),
            'active_libraries': cls.objects.filter(is_active=True).count(),
            'has_current_library': cls.objects.filter(is_active=True).exists(),
            'can_create_new': cls.can_create_library(),
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
        help_text="Description of the category"
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
        return f"{self.name}" + (" (Inactive)" if not self.is_active else "")
    
    def get_books_count(self):
        """Get the total number of books in this category."""
        return self.books.count()
    
    def get_available_books_count(self):
        """Get the number of available books in this category."""
        return self.books.filter(is_available=True).count()
    
    @classmethod
    def get_active_categories(cls):
        """Get all active categories."""
        return cls.objects.filter(is_active=True)
    
    @classmethod
    def get_category_stats(cls):
        """Get statistics about categories."""
        return {
            'total_categories': cls.objects.count(),
            'active_categories': cls.objects.filter(is_active=True).count(),
            'inactive_categories': cls.objects.filter(is_active=False).count(),
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
            models.Index(fields=['created_at']),
            models.Index(fields=['nationality']),
        ]
    
    def __str__(self):
        return self.name
    
    def get_books_count(self):
        """Get the total number of books by this author."""
        return self.books.count()
    
    def get_available_books_count(self):
        """Get the number of available books by this author."""
        return self.books.filter(is_available=True).count()
    
    def get_photo_url(self):
        """Get the URL of the author's photo."""
        if self.photo:
            return self.photo.url
        return None
    
    def has_photo(self):
        """Check if the author has a photo."""
        return bool(self.photo)
    
    def is_alive(self):
        """Check if the author is still alive."""
        return self.death_date is None
    
    def get_age(self):
        """Calculate author's current age or age at death."""
        if not self.birth_date:
            return None
        
        from django.utils import timezone
        from datetime import date
        
        end_date = self.death_date if self.death_date else date.today()
        age = end_date.year - self.birth_date.year
        
        # Adjust for birthday not yet occurred this year
        if end_date.month < self.birth_date.month or \
           (end_date.month == self.birth_date.month and end_date.day < self.birth_date.day):
            age -= 1
        
        return age
    
    @classmethod
    def search_authors(cls, query):
        """Search authors by name, bio, or nationality."""
        from django.db.models import Q
        return cls.objects.filter(
            Q(name__icontains=query) | 
            Q(bio__icontains=query) | 
            Q(nationality__icontains=query)
        )
    
    def delete(self, *args, **kwargs):
        """Override delete to handle photo file deletion."""
        # Delete the photo file if it exists
        if self.photo:
            self.photo.delete(save=False)
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
    
    author = models.ForeignKey(
        Author,
        on_delete=models.PROTECT,
        related_name='books',
        null=True,
        blank=True,
        help_text="Author of the book"
    )
    
    price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        help_text="Price of the book",
        null=True,
        blank=True
    )
    
    is_available = models.BooleanField(
        default=True,
        help_text="Whether the book is available for borrowing"
    )
    
    is_new = models.BooleanField(
        default=True,
        help_text="Whether the book is marked as new (automatically set to False after 30 days)"
    )
    
    # Relationships
    library = models.ForeignKey(
        Library,
        on_delete=models.CASCADE,
        related_name='books',
        help_text="Library that owns this book"
    )
    
    category = models.ForeignKey(
        Category,
        on_delete=models.SET_NULL,
        related_name='books',
        null=True,
        blank=True,
        help_text="Category this book belongs to (optional)"
    )
    
    # Metadata
    created_by = models.ForeignKey(
        'User', 
        on_delete=models.PROTECT,
        related_name='created_books',
        limit_choices_to={'user_type': 'library_admin'},
        help_text="Library administrator who added this book"
    )
    
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="Date and time when book was added"
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="Date and time when book was last updated"
    )
    
    last_updated_by = models.ForeignKey(
        'User',
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
            models.Index(fields=['is_new']),
            models.Index(fields=['created_at']),
            models.Index(fields=['price']),
            models.Index(fields=['category']),
        ]
        unique_together = ['library', 'name', 'author']  # Prevent duplicate books in same library
    
    def __str__(self):
        return f"{self.name} by {self.author}"
    
    def get_image_count(self):
        """Get the number of images for this book."""
        return self.images.count()
    
    def get_primary_image(self):
        """Get the primary (first) image for this book."""
        return self.images.filter(is_primary=True).first() or self.images.first()
    
    def get_primary_image_url(self):
        """Get the URL of the primary image."""
        primary_image = self.get_primary_image()
        return primary_image.image.url if primary_image and primary_image.image else None
    
    @classmethod
    def get_available_books(cls, library=None):
        """Get all available books in a library or all libraries."""
        queryset = cls.objects.filter(is_available=True)
        if library:
            queryset = queryset.filter(library=library)
        return queryset
    
    @classmethod
    def search_books(cls, query, library=None):
        """Search books by name or author."""
        from django.db.models import Q
        queryset = cls.objects.filter(
            Q(name__icontains=query) | Q(author__icontains=query)
        )
        if library:
            queryset = queryset.filter(library=library)
        return queryset
    
    @classmethod
    def get_new_books(cls, library=None, days=30):
        """Get books marked as new or created within specified days."""
        from django.utils import timezone
        from datetime import timedelta
        
        cutoff_date = timezone.now() - timedelta(days=days)
        queryset = cls.objects.filter(
            models.Q(is_new=True) | models.Q(created_at__gte=cutoff_date)
        )
        if library:
            queryset = queryset.filter(library=library)
        return queryset
    
    @classmethod
    def get_books_by_category(cls, category_id, library=None):
        """Get books by category."""
        queryset = cls.objects.filter(category_id=category_id)
        if library:
            queryset = queryset.filter(library=library)
        return queryset
    
    @classmethod
    def get_books_by_author(cls, author, library=None):
        """Get books by specific author."""
        queryset = cls.objects.filter(author__icontains=author)
        if library:
            queryset = queryset.filter(library=library)
        return queryset
    
    @classmethod
    def get_books_by_price_range(cls, min_price=None, max_price=None, library=None):
        """Get books within a price range."""
        queryset = cls.objects.all()
        if min_price is not None:
            queryset = queryset.filter(price__gte=min_price)
        if max_price is not None:
            queryset = queryset.filter(price__lte=max_price)
        if library:
            queryset = queryset.filter(library=library)
        return queryset
    
    def is_recently_added(self, days=30):
        """Check if book was added within the specified days."""
        from django.utils import timezone
        from datetime import timedelta
        
        cutoff_date = timezone.now() - timedelta(days=days)
        return self.created_at >= cutoff_date
    
    def mark_as_old(self):
        """Mark book as no longer new."""
        self.is_new = False
        self.save()


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
        'User',
        on_delete=models.PROTECT,
        related_name='uploaded_book_images',
        limit_choices_to={'user_type': 'library_admin'},
        help_text="Library administrator who uploaded this image"
    )
    
    class Meta:
        db_table = 'book_image'
        verbose_name = 'Book Image'
        verbose_name_plural = 'Book Images'
        ordering = ['-is_primary', 'uploaded_at']
        indexes = [
            models.Index(fields=['book', 'is_primary']),
            models.Index(fields=['uploaded_at']),
        ]
    
    def __str__(self):
        return f"Image for {self.book.name}" + (" (Primary)" if self.is_primary else "")
    
    def delete(self, *args, **kwargs):
        """Override delete to handle image file deletion."""
        # Delete the image file
        if self.image:
            self.image.delete(save=False)
        super().delete(*args, **kwargs)
    
    def save(self, *args, **kwargs):
        """Override save to handle primary image logic."""
        # If this is being set as primary, unset other primary images
        if self.is_primary:
            BookImage.objects.filter(book=self.book, is_primary=True).update(is_primary=False)
        
        # If this is the first image for the book, make it primary
        if not self.pk and not self.book.images.exists():
            self.is_primary = True
        
        super().save(*args, **kwargs) 
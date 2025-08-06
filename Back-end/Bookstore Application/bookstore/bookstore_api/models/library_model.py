from django.db import models
from django.core.exceptions import ValidationError
from django.utils.translation import gettext_lazy as _
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
        Validate that only one active library exists at a time.
        """
        # Check if a library already exists when creating a new one
        if not self.pk and Library.objects.filter(is_active=True).exists():
            existing_library = Library.objects.filter(is_active=True).first()
            raise ValidationError(
                f"Only one active library can exist at a time. "
                f"Please deactivate the existing library '{existing_library.name}' first."
            )
        
        # Check if trying to deactivate the only library
        if self.pk and not self.is_active:
            # If this is the only library, don't allow deactivation
            if Library.objects.count() == 1:
                raise ValidationError("Cannot deactivate the only library. Create a new one first.")
        
        return super().clean()
    
    def save(self, *args, **kwargs):
        """Override save to ensure only one active library exists."""
        self.full_clean()
        super().save(*args, **kwargs)
    
    def delete(self, *args, **kwargs):
        """Override delete to handle logo file deletion."""
        # Delete the logo file if it exists
        if self.logo:
            self.logo.delete(save=False)
        super().delete(*args, **kwargs)
    
    def get_logo_url(self):
        """
        Get the URL of the library logo or return None if no logo exists.
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
        Get the current active library or None if no active library exists.
        """
        return cls.objects.filter(is_active=True).first()
    
    @classmethod
    def can_create_library(cls):
        """
        Check if a new library can be created.
        """
        return not cls.objects.filter(is_active=True).exists()
    
    @classmethod
    def get_library_stats(cls):
        """
        Get library statistics.
        """
        total_libraries = cls.objects.count()
        active_libraries = cls.objects.filter(is_active=True).count()
        current_library = cls.get_current_library()
        
        return {
            'total_libraries': total_libraries,
            'active_libraries': active_libraries,
            'has_current_library': current_library is not None,
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
        return self.name
    
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
        """
        Get category statistics.
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
            models.Index(fields=['birth_date']),
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
        """Get the URL of the author's photo or return None if no photo exists."""
        if self.photo:
            return self.photo.url
        return None
    
    def has_photo(self):
        """Check if the author has a photo."""
        return bool(self.photo)
    
    def is_alive(self):
        """Check if the author is alive (no death date)."""
        return self.death_date is None
    
    def get_age(self):
        """
        Calculate the author's age.
        Returns age in years if alive, or age at death if deceased.
        Returns None if birth date is not set.
        """
        if not self.birth_date:
            return None
        
        if self.death_date:
            # Calculate age at death
            delta = self.death_date - self.birth_date
            return delta.days // 365
        else:
            # Calculate current age
            delta = timezone.now().date() - self.birth_date
            return delta.days // 365
    
    @classmethod
    def search_authors(cls, query):
        """
        Search authors by name, bio, or nationality.
        """
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
    
    title = models.CharField(
        max_length=300,
        help_text="Title of the book (same as name, for API consistency)",
        blank=True
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
            models.Index(fields=['title']),
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
        """Override save to set title field and ensure data consistency"""
        # Set title to name for API consistency
        if not self.title:
            self.title = self.name
        
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
        return self.is_available_for_borrow and self.available_copies > 0
    
    def can_purchase(self):
        """Check if the book can be purchased."""
        return self.is_available and self.price is not None
    
    def can_borrow(self):
        """Check if the book can be borrowed."""
        return self.is_available_for_borrow and self.available_copies > 0
    
    def reserve_copy(self):
        """Reserve a copy for borrowing (decrease available copies)."""
        if self.available_copies > 0:
            self.available_copies -= 1
            self.save(update_fields=['available_copies'])
            return True
        return False
    
    def release_copy(self):
        """Release a copy back to available pool (increase available copies)."""
        if self.available_copies < self.quantity:
            self.available_copies += 1
            self.save(update_fields=['available_copies'])
            return True
        return False
    
    def increment_borrow_count(self):
        """Increment the borrow count when a book is successfully delivered."""
        self.borrow_count += 1
        self.save(update_fields=['borrow_count'])
    
    def get_borrowing_options(self):
        """Get borrowing options for the book."""
        return {
            'can_borrow': self.can_borrow(),
            'can_purchase': self.can_purchase(),
            'available_copies': self.available_copies,
            'total_copies': self.quantity,
            'borrow_price': self.borrow_price,
            'purchase_price': self.price,
            'borrow_periods': [7, 14, 21, 30]  # Available borrowing periods in days
        }
    
    @classmethod
    def get_available_books(cls, library=None):
        """Get all available books, optionally filtered by library."""
        queryset = cls.objects.filter(is_available=True)
        if library:
            queryset = queryset.filter(library=library)
        return queryset
    
    @classmethod
    def search_books(cls, query, library=None):
        """
        Search books by name, description, or author name.
        """
        from django.db.models import Q
        queryset = cls.objects.filter(
            Q(name__icontains=query) | 
            Q(description__icontains=query) |
            Q(author__name__icontains=query)
        )
        
        if library:
            queryset = queryset.filter(library=library)
        
        return queryset
    
    @classmethod
    def get_new_books(cls, library=None, days=30):
        """
        Get books marked as new or created within the specified number of days.
        """
        cutoff_date = timezone.now() - timedelta(days=days)
        queryset = cls.objects.filter(
            models.Q(is_new=True) | models.Q(created_at__gte=cutoff_date)
        )
        
        if library:
            queryset = queryset.filter(library=library)
        
        return queryset
    
    @classmethod
    def get_books_by_category(cls, category_id, library=None):
        """
        Get books in a specific category.
        """
        queryset = cls.objects.filter(category_id=category_id)
        
        if library:
            queryset = queryset.filter(library=library)
        
        return queryset
    
    @classmethod
    def get_books_by_author(cls, author, library=None):
        """
        Get books by a specific author.
        """
        queryset = cls.objects.filter(author=author)
        
        if library:
            queryset = queryset.filter(library=library)
        
        return queryset
    
    @classmethod
    def get_books_by_price_range(cls, min_price=None, max_price=None, library=None):
        """
        Get books within a specific price range.
        """
        queryset = cls.objects.all()
        
        if min_price is not None:
            queryset = queryset.filter(price__gte=min_price)
        
        if max_price is not None:
            queryset = queryset.filter(price__lte=max_price)
        
        if library:
            queryset = queryset.filter(library=library)
        
        return queryset
    
    def is_recently_added(self, days=30):
        """
        Check if the book was added within the specified number of days.
        """
        cutoff_date = timezone.now() - timedelta(days=days)
        return self.created_at >= cutoff_date
    
    def mark_as_old(self):
        """
        Mark the book as no longer new.
        """
        if self.is_new:
            self.is_new = False
            self.save(update_fields=['is_new', 'updated_at'])
    
    def get_average_rating(self):
        """
        Calculate the average rating for this book.
        Returns None if there are no ratings.
        """
        evaluations = self.evaluations.all()
        if not evaluations.exists():
            return None
        
        total = sum(evaluation.rating for evaluation in evaluations)
        return round(total / evaluations.count(), 1)
    
    def get_evaluations_count(self):
        """
        Get the number of evaluations for this book.
        """
        return self.evaluations.count()


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
    
    # Rating (1-5 stars)
    rating = models.IntegerField(
        validators=[
            MinValueValidator(1),
            MaxValueValidator(5)
        ],
        help_text=_("Rating from 1 to 5 stars")
    )
    
    # Comments removed - only ratings for books
    
    # Relationships
    book = models.ForeignKey(
        Book,
        on_delete=models.CASCADE,
        related_name='evaluations',
        help_text=_("Book being evaluated")
    )
    
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='book_evaluations',
        help_text=_("User who created the evaluation")
    )
    
    # Metadata
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text=_("Date and time when evaluation was created")
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text=_("Date and time when evaluation was last updated")
    )
    
    class Meta:
        db_table = 'book_evaluation'
        verbose_name = _('Book Evaluation')
        verbose_name_plural = _('Book Evaluations')
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
        return f"{self.user.email}'s {self.rating}-star evaluation for '{self.book.name}'"


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
        help_text=_("Customer who favorited the book")
    )
    
    book = models.ForeignKey(
        Book,
        on_delete=models.CASCADE,
        related_name='favorited_by',
        help_text=_("Book that was favorited")
    )
    
    # Metadata
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text=_("Date and time when book was added to favorites")
    )
    
    class Meta:
        db_table = 'favorite'
        verbose_name = _('Favorite')
        verbose_name_plural = _('Favorites')
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
                _("Only customers can add books to favorites.")
            )
    
    def save(self, *args, **kwargs):
        """Override save to run validation."""
        self.clean()
        super().save(*args, **kwargs)
    
    @classmethod
    def is_book_favorited(cls, user, book):
        """Check if a book is favorited by a specific user."""
        return cls.objects.filter(user=user, book=book).exists()
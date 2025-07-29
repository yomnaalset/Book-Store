from rest_framework import serializers
from django.core.exceptions import ValidationError
from ..models import Library, User, Book, BookImage, Category, Author


class BookSerializer(serializers.ModelSerializer):
    """
    Basic serializer for Book model.
    Used for displaying book information in cart and order items.
    """
    
    category_name = serializers.CharField(source='category.name', read_only=True)
    author_name = serializers.CharField(source='author.name', read_only=True)
    primary_image_url = serializers.CharField(source='get_primary_image_url', read_only=True)
    
    class Meta:
        model = Book
        fields = [
            'id', 'name', 'description', 'author', 'author_name',
            'price', 'is_available', 'category', 'category_name',
            'primary_image_url'
        ]
        read_only_fields = ['id', 'author']


class LibraryCreateSerializer(serializers.ModelSerializer):
    """
    Serializer for creating a new library.
    Only library administrators can create libraries.
    """
    
    logo = serializers.ImageField(
        required=False,
        allow_null=True,
        help_text="Library logo image (optional)"
    )
    
    class Meta:
        model = Library
        fields = [
            'name', 'logo', 'details'
        ]
        extra_kwargs = {
            'name': {
                'required': True,
                'help_text': 'Name of the library'
            },
            'details': {
                'required': True,
                'help_text': 'Detailed description of the library'
            },
        }
    
    def validate(self, attrs):
        """
        Validate that no active library exists before creating a new one.
        """
        if not Library.can_create_library():
            existing_library = Library.get_current_library()
            raise serializers.ValidationError(
                f"Only one library can exist at a time. "
                f"Please delete the existing library '{existing_library.name}' first."
            )
        return attrs
    
    def create(self, validated_data):
        """
        Create a new library with the current user as creator.
        """
        # Get the current user from the context
        user = self.context['request'].user
        
        # Ensure user is a library administrator
        if not user.is_library_admin():
            raise serializers.ValidationError(
                "Only library administrators can create libraries."
            )
        
        # Create the library
        library = Library.objects.create(
            created_by=user,
            last_updated_by=user,
            **validated_data
        )
        
        return library


class LibraryUpdateSerializer(serializers.ModelSerializer):
    """
    Serializer for updating an existing library.
    Only library administrators can update libraries.
    """
    
    logo = serializers.ImageField(
        required=False,
        allow_null=True,
        help_text="Library logo image (set to null to delete current logo)"
    )
    
    class Meta:
        model = Library
        fields = [
            'name', 'logo', 'details'
        ]
        extra_kwargs = {
            'name': {'required': False},
            'details': {'required': False},
        }
    
    def update(self, instance, validated_data):
        """
        Update the library and handle logo deletion if needed.
        """
        # Get the current user from the context
        user = self.context['request'].user
        
        # Ensure user is a library administrator
        if not user.is_library_admin():
            raise serializers.ValidationError(
                "Only library administrators can update libraries."
            )
        
        # Handle logo deletion
        logo = validated_data.get('logo', 'not_provided')
        if logo == 'not_provided':
            # Logo field was not included in the request
            pass
        elif logo is None:
            # User wants to delete the current logo
            if instance.logo:
                instance.logo.delete(save=False)
            validated_data['logo'] = None
        else:
            # User is uploading a new logo
            # If there was an old logo, delete it
            if instance.logo:
                instance.logo.delete(save=False)
        
        # Update the instance
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        
        # Set the last updated by user
        instance.last_updated_by = user
        instance.save()
        
        return instance


class LibraryDetailSerializer(serializers.ModelSerializer):
    """
    Serializer for displaying library details.
    Includes additional metadata and creator information.
    """
    
    created_by_name = serializers.CharField(
        source='created_by.get_full_name', 
        read_only=True
    )
    created_by_email = serializers.EmailField(
        source='created_by.email', 
        read_only=True
    )
    last_updated_by_name = serializers.CharField(
        source='last_updated_by.get_full_name', 
        read_only=True
    )
    last_updated_by_email = serializers.EmailField(
        source='last_updated_by.email', 
        read_only=True
    )
    logo_url = serializers.CharField(
        source='get_logo_url', 
        read_only=True
    )
    has_logo = serializers.BooleanField(
        read_only=True
    )
    
    class Meta:
        model = Library
        fields = [
            'id', 'name', 'logo', 'logo_url', 'has_logo', 'details',
            'created_by', 'created_by_name', 'created_by_email',
            'last_updated_by', 'last_updated_by_name', 'last_updated_by_email',
            'created_at', 'updated_at', 'is_active'
        ]
        read_only_fields = [
            'id', 'created_by', 'created_at', 'updated_at', 
            'last_updated_by', 'is_active'
        ]


class LibraryListSerializer(serializers.ModelSerializer):
    """
    Simplified serializer for listing libraries.
    """
    
    created_by_name = serializers.CharField(
        source='created_by.get_full_name', 
        read_only=True
    )
    logo_url = serializers.CharField(
        source='get_logo_url', 
        read_only=True
    )
    has_logo = serializers.BooleanField(
        read_only=True
    )
    
    class Meta:
        model = Library
        fields = [
            'id', 'name', 'logo_url', 'has_logo', 'details',
            'created_by_name', 'created_at', 'updated_at', 'is_active'
        ]


class LibraryStatsSerializer(serializers.Serializer):
    """
    Serializer for library statistics.
    """
    
    total_libraries = serializers.IntegerField(read_only=True)
    active_libraries = serializers.IntegerField(read_only=True)
    has_current_library = serializers.BooleanField(read_only=True)
    can_create_new = serializers.BooleanField(read_only=True)
    current_library = LibraryDetailSerializer(read_only=True, allow_null=True)


# =====================================
# BOOK MANAGEMENT SERIALIZERS
# =====================================

class BookImageSerializer(serializers.ModelSerializer):
    """
    Serializer for book images.
    """
    image_url = serializers.CharField(source='image.url', read_only=True)
    uploaded_by_name = serializers.CharField(source='uploaded_by.get_full_name', read_only=True)
    
    class Meta:
        model = BookImage
        fields = [
            'id', 'image', 'image_url', 'is_primary', 'alt_text',
            'uploaded_at', 'uploaded_by', 'uploaded_by_name'
        ]
        read_only_fields = ['id', 'uploaded_at', 'uploaded_by']


class BookCreateSerializer(serializers.ModelSerializer):
    """
    Serializer for creating a new book.
    Only library administrators can create books.
    """
    
    # Handle multiple image uploads
    images = serializers.ListField(
        child=serializers.ImageField(),
        write_only=True,
        required=False,
        allow_empty=True,
        help_text="List of book images (optional, but 2+ recommended)"
    )
    
    class Meta:
        model = Book
        fields = [
            'name', 'description', 'author', 'price', 'is_available', 'is_new', 'category', 'images'
        ]
        extra_kwargs = {
            'name': {
                'required': True,
                'help_text': 'Name of the book'
            },
            'description': {
                'required': True,
                'help_text': 'Description of the book'
            },
            'author': {
                'required': True,
                'help_text': 'Author ID (must be an existing active author)'
            },
            'price': {
                'required': False,
                'help_text': 'Price of the book (optional)'
            },
            'is_available': {
                'default': True,
                'help_text': 'Whether the book is available for borrowing'
            },
            'is_new': {
                'default': True,
                'help_text': 'Whether the book is marked as new'
            },
            'category': {
                'required': False,
                'help_text': 'Category ID for the book (optional, must be active category)'
            },
        }
    
    def to_internal_value(self, data):
        """
        Override to_internal_value to handle author names as strings.
        If author is provided as a string (name), try to find the corresponding author ID.
        """
        data_copy = data.copy()
        
        # Check if author is provided as a string (not an integer)
        author_value = data_copy.get('author')
        if author_value and not isinstance(author_value, int):
            try:
                # Try to convert to int (might be a string representation of an integer)
                author_id = int(author_value)
                data_copy['author'] = author_id
            except (ValueError, TypeError):
                # If not an integer, try to find author by name
                try:
                    from ..models import Author
                    author = Author.objects.filter(name__iexact=author_value).first()
                    if author:
                        data_copy['author'] = author.id
                    else:
                        # Author not found by name
                        import logging
                        logger = logging.getLogger(__name__)
                        logger.error(f"Author not found with name: {author_value}")
                except Exception as e:
                    import logging
                    logger = logging.getLogger(__name__)
                    logger.error(f"Error looking up author: {str(e)}")
        
        return super().to_internal_value(data_copy)
    
    def validate_images(self, value):
        """Validate images - allow any number but recommend at least 2."""
        # If no images provided, that's fine
        if not value:
            return value
        
        # If only 1 image provided, that's also acceptable
        # (just log a warning, don't raise an error)
        if len(value) == 1:
            import logging
            logger = logging.getLogger(__name__)
            logger.warning("Only 1 image provided for book. 2 or more images are recommended.")
        
        return value
    
    def validate_category(self, value):
        """Validate that the category is active."""
        if value and not value.is_active:
            raise serializers.ValidationError(
                "Cannot assign book to an inactive category. Please choose an active category."
            )
        return value
    
    def validate_author(self, value):
        """Validate that the author is active."""
        if value and not value.is_active:
            raise serializers.ValidationError(
                "Cannot assign book to an inactive author. Please choose an active author."
            )
        return value
    
    def create(self, validated_data):
        """Create a new book with images."""
        # Extract images data
        images_data = validated_data.pop('images', [])
        
        # Get the current user from the context
        user = self.context['request'].user
        
        # Ensure user is a library administrator
        if not user.is_library_admin():
            raise serializers.ValidationError(
                "Only library administrators can create books."
            )
        
        # Get the current library
        from ..models import Library
        library = Library.get_current_library()
        if not library:
            raise serializers.ValidationError(
                "No active library found. Please create a library first."
            )
        
        # Create the book
        book = Book.objects.create(
            library=library,
            created_by=user,
            last_updated_by=user,
            **validated_data
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
        
        return book


class BookUpdateSerializer(serializers.ModelSerializer):
    """
    Serializer for updating an existing book.
    Only library administrators can update books.
    """
    
    # Handle new image uploads
    new_images = serializers.ListField(
        child=serializers.ImageField(),
        write_only=True,
        required=False,
        allow_empty=True,
        help_text="List of new images to add to the book"
    )
    
    # Handle image deletions
    remove_images = serializers.ListField(
        child=serializers.IntegerField(),
        write_only=True,
        required=False,
        allow_empty=True,
        help_text="List of image IDs to remove from the book"
    )
    
    class Meta:
        model = Book
        fields = [
            'name', 'description', 'author', 'price', 'is_available', 'is_new', 'category',
            'new_images', 'remove_images'
        ]
        extra_kwargs = {
            'name': {'required': False},
            'description': {'required': False},
            'author': {'required': False, 'help_text': 'Author ID (must be an existing active author)'},
            'price': {'required': False, 'help_text': 'Price of the book'},
            'is_available': {'required': False},
            'is_new': {'required': False, 'help_text': 'Whether the book is marked as new'},
            'category': {'required': False, 'help_text': 'Category ID for the book (optional, must be active category)'},
        }
    
    def to_internal_value(self, data):
        """
        Override to_internal_value to handle author names as strings.
        If author is provided as a string (name), try to find the corresponding author ID.
        """
        data_copy = data.copy()
        
        # Check if author is provided as a string (not an integer)
        author_value = data_copy.get('author')
        if author_value and not isinstance(author_value, int):
            try:
                # Try to convert to int (might be a string representation of an integer)
                author_id = int(author_value)
                data_copy['author'] = author_id
            except (ValueError, TypeError):
                # If not an integer, try to find author by name
                try:
                    from ..models import Author
                    author = Author.objects.filter(name__iexact=author_value).first()
                    if author:
                        data_copy['author'] = author.id
                    else:
                        # Author not found by name
                        import logging
                        logger = logging.getLogger(__name__)
                        logger.error(f"Author not found with name: {author_value}")
                except Exception as e:
                    import logging
                    logger = logging.getLogger(__name__)
                    logger.error(f"Error looking up author: {str(e)}")
        
        return super().to_internal_value(data_copy)
    
    def validate_category(self, value):
        """Validate that the category is active."""
        if value and not value.is_active:
            raise serializers.ValidationError(
                "Cannot assign book to an inactive category. Please choose an active category."
            )
        return value
    
    def validate_author(self, value):
        """Validate that the author is active."""
        if value and not value.is_active:
            raise serializers.ValidationError(
                "Cannot assign book to an inactive author. Please choose an active author."
            )
        return value
    
    def update(self, instance, validated_data):
        """Update the book and handle image operations."""
        # Extract image operations data
        new_images_data = validated_data.pop('new_images', [])
        remove_images_ids = validated_data.pop('remove_images', [])
        
        # Get the current user from the context
        user = self.context['request'].user
        
        # Ensure user is a library administrator
        if not user.is_library_admin():
            raise serializers.ValidationError(
                "Only library administrators can update books."
            )
        
        # Update book fields
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        
        # Set the last updated by user
        instance.last_updated_by = user
        instance.save()
        
        # Remove specified images
        if remove_images_ids:
            BookImage.objects.filter(
                book=instance,
                id__in=remove_images_ids
            ).delete()
        
        # Add new images
        existing_image_count = instance.images.count()
        for i, image_data in enumerate(new_images_data):
            BookImage.objects.create(
                book=instance,
                image=image_data,
                is_primary=(existing_image_count == 0 and i == 0),  # Make primary if no images exist
                uploaded_by=user,
                alt_text=f"New image for {instance.name}"
            )
        
        return instance


class BookDetailSerializer(serializers.ModelSerializer):
    """
    Serializer for displaying book details.
    Includes all book information and related images.
    """
    
    images = BookImageSerializer(many=True, read_only=True)
    library_name = serializers.CharField(source='library.name', read_only=True)
    category_name = serializers.CharField(source='category.name', read_only=True)
    category_id = serializers.IntegerField(source='category.id', read_only=True)
    author_name = serializers.CharField(source='author.name', read_only=True)
    author_id = serializers.IntegerField(source='author.id', read_only=True)
    created_by_name = serializers.CharField(source='created_by.get_full_name', read_only=True)
    created_by_email = serializers.EmailField(source='created_by.email', read_only=True)
    last_updated_by_name = serializers.CharField(source='last_updated_by.get_full_name', read_only=True)
    last_updated_by_email = serializers.EmailField(source='last_updated_by.email', read_only=True)
    primary_image_url = serializers.CharField(source='get_primary_image_url', read_only=True)
    image_count = serializers.IntegerField(source='get_image_count', read_only=True)
    
    class Meta:
        model = Book
        fields = [
            'id', 'name', 'description', 'author', 'author_id', 'author_name', 
            'price', 'is_available', 'is_new',
            'library', 'library_name', 'category', 'category_id', 'category_name',
            'images', 'primary_image_url', 'image_count',
            'created_by', 'created_by_name', 'created_by_email',
            'last_updated_by', 'last_updated_by_name', 'last_updated_by_email',
            'created_at', 'updated_at'
        ]
        read_only_fields = [
            'id', 'library', 'created_by', 'created_at', 'updated_at', 'last_updated_by'
        ]


class BookListSerializer(serializers.ModelSerializer):
    """
    Simplified serializer for listing books.
    """
    
    library_name = serializers.CharField(source='library.name', read_only=True)
    category_name = serializers.CharField(source='category.name', read_only=True)
    category_id = serializers.IntegerField(source='category.id', read_only=True)
    author_name = serializers.CharField(source='author.name', read_only=True)
    author_id = serializers.IntegerField(source='author.id', read_only=True)
    primary_image_url = serializers.CharField(source='get_primary_image_url', read_only=True)
    image_count = serializers.IntegerField(source='get_image_count', read_only=True)
    
    class Meta:
        model = Book
        fields = [
            'id', 'name', 'author_id', 'author_name', 'price', 'is_available', 'is_new',
            'library_name', 'category_id', 'category_name', 
            'primary_image_url', 'image_count',
            'created_at', 'updated_at'
        ]


class BookSearchSerializer(serializers.Serializer):
    """
    Serializer for book search parameters.
    """
    
    query = serializers.CharField(
        required=False,
        help_text="Search query for book name or author"
    )
    is_available = serializers.BooleanField(
        required=False,
        help_text="Filter by availability"
    )
    author = serializers.CharField(
        required=False,
        help_text="Filter by author name"
    )
    min_price = serializers.DecimalField(
        max_digits=10,
        decimal_places=2,
        required=False,
        help_text="Minimum price filter"
    )
    max_price = serializers.DecimalField(
        max_digits=10,
        decimal_places=2,
        required=False,
        help_text="Maximum price filter"
    )


class BookStatsSerializer(serializers.Serializer):
    """
    Serializer for book statistics.
    """
    
    total_books = serializers.IntegerField(read_only=True)
    available_books = serializers.IntegerField(read_only=True)
    unavailable_books = serializers.IntegerField(read_only=True)
    total_authors = serializers.IntegerField(read_only=True)
    books_with_images = serializers.IntegerField(read_only=True)
    recent_books = BookListSerializer(many=True, read_only=True) 


# =====================================
# CATEGORY MANAGEMENT SERIALIZERS
# =====================================

class CategoryCreateSerializer(serializers.ModelSerializer):
    """
    Serializer for creating a new category.
    Only library administrators can create categories.
    """
    
    class Meta:
        model = Category
        fields = ['name', 'description', 'is_active']
        extra_kwargs = {
            'name': {
                'required': True,
                'help_text': 'Name of the category (must be unique)'
            },
            'description': {
                'required': True,
                'help_text': 'Description of the category'
            },
            'is_active': {
                'default': True,
                'help_text': 'Whether the category is active'
            },
        }
    
    def validate_name(self, value):
        """Validate that category name is unique (case-insensitive)."""
        if Category.objects.filter(name__iexact=value).exists():
            raise serializers.ValidationError(
                f"A category with the name '{value}' already exists."
            )
        return value
    
    def create(self, validated_data):
        """Create a new category with the current user as creator."""
        # Get the current user from the context
        user = self.context['request'].user
        
        # Ensure user is a library administrator
        if not user.is_library_admin():
            raise serializers.ValidationError(
                "Only library administrators can create categories."
            )
        
        # Create the category
        category = Category.objects.create(
            created_by=user,
            last_updated_by=user,
            **validated_data
        )
        
        return category


class CategoryUpdateSerializer(serializers.ModelSerializer):
    """
    Serializer for updating an existing category.
    Only library administrators can update categories.
    """
    
    class Meta:
        model = Category
        fields = ['name', 'description', 'is_active']
        extra_kwargs = {
            'name': {'required': False},
            'description': {'required': False},
            'is_active': {'required': False},
        }
    
    def validate_name(self, value):
        """Validate that category name is unique (case-insensitive), excluding current instance."""
        existing_category = Category.objects.filter(name__iexact=value).exclude(pk=self.instance.pk).first()
        if existing_category:
            raise serializers.ValidationError(
                f"A category with the name '{value}' already exists."
            )
        return value
    
    def update(self, instance, validated_data):
        """Update the category."""
        # Get the current user from the context
        user = self.context['request'].user
        
        # Ensure user is a library administrator
        if not user.is_library_admin():
            raise serializers.ValidationError(
                "Only library administrators can update categories."
            )
        
        # Update the instance
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        
        # Set the last updated by user
        instance.last_updated_by = user
        instance.save()
        
        return instance


class CategoryDetailSerializer(serializers.ModelSerializer):
    """
    Serializer for displaying category details.
    Includes additional metadata and statistics.
    """
    
    created_by_name = serializers.CharField(
        source='created_by.get_full_name', 
        read_only=True
    )
    created_by_email = serializers.EmailField(
        source='created_by.email', 
        read_only=True
    )
    last_updated_by_name = serializers.CharField(
        source='last_updated_by.get_full_name', 
        read_only=True
    )
    last_updated_by_email = serializers.EmailField(
        source='last_updated_by.email', 
        read_only=True
    )
    books_count = serializers.IntegerField(
        source='get_books_count',
        read_only=True
    )
    available_books_count = serializers.IntegerField(
        source='get_available_books_count',
        read_only=True
    )
    
    class Meta:
        model = Category
        fields = [
            'id', 'name', 'description', 'is_active',
            'books_count', 'available_books_count',
            'created_by', 'created_by_name', 'created_by_email',
            'last_updated_by', 'last_updated_by_name', 'last_updated_by_email',
            'created_at', 'updated_at'
        ]
        read_only_fields = [
            'id', 'created_by', 'created_at', 'updated_at', 'last_updated_by'
        ]


class CategoryListSerializer(serializers.ModelSerializer):
    """
    Simplified serializer for listing categories.
    """
    
    books_count = serializers.IntegerField(
        source='get_books_count',
        read_only=True
    )
    available_books_count = serializers.IntegerField(
        source='get_available_books_count',
        read_only=True
    )
    created_by_name = serializers.CharField(
        source='created_by.get_full_name', 
        read_only=True
    )
    
    class Meta:
        model = Category
        fields = [
            'id', 'name', 'description', 'is_active',
            'books_count', 'available_books_count',
            'created_by_name', 'created_at', 'updated_at'
        ]


class CategoryStatsSerializer(serializers.Serializer):
    """
    Serializer for category statistics.
    """
    
    total_categories = serializers.IntegerField(read_only=True)
    active_categories = serializers.IntegerField(read_only=True)
    inactive_categories = serializers.IntegerField(read_only=True)


class CategoryChoiceSerializer(serializers.ModelSerializer):
    """
    Simple serializer for category choices in dropdowns.
    Only shows active categories.
    """
    
    class Meta:
        model = Category
        fields = ['id', 'name']


# =====================================
# AUTHOR MANAGEMENT SERIALIZERS
# =====================================

class AuthorCreateSerializer(serializers.ModelSerializer):
    """
    Serializer for creating a new author.
    Only library administrators can create authors.
    """
    
    photo = serializers.ImageField(
        required=False,
        allow_null=True,
        help_text="Author's photograph (optional)"
    )
    
    class Meta:
        model = Author
        fields = [
            'name', 'bio', 'photo', 'birth_date', 'death_date', 
            'nationality'
        ]
        extra_kwargs = {
            'name': {
                'required': True,
                'help_text': 'Full name of the author (must be unique)'
            },
            'bio': {
                'required': False,
                'help_text': 'Detailed biography and information about the author'
            },
            'birth_date': {
                'required': False,
                'help_text': 'Author\'s birth date (YYYY-MM-DD format)'
            },
            'death_date': {
                'required': False,
                'help_text': 'Author\'s death date (YYYY-MM-DD format, if applicable)'
            },
            'nationality': {
                'required': False,
                'help_text': 'Author\'s nationality'
            },
        }
    
    def validate_name(self, value):
        """Validate that author name is unique (case-insensitive)."""
        if Author.objects.filter(name__iexact=value).exists():
            raise serializers.ValidationError(
                f"An author with the name '{value}' already exists."
            )
        return value
    
    def validate(self, attrs):
        """Validate author data."""
        # Check that death_date is after birth_date
        if attrs.get('birth_date') and attrs.get('death_date'):
            if attrs['death_date'] <= attrs['birth_date']:
                raise serializers.ValidationError(
                    "Death date must be after birth date."
                )
        
        # Check that death_date is not in the future
        if attrs.get('death_date'):
            from datetime import date
            if attrs['death_date'] > date.today():
                raise serializers.ValidationError(
                    "Death date cannot be in the future."
                )
        
        return attrs
    
    def create(self, validated_data):
        """Create a new author with the current user as creator."""
        # Get the current user from the context
        user = self.context['request'].user
        
        # Ensure user is a library administrator
        if not user.is_library_admin():
            raise serializers.ValidationError(
                "Only library administrators can create authors."
            )
        
        # Create the author
        author = Author.objects.create(
            created_by=user,
            last_updated_by=user,
            **validated_data
        )
        
        return author


class AuthorUpdateSerializer(serializers.ModelSerializer):
    """
    Serializer for updating an existing author.
    Only library administrators can update authors.
    """
    
    photo = serializers.ImageField(
        required=False,
        allow_null=True,
        help_text="Author's photograph (set to null to delete current photo)"
    )
    
    class Meta:
        model = Author
        fields = [
            'name', 'bio', 'photo', 'birth_date', 'death_date', 
            'nationality'
        ]
        extra_kwargs = {
            'name': {'required': False},
            'bio': {'required': False},
            'birth_date': {'required': False},
            'death_date': {'required': False},
            'nationality': {'required': False},
        }
    
    def validate_name(self, value):
        """Validate that author name is unique (case-insensitive), excluding current instance."""
        existing_author = Author.objects.filter(name__iexact=value).exclude(pk=self.instance.pk).first()
        if existing_author:
            raise serializers.ValidationError(
                f"An author with the name '{value}' already exists."
            )
        return value
    
    def validate(self, attrs):
        """Validate author data."""
        # Get current values for comparison
        birth_date = attrs.get('birth_date', self.instance.birth_date)
        death_date = attrs.get('death_date', self.instance.death_date)
        
        # Check that death_date is after birth_date
        if birth_date and death_date:
            if death_date <= birth_date:
                raise serializers.ValidationError(
                    "Death date must be after birth date."
                )
        
        # Check that death_date is not in the future
        if death_date:
            from datetime import date
            if death_date > date.today():
                raise serializers.ValidationError(
                    "Death date cannot be in the future."
                )
        
        return attrs
    
    def update(self, instance, validated_data):
        """Update the author."""
        # Get the current user from the context
        user = self.context['request'].user
        
        # Ensure user is a library administrator
        if not user.is_library_admin():
            raise serializers.ValidationError(
                "Only library administrators can update authors."
            )
        
        # Handle photo deletion
        photo = validated_data.get('photo', 'not_provided')
        if photo == 'not_provided':
            # Photo field was not included in the request
            pass
        elif photo is None:
            # User wants to delete the current photo
            if instance.photo:
                instance.photo.delete(save=False)
            validated_data['photo'] = None
        else:
            # User is uploading a new photo
            # If there was an old photo, delete it
            if instance.photo:
                instance.photo.delete(save=False)
        
        # Update the instance
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        
        # Set the last updated by user
        instance.last_updated_by = user
        instance.save()
        
        return instance


class AuthorDetailSerializer(serializers.ModelSerializer):
    """
    Serializer for displaying author details.
    Includes additional metadata and statistics.
    """
    
    created_by_name = serializers.CharField(
        source='created_by.get_full_name', 
        read_only=True
    )
    created_by_email = serializers.EmailField(
        source='created_by.email', 
        read_only=True
    )
    last_updated_by_name = serializers.CharField(
        source='last_updated_by.get_full_name', 
        read_only=True
    )
    last_updated_by_email = serializers.EmailField(
        source='last_updated_by.email', 
        read_only=True
    )
    photo_url = serializers.CharField(
        source='get_photo_url',
        read_only=True
    )
    has_photo = serializers.BooleanField(
        read_only=True
    )
    books_count = serializers.IntegerField(
        source='get_books_count',
        read_only=True
    )
    available_books_count = serializers.IntegerField(
        source='get_available_books_count',
        read_only=True
    )
    is_alive = serializers.BooleanField(
        read_only=True
    )
    age = serializers.IntegerField(
        source='get_age',
        read_only=True
    )
    
    class Meta:
        model = Author
        fields = [
            'id', 'name', 'bio', 'photo', 'photo_url', 'has_photo',
            'birth_date', 'death_date', 'nationality',
            'books_count', 'available_books_count', 'is_alive', 'age',
            'created_by', 'created_by_name', 'created_by_email',
            'last_updated_by', 'last_updated_by_name', 'last_updated_by_email',
            'created_at', 'updated_at'
        ]
        read_only_fields = [
            'id', 'created_by', 'created_at', 'updated_at', 'last_updated_by'
        ]


class AuthorListSerializer(serializers.ModelSerializer):
    """
    Simplified serializer for listing authors.
    """
    
    photo_url = serializers.CharField(
        source='get_photo_url',
        read_only=True
    )
    has_photo = serializers.BooleanField(
        read_only=True
    )
    books_count = serializers.IntegerField(
        source='get_books_count',
        read_only=True
    )
    available_books_count = serializers.IntegerField(
        source='get_available_books_count',
        read_only=True
    )
    is_alive = serializers.BooleanField(
        
        read_only=True
    )
    age = serializers.IntegerField(
        source='get_age',
        read_only=True
    )
    created_by_name = serializers.CharField(
        source='created_by.get_full_name', 
        read_only=True
    )
    
    class Meta:
        model = Author
        fields = [
            'id', 'name', 'bio', 'photo_url', 'has_photo', 'nationality',
            'is_alive', 'age', 'books_count', 'available_books_count',
            'created_by_name', 'created_at', 'updated_at'
        ]


class AuthorStatsSerializer(serializers.Serializer):
    """
    Serializer for author statistics.
    """
    
    total_authors = serializers.IntegerField(read_only=True)
    active_authors = serializers.IntegerField(read_only=True)
    inactive_authors = serializers.IntegerField(read_only=True)
    authors_with_photos = serializers.IntegerField(read_only=True)


class AuthorChoiceSerializer(serializers.ModelSerializer):
    """
    Simple serializer for author choices in dropdowns.
    Only shows active authors.
    """
    
    class Meta:
        model = Author
        fields = ['id', 'name']


class AuthorWithBooksSerializer(serializers.ModelSerializer):
    """
    Serializer for displaying author with all their books.
    Used for author detail page with book listings.
    """
    
    photo_url = serializers.CharField(
        source='get_photo_url',
        read_only=True
    )
    has_photo = serializers.BooleanField(
        
        read_only=True
    )
    books_count = serializers.IntegerField(
        source='get_books_count',
        read_only=True
    )
    available_books_count = serializers.IntegerField(
        source='get_available_books_count',
        read_only=True
    )
    is_alive = serializers.BooleanField(
        
        read_only=True
    )
    age = serializers.IntegerField(
        source='get_age',
        read_only=True
    )
    books = serializers.SerializerMethodField()
    
    class Meta:
        model = Author
        fields = [
            'id', 'name', 'bio', 'photo_url', 'has_photo',
            'birth_date', 'death_date', 'nationality',
            'is_alive', 'age', 'books_count', 'available_books_count',
            'books', 'created_at', 'updated_at'
        ]
    
    def get_books(self, obj):
        """Get all books by this author with simplified book data."""
        books = obj.books.all().order_by('-created_at')
        return BookListSerializer(books, many=True).data 
from rest_framework import serializers
from django.core.exceptions import ValidationError
from ..models import Library, User, Book, BookImage, Category, Author, BookEvaluation, Favorite


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
            library_name = existing_library.name if existing_library else "Unknown"
            raise serializers.ValidationError(
                f"Only one library can exist at a time. "
                f"Please delete the existing library '{library_name}' first."
            )
        return attrs
    
    def create(self, validated_data):
        """
        Create a new library with the current user as creator.
        """
        try:
            # Get the current user from the context
            if 'request' not in self.context:
                raise serializers.ValidationError("Request context not available")
            
            user = self.context['request'].user
            
            if not user or not user.is_authenticated:
                raise serializers.ValidationError("User not authenticated")
            
            # Ensure user is a library administrator
            if not user.is_library_admin():
                raise serializers.ValidationError(
                    f"Only library administrators can create libraries. User type: {user.user_type}"
                )
            
            # Create the library with all validated data including logo
            library = Library.objects.create(
                created_by=user,
                last_updated_by=user,
                **validated_data
            )
            
            return library
        except Exception as e:
            # Log the error for debugging
            import logging
            logger = logging.getLogger(__name__)
            logger.error(f"Error in LibraryCreateSerializer.create: {str(e)}")
            raise serializers.ValidationError(f"Error creating library: {str(e)}")


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
        if logo == 'not_provided' or logo == 'KEEP_EXISTING':
            # Logo field was not included in the request or user wants to keep existing
            validated_data.pop('logo', None)  # Remove logo from update data
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
            'name', 'description', 'author', 'price', 'borrow_price',
            'is_available', 'is_available_for_borrow', 'is_new', 'quantity', 'available_copies',
            'category', 'images'
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
                'help_text': 'Purchase price of the book (optional)'
            },
            'borrow_price': {
                'default': 10.00,
                'help_text': 'Price to borrow the book'
            },
            'is_available': {
                'default': True,
                'help_text': 'Whether the book is available for purchase'
            },
            'is_available_for_borrow': {
                'default': True,
                'help_text': 'Whether the book is available for borrowing'
            },
            'is_new': {
                'default': True,
                'help_text': 'Whether the book is marked as new'
            },
            'quantity': {
                'default': 1,
                'help_text': 'Total number of copies available'
            },
            'available_copies': {
                'required': False,
                'help_text': 'Number of copies currently available (defaults to quantity)'
            },
            'category': {
                'required': True,
                'help_text': 'Category ID for the book (required, must be active category)'
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
    
    def validate(self, data):
        """Validate the entire book data."""
        # Set available_copies to quantity if not provided
        if 'available_copies' not in data or data['available_copies'] is None:
            data['available_copies'] = data.get('quantity', 1)
        
        # Ensure available_copies doesn't exceed quantity
        if data.get('available_copies', 0) > data.get('quantity', 1):
            raise serializers.ValidationError({
                'available_copies': 'Available copies cannot exceed total quantity'
            })
        
        # Validate category is provided and active
        category = data.get('category')
        if not category:
            raise serializers.ValidationError({
                'category': 'Category is required for creating a book.'
            })
        
        if not category.is_active:
            raise serializers.ValidationError({
                'category': 'Cannot assign book to an inactive category. Please choose an active category.'
            })
        
        # Validate author is provided and active
        author = data.get('author')
        if not author:
            raise serializers.ValidationError({
                'author': 'Author is required for creating a book.'
            })
        
        if not author.is_active:
            raise serializers.ValidationError({
                'author': 'Cannot assign book to an inactive author. Please choose an active author.'
            })
        
        # Check for duplicate book (unique constraint: library + name + author)
        from ..models import Library
        library = Library.get_current_library()
        if library:
            existing_book = Book.objects.filter(
                library=library,
                name=data.get('name'),
                author=data.get('author')
            ).first()
            
            if existing_book:
                raise serializers.ValidationError({
                    'name': f'A book with the name "{data.get("name")}" by {author.name} already exists in this library. Please choose a different name or author.'
                })
        
        return data
    
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
            'name', 'description', 'author', 'price', 'borrow_price', 'available_copies', 
            'quantity', 'is_available', 'is_available_for_borrow', 'is_new', 'category',
            'new_images', 'remove_images'
        ]
        extra_kwargs = {
            'name': {'required': False},
            'description': {'required': False},
            'author': {'required': False, 'help_text': 'Author ID (must be an existing active author)'},
            'price': {'required': False, 'help_text': 'Price of the book'},
            'borrow_price': {'required': False, 'help_text': 'Borrow price of the book'},
            'available_copies': {'required': False, 'help_text': 'Number of available copies'},
            'quantity': {'required': False, 'help_text': 'Total quantity of the book'},
            'is_available': {'required': False},
            'is_available_for_borrow': {'required': False, 'help_text': 'Whether the book is available for borrowing'},
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
    Includes all book information, related images, evaluation data, and borrowing options.
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
    average_rating = serializers.FloatField(source='get_average_rating', read_only=True)
    evaluations_count = serializers.IntegerField(source='get_evaluations_count', read_only=True)
    
    # Borrowing-related fields
    can_borrow = serializers.BooleanField(read_only=True)
    can_purchase = serializers.BooleanField(read_only=True)
    borrowing_options = serializers.DictField(source='get_borrowing_options', read_only=True)
    
    class Meta:
        model = Book
        fields = [
            'id', 'name', 'description', 'author', 'author_id', 'author_name', 
            'price', 'borrow_price', 'is_available', 'is_available_for_borrow', 'is_new',
            'quantity', 'available_copies', 'borrow_count',
            'library', 'library_name', 'category', 'category_id', 'category_name',
            'images', 'primary_image_url', 'image_count',
            'average_rating', 'evaluations_count',
            'can_borrow', 'can_purchase', 'borrowing_options',
            'created_by', 'created_by_name', 'created_by_email',
            'last_updated_by', 'last_updated_by_name', 'last_updated_by_email',
            'created_at', 'updated_at'
        ]
        read_only_fields = [
            'id', 'library', 'created_by', 'created_at', 'updated_at', 'last_updated_by',
            'borrow_count', 'can_borrow', 'can_purchase', 'borrowing_options'
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
    can_borrow = serializers.BooleanField(read_only=True)
    can_purchase = serializers.BooleanField(read_only=True)
    
    class Meta:
        model = Book
        fields = [
            'id', 'name', 'author_id', 'author_name', 
            'price', 'borrow_price', 'is_available', 'is_available_for_borrow', 'is_new',
            'quantity', 'available_copies', 'borrow_count',
            'library_name', 'category_id', 'category_name', 
            'primary_image_url', 'image_count',
            'can_borrow', 'can_purchase',
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
                'required': False,
                'help_text': 'Description of the category (optional)'
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


# =====================================
# EVALUATION SERIALIZERS
# =====================================

class EvaluationCreateSerializer(serializers.ModelSerializer):
    """
    Serializer for creating a new book evaluation.
    Only customers can create evaluations.
    """
    
    book_id = serializers.IntegerField(write_only=True, help_text="ID of the book to evaluate")
    
    class Meta:
        model = BookEvaluation
        fields = ['book_id', 'rating']
        extra_kwargs = {
            'rating': {
                'required': True,
                'help_text': 'Rating from 1 to 5 stars'
            }
        }
    
    def validate_rating(self, value):
        """Validate that rating is between 1 and 5."""
        if not (1 <= value <= 5):
            raise serializers.ValidationError("Rating must be between 1 and 5 stars.")
        return value
    
    def validate_book_id(self, value):
        """Validate that the book exists and is available."""
        try:
            book = Book.objects.get(id=value, is_available=True)
            return book.id
        except Book.DoesNotExist:
            raise serializers.ValidationError("Book not found or not available for evaluation.")
    
    def validate(self, attrs):
        """Validate that user hasn't already evaluated this book."""
        request = self.context.get('request')
        if request and request.user:
            book_id = attrs.get('book_id')
            if BookEvaluation.objects.filter(book_id=book_id, user=request.user).exists():
                raise serializers.ValidationError({
                    'book_id': 'You have already evaluated this book. You can update your existing evaluation.'
                })
        return attrs
    
    def create(self, validated_data):
        """Create evaluation with book_id converted to book instance."""
        from ..services.library_services import EvaluationManagementService
        
        # Get the user from request
        request = self.context.get('request')
        user = request.user
        
        # Use the service to create the evaluation
        result = EvaluationManagementService.create_evaluation(user, validated_data)
        
        if not result.get('success', False):
            raise serializers.ValidationError(result.get('message', 'Failed to create evaluation'))
        
        # Return the created evaluation
        return BookEvaluation.objects.get(id=result['evaluation_data']['id'])


class EvaluationUpdateSerializer(serializers.ModelSerializer):
    """
    Serializer for updating an existing book evaluation.
    Users can only update their own evaluations.
    """
    
    class Meta:
        model = BookEvaluation
        fields = ['rating']
        extra_kwargs = {
            'rating': {
                'required': False,
                'help_text': 'Rating from 1 to 5 stars'
            }
        }
    
    def validate_rating(self, value):
        """Validate that rating is between 1 and 5."""
        if value is not None and not (1 <= value <= 5):
            raise serializers.ValidationError("Rating must be between 1 and 5 stars.")
        return value
    
    def update(self, instance, validated_data):
        """Update evaluation using the service."""
        from ..services.library_services import EvaluationManagementService
        
        # Get the user from request
        request = self.context.get('request')
        user = request.user
        
        # Use the service to update the evaluation
        result = EvaluationManagementService.update_evaluation(user, instance.id, validated_data)
        
        if not result.get('success', False):
            raise serializers.ValidationError(result.get('message', 'Failed to update evaluation'))
        
        # Refresh the instance from database
        instance.refresh_from_db()
        return instance


class EvaluationDetailSerializer(serializers.ModelSerializer):
    """
    Serializer for displaying evaluation details.
    Includes book and user information.
    """
    
    book_name = serializers.CharField(source='book.name', read_only=True)
    book_id = serializers.IntegerField(source='book.id', read_only=True)
    author_name = serializers.CharField(source='book.author.name', read_only=True)
    user_name = serializers.CharField(source='user.get_full_name', read_only=True)
    user_email = serializers.EmailField(source='user.email', read_only=True)
    user_id = serializers.IntegerField(source='user.id', read_only=True)
    
    class Meta:
        model = BookEvaluation
        fields = [
            'id', 'rating',
            'book_id', 'book_name', 'author_name',
            'user_id', 'user_name', 'user_email',
            'created_at', 'updated_at'
        ]
        read_only_fields = [
            'id', 'book_id', 'book_name', 'author_name',
            'user_id', 'user_name', 'user_email',
            'created_at', 'updated_at'
        ]


class EvaluationListSerializer(serializers.ModelSerializer):
    """
    Simplified serializer for listing evaluations.
    """
    
    book_name = serializers.CharField(source='book.name', read_only=True)
    book_id = serializers.IntegerField(source='book.id', read_only=True)
    author_name = serializers.CharField(source='book.author.name', read_only=True)
    user_name = serializers.CharField(source='user.get_full_name', read_only=True)
    user_email = serializers.EmailField(source='user.email', read_only=True)
    user_id = serializers.IntegerField(source='user.id', read_only=True)
    
    class Meta:
        model = BookEvaluation
        fields = [
            'id', 'rating',
            'book_id', 'book_name', 'author_name',
            'user_id', 'user_name', 'user_email',
            'created_at', 'updated_at'
        ]


class EvaluationStatsSerializer(serializers.Serializer):
    """
    Serializer for evaluation statistics.
    """
    
    total_evaluations = serializers.IntegerField(read_only=True)
    average_rating = serializers.FloatField(read_only=True)
    rating_distribution = serializers.DictField(read_only=True)


class BookEvaluationsSerializer(serializers.Serializer):
    """
    Serializer for displaying all evaluations of a specific book.
    """
    
    book = serializers.SerializerMethodField()
    evaluations = EvaluationListSerializer(many=True, read_only=True)
    count = serializers.IntegerField(read_only=True)
    average_rating = serializers.FloatField(read_only=True, allow_null=True)
    statistics = EvaluationStatsSerializer(read_only=True)
    
    def get_book(self, obj):
        """Get book information."""
        return obj.get('book', {})


class UserEvaluationSerializer(serializers.ModelSerializer):
    """
    Serializer for displaying a user's own evaluations.
    Includes additional book information for context.
    """
    
    book_name = serializers.CharField(source='book.name', read_only=True)
    book_id = serializers.IntegerField(source='book.id', read_only=True)
    author_name = serializers.CharField(source='book.author.name', read_only=True)
    book_primary_image_url = serializers.CharField(source='book.get_primary_image_url', read_only=True)
    can_edit = serializers.SerializerMethodField()
    can_delete = serializers.SerializerMethodField()
    
    class Meta:
        model = BookEvaluation
        fields = [
            'id', 'rating',
            'book_id', 'book_name', 'author_name', 'book_primary_image_url',
            'can_edit', 'can_delete',
            'created_at', 'updated_at'
        ]
        read_only_fields = [
            'id', 'book_id', 'book_name', 'author_name', 'book_primary_image_url',
            'created_at', 'updated_at'
        ]
    
    def get_can_edit(self, obj):
        """Check if user can edit this evaluation."""
        request = self.context.get('request')
        if request and request.user:
            return obj.user == request.user or request.user.is_library_admin()
        return False
    
    def get_can_delete(self, obj):
        """Check if user can delete this evaluation."""
        request = self.context.get('request')
        if request and request.user:
            return obj.user == request.user or request.user.is_library_admin()
        return False


# =====================================
# FAVORITES SERIALIZERS
# =====================================

class FavoriteAddSerializer(serializers.ModelSerializer):
    """
    Serializer for adding a book to favorites.
    Only customers can add books to their favorites.
    """
    
    book_id = serializers.IntegerField(write_only=True, help_text="ID of the book to add to favorites")
    
    class Meta:
        model = Favorite
        fields = ['book_id']
    
    def validate_book_id(self, value):
        """Validate that the book exists and is available."""
        try:
            book = Book.objects.get(id=value)
            if not book.is_available:
                raise serializers.ValidationError("Cannot favorite an unavailable book.")
            return value
        except Book.DoesNotExist:
            raise serializers.ValidationError("Book not found.")
    
    def validate(self, attrs):
        """Validate that the user hasn't already favorited this book."""
        request = self.context.get('request')
        if not request or not request.user:
            raise serializers.ValidationError("User authentication required.")
        
        if request.user.user_type != 'customer':
            raise serializers.ValidationError("Only customers can add books to favorites.")
        
        book_id = attrs['book_id']
        if Favorite.objects.filter(user=request.user, book_id=book_id).exists():
            raise serializers.ValidationError("This book is already in your favorites.")
        
        return attrs
    
    def create(self, validated_data):
        """Create a new favorite entry."""
        request = self.context.get('request')
        book = Book.objects.get(id=validated_data['book_id'])
        return Favorite.objects.create(
            user=request.user,
            book=book
        )


class FavoriteDetailSerializer(serializers.ModelSerializer):
    """
    Serializer for displaying favorite details with book information.
    """
    
    book_id = serializers.IntegerField(source='book.id', read_only=True)
    book_name = serializers.CharField(source='book.name', read_only=True)
    book_description = serializers.CharField(source='book.description', read_only=True)
    book_price = serializers.DecimalField(source='book.price', max_digits=10, decimal_places=2, read_only=True)
    book_is_available = serializers.BooleanField(source='book.is_available', read_only=True)
    book_is_new = serializers.BooleanField(source='book.is_new', read_only=True)
    
    # Author information
    author_id = serializers.IntegerField(source='book.author.id', read_only=True)
    author_name = serializers.CharField(source='book.author.name', read_only=True)
    
    # Category information
    category_id = serializers.IntegerField(source='book.category.id', read_only=True)
    category_name = serializers.CharField(source='book.category.name', read_only=True)
    
    # Book images
    book_primary_image_url = serializers.CharField(source='book.get_primary_image_url', read_only=True)
    book_image_count = serializers.IntegerField(source='book.get_image_count', read_only=True)
    
    # Book statistics
    book_average_rating = serializers.FloatField(source='book.get_average_rating', read_only=True)
    book_evaluations_count = serializers.IntegerField(source='book.get_evaluations_count', read_only=True)
    
    # Favorite metadata
    user_id = serializers.IntegerField(source='user.id', read_only=True)
    user_name = serializers.CharField(source='user.get_full_name', read_only=True)
    
    class Meta:
        model = Favorite
        fields = [
            'id', 'created_at',
            'user_id', 'user_name',
            'book_id', 'book_name', 'book_description', 'book_price', 
            'book_is_available', 'book_is_new',
            'author_id', 'author_name',
            'category_id', 'category_name',
            'book_primary_image_url', 'book_image_count',
            'book_average_rating', 'book_evaluations_count'
        ]
        read_only_fields = [
            'id', 'created_at', 'user_id', 'user_name',
            'book_id', 'book_name', 'book_description', 'book_price',
            'book_is_available', 'book_is_new',
            'author_id', 'author_name',
            'category_id', 'category_name',
            'book_primary_image_url', 'book_image_count',
            'book_average_rating', 'book_evaluations_count'
        ]


class FavoriteListSerializer(serializers.ModelSerializer):
    """
    Simplified serializer for listing favorites.
    Shows essential book information in a list view.
    """
    
    book_id = serializers.IntegerField(source='book.id', read_only=True)
    book_name = serializers.CharField(source='book.name', read_only=True)
    book_price = serializers.DecimalField(source='book.price', max_digits=10, decimal_places=2, read_only=True)
    book_is_available = serializers.BooleanField(source='book.is_available', read_only=True)
    book_is_new = serializers.BooleanField(source='book.is_new', read_only=True)
    
    author_name = serializers.CharField(source='book.author.name', read_only=True)
    category_name = serializers.CharField(source='book.category.name', read_only=True)
    book_primary_image_url = serializers.CharField(source='book.get_primary_image_url', read_only=True)
    book_average_rating = serializers.FloatField(source='book.get_average_rating', read_only=True)
    
    class Meta:
        model = Favorite
        fields = [
            'id', 'created_at',
            'book_id', 'book_name', 'book_price', 
            'book_is_available', 'book_is_new',
            'author_name', 'category_name',
            'book_primary_image_url', 'book_average_rating'
        ]
        read_only_fields = [
            'id', 'created_at',
            'book_id', 'book_name', 'book_price',
            'book_is_available', 'book_is_new',
            'author_name', 'category_name',
            'book_primary_image_url', 'book_average_rating'
        ]



class BookIsFavoritedSerializer(serializers.Serializer):
    """
    Serializer for checking if a book is favorited by the current user.
    Used to show heart icon state in frontend.
    """
    
    book_id = serializers.IntegerField(read_only=True)
    is_favorited = serializers.BooleanField(read_only=True)
    favorites_count = serializers.IntegerField(read_only=True)  # Total users who favorited this book 
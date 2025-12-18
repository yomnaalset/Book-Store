import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../providers/library_manager/books_provider.dart';
import '../../../providers/categories_provider.dart';
import '../../../providers/library_manager/authors_provider.dart';
import '../../../models/book.dart';
import '../../../models/category.dart';
import '../../../models/author.dart';
import '../../../../auth/providers/auth_provider.dart';
import '../../../../../../core/localization/app_localizations.dart';

class BookFormScreen extends StatefulWidget {
  final Book? book;

  const BookFormScreen({super.key, this.book});

  @override
  State<BookFormScreen> createState() => _BookFormScreenState();
}

class _BookFormScreenState extends State<BookFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _borrowPriceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _totalStockController = TextEditingController();
  final _availableCopiesController = TextEditingController();
  final _imageUrlController = TextEditingController();

  Category? _selectedCategory;
  Author? _selectedAuthor;
  String? _selectedCategoryId;
  String? _selectedAuthorId;
  File? _selectedImage;
  Uint8List? _selectedImageBytes; // For web platform
  String? _selectedImageFileName; // Store filename for web platform
  bool _isAvailable = true;
  bool _isAvailableForBorrow = true;
  bool _isNew = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    if (widget.book != null) {
      _populateForm();
    }
  }

  Future<void> _loadData() async {
    final categoriesProvider = context.read<CategoriesProvider>();
    final authorsProvider = context.read<AuthorsProvider>();
    final authProvider = context.read<AuthProvider>();

    // Ensure providers have the current token
    if (authProvider.token != null) {
      categoriesProvider.setToken(authProvider.token);
      authorsProvider.setToken(authProvider.token);
      debugPrint(
        'DEBUG: Book form - Updated providers with token: ${authProvider.token!.substring(0, 20)}...',
      );
    } else {
      debugPrint('DEBUG: Book form - No token available for loading data');
    }

    await Future.wait([
      categoriesProvider.getCategories(),
      authorsProvider.loadAuthors(),
    ]);

    debugPrint(
      'DEBUG: Book form - Loaded ${categoriesProvider.categories.length} categories (${categoriesProvider.categories.where((c) => c.isActive).length} active)',
    );
    debugPrint(
      'DEBUG: Book form - Loaded ${authorsProvider.authors.length} authors (${authorsProvider.authors.where((a) => a.isActive).length} active)',
    );

    // Set selected category and author after data is loaded
    if (widget.book != null) {
      _setSelectedCategoryAndAuthor(categoriesProvider, authorsProvider);
    }

    // Check if we have active categories and authors
    final activeCategories = categoriesProvider.categories
        .where((c) => c.isActive)
        .toList();
    final activeAuthors = authorsProvider.authors
        .where((a) => a.isActive)
        .toList();

    if (activeCategories.isEmpty) {
      debugPrint('DEBUG: Book form - WARNING: No active categories available');
    }
    if (activeAuthors.isEmpty) {
      debugPrint('DEBUG: Book form - WARNING: No active authors available');
    }
  }

  void _populateForm() {
    final book = widget.book!;
    _nameController.text =
        book.title; // Using title as name since we removed title field
    _descriptionController.text = book.description ?? '';
    _priceController.text = book.price ?? '';
    _borrowPriceController.text = book.borrowPrice ?? '';
    _quantityController.text = (book.quantity ?? book.availableCopies ?? 0)
        .toString();
    _totalStockController.text = (book.quantity ?? 0).toString();
    _availableCopiesController.text = (book.availableCopies ?? 0).toString();
    _imageUrlController.text = book.primaryImageUrl ?? '';

    // Store the IDs instead of the objects to avoid object equality issues
    _selectedCategoryId = book.category?.id;
    _selectedAuthorId = book.author?.id;

    _isAvailable = book.isAvailable ?? false;
    _isAvailableForBorrow = book.isAvailableForBorrow ?? false;
    _isNew = book.isNew ?? false;
  }

  void _setSelectedCategoryAndAuthor(
    CategoriesProvider categoriesProvider,
    AuthorsProvider authorsProvider,
  ) {
    // Find the category by ID
    if (_selectedCategoryId != null) {
      final activeCategories = categoriesProvider.categories
          .where((c) => c.isActive)
          .cast<Category>()
          .toList();
      try {
        _selectedCategory = activeCategories.firstWhere(
          (c) => c.id == _selectedCategoryId,
        );
      } catch (e) {
        // If not found, use first available category or null
        _selectedCategory = activeCategories.isNotEmpty
            ? activeCategories.first
            : null;
      }
    }

    // Find the author by ID
    if (_selectedAuthorId != null) {
      final activeAuthors = authorsProvider.authors
          .where((a) => a.isActive)
          .cast<Author>()
          .toList();
      try {
        _selectedAuthor = activeAuthors.firstWhere(
          (a) => a.id == _selectedAuthorId,
        );
      } catch (e) {
        // If not found, use first available author or null
        _selectedAuthor = activeAuthors.isNotEmpty ? activeAuthors.first : null;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _borrowPriceController.dispose();
    _quantityController.dispose();
    _totalStockController.dispose();
    _availableCopiesController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      if (image != null) {
        if (kIsWeb) {
          // On web, read bytes instead of using File
          final bytes = await image.readAsBytes();
          if (mounted) {
            setState(() {
              _selectedImageBytes = bytes;
              _selectedImageFileName = image.name;
              _selectedImage = null;
            });
          }
        } else {
          // On mobile, use File
          setState(() {
            _selectedImage = File(image.path);
            _selectedImageBytes = null;
            _selectedImageFileName = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localizations.error}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveBook() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate category and author selection
    final localizations = AppLocalizations.of(context);
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.pleaseSelectCategory),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedAuthor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.pleaseSelectAuthor),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<BooksProvider>();
      final authProvider = context.read<AuthProvider>();
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      // Ensure provider has the current token
      if (authProvider.token != null) {
        provider.setToken(authProvider.token);
        debugPrint(
          'DEBUG: Book form - Updated provider with token: ${authProvider.token!.substring(0, 20)}...',
        );
      } else {
        debugPrint('DEBUG: Book form - No token available from AuthProvider');
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(localizations.authenticationRequiredPleaseLogIn),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      debugPrint(
        'DEBUG: Book form - Selected author: ${_selectedAuthor?.id}, Selected category: ${_selectedCategory?.id}',
      );

      final bookData = Book(
        id: widget.book?.id ?? '',
        title: _nameController.text.trim(), // Using name as title
        description: _descriptionController.text.trim(),
        author: _selectedAuthor,
        category: _selectedCategory,
        // Only set primaryImageUrl if no image file is selected (use URL input instead)
        primaryImageUrl: (_selectedImage == null && _selectedImageBytes == null)
            ? (_imageUrlController.text.trim().isEmpty
                  ? null
                  : _imageUrlController.text.trim())
            : null, // Don't set path when uploading file
        price: _priceController.text.trim(), // Now mandatory, no null check
        borrowPrice: _isAvailableForBorrow
            ? _borrowPriceController.text.trim()
            : '0',
        isActive: true,
        createdAt: widget.book?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        availableCopies: int.parse(_availableCopiesController.text.trim()),
        averageRating: widget.book?.averageRating,
        evaluationsCount: widget.book?.evaluationsCount,
        images: widget.book?.images,
        isAvailable: _isAvailable,
        isAvailableForBorrow: _isAvailableForBorrow,
        quantity: int.parse(_totalStockController.text.trim()),
        borrowCount: widget.book?.borrowCount ?? 0,
        isNew: _isNew,
      );

      if (widget.book == null) {
        debugPrint(
          'DEBUG: Book form - Creating book with data: ${bookData.toJson()}',
        );
        final createdBook = await provider.createBook(
          bookData,
          imageFile: _selectedImage,
          imageBytes: _selectedImageBytes,
          imageFileName: _selectedImageFileName,
        );
        if (mounted) {
          if (createdBook != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(localizations.bookCreatedSuccessfully)),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  localizations.failedToCreateBook(
                    provider.error ?? localizations.unknownError,
                  ),
                ),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        }
      } else {
        // Ensure provider has the current token for update
        if (authProvider.token != null) {
          provider.setToken(authProvider.token);
          debugPrint(
            'DEBUG: Book form - Updated provider with token for update: ${authProvider.token!.substring(0, 20)}...',
          );
        }

        final updatedBook = await provider.updateBook(
          bookData,
          imageFile: _selectedImage,
          imageBytes: _selectedImageBytes,
          imageFileName: _selectedImageFileName,
        );
        if (mounted) {
          if (updatedBook != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(localizations.bookUpdatedSuccessfully)),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  localizations.failedToUpdateBook(
                    provider.error ?? localizations.unknownError,
                  ),
                ),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        }
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('DEBUG: Book form - Error during save operation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localizations.error}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.book == null ? localizations.addBook : localizations.editBook,
        ),
        actions: [
          if (widget.book != null)
            IconButton(
              onPressed: _isLoading ? null : () => _deleteBook(),
              icon: const Icon(Icons.delete),
              color: Colors.red,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Information
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Builder(
                              builder: (context) {
                                final localizations = AppLocalizations.of(
                                  context,
                                );
                                return Row(
                                  children: [
                                    const Icon(
                                      Icons.book,
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      localizations.bookInformation,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 24),

                            // Name Field
                            Builder(
                              builder: (context) {
                                final localizations = AppLocalizations.of(
                                  context,
                                );
                                return TextFormField(
                                  controller: _nameController,
                                  decoration: InputDecoration(
                                    labelText: '${localizations.bookName} *',
                                    border: const OutlineInputBorder(),
                                    hintText: localizations.enterBookName,
                                    prefixIcon: const Icon(Icons.book),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return localizations.bookNameRequired;
                                    }
                                    return null;
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 16),

                            // Description Field
                            Builder(
                              builder: (context) {
                                final localizations = AppLocalizations.of(
                                  context,
                                );
                                return TextFormField(
                                  controller: _descriptionController,
                                  decoration: InputDecoration(
                                    labelText: '${localizations.description} *',
                                    border: const OutlineInputBorder(),
                                    hintText:
                                        localizations.enterBookDescription,
                                    prefixIcon: const Icon(Icons.description),
                                    alignLabelWithHint: true,
                                  ),
                                  maxLines: 4,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return localizations.descriptionRequired;
                                    }
                                    return null;
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 16),

                            // Book Picture Section
                            Builder(
                              builder: (context) {
                                final localizations = AppLocalizations.of(
                                  context,
                                );
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      localizations.bookPicture,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // Image Selection Buttons
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () =>
                                                _pickImage(ImageSource.gallery),
                                            icon: const Icon(
                                              Icons.photo_library,
                                            ),
                                            label: Text(localizations.gallery),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () =>
                                                _pickImage(ImageSource.camera),
                                            icon: const Icon(Icons.camera_alt),
                                            label: Text(localizations.camera),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // Image URL Field
                                    TextFormField(
                                      controller: _imageUrlController,
                                      decoration: InputDecoration(
                                        labelText:
                                            localizations.orEnterImageUrl,
                                        border: const OutlineInputBorder(),
                                        hintText: localizations.enterImageUrl,
                                        prefixIcon: const Icon(Icons.link),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 12),

                            // Selected Image Preview
                            if (_selectedImage != null ||
                                _selectedImageBytes != null)
                              Container(
                                height: 200,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: kIsWeb && _selectedImageBytes != null
                                      ? Image.memory(
                                          _selectedImageBytes!,
                                          fit: BoxFit.cover,
                                        )
                                      : _selectedImage != null
                                      ? Image.file(
                                          _selectedImage!,
                                          fit: BoxFit.cover,
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Category and Author Selection
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Builder(
                              builder: (context) {
                                final localizations = AppLocalizations.of(
                                  context,
                                );
                                return Row(
                                  children: [
                                    const Icon(
                                      Icons.category,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      localizations.classification,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 24),

                            // Category Selection
                            Consumer<CategoriesProvider>(
                              builder: (context, provider, child) {
                                final localizations = AppLocalizations.of(
                                  context,
                                );
                                return DropdownButtonFormField<Category>(
                                  // ignore: deprecated_member_use
                                  value: _selectedCategory,
                                  decoration: InputDecoration(
                                    labelText: '${localizations.category} *',
                                    border: const OutlineInputBorder(),
                                    prefixIcon: const Icon(Icons.category),
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: null,
                                      child: Text(localizations.selectCategory),
                                    ),
                                    ...provider.categories
                                        .where((category) => category.isActive)
                                        .map((category) {
                                          return DropdownMenuItem(
                                            value: category as Category?,
                                            child: Text(category.name),
                                          );
                                        }),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedCategory = value;
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null) {
                                      return localizations.pleaseSelectCategory;
                                    }
                                    return null;
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 16),

                            // Author Selection
                            Consumer<AuthorsProvider>(
                              builder: (context, provider, child) {
                                final localizations = AppLocalizations.of(
                                  context,
                                );
                                return DropdownButtonFormField<Author>(
                                  // ignore: deprecated_member_use
                                  value: _selectedAuthor,
                                  decoration: InputDecoration(
                                    labelText: '${localizations.author} *',
                                    border: const OutlineInputBorder(),
                                    prefixIcon: const Icon(Icons.person),
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: null,
                                      child: Text(
                                        localizations.selectAuthorLabel,
                                      ),
                                    ),
                                    ...provider.authors
                                        .where((author) => author.isActive)
                                        .map((author) {
                                          return DropdownMenuItem(
                                            value: author as Author?,
                                            child: Text(author.name),
                                          );
                                        }),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedAuthor = value;
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null) {
                                      return localizations.pleaseSelectAuthor;
                                    }
                                    return null;
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Pricing and Availability
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Builder(
                              builder: (context) {
                                final localizations = AppLocalizations.of(
                                  context,
                                );
                                return Row(
                                  children: [
                                    const Icon(
                                      Icons.attach_money,
                                      color: Colors.blue,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      localizations.pricingAvailability,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 24),

                            // Price Field
                            Builder(
                              builder: (context) {
                                final localizations = AppLocalizations.of(
                                  context,
                                );
                                return TextFormField(
                                  controller: _priceController,
                                  decoration: InputDecoration(
                                    labelText:
                                        '${localizations.purchasePrice} *',
                                    border: const OutlineInputBorder(),
                                    hintText: localizations.enterPurchasePrice,
                                    prefixIcon: const Icon(Icons.attach_money),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return localizations
                                          .purchasePriceRequired;
                                    }
                                    if (double.tryParse(value) == null) {
                                      return localizations
                                          .pleaseEnterValidPrice;
                                    }
                                    return null;
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 16),

                            // Borrow Price Field
                            Builder(
                              builder: (context) {
                                final localizations = AppLocalizations.of(
                                  context,
                                );
                                return TextFormField(
                                  controller: _borrowPriceController,
                                  decoration: InputDecoration(
                                    labelText: _isAvailableForBorrow
                                        ? '${localizations.borrowPrice} *'
                                        : localizations.borrowPrice,
                                    border: const OutlineInputBorder(),
                                    hintText: localizations.enterBorrowPrice,
                                    prefixIcon: const Icon(Icons.money),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (_isAvailableForBorrow) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return localizations
                                            .borrowPriceRequired;
                                      }
                                      if (double.tryParse(value) == null) {
                                        return localizations
                                            .pleaseEnterValidPrice;
                                      }
                                    }
                                    return null;
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 16),

                            // Total Stock Field
                            Builder(
                              builder: (context) {
                                final localizations = AppLocalizations.of(
                                  context,
                                );
                                return TextFormField(
                                  controller: _totalStockController,
                                  decoration: InputDecoration(
                                    labelText: '${localizations.totalStock} *',
                                    border: const OutlineInputBorder(),
                                    hintText:
                                        localizations.enterTotalNumberBooks,
                                    prefixIcon: const Icon(Icons.inventory_2),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return localizations.totalStockRequired;
                                    }
                                    if (int.tryParse(value) == null ||
                                        int.parse(value) <= 0) {
                                      return localizations
                                          .pleaseEnterValidStockQuantity;
                                    }
                                    return null;
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 16),

                            // Available Copies Field
                            Builder(
                              builder: (context) {
                                final localizations = AppLocalizations.of(
                                  context,
                                );
                                return TextFormField(
                                  controller: _availableCopiesController,
                                  decoration: InputDecoration(
                                    labelText:
                                        '${localizations.availableCopiesLabel} *',
                                    border: const OutlineInputBorder(),
                                    hintText: localizations
                                        .enterNumberAvailableCopies,
                                    prefixIcon: const Icon(Icons.check_circle),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return localizations
                                          .availableCopiesRequired;
                                    }
                                    if (int.tryParse(value) == null ||
                                        int.parse(value) <= 0) {
                                      return localizations
                                          .pleaseEnterValidQuantity;
                                    }
                                    return null;
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 16),

                            // Quantity Field (for borrowing)
                            Builder(
                              builder: (context) {
                                final localizations = AppLocalizations.of(
                                  context,
                                );
                                return TextFormField(
                                  controller: _quantityController,
                                  decoration: InputDecoration(
                                    labelText: _isAvailableForBorrow
                                        ? '${localizations.numberOfBooksForBorrowing} *'
                                        : localizations
                                              .numberOfBooksForBorrowing,
                                    border: const OutlineInputBorder(),
                                    hintText:
                                        localizations.enterNumberBooksBorrowing,
                                    prefixIcon: const Icon(Icons.inventory),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (_isAvailableForBorrow) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return localizations.quantityRequired;
                                      }
                                      if (int.tryParse(value) == null ||
                                          int.parse(value) <= 0) {
                                        return localizations
                                            .pleaseEnterValidQuantity;
                                      }
                                    }
                                    return null;
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 16),

                            // Availability Switches
                            Builder(
                              builder: (context) {
                                final localizations = AppLocalizations.of(
                                  context,
                                );
                                return Column(
                                  children: [
                                    SwitchListTile(
                                      title: Text(
                                        localizations.availableForPurchase,
                                      ),
                                      subtitle: Text(
                                        localizations.bookCanBePurchased,
                                      ),
                                      value: _isAvailable,
                                      onChanged: (value) {
                                        setState(() {
                                          _isAvailable = value;
                                        });
                                      },
                                    ),
                                    SwitchListTile(
                                      title: Text(
                                        localizations.availableForBorrowing,
                                      ),
                                      subtitle: Text(
                                        localizations.bookCanBeBorrowed,
                                      ),
                                      value: _isAvailableForBorrow,
                                      onChanged: (value) {
                                        setState(() {
                                          _isAvailableForBorrow = value;
                                          // Clear borrow fields when borrowing is disabled
                                          if (!value) {
                                            _borrowPriceController.clear();
                                            _quantityController.clear();
                                          }
                                        });
                                      },
                                    ),
                                    SwitchListTile(
                                      title: Text(localizations.newBook),
                                      subtitle: Text(
                                        localizations.markAsNewArrival,
                                      ),
                                      value: _isNew,
                                      onChanged: (value) {
                                        setState(() {
                                          _isNew = value;
                                        });
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveBook,
                            child: _isLoading
                                ? const CircularProgressIndicator()
                                : Text(
                                    widget.book == null
                                        ? localizations.addBook
                                        : localizations.updateBook,
                                  ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _deleteBook() async {
    final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.deleteBook),
        content: Text(
          localizations.areYouSureDeleteBookWithTitle(widget.book!.title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(localizations.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        if (!mounted) return;
        final provider = context.read<BooksProvider>();
        final authProvider = context.read<AuthProvider>();

        // Ensure provider has the current token for delete
        if (authProvider.token != null) {
          provider.setToken(authProvider.token);
          debugPrint(
            'DEBUG: Book form - Updated provider with token for delete: ${authProvider.token!.substring(0, 20)}...',
          );
        } else {
          debugPrint(
            'DEBUG: Book form - No token available for delete operation',
          );
          if (mounted) {
            final localizations = AppLocalizations.of(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(localizations.authenticationRequiredPleaseLogIn),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        final success = await provider.deleteBook(int.parse(widget.book!.id));

        if (mounted) {
          final localizations = AppLocalizations.of(context);
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(localizations.bookDeletedSuccessfully)),
            );
            Navigator.pop(context);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  localizations.failedToDeleteBook(
                    provider.error ?? localizations.unknownError,
                  ),
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('DEBUG: Book form - Error during delete operation: $e');
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${localizations.error}: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }
}

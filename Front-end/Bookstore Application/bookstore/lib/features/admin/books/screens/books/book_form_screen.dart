import 'package:flutter/material.dart';
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
      _selectedCategory = categoriesProvider.categories
          .where((c) => c.isActive)
          .cast<Category>()
          .firstWhere(
            (c) => c.id == _selectedCategoryId,
            orElse: () => categoriesProvider.categories
                .where((c) => c.isActive)
                .cast<Category>()
                .first,
          );
    }

    // Find the author by ID
    if (_selectedAuthorId != null) {
      _selectedAuthor = authorsProvider.authors
          .where((a) => a.isActive)
          .cast<Author>()
          .firstWhere(
            (a) => a.id == _selectedAuthorId,
            orElse: () => authorsProvider.authors
                .where((a) => a.isActive)
                .cast<Author>()
                .first,
          );
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
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveBook() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate category and author selection
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a category'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedAuthor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an author'),
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
          const SnackBar(
            content: Text('Authentication required. Please log in again.'),
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
        primaryImageUrl: _selectedImage != null
            ? _selectedImage!.path
            : (_imageUrlController.text.trim().isEmpty
                  ? null
                  : _imageUrlController.text.trim()),
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
        final createdBook = await provider.createBook(bookData);
        if (mounted) {
          if (createdBook != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Book created successfully')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to create book: ${provider.error ?? 'Unknown error'}',
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

        final updatedBook = await provider.updateBook(bookData);
        if (mounted) {
          if (updatedBook != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Book updated successfully')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to update book: ${provider.error ?? 'Unknown error'}',
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
            content: Text('Error: ${e.toString()}'),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book == null ? 'Add Book' : 'Edit Book'),
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
                            const Row(
                              children: [
                                Icon(Icons.book, color: Colors.orange),
                                SizedBox(width: 12),
                                Text(
                                  'Book Information',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Name Field
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Book Name *',
                                border: OutlineInputBorder(),
                                hintText: 'Enter book name',
                                prefixIcon: Icon(Icons.book),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Book name is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Description Field
                            TextFormField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Description *',
                                border: OutlineInputBorder(),
                                hintText: 'Enter book description',
                                prefixIcon: Icon(Icons.description),
                                alignLabelWithHint: true,
                              ),
                              maxLines: 4,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Description is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Book Picture Section
                            const Text(
                              'Book Picture',
                              style: TextStyle(
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
                                    icon: const Icon(Icons.photo_library),
                                    label: const Text('Gallery'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _pickImage(ImageSource.camera),
                                    icon: const Icon(Icons.camera_alt),
                                    label: const Text('Camera'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Image URL Field
                            TextFormField(
                              controller: _imageUrlController,
                              decoration: const InputDecoration(
                                labelText: 'Or enter image URL',
                                border: OutlineInputBorder(),
                                hintText: 'Enter image URL',
                                prefixIcon: Icon(Icons.link),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Selected Image Preview
                            if (_selectedImage != null)
                              Container(
                                height: 200,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    _selectedImage!,
                                    fit: BoxFit.cover,
                                  ),
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
                            const Row(
                              children: [
                                Icon(Icons.category, color: Colors.green),
                                SizedBox(width: 12),
                                Text(
                                  'Classification',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Category Selection
                            Consumer<CategoriesProvider>(
                              builder: (context, provider, child) {
                                return DropdownButtonFormField<Category>(
                                  // ignore: deprecated_member_use
                                  value: _selectedCategory,
                                  decoration: const InputDecoration(
                                    labelText: 'Category *',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.category),
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text('Select Category'),
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
                                      return 'Please select a category';
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
                                return DropdownButtonFormField<Author>(
                                  // ignore: deprecated_member_use
                                  value: _selectedAuthor,
                                  decoration: const InputDecoration(
                                    labelText: 'Author *',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.person),
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text('Select Author'),
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
                                      return 'Please select an author';
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
                            const Row(
                              children: [
                                Icon(Icons.attach_money, color: Colors.blue),
                                SizedBox(width: 12),
                                Text(
                                  'Pricing & Availability',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Price Field
                            TextFormField(
                              controller: _priceController,
                              decoration: const InputDecoration(
                                labelText: 'Purchase Price *',
                                border: OutlineInputBorder(),
                                hintText: 'Enter purchase price',
                                prefixIcon: Icon(Icons.attach_money),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Purchase price is required';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'Please enter a valid price';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Borrow Price Field
                            TextFormField(
                              controller: _borrowPriceController,
                              decoration: InputDecoration(
                                labelText: _isAvailableForBorrow
                                    ? 'Borrow Price *'
                                    : 'Borrow Price',
                                border: const OutlineInputBorder(),
                                hintText: 'Enter borrow price',
                                prefixIcon: const Icon(Icons.money),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (_isAvailableForBorrow) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Borrow price is required';
                                  }
                                  if (double.tryParse(value) == null) {
                                    return 'Please enter a valid price';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Total Stock Field
                            TextFormField(
                              controller: _totalStockController,
                              decoration: const InputDecoration(
                                labelText: 'Total Stock *',
                                border: OutlineInputBorder(),
                                hintText:
                                    'Enter total number of books in stock',
                                prefixIcon: Icon(Icons.inventory_2),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Total stock is required';
                                }
                                if (int.tryParse(value) == null ||
                                    int.parse(value) <= 0) {
                                  return 'Please enter a valid stock quantity';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Available Copies Field
                            TextFormField(
                              controller: _availableCopiesController,
                              decoration: const InputDecoration(
                                labelText: 'Available Copies *',
                                border: OutlineInputBorder(),
                                hintText: 'Enter number of available copies',
                                prefixIcon: Icon(Icons.check_circle),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Available copies is required';
                                }
                                if (int.tryParse(value) == null ||
                                    int.parse(value) <= 0) {
                                  return 'Please enter a valid quantity';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Quantity Field (for borrowing)
                            TextFormField(
                              controller: _quantityController,
                              decoration: InputDecoration(
                                labelText: _isAvailableForBorrow
                                    ? 'Number of Books for Borrowing *'
                                    : 'Number of Books for Borrowing',
                                border: const OutlineInputBorder(),
                                hintText:
                                    'Enter number of books available for borrowing',
                                prefixIcon: const Icon(Icons.inventory),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (_isAvailableForBorrow) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Quantity is required';
                                  }
                                  if (int.tryParse(value) == null ||
                                      int.parse(value) <= 0) {
                                    return 'Please enter a valid quantity';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Availability Switches
                            SwitchListTile(
                              title: const Text('Available for Purchase'),
                              subtitle: const Text('Book can be purchased'),
                              value: _isAvailable,
                              onChanged: (value) {
                                setState(() {
                                  _isAvailable = value;
                                });
                              },
                            ),
                            SwitchListTile(
                              title: const Text('Available for Borrowing'),
                              subtitle: const Text('Book can be borrowed'),
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
                              title: const Text('New Book'),
                              subtitle: const Text('Mark as new arrival'),
                              value: _isNew,
                              onChanged: (value) {
                                setState(() {
                                  _isNew = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveBook,
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : Text(
                                widget.book == null
                                    ? 'Add Book'
                                    : 'Update Book',
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _deleteBook() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Book'),
        content: Text(
          'Are you sure you want to delete "${widget.book!.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Authentication required. Please log in again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        final success = await provider.deleteBook(int.parse(widget.book!.id));

        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Book deleted successfully')),
            );
            Navigator.pop(context);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to delete book: ${provider.error ?? 'Unknown error'}',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('DEBUG: Book form - Error during delete operation: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
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

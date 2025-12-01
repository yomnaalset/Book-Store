import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/common/custom_button.dart';
import '../../../core/widgets/common/custom_text_field.dart';
import '../../../core/widgets/common/loading_indicator.dart';
import '../../books/providers/books_provider.dart';
import '../../books/models/book.dart';
import '../../books/screens/book_detail_screen.dart';

class BookManagementScreen extends StatefulWidget {
  const BookManagementScreen({super.key});

  @override
  State<BookManagementScreen> createState() => _BookManagementScreenState();
}

class _BookManagementScreenState extends State<BookManagementScreen> {
  final _searchController = TextEditingController();
  String _selectedFilter = 'all';
  String _selectedSortBy = 'title';
  List<Book> _filteredBooks = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Management'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddBookDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            color: AppColors.background,
            child: Column(
              children: [
                // Search Field
                CustomTextField(
                  controller: _searchController,
                  label: 'Search Books',
                  hint: 'Search by title, author, or ISBN',
                  prefixIcon: const Icon(Icons.search),
                  onChanged: _filterBooks,
                ),
                const SizedBox(height: AppDimensions.spacingM),

                // Filter and Sort Row
                Row(
                  children: [
                    // Filter Dropdown
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.paddingM,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedFilter,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(
                                value: 'all',
                                child: Text('All Books'),
                              ),
                              DropdownMenuItem(
                                value: 'available',
                                child: Text('Available'),
                              ),
                              DropdownMenuItem(
                                value: 'borrow_only',
                                child: Text('Borrow Only'),
                              ),
                              DropdownMenuItem(
                                value: 'purchase_only',
                                child: Text('Purchase Only'),
                              ),
                              DropdownMenuItem(
                                value: 'out_of_stock',
                                child: Text('Out of Stock'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedFilter = value!;
                              });
                              _filterBooks(_searchController.text);
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingM),

                    // Sort Dropdown
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.paddingM,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedSortBy,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(
                                value: 'title',
                                child: Text('Title A-Z'),
                              ),
                              DropdownMenuItem(
                                value: 'author',
                                child: Text('Author A-Z'),
                              ),
                              DropdownMenuItem(
                                value: 'price',
                                child: Text('Price'),
                              ),
                              DropdownMenuItem(
                                value: 'rating',
                                child: Text('Rating'),
                              ),
                              DropdownMenuItem(
                                value: 'newest',
                                child: Text('Newest'),
                              ),
                              DropdownMenuItem(
                                value: 'most_borrowed',
                                child: Text('Most Borrowed'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedSortBy = value!;
                              });
                              _filterBooks(_searchController.text);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Books List
          Expanded(
            child: _isLoading
                ? const Center(child: LoadingIndicator())
                : _filteredBooks.isEmpty
                ? _buildEmptyState()
                : _buildBooksList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddBookDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.book_outlined, size: 64, color: AppColors.textHint),
          const SizedBox(height: AppDimensions.spacingL),
          const Text(
            'No books found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingS),
          const Text(
            'Try adjusting your search or add new books',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimensions.spacingL),
          CustomButton(text: 'Add New Book', onPressed: _showAddBookDialog),
        ],
      ),
    );
  }

  Widget _buildBooksList() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      itemCount: _filteredBooks.length,
      itemBuilder: (context, index) {
        final book = _filteredBooks[index];
        return Card(
          margin: const EdgeInsets.only(bottom: AppDimensions.spacingM),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                book.primaryImageUrl ?? '',
                width: 60,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 60,
                    height: 80,
                    color: AppColors.background,
                    child: const Icon(Icons.book, color: AppColors.textHint),
                  );
                },
              ),
            ),
            title: Text(
              book.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (book.author != null) Text('By ${book.author!.name}'),
                Row(
                  children: [
                    Text('Price: \$${book.priceAsDouble.toStringAsFixed(2)}'),
                    const SizedBox(width: AppDimensions.spacingM),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getAvailabilityColor(book),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getAvailabilityText(book),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _handleBookAction(value, book),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'view',
                  child: Row(
                    children: [
                      Icon(Icons.visibility, size: 16),
                      SizedBox(width: 8),
                      Text('View Details'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 16),
                      SizedBox(width: 8),
                      Text('Edit Book'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'duplicate',
                  child: Row(
                    children: [
                      Icon(Icons.copy, size: 16),
                      SizedBox(width: 8),
                      Text('Duplicate'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 16, color: AppColors.error),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookDetailScreen(book: book),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Color _getAvailabilityColor(Book book) {
    if (book.stock == null || book.stock! <= 0) {
      return AppColors.error;
    } else if (book.isAvailableForBorrow == true && book.isAvailable == true) {
      return AppColors.success;
    } else if (book.isAvailableForBorrow == true) {
      return AppColors.warning;
    } else {
      return AppColors.primary;
    }
  }

  String _getAvailabilityText(Book book) {
    if (book.stock == null || book.stock! <= 0) {
      return 'Out of Stock';
    } else if (book.isAvailableForBorrow == true && book.isAvailable == true) {
      return 'Available';
    } else if (book.isAvailableForBorrow == true) {
      return 'Borrow Only';
    } else {
      return 'Purchase Only';
    }
  }

  void _handleBookAction(String action, Book book) {
    switch (action) {
      case 'view':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => BookDetailScreen(book: book)),
        );
        break;
      case 'edit':
        _showEditBookDialog(book);
        break;
      case 'duplicate':
        _showDuplicateBookDialog(book);
        break;
      case 'delete':
        _showDeleteBookDialog(book);
        break;
    }
  }

  void _showAddBookDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Book'),
        content: const Text('Book creation form will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Add book feature coming soon!'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditBookDialog(Book book) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Book'),
        content: Text(
          'Edit form for "${book.title}" will be implemented here.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Edit book feature coming soon!'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDuplicateBookDialog(Book book) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duplicate Book'),
        content: Text('Create a copy of "${book.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Duplicate book feature coming soon!'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
            child: const Text('Duplicate'),
          ),
        ],
      ),
    );
  }

  void _showDeleteBookDialog(Book book) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Book'),
        content: Text(
          'Are you sure you want to delete "${book.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Delete book feature coming soon!'),
                  backgroundColor: AppColors.error,
                ),
              );
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadBooks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final booksProvider = Provider.of<BooksProvider>(context, listen: false);
      await booksProvider.getBooks();

      setState(() {
        _filteredBooks = booksProvider.books;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load books: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _filterBooks(String query) {
    final booksProvider = Provider.of<BooksProvider>(context, listen: false);
    List<Book> books = booksProvider.books;

    // Apply search filter
    if (query.isNotEmpty) {
      books = books.where((book) {
        final title = book.title.toLowerCase();
        final author = book.author?.name.toLowerCase() ?? '';
        final searchQuery = query.toLowerCase();
        return title.contains(searchQuery) || author.contains(searchQuery);
      }).toList();
    }

    // Apply availability filter
    if (_selectedFilter != 'all') {
      books = books.where((book) {
        switch (_selectedFilter) {
          case 'available':
            return book.isAvailable == true &&
                book.isAvailableForBorrow == true;
          case 'borrow_only':
            return book.isAvailableForBorrow == true &&
                book.isAvailable != true;
          case 'purchase_only':
            return book.isAvailable == true &&
                book.isAvailableForBorrow != true;
          case 'out_of_stock':
            return book.stock == null || book.stock! <= 0;
          default:
            return true;
        }
      }).toList();
    }

    // Apply sorting
    books.sort((a, b) {
      switch (_selectedSortBy) {
        case 'title':
          return a.title.compareTo(b.title);
        case 'author':
          return (a.author?.name ?? '').compareTo(b.author?.name ?? '');
        case 'price':
          return a.priceAsDouble.compareTo(b.priceAsDouble);
        case 'rating':
          return (b.averageRating ?? 0).compareTo(a.averageRating ?? 0);
        case 'newest':
          return (b.createdAt ?? DateTime.now()).compareTo(
            a.createdAt ?? DateTime.now(),
          );
        case 'most_borrowed':
          return (b.borrowCount ?? 0).compareTo(a.borrowCount ?? 0);
        default:
          return 0;
      }
    });

    setState(() {
      _filteredBooks = books;
    });
  }
}

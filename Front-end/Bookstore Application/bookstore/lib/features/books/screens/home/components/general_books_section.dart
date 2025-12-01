import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../cart/providers/cart_provider.dart';
import '../../../providers/books_provider.dart';
import '../../../models/book.dart';
import '../../../widgets/book_price_display.dart';

class GeneralBooksSection extends StatefulWidget {
  const GeneralBooksSection({super.key});

  @override
  State<GeneralBooksSection> createState() => _GeneralBooksSectionState();
}

class _GeneralBooksSectionState extends State<GeneralBooksSection> {
  bool _isLoading = true;
  List<Book> _books = [];
  String _sortBy = 'all'; // all, newest, rating

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    await _loadBooksBySort(_sortBy);
  }

  Future<void> _loadBooksBySort(String sortBy) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final booksProvider = Provider.of<BooksProvider>(context, listen: false);
      List<Book> books = [];

      switch (sortBy) {
        case 'all':
          books = await booksProvider.getMostPopularBooks(limit: 10);
          break;
        case 'newest':
          books = await booksProvider.getNewBooks(limit: 10);
          break;
        case 'rating':
          books = await booksProvider.getTopRatedBooks(limit: 10);
          break;
        default:
          books = await booksProvider.getMostPopularBooks(limit: 10);
      }

      if (mounted) {
        setState(() {
          // Show ALL books in the library (both available for purchase and borrowing)
          _books = books
              .where(
                (book) =>
                    book.isAvailable == true ||
                    book.isAvailableForBorrow == true,
              )
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading general books: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_books.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.uranianBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.book,
                        color: AppColors.uranianBlue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _getSectionTitle(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  initialValue: _sortBy,
                  onSelected: (value) async {
                    setState(() {
                      _sortBy = value;
                      _isLoading = true;
                    });
                    await _loadBooksBySort(value);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'all',
                      child: Row(
                        children: [
                          Icon(Icons.book, size: 18),
                          SizedBox(width: 8),
                          Text('All'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'newest',
                      child: Row(
                        children: [
                          Icon(Icons.access_time, size: 18),
                          SizedBox(width: 8),
                          Text('New Books'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'rating',
                      child: Row(
                        children: [
                          Icon(Icons.star, size: 18),
                          SizedBox(width: 8),
                          Text('Highest Rated'),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.uranianBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.uranianBlue.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getSortLabel(),
                          style: const TextStyle(
                            color: AppColors.uranianBlue,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.arrow_drop_down,
                          color: AppColors.uranianBlue,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Empty state
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.book_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _getEmptyStateTitle(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getEmptyStateMessage(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.uranianBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.book,
                      color: AppColors.uranianBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _getSectionTitle(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              PopupMenuButton<String>(
                initialValue: _sortBy,
                onSelected: (value) async {
                  setState(() {
                    _sortBy = value;
                    _isLoading = true;
                  });
                  await _loadBooksBySort(value);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'all',
                    child: Row(
                      children: [
                        Icon(Icons.book, size: 18),
                        SizedBox(width: 8),
                        Text('All'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'newest',
                    child: Row(
                      children: [
                        Icon(Icons.access_time, size: 18),
                        SizedBox(width: 8),
                        Text('New Books'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'rating',
                    child: Row(
                      children: [
                        Icon(Icons.star, size: 18),
                        SizedBox(width: 8),
                        Text('Highest Rated'),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.uranianBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.uranianBlue.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getSortLabel(),
                        style: const TextStyle(
                          color: AppColors.uranianBlue,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: AppColors.uranianBlue,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Books List
          SizedBox(
            height: 240,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _books.length,
              itemBuilder: (context, index) {
                final book = _books[index];
                return _buildBookCard(book);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookCard(Book book) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/book-detail', arguments: {'book': book});
      },
      child: Container(
        width: 170,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book Cover with Discount Badge
            Expanded(
              flex: 2,
              child: SizedBox(
                width: double.infinity,
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.uranianBlue.withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: book.primaryImageUrl != null
                          ? ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                              child: Image.network(
                                book.primaryImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(
                                      Icons.book,
                                      size: 40,
                                      color: AppColors.uranianBlue,
                                    ),
                                  );
                                },
                              ),
                            )
                          : const Center(
                              child: Icon(
                                Icons.book,
                                size: 40,
                                color: AppColors.uranianBlue,
                              ),
                            ),
                    ),
                    // Discount Badge
                    if (book.hasDiscount)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${book.savingsPercentage.toInt()}% OFF',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Book Details
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      book.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      book.author?.name ?? 'Unknown Author',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Column(
                      children: [
                        // Price display
                        BookPriceDisplay(
                          book: book,
                          showBorrowPrice: true,
                          isCompact: true,
                          fontSize: 9,
                          smallFontSize: 8,
                        ),
                        const SizedBox(height: 4),
                        // Action Buttons Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            if (book.isAvailable == true)
                              GestureDetector(
                                onTap: () => _addToCart(book),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: AppColors.uranianBlue.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(
                                    Icons.add_shopping_cart,
                                    size: 14,
                                    color: AppColors.uranianBlue,
                                  ),
                                ),
                              ),
                            if (book.isAvailableForBorrow == true)
                              GestureDetector(
                                onTap: () => _requestBorrow(book),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(
                                    Icons.library_add,
                                    size: 14,
                                    color: AppColors.success,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSectionTitle() {
    switch (_sortBy) {
      case 'newest':
        return 'All Books';
      case 'rating':
        return 'All Books';
      default:
        return 'All Books';
    }
  }

  String _getSortLabel() {
    switch (_sortBy) {
      case 'all':
        return 'All';
      case 'newest':
        return 'New Books';
      case 'rating':
        return 'Highest Rated';
      default:
        return 'All';
    }
  }

  String _getEmptyStateTitle() {
    switch (_sortBy) {
      case 'all':
        return 'No books available';
      case 'newest':
        return 'No books available';
      case 'rating':
        return 'No books available';
      default:
        return 'No books available';
    }
  }

  String _getEmptyStateMessage() {
    switch (_sortBy) {
      case 'all':
        return 'No books found in the library';
      case 'newest':
        return 'Check back later for new books';
      case 'rating':
        return 'Try a different filter or check back later';
      default:
        return 'No books found in the library';
    }
  }

  void _addToCart(Book book) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    cartProvider.addToCart(book, 1, context: context);
    _showSnackBar('Added to cart!');
  }

  void _requestBorrow(Book book) {
    Navigator.pushNamed(context, '/borrow-request', arguments: {'book': book});
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

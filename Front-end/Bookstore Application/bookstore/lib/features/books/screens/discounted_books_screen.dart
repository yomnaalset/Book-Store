import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../screens/home/components/discounted_books_section.dart';
import '../models/book.dart';
import '../models/author.dart';
import '../models/category.dart' as book_category;

class DiscountedBooksScreen extends StatefulWidget {
  const DiscountedBooksScreen({super.key});

  @override
  State<DiscountedBooksScreen> createState() => _DiscountedBooksScreenState();
}

class _DiscountedBooksScreenState extends State<DiscountedBooksScreen> {
  List<DiscountedBook> _discountedBooks = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDiscountedBooks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDiscountedBooks() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.token == null) {
        setState(() {
          _isLoading = false;
          _error = 'Authentication required';
        });
        return;
      }

      final response = await ApiClient.get(
        '/discounts/book-discounts/discounted-books/',
        queryParams: {'limit': '50'},
        token: authProvider.token!,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final booksData = data['discounted_books'] as List;
        final books = booksData
            .map((bookData) => DiscountedBook.fromJson(bookData))
            .toList();

        if (mounted) {
          setState(() {
            _discountedBooks = books;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = 'Failed to load discounted books';
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading discounted books: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load discounted books';
        });
      }
    }
  }

  List<DiscountedBook> get _filteredBooks {
    if (_searchQuery.isEmpty) {
      return _discountedBooks;
    }

    return _discountedBooks.where((book) {
      return book.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          book.author.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          book.category.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Text(localizations.discountedBooks);
          },
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDiscountedBooks,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surface,
            child: Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: localizations.searchDiscountedBooksPlaceholder,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                );
              },
            ),
          ),

          // Content
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading discounted books',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDiscountedBooks,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredBooks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_offer_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'No discounted books available'
                  : 'No books found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty
                  ? 'Check back later for special offers'
                  : 'Try adjusting your search terms',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Results count
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Text(
                    localizations.discountedBooksFound(_filteredBooks.length),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  );
                },
              ),
              const Spacer(),
              if (_searchQuery.isNotEmpty)
                Text(
                  'for "$_searchQuery"',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),

        // Books Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _filteredBooks.length,
            itemBuilder: (context, index) {
              final book = _filteredBooks[index];
              return _buildDiscountedBookCard(book);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDiscountedBookCard(DiscountedBook book) {
    return GestureDetector(
      onTap: () {
        final bookObject = _convertDiscountedBookToBook(book);
        Navigator.pushNamed(
          context,
          '/book-detail',
          arguments: {'book': bookObject},
        );
      },
      child: Container(
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
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: book.thumbnailUrl != null
                        ? ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                            child: Image.network(
                              book.thumbnailUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(
                                    Icons.book,
                                    size: 40,
                                    color: AppColors.warning,
                                  ),
                                );
                              },
                            ),
                          )
                        : const Center(
                            child: Icon(
                              Icons.book,
                              size: 40,
                              color: AppColors.warning,
                            ),
                          ),
                  ),
                  // Discount Badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Text(
                            book.discountPercentage != null
                                ? localizations.discountOff(
                                    book.discountPercentage!.toInt(),
                                  )
                                : localizations.saleBadge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // Expiring Soon Badge
                  if (book.isExpiringSoon)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'EXPIRES SOON',
                          style: TextStyle(
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

            // Book Details
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        book.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      book.author,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 9,
                        height: 1.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    // Price Display
                    Flexible(child: _buildPriceDisplay(book)),
                    const SizedBox(height: 3),
                    // Action Button
                    Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _addToCart(book),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.warning,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              minimumSize: const Size(0, 24),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              localizations.addToCartButton,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      },
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

  Widget _buildPriceDisplay(DiscountedBook book) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Original Price (Crossed out) and Final Price in a Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (book.originalPrice > 0) ...[
              Text(
                '\$${book.originalPrice.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  decoration: TextDecoration.lineThrough,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 8,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 3),
            ],
            Flexible(
              child: Text(
                '\$${book.finalPrice.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  height: 1.0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        // Savings - only show if there's space, make it very compact
        if (book.discountAmount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              'Save \$${book.discountAmount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.success,
                fontSize: 7,
                fontWeight: FontWeight.w500,
                height: 1.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  void _addToCart(DiscountedBook book) {
    // Convert DiscountedBook to Book and navigate to book detail page
    final bookObject = _convertDiscountedBookToBook(book);
    Navigator.pushNamed(
      context,
      '/book-detail',
      arguments: {'book': bookObject},
    );
  }

  Book _convertDiscountedBookToBook(DiscountedBook discountedBook) {
    return Book(
      id: discountedBook.id.toString(),
      title: discountedBook.title,
      description: discountedBook.description,
      author: Author(
        id: null, // Not available in DiscountedBook
        name: discountedBook.author,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      category: book_category.Category(
        id: null, // Not available in DiscountedBook
        name: discountedBook.category,
      ),
      primaryImageUrl: discountedBook.thumbnailUrl,
      additionalImages: null,
      price: discountedBook.finalPrice.toString(),
      borrowPrice: null, // Not available in DiscountedBook
      availableCopies: discountedBook.isAvailableForPurchase ? 1 : 0,
      averageRating: null,
      evaluationsCount: null,
      isActive: discountedBook.isActive,
      createdAt: null,
      updatedAt: null,
      isNew: false,
      isAvailable: discountedBook.isAvailableForPurchase,
      isAvailableForBorrow: discountedBook.isAvailableForBorrow,
      quantity: discountedBook.isAvailableForPurchase ? 1 : 0,
      borrowCount: null,
      images: null,
      name: discountedBook.title,
      originalPrice: discountedBook.originalPrice,
      discountedPrice: discountedBook.finalPrice,
      discountAmount: discountedBook.discountAmount,
      discountPercentage: discountedBook.discountPercentage,
      hasActiveDiscount: discountedBook.isActive,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../../core/constants/app_colors.dart';
import '../../../../../../core/localization/app_localizations.dart';
import '../../../models/book.dart';
import '../../../../cart/providers/cart_provider.dart';
import '../../../../favorites/providers/favorites_provider.dart';
import '../../../providers/books_provider.dart';
import '../../../../auth/providers/auth_provider.dart';

class NewBooksSection extends StatefulWidget {
  const NewBooksSection({super.key});

  @override
  State<NewBooksSection> createState() => _NewBooksSectionState();
}

class _NewBooksSectionState extends State<NewBooksSection> {
  bool _isLoading = true;
  List<Book> _books = [];

  @override
  void initState() {
    super.initState();
    _loadNewBooks();
  }

  Future<void> _loadNewBooks() async {
    try {
      final booksProvider = Provider.of<BooksProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.token != null) {
        booksProvider.setToken(authProvider.token);
        await booksProvider.getNewBooks(limit: 10);
        debugPrint('NewBooksSection: Token available, loading new books');
      } else {
        debugPrint(
          'NewBooksSection: No token available, cannot load new books',
        );
      }

      if (mounted) {
        setState(() {
          _books = booksProvider.newBooks;
          _isLoading = false;
        });
        debugPrint('NewBooksSection: Loaded ${_books.length} new books');
      }
    } catch (e) {
      debugPrint('Error loading new books: $e');
      if (mounted) {
        setState(() {
          _books = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      Icons.fiber_new,
                      color: AppColors.uranianBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'New Arrivals',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/categories');
                },
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: AppColors.uranianBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Books List
          SizedBox(
            height: 300, // Increased height to prevent overflow
            child: _isLoading
                ? _buildLoadingShimmer()
                : _books.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.book_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No new books available',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for new arrivals',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          width: 140,
          margin: const EdgeInsets.only(right: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 140,
                height: 200,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: 16,
                color: Theme.of(context).cardColor,
              ),
              const SizedBox(height: 4),
              Container(
                width: 100,
                height: 14,
                color: Theme.of(context).cardColor,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBookCard(Book book) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/book-detail', arguments: {'book': book});
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book Cover
            Stack(
              children: [
                Container(
                  width: 140,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: book.primaryImageUrl != null
                        ? Image.network(
                            book.primaryImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, url, error) => Container(
                              color: AppColors.textHint,
                              child: const Icon(
                                Icons.book,
                                color: AppColors.uranianBlue,
                                size: 48,
                              ),
                            ),
                          )
                        : Container(
                            color: AppColors.textHint,
                            child: const Icon(
                              Icons.book,
                              color: AppColors.uranianBlue,
                              size: 48,
                            ),
                          ),
                  ),
                ),

                // New Badge
                if (book.isNew != null && book.isNew!)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                // Quick Actions
                Positioned(
                  top: 8,
                  right: 8,
                  child: Column(
                    children: [
                      _buildQuickActionButton(
                        Icons.favorite_outline,
                        () => _toggleFavorite(book),
                      ),
                      const SizedBox(height: 4),
                      _buildQuickActionButton(
                        Icons.shopping_cart_outlined,
                        () => _addToCart(book),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Book Title
            Text(
              book.title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText,
                height: 1.1,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 3),

            // Author
            Text(
              book.author?.name ?? 'Unknown Author',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.secondaryText,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 6),

            // Price and Rating Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Price
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (book.price != null)
                        Text(
                          '\$${book.priceAsDouble.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.uranianBlue,
                          ),
                        ),
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Text(
                            '${localizations.borrowPrefix} \$${book.borrowPriceAsDouble.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.secondaryText,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Rating
                if (book.averageRating != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star,
                        color: AppColors.warning,
                        size: 10,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        book.averageRating!.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryText,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 16, color: AppColors.uranianBlue),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.uranianBlue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _addToCart(Book book) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    cartProvider.addToCart(book, 1);
    _showSnackBar('Added to cart!');
  }

  void _toggleFavorite(Book book) {
    final favoritesProvider = Provider.of<FavoritesProvider>(
      context,
      listen: false,
    );
    favoritesProvider.toggleFavorite(book);

    final isFavorite = favoritesProvider.isFavorite(book.id.toString());
    _showSnackBar(
      isFavorite ? 'Added to favorites!' : 'Removed from favorites!',
    );
  }
}

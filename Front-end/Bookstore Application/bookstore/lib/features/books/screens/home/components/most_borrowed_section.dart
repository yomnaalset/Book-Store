import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../../core/constants/app_colors.dart';
import '../../../models/book.dart';
import '../../../../cart/providers/cart_provider.dart';
import '../../../../favorites/providers/favorites_provider.dart';
import '../../../providers/books_provider.dart';
import '../../../../auth/providers/auth_provider.dart';

class MostBorrowedSection extends StatefulWidget {
  final Function(String)? onFilterChanged;

  const MostBorrowedSection({super.key, this.onFilterChanged});

  @override
  State<MostBorrowedSection> createState() => _MostBorrowedSectionState();
}

class _MostBorrowedSectionState extends State<MostBorrowedSection> {
  String _sortBy = 'most_borrowed'; // most_borrowed, newest, rating
  List<Book> _books = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMostBorrowedBooks();
  }

  Future<void> _loadMostBorrowedBooks() async {
    await _loadBooksBySort(_sortBy);
  }

  Future<void> _loadBooksBySort(String sortBy) async {
    try {
      final booksProvider = Provider.of<BooksProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.token != null) {
        booksProvider.setToken(authProvider.token);

        List<Book> books = [];
        switch (sortBy) {
          case 'most_borrowed':
            books = await booksProvider.getMostBorrowedBooks(limit: 10);
            break;
          case 'newest':
            books = await booksProvider.getNewBooks(limit: 10);
            break;
          case 'rating':
            books = await booksProvider.getTopRatedBooks(limit: 10);
            break;
          default:
            books = await booksProvider.getMostBorrowedBooks(limit: 10);
        }

        if (mounted) {
          setState(() {
            // Always show all books returned by the API, regardless of availability
            _books = books;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading books by sort: $e');
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
                        color: AppColors.success.withValues(alpha: 10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.trending_up,
                        color: AppColors.success,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _getSectionTitle(_sortBy),
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
                    // Notify parent about filter change
                    widget.onFilterChanged?.call(value);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'most_borrowed',
                      child: Row(
                        children: [
                          Icon(Icons.trending_up, size: 18),
                          SizedBox(width: 8),
                          Text('Most Borrowed'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'newest',
                      child: Row(
                        children: [
                          Icon(Icons.access_time, size: 18),
                          SizedBox(width: 8),
                          Text('Newest First'),
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
                          _getSortLabel(_sortBy),
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
                    'No books found',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try a different filter or check back later',
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
          // Section Header with Sort Options
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.trending_up,
                      color: AppColors.success,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _getSectionTitle(_sortBy),
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
                  // Notify parent about filter change
                  widget.onFilterChanged?.call(value);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'most_borrowed',
                    child: Row(
                      children: [
                        Icon(Icons.trending_up, size: 18),
                        SizedBox(width: 8),
                        Text('Most Borrowed'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'newest',
                    child: Row(
                      children: [
                        Icon(Icons.access_time, size: 18),
                        SizedBox(width: 8),
                        Text('Newest First'),
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
                        _getSortLabel(_sortBy),
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
            height: 240, // Increased height to prevent overflow
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _books.length,
              itemBuilder: (context, index) {
                final book = _books[index];
                return _buildBookCard(book, index + 1);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookCard(Book book, int rank) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/book-detail', arguments: {'book': book});
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book Cover with Rank Badge
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: 100, // Reduced height to give more space for content
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: book.primaryImageUrl != null
                        ? Image.network(
                            book.primaryImageUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: AppColors.background,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.uranianBlue,
                                    ),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, url, error) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.uranianBlue.withValues(
                                      alpha: 0.1,
                                    ),
                                    AppColors.primary.withValues(alpha: 0.1),
                                  ],
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.book_outlined,
                                  color: AppColors.uranianBlue,
                                  size: 40,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.uranianBlue.withValues(alpha: 0.1),
                                  AppColors.primary.withValues(alpha: 0.1),
                                ],
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.book_outlined,
                                color: AppColors.uranianBlue,
                                size: 40,
                              ),
                            ),
                          ),
                  ),
                ),

                // Rank Badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _getRankColor(rank),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        rank.toString(),
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

                // Trending Icon
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 90),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.trending_up,
                      color: AppColors.white,
                      size: 12,
                    ),
                  ),
                ),
              ],
            ),

            // Book Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    book.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      height: 1.1,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 3),

                  // Author
                  Text(
                    book.author?.name ?? 'Unknown Author',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 6),

                  // Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Borrow Count
                      Row(
                        children: [
                          const Icon(
                            Icons.download_outlined,
                            color: AppColors.success,
                            size: 10,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${book.borrowCount}',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),

                      // Rating
                      if (book.averageRating != null)
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: AppColors.warning,
                              size: 10,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              book.averageRating!.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.color,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 32, // Fixed height for button
                      child: ElevatedButton(
                        onPressed: book.isAvailableForBorrow == true
                            ? () {
                                _addToCart(book);
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: book.isAvailableForBorrow == true
                              ? AppColors.uranianBlue
                              : AppColors.textHint.withValues(alpha: 0.3),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text(
                          book.isAvailableForBorrow == true
                              ? 'Borrow'
                              : 'Unavailable',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: book.isAvailableForBorrow == true
                                ? Colors.white
                                : AppColors.textHint,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.uranianBlue),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: IconButton(
                        onPressed: () {
                          _toggleFavorite(book);
                        },
                        icon: const Icon(
                          Icons.favorite_outline,
                          color: AppColors.uranianBlue,
                          size: 14,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return AppColors.uranianBlue;
    }
  }

  String _getSortLabel(String sortBy) {
    switch (sortBy) {
      case 'most_borrowed':
        return 'Most Borrowed';
      case 'newest':
        return 'Newest';
      case 'rating':
        return 'Top Rated';
      default:
        return 'Sort';
    }
  }

  String _getSectionTitle(String sortBy) {
    switch (sortBy) {
      case 'most_borrowed':
        return 'Most Popular';
      case 'newest':
        return 'New Arrivals';
      case 'rating':
        return 'Top Rated';
      default:
        return 'Most Popular';
    }
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

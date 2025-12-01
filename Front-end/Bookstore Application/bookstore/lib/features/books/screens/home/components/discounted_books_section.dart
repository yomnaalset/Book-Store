import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../../../../../core/constants/app_colors.dart';
import '../../../../../../core/services/api_client.dart';
import '../../../../auth/providers/auth_provider.dart';
import '../../../models/book.dart';
import '../../../models/author.dart';
import '../../../models/category.dart' as book_category;

class DiscountedBooksSection extends StatefulWidget {
  const DiscountedBooksSection({super.key});

  @override
  State<DiscountedBooksSection> createState() => _DiscountedBooksSectionState();
}

class _DiscountedBooksSectionState extends State<DiscountedBooksSection> {
  List<DiscountedBook> _discountedBooks = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDiscountedBooks();
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
        queryParams: {'limit': '10'},
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

    if (_error != null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading discounted books',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
            ),
          ],
        ),
      );
    }

    if (_discountedBooks.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(),
            const SizedBox(height: 16),
            // Empty state
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.local_offer_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No discounted books available',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check back later for special offers',
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
          _buildSectionHeader(),
          const SizedBox(height: 16),

          // Books List
          SizedBox(
            height: 300,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _discountedBooks.length,
              itemBuilder: (context, index) {
                final book = _discountedBooks[index];
                return _buildDiscountedBookCard(book);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.local_offer,
                color: AppColors.warning,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Discounted Books',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        TextButton(
          onPressed: () {
            Navigator.pushNamed(context, '/all-discounted-books');
          },
          child: const Text(
            'View All',
            style: TextStyle(
              color: AppColors.warning,
              fontWeight: FontWeight.w600,
            ),
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
        width: 160,
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
            SizedBox(
              height: 120,
              width: double.infinity,
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
                      child: Text(
                        book.discountPercentage != null
                            ? '${book.discountPercentage!.toInt()}% OFF'
                            : 'SALE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Status Badges
                  if (book.isUpcoming)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'COMING SOON',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (book.isExpiringSoon && !book.isUpcoming)
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
                            fontSize: 9,
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
              child: Padding(
                padding: const EdgeInsets.all(8),
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
                    const SizedBox(height: 4),
                    Text(
                      book.author,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Price Display
                    _buildPriceDisplay(book),
                    const SizedBox(height: 8),
                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _addToCart(book),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warning,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          minimumSize: const Size(0, 28),
                        ),
                        child: const Text(
                          'Add to Cart',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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
        // Original Price (Crossed out)
        if (book.originalPrice > 0)
          Text(
            '\$${book.originalPrice.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        // Final Price (Green)
        Text(
          '\$${book.finalPrice.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.success,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        // Savings
        if (book.discountAmount > 0)
          Text(
            'Save \$${book.discountAmount.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.success,
              fontSize: 9,
              fontWeight: FontWeight.w500,
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
      description:
          discountedBook.description, // Use description from DiscountedBook
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
    );
  }
}

class DiscountedBook {
  final int id;
  final String title;
  final String? description; // Add description field
  final String author;
  final String category;
  final String? thumbnailUrl;
  final double originalPrice;
  final double finalPrice;
  final double discountAmount;
  final double? discountPercentage;
  final String discountType;
  final String discountCode;
  final bool canUse;
  final DateTime expiresAt;
  final DateTime? startsAt;
  final bool isActive;
  final bool isUpcoming;
  final bool isExpiringSoon;
  final bool isAvailableForPurchase;
  final bool isAvailableForBorrow;

  DiscountedBook({
    required this.id,
    required this.title,
    this.description, // Add description parameter
    required this.author,
    required this.category,
    this.thumbnailUrl,
    required this.originalPrice,
    required this.finalPrice,
    required this.discountAmount,
    this.discountPercentage,
    required this.discountType,
    required this.discountCode,
    required this.canUse,
    required this.expiresAt,
    this.startsAt,
    required this.isActive,
    required this.isUpcoming,
    required this.isExpiringSoon,
    required this.isAvailableForPurchase,
    required this.isAvailableForBorrow,
  });

  factory DiscountedBook.fromJson(Map<String, dynamic> json) {
    return DiscountedBook(
      id: json['id'],
      title: json['title'],
      description: json['description'], // Parse description field
      author: json['author'],
      category: json['category'],
      thumbnailUrl: json['thumbnail_url'],
      originalPrice: (json['original_price'] ?? 0).toDouble(),
      finalPrice: (json['final_price'] ?? 0).toDouble(),
      discountAmount: (json['discount_amount'] ?? 0).toDouble(),
      discountPercentage: json['discount_percentage']?.toDouble(),
      discountType: json['discount_type'],
      discountCode: json['discount_code'],
      canUse: json['can_use'] ?? false,
      expiresAt: DateTime.parse(json['expires_at']),
      startsAt: json['starts_at'] != null
          ? DateTime.parse(json['starts_at'])
          : null,
      isActive: json['is_active'] ?? false,
      isUpcoming: json['is_upcoming'] ?? false,
      isExpiringSoon: json['is_expiring_soon'] ?? false,
      isAvailableForPurchase: json['is_available_for_purchase'] ?? false,
      isAvailableForBorrow: json['is_available_for_borrow'] ?? false,
    );
  }
}

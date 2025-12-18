import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/extensions/theme_extensions.dart';
import '../../../core/widgets/common/custom_button.dart';
import '../../../core/widgets/common/loading_indicator.dart';
import '../../../core/localization/app_localizations.dart';
import '../../cart/providers/cart_provider.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../../reviews/widgets/reviews_list.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/book.dart';
import '../services/books_api_service.dart';

class BookDetailScreen extends StatefulWidget {
  final Book book;

  const BookDetailScreen({super.key, required this.book});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isFavorite = false;
  int _quantity = 1;

  // State for fetching book details
  Book? _bookDetails;
  bool _isLoading = true;
  String? _errorMessage;

  // Debouncing timer to prevent rapid API calls
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkFavoriteStatus();
    _fetchBookDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _checkFavoriteStatus() {
    final favoritesProvider = Provider.of<FavoritesProvider>(
      context,
      listen: false,
    );
    _isFavorite = favoritesProvider.isFavorite(widget.book.id.toString());
  }

  Future<void> _fetchBookDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final bookDetails = await BooksApiService.getBookDetail(
        int.parse(widget.book.id),
        token: authProvider.token,
      );

      if (mounted) {
        setState(() {
          _bookDetails = bookDetails;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _debouncedFetchBookDetails() {
    // Cancel any existing timer
    _debounceTimer?.cancel();

    // Set a new timer
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _fetchBookDetails();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use fetched book details if available, otherwise fall back to passed book
    final book = _bookDetails ?? widget.book;

    if (_isLoading) {
      final localizations = AppLocalizations.of(context);
      return Scaffold(
        appBar: AppBar(
          title: Text(localizations.bookDetailsTitle),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: LoadingIndicator()),
      );
    }

    if (_errorMessage != null) {
      final localizations = AppLocalizations.of(context);
      return Scaffold(
        appBar: AppBar(
          title: Text(localizations.bookDetailsTitle),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                localizations.failedToLoadBookDetails,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 14,
                  color: context.secondaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _fetchBookDetails,
                child: Text(localizations.retry),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(book),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBookInfo(book),
                  const SizedBox(height: AppDimensions.spacingL),
                  _buildTabs(),
                  const SizedBox(height: AppDimensions.spacingM),
                  _buildTabContent(book),
                  const SizedBox(
                    height: 12.0,
                  ), // Reduced to approximately 3 lines
                  _buildActionButtons(book),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(Book book) {
    return SliverAppBar(
      expandedHeight: 400,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Book Cover
            book.primaryImageUrl != null
                ? Image.network(
                    book.primaryImageUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: context.surfaceColor,
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) =>
                        _buildDefaultBookCover(),
                  )
                : _buildDefaultBookCover(),
            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
            // Book Title Overlay
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(
                        localizations.byAuthorUnknown(
                          book.author?.name ?? localizations.unknownAuthor,
                        ),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        Consumer<FavoritesProvider>(
          builder: (context, favoritesProvider, child) {
            return IconButton(
              onPressed: () => _toggleFavorite(favoritesProvider),
              icon: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite ? AppColors.error : Colors.white,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBookInfo(Book book) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rating and Reviews
        Row(
          children: [
            if (book.averageRating != null) ...[
              ...List.generate(5, (index) {
                return Icon(
                  index < (book.averageRating ?? 0).floor()
                      ? Icons.star
                      : index < (book.averageRating ?? 0)
                      ? Icons.star_half
                      : Icons.star_border,
                  color: AppColors.warning,
                  size: 20,
                );
              }),
              const SizedBox(width: AppDimensions.spacingS),
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Text(
                    '${book.averageRating?.toStringAsFixed(1) ?? '0.0'} ${localizations.reviewsCountWithNumber(book.evaluationsCount ?? 0)}',
                    style: TextStyle(
                      fontSize: AppDimensions.fontSizeS,
                      color: context.secondaryTextColor,
                    ),
                  );
                },
              ),
            ],
          ],
        ),
        const SizedBox(height: AppDimensions.spacingM),

        // Price
        Row(
          children: [
            if (book.hasDiscount) ...[
              Text(
                '\$${book.originalPrice!.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: AppDimensions.fontSizeL,
                  color: context.secondaryTextColor,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingS),
              Text(
                '\$${book.discountedPrice!.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: AppDimensions.fontSizeXL,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingS),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingS,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                ),
                child: Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      localizations.saveAmount('\$${book.savingsAmount.toStringAsFixed(2)}'),
                      style: const TextStyle(
                        fontSize: AppDimensions.fontSizeS,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              // Show price only if it's not null/empty, otherwise show "Price not set"
              if (book.price != null &&
                  book.price!.isNotEmpty &&
                  book.priceAsDouble > 0) ...[
                Text(
                  '\$${book.priceAsDouble.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: AppDimensions.fontSizeXL,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ] else ...[
                Text(
                  'Price not set',
                  style: TextStyle(
                    fontSize: AppDimensions.fontSizeXL,
                    fontWeight: FontWeight.bold,
                    color: context.secondaryTextColor,
                  ),
                ),
              ],
            ],
          ],
        ),
        const SizedBox(height: AppDimensions.spacingM),

        // Availability
        Row(
          children: [
            Icon(
              _isBookAvailable(book) ? Icons.check_circle : Icons.cancel,
              color: _isBookAvailable(book)
                  ? AppColors.success
                  : AppColors.error,
              size: 20,
            ),
            const SizedBox(width: AppDimensions.spacingS),
            Text(
              book.availabilityStatus ?? _getAvailabilityStatus(book),
              style: TextStyle(
                fontSize: AppDimensions.fontSizeM,
                color: _isBookAvailable(book)
                    ? AppColors.success
                    : AppColors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabs() {
    final localizations = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        labelColor: Colors.white,
        unselectedLabelColor: context.secondaryTextColor,
        labelStyle: const TextStyle(
          fontSize: AppDimensions.fontSizeM,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: AppDimensions.fontSizeM,
          fontWeight: FontWeight.w500,
        ),
        dividerColor: Colors.transparent,
        tabs: [
          Tab(text: localizations.descriptionTab),
          Tab(text: localizations.detailsTab),
          Tab(text: localizations.reviewsTab),
        ],
      ),
    );
  }

  Widget _buildTabContent(Book book) {
    return Container(
      constraints: const BoxConstraints(minHeight: 80, maxHeight: 200),
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildDescriptionTab(book),
          _buildDetailsTab(book),
          _buildReviewsTab(book),
        ],
      ),
    );
  }

  Widget _buildDescriptionTab(Book book) {
    final description = book.description?.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingM,
        vertical: AppDimensions.spacingS,
      ),
      child: description != null && description.isNotEmpty
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.spacingM),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                border: Border.all(
                  color: context.dividerColor.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                description,
                style: TextStyle(
                  fontSize: AppDimensions.fontSizeM,
                  color: context.textColor,
                  height: 1.5,
                ),
              ),
            )
          : Container(
              padding: const EdgeInsets.all(AppDimensions.spacingM),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                border: Border.all(
                  color: context.dividerColor.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 32,
                    color: context.secondaryTextColor.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: AppDimensions.spacingS),
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Column(
                        children: [
                          Text(
                            localizations.noDescriptionAvailable,
                            style: TextStyle(
                              fontSize: AppDimensions.fontSizeM,
                              color: context.secondaryTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacingXS),
                          Text(
                            localizations.noDescriptionAvailableBook,
                            style: TextStyle(
                              fontSize: AppDimensions.fontSizeS,
                              color: context.secondaryTextColor.withValues(
                                alpha: 0.7,
                              ),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDetailsTab(Book book) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingM,
        vertical: AppDimensions.spacingS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                    localizations.authorLabel,
                    book.author?.name ?? localizations.unknownAuthor,
                  ),
                  _buildDetailRow(
                    localizations.categoryLabel,
                    book.category?.name ?? localizations.notAvailable,
                  ),
                ],
              );
            },
          ),
          if (book.hasDiscount) ...[
            const SizedBox(height: AppDimensions.spacingM),
            Container(
              padding: const EdgeInsets.all(AppDimensions.spacingM),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_offer,
                    color: AppColors.success,
                    size: 20,
                  ),
                  const SizedBox(width: AppDimensions.spacingS),
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(
                        localizations.thisBookOnSale,
                        style: const TextStyle(
                          fontSize: AppDimensions.fontSizeM,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: AppDimensions.fontSizeS,
                fontWeight: FontWeight.w600,
                color: context.secondaryTextColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: AppDimensions.fontSizeS,
                color: context.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsTab(Book book) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingM,
        vertical: AppDimensions.spacingS,
      ),
      child: ReviewsList(
        bookId: book.id,
        onReviewsUpdated: _debouncedFetchBookDetails,
      ),
    );
  }

  Widget _buildActionButtons(Book book) {
    return Column(
      children: [
        // Quantity Selector
        Row(
          children: [
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  localizations.quantityLabel,
                  style: TextStyle(
                    fontSize: AppDimensions.fontSizeM,
                    fontWeight: FontWeight.w600,
                    color: context.textColor,
                  ),
                );
              },
            ),
            const SizedBox(width: AppDimensions.spacingM),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: context.dividerColor),
                borderRadius: BorderRadius.circular(AppDimensions.radiusS),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _quantity > 1
                        ? () => setState(() => _quantity--)
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Text(
                    _quantity.toString(),
                    style: const TextStyle(
                      fontSize: AppDimensions.fontSizeM,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _quantity++),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8.0), // Reduced spacing before action buttons
        // Action Buttons
        Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    text: localizations.addToCartButtonDetail,
                    onPressed: _canAddToCart(book) ? _addToCart : null,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingM),
                // Borrow Button
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    text: localizations.borrowBookButton,
                    onPressed: _canBorrowBook(book) ? _borrowBook : null,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // Helper methods for availability logic
  bool _isBookAvailable(Book book) {
    // Book is available if:
    // 1. It's marked as available for purchase AND has stock
    // 2. OR it's available for borrowing AND has available copies
    return (book.isAvailable == true && (book.quantity ?? 0) > 0) ||
        (book.isAvailableForBorrow == true && (book.availableCopies ?? 0) > 0);
  }

  String _getAvailabilityStatus(Book book) {
    final localizations = AppLocalizations.of(context);
    // Check if book is available for purchase
    if (book.isAvailable == true && (book.quantity ?? 0) > 0) {
      if ((book.availableCopies ?? 0) == 0) {
        return localizations.outOfStockStatus;
      } else if ((book.availableCopies ?? 0) <= 3) {
        return localizations.limitedStock;
      } else {
        return localizations.inStockStatus;
      }
    }

    // Check if book is available for borrowing
    if (book.isAvailableForBorrow == true && (book.availableCopies ?? 0) > 0) {
      return localizations.availableForBorrowing;
    }

    // If neither purchase nor borrowing is available
    return localizations.notAvailableStatus;
  }

  bool _canAddToCart(Book book) {
    // Can add to cart if:
    // 1. Book is available for purchase
    // 2. Has stock (quantity > 0)
    // 3. Has a valid price (not null/empty and > 0)
    return book.isAvailable == true &&
        (book.quantity ?? 0) > 0 &&
        book.price != null &&
        book.price!.isNotEmpty &&
        book.priceAsDouble > 0;
  }

  bool _canBorrowBook(Book book) {
    // Can borrow if:
    // 1. Book is available for borrowing
    // 2. Has available copies
    return book.isAvailableForBorrow == true && (book.availableCopies ?? 0) > 0;
  }

  Widget _buildDefaultBookCover() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.uranianBlue.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.book_outlined, size: 100, color: AppColors.primary),
      ),
    );
  }

  void _toggleFavorite(FavoritesProvider favoritesProvider) async {
    final book = _bookDetails ?? widget.book;
    setState(() {
      _isFavorite = !_isFavorite;
    });

    try {
      if (_isFavorite) {
        // Get auth token and add to favorites
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.token != null) {
          await favoritesProvider.addToFavoritesWithAuth(
            book,
            authProvider.token!,
          );
        } else {
          await favoritesProvider.addToFavorites(book);
        }
      } else {
        // Get auth token and remove from favorites
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.token != null) {
          await favoritesProvider.removeFromFavoritesWithAuth(
            book.id.toString(),
            authProvider.token!,
          );
        } else {
          await favoritesProvider.removeFromFavorites(book.id.toString());
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isFavorite ? 'Added to favorites!' : 'Removed from favorites!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      // Revert the state if there was an error
      setState(() {
        _isFavorite = !_isFavorite;
      });

      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localizations.errorOccurred}: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _addToCart() {
    final book = _bookDetails ?? widget.book;
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final localizations = AppLocalizations.of(context);
    cartProvider.addToCart(book, _quantity, context: context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${localizations.addedToCartPlaceholder}: ${book.title}'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _borrowBook() {
    final book = _bookDetails ?? widget.book;
    Navigator.pushNamed(context, '/borrow-request', arguments: {'book': book});
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../../core/constants/app_colors.dart';
import '../../../../../../core/localization/app_localizations.dart';
import '../../../models/book.dart';
import '../../../providers/books_provider.dart';
import '../../../widgets/book_price_display.dart';
import '../../../../auth/providers/auth_provider.dart';

class BorrowedBooksSection extends StatefulWidget {
  const BorrowedBooksSection({super.key});

  @override
  State<BorrowedBooksSection> createState() => _BorrowedBooksSectionState();
}

class _BorrowedBooksSectionState extends State<BorrowedBooksSection> {
  List<Book> _books = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Defer loading until after the build phase to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBorrowedBooks();
    });
  }

  Future<void> _loadBorrowedBooks() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final booksProvider = Provider.of<BooksProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Set token if available, but still try to load books even without auth
      if (authProvider.token != null) {
        booksProvider.setToken(authProvider.token);
        debugPrint('BorrowedBooksSection: Token set for API call');
      } else {
        debugPrint(
          'BorrowedBooksSection: No token available, proceeding without auth',
        );
      }

      debugPrint('BorrowedBooksSection: Calling getMostBorrowedBooks...');
      final books = await booksProvider.getMostBorrowedBooks(
        limit: 10,
        forceRefresh: true,
      );

      debugPrint(
        'BorrowedBooksSection: Received ${books.length} books from API',
      );

      if (books.isEmpty) {
        debugPrint(
          'BorrowedBooksSection: WARNING - No books returned from API!',
        );
      }

      for (var book in books) {
        debugPrint(
          'BorrowedBooksSection: Book "${book.title}" (id: ${book.id}) - isAvailableForBorrow: ${book.isAvailableForBorrow}, borrowPrice: ${book.borrowPrice}, isAvailable: ${book.isAvailable}',
        );
      }

      if (mounted) {
        setState(() {
          // Show books available for borrowing
          // Filter: show if is_available_for_borrow is true OR has borrow price > 0
          _books = books.where((book) {
            // Check if book has a borrow price > 0
            final hasBorrowPrice =
                book.borrowPrice != null &&
                book.borrowPrice!.isNotEmpty &&
                book.borrowPrice != '0.00' &&
                book.borrowPrice != '0';

            // Check if explicitly marked as available for borrow
            final isAvailableForBorrow = book.isAvailableForBorrow == true;

            // Show if available for borrow OR has borrow price
            final shouldShow = isAvailableForBorrow || hasBorrowPrice;

            debugPrint(
              'BorrowedBooksSection: Book "${book.title}" (id: ${book.id}) - isAvailableForBorrow: $isAvailableForBorrow, borrowPrice: ${book.borrowPrice}, hasBorrowPrice: $hasBorrowPrice, shouldShow: $shouldShow',
            );

            return shouldShow;
          }).toList();

          debugPrint(
            'BorrowedBooksSection: Filtered ${_books.length} books from ${books.length} total',
          );

          // Fallback: If filter removed all books but API returned books, show all
          // This handles cases where API filtering might not work perfectly
          if (_books.isEmpty && books.isNotEmpty) {
            debugPrint(
              'BorrowedBooksSection: Filter removed all books, showing all ${books.length} books as fallback',
            );
            _books = books;
          }

          debugPrint(
            'BorrowedBooksSection: Final count - Displaying ${_books.length} books',
          );

          if (_books.isEmpty) {
            debugPrint('BorrowedBooksSection: ERROR - No books to display!');
          }

          _isLoading = false;
        });
      } else {
        debugPrint(
          'BorrowedBooksSection: Widget not mounted, skipping setState',
        );
      }
    } catch (e) {
      debugPrint('Error loading borrowed books: $e');
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
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.trending_up,
                        color: AppColors.success,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Text(
                          localizations.borrowedBooks,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ],
                ),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/all-borrowed-books');
                      },
                      child: Text(
                        localizations.viewAll,
                        style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Empty state
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.library_books_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(
                        localizations.noBorrowedBooksFound,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No books available for borrowing at the moment',
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
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.trending_up,
                      color: AppColors.success,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(
                        localizations.borrowedBooks,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ],
              ),
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/all-borrowed-books');
                    },
                    child: Text(
                      localizations.viewAll,
                      style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
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
        width: 140,
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
              height: 100,
              width: double.infinity,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
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
                                    color: AppColors.success,
                                  ),
                                );
                              },
                            ),
                          )
                        : const Center(
                            child: Icon(
                              Icons.book,
                              size: 40,
                              color: AppColors.success,
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
                        child: Builder(
                          builder: (context) {
                            final localizations = AppLocalizations.of(context);
                            return Text(
                              localizations.discountOff(
                                book.savingsPercentage.toInt(),
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
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
                    // Title
                    Text(
                      book.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Author
                    Text(
                      book.author?.name ?? 'Unknown Author',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Price display
                    BookPriceDisplay(
                      book: book,
                      showBorrowPrice: true,
                      isCompact: true,
                      fontSize: 8,
                      smallFontSize: 7,
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
}

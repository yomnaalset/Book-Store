import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/common/error_message.dart';
import '../../../core/widgets/common/loading_indicator.dart';
import '../models/book.dart';
import '../providers/books_provider.dart';
import '../../auth/providers/auth_provider.dart';

class AllBorrowedBooksScreen extends StatefulWidget {
  const AllBorrowedBooksScreen({super.key});

  @override
  State<AllBorrowedBooksScreen> createState() => _AllBorrowedBooksScreenState();
}

class _AllBorrowedBooksScreenState extends State<AllBorrowedBooksScreen> {
  bool _isLoading = true;
  List<Book> _books = [];
  String? _error;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all'; // New filter state - using keys

  @override
  void initState() {
    super.initState();
    _loadAllBorrowedBooks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllBorrowedBooks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final booksProvider = Provider.of<BooksProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.token != null) {
        booksProvider.setToken(authProvider.token);
        final books = await booksProvider.getMostBorrowedBooks(
          limit: 100,
        ); // Get more books

        setState(() {
          // Show only books available for borrowing
          _books = books
              .where((book) => book.isAvailableForBorrow == true)
              .toList();
          _isLoading = false;
        });

        debugPrint(
          'AllBorrowedBooksScreen: Loaded ${books.length} total books',
        );
        debugPrint(
          'AllBorrowedBooksScreen: Available for borrow: ${_books.length} books',
        );
        for (int i = 0; i < _books.length && i < 3; i++) {
          final book = _books[i];
          debugPrint(
            'AllBorrowedBooksScreen: Book $i - Title: "${book.title}", Name: "${book.name}", Author: "${book.author?.name}"',
          );
        }
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Authentication required';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
      debugPrint('Error loading all borrowed books: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Borrowed Books'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        actions: [
          IconButton(
            onPressed: () {
              _loadAllBorrowedBooks();
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: LoadingIndicator())
                : _error != null
                ? ErrorMessage(message: _error!, onRetry: _loadAllBorrowedBooks)
                : _getFilteredBooks().isEmpty
                ? _buildEmptyState()
                : _buildBooksGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() => _searchQuery = value);
          _applyFilters();
        },
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context).searchBooksPlaceholder,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Builder(
      builder: (context) {
        final localizations = AppLocalizations.of(context);
        return Container(
          height: 50,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingM,
          ),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildFilterChip('all', localizations.filterAll),
              const SizedBox(width: 8),
              _buildFilterChip('new_books', localizations.filterNewBooks),
              const SizedBox(width: 8),
              _buildFilterChip(
                'highest_rated',
                localizations.filterHighestRated,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = filterKey;
        });
        _applyFilters();
      },
      selectedColor: AppColors.success.withValues(alpha: 0.2),
      checkmarkColor: AppColors.success,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.success : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Future<void> _applyFilters() async {
    final booksProvider = Provider.of<BooksProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.token != null) {
      booksProvider.setToken(authProvider.token);

      // Determine sortBy parameter based on selected filter
      String? sortBy;
      if (_selectedFilter == 'new_books') {
        sortBy = 'created_at';
      } else if (_selectedFilter == 'highest_rated') {
        sortBy = 'average_rating';
      }

      debugPrint('AllBorrowedBooksScreen: Applying filters with API call');
      debugPrint('  - Search query: "$_searchQuery"');
      debugPrint('  - Selected filter: "$_selectedFilter"');
      debugPrint('  - Sort by: $sortBy');

      await booksProvider.getBooks(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        availableToBorrow: true,
        sortBy: sortBy,
      );
    }
  }

  List<Book> _getFilteredBooks() {
    // Since filtering is now done via API calls, just return the books from provider
    return _books;
  }

  Widget _buildBooksGrid() {
    final filteredBooks = _getFilteredBooks();
    return GridView.builder(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75, // Increased from 0.7 to prevent overflow
        crossAxisSpacing: AppDimensions.spacingM,
        mainAxisSpacing: AppDimensions.spacingM,
      ),
      itemCount: filteredBooks.length,
      itemBuilder: (context, index) {
        final book = filteredBooks[index];
        return _buildBookCard(book);
      },
    );
  }

  Widget _buildBookCard(Book book) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/book-detail', arguments: {'book': book});
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book Cover
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: book.primaryImageUrl != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
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
            ),

            // Book Details
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8), // Reduced padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 12, // Reduced font size
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2), // Reduced spacing
                    Text(
                      book.author?.name ?? 'Unknown Author',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 10, // Reduced font size
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    // Borrow Price
                    if (book.borrowPrice != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6, // Reduced padding
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            6,
                          ), // Reduced radius
                        ),
                        child: Builder(
                          builder: (context) {
                            final localizations = AppLocalizations.of(context);
                            return Text(
                              '${localizations.borrowPrefix} \$${book.borrowPrice}',
                              style: const TextStyle(
                                fontSize: 10, // Reduced font size
                                fontWeight: FontWeight.w600,
                                color: AppColors.success,
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 4), // Reduced spacing
                    // Borrow Button
                    GestureDetector(
                      onTap: () => _requestBorrow(book),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                        ), // Reduced padding
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(
                            6,
                          ), // Reduced radius
                        ),
                        child: Builder(
                          builder: (context) {
                            final localizations = AppLocalizations.of(context);
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.library_add,
                                  size: 14, // Reduced icon size
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 2), // Reduced spacing
                                Text(
                                  localizations.borrowButton,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10, // Reduced font size
                                  ),
                                ),
                              ],
                            );
                          },
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 80,
              color: AppColors.textHint.withValues(alpha: 128),
            ),
            const SizedBox(height: AppDimensions.spacingL),
            Text(
              'No borrowed books found',
              style: TextStyle(
                fontSize: AppDimensions.fontSizeL,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Text(
              'No books available for borrowing at the moment',
              style: TextStyle(
                fontSize: AppDimensions.fontSizeM,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _requestBorrow(Book book) {
    Navigator.pushNamed(context, '/borrow-request', arguments: {'book': book});
  }
}

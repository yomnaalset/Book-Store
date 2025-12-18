import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/extensions/theme_extensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/common/error_message.dart';
import '../../../core/widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/books_provider.dart';
import '../models/book.dart';
import 'book_detail_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  int? _selectedCategoryId;
  bool _isLoadingBooks = false;
  String _selectedFilter =
      'all'; // New filter state - using keys instead of labels

  @override
  void initState() {
    super.initState();
    // Delay loading to ensure AuthProvider is fully initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBooks();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeFromArguments();
    _ensureTokenIsSet();
  }

  void _initializeFromArguments() {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args['categoryId'] != null) {
      _selectedCategoryId = args['categoryId'] as int;
      // Reload books with the new category filter
      _loadBooks();
    }
  }

  void _ensureTokenIsSet() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final booksProvider = Provider.of<BooksProvider>(context, listen: false);

    if (authProvider.token != null) {
      booksProvider.setToken(authProvider.token);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getAppBarTitle() {
    final localizations = AppLocalizations.of(context);
    if (_selectedCategoryId != null) {
      return localizations.booksInCategory;
    } else if (_searchQuery.isNotEmpty) {
      return localizations.searchResultsTitle;
    } else {
      return localizations.purchaseBooks;
    }
  }

  Future<void> _loadBooks() async {
    if (_isLoadingBooks) {
      debugPrint('CategoriesScreen: Already loading books, skipping...');
      return;
    }

    _isLoadingBooks = true;

    final booksProvider = Provider.of<BooksProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    debugPrint('CategoriesScreen: Loading books...');
    debugPrint(
      'CategoriesScreen: AuthProvider token: ${authProvider.token != null ? '${authProvider.token!.substring(0, 20)}...' : 'null'}',
    );
    debugPrint('CategoriesScreen: Selected category ID: $_selectedCategoryId');

    // Ensure the BooksProvider has the current token
    if (authProvider.token != null) {
      booksProvider.setToken(authProvider.token);
      debugPrint('CategoriesScreen: Token set in BooksProvider');
    } else {
      // If no token, try to refresh from storage
      debugPrint(
        'CategoriesScreen: No token available, attempting to refresh from storage',
      );
      await authProvider.refreshUserData();
      if (authProvider.token != null) {
        booksProvider.setToken(authProvider.token);
        debugPrint(
          'CategoriesScreen: Token refreshed and set in BooksProvider',
        );
      } else {
        debugPrint('CategoriesScreen: Still no token available after refresh');
        return; // Don't proceed without a token
      }
    }

    try {
      // Always load all books first, then filter by category if needed
      debugPrint('CategoriesScreen: Loading all books from API');
      await booksProvider.getBooks();

      debugPrint(
        'CategoriesScreen: Books loaded successfully, count: ${booksProvider.books.length}',
      );
    } catch (e) {
      debugPrint('CategoriesScreen: Error loading books: $e');
      // If there's an error, it might be due to authentication
      // The error will be handled by the BooksProvider and displayed in the UI
    } finally {
      _isLoadingBooks = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to AuthProvider changes to ensure token is always up to date
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_getAppBarTitle()),
            actions: [
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return IconButton(
                    onPressed: _loadBooks,
                    icon: const Icon(Icons.refresh),
                    tooltip: localizations.refresh,
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              _buildSearchBar(),
              _buildFilterBar(),
              Expanded(child: _buildBooksList()),
            ],
          ),
        );
      },
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
          hintText: AppLocalizations.of(context).searchBooksHint,
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
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return Row(
                children: [
                  _buildFilterChip(localizations.filterAll, 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip(localizations.filterNewBooks, 'new_books'),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    localizations.filterHighestRated,
                    'highest_rated',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String filterKey) {
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
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : context.secondaryTextColor,
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

      debugPrint('CategoriesScreen: Applying filters with API call');
      debugPrint('  - Search query: "$_searchQuery"');
      debugPrint('  - Selected filter: "$_selectedFilter"');
      debugPrint('  - Sort by: $sortBy');

      await booksProvider.getBooks(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        categoryId: _selectedCategoryId,
        sortBy: sortBy,
      );
    }
  }

  Widget _buildBooksList() {
    return Consumer<BooksProvider>(
      builder: (context, booksProvider, child) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);

        // Force a rebuild when books change
        debugPrint('CategoriesScreen: Consumer rebuild triggered');
        debugPrint(
          'CategoriesScreen: Current books count: ${booksProvider.books.length}',
        );
        // Check if user is authenticated
        if (!authProvider.isAuthenticated) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Column(
                      children: [
                        Text(
                          localizations.pleaseLogInToViewBooks,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          localizations.needToBeLoggedIn,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/login');
                          },
                          child: Text(localizations.goToLogin),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        }

        if (booksProvider.isLoading) {
          return const Center(child: LoadingIndicator());
        }

        if (booksProvider.error != null) {
          return ErrorMessage(
            message: booksProvider.error!,
            onRetry: () => booksProvider.getBooks(),
          );
        }

        List<Book> books = booksProvider.books;

        debugPrint('CategoriesScreen: UI Build - BooksProvider state:');
        debugPrint('  - isLoading: ${booksProvider.isLoading}');
        debugPrint('  - error: ${booksProvider.error}');
        debugPrint('  - books count: ${booksProvider.books.length}');
        debugPrint('  - search query: "$_searchQuery"');
        debugPrint('  - selected category: $_selectedCategoryId');

        if (books.isEmpty) {
          debugPrint(
            'CategoriesScreen: No books to display, showing empty state',
          );
          debugPrint(
            'CategoriesScreen: BooksProvider books count: ${booksProvider.books.length}',
          );
          debugPrint('CategoriesScreen: Search query: "$_searchQuery"');
          debugPrint(
            'CategoriesScreen: Selected category ID: $_selectedCategoryId',
          );
          return _buildEmptyState();
        }

        debugPrint('CategoriesScreen: Displaying ${books.length} books');

        return GridView.builder(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.7,
            crossAxisSpacing: AppDimensions.spacingM,
            mainAxisSpacing: AppDimensions.spacingM,
          ),
          itemCount: books.length,
          itemBuilder: (context, index) {
            final book = books[index];
            return _buildBookCard(book);
          },
        );
      },
    );
  }

  Widget _buildBookCard(Book book) {
    return Card(
      child: InkWell(
        onTap: () => _navigateToBookDetail(book),
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book Cover
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppDimensions.radiusM),
                  ),
                  color: context.surfaceColor,
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppDimensions.radiusM),
                  ),
                  child: book.primaryImageUrl != null
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
                ),
              ),
            ),

            // Book Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingS),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: TextStyle(
                        fontSize: AppDimensions.fontSizeS,
                        fontWeight: FontWeight.w600,
                        color: context.textColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Text(
                          book.author?.name ?? localizations.unknownAuthor,
                          style: TextStyle(
                            fontSize: AppDimensions.fontSizeXS,
                            color: context.secondaryTextColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$${book.priceAsDouble.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: AppDimensions.fontSizeS,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        if (book.averageRating != null)
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                size: 12,
                                color: AppColors.warning,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                book.averageRating!.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: AppDimensions.fontSizeXS,
                                  color: context.secondaryTextColor,
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
        child: Icon(Icons.book_outlined, size: 40, color: AppColors.primary),
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
              Icons.search_off,
              size: 80,
              color: context.secondaryTextColor.withValues(alpha: 128),
            ),
            const SizedBox(height: AppDimensions.spacingL),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Column(
                  children: [
                    Text(
                      localizations.noBooksFoundCategory,
                      style: TextStyle(
                        fontSize: AppDimensions.fontSizeL,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingM),
                    Text(
                      _searchQuery.isNotEmpty
                          ? localizations.noBooksMatchSearch(_searchQuery)
                          : _selectedCategoryId != null
                          ? localizations.noBooksInCategory
                          : localizations.noBooksAvailable,
                      style: TextStyle(
                        fontSize: AppDimensions.fontSizeM,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
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

  void _navigateToBookDetail(Book book) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BookDetailScreen(book: book)),
    );
  }
}

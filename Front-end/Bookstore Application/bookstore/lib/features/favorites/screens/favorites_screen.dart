import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/extensions/theme_extensions.dart';
import '../../../core/widgets/common/loading_indicator.dart';
import '../../../core/localization/app_localizations.dart';
import '../../books/models/book.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/favorites_provider.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFavoritesFromServer();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFavoritesFromServer() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final favoritesProvider = Provider.of<FavoritesProvider>(
      context,
      listen: false,
    );

    if (authProvider.token != null) {
      debugPrint('FavoritesScreen: Loading favorites from server...');
      await favoritesProvider.loadFavoritesFromServer(authProvider.token!);
    } else {
      debugPrint(
        'FavoritesScreen: No auth token available, using local favorites only',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.myFavorites),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              Provider.of<FavoritesProvider>(
                context,
                listen: false,
              ).sortFavorites(value); //
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'date_added',
                child: Text('Date Added'),
              ),
              const PopupMenuItem(value: 'title', child: Text('Title')),
              const PopupMenuItem(value: 'author', child: Text('Author')),
              const PopupMenuItem(value: 'price', child: Text('Price')),
            ],
            icon: const Icon(Icons.sort),
          ),
        ],
      ),
      body: Consumer<FavoritesProvider>(
        builder: (context, favoritesProvider, child) {
          if (favoritesProvider.isLoading) {
            return const Center(child: LoadingIndicator());
          }

          if (favoritesProvider.isEmpty) {
            return _buildEmptyFavorites();
          }

          final filteredFavorites = _searchQuery.isEmpty
              ? favoritesProvider.favorites
              : favoritesProvider.searchFavorites(_searchQuery);

          return Column(
            children: [
              _buildSearchBar(favoritesProvider),
              Expanded(
                child: filteredFavorites.isEmpty
                    ? _buildNoResults()
                    : _buildFavoritesList(filteredFavorites, favoritesProvider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyFavorites() {
    final localizations = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_outline,
              size: 100,
              color: context.secondaryTextColor.withValues(alpha: 128),
            ),
            const SizedBox(height: AppDimensions.spacingL),
            Text(
              localizations.emptyFavorites,
              style: TextStyle(
                fontSize: AppDimensions.fontSizeXL,
                fontWeight: FontWeight.w600,
                color: context.textColor,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Text(
              localizations.emptyFavoritesDescription,
              style: TextStyle(
                fontSize: AppDimensions.fontSizeM,
                color: context.secondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingXL),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/home'),
              child: const Text('Browse Books'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(FavoritesProvider favoritesProvider) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).searchFavorites,
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
          ),
          const SizedBox(width: AppDimensions.spacingM),
          Container(
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusM),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: IconButton(
              onPressed: () => _showClearAllDialog(favoritesProvider),
              icon: const Icon(
                Icons.clear_all,
                color: AppColors.error,
                size: 20,
              ),
              tooltip: 'Clear All Favorites',
              padding: const EdgeInsets.all(8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
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
            Text(
              'No results found',
              style: TextStyle(
                fontSize: AppDimensions.fontSizeL,
                fontWeight: FontWeight.w600,
                color: context.textColor,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Text(
              'No favorites match "$_searchQuery"',
              style: TextStyle(
                fontSize: AppDimensions.fontSizeM,
                color: context.secondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesList(
    List<Book> favorites,
    FavoritesProvider favoritesProvider,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final book = favorites[index];
        return _buildFavoriteItem(book, favoritesProvider);
      },
    );
  }

  Widget _buildFavoriteItem(Book book, FavoritesProvider favoritesProvider) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingM),
      child: InkWell(
        onTap: () => _navigateToBookDetail(book),
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Book Cover
              Container(
                width: 80,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                  color: context.surfaceColor,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusS),
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
              const SizedBox(width: AppDimensions.spacingM),

              // Book Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: TextStyle(
                        fontSize: AppDimensions.fontSizeM,
                        fontWeight: FontWeight.w600,
                        color: context.textColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppDimensions.spacingS),
                    Text(
                      'by ${book.author?.name ?? 'Unknown Author'}',
                      style: TextStyle(
                        fontSize: AppDimensions.fontSizeS,
                        color: context.secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingS),

                    // Rating
                    if (book.averageRating != null)
                      Row(
                        children: [
                          ...List.generate(5, (index) {
                            return Icon(
                              index < (book.averageRating ?? 0).floor()
                                  ? Icons.star
                                  : index < (book.averageRating ?? 0)
                                  ? Icons.star_half
                                  : Icons.star_border,
                              color: AppColors.warning,
                              size: 16,
                            );
                          }),
                          const SizedBox(width: AppDimensions.spacingS),
                          Text(
                            book.averageRating?.toStringAsFixed(1) ?? '0.0',
                            style: TextStyle(
                              fontSize: AppDimensions.fontSizeS,
                              color: context.secondaryTextColor,
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: AppDimensions.spacingS),

                    // Price
                    Row(
                      children: [
                        if (book.discountPrice != null &&
                            book.discountPrice! < book.priceAsDouble) ...[
                          Text(
                            '\$${book.priceAsDouble.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: AppDimensions.fontSizeS,
                              color: context.secondaryTextColor,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spacingS),
                          Text(
                            '\$${book.discountPrice!.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: AppDimensions.fontSizeM,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ] else ...[
                          Text(
                            '\$${book.priceAsDouble.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: AppDimensions.fontSizeM,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              Column(
                children: [
                  IconButton(
                    onPressed: () =>
                        _removeFromFavorites(book, favoritesProvider),
                    icon: const Icon(Icons.favorite, color: AppColors.error),
                    tooltip: 'Remove from favorites',
                  ),
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return IconButton(
                        onPressed: () => _addToCart(book),
                        icon: const Icon(
                          Icons.add_shopping_cart,
                          color: AppColors.primary,
                        ),
                        tooltip: localizations.addToCartButton,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultBookCover() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
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

  void _navigateToBookDetail(Book book) {
    Navigator.pushNamed(
      context,
      '/book-detail',
      arguments: {'bookId': book.id, 'book': book},
    );
  }

  void _removeFromFavorites(
    Book book,
    FavoritesProvider favoritesProvider,
  ) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Favorites'),
        content: Text('Remove "${book.title}" from your favorites?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                final authProvider = Provider.of<AuthProvider>(
                  context,
                  listen: false,
                );
                if (authProvider.token != null) {
                  await favoritesProvider.removeFromFavoritesWithAuth(
                    book.id.toString(),
                    authProvider.token!,
                  );
                } else {
                  await favoritesProvider.removeFromFavorites(
                    book.id.toString(),
                  );
                }

                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text('${book.title} removed from favorites'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: Text('Remove', style: TextStyle(color: context.errorColor)),
          ),
        ],
      ),
    );
  }

  void _addToCart(Book book) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${book.title} added to cart'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _showClearAllDialog(FavoritesProvider favoritesProvider) {
    final localizations = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.clearAllFavorites),
        content: Text(localizations.confirmClearFavorites),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              favoritesProvider.clearFavorites();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(localizations.favoritesCleared),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: Text(
              localizations.clearAll,
              style: TextStyle(color: context.errorColor),
            ),
          ),
        ],
      ),
    );
  }
}

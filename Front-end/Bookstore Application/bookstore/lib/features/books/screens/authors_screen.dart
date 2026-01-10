import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../providers/authors_provider.dart';
import '../providers/books_provider.dart';
import '../models/author.dart';
import '../models/book.dart';
import 'book_detail_screen.dart';

class AuthorsScreen extends StatefulWidget {
  const AuthorsScreen({super.key});

  @override
  State<AuthorsScreen> createState() => _AuthorsScreenState();
}

class _AuthorsScreenState extends State<AuthorsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _bookSearchController = TextEditingController();
  String _searchQuery = '';
  String _bookSearchQuery = '';
  Author? _selectedAuthor;
  List<Book> _authorBooks = [];
  bool _isLoadingBooks = false;

  @override
  void initState() {
    super.initState();
    _loadAuthors();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bookSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadAuthors() async {
    final authorsProvider = Provider.of<AuthorsProvider>(
      context,
      listen: false,
    );
    await authorsProvider.getAuthors();
  }

  Future<void> _loadBooksByAuthor(Author author) async {
    setState(() {
      _isLoadingBooks = true;
      _selectedAuthor = author;
    });

    try {
      final booksProvider = Provider.of<BooksProvider>(context, listen: false);
      final books = await booksProvider.getBooksByAuthor(author.id!);
      setState(() {
        _authorBooks = books;
        _isLoadingBooks = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingBooks = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading books: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedAuthor = null;
      _authorBooks = [];
      _bookSearchQuery = '';
      _bookSearchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Text(
              _selectedAuthor != null
                  ? localizations.booksByAuthor(_selectedAuthor!.name)
                  : localizations.browseByAuthor,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: 0.5,
              ),
            );
          },
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        shadowColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withValues(alpha: 204),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: _selectedAuthor != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _clearSelection,
              )
            : null,
        actions: [
          if (_selectedAuthor != null)
            Container(
              margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => _showSearchDialog(),
              ),
            ),
        ],
      ),
      body: _selectedAuthor == null ? _buildAuthorsList() : _buildBooksList(),
    );
  }

  Widget _buildAuthorsList() {
    return Consumer<AuthorsProvider>(
      builder: (context, authorsProvider, child) {
        if (authorsProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          );
        }

        if (authorsProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppColors.error.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Column(
                      children: [
                        Text(
                          localizations.errorLoadingAuthors,
                          style: const TextStyle(
                            fontSize: AppDimensions.fontSizeL,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          authorsProvider.error!,
                          style: const TextStyle(
                            fontSize: AppDimensions.fontSizeM,
                            color: AppColors.textHint,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadAuthors,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.white,
                          ),
                          child: Text(localizations.retry),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        }

        final authors = authorsProvider.authors;

        if (authors.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_outline,
                  size: 64,
                  color: AppColors.textHint.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Column(
                      children: [
                        Text(
                          localizations.noAuthorsFound,
                          style: const TextStyle(
                            fontSize: AppDimensions.fontSizeL,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          localizations.authorsWillAppearHere,
                          style: const TextStyle(
                            fontSize: AppDimensions.fontSizeM,
                            color: AppColors.textHint,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Search Bar
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.white,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(
                    context,
                  ).searchAuthorsPlaceholder,
                  hintStyle: const TextStyle(color: AppColors.textHint),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.textHint,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: AppColors.textHint,
                          ),
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
                    borderSide: BorderSide(
                      color: AppColors.textHint.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.textHint.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),

            // Authors List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _getFilteredAuthors(authors).length,
                itemBuilder: (context, index) {
                  final author = _getFilteredAuthors(authors)[index];
                  return _buildAuthorCard(author);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBooksList() {
    return Column(
      children: [
        // Author Info Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withValues(alpha: 0.1),
                AppColors.secondary.withValues(alpha: 0.1),
              ],
            ),
          ),
          child: Row(
            children: [
              // Author Photo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: AppColors.secondaryGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.thistle.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Container(
                  margin: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.white,
                  ),
                  child: ClipOval(
                    child: _selectedAuthor!.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: _selectedAuthor!.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: AppColors.textHint,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.primary,
                                  ),
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: AppColors.textHint,
                              child: const Icon(
                                Icons.person,
                                color: AppColors.primary,
                                size: 32,
                              ),
                            ),
                          )
                        : Container(
                            color: AppColors.textHint,
                            child: const Icon(
                              Icons.person,
                              color: AppColors.primary,
                              size: 32,
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Author Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedAuthor!.name,
                      style: const TextStyle(
                        fontSize: AppDimensions.fontSizeXL,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (_selectedAuthor!.biography != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _selectedAuthor!.biography!,
                        style: const TextStyle(
                          fontSize: AppDimensions.fontSizeM,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '${_authorBooks.length} books available',
                      style: const TextStyle(
                        fontSize: AppDimensions.fontSizeS,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Book Search Bar
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.white,
          child: TextField(
            controller: _bookSearchController,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(
                context,
              ).searchBooksByAuthor(_selectedAuthor!.name),
              hintStyle: const TextStyle(color: AppColors.textHint),
              prefixIcon: const Icon(Icons.search, color: AppColors.textHint),
              suffixIcon: _bookSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.textHint),
                      onPressed: () {
                        _bookSearchController.clear();
                        setState(() {
                          _bookSearchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.textHint.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.textHint.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              filled: true,
              fillColor: AppColors.background,
            ),
            onChanged: (value) {
              setState(() {
                _bookSearchQuery = value;
              });
            },
          ),
        ),

        // Books List
        Expanded(
          child: _isLoadingBooks
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                )
              : _getFilteredBooks().isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.book_outlined,
                        size: 64,
                        color: AppColors.textHint.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No books found',
                        style: TextStyle(
                          fontSize: AppDimensions.fontSizeL,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _bookSearchQuery.isNotEmpty
                            ? 'No books match "$_bookSearchQuery"'
                            : 'This author doesn\'t have any books available yet.',
                        style: const TextStyle(
                          fontSize: AppDimensions.fontSizeM,
                          color: AppColors.textHint,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _getFilteredBooks().length,
                  itemBuilder: (context, index) {
                    final book = _getFilteredBooks()[index];
                    return _buildBookCard(book);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAuthorCard(Author author) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _loadBooksByAuthor(author),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Author Photo
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: AppColors.secondaryGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.thistle.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.white,
                    ),
                    child: ClipOval(
                      child: author.imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: author.imageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: AppColors.textHint,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primary,
                                    ),
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: AppColors.textHint,
                                child: const Icon(
                                  Icons.person,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                              ),
                            )
                          : Container(
                              color: AppColors.textHint,
                              child: const Icon(
                                Icons.person,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Author Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        author.name,
                        style: const TextStyle(
                          fontSize: AppDimensions.fontSizeL,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (author.biography != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          author.biography!,
                          style: const TextStyle(
                            fontSize: AppDimensions.fontSizeM,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Icon(
                            Icons.book_outlined,
                            size: 16,
                            color: AppColors.textHint,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'View books',
                            style: TextStyle(
                              fontSize: AppDimensions.fontSizeS,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Spacer(),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: AppColors.textHint,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookCard(Book book) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BookDetailScreen(book: book),
            ),
          ),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Book Cover
                Container(
                  width: 60,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      colors: AppColors.secondaryGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.thistle.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: AppColors.white,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: book.primaryImageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: book.primaryImageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: AppColors.textHint,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primary,
                                    ),
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: AppColors.textHint,
                                child: const Icon(
                                  Icons.book,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                              ),
                            )
                          : Container(
                              color: AppColors.textHint,
                              child: const Icon(
                                Icons.book,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Book Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        style: const TextStyle(
                          fontSize: AppDimensions.fontSizeL,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        book.description ?? 'No description available',
                        style: const TextStyle(
                          fontSize: AppDimensions.fontSizeM,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (book.price != null) ...[
                            Text(
                              '\$${book.price!}',
                              style: const TextStyle(
                                fontSize: AppDimensions.fontSizeM,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: (book.isAvailable ?? false)
                                  ? AppColors.success.withValues(alpha: 0.1)
                                  : AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Builder(
                              builder: (context) {
                                final localizations = AppLocalizations.of(
                                  context,
                                );
                                return Text(
                                  (book.isAvailable ?? false)
                                      ? localizations.availableStatus
                                      : localizations.unavailableStatus,
                                  style: TextStyle(
                                    fontSize: AppDimensions.fontSizeS,
                                    color: (book.isAvailable ?? false)
                                        ? AppColors.success
                                        : AppColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Arrow
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppColors.textHint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Author> _getFilteredAuthors(List<Author> authors) {
    if (_searchQuery.isEmpty) {
      return authors;
    }
    return authors
        .where(
          (author) =>
              author.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (author.biography != null &&
                  author.biography!.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  )),
        )
        .toList();
  }

  List<Book> _getFilteredBooks() {
    if (_bookSearchQuery.isEmpty) {
      return _authorBooks;
    }
    return _authorBooks
        .where(
          (book) =>
              book.title.toLowerCase().contains(
                _bookSearchQuery.toLowerCase(),
              ) ||
              (book.description != null &&
                  book.description!.toLowerCase().contains(
                    _bookSearchQuery.toLowerCase(),
                  )),
        )
        .toList();
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final localizations = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(localizations.searchBooks),
          content: TextField(
            decoration: InputDecoration(
              hintText: localizations.searchInBooksByAuthor(
                _selectedAuthor!.name,
              ),
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              // Implement book search functionality
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(localizations.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(localizations.search),
            ),
          ],
        );
      },
    );
  }
}

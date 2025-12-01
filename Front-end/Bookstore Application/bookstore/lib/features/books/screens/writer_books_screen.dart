import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/common/error_message.dart';
import '../../../core/widgets/common/loading_indicator.dart';
import '../providers/books_provider.dart';
import '../models/book.dart';

class WriterBooksScreen extends StatefulWidget {
  final int? writerId;
  final String? writerName;

  const WriterBooksScreen({super.key, this.writerId, this.writerName});

  @override
  State<WriterBooksScreen> createState() => _WriterBooksScreenState();
}

class _WriterBooksScreenState extends State<WriterBooksScreen> {
  List<Book> _books = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All'; // New filter state

  @override
  void initState() {
    super.initState();
    _loadWriterBooks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadWriterBooks() async {
    if (widget.writerId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final booksProvider = Provider.of<BooksProvider>(context, listen: false);

      // Load books by author using the existing method
      _books = await booksProvider.getBooksByAuthor(widget.writerId!);
      debugPrint(
        'WriterBooksScreen: Loaded ${_books.length} books for writer ${widget.writerId}',
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
      debugPrint('Error loading writer books: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.writerName ?? 'Writer Books'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        actions: [
          IconButton(
            onPressed: () {
              _loadWriterBooks();
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
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: LoadingIndicator());
    }

    if (_error != null) {
      return ErrorMessage(message: _error!, onRetry: () => _loadWriterBooks());
    }

    if (_getFilteredBooks().isEmpty) {
      return _buildEmptyState();
    }

    return _buildBooksList();
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Search books...',
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
          _buildFilterChip('All'),
          const SizedBox(width: 8),
          _buildFilterChip('New Books'),
          const SizedBox(width: 8),
          _buildFilterChip('Highest Rated'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = label;
        });
      },
      selectedColor: AppColors.uranianBlue.withValues(alpha: 0.2),
      checkmarkColor: AppColors.uranianBlue,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.uranianBlue : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  List<Book> _getFilteredBooks() {
    List<Book> filteredBooks = List.from(_books);

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filteredBooks = filteredBooks
          .where(
            (book) =>
                book.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (book.author?.name != null &&
                    book.author!.name.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    )),
          )
          .toList();
    }

    // Apply filter based on selected filter
    if (_selectedFilter == 'New Books') {
      // Sort by creation date (assuming newer books have higher IDs)
      filteredBooks.sort((a, b) => b.id.compareTo(a.id));
    } else if (_selectedFilter == 'Highest Rated') {
      // Filter books with ratings and sort by rating
      filteredBooks = filteredBooks
          .where((book) => book.averageRating != null)
          .toList();
      filteredBooks.sort(
        (a, b) => (b.averageRating ?? 0).compareTo(a.averageRating ?? 0),
      );
    }
    // 'All' filter doesn't need additional sorting

    return filteredBooks;
  }

  Widget _buildBooksList() {
    final filteredBooks = _getFilteredBooks();
    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      itemCount: filteredBooks.length,
      itemBuilder: (context, index) {
        final book = filteredBooks[index];
        return _buildBookCard(book);
      },
    );
  }

  Widget _buildBookCard(Book book) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingM),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/book-detail',
            arguments: {'book': book},
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          child: Row(
            children: [
              // Book Cover
              Container(
                width: 80,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.uranianBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: book.primaryImageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          book.primaryImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.book,
                              size: 40,
                              color: AppColors.uranianBlue,
                            );
                          },
                        ),
                      )
                    : const Icon(
                        Icons.book,
                        size: 40,
                        color: AppColors.uranianBlue,
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
                        fontSize: AppDimensions.fontSizeL,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    if (book.author != null)
                      Text(
                        'by ${book.author!.name}',
                        style: TextStyle(
                          fontSize: AppDimensions.fontSizeM,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        if (book.price != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '\$${book.price}',
                              style: const TextStyle(
                                fontSize: AppDimensions.fontSizeS,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success,
                              ),
                            ),
                          ),

                        const SizedBox(width: 8),

                        if (book.borrowPrice != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.uranianBlue.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Borrow: \$${book.borrowPrice}',
                              style: const TextStyle(
                                fontSize: AppDimensions.fontSizeS,
                                fontWeight: FontWeight.w600,
                                color: AppColors.uranianBlue,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        if (book.isAvailable == true)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Available',
                              style: TextStyle(
                                fontSize: AppDimensions.fontSizeS,
                                fontWeight: FontWeight.w500,
                                color: AppColors.success,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Unavailable',
                              style: TextStyle(
                                fontSize: AppDimensions.fontSizeS,
                                fontWeight: FontWeight.w500,
                                color: AppColors.error,
                              ),
                            ),
                          ),

                        const Spacer(),

                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Theme.of(context).textTheme.bodySmall?.color,
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
              Icons.book_outlined,
              size: 80,
              color: AppColors.textHint.withValues(alpha: 128),
            ),
            const SizedBox(height: AppDimensions.spacingL),
            Text(
              'No books found',
              style: TextStyle(
                fontSize: AppDimensions.fontSizeL,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No books match "$_searchQuery"'
                  : _selectedFilter != 'All'
                  ? 'No books match the selected filter'
                  : '${widget.writerName ?? 'This writer'} has no books available at the moment',
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
}

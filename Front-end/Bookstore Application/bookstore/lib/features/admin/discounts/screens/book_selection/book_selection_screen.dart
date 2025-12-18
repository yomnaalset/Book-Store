import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/book_discount.dart';
import '../../../services/manager_api_service.dart';
import '../../../../auth/providers/auth_provider.dart';
import '../../../../../core/services/api_config.dart';
import '../../../../../core/localization/app_localizations.dart';
import 'package:provider/provider.dart';

class BookSelectionScreen extends StatefulWidget {
  final Function(AvailableBook) onBookSelected;

  const BookSelectionScreen({super.key, required this.onBookSelected});

  @override
  State<BookSelectionScreen> createState() => _BookSelectionScreenState();
}

class _BookSelectionScreenState extends State<BookSelectionScreen> {
  List<AvailableBook> _books = [];
  List<AvailableBook> _filteredBooks = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final apiService = ManagerApiService(
        baseUrl: ApiConfig.getBaseUrl(),
        headers: {},
        getAuthToken: () => authProvider.token ?? '',
      );

      if (authProvider.token != null) {
        apiService.setToken(authProvider.token);
      }

      final books = await apiService.fetchAvailableBooks();

      setState(() {
        _books = books;
        _filteredBooks = books;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterBooks() {
    setState(() {
      _filteredBooks = _books.where((book) {
        final matchesSearch =
            _searchQuery.isEmpty ||
            book.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            book.authorName.toLowerCase().contains(_searchQuery.toLowerCase());

        final matchesCategory =
            _selectedCategory == 'all' ||
            book.categoryName.toLowerCase() == _selectedCategory.toLowerCase();

        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _filterBooks();
  }

  void _onCategoryChanged(String? category) {
    setState(() {
      _selectedCategory = category ?? 'all';
    });
    _filterBooks();
  }

  List<String> _getCategories() {
    final categories = _books.map((book) => book.categoryName).toSet().toList();
    categories.sort();
    return ['all', ...categories];
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.selectBook),
        actions: [
          IconButton(onPressed: _loadBooks, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  decoration: InputDecoration(
                    labelText: localizations.searchBooksPlaceholder,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: _onSearchChanged,
                ),
                const SizedBox(height: 16),

                // Category Filter
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: localizations.category,
                    border: const OutlineInputBorder(),
                  ),
                  items: _getCategories().map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(
                        category == 'all'
                            ? localizations.allCategories
                            : category,
                      ),
                    );
                  }).toList(),
                  onChanged: _onCategoryChanged,
                ),
              ],
            ),
          ),

          // Books List
          Expanded(child: _buildBooksList()),
        ],
      ),
    );
  }

  Widget _buildBooksList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Error: $_error',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadBooks, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_filteredBooks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No books found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Try adjusting your search or filter',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: _filteredBooks.length,
      itemBuilder: (context, index) {
        final book = _filteredBooks[index];
        return _buildBookCard(book);
      },
    );
  }

  Widget _buildBookCard(AvailableBook book) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () {
          widget.onBookSelected(book);
          Navigator.pop(context);
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Book Thumbnail
              Container(
                width: 80,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[200],
                ),
                child: book.thumbnail != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: book.thumbnail!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.book,
                            size: 40,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : const Icon(Icons.book, size: 40, color: Colors.grey),
              ),
              const SizedBox(width: 16),

              // Book Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Book Name
                    Text(
                      book.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Author
                    Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Text(
                          localizations.byAuthor(book.authorName),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                    const SizedBox(height: 4),

                    // Category
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        book.categoryName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Price and Status
                    Row(
                      children: [
                        if (book.price != null) ...[
                          Text(
                            '\$${book.price!.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (book.hasActiveDiscount)
                          Builder(
                            builder: (context) {
                              final localizations = AppLocalizations.of(
                                context,
                              );
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  localizations.hasDiscount,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Select Button
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

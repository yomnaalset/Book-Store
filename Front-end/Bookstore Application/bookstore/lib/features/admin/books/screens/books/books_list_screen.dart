import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/library_manager/books_provider.dart';
import '../../../providers/categories_provider.dart';
import '../../../providers/library_manager/authors_provider.dart';
import '../../../models/book.dart';
import '../../../widgets/library_manager/admin_search_bar.dart';
import '../../../widgets/library_manager/empty_state.dart';
import '../../../../auth/providers/auth_provider.dart';
import '../../../../../../routes/app_routes.dart';
import '../../../../../../core/constants/app_colors.dart' as app_colors;

class BooksListScreen extends StatefulWidget {
  const BooksListScreen({super.key});

  @override
  State<BooksListScreen> createState() => _BooksListScreenState();
}

class _BooksListScreenState extends State<BooksListScreen> {
  String? _searchQuery;
  String? _selectedStatus;
  String? _selectedCategory;
  String? _selectedAuthor;
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBooks();
      _loadCategories();
      _loadAuthors();
    });
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBooks() async {
    final provider = context.read<BooksProvider>();
    final authProvider = context.read<AuthProvider>();

    // Ensure provider has the current token
    if (authProvider.token != null) {
      provider.setToken(authProvider.token);
      debugPrint(
        'DEBUG: Books list - Updated provider with token: ${authProvider.token!.substring(0, 20)}...',
      );
    } else {
      debugPrint('DEBUG: Books list - No token available from AuthProvider');
      // Don't proceed with loading if no token
      return;
    }

    await provider.loadBooks(
      search: _searchQuery?.isEmpty ?? true ? null : _searchQuery,
      category: _selectedCategory,
      author: _selectedAuthor,
      status: _selectedStatus,
    );
  }

  Future<void> _loadCategories() async {
    final categoriesProvider = context.read<CategoriesProvider>();
    final authProvider = context.read<AuthProvider>();

    // Ensure provider has the current token
    if (authProvider.token != null) {
      categoriesProvider.setToken(authProvider.token);
      debugPrint(
        'DEBUG: Books list - Updated categories provider with token: ${authProvider.token!.substring(0, 20)}...',
      );
      await categoriesProvider.getCategories();
    } else {
      debugPrint('DEBUG: Books list - No token available for categories');
    }
  }

  Future<void> _loadAuthors() async {
    final authorsProvider = context.read<AuthorsProvider>();
    final authProvider = context.read<AuthProvider>();

    // Ensure provider has the current token
    if (authProvider.token != null) {
      authorsProvider.setToken(authProvider.token);
      debugPrint(
        'DEBUG: Books list - Updated authors provider with token: ${authProvider.token!.substring(0, 20)}...',
      );
      await authorsProvider.loadAuthors();
    } else {
      debugPrint('DEBUG: Books list - No token available for authors');
    }
  }

  void _onFilterChanged(String? status) {
    setState(() {
      _selectedStatus = status;
    });
    _loadBooks();
  }

  void _onCategoryFilterChanged(String? category) {
    setState(() {
      _selectedCategory = category;
    });
    _loadBooks();
  }

  void _onAuthorFilterChanged(String? author) {
    setState(() {
      _selectedAuthor = author;
    });
    _loadBooks();
  }

  void _navigateToBookForm([Book? book]) {
    // Use different routes for create vs edit
    final routeName = book != null
        ? AppRoutes
              .libraryBookForm // For editing existing book
        : AppRoutes.managerBooksCreate; // For creating new book

    Navigator.pushNamed(
      context,
      routeName,
      arguments: book != null ? {'book': book} : null,
    ).then((_) => _loadBooks());
  }

  void _navigateToBookDetails(Book book) {
    Navigator.pushNamed(context, AppRoutes.managerBookDetails, arguments: book);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Books'),
        actions: [
          IconButton(
            onPressed: () => _loadBooks(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: AdminSearchBar(
              hintText: 'Search books...',
              onChanged: (query) {
                // Cancel previous timer
                _searchDebounceTimer?.cancel();

                // Set new timer for debounced search
                _searchDebounceTimer = Timer(
                  const Duration(milliseconds: 500),
                  () {
                    setState(() {
                      _searchQuery = query.isEmpty ? null : query;
                    });
                    _loadBooks();
                  },
                );
              },
              onSubmitted: (query) {
                setState(() {
                  _searchQuery = query.isEmpty ? null : query;
                });
                _loadBooks();
              },
            ),
          ),

          // Filters
          Consumer<BooksProvider>(
            builder: (context, provider, child) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    // First row - Status and Category
                    Row(
                      children: [
                        // Status Filter
                        Expanded(
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 60),
                            child: DropdownButtonFormField<String>(
                              // ignore: deprecated_member_use
                              value: _selectedStatus,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Status',
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.always,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surface,
                                labelStyle: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: null,
                                  child: Text(
                                    'All Statuses',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'available',
                                  child: Text(
                                    'Available',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'unavailable',
                                  child: Text(
                                    'Unavailable',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'borrowed',
                                  child: Text(
                                    'Borrowed',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (value) => _onFilterChanged(value),
                              dropdownColor: Theme.of(context).colorScheme.surface,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Category Filter
                        Expanded(
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 60),
                            child: Consumer<CategoriesProvider>(
                              builder: (context, categoriesProvider, child) {
                                return DropdownButtonFormField<String>(
                                  // ignore: deprecated_member_use
                                  value: _selectedCategory,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: 'Category',
                                    floatingLabelBehavior:
                                        FloatingLabelBehavior.always,
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(context).colorScheme.surface,
                                    labelStyle: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: null,
                                      child: Text(
                                        'All Categories',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Theme.of(context).colorScheme.onSurface,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    ...categoriesProvider.categories
                                        .where((category) => category.isActive)
                                        .map((category) {
                                          return DropdownMenuItem(
                                            value: category.id,
                                            child: Text(
                                              category.name,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Theme.of(context).colorScheme.onSurface,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          );
                                        }),
                                  ],
                                  onChanged: (value) =>
                                      _onCategoryFilterChanged(value),
                                  dropdownColor: Theme.of(context).colorScheme.surface,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Second row - Author Filter (full width)
                    Row(
                      children: [
                        // Author Filter
                        Expanded(
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 60),
                            child: Consumer<AuthorsProvider>(
                              builder: (context, authorsProvider, child) {
                                return DropdownButtonFormField<String>(
                                  // ignore: deprecated_member_use
                                  value: _selectedAuthor,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: 'Author',
                                    floatingLabelBehavior:
                                        FloatingLabelBehavior.always,
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(context).colorScheme.surface,
                                    labelStyle: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: null,
                                      child: Text(
                                        'All Authors',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Theme.of(context).colorScheme.onSurface,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    ...authorsProvider.authors
                                        .where((author) => author.isActive)
                                        .map((author) {
                                          return DropdownMenuItem(
                                            value: author.id,
                                            child: Text(
                                              author.name,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Theme.of(context).colorScheme.onSurface,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          );
                                        }),
                                  ],
                                  onChanged: (value) =>
                                      _onAuthorFilterChanged(value),
                                  dropdownColor: Theme.of(context).colorScheme.surface,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Books List
          Expanded(
            child: Consumer<BooksProvider>(
              builder: (context, provider, child) {
                debugPrint(
                  'DEBUG: Books list - isLoading: ${provider.isLoading}, books count: ${provider.books.length}, error: ${provider.error}',
                );

                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.error != null && provider.books.isEmpty) {
                  // Check if it's an authentication error
                  final isAuthError =
                      provider.error!.contains('Authentication required') ||
                      provider.error!.contains('401') ||
                      provider.error!.contains('token');

                  // Check if it's a "no library found" error (which is a valid state)
                  final isNoLibraryError = provider.error!.contains(
                    'NO_LIBRARY_FOUND',
                  );

                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isAuthError
                              ? Icons.lock
                              : isNoLibraryError
                              ? Icons.library_books
                              : Icons.error,
                          size: 64,
                          color: isNoLibraryError
                              ? app_colors.AppColors.primary
                              : Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isAuthError
                              ? 'Authentication Required'
                              : isNoLibraryError
                              ? 'No Library Found'
                              : 'Error: ${provider.error}',
                          style: TextStyle(
                            color: isNoLibraryError
                                ? app_colors.AppColors.primary
                                : Theme.of(context).colorScheme.error,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (isAuthError) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Please log in to access books management.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (isNoLibraryError) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Create a library first to manage books',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 16),
                        if (isNoLibraryError)
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.managerLibraryForm,
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Create Library'),
                          )
                        else
                          ElevatedButton(
                            onPressed: () {
                              if (isAuthError) {
                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  AppRoutes.login,
                                  (route) => false,
                                );
                              } else {
                                _loadBooks();
                              }
                            },
                            child: Text(isAuthError ? 'Go to Login' : 'Retry'),
                          ),
                      ],
                    ),
                  );
                }

                if (provider.books.isEmpty) {
                  return EmptyState(
                    title: 'No Books',
                    message: 'No books found',
                    icon: Icons.book,
                    actionText: 'Add Book',
                    onAction: () => _navigateToBookForm(),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: provider.books.length,
                  itemBuilder: (context, index) {
                    final book = provider.books[index];
                    return _buildBookCard(book);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToBookForm(),
        tooltip: 'Add Book',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBookCard(Book book) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.withValues(alpha: (0.1)),
          child: const Icon(Icons.book, color: Colors.orange),
        ),
        title: Text(
          book.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (book.author != null) ...[
              const SizedBox(height: 4),
              Text(
                'By: ${book.author!.name}',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (book.category != null) ...[
              const SizedBox(height: 4),
              Text(
                'Category: ${book.category!.name}',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: (0.1)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Copies: ${book.availableCopies}/${book.quantity ?? 0}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (book.description != null) ...[
              const SizedBox(height: 8),
              Text(
                book.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            // View Details Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _navigateToBookDetails(book),
                icon: const Icon(Icons.visibility, size: 16),
                label: const Text('View Details'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _navigateToBookForm(book);
                break;
              case 'delete':
                _deleteBook(book);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteBook(Book book) async {
    // Check user permissions first
    final authProvider = context.read<AuthProvider>();
    if (authProvider.userRole != 'library_admin') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only library administrators can delete books'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Book'),
        content: Text(
          'Are you sure you want to delete "${book.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (!mounted) return;
        final provider = context.read<BooksProvider>();
        await provider.deleteBook(int.parse(book.id));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Book deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Reload the books list
          _loadBooks();
        }
      } catch (e) {
        if (mounted) {
          String errorMessage = e.toString();
          if (errorMessage.contains('Permission denied') ||
              errorMessage.contains('403') ||
              errorMessage.contains('Unauthorized')) {
            errorMessage =
                'You do not have permission to delete books. Only library administrators can delete books.';
          } else if (errorMessage.contains('AUTHOR_HAS_BOOKS')) {
            errorMessage =
                'Cannot delete this book because it is associated with an author who has other books.';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $errorMessage'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }
}

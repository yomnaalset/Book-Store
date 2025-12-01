import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/book.dart';
import '../../../providers/library_manager/books_provider.dart';
import '../../../../../../routes/app_routes.dart';
import '../../../../reviews/widgets/reviews_list.dart';

class BookAdminDetailScreen extends StatefulWidget {
  const BookAdminDetailScreen({super.key});

  @override
  State<BookAdminDetailScreen> createState() => _BookAdminDetailScreenState();
}

class _BookAdminDetailScreenState extends State<BookAdminDetailScreen> {
  bool _isLoading = false;
  late Book _book;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Book) {
      _book = args;
    } else {
      // Handle case where no book is provided
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No book data provided')));
      });
    }
  }

  Future<void> _deleteBook() async {
    final booksProvider = Provider.of<BooksProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Book'),
        content: const Text(
          'Are you sure you want to delete this book? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await booksProvider.deleteBook(int.parse(_book.id));
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Book deleted successfully')),
          );
          navigator.pop(true);
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Error deleting book: ${e.toString()}')),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _editBook() {
    final booksProvider = Provider.of<BooksProvider>(context, listen: false);

    Navigator.pushNamed(
      context,
      AppRoutes.libraryBookForm,
      arguments: {'book': _book},
    ).then((result) {
      if (result == true) {
        // Refresh book data if edited
        setState(() {
          _isLoading = true;
        });

        booksProvider
            .loadBooks()
            .then((_) {
              final updatedBooks = booksProvider.books;
              final updatedBook = updatedBooks.firstWhere(
                (book) => book.id == _book.id,
              );
              if (mounted) {
                setState(() {
                  _book = updatedBook;
                  _isLoading = false;
                });
              }
            })
            .catchError((error) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error refreshing book: ${error.toString()}'),
                  ),
                );
                setState(() {
                  _isLoading = false;
                });
              }
            });
      }
    });
  }

  void _showReviews() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('Reviews for ${_book.title}'),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          body: ReviewsList(bookId: _book.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editBook,
            tooltip: 'Edit Book',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteBook,
            tooltip: 'Delete Book',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book Images
            if (_book.images != null && _book.images!.isNotEmpty)
              SizedBox(
                height: 200,
                child: PageView.builder(
                  itemCount: _book.images!.length,
                  itemBuilder: (context, index) {
                    return Image.network(
                      _book.images![index],
                      fit: BoxFit.contain,
                    );
                  },
                ),
              )
            else
              Container(
                height: 200,
                color: Colors.grey[300],
                child: const Center(
                  child: Icon(Icons.image_not_supported, size: 64),
                ),
              ),

            const SizedBox(height: 16),

            // Book Title
            Text(
              _book.title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            // Author and Categories
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'Author:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Text(_book.author?.name ?? ''),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.category, color: Colors.orange),
                        const SizedBox(width: 8),
                        const Text(
                          'Category:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_book.category?.name ?? 'Uncategorized'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Description
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_book.description ?? ''),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Pricing and Inventory
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pricing and Inventory',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Purchase Price',
                                style: TextStyle(color: Colors.grey),
                              ),
                              Text(
                                '\$${_book.price}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Borrow Price',
                                style: TextStyle(color: Colors.grey),
                              ),
                              Text(
                                '\$${_book.borrowPrice}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total Inventory',
                                style: TextStyle(color: Colors.grey),
                              ),
                              Text(
                                '${_book.quantity ?? 0}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Available Copies',
                                style: TextStyle(color: Colors.grey),
                              ),
                              Text(
                                '${_book.availableCopies}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Borrow Count',
                                style: TextStyle(color: Colors.grey),
                              ),
                              Text(
                                '${_book.borrowCount ?? 0}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Default Borrowing Period',
                                style: TextStyle(color: Colors.grey),
                              ),
                              Text(
                                '14 days', // This should come from your model
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Dates
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dates',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Created At',
                                style: TextStyle(color: Colors.grey),
                              ),
                              Text(
                                _formatDate(_book.createdAt),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Last Updated',
                                style: TextStyle(color: Colors.grey),
                              ),
                              Text(
                                _formatDate(_book.updatedAt),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Reviews Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showReviews,
                icon: const Icon(Icons.rate_review),
                label: const Text('View Reviews'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _editBook,
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Book'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _deleteBook,
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete Book'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }
}

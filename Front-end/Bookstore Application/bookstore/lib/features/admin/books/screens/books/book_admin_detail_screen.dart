import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/book.dart';
import '../../../providers/library_manager/books_provider.dart';
import '../../../../../../routes/app_routes.dart';
import '../../../../reviews/widgets/reviews_list.dart';
import '../../../../../../core/localization/app_localizations.dart';

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
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.noBookDataProvided)),
        );
      });
    }
  }

  Future<void> _deleteBook() async {
    final booksProvider = Provider.of<BooksProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final localizations = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.deleteBook),
        content: Text(localizations.areYouSureDeleteBook),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(localizations.delete),
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
          final localizations = AppLocalizations.of(context);
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text(localizations.bookDeletedSuccessfully)),
          );
          navigator.pop(true);
        }
      } catch (e) {
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(localizations.errorDeletingBook(e.toString())),
            ),
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
                final localizations = AppLocalizations.of(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      localizations.errorRefreshingBook(error.toString()),
                    ),
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
    final localizations = AppLocalizations.of(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(localizations.reviewsFor(_book.title)),
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

    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.bookDetails),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editBook,
            tooltip: localizations.editBook,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteBook,
            tooltip: localizations.deleteBook,
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
                    Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person, color: Colors.blue),
                                const SizedBox(width: 8),
                                Text(
                                  '${localizations.author}:',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(_book.author?.name ?? ''),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.category,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${localizations.category}:',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _book.category?.name ??
                                        localizations.uncategorized,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Description
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.description,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(_book.description ?? ''),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Pricing and Inventory
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.pricingAndInventory,
                          style: const TextStyle(
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
                                  Text(
                                    localizations.purchasePrice,
                                    style: const TextStyle(color: Colors.grey),
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
                                  Text(
                                    localizations.borrowPrice,
                                    style: const TextStyle(color: Colors.grey),
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
                                  Text(
                                    localizations.totalInventory,
                                    style: const TextStyle(color: Colors.grey),
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
                                  Text(
                                    localizations.availableCopies(
                                      _book.availableCopies ?? 0,
                                    ),
                                    style: const TextStyle(color: Colors.grey),
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
                                  Text(
                                    localizations.borrowCount,
                                    style: const TextStyle(color: Colors.grey),
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    localizations.defaultBorrowingPeriod,
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                  Text(
                                    '14 ${localizations.days}',
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
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Dates
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.dates,
                          style: const TextStyle(
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
                                  Text(
                                    localizations.createdAt,
                                    style: const TextStyle(color: Colors.grey),
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
                                  Text(
                                    localizations.lastUpdated,
                                    style: const TextStyle(color: Colors.grey),
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
                );
              },
            ),

            const SizedBox(height: 24),

            // Reviews Button
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showReviews,
                    icon: const Icon(Icons.rate_review),
                    label: Text(localizations.viewReviews),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _editBook,
                        icon: const Icon(Icons.edit),
                        label: Text(localizations.editBook),
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
                        label: Text(localizations.deleteBook),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                        ),
                      ),
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

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }
}

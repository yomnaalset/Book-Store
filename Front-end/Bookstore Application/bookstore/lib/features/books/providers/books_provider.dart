import 'package:flutter/foundation.dart';
import '../models/book.dart';
import '../services/books_service.dart';

class BooksProvider with ChangeNotifier {
  final BooksService _booksService;
  List<Book> _books = [];
  List<Book> _newBooks = [];
  List<Book> _mostBorrowedBooks = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  int _itemsPerPage = 10;

  BooksProvider(this._booksService);

  void setToken(String? token) {
    debugPrint(
      'DEBUG: BooksProvider setToken called with: ${token != null ? '${token.substring(0, 20)}...' : 'null'}',
    );

    // Only update if token has changed
    if (_booksService.token != token) {
      _booksService.setToken(token);
      debugPrint('DEBUG: BooksProvider token set successfully');
      // Notify listeners to trigger UI updates
      notifyListeners();
    } else {
      debugPrint('DEBUG: BooksProvider token unchanged, skipping update');
    }
  }

  Book? _selectedBook;

  List<Book> get books => _books;
  List<Book> get newBooks => _newBooks;
  List<Book> get mostBorrowedBooks => _mostBorrowedBooks;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;
  int get itemsPerPage => _itemsPerPage;
  Book? get selectedBook => _selectedBook;

  Future<void> getBooks({
    int page = 1,
    int limit = 10,
    String? search,
    int? categoryId,
    int? authorId,
    double? minRating,
    double? maxRating,
    double? minPrice,
    double? maxPrice,
    bool? availableToBorrow,
    bool? newOnly,
    String? sortBy,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _booksService.getBooks(
        page: page,
        limit: limit,
        search: search,
        categoryId: categoryId?.toString(),
        authorId: authorId?.toString(),
        minRating: minRating,
        maxRating: maxRating,
        minPrice: minPrice,
        maxPrice: maxPrice,
        availableToBorrow: availableToBorrow,
        newOnly: newOnly,
        sortBy: sortBy,
      );

      _books = result;
      _currentPage = page;
      _itemsPerPage = limit;
      _totalItems = result.length;
      _totalPages = (result.length / limit).ceil();

      debugPrint(
        'BooksProvider: Books loaded successfully - count: ${result.length}',
      );
      debugPrint('BooksProvider: Category ID: $categoryId');
      debugPrint('BooksProvider: Search query: $search');

      // Log details of each book
      for (int i = 0; i < result.length; i++) {
        final book = result[i];
        debugPrint(
          'BooksProvider: Book $i: "${book.title}" by ${book.author?.name ?? "Unknown"}',
        );
      }

      _isLoading = false;
      debugPrint(
        'BooksProvider: About to notify listeners with ${_books.length} books',
      );
      notifyListeners();
      debugPrint('BooksProvider: Listeners notified');
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<Book> getBookById(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final book = await _booksService.getBookById(id);
      _isLoading = false;
      notifyListeners();
      return book ?? Book.empty();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<Book> createBook(Book book) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final Map<String, dynamic> bookData = {
        'title': book.title,
        'description': book.description,
        'authorId': book.author?.id,
        'categoryId': book.category?.id,
        'price': book.price,
        'borrowPrice': book.borrowPrice,
        'availableCopies': book.availableCopies,
        'primaryImageUrl': book.primaryImageUrl,
        'additionalImages': book.additionalImages,
      };

      final newBook = await _booksService.createBook(bookData);
      if (newBook != null) {
        _books.add(newBook);
      }
      _isLoading = false;
      notifyListeners();
      return newBook ?? Book.empty();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<Book> updateBook(Book book) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final Map<String, dynamic> bookData = {
        'title': book.title,
        'description': book.description,
        'authorId': book.author?.id,
        'categoryId': book.category?.id,
        'price': book.price,
        'borrowPrice': book.borrowPrice,
        'availableCopies': book.availableCopies,
        'primaryImageUrl': book.primaryImageUrl,
        'additionalImages': book.additionalImages,
      };

      final updatedBook = await _booksService.updateBook(book.id, bookData);
      if (updatedBook != null) {
        _books.removeWhere((b) => b.id == book.id);
        _books.add(updatedBook);
      }

      _isLoading = false;
      notifyListeners();
      return updatedBook ?? Book.empty();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteBook(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _booksService.deleteBook(id.toString());
      _books.removeWhere((b) => b.id == id);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Add methods for special book lists
  Future<List<Book>> getNewBooks({int limit = 10}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('BooksProvider: Loading new books...');
      final books = await _booksService.getNewBooks(limit: limit);
      debugPrint('BooksProvider: New books loaded: ${books.length} books');
      _newBooks = books;
      _isLoading = false;
      notifyListeners();
      return books;
    } catch (e) {
      debugPrint('BooksProvider: Error loading new books: $e');
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  Future<List<Book>> getMostBorrowedBooks({int limit = 10}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('BooksProvider: Loading most borrowed books...');
      final books = await _booksService.getMostBorrowedBooks(limit: limit);
      debugPrint(
        'BooksProvider: Most borrowed books loaded: ${books.length} books',
      );
      _mostBorrowedBooks = books;
      _isLoading = false;
      notifyListeners();
      return books;
    } catch (e) {
      debugPrint('BooksProvider: Error loading most borrowed books: $e');
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  Future<List<Book>> getMostPopularBooks({int limit = 10}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('BooksProvider: Loading most popular books...');
      final books = await _booksService.getMostPopularBooks(limit: limit);
      debugPrint(
        'BooksProvider: Most popular books loaded: ${books.length} books',
      );
      _isLoading = false;
      notifyListeners();
      return books;
    } catch (e) {
      debugPrint('BooksProvider: Error loading most popular books: $e');
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  Future<List<Book>> getPurchasingBooks({int limit = 10}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('BooksProvider: Loading purchasing books...');
      final books = await _booksService.getPurchasingBooks(limit: limit);
      debugPrint(
        'BooksProvider: Purchasing books loaded: ${books.length} books',
      );
      _isLoading = false;
      notifyListeners();
      return books;
    } catch (e) {
      debugPrint('BooksProvider: Error loading purchasing books: $e');
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  Future<List<Book>> getTopRatedBooks({int limit = 10}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('BooksProvider: Loading top-rated books...');
      final books = await _booksService.getTopRatedBooks(limit: limit);
      debugPrint(
        'BooksProvider: Top-rated books loaded: ${books.length} books',
      );
      _isLoading = false;
      notifyListeners();
      return books;
    } catch (e) {
      debugPrint('BooksProvider: Error loading top-rated books: $e');
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  // Get book details by ID
  Future<void> getBookDetails(String bookId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final book = await _booksService.getBookById(bookId.toString());
      _selectedBook = book;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  // Get books by author
  Future<List<Book>> getBooksByAuthor(int authorId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final books = await _booksService.getBooksByAuthor(
        authorId: authorId.toString(),
      );
      _isLoading = false;
      notifyListeners();
      return books;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }
}

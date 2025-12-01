import 'package:flutter/foundation.dart';
import '../../../admin/models/book.dart';
import '../../services/manager_api_service.dart';

class BooksProvider extends ChangeNotifier {
  final ManagerApiService _apiService;

  BooksProvider(this._apiService);

  // State
  List<Book> _books = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  int _itemsPerPage = 10;

  // Getters
  List<Book> get books => _books;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;
  int get itemsPerPage => _itemsPerPage;
  bool get isAuthenticated => _apiService.isAuthenticated;

  // Methods
  Future<void> loadBooks({
    int page = 1,
    String? search,
    String? category,
    String? author,
    String? status,
  }) async {
    _setLoading(true);
    _error = null;
    notifyListeners();

    try {
      if (kDebugMode) {
        debugPrint('BooksProvider: Loading books...');
      }

      // Check if we have a valid token before making the API call
      // The ManagerApiService stores the token in _cachedToken when setToken is called
      // We need to check if the API service has a valid token
      if (!_apiService.isAuthenticated) {
        throw Exception('Authentication required. Please log in first.');
      }

      final books = await _apiService.getBooks(
        page: page,
        search: search,
        categoryId: category != null ? int.tryParse(category) : null,
        authorId: author != null ? int.tryParse(author) : null,
        availableToBorrow: status == 'available'
            ? true
            : status == 'unavailable'
            ? false
            : null,
      );

      // Apply borrowed filter on frontend if needed
      List<Book> filteredBooks = books;
      if (status == 'borrowed') {
        filteredBooks = books
            .where(
              (book) =>
                  book.availableCopies != null &&
                  book.quantity != null &&
                  book.availableCopies! < book.quantity!,
            )
            .toList();
      }

      _books = filteredBooks;
      _currentPage = page;
      // Note: The API service doesn't return pagination info, so we'll use defaults
      _totalPages = 1;
      _totalItems = filteredBooks.length;
      _itemsPerPage = 10;

      if (kDebugMode) {
        debugPrint(
          'BooksProvider: Books loaded successfully: ${filteredBooks.length} books (filtered from ${books.length} total)',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('BooksProvider: Error loading books: $e');
      }
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<Book?> createBook(Book book) async {
    _setLoading(true);
    _error = null;
    notifyListeners();

    try {
      debugPrint('DEBUG: BooksProvider - Creating book: ${book.toJson()}');
      final newBook = await _apiService.createBook(book);
      debugPrint(
        'DEBUG: BooksProvider - Book created successfully: ${newBook.toJson()}',
      );
      _books.insert(0, newBook);
      _totalItems++;
      notifyListeners();
      debugPrint(
        'DEBUG: BooksProvider - Book added to local list, total items: $_totalItems',
      );
      return newBook;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<Book?> updateBook(Book book) async {
    _setLoading(true);
    _error = null;
    notifyListeners();

    try {
      debugPrint('DEBUG: BooksProvider - Updating book: ${book.toJson()}');
      final updatedBook = await _apiService.updateBook(book);
      debugPrint(
        'DEBUG: BooksProvider - Book updated successfully: ${updatedBook.toJson()}',
      );
      final index = _books.indexWhere((b) => b.id == book.id);
      if (index != -1) {
        _books[index] = updatedBook;
        notifyListeners();
        debugPrint(
          'DEBUG: BooksProvider - Book updated in local list at index $index',
        );
      } else {
        debugPrint(
          'DEBUG: BooksProvider - Book not found in local list for update',
        );
      }
      return updatedBook;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteBook(int id) async {
    _setLoading(true);
    _error = null;
    notifyListeners();

    try {
      debugPrint('DEBUG: BooksProvider - Deleting book with ID: $id');
      await _apiService.deleteBook(id);
      debugPrint('DEBUG: BooksProvider - Book deleted successfully from API');
      _books.removeWhere((book) => book.id == id.toString());
      _totalItems--;
      notifyListeners();
      debugPrint(
        'DEBUG: BooksProvider - Book removed from local list, total items: $_totalItems',
      );
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<Book?> getBookById(int id) async {
    try {
      // First try to find in the current list
      final existingBook = _books.firstWhere(
        (book) => int.parse(book.id) == id,
        orElse: () => throw StateError('Book not found'),
      );
      return existingBook;
    } catch (e) {
      // If not found in list, try to fetch from API
      try {
        return await _apiService.getBook(id);
      } catch (apiError) {
        _error = apiError.toString();
        notifyListeners();
        return null;
      }
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Update the API service with a new token
  void setToken(String? token) {
    debugPrint(
      'DEBUG: BooksProvider setToken called with: ${token != null ? '${token.substring(0, 20)}...' : 'null'}',
    );
    if (token != null && token.isNotEmpty) {
      // Set the token directly on the existing API service
      _apiService.setToken(token);
      debugPrint('DEBUG: BooksProvider token set successfully');
    } else {
      debugPrint('DEBUG: BooksProvider token is null or empty');
    }
  }
}

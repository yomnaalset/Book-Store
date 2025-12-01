import 'package:flutter/foundation.dart';
import '../../../../../../features/books/models/author.dart';
import '../../../../../../features/books/services/books_service.dart';

class AuthorsProvider with ChangeNotifier {
  final BooksService _apiService;
  List<Author> _authors = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  int _itemsPerPage = 10;

  AuthorsProvider(this._apiService);

  void setToken(String? token) {
    _apiService.setToken(token);
  }

  List<Author> get authors => _authors;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;
  int get itemsPerPage => _itemsPerPage;

  Future<void> getAuthors({
    int page = 1,
    int limit = 10,
    String? search,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('AuthorsProvider: Loading authors...');
      final result = await _apiService.getAuthors(
        page: page,
        limit: limit,
        search: search,
      );
      debugPrint('AuthorsProvider: Authors loaded: ${result.length} authors');

      // Convert the dynamic list to Author objects
      _authors = result.map((json) => Author.fromJson(json)).toList();
      _currentPage = page;
      _itemsPerPage = limit;
      // In a real implementation, these values would come from the API response
      _totalItems = result.length;
      _totalPages = (result.length / limit).ceil();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('AuthorsProvider: Error loading authors: $e');
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<Author> createAuthor(Author author) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newAuthor = await _apiService.createAuthor(author.toJson());
      _authors.add(newAuthor);
      _isLoading = false;
      notifyListeners();
      return newAuthor;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<Author> updateAuthor(Author author) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedAuthor = await _apiService.updateAuthor(
        author.id.toString(),
        author.toJson(),
      );
      final index = _authors.indexWhere((a) => a.id == author.id);
      if (index != -1) {
        _authors[index] = updatedAuthor;
      }
      _isLoading = false;
      notifyListeners();
      return updatedAuthor;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteAuthor(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.deleteAuthor(id.toString());
      _authors.removeWhere((a) => a.id == id);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}

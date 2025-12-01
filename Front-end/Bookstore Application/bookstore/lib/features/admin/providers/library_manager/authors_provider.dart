import 'package:flutter/foundation.dart';
import '../../../admin/models/author.dart';
import '../../services/manager_api_service.dart';

class AuthorsProvider extends ChangeNotifier {
  final ManagerApiService _apiService;

  AuthorsProvider(this._apiService);

  // State
  List<Author> _authors = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  int _itemsPerPage = 10;

  // Getters
  List<Author> get authors => _authors;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;
  int get itemsPerPage => _itemsPerPage;

  // Methods
  Future<void> loadAuthors({int page = 1, String? search}) async {
    _setLoading(true);
    _error = null;
    notifyListeners();

    try {
      debugPrint(
        'DEBUG: AuthorsProvider - Loading authors, page: $page, search: $search',
      );
      debugPrint(
        'DEBUG: AuthorsProvider - Current token status: ${_apiService.getAuthToken?.call().isNotEmpty ?? false}',
      );
      final authors = await _apiService.getAuthors(page: page, search: search);
      debugPrint(
        'DEBUG: AuthorsProvider - Loaded ${authors.length} authors from API',
      );
      _authors = authors;
      _currentPage = page;
      // Note: The API service doesn't return pagination info, so we'll use defaults
      _totalPages = 1;
      _totalItems = authors.length;
      _itemsPerPage = 10;
      debugPrint(
        'DEBUG: AuthorsProvider - Authors list updated, notifying listeners',
      );
    } catch (e) {
      debugPrint('DEBUG: Error loading authors: $e');
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<Author?> createAuthor(Author author) async {
    _setLoading(true);
    _error = null;
    notifyListeners();

    try {
      debugPrint(
        'DEBUG: AuthorsProvider - Creating author: ${author.toJson()}',
      );
      debugPrint(
        'DEBUG: AuthorsProvider - Current token status: ${_apiService.getAuthToken?.call().isNotEmpty ?? false}',
      );
      final newAuthor = await _apiService.createAuthor(author);
      debugPrint(
        'DEBUG: AuthorsProvider - Author created successfully: ${newAuthor.toJson()}',
      );
      _authors.insert(0, newAuthor);
      _totalItems++;
      notifyListeners();
      debugPrint(
        'DEBUG: AuthorsProvider - Author added to local list, total items: $_totalItems',
      );
      return newAuthor;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<Author?> updateAuthor(Author author) async {
    _setLoading(true);
    _error = null;
    notifyListeners();

    try {
      debugPrint('DEBUG: Updating author with ID: ${author.id}');
      debugPrint('DEBUG: Author data: ${author.toJson()}');

      final updatedAuthor = await _apiService.updateAuthor(author);

      debugPrint(
        'DEBUG: API returned updated author: ${updatedAuthor.toJson()}',
      );

      final index = _authors.indexWhere((a) => a.id == author.id);
      if (index != -1) {
        debugPrint('DEBUG: Found author at index $index, updating local list');
        _authors[index] = updatedAuthor;
        notifyListeners();
        debugPrint('DEBUG: Local list updated, notifying listeners');
      } else {
        debugPrint('DEBUG: Author not found in local list, index: $index');
      }
      return updatedAuthor;
    } catch (e) {
      debugPrint('DEBUG: Error updating author: $e');
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteAuthor(int id) async {
    _setLoading(true);
    _error = null;
    notifyListeners();

    try {
      await _apiService.deleteAuthor(id);
      _authors.removeWhere((author) => author.id == id.toString());
      _totalItems--;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
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
      'DEBUG: AuthorsProvider setToken called with: ${token != null ? '${token.substring(0, 20)}...' : 'null'}',
    );
    if (token != null && token.isNotEmpty) {
      // Set the token directly on the existing API service
      _apiService.setToken(token);
      debugPrint('DEBUG: AuthorsProvider token set successfully');
    } else {
      debugPrint('DEBUG: AuthorsProvider token is null or empty');
    }
  }
}

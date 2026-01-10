import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../books/models/book.dart';
import '../services/favorites_service.dart';

class FavoritesProvider extends ChangeNotifier {
  final FavoritesService _favoritesService;
  List<Book> _favorites = [];
  bool _isLoading = false;
  String? _errorMessage;

  FavoritesProvider(this._favoritesService) {
    _loadFavoritesFromLocal();
  }

  // Getters
  List<Book> get favorites => List.unmodifiable(_favorites);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isEmpty => _favorites.isEmpty;
  int get count => _favorites.length;

  // Check if a book is in favorites
  bool isFavorite(String bookId) {
    return _favorites.any((book) => book.id == bookId);
  }

  // Add to favorites
  Future<void> addToFavorites(Book book) async {
    if (!isFavorite(book.id.toString())) {
      _favorites.add(book);
      await _saveFavoritesToLocal();
      notifyListeners();

      // Sync with server if user is authenticated
      await _syncWithServer();
    }
  }

  // Add to favorites with authentication token
  Future<void> addToFavoritesWithAuth(Book book, String token) async {
    if (!isFavorite(book.id.toString())) {
      try {
        // First add to server
        final success = await _favoritesService.addToFavorites(
          token: token,
          bookId: book.id.toString(),
        );

        if (success) {
          // Then add to local storage (even if already on server)
          if (!isFavorite(book.id.toString())) {
            _favorites.add(book);
            await _saveFavoritesToLocal();
            notifyListeners();
          }
        } else {
          _setError('Failed to add to favorites on server');
        }
      } catch (e) {
        _setError('Failed to add to favorites: ${e.toString()}');
      }
    }
  }

  // Remove from favorites
  Future<void> removeFromFavorites(String bookId) async {
    _favorites.removeWhere((book) => book.id == bookId);
    await _saveFavoritesToLocal();
    notifyListeners();

    // Sync with server if user is authenticated
    await _syncWithServer();
  }

  // Remove from favorites with authentication token
  Future<void> removeFromFavoritesWithAuth(String bookId, String token) async {
    try {
      // First remove from server
      final success = await _favoritesService.removeFromFavorites(
        token: token,
        bookId: bookId,
      );

      if (success) {
        // Then remove from local storage
        _favorites.removeWhere((book) => book.id == bookId);
        await _saveFavoritesToLocal();
        notifyListeners();
      } else {
        _setError('Failed to remove from favorites on server');
      }
    } catch (e) {
      _setError('Failed to remove from favorites: ${e.toString()}');
    }
  }

  // Toggle favorite status
  Future<void> toggleFavorite(Book book) async {
    if (isFavorite(book.id.toString())) {
      await removeFromFavorites(book.id.toString());
    } else {
      await addToFavorites(book);
    }
  }

  // Clear all favorites
  Future<void> clearFavorites() async {
    _favorites.clear();
    await _saveFavoritesToLocal();
    notifyListeners();

    // Sync with server if user is authenticated
    await _syncWithServer();
  }

  // Load favorites from server
  Future<void> loadFavoritesFromServer(String token) async {
    _setLoading(true);
    _clearError();

    try {
      debugPrint('FavoritesProvider: Loading favorites from server...');
      final serverFavorites = await _favoritesService.getFavorites(token);
      debugPrint(
        'FavoritesProvider: Received ${serverFavorites.length} favorites from server',
      );

      _favorites = serverFavorites;
      await _saveFavoritesToLocal();
      debugPrint(
        'FavoritesProvider: Saved ${_favorites.length} favorites to local storage',
      );
      notifyListeners();
      _setLoading(false);
    } catch (e, stackTrace) {
      debugPrint('FavoritesProvider: Error loading favorites: $e');
      debugPrint('FavoritesProvider: Stack trace: $stackTrace');
      _setError('Failed to load favorites: ${e.toString()}');
      _setLoading(false);
    }
  }

  // Sync favorites with server
  Future<void> _syncWithServer() async {
    // This would be called when user is authenticated
    // Implementation depends on auth state management
    try {
      // Get auth token from shared preferences or auth provider
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token != null) {
        // Sync each favorite to server
        for (final book in _favorites) {
          await _favoritesService.addToFavorites(
            token: token,
            bookId: book.id.toString(),
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to sync favorites with server: $e');
    }
  }

  // Save favorites to local storage
  Future<void> _saveFavoritesToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = _favorites.map((book) => book.toJson()).toList();
      await prefs.setString('favorites_data', json.encode(favoritesJson));
    } catch (e) {
      debugPrint('Failed to save favorites to local storage: $e');
    }
  }

  // Load favorites from local storage
  Future<void> _loadFavoritesFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesDataString = prefs.getString('favorites_data');

      if (favoritesDataString != null) {
        final List<dynamic> favoritesJson = json.decode(favoritesDataString);
        _favorites = favoritesJson.map((json) => Book.fromJson(json)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to load favorites from local storage: $e');
    }
  }

  // Get favorites by category
  List<Book> getFavoritesByCategory(String categoryId) {
    return _favorites
        .where((book) => book.category?.id == int.parse(categoryId))
        .toList();
  }

  // Get favorites by author
  List<Book> getFavoritesByAuthor(String authorId) {
    return _favorites
        .where((book) => book.author?.id == int.parse(authorId))
        .toList();
  }

  // Search favorites
  List<Book> searchFavorites(String query) {
    final lowerQuery = query.toLowerCase();
    return _favorites.where((book) {
      final title = book.title.toLowerCase();
      final author = book.author?.name.toLowerCase() ?? '';
      return title.contains(lowerQuery) || author.contains(lowerQuery);
    }).toList();
  }

  // Sort favorites
  void sortFavorites(String sortBy) {
    switch (sortBy) {
      case 'title':
        _favorites.sort((a, b) => (a.title).compareTo(b.title));
        break;
      case 'author':
        _favorites.sort(
          (a, b) => (a.author?.name ?? '').compareTo(b.author?.name ?? ''),
        );
        break;
      case 'price':
        _favorites.sort((a, b) => a.priceAsDouble.compareTo(b.priceAsDouble));
        break;
      case 'date_added':
        // Sort by the order they were added (reverse order for newest first)
        _favorites = _favorites.reversed.toList();
        break;
    }
    notifyListeners();
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  // Clear all data
  void clear() {
    _favorites.clear();
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  // Clear all local storage data
  Future<void> clearLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('favorites_data');
      _favorites.clear();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to clear local favorites data: $e');
    }
  }
}

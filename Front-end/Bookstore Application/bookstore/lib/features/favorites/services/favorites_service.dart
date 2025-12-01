import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../books/models/book.dart';

class FavoritesService {
  final String baseUrl;
  String? _errorMessage;

  FavoritesService({required this.baseUrl});

  String? get errorMessage => _errorMessage;

  // Get user's favorites from server
  Future<List<Book>> getFavorites(String token) async {
    _clearError();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/library/favorites/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> booksJson = data['data'] ?? [];

        // Convert favorite items to book objects
        return booksJson.map((favoriteJson) {
          // The backend returns favorite objects with book data nested
          return Book.fromJson({
            'id': favoriteJson['book_id'],
            'title': favoriteJson['book_name'],
            'price': favoriteJson['book_price'],
            'is_available': favoriteJson['book_is_available'],
            'is_new': favoriteJson['book_is_new'],
            'author': {
              'id': null, // Not provided in simplified serializer
              'name': favoriteJson['author_name'],
            },
            'category': {
              'id': null, // Not provided in simplified serializer
              'name': favoriteJson['category_name'],
            },
            'primary_image_url': favoriteJson['book_primary_image_url'],
            'average_rating': favoriteJson['book_average_rating'],
          });
        }).toList();
      } else {
        final data = json.decode(response.body);
        _setError(data['message'] ?? 'Failed to load favorites');
        return [];
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('FavoritesService: Error getting favorites: $e');
      return [];
    }
  }

  // Add book to favorites
  Future<bool> addToFavorites({
    required String token,
    required String bookId,
  }) async {
    _clearError();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/library/favorites/add/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'book_id': bookId}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('FavoritesService: Book added to favorites successfully');
        return true;
      } else {
        final data = json.decode(response.body);
        _setError(data['message'] ?? 'Failed to add to favorites');
        return false;
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('FavoritesService: Error adding to favorites: $e');
      return false;
    }
  }

  // Remove book from favorites
  Future<bool> removeFromFavorites({
    required String token,
    required String bookId,
  }) async {
    _clearError();

    try {
      // First, get the list of favorites to find the favorite ID for this book
      final favoritesResponse = await http.get(
        Uri.parse('$baseUrl/library/favorites/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (favoritesResponse.statusCode == 200) {
        final favoritesData = json.decode(favoritesResponse.body);
        final List<dynamic> favorites = favoritesData['data'] ?? [];

        // Find the favorite ID for this book
        int? favoriteId;
        for (var favorite in favorites) {
          if (favorite['book_id'].toString() == bookId) {
            favoriteId = favorite['id'];
            break;
          }
        }

        if (favoriteId == null) {
          _setError('Book not found in favorites');
          return false;
        }

        // Now delete using the favorite ID
        final response = await http.delete(
          Uri.parse('$baseUrl/library/favorites/$favoriteId/delete/'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200 || response.statusCode == 204) {
          debugPrint(
            'FavoritesService: Book removed from favorites successfully',
          );
          return true;
        } else {
          final data = json.decode(response.body);
          _setError(data['message'] ?? 'Failed to remove from favorites');
          return false;
        }
      } else {
        final data = json.decode(favoritesResponse.body);
        _setError(data['message'] ?? 'Failed to get favorites list');
        return false;
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('FavoritesService: Error removing from favorites: $e');
      return false;
    }
  }

  // Check if book is in favorites
  Future<bool> isFavorite({
    required String token,
    required String bookId,
  }) async {
    _clearError();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/library/books/$bookId/favorite/status/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['is_favorite'] ?? false;
      } else {
        return false;
      }
    } catch (e) {
      debugPrint('FavoritesService: Error checking favorite status: $e');
      return false;
    }
  }

  // Clear all favorites
  Future<bool> clearFavorites(String token) async {
    _clearError();

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/library/favorites/clear/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint('FavoritesService: Favorites cleared successfully');
        return true;
      } else {
        final data = json.decode(response.body);
        _setError(data['message'] ?? 'Failed to clear favorites');
        return false;
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('FavoritesService: Error clearing favorites: $e');
      return false;
    }
  }

  // Sync local favorites with server
  Future<bool> syncFavorites({
    required String token,
    required List<String> bookIds,
  }) async {
    _clearError();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/library/favorites/sync/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'book_ids': bookIds}),
      );

      if (response.statusCode == 200) {
        debugPrint('FavoritesService: Favorites synced successfully');
        return true;
      } else {
        final data = json.decode(response.body);
        _setError(data['message'] ?? 'Failed to sync favorites');
        return false;
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('FavoritesService: Error syncing favorites: $e');
      return false;
    }
  }

  // Private helper methods
  void _setError(String error) {
    _errorMessage = error;
  }

  void _clearError() {
    _errorMessage = null;
  }
}

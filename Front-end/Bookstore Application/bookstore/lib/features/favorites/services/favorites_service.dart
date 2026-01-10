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

      debugPrint('FavoritesService: Response status: ${response.statusCode}');
      debugPrint('FavoritesService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('FavoritesService: Parsed data keys: ${data.keys.toList()}');

        // Handle different response formats
        List<dynamic> favoritesJson = [];
        if (data['data'] != null) {
          favoritesJson = data['data'] is List ? data['data'] as List : [];
        } else if (data['results'] != null) {
          favoritesJson = data['results'] is List
              ? data['results'] as List
              : [];
        } else if (data is List) {
          favoritesJson = data;
        }

        debugPrint('FavoritesService: Found ${favoritesJson.length} favorites');

        // Convert favorite items to book objects
        final books = <Book>[];
        for (var favoriteJson in favoritesJson) {
          try {
            debugPrint(
              'FavoritesService: Processing favorite: ${favoriteJson.keys.toList()}',
            );
            debugPrint('FavoritesService: Favorite data: $favoriteJson');

            // The backend returns favorite objects with book data nested
            // Ensure all required fields are present
            final bookId =
                favoriteJson['book_id']?.toString() ??
                favoriteJson['id']?.toString();
            if (bookId == null || bookId.isEmpty) {
              debugPrint(
                'FavoritesService: Skipping favorite - missing book_id',
              );
              continue;
            }

            final bookName =
                favoriteJson['book_name'] ?? favoriteJson['name'] ?? '';
            if (bookName.isEmpty) {
              debugPrint(
                'FavoritesService: Warning - book name is empty for ID: $bookId',
              );
            }

            final bookData = <String, dynamic>{
              'id': bookId,
              'name': bookName,
              'title': bookName,
              'price':
                  favoriteJson['book_price']?.toString() ??
                  favoriteJson['price']?.toString(),
              'is_available':
                  favoriteJson['book_is_available'] ??
                  favoriteJson['is_available'] ??
                  true,
              'is_available_for_borrow':
                  favoriteJson['book_is_available_for_borrow'] ??
                  favoriteJson['is_available_for_borrow'] ??
                  true,
              'is_new':
                  favoriteJson['book_is_new'] ??
                  favoriteJson['is_new'] ??
                  false,
              'author_id': favoriteJson['author_id'],
              'author_name': favoriteJson['author_name'] ?? '',
              'category_id': favoriteJson['category_id'],
              'category_name': favoriteJson['category_name'] ?? '',
              'primary_image_url':
                  favoriteJson['book_primary_image_url'] ??
                  favoriteJson['primary_image_url'],
              'average_rating':
                  favoriteJson['book_average_rating']?.toDouble() ??
                  favoriteJson['average_rating']?.toDouble() ??
                  0.0,
            };

            debugPrint(
              'FavoritesService: Created book data for ID: ${bookData['id']}, Title: ${bookData['title']}',
            );
            final book = Book.fromJson(bookData);
            books.add(book);
            debugPrint(
              'FavoritesService: Successfully created book: ${book.title}',
            );
          } catch (e, stackTrace) {
            debugPrint('FavoritesService: Error parsing favorite item: $e');
            debugPrint('FavoritesService: Stack trace: $stackTrace');
            debugPrint('FavoritesService: Favorite JSON: $favoriteJson');
            // Continue processing other favorites instead of failing completely
            continue;
          }
        }

        debugPrint(
          'FavoritesService: Successfully parsed ${books.length} books',
        );
        return books;
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
        final errorMessage =
            data['message'] ??
            (data['error'] is String ? data['error'] : null) ??
            'Failed to add to favorites';

        // If book is already in favorites (400 error), don't treat it as an error
        if (response.statusCode == 400 &&
            (errorMessage.toLowerCase().contains('already') ||
                errorMessage.toLowerCase().contains('favorites'))) {
          debugPrint('FavoritesService: Book is already in favorites');
          return true; // Return true since the book is already favorited
        }

        _setError(errorMessage);
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

import 'package:flutter/foundation.dart';
import '../models/book.dart';
import '../models/books_response.dart';
import '../../../core/services/api_client.dart';

/// Books API service for handling all book-related operations
class BooksApiService {
  /// Get all books with pagination and filters
  static Future<BooksResponse?> getBooks({
    String? token,
    int page = 1,
    int limit = 20,
    String? search,
    int? categoryId,
    String? authorName,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    double? maxRating,
    bool? availableToBorrow,
    bool? newOnly,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
        if (categoryId != null) 'category': categoryId.toString(),
        if (authorName != null && authorName.isNotEmpty)
          'author_name': authorName,
        if (minPrice != null) 'min_price': minPrice.toString(),
        if (maxPrice != null) 'max_price': maxPrice.toString(),
        if (minRating != null) 'min_rating': minRating.toString(),
        if (maxRating != null) 'max_rating': maxRating.toString(),
        if (availableToBorrow != null)
          'available_to_borrow': availableToBorrow.toString(),
        if (newOnly != null) 'new_only': newOnly.toString(),
        if (sortBy != null) 'sort_by': sortBy,
        if (sortOrder != null) 'sort_order': sortOrder,
      };

      final response = await ApiClient.get(
        '/library/books/',
        queryParams: queryParams,
        token: token,
      );

      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response)) {
        // Extract the actual books data from the response wrapper
        final booksData = data['data'] ?? data;
        return BooksResponse.fromJson(booksData);
      } else {
        debugPrint('BooksApiService getBooks error: ${data['error']}');
        return null;
      }
    } catch (e) {
      debugPrint('BooksApiService getBooks error: $e');
      return null;
    }
  }

  /// Get book details by ID
  static Future<Book?> getBookDetail(int bookId, {String? token}) async {
    try {
      final response = await ApiClient.get(
        '/library/books/$bookId/',
        token: token,
      );

      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response)) {
        // Extract the actual book data from the response wrapper
        final bookData = data['data'] ?? data;
        return Book.fromJson(bookData);
      } else {
        debugPrint('BooksApiService getBookDetail error: ${data['error']}');
        return null;
      }
    } catch (e) {
      debugPrint('BooksApiService getBookDetail error: $e');
      return null;
    }
  }

  /// Get new books
  static Future<BooksResponse?> getNewBooks({
    String? token,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await ApiClient.get(
        '/library/books/new/',
        queryParams: {'page': page.toString(), 'limit': limit.toString()},
        token: token,
      );

      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response)) {
        // Extract the actual books data from the response wrapper
        final booksData = data['data'] ?? data;
        return BooksResponse.fromJson(booksData);
      } else {
        debugPrint('BooksApiService getNewBooks error: ${data['error']}');
        return null;
      }
    } catch (e) {
      debugPrint('BooksApiService getNewBooks error: $e');
      return null;
    }
  }

  /// Get books by category
  static Future<BooksResponse?> getBooksByCategory(
    int categoryId, {
    String? token,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await ApiClient.get(
        '/library/books/category/$categoryId/',
        queryParams: {'page': page.toString(), 'limit': limit.toString()},
        token: token,
      );

      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response)) {
        // Extract the actual books data from the response wrapper
        final booksData = data['data'] ?? data;
        return BooksResponse.fromJson(booksData);
      } else {
        debugPrint(
          'BooksApiService getBooksByCategory error: ${data['error']}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('BooksApiService getBooksByCategory error: $e');
      return null;
    }
  }

  /// Get books by author
  static Future<BooksResponse?> getBooksByAuthor(
    int authorId, {
    String? token,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await ApiClient.get(
        '/library/books/author/$authorId/',
        queryParams: {'page': page.toString(), 'limit': limit.toString()},
        token: token,
      );

      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response)) {
        // Extract the actual books data from the response wrapper
        final booksData = data['data'] ?? data;
        return BooksResponse.fromJson(booksData);
      } else {
        debugPrint('BooksApiService getBooksByAuthor error: ${data['error']}');
        return null;
      }
    } catch (e) {
      debugPrint('BooksApiService getBooksByAuthor error: $e');
      return null;
    }
  }

  /// Search books
  static Future<BooksResponse?> searchBooks({
    required String query,
    String? token,
    int page = 1,
    int limit = 20,
    int? categoryId,
    int? authorId,
  }) async {
    try {
      final queryParams = <String, String>{
        'q': query,
        'page': page.toString(),
        'limit': limit.toString(),
        if (categoryId != null) 'category': categoryId.toString(),
        if (authorId != null) 'author': authorId.toString(),
      };

      final response = await ApiClient.get(
        '/library/books/search/',
        queryParams: queryParams,
        token: token,
      );

      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response)) {
        // Extract the actual books data from the response wrapper
        final booksData = data['data'] ?? data;
        return BooksResponse.fromJson(booksData);
      } else {
        debugPrint('BooksApiService searchBooks error: ${data['error']}');
        return null;
      }
    } catch (e) {
      debugPrint('BooksApiService searchBooks error: $e');
      return null;
    }
  }

  /// Get most borrowed books
  static Future<BooksResponse?> getMostBorrowedBooks({
    String? token,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await ApiClient.get(
        '/library/books/most-borrowed/',
        queryParams: {'page': page.toString(), 'limit': limit.toString()},
        token: token,
      );

      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response)) {
        // Extract the actual books data from the response wrapper
        final booksData = data['data'] ?? data;
        return BooksResponse.fromJson(booksData);
      } else {
        debugPrint(
          'BooksApiService getMostBorrowedBooks error: ${data['error']}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('BooksApiService getMostBorrowedBooks error: $e');
      return null;
    }
  }

  /// Get book recommendations
  static Future<BooksResponse?> getRecommendations({
    String? token,
    int? bookId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (bookId != null) 'book_id': bookId.toString(),
      };

      final response = await ApiClient.get(
        '/library/books/recommendations/',
        queryParams: queryParams,
        token: token,
      );

      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response)) {
        // Extract the actual books data from the response wrapper
        final booksData = data['data'] ?? data;
        return BooksResponse.fromJson(booksData);
      } else {
        debugPrint(
          'BooksApiService getRecommendations error: ${data['error']}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('BooksApiService getRecommendations error: $e');
      return null;
    }
  }

  /// Get books with offers/discounts
  static Future<BooksResponse?> getBooksWithOffers({
    String? token,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await ApiClient.get(
        '/library/books/offers/',
        queryParams: {'page': page.toString(), 'limit': limit.toString()},
        token: token,
      );

      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response)) {
        // Extract the actual books data from the response wrapper
        final booksData = data['data'] ?? data;
        return BooksResponse.fromJson(booksData);
      } else {
        debugPrint(
          'BooksApiService getBooksWithOffers error: ${data['error']}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('BooksApiService getBooksWithOffers error: $e');
      return null;
    }
  }

  /// Check book availability
  static Future<bool> checkAvailability(int bookId, {String? token}) async {
    try {
      final response = await ApiClient.get(
        '/library/books/$bookId/availability/',
        token: token,
      );

      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response)) {
        return data['available'] ?? false;
      } else {
        debugPrint('BooksApiService checkAvailability error: ${data['error']}');
        return false;
      }
    } catch (e) {
      debugPrint('BooksApiService checkAvailability error: $e');
      return false;
    }
  }

  /// Get book reviews
  static Future<Map<String, dynamic>?> getBookReviews(
    int bookId, {
    String? token,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await ApiClient.get(
        '/library/books/$bookId/reviews/',
        queryParams: {'page': page.toString(), 'limit': limit.toString()},
        token: token,
      );

      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response)) {
        return data;
      } else {
        debugPrint('BooksApiService getBookReviews error: ${data['error']}');
        return null;
      }
    } catch (e) {
      debugPrint('BooksApiService getBookReviews error: $e');
      return null;
    }
  }

  /// Add book to favorites
  static Future<bool> addToFavorites(int bookId, String token) async {
    try {
      final response = await ApiClient.post(
        '/library/books/$bookId/favorite/',
        token: token,
      );

      return ApiClient.isSuccess(response);
    } catch (e) {
      debugPrint('BooksApiService addToFavorites error: $e');
      return false;
    }
  }

  /// Remove book from favorites
  static Future<bool> removeFromFavorites(int bookId, String token) async {
    try {
      final response = await ApiClient.delete(
        '/library/books/$bookId/favorite/',
        token: token,
      );

      return ApiClient.isSuccess(response);
    } catch (e) {
      debugPrint('BooksApiService removeFromFavorites error: $e');
      return false;
    }
  }

  /// Check if book is in favorites
  static Future<bool> isFavorite(int bookId, String token) async {
    try {
      final response = await ApiClient.get(
        '/library/books/$bookId/favorite/',
        token: token,
      );

      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response)) {
        return data['is_favorite'] ?? false;
      } else {
        debugPrint('BooksApiService isFavorite error: ${data['error']}');
        return false;
      }
    } catch (e) {
      debugPrint('BooksApiService isFavorite error: $e');
      return false;
    }
  }
}

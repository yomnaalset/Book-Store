import 'package:flutter/foundation.dart';
import '../../books/models/category.dart' as book_category;
import '../../books/models/author.dart';
import '../../../core/services/api_client.dart';

/// Library API service for handling categories and authors
class LibraryApiService {
  /// Get all categories
  static Future<List<book_category.Category>> getCategories({
    String? token,
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
      };

      final response = await ApiClient.get(
        '/library/categories/',
        queryParams: queryParams,
        token: token,
      );

      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response)) {
        final List<dynamic> categoriesData = data['results'] ?? data;
        return categoriesData
            .map((json) => book_category.Category.fromJson(json))
            .toList();
      } else {
        debugPrint('LibraryApiService getCategories error: ${data['error']}');
        return [];
      }
    } catch (e) {
      debugPrint('LibraryApiService getCategories error: $e');
      return [];
    }
  }

  /// Get category by ID
  static Future<book_category.Category?> getCategory(
    int categoryId, {
    String? token,
  }) async {
    try {
      final response = await ApiClient.get(
        '/library/categories/$categoryId/',
        token: token,
      );

      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response)) {
        return book_category.Category.fromJson(data);
      } else {
        debugPrint('LibraryApiService getCategory error: ${data['error']}');
        return null;
      }
    } catch (e) {
      debugPrint('LibraryApiService getCategory error: $e');
      return null;
    }
  }

  /// Get all authors
  static Future<List<Author>> getAuthors({
    String? token,
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
      };

      final response = await ApiClient.get(
        '/library/authors/',
        queryParams: queryParams,
        token: token,
      );

      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response)) {
        final List<dynamic> authorsData = data['results'] ?? data;
        return authorsData.map((json) => Author.fromJson(json)).toList();
      } else {
        debugPrint('LibraryApiService getAuthors error: ${data['error']}');
        return [];
      }
    } catch (e) {
      debugPrint('LibraryApiService getAuthors error: $e');
      return [];
    }
  }

  /// Get author by ID
  static Future<Author?> getAuthor(int authorId, {String? token}) async {
    try {
      final response = await ApiClient.get(
        '/library/authors/$authorId/',
        token: token,
      );

      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response)) {
        return Author.fromJson(data);
      } else {
        debugPrint('LibraryApiService getAuthor error: ${data['error']}');
        return null;
      }
    } catch (e) {
      debugPrint('LibraryApiService getAuthor error: $e');
      return null;
    }
  }

  /// Get author's books
  static Future<Map<String, dynamic>?> getAuthorBooks(
    int authorId, {
    String? token,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await ApiClient.get(
        '/library/authors/$authorId/books/',
        queryParams: {'page': page.toString(), 'limit': limit.toString()},
        token: token,
      );

      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response)) {
        return data;
      } else {
        debugPrint('LibraryApiService getAuthorBooks error: ${data['error']}');
        return null;
      }
    } catch (e) {
      debugPrint('LibraryApiService getAuthorBooks error: $e');
      return null;
    }
  }

  /// Get category's books
  static Future<Map<String, dynamic>?> getCategoryBooks(
    int categoryId, {
    String? token,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await ApiClient.get(
        '/library/categories/$categoryId/books/',
        queryParams: {'page': page.toString(), 'limit': limit.toString()},
        token: token,
      );

      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response)) {
        return data;
      } else {
        debugPrint(
          'LibraryApiService getCategoryBooks error: ${data['error']}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('LibraryApiService getCategoryBooks error: $e');
      return null;
    }
  }

  /// Search authors
  static Future<List<Author>> searchAuthors({
    required String query,
    String? token,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await ApiClient.get(
        '/library/authors/search/',
        queryParams: {
          'q': query,
          'page': page.toString(),
          'limit': limit.toString(),
        },
        token: token,
      );

      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response)) {
        final List<dynamic> authorsData = data['results'] ?? data;
        return authorsData.map((json) => Author.fromJson(json)).toList();
      } else {
        debugPrint('LibraryApiService searchAuthors error: ${data['error']}');
        return [];
      }
    } catch (e) {
      debugPrint('LibraryApiService searchAuthors error: $e');
      return [];
    }
  }

  /// Search categories
  static Future<List<book_category.Category>> searchCategories({
    required String query,
    String? token,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await ApiClient.get(
        '/library/categories/search/',
        queryParams: {
          'q': query,
          'page': page.toString(),
          'limit': limit.toString(),
        },
        token: token,
      );

      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response)) {
        final List<dynamic> categoriesData = data['results'] ?? data;
        return categoriesData
            .map((json) => book_category.Category.fromJson(json))
            .toList();
      } else {
        debugPrint(
          'LibraryApiService searchCategories error: ${data['error']}',
        );
        return [];
      }
    } catch (e) {
      debugPrint('LibraryApiService searchCategories error: $e');
      return [];
    }
  }

  /// Get popular authors
  static Future<List<Author>> getPopularAuthors({
    String? token,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await ApiClient.get(
        '/library/authors/popular/',
        queryParams: {'page': page.toString(), 'limit': limit.toString()},
        token: token,
      );

      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response)) {
        final List<dynamic> authorsData = data['results'] ?? data;
        return authorsData.map((json) => Author.fromJson(json)).toList();
      } else {
        debugPrint(
          'LibraryApiService getPopularAuthors error: ${data['error']}',
        );
        return [];
      }
    } catch (e) {
      debugPrint('LibraryApiService getPopularAuthors error: $e');
      return [];
    }
  }

  /// Get popular categories
  static Future<List<book_category.Category>> getPopularCategories({
    String? token,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await ApiClient.get(
        '/library/categories/popular/',
        queryParams: {'page': page.toString(), 'limit': limit.toString()},
        token: token,
      );

      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response)) {
        final List<dynamic> categoriesData = data['results'] ?? data;
        return categoriesData
            .map((json) => book_category.Category.fromJson(json))
            .toList();
      } else {
        debugPrint(
          'LibraryApiService getPopularCategories error: ${data['error']}',
        );
        return [];
      }
    } catch (e) {
      debugPrint('LibraryApiService getPopularCategories error: $e');
      return [];
    }
  }

  /// Get library statistics
  static Future<Map<String, dynamic>?> getLibraryStats({String? token}) async {
    try {
      final response = await ApiClient.get('/library/stats/', token: token);

      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response)) {
        return data;
      } else {
        debugPrint('LibraryApiService getLibraryStats error: ${data['error']}');
        return null;
      }
    } catch (e) {
      debugPrint('LibraryApiService getLibraryStats error: $e');
      return null;
    }
  }

  /// Get featured categories
  static Future<List<book_category.Category>> getFeaturedCategories({
    String? token,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await ApiClient.get(
        '/library/categories/featured/',
        queryParams: {'page': page.toString(), 'limit': limit.toString()},
        token: token,
      );

      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response)) {
        final List<dynamic> categoriesData = data['results'] ?? data;
        return categoriesData
            .map((json) => book_category.Category.fromJson(json))
            .toList();
      } else {
        debugPrint(
          'LibraryApiService getFeaturedCategories error: ${data['error']}',
        );
        return [];
      }
    } catch (e) {
      debugPrint('LibraryApiService getFeaturedCategories error: $e');
      return [];
    }
  }

  /// Get featured authors
  static Future<List<Author>> getFeaturedAuthors({
    String? token,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await ApiClient.get(
        '/library/authors/featured/',
        queryParams: {'page': page.toString(), 'limit': limit.toString()},
        token: token,
      );

      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response)) {
        final List<dynamic> authorsData = data['results'] ?? data;
        return authorsData.map((json) => Author.fromJson(json)).toList();
      } else {
        debugPrint(
          'LibraryApiService getFeaturedAuthors error: ${data['error']}',
        );
        return [];
      }
    } catch (e) {
      debugPrint('LibraryApiService getFeaturedAuthors error: $e');
      return [];
    }
  }
}

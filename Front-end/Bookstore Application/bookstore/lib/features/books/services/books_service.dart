import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../../core/services/api_client.dart';
import '../models/book.dart';
import '../models/category.dart' as book_category;

class BooksService {
  final String baseUrl;
  String? _errorMessage;
  String? _token;

  BooksService({required this.baseUrl, String? token}) : _token = token;

  // Getter for token to allow comparison
  String? get token => _token;

  String? get errorMessage => _errorMessage;

  void setToken(String? token) {
    debugPrint(
      'DEBUG: BooksService setToken called with: ${token != null ? '${token.substring(0, 20)}...' : 'null'}',
    );
    _token = token;
    debugPrint('DEBUG: BooksService token set successfully');
  }

  // Get all books with pagination and filters
  Future<List<Book>> getBooks({
    int page = 1,
    int limit = 20,
    String? search,
    String? category,
    String? author,
    String? categoryId,
    String? authorId,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    double? maxRating,
    bool? availableToBorrow,
    bool? newOnly,
    String? sortBy,
    String? sortOrder,
  }) async {
    _clearError();

    try {
      // If categoryId is provided, use the dedicated category endpoint
      if (categoryId != null && categoryId.isNotEmpty) {
        debugPrint(
          'BooksService: Using category-specific endpoint for categoryId: $categoryId',
        );
        return await _getBooksByCategory(categoryId, page, limit);
      }

      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
        if (category != null && category.isNotEmpty) 'category': category,
        if (author != null && author.isNotEmpty) 'author': author,
        if (authorId != null && authorId.isNotEmpty) 'author_id': authorId,
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

      debugPrint(
        'BooksService: Making API call with queryParams: $queryParams',
      );

      final response = await ApiClient.get(
        '/library/books/',
        queryParams: queryParams,
        token: _token,
      );

      if (ApiClient.isSuccess(response)) {
        final data = json.decode(response.body);
        debugPrint(
          'BooksService: getBooks - Raw API response type: ${data.runtimeType}',
        );

        // Handle different response formats
        List<dynamic> booksJson = [];

        if (data is List) {
          // Direct list response
          booksJson = data;
          debugPrint(
            'BooksService: Direct list response with ${booksJson.length} items',
          );
        } else if (data is Map<String, dynamic>) {
          // Check for nested structure: results.data
          if (data['results'] != null) {
            final results = data['results'];
            debugPrint(
              'BooksService: Found results field, type: ${results.runtimeType}',
            );

            if (results is Map<String, dynamic>) {
              // Nested structure: {results: {success: true, data: [...]}}
              booksJson = results['data'] ?? [];
              debugPrint(
                'BooksService: Extracted ${booksJson.length} books from results.data',
              );
            } else if (results is List) {
              // Direct list in results: {results: [...]}
              booksJson = results;
              debugPrint(
                'BooksService: Extracted ${booksJson.length} books from results list',
              );
            }
          } else if (data['data'] != null) {
            // Handle paginated response: data['data'] might be a Map with 'results' key
            final dataField = data['data'];
            if (dataField is List) {
              booksJson = dataField;
              debugPrint(
                'BooksService: Extracted ${booksJson.length} books from data field (List)',
              );
            } else if (dataField is Map<String, dynamic>) {
              // Paginated response: {data: {count: ..., results: [...]}}
              booksJson = dataField['results'] is List
                  ? dataField['results']
                  : [];
              debugPrint(
                'BooksService: Extracted ${booksJson.length} books from data.results (paginated)',
              );
            }
          } else if (data['books'] != null) {
            booksJson = data['books'] is List ? data['books'] : [];
            debugPrint(
              'BooksService: Extracted ${booksJson.length} books from books field',
            );
          }
        }

        debugPrint(
          'BooksService: API response successful, found ${booksJson.length} books',
        );

        // Safely parse books, handling any parsing errors
        try {
          return booksJson
              .map((json) {
                try {
                  if (json is Map<String, dynamic>) {
                    return Book.fromJson(json);
                  } else {
                    debugPrint(
                      'BooksService: Skipping invalid book JSON (not a Map): $json',
                    );
                    return null;
                  }
                } catch (e) {
                  debugPrint(
                    'BooksService: Error parsing book JSON: $e, JSON: $json',
                  );
                  return null;
                }
              })
              .whereType<Book>()
              .toList();
        } catch (e) {
          debugPrint('BooksService: Error mapping books: $e');
          _setError('Error parsing books: ${e.toString()}');
          return [];
        }
      } else {
        final data = json.decode(response.body);
        debugPrint(
          'BooksService: API response failed: ${response.statusCode} - ${data['message'] ?? 'Unknown error'}',
        );
        _setError(data['message'] ?? 'Failed to load books');
        return [];
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('BooksService: Error getting books: $e');
      return [];
    }
  }

  // Get new books
  Future<List<Book>> getNewBooks({int limit = 10}) async {
    _clearError();

    try {
      final response = await ApiClient.get(
        '/library/books/new/',
        queryParams: {'limit': limit.toString()},
        token: _token,
      );

      if (ApiClient.isSuccess(response)) {
        final data = json.decode(response.body);

        // Handle different response structures
        List<dynamic> booksJson = [];

        if (data is List) {
          booksJson = data;
        } else if (data is Map<String, dynamic>) {
          if (data['results'] != null) {
            final results = data['results'];
            if (results is Map<String, dynamic>) {
              booksJson = results['data'] ?? [];
            } else if (results is List) {
              booksJson = results;
            }
          } else {
            booksJson = data['books'] ?? data['data'] ?? [];
          }
        }

        return booksJson.map((json) => Book.fromJson(json)).toList();
      } else {
        final data = json.decode(response.body);
        _setError(data['message'] ?? 'Failed to load new books');
        return [];
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('BooksService: Error getting new books: $e');
      return [];
    }
  }

  // Get most borrowed books (using general books endpoint with borrow filter)
  Future<List<Book>> getMostBorrowedBooks({int limit = 10}) async {
    _clearError();

    try {
      // Use the general books endpoint with available_to_borrow filter
      final response = await ApiClient.get(
        '/library/books/',
        queryParams: {
          'limit': limit.toString(),
          'available_to_borrow': 'true',
          'sort_by': 'borrow_count',
          'sort_order': 'desc',
        },
        token: _token,
      );

      if (ApiClient.isSuccess(response)) {
        final data = json.decode(response.body);
        debugPrint('BooksService: Raw API response type: ${data.runtimeType}');
        debugPrint(
          'BooksService: Raw API response keys: ${data is Map ? data.keys.toList() : 'N/A'}',
        );

        // Handle different response structures
        List<dynamic> booksJson = [];

        if (data is List) {
          // Direct list response
          booksJson = data;
          debugPrint(
            'BooksService: Direct list response with ${booksJson.length} items',
          );
        } else if (data is Map<String, dynamic>) {
          // Check for nested structure: results.data
          if (data['results'] != null) {
            final results = data['results'];
            debugPrint(
              'BooksService: Found results field, type: ${results.runtimeType}',
            );

            if (results is Map<String, dynamic>) {
              // Nested structure: {results: {success: true, data: [...]}}
              booksJson = results['data'] ?? [];
              debugPrint(
                'BooksService: Extracted ${booksJson.length} books from results.data',
              );
            } else if (results is List) {
              // Direct list in results: {results: [...]}
              booksJson = results;
              debugPrint(
                'BooksService: Extracted ${booksJson.length} books from results list',
              );
            }
          } else {
            // Try other possible fields
            booksJson = data['books'] ?? data['data'] ?? [];
            debugPrint(
              'BooksService: Extracted ${booksJson.length} books from data/books field',
            );
          }
        }

        debugPrint(
          'BooksService: Successfully parsed ${booksJson.length} books',
        );
        return booksJson.map((json) => Book.fromJson(json)).toList();
      } else {
        final data = json.decode(response.body);
        _setError(data['message'] ?? 'Failed to load most borrowed books');
        return [];
      }
    } catch (e, stackTrace) {
      _setError('Network error: ${e.toString()}');
      debugPrint('BooksService: Error getting most borrowed books: $e');
      debugPrint('BooksService: Stack trace: $stackTrace');
      return [];
    }
  }

  // Get most popular books (using general books endpoint)
  // Returns ALL books from database without filtering by availability
  Future<List<Book>> getMostPopularBooks({int limit = 10}) async {
    _clearError();

    try {
      // Use the general books endpoint to get ALL books
      // Don't pass is_available parameter to get all books regardless of availability
      final response = await ApiClient.get(
        '/library/books/',
        queryParams: {
          'limit': limit.toString(),
          'ordering': 'newest', // Sort by newest, but show all books
        },
        token: _token,
      );

      if (ApiClient.isSuccess(response)) {
        final data = json.decode(response.body);
        debugPrint(
          'BooksService: getMostPopularBooks - Raw API response type: ${data.runtimeType}',
        );

        // Handle different response structures
        List<dynamic> booksJson = [];

        if (data is List) {
          // Direct list response
          booksJson = data;
          debugPrint(
            'BooksService: Direct list response with ${booksJson.length} items',
          );
        } else if (data is Map<String, dynamic>) {
          // Check for nested structure: results.data
          if (data['results'] != null) {
            final results = data['results'];
            debugPrint(
              'BooksService: Found results field, type: ${results.runtimeType}',
            );

            if (results is Map<String, dynamic>) {
              // Nested structure: {results: {success: true, data: [...]}}
              booksJson = results['data'] ?? [];
              debugPrint(
                'BooksService: Extracted ${booksJson.length} books from results.data',
              );
            } else if (results is List) {
              // Direct list in results: {results: [...]}
              booksJson = results;
              debugPrint(
                'BooksService: Extracted ${booksJson.length} books from results list',
              );
            }
          } else {
            // Try other possible fields
            booksJson = data['books'] ?? data['data'] ?? [];
            debugPrint(
              'BooksService: Extracted ${booksJson.length} books from data/books field',
            );
          }
        }

        debugPrint(
          'BooksService: Successfully parsed ${booksJson.length} books',
        );
        return booksJson.map((json) => Book.fromJson(json)).toList();
      } else {
        final data = json.decode(response.body);
        _setError(data['message'] ?? 'Failed to load most popular books');
        return [];
      }
    } catch (e, stackTrace) {
      _setError('Network error: ${e.toString()}');
      debugPrint('BooksService: Error getting most popular books: $e');
      debugPrint('BooksService: Stack trace: $stackTrace');
      return [];
    }
  }

  // Get books available for purchase only
  Future<List<Book>> getPurchasingBooks({int limit = 10}) async {
    _clearError();

    try {
      final response = await ApiClient.get(
        '/library/books/purchasing/',
        queryParams: {'limit': limit.toString()},
        token: _token,
      );

      if (ApiClient.isSuccess(response)) {
        final data = json.decode(response.body);
        // Handle both list response and object with books/results field
        List<dynamic> booksJson = [];
        if (data is List) {
          booksJson = data;
        } else {
          booksJson = data['results'] ?? data['books'] ?? data['data'] ?? [];
        }
        return booksJson.map((json) => Book.fromJson(json)).toList();
      } else {
        final data = json.decode(response.body);
        _setError(data['message'] ?? 'Failed to load purchasing books');
        return [];
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('BooksService: Error getting purchasing books: $e');
      return [];
    }
  }

  // Get top-rated books
  // Returns ALL books with ratings, regardless of availability
  Future<List<Book>> getTopRatedBooks({int limit = 10}) async {
    _clearError();

    try {
      // Get top-rated books - backend now returns all books regardless of availability
      final response = await ApiClient.get(
        '/library/books/top-rated/',
        queryParams: {
          'limit': limit.toString(),
          'min_reviews': '1', // Minimum 1 review to be included
          'min_rating': '0.0', // No minimum rating - show all rated books
        },
        token: _token,
      );

      if (ApiClient.isSuccess(response)) {
        final data = json.decode(response.body);
        // Handle both list response and object with books/results field
        List<dynamic> booksJson = [];
        if (data is List) {
          booksJson = data;
        } else {
          booksJson = data['results'] ?? data['books'] ?? data['data'] ?? [];
        }
        return booksJson.map((json) => Book.fromJson(json)).toList();
      } else {
        final data = json.decode(response.body);
        _setError(data['message'] ?? 'Failed to load top-rated books');
        return [];
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('BooksService: Error getting top-rated books: $e');
      return [];
    }
  }

  // Get books by specific category using dedicated endpoint
  Future<List<Book>> _getBooksByCategory(
    String categoryId,
    int page,
    int limit,
  ) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      debugPrint(
        'BooksService: Getting books for category $categoryId with params: $queryParams',
      );
      debugPrint(
        'BooksService: Using token: ${_token != null ? '${_token!.substring(0, 20)}...' : 'null'}',
      );

      final response = await ApiClient.get(
        '/library/books/category/$categoryId/',
        queryParams: queryParams,
        token: _token,
      );

      debugPrint(
        'BooksService: Category API response status: ${response.statusCode}',
      );
      debugPrint('BooksService: Category API response body: ${response.body}');

      if (ApiClient.isSuccess(response)) {
        final data = json.decode(response.body);

        debugPrint('BooksService: Full API response: $data');
        debugPrint(
          'BooksService: Response type: ${data.runtimeType}, Keys: ${data is Map ? data.keys.toList() : 'N/A'}',
        );

        // Handle both paginated and non-paginated responses
        List<dynamic> booksJson = [];

        // Check if this is a paginated response (has 'count', 'next', 'previous', 'results')
        if (data['results'] != null && data['count'] != null) {
          // Standard DRF paginated response
          final results = data['results'];
          if (results is Map && results['data'] != null) {
            // Backend wrapped paginated response: {results: {data: [...], success: true, ...}}
            booksJson = results['data'] is List ? results['data'] : [];
            debugPrint(
              'BooksService: Found ${booksJson.length} books in paginated results.data',
            );
          } else if (results is List) {
            // Standard paginated response: {results: [...]}
            booksJson = results;
            debugPrint(
              'BooksService: Found ${booksJson.length} books in paginated results',
            );
          }
        } else if (data['data'] != null) {
          // Non-paginated response - check if data is a list or nested
          if (data['data'] is List) {
            booksJson = data['data'];
            debugPrint(
              'BooksService: Found ${booksJson.length} books in data field (List)',
            );
          } else if (data['data'] is Map && data['data']['data'] != null) {
            // Nested data structure
            booksJson = data['data']['data'] is List
                ? data['data']['data']
                : [];
            debugPrint(
              'BooksService: Found ${booksJson.length} books in nested data.data',
            );
          }
        } else if (data['books'] != null) {
          // Alternative field name
          booksJson = data['books'] is List ? data['books'] : [];
          debugPrint(
            'BooksService: Found ${booksJson.length} books in books field',
          );
        } else {
          debugPrint('BooksService: No books found in response data');
          debugPrint(
            'BooksService: Available keys in response: ${data is Map ? data.keys.toList() : 'N/A'}',
          );
        }

        debugPrint(
          'BooksService: Category API response successful, found ${booksJson.length} books',
        );

        if (booksJson.isEmpty) {
          debugPrint(
            'BooksService: WARNING - No books found in response for category $categoryId',
          );
          debugPrint(
            'BooksService: This might mean: 1) Category has no books, 2) Response structure mismatch, or 3) Filtering issue',
          );
        }

        // Parse each book and log the result
        final List<Book> books = [];
        for (int i = 0; i < booksJson.length; i++) {
          try {
            if (booksJson[i] is! Map<String, dynamic>) {
              debugPrint(
                'BooksService: Skipping book $i - not a Map, type: ${booksJson[i].runtimeType}',
              );
              continue;
            }
            final book = Book.fromJson(booksJson[i] as Map<String, dynamic>);
            books.add(book);
            debugPrint(
              'BooksService: Parsed book $i: "${book.title}" by ${book.author?.name ?? "Unknown"} (Category: ${book.category?.name ?? "Unknown"})',
            );
          } catch (e, stackTrace) {
            debugPrint('BooksService: Error parsing book $i: $e');
            debugPrint('BooksService: Stack trace: $stackTrace');
            debugPrint('BooksService: Book data: ${booksJson[i]}');
          }
        }

        debugPrint(
          'BooksService: Successfully parsed ${books.length} out of ${booksJson.length} books',
        );
        if (books.length != booksJson.length) {
          debugPrint(
            'BooksService: WARNING - Some books failed to parse (${booksJson.length - books.length} failed)',
          );
        }
        return books;
      } else {
        final data = json.decode(response.body);
        debugPrint(
          'BooksService: Category API response failed: ${response.statusCode} - ${data['message'] ?? 'Unknown error'}',
        );
        _setError(data['message'] ?? 'Failed to load books for category');
        return [];
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('BooksService: Error getting books by category: $e');
      return [];
    }
  }

  // Get book by ID
  Future<Book?> getBookById(String bookId) async {
    _clearError();

    try {
      final response = await ApiClient.get(
        '/library/books/$bookId/',
        token: _token,
      );

      if (ApiClient.isSuccess(response)) {
        final data = json.decode(response.body);
        return Book.fromJson(data);
      } else {
        final data = json.decode(response.body);
        _setError(data['message'] ?? 'Failed to load book details');
        return null;
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('BooksService: Error getting book by ID: $e');
      return null;
    }
  }

  // Search books
  Future<List<Book>> searchBooks({
    required String query,
    int page = 1,
    int limit = 20,
    String? category,
    String? author,
  }) async {
    _clearError();

    try {
      final queryParams = <String, String>{
        'q': query,
        'page': page.toString(),
        'limit': limit.toString(),
        if (category != null && category.isNotEmpty) 'category': category,
        if (author != null && author.isNotEmpty) 'author': author,
      };

      final response = await ApiClient.get(
        '/library/books/search/',
        queryParams: queryParams,
        token: _token,
      );

      if (ApiClient.isSuccess(response)) {
        final data = json.decode(response.body);
        final List<dynamic> booksJson = data['results'] ?? data['books'] ?? [];
        return booksJson.map((json) => Book.fromJson(json)).toList();
      } else {
        final data = json.decode(response.body);
        _setError(data['message'] ?? 'Failed to search books');
        return [];
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('BooksService: Error searching books: $e');
      return [];
    }
  }

  // Get books by category
  Future<List<Book>> getBooksByCategory({
    required String categoryId,
    int page = 1,
    int limit = 20,
  }) async {
    _clearError();

    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      final response = await ApiClient.get(
        '/library/books/category/$categoryId/',
        queryParams: queryParams,
        token: _token,
      );

      if (ApiClient.isSuccess(response)) {
        final data = json.decode(response.body);
        final List<dynamic> booksJson = data['results'] ?? data['books'] ?? [];
        return booksJson.map((json) => Book.fromJson(json)).toList();
      } else {
        final data = json.decode(response.body);
        _setError(data['message'] ?? 'Failed to load books by category');
        return [];
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('BooksService: Error getting books by category: $e');
      return [];
    }
  }

  // Get books by author
  Future<List<Book>> getBooksByAuthor({
    required String authorId,
    int page = 1,
    int limit = 20,
  }) async {
    _clearError();

    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      final response = await ApiClient.get(
        '/library/books/author/$authorId/',
        queryParams: queryParams,
        token: _token,
      );

      if (ApiClient.isSuccess(response)) {
        final data = json.decode(response.body);
        debugPrint('BooksService: Raw API response: $data');

        // Handle different response formats
        List<dynamic> booksJson = [];

        if (data is List) {
          // Direct array response
          booksJson = data;
          debugPrint(
            'BooksService: Direct array response with ${booksJson.length} books',
          );
        } else if (data is Map<String, dynamic>) {
          // Check for paginated response
          booksJson = data['results'] ?? data['books'] ?? data['data'] ?? [];
          debugPrint(
            'BooksService: Map response with ${booksJson.length} books',
          );
        }

        final books = booksJson.map((json) => Book.fromJson(json)).toList();
        debugPrint('BooksService: Parsed ${books.length} books');
        return books;
      } else {
        final data = json.decode(response.body);
        _setError(data['message'] ?? 'Failed to load books by author');
        return [];
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('BooksService: Error getting books by author: $e');
      return [];
    }
  }

  // Get book recommendations
  Future<List<Book>> getRecommendations({
    String? token,
    String? bookId,
    int limit = 10,
  }) async {
    _clearError();

    try {
      final response = await ApiClient.get(
        '/library/books/recommendations/',
        queryParams: {
          'limit': limit.toString(),
          if (bookId != null && bookId.isNotEmpty) 'book_id': bookId,
        },
        token: _token,
      );

      if (ApiClient.isSuccess(response)) {
        final data = json.decode(response.body);
        final List<dynamic> booksJson = data['results'] ?? data['books'] ?? [];
        return booksJson.map((json) => Book.fromJson(json)).toList();
      } else {
        final data = json.decode(response.body);
        _setError(data['message'] ?? 'Failed to load recommendations');
        return [];
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('BooksService: Error getting recommendations: $e');
      return [];
    }
  }

  // Get book availability
  Future<bool> checkAvailability(String bookId) async {
    _clearError();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/library/books/$bookId/availability/'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['available'] ?? false;
      } else {
        final data = json.decode(response.body);
        _setError(data['message'] ?? 'Failed to check availability');
        return false;
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('BooksService: Error checking availability: $e');
      return false;
    }
  }

  // Get books with discounts/offers
  Future<List<Book>> getBooksWithOffers({int limit = 10}) async {
    _clearError();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/library/books/offers/?limit=$limit'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> booksJson = data['results'] ?? data['books'] ?? [];
        return booksJson.map((json) => Book.fromJson(json)).toList();
      } else {
        final data = json.decode(response.body);
        _setError(data['message'] ?? 'Failed to load books with offers');
        return [];
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('BooksService: Error getting books with offers: $e');
      return [];
    }
  }

  // Get single book by ID
  Future<Book?> getBook(String bookId) async {
    _clearError();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/library/books/$bookId/'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Book.fromJson(data);
      }
      return null;
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('BooksService: Error getting book: $e');
      return null;
    }
  }

  // Create book (admin only)
  Future<Book?> createBook(Map<String, dynamic> bookData) async {
    _clearError();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/library/books/create/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(bookData),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return Book.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('BooksService: Error creating book: $e');
      return null;
    }
  }

  // Update book (admin only)
  Future<Book?> updateBook(String bookId, Map<String, dynamic> bookData) async {
    _clearError();

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/library/books/$bookId/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(bookData),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Book.fromJson(data);
      }
      return null;
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('BooksService: Error updating book: $e');
      return null;
    }
  }

  // Delete book (admin only)
  Future<bool> deleteBook(String bookId) async {
    _clearError();

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/library/books/$bookId/'),
        headers: {'Content-Type': 'application/json'},
      );

      return response.statusCode == 204;
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('BooksService: Error deleting book: $e');
      return false;
    }
  }

  // Author management methods
  Future<List<dynamic>> getAuthors({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    _clearError();

    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
      };

      final response = await ApiClient.get(
        '/library/authors/',
        queryParams: queryParams,
        token: _token,
      );

      if (ApiClient.isSuccess(response)) {
        final data = json.decode(response.body);
        debugPrint(
          'BooksService getAuthors: Response data structure: ${data is Map ? data.keys.toList() : data.runtimeType}',
        );

        // Handle both paginated and non-paginated responses
        List<dynamic> authorsJson = [];
        if (data['data'] != null) {
          // Check if data is a list or contains nested data
          if (data['data'] is List) {
            authorsJson = data['data'];
            debugPrint(
              'BooksService getAuthors: Found ${authorsJson.length} authors in data array',
            );
          } else if (data['data']['data'] != null) {
            // Paginated response with nested data
            authorsJson = data['data']['data'] is List
                ? data['data']['data']
                : [];
            debugPrint(
              'BooksService getAuthors: Found ${authorsJson.length} authors in nested data',
            );
          } else if (data['data'] is Map) {
            // Single author object wrapped in data
            authorsJson = [data['data']];
            debugPrint(
              'BooksService getAuthors: Found single author in data object',
            );
          }
        } else if (data['results'] != null) {
          authorsJson = data['results'];
          debugPrint(
            'BooksService getAuthors: Found ${authorsJson.length} authors in results',
          );
        } else if (data is List) {
          // Direct list response
          authorsJson = data;
          debugPrint(
            'BooksService getAuthors: Found ${authorsJson.length} authors in direct list',
          );
        } else {
          debugPrint(
            'BooksService getAuthors: Warning - No authors found in response',
          );
          debugPrint('BooksService getAuthors: Response structure: $data');
        }

        debugPrint(
          'BooksService getAuthors: Returning ${authorsJson.length} authors',
        );
        return authorsJson;
      } else {
        final data = json.decode(response.body);
        _setError(data['message'] ?? 'Failed to load authors');
        return [];
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('BooksService: Error getting authors: $e');
      return [];
    }
  }

  Future<dynamic> createAuthor(Map<String, dynamic> authorData) async {
    _clearError();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/library/authors/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(authorData),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('BooksService: Error creating author: $e');
      return null;
    }
  }

  Future<dynamic> updateAuthor(
    String authorId,
    Map<String, dynamic> authorData,
  ) async {
    _clearError();

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/library/authors/$authorId/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(authorData),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('BooksService: Error updating author: $e');
      return null;
    }
  }

  Future<bool> deleteAuthor(String authorId) async {
    _clearError();

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/library/authors/$authorId/'),
        headers: {'Content-Type': 'application/json'},
      );

      return response.statusCode == 204;
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('BooksService: Error deleting author: $e');
      return false;
    }
  }

  // Category management methods
  Future<List<book_category.Category>> getCategories({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    _clearError();

    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
      };

      final response = await ApiClient.get(
        '/library/categories/',
        queryParams: queryParams,
        token: _token,
      );

      if (ApiClient.isSuccess(response)) {
        final data = json.decode(response.body);
        debugPrint(
          'BooksService getCategories: Response data structure: ${data is Map ? data.keys.toList() : data.runtimeType}',
        );

        // Handle both paginated and non-paginated responses
        List<dynamic> categoriesJson = [];
        if (data['data'] != null) {
          // Check if data is a list or contains nested data
          if (data['data'] is List) {
            categoriesJson = data['data'];
            debugPrint(
              'BooksService getCategories: Found ${categoriesJson.length} categories in data array',
            );
          } else if (data['data']['data'] != null) {
            // Paginated response with nested data
            categoriesJson = data['data']['data'] is List
                ? data['data']['data']
                : [];
            debugPrint(
              'BooksService getCategories: Found ${categoriesJson.length} categories in nested data',
            );
          } else if (data['data'] is Map) {
            // Single category object wrapped in data
            categoriesJson = [data['data']];
            debugPrint(
              'BooksService getCategories: Found single category in data object',
            );
          }
        } else if (data['results'] != null) {
          categoriesJson = data['results'];
          debugPrint(
            'BooksService getCategories: Found ${categoriesJson.length} categories in results',
          );
        } else if (data is List) {
          // Direct list response
          categoriesJson = data;
          debugPrint(
            'BooksService getCategories: Found ${categoriesJson.length} categories in direct list',
          );
        } else {
          debugPrint(
            'BooksService getCategories: Warning - No categories found in response',
          );
          debugPrint('BooksService getCategories: Response structure: $data');
        }

        final categories = categoriesJson
            .map((json) => book_category.Category.fromJson(json))
            .toList();
        debugPrint(
          'BooksService getCategories: Parsed ${categories.length} categories successfully',
        );
        return categories;
      } else {
        final data = json.decode(response.body);
        _setError(data['message'] ?? 'Failed to load categories');
        return [];
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('BooksService: Error getting categories: $e');
      return [];
    }
  }

  Future<book_category.Category?> createCategory(
    Map<String, dynamic> categoryData,
  ) async {
    _clearError();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/library/categories/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(categoryData),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return book_category.Category.fromJson(data);
      }
      return null;
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('BooksService: Error creating category: $e');
      return null;
    }
  }

  Future<book_category.Category?> updateCategory(
    String categoryId,
    Map<String, dynamic> categoryData,
  ) async {
    _clearError();

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/library/categories/$categoryId/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(categoryData),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return book_category.Category.fromJson(data);
      }
      return null;
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('BooksService: Error updating category: $e');
      return null;
    }
  }

  Future<bool> deleteCategory(String categoryId) async {
    _clearError();

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/library/categories/$categoryId/'),
        headers: {'Content-Type': 'application/json'},
      );

      return response.statusCode == 204;
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('BooksService: Error deleting category: $e');
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

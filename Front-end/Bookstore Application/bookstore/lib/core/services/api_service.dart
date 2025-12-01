import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show debugPrint;
import '../../features/auth/models/user.dart';
import '../../features/books/models/book.dart';
import '../../features/books/models/category.dart';
import '../../features/books/models/author.dart';
import '../../features/books/models/books_response.dart';

import 'api_config.dart';

class ApiService {
  // Update this with your actual backend URL
  // Use 10.0.2.2 for Android emulator, 127.0.0.1 for Windows development
  static String get baseUrl => ApiConfig.getBaseUrl();

  // Headers for HTTP requests
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Map<String, String> _headersWithAuth(String token) => {
    ..._headers,
    'Authorization': 'Bearer $token',
  };

  // Authentication endpoints
  static Future<AuthResponse> register(RegisterRequest request) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/register/'),
        headers: _headers,
        body: json.encode(request.toJson()),
      );

      final data = json.decode(response.body);
      debugPrint(
        'ApiService: Registration response - Status: ${response.statusCode}, Body: $data',
      );

      if (response.statusCode == 201 && data['success'] == true) {
        // Registration successful - parse Django response format
        final responseData = data['data'];

        debugPrint(
          'ApiService: Registration successful - parsing response data: $responseData',
        );

        // For registration, we don't need tokens - user will login separately
        final authResponse = AuthResponse(
          token: null, // No token on registration
          refresh: null, // No refresh token on registration
          user: User(
            id: responseData['user_id'],
            email: responseData['email'],
            firstName: responseData['full_name']?.split(' ')[0] ?? '',
            lastName:
                responseData['full_name']?.split(' ').skip(1).join(' ') ?? '',
            userType: responseData['user_type'],
            preferredLanguage: 'en', // Default language
            dateJoined: DateTime.now().toIso8601String(),
            isActive: true,
          ),
          message: data['message'],
        );

        debugPrint(
          'ApiService: Created AuthResponse - isSuccess: ${authResponse.isSuccess}, user: ${authResponse.user}, message: ${authResponse.message}',
        );

        return authResponse;
      } else {
        return AuthResponse(
          message: data['message'] ?? 'Registration failed',
          errors: data is Map<String, dynamic> ? data : null,
        );
      }
    } catch (e) {
      return AuthResponse(message: 'Network error: ${e.toString()}');
    }
  }

  static Future<AuthResponse> login(LoginRequest request) async {
    try {
      debugPrint(
        '🚀 ApiService: Sending login request to $baseUrl/users/login/',
      );
      debugPrint(
        '🚀 ApiService: Request body: ${json.encode(request.toJson())}',
      );

      final response = await http.post(
        Uri.parse('$baseUrl/users/login/'),
        headers: _headers,
        body: json.encode(request.toJson()),
      );

      debugPrint('🚀 ApiService: Response status code: ${response.statusCode}');
      debugPrint('🚀 ApiService: Response headers: ${response.headers}');
      debugPrint('🚀 ApiService: Response body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        debugPrint('🚀 ApiService: Login successful, parsing response data');
        // Parse Django response format
        final responseData = data['data'];

        // Handle full_name parsing more safely
        String firstName = 'User';
        String lastName = '';

        if (responseData['full_name'] != null) {
          final nameParts = responseData['full_name'].toString().split(' ');
          firstName = nameParts.isNotEmpty ? nameParts[0] : 'User';
          lastName = nameParts.length > 1 ? nameParts.skip(1).join(' ') : '';
        }

        final authResponse = AuthResponse(
          token: responseData['access_token'],
          refresh: responseData['refresh_token'],
          user: User(
            id: responseData['user_id'],
            email: responseData['email'],
            firstName: firstName,
            lastName: lastName,
            userType: responseData['user_type'],
            preferredLanguage: 'en', // Default language
            dateJoined: DateTime.now().toIso8601String(),
            isActive: true,
          ),
          message: data['message'],
        );

        debugPrint(
          '🚀 ApiService: Created AuthResponse - isSuccess: ${authResponse.isSuccess}',
        );
        debugPrint('🚀 ApiService: Token: ${authResponse.token}');
        debugPrint('🚀 ApiService: User: ${authResponse.user}');
        return authResponse;
      } else {
        debugPrint(
          '🚀 ApiService: Login failed - Status: ${response.statusCode}, Success: ${data['success']}',
        );
        return AuthResponse(
          message: data['message'] ?? 'Login failed',
          errors: data is Map<String, dynamic> ? data : null,
        );
      }
    } catch (e) {
      debugPrint('🚀 ApiService: Exception during login: $e');
      return AuthResponse(message: 'Network error: ${e.toString()}');
    }
  }

  static Future<User?> getUserProfile(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/profile/'),
        headers: _headersWithAuth(token),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return User.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  // Books endpoints
  static Future<BooksResponse?> getBooks({
    String? token,
    int page = 1,
    String? search,
    int? categoryId,
    String? authorName,
  }) async {
    try {
      var uri = Uri.parse('$baseUrl/library/books/');

      // Add query parameters
      Map<String, String> queryParams = {'page': page.toString()};

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (categoryId != null) {
        queryParams['category'] = categoryId.toString();
      }
      if (authorName != null && authorName.isNotEmpty) {
        queryParams['author_name'] = authorName;
      }

      uri = uri.replace(queryParameters: queryParams);

      final headers = token != null ? _headersWithAuth(token) : _headers;

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return BooksResponse.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting books: $e');
      return null;
    }
  }

  static Future<Book?> getBookDetail(int bookId, {String? token}) async {
    try {
      final headers = token != null ? _headersWithAuth(token) : _headers;

      final response = await http.get(
        Uri.parse('$baseUrl/library/books/$bookId/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Book.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting book detail: $e');
      return null;
    }
  }

  static Future<List<Category>> getCategories({String? token}) async {
    try {
      final headers = token != null ? _headersWithAuth(token) : _headers;

      final response = await http.get(
        Uri.parse('$baseUrl/library/categories/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> categoriesData = data['results'] ?? data;
        return categoriesData.map((json) => Category.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting categories: $e');
      return [];
    }
  }

  static Future<List<Author>> getAuthors({String? token}) async {
    try {
      final headers = token != null ? _headersWithAuth(token) : _headers;

      final response = await http.get(
        Uri.parse('$baseUrl/library/authors/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> authorsData = data['results'] ?? data;
        return authorsData.map((json) => Author.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting authors: $e');
      return [];
    }
  }

  static Future<BooksResponse?> getNewBooks({
    String? token,
    int page = 1,
  }) async {
    try {
      var uri = Uri.parse('$baseUrl/library/books/new/');
      uri = uri.replace(queryParameters: {'page': page.toString()});

      final headers = token != null ? _headersWithAuth(token) : _headers;

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return BooksResponse.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting new books: $e');
      return null;
    }
  }

  static Future<BooksResponse?> getBooksByCategory(
    int categoryId, {
    String? token,
    int page = 1,
  }) async {
    try {
      var uri = Uri.parse('$baseUrl/library/books/category/$categoryId/');
      uri = uri.replace(queryParameters: {'page': page.toString()});

      final headers = token != null ? _headersWithAuth(token) : _headers;

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return BooksResponse.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting books by category: $e');
      return null;
    }
  }

  // Utility method to check if the backend is reachable
  static Future<bool> checkConnection() async {
    try {
      debugPrint('🔍 ApiService: Checking connection to $baseUrl');
      debugPrint(
        '🔍 ApiService: Testing endpoint: $baseUrl/users/register/user-types/',
      );

      final response = await http
          .get(
            Uri.parse('$baseUrl/users/register/user-types/'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 5));

      debugPrint(
        '🔍 ApiService: Connection check - Status: ${response.statusCode}',
      );
      debugPrint(
        '🔍 ApiService: Connection check - Headers: ${response.headers}',
      );
      debugPrint('🔍 ApiService: Connection check - Body: ${response.body}');

      final isSuccess = response.statusCode == 200;
      debugPrint('🔍 ApiService: Connection check result: $isSuccess');

      return isSuccess;
    } catch (e) {
      debugPrint('🔍 ApiService: Connection check failed: $e');
      debugPrint('🔍 ApiService: Error type: ${e.runtimeType}');
      return false;
    }
  }

  // Test login with hardcoded credentials
  static Future<bool> testLogin() async {
    try {
      debugPrint('ApiService: Testing login endpoint...');
      final testRequest = LoginRequest(
        email: 'test@example.com',
        password: 'testpassword',
      );

      final response = await login(testRequest);
      debugPrint(
        'ApiService: Test login response - isSuccess: ${response.isSuccess}',
      );
      debugPrint(
        'ApiService: Test login response - message: ${response.message}',
      );
      return response.isSuccess;
    } catch (e) {
      debugPrint('ApiService: Test login failed: $e');
      return false;
    }
  }

  // Method to get user type options for registration
  static Future<List<Map<String, String>>> getUserTypeOptions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/register/user-types/'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final Map<String, dynamic> userTypesData = data['data']['user_types'];
          final List<Map<String, String>> options = [];

          // Convert the backend response format to frontend format
          // Only include available user types
          userTypesData.forEach((key, value) {
            if (value['available'] == true) {
              options.add({
                'value': value['value'].toString(),
                'label': value['label'].toString(),
              });
            }
          });

          return options;
        }
      }

      // Fallback to default options if API fails
      return [
        {'value': 'customer', 'label': 'Customer'},
        {'value': 'library_admin', 'label': 'Library Administrator'},
        {'value': 'delivery_admin', 'label': 'Delivery Administrator'},
      ];
    } catch (e) {
      debugPrint('Error getting user type options: $e');
      // Return default options
      return [
        {'value': 'customer', 'label': 'Customer'},
        {'value': 'library_admin', 'label': 'Library Administrator'},
        {'value': 'delivery_admin', 'label': 'Delivery Administrator'},
      ];
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'api_config.dart';

/// Centralized API client for handling base URL and common headers
class ApiClient {
  /// Callback function to refresh token when 401 is received
  /// Should return the new access token, or null if refresh failed
  static Future<String?> Function()? onTokenRefresh;

  /// Get the base URL for API calls
  static String get baseUrl => ApiConfig.getBaseUrl();

  /// Get standard headers for API requests
  static Map<String, String> get headers => ApiConfig.getStandardHeaders();

  /// Get headers with authorization token
  static Map<String, String> getHeadersWithAuth(String token) =>
      ApiConfig.addAuthHeader(headers, token);

  /// Make a GET request
  static Future<http.Response> get(
    String endpoint, {
    Map<String, String>? queryParams,
    String? token,
  }) async {
    try {
      var uri = Uri.parse('$baseUrl$endpoint');

      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }

      var response = await http.get(
        uri,
        headers: token != null ? getHeadersWithAuth(token) : headers,
      );

      // Handle 401 Unauthorized - try to refresh token
      if (response.statusCode == 401 &&
          token != null &&
          onTokenRefresh != null) {
        debugPrint('ApiClient: Received 401, attempting token refresh...');
        final newToken = await onTokenRefresh!();
        if (newToken != null) {
          debugPrint('ApiClient: Token refreshed, retrying request...');
          response = await http.get(uri, headers: getHeadersWithAuth(newToken));
        }
      }

      _logRequest('GET', uri.toString(), response);
      return response;
    } catch (e) {
      debugPrint('ApiClient GET error: $e');
      rethrow;
    }
  }

  /// Make a POST request
  static Future<http.Response> post(
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    try {
      final url = '$baseUrl$endpoint';
      debugPrint('=== API CLIENT POST REQUEST ===');
      debugPrint('ApiClient: Making POST request to: $url');
      debugPrint('ApiClient: Base URL: $baseUrl');
      debugPrint('ApiClient: Endpoint: $endpoint');
      debugPrint(
        'ApiClient: Request body: ${body != null ? json.encode(body) : null}',
      );
      debugPrint(
        'ApiClient: Headers: ${token != null ? getHeadersWithAuth(token) : headers}',
      );
      debugPrint('=== END API CLIENT POST REQUEST ===');

      var response = await http.post(
        Uri.parse(url),
        headers: token != null ? getHeadersWithAuth(token) : headers,
        body: body != null ? json.encode(body) : null,
      );

      // Handle 401 Unauthorized - try to refresh token
      if (response.statusCode == 401 &&
          token != null &&
          onTokenRefresh != null) {
        debugPrint('ApiClient: Received 401, attempting token refresh...');
        final newToken = await onTokenRefresh!();
        if (newToken != null) {
          debugPrint('ApiClient: Token refreshed, retrying request...');
          response = await http.post(
            Uri.parse(url),
            headers: getHeadersWithAuth(newToken),
            body: body != null ? json.encode(body) : null,
          );
        }
      }

      debugPrint(
        'ApiClient: Response received - Status: ${response.statusCode}',
      );
      debugPrint('ApiClient: Response body: ${response.body}');

      _logRequest('POST', url, response, body: body);
      return response;
    } catch (e) {
      debugPrint('ApiClient POST error: $e');
      debugPrint('ApiClient POST error type: ${e.runtimeType}');
      rethrow;
    }
  }

  /// Make a PUT request
  static Future<http.Response> put(
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    try {
      var response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: token != null ? getHeadersWithAuth(token) : headers,
        body: body != null ? json.encode(body) : null,
      );

      // Handle 401 Unauthorized - try to refresh token
      if (response.statusCode == 401 &&
          token != null &&
          onTokenRefresh != null) {
        debugPrint('ApiClient: Received 401, attempting token refresh...');
        final newToken = await onTokenRefresh!();
        if (newToken != null) {
          debugPrint('ApiClient: Token refreshed, retrying request...');
          response = await http.put(
            Uri.parse('$baseUrl$endpoint'),
            headers: getHeadersWithAuth(newToken),
            body: body != null ? json.encode(body) : null,
          );
        }
      }

      _logRequest('PUT', '$baseUrl$endpoint', response, body: body);
      return response;
    } catch (e) {
      debugPrint('ApiClient PUT error: $e');
      rethrow;
    }
  }

  /// Make a PATCH request
  static Future<http.Response> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    try {
      var response = await http.patch(
        Uri.parse('$baseUrl$endpoint'),
        headers: token != null ? getHeadersWithAuth(token) : headers,
        body: body != null ? json.encode(body) : null,
      );

      // Handle 401 Unauthorized - try to refresh token
      if (response.statusCode == 401 &&
          token != null &&
          onTokenRefresh != null) {
        debugPrint('ApiClient: Received 401, attempting token refresh...');
        final newToken = await onTokenRefresh!();
        if (newToken != null) {
          debugPrint('ApiClient: Token refreshed, retrying request...');
          response = await http.patch(
            Uri.parse('$baseUrl$endpoint'),
            headers: getHeadersWithAuth(newToken),
            body: body != null ? json.encode(body) : null,
          );
        }
      }

      _logRequest('PATCH', '$baseUrl$endpoint', response);
      return response;
    } catch (e) {
      debugPrint('ApiClient PATCH error: $e');
      rethrow;
    }
  }

  /// Make a DELETE request
  static Future<http.Response> delete(String endpoint, {String? token}) async {
    try {
      var response = await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: token != null ? getHeadersWithAuth(token) : headers,
      );

      // Handle 401 Unauthorized - try to refresh token
      if (response.statusCode == 401 &&
          token != null &&
          onTokenRefresh != null) {
        debugPrint('ApiClient: Received 401, attempting token refresh...');
        final newToken = await onTokenRefresh!();
        if (newToken != null) {
          debugPrint('ApiClient: Token refreshed, retrying request...');
          response = await http.delete(
            Uri.parse('$baseUrl$endpoint'),
            headers: getHeadersWithAuth(newToken),
          );
        }
      }

      _logRequest('DELETE', '$baseUrl$endpoint', response);
      return response;
    } catch (e) {
      debugPrint('ApiClient DELETE error: $e');
      rethrow;
    }
  }

  /// Handle API response and return parsed data
  static dynamic handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = json.decode(response.body);
        // Return the decoded data as-is, whether it's a Map, List, or other type
        return decoded;
      } catch (e) {
        debugPrint('Error parsing JSON response: $e');
        debugPrint('Response body: ${response.body}');
        return {'error': 'Invalid JSON response'};
      }
    } else {
      try {
        final errorData = json.decode(response.body);
        if (errorData is Map<String, dynamic>) {
          return {
            'error': errorData['message'] ?? 'Request failed',
            'status_code': response.statusCode,
            'details': errorData,
          };
        } else {
          return {
            'error': 'Request failed with status ${response.statusCode}',
            'status_code': response.statusCode,
            'details': errorData,
          };
        }
      } catch (e) {
        return {
          'error': 'Request failed with status ${response.statusCode}',
          'status_code': response.statusCode,
        };
      }
    }
  }

  /// Check if response indicates success
  static bool isSuccess(http.Response response) {
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  /// Log request details for debugging
  static void _logRequest(
    String method,
    String url,
    http.Response response, {
    Map<String, dynamic>? body,
  }) {
    if (kDebugMode) {
      debugPrint('=== API Request ===');
      debugPrint('$method $url');
      debugPrint('Status: ${response.statusCode}');
      debugPrint('Headers: ${response.headers}');
      if (body != null) {
        debugPrint('Body: ${json.encode(body)}');
      }
      debugPrint('Response: ${response.body}');
      debugPrint('==================');
    }
  }

  /// Test API connectivity
  static Future<bool> testConnectivity() async {
    try {
      // Test with the login endpoint - now handles GET requests gracefully
      final response = await http.get(
        Uri.parse('$baseUrl/login/'),
        headers: headers,
      );
      debugPrint('API Connectivity Test: ${response.statusCode}');
      // Accept 200 (success), 401 (unauthorized), or 405 (method not allowed but server reachable)
      return response.statusCode == 200 ||
          response.statusCode == 401 ||
          response.statusCode == 405;
    } catch (e) {
      debugPrint('API Connectivity Test Failed: $e');
      return false;
    }
  }
}

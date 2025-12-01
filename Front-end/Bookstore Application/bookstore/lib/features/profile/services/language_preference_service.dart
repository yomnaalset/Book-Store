import 'dart:convert';
import 'package:http/http.dart' as http;

class LanguagePreferenceService {
  final String baseUrl;

  LanguagePreferenceService({required this.baseUrl});

  // Get available language options
  Future<Map<String, dynamic>> getLanguageOptions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/preferences/languages/'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception(
          'Failed to load language options: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error loading language options: $e');
    }
  }

  // Get current user's language preference
  Future<Map<String, dynamic>> getCurrentLanguagePreference(
    String token,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/preferences/settings/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Extract language preference from the comprehensive preferences
        if (data['success'] == true && data['data'] != null) {
          final preferences = data['data'];
          return {
            'success': true,
            'data': {
              'preferred_language': preferences['preferred_language'] ?? 'en',
            },
          };
        }
        return data;
      } else {
        throw Exception(
          'Failed to load language preference: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error loading language preference: $e');
    }
  }

  // Update user's language preference
  Future<Map<String, dynamic>> updateLanguagePreference(
    String token,
    String language,
  ) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/preferences/settings/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'preferred_language': language}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
          errorData['message'] ?? 'Failed to update language preference',
        );
      }
    } catch (e) {
      throw Exception('Error updating language preference: $e');
    }
  }

  // Get application language information
  Future<Map<String, dynamic>> getApplicationLanguageInfo() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/preferences/languages/'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception(
          'Failed to load application language info: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error loading application language info: $e');
    }
  }
}

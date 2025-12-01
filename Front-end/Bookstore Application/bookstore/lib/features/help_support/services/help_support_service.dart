import 'dart:convert';
import 'package:http/http.dart' as http;

class HelpSupportService {
  final String baseUrl;

  HelpSupportService({required this.baseUrl});

  // Get all help and support data
  Future<Map<String, dynamic>> getAllHelpSupportData(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/help-support/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception(
          'Failed to load help and support data: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error loading help and support data: $e');
    }
  }

  // Get FAQs by category
  Future<Map<String, dynamic>> getFAQs({
    String? category,
    String? token,
  }) async {
    try {
      String url = '$baseUrl/users/help-support/faqs/';
      if (category != null) {
        url += '?category=$category';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Failed to load FAQs: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading FAQs: $e');
    }
  }

  // Get user guides by section
  Future<Map<String, dynamic>> getUserGuides({
    String? section,
    String? token,
  }) async {
    try {
      String url = '$baseUrl/users/help-support/user-guides/';
      if (section != null) {
        url += '?section=$section';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Failed to load user guides: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading user guides: $e');
    }
  }

  // Get troubleshooting guides by category
  Future<Map<String, dynamic>> getTroubleshootingGuides({
    String? category,
    String? token,
  }) async {
    try {
      String url = '$baseUrl/users/help-support/troubleshooting/';
      if (category != null) {
        url += '?category=$category';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception(
          'Failed to load troubleshooting guides: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error loading troubleshooting guides: $e');
    }
  }

  // Get support contacts
  Future<Map<String, dynamic>> getSupportContacts(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/help-support/contacts/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception(
          'Failed to load support contacts: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error loading support contacts: $e');
    }
  }
}

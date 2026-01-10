import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ProfileService {
  final String baseUrl;
  String? _errorMessage;

  ProfileService({required this.baseUrl});

  String? get errorMessage => _errorMessage;

  // Test connectivity to the backend
  Future<bool> testConnectivity() async {
    try {
      debugPrint('=== CONNECTIVITY TEST DEBUG START ===');
      debugPrint('DEBUG: Testing connectivity to: $baseUrl');
      // Use a public endpoint that supports GET requests without authentication
      final url = '$baseUrl/users/languages/';
      debugPrint('DEBUG: Full URL: $url');

      debugPrint('DEBUG: Making GET request...');
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );
      debugPrint('DEBUG: Connectivity test response: ${response.statusCode}');
      debugPrint('DEBUG: Response body: ${response.body}');
      debugPrint('=== CONNECTIVITY TEST DEBUG END ===');

      // Any 2xx or 4xx response indicates the server is reachable
      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (e) {
      debugPrint('=== CONNECTIVITY TEST ERROR ===');
      debugPrint('DEBUG: Connectivity test failed: $e');
      debugPrint('DEBUG: Error type: ${e.runtimeType}');
      return false;
    }
  }

  // Get user profile from server
  Future<bool> getProfile(String token) async {
    _clearError();

    // Validate token before making API call
    if (token.isEmpty || token.length < 20) {
      debugPrint('ProfileService: Invalid token - skipping profile API call');
      _setError('Authentication token is invalid or missing');
      return false;
    }

    try {
      final url = '$baseUrl/users/profile/';
      debugPrint('=== PROFILE API CALL START ===');
      debugPrint('ProfileService: Making GET request to: $url');
      debugPrint('ProfileService: Using token: ${token.substring(0, 20)}...');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint(
        'ProfileService: GET profile response status: ${response.statusCode}',
      );
      debugPrint('ProfileService: GET profile response body: ${response.body}');
      debugPrint('=== PROFILE API CALL END ===');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('ProfileService: Parsed response data: $data');
        debugPrint('ProfileService: Success field: ${data['success']}');
        debugPrint('ProfileService: Message field: ${data['message']}');

        if (data['success'] == true) {
          debugPrint('ProfileService: Profile retrieved successfully');
          return true;
        } else {
          debugPrint(
            'ProfileService: Profile retrieval failed - ${data['message']}',
          );
          _setError(data['message'] ?? 'Failed to get profile');
          return false;
        }
      } else {
        debugPrint(
          'ProfileService: HTTP error - Status: ${response.statusCode}',
        );
        _setError('Failed to get profile: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _setError('Error getting profile: ${e.toString()}');
      return false;
    }
  }

  // Update user profile using PATCH for partial updates
  Future<bool> updateProfile(
    String token,
    Map<String, dynamic> profileData, {
    String? userType,
  }) async {
    _clearError();

    try {
      // Filter out empty strings and null values to send only changed fields
      final Map<String, dynamic> filteredData = {};
      profileData.forEach((key, value) {
        if (value != null && value.toString().trim().isNotEmpty) {
          filteredData[key] = value;
        } else if (value == null || value.toString().trim().isEmpty) {
          // For optional fields, send null to clear them
          if ([
            'phone_number',
            'address',
            'city',
            'zip_code',
            'country',
            'date_of_birth',
          ].contains(key)) {
            filteredData[key] = null;
          }
        }
      });

      // Choose endpoint based on user type
      String endpoint = '$baseUrl/users/profile/';
      if (userType == 'library_admin') {
        endpoint = '$baseUrl/users/library-manager/profile/';
      }

      debugPrint('ProfileService: Making PATCH request to $endpoint');
      debugPrint('ProfileService: User type: $userType');
      debugPrint('ProfileService: Original data: ${json.encode(profileData)}');
      debugPrint('ProfileService: Filtered data: ${json.encode(filteredData)}');
      debugPrint('ProfileService: Token: ${token.substring(0, 20)}...');

      final response = await http.patch(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(filteredData),
      );

      debugPrint('ProfileService: Response status: ${response.statusCode}');
      debugPrint('ProfileService: Response body: ${response.body}');

      // Check if response is HTML (error page)
      if (response.body.trim().startsWith('<!DOCTYPE html>') ||
          response.body.trim().startsWith('<html')) {
        _setError(
          'Server error: Received HTML response instead of JSON. Please check your authentication.',
        );
        debugPrint(
          'ProfileService: Received HTML response: ${response.body.substring(0, 200)}...',
        );
        return false;
      }

      // Handle different response status codes
      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final data = json.decode(response.body);
          debugPrint(
            'ProfileService: Profile updated successfully - ${data['message'] ?? 'Success'}',
          );
          debugPrint('ProfileService: Server response data: $data');

          // Check if the response indicates success
          if (data['success'] == true) {
            return true;
          } else {
            _setError(data['message'] ?? 'Profile update failed');
            return false;
          }
        } catch (e) {
          debugPrint(
            'ProfileService: Success but failed to parse response: $e',
          );
          return true; // Still consider it successful if status is 200/201
        }
      } else if (response.statusCode == 400) {
        // Bad request - likely validation error
        try {
          final data = json.decode(response.body);
          String errorMessage = 'Invalid profile data provided';

          if (data['message'] != null) {
            errorMessage = data['message'];
          } else if (data['errors'] != null) {
            // Handle field-specific validation errors
            final errors = data['errors'] as Map<String, dynamic>;
            final errorList = <String>[];
            errors.forEach((field, messages) {
              if (messages is List) {
                errorList.addAll(messages.map((msg) => '$field: $msg'));
              } else {
                errorList.add('$field: $messages');
              }
            });
            errorMessage = errorList.join(', ');
          }

          _setError(errorMessage);
        } catch (e) {
          _setError('Invalid profile data provided');
        }
        return false;
      } else if (response.statusCode == 401) {
        _setError('Authentication failed. Please log in again.');
        return false;
      } else if (response.statusCode == 403) {
        _setError(
          'Access denied. You do not have permission to update profile.',
        );
        return false;
      } else if (response.statusCode == 404) {
        _setError('Profile update endpoint not found. Please contact support.');
        return false;
      } else {
        // Other error status codes
        try {
          final data = json.decode(response.body);
          _setError(
            data['message'] ?? data['error'] ?? 'Failed to update profile',
          );
        } catch (e) {
          _setError('Server error: ${response.statusCode}');
        }
        return false;
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('ProfileService: Exception during profile update: $e');
      return false;
    }
  }

  // Change email address
  Future<bool> changeEmail({
    required String token,
    required String newEmail,
    required String confirmEmail,
    required String currentPassword,
  }) async {
    _clearError();

    try {
      debugPrint('ProfileService: Attempting to change email...');
      debugPrint('ProfileService: newEmail: $newEmail');
      debugPrint('ProfileService: confirmEmail: $confirmEmail');
      debugPrint('ProfileService: token: ${token.substring(0, 20)}...');

      final requestBody = {
        'new_email': newEmail,
        'confirm_email': confirmEmail,
        'current_password': currentPassword,
      };
      debugPrint('ProfileService: Request body: $requestBody');

      final response = await http.post(
        Uri.parse('$baseUrl/users/change-email/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      );

      debugPrint(
        'ProfileService: Email change response status: ${response.statusCode}',
      );
      debugPrint(
        'ProfileService: Email change response body: ${response.body}',
      );

      // Check if response is HTML (error page)
      if (response.body.trim().startsWith('<!DOCTYPE html>') ||
          response.body.trim().startsWith('<html')) {
        _setError(
          'Server error: Received HTML response instead of JSON. Please check your authentication.',
        );
        debugPrint(
          'ProfileService: Received HTML response: ${response.body.substring(0, 200)}...',
        );
        return false;
      }

      // Handle different response status codes
      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('ProfileService: Email changed successfully');
        return true;
      } else if (response.statusCode == 400) {
        // Bad request - likely validation error
        try {
          final data = json.decode(response.body);
          String errorMessage =
              data['message'] ?? data['error'] ?? 'Invalid email data provided';

          // Check for specific error details
          if (data['error_details'] != null) {
            errorMessage = data['error_details'];
          } else if (data['errors'] != null) {
            // Handle field-specific validation errors
            final errors = data['errors'] as Map<String, dynamic>;
            final errorList = <String>[];
            errors.forEach((field, messages) {
              if (messages is List) {
                errorList.addAll(messages.map((msg) => '$field: $msg'));
              } else {
                errorList.add('$field: $messages');
              }
            });
            if (errorList.isNotEmpty) {
              errorMessage = errorList.join(', ');
            }
          }

          _setError(errorMessage);
        } catch (e) {
          _setError('Invalid email data provided');
        }
        return false;
      } else if (response.statusCode == 401) {
        _setError('Authentication failed. Please log in again.');
        return false;
      } else if (response.statusCode == 403) {
        _setError('Access denied. You do not have permission to change email.');
        return false;
      } else if (response.statusCode == 404) {
        _setError('Email change endpoint not found. Please contact support.');
        return false;
      } else {
        // Other error status codes
        try {
          final data = json.decode(response.body);
          _setError(
            data['message'] ?? data['error'] ?? 'Failed to change email',
          );
        } catch (e) {
          _setError('Server error: ${response.statusCode}');
        }
        return false;
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('ProfileService: Exception during email change: $e');
      return false;
    }
  }

  // Upload profile picture
  Future<bool> uploadProfilePicture(String token, String imagePath) async {
    _clearError();

    try {
      var request = http.MultipartRequest(
        'PATCH',
        Uri.parse('$baseUrl/users/profile/'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        await http.MultipartFile.fromPath('profile_picture', imagePath),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint(
        'ProfileService: Profile picture upload response status: ${response.statusCode}',
      );
      debugPrint(
        'ProfileService: Profile picture upload response body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          debugPrint('ProfileService: Profile picture uploaded successfully');
          return true;
        } else {
          _setError(data['message'] ?? 'Failed to upload profile picture');
          return false;
        }
      } else {
        try {
          final data = json.decode(response.body);
          _setError(data['message'] ?? 'Failed to upload profile picture');
        } catch (e) {
          _setError('Failed to upload profile picture');
        }
        return false;
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('ProfileService: Exception during picture upload: $e');
      return false;
    }
  }

  // Upload profile picture from bytes (for web)
  Future<bool> uploadProfilePictureBytes(
    String token,
    List<int> imageBytes, {
    String fileName = 'profile_picture.jpg',
  }) async {
    _clearError();

    try {
      var request = http.MultipartRequest(
        'PATCH',
        Uri.parse('$baseUrl/users/profile/'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        http.MultipartFile.fromBytes(
          'profile_picture',
          imageBytes,
          filename: fileName,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint(
        'ProfileService: Profile picture upload (bytes) response status: ${response.statusCode}',
      );
      debugPrint(
        'ProfileService: Profile picture upload (bytes) response body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          debugPrint('ProfileService: Profile picture uploaded successfully');
          return true;
        } else {
          _setError(data['message'] ?? 'Failed to upload profile picture');
          return false;
        }
      } else {
        try {
          final data = json.decode(response.body);
          _setError(data['message'] ?? 'Failed to upload profile picture');
        } catch (e) {
          _setError('Failed to upload profile picture');
        }
        return false;
      }
    } catch (e) {
      debugPrint('ProfileService: Error uploading profile picture: $e');
      _setError('Network error: ${e.toString()}');
      return false;
    }
  }

  // Get user profile
  Future<Map<String, dynamic>?> getUserProfile(String token) async {
    _clearError();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/profile/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        debugPrint('ProfileService: Profile data retrieved successfully');
        return data['user'];
      } else {
        _setError(data['message'] ?? 'Failed to get profile data');
        debugPrint('ProfileService: Get profile failed - ${data['message']}');
        return null;
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('ProfileService: Exception during profile retrieval: $e');
      return null;
    }
  }

  // Update notification preferences
  Future<bool> updateNotificationPreferences({
    required String token,
    required Map<String, bool> preferences,
  }) async {
    _clearError();

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/auth/notification-preferences/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'preferences': preferences}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        debugPrint(
          'ProfileService: Notification preferences updated successfully',
        );
        return true;
      } else {
        _setError(
          data['message'] ?? 'Failed to update notification preferences',
        );
        debugPrint(
          'ProfileService: Notification update failed - ${data['message']}',
        );
        return false;
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint(
        'ProfileService: Exception during notification preferences update: $e',
      );
      return false;
    }
  }

  // Update privacy settings
  Future<bool> updatePrivacySettings({
    required String token,
    required Map<String, dynamic> settings,
  }) async {
    _clearError();

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/auth/privacy-settings/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'settings': settings}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        debugPrint('ProfileService: Privacy settings updated successfully');
        return true;
      } else {
        _setError(data['message'] ?? 'Failed to update privacy settings');
        debugPrint(
          'ProfileService: Privacy settings update failed - ${data['message']}',
        );
        return false;
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint(
        'ProfileService: Exception during privacy settings update: $e',
      );
      return false;
    }
  }

  // Delete account
  Future<bool> deleteAccount(String token, String password) async {
    _clearError();

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/users/profile/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'password': password}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        debugPrint('ProfileService: Account deleted successfully');
        return true;
      } else {
        _setError(data['message'] ?? 'Failed to delete account');
        debugPrint(
          'ProfileService: Account deletion failed - ${data['message']}',
        );
        return false;
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('ProfileService: Exception during account deletion: $e');
      return false;
    }
  }

  // Get notification preferences
  Future<Map<String, bool>?> getNotificationPreferences(String token) async {
    _clearError();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/notification-preferences/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        debugPrint(
          'ProfileService: Notification preferences retrieved successfully',
        );
        return Map<String, bool>.from(data['preferences']);
      } else {
        _setError(data['message'] ?? 'Failed to get notification preferences');
        debugPrint(
          'ProfileService: Get notification preferences failed - ${data['message']}',
        );
        return null;
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint(
        'ProfileService: Exception during notification preferences retrieval: $e',
      );
      return null;
    }
  }

  // Get privacy settings
  Future<Map<String, dynamic>?> getPrivacySettings(String token) async {
    _clearError();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/privacy-settings/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        debugPrint('ProfileService: Privacy settings retrieved successfully');
        return data['settings'];
      } else {
        _setError(data['message'] ?? 'Failed to get privacy settings');
        debugPrint(
          'ProfileService: Get privacy settings failed - ${data['message']}',
        );
        return null;
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint(
        'ProfileService: Exception during privacy settings retrieval: $e',
      );
      return null;
    }
  }

  // Private helper methods
  void _setError(String error) {
    _errorMessage = error;
  }

  // Change user password
  Future<bool> changePassword(
    String token,
    String currentPassword,
    String newPassword,
    String confirmPassword,
  ) async {
    _clearError();

    try {
      debugPrint('=== PASSWORD CHANGE SERVICE DEBUG START ===');
      debugPrint('DEBUG: ProfileService.changePassword called');
      debugPrint('DEBUG: Base URL: $baseUrl');
      debugPrint('DEBUG: Token: ${token.substring(0, 20)}...');
      debugPrint('DEBUG: Current password length: ${currentPassword.length}');
      debugPrint('DEBUG: New password length: ${newPassword.length}');
      debugPrint('DEBUG: Confirm password length: ${confirmPassword.length}');

      final requestBody = {
        'current_password': currentPassword,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      };
      debugPrint('DEBUG: Request body: ${json.encode(requestBody)}');

      final url = '$baseUrl/users/change-password/';
      debugPrint('DEBUG: Full URL: $url');

      debugPrint('DEBUG: Making HTTP POST request...');
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );
      debugPrint('DEBUG: HTTP request completed');

      debugPrint(
        'ProfileService: Change password response status: ${response.statusCode}',
      );
      debugPrint(
        'ProfileService: Change password response body: ${response.body}',
      );
      debugPrint('=== PASSWORD CHANGE SERVICE DEBUG END ===');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          debugPrint('ProfileService: Password changed successfully');
          return true;
        } else {
          _setError(data['message'] ?? 'Failed to change password');
          return false;
        }
      } else {
        final data = json.decode(response.body);
        _setError(data['message'] ?? 'Failed to change password');
        debugPrint(
          'ProfileService: Change password failed - ${data['message']}',
        );
        return false;
      }
    } catch (e) {
      _setError('Error changing password: ${e.toString()}');
      debugPrint('ProfileService: Change password error: $e');
      return false;
    }
  }

  void _clearError() {
    _errorMessage = null;
  }
}

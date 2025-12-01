import 'package:flutter/foundation.dart';
import '../models/auth_response.dart';
import '../models/user_model.dart';
import '../../../core/services/api_client.dart';

/// Authentication API service for handling all auth-related operations
class AuthApiService {
  /// Login user with email and password
  static Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    debugPrint('AuthApiService: Login called with email: $email');
    try {
      debugPrint('AuthApiService: Making POST request to /users/login/');
      final response = await ApiClient.post(
        '/users/login/',
        body: {'email': email, 'password': password},
      );

      debugPrint(
        'AuthApiService: Response received - Status: ${response.statusCode}',
      );
      debugPrint('AuthApiService: Response body: ${response.body}');

      final data = ApiClient.handleResponse(response);
      debugPrint('AuthApiService: Parsed data: $data');

      if (ApiClient.isSuccess(response)) {
        debugPrint('AuthApiService: Response indicates success');
        // Parse Django response format
        final responseData = data['data'];
        debugPrint('AuthApiService: Response data: $responseData');

        // Handle full_name parsing safely
        String firstName = 'User';
        String lastName = '';

        if (responseData['full_name'] != null) {
          final nameParts = responseData['full_name'].toString().split(' ');
          firstName = nameParts.isNotEmpty ? nameParts[0] : 'User';
          lastName = nameParts.length > 1 ? nameParts.skip(1).join(' ') : '';
        }

        debugPrint('AuthApiService: Creating AuthResponse with success=true');
        debugPrint(
          'AuthApiService: User type from response: ${responseData['user_type']}',
        );
        debugPrint('AuthApiService: User ID: ${responseData['user_id']}');
        debugPrint('AuthApiService: Email: ${responseData['email']}');

        return AuthResponse(
          success: true,
          accessToken: responseData['access_token'],
          refreshToken: responseData['refresh_token'],
          user: User(
            id: responseData['user_id'],
            email: responseData['email'],
            firstName: firstName,
            lastName: lastName,
            userType: responseData['user_type'],
            isActive: true,
            createdAt: DateTime.now(),
          ),
          message: data['message'],
        );
      } else {
        debugPrint('AuthApiService: Response indicates failure');
        return AuthResponse(
          success: false,
          message: data['message'] ?? data['error'] ?? 'Login failed',
          errors: data['errors'],
        );
      }
    } catch (e) {
      debugPrint('AuthApiService login error: $e');
      debugPrint('AuthApiService login error type: ${e.runtimeType}');
      return AuthResponse(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Register new user
  static Future<AuthResponse> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String userType,
    String? phone,
    String? address,
    String? city,
    String? state,
    String? zipCode,
    String? country,
  }) async {
    try {
      final response = await ApiClient.post(
        '/users/register/',
        body: {
          'email': email,
          'password': password,
          'password_confirm': password, // Backend expects password_confirm
          'first_name': firstName,
          'last_name': lastName,
          'user_type': userType,
          'preferred_language': 'en', // Add required field
          'phone': phone,
          'address': address,
          'city': city,
          'zip_code': zipCode,
          'country': country,
        },
      );

      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response)) {
        // Registration successful - parse Django response format
        final responseData = data['data'];

        return AuthResponse(
          success: true,
          user: User(
            id: responseData['user_id'],
            email: responseData['email'],
            firstName: responseData['full_name']?.split(' ')[0] ?? '',
            lastName:
                responseData['full_name']?.split(' ').skip(1).join(' ') ?? '',
            userType: responseData['user_type'],
            isActive: true,
            createdAt: DateTime.now(),
          ),
          message: data['message'],
        );
      } else {
        return AuthResponse(
          success: false,
          message: data['error'] ?? 'Registration failed',
          errors: data['details'],
        );
      }
    } catch (e) {
      debugPrint('AuthApiService register error: $e');
      return AuthResponse(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Logout user
  static Future<AuthResponse> logout(String refreshToken) async {
    try {
      final response = await ApiClient.post(
        '/logout/',
        body: {'refresh_token': refreshToken},
      );

      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response)) {
        return AuthResponse(
          success: true,
          message: data['message'] ?? 'Logout successful',
        );
      } else {
        return AuthResponse(
          success: false,
          message: data['message'] ?? data['error'] ?? 'Logout failed',
        );
      }
    } catch (e) {
      debugPrint('AuthApiService logout error: $e');
      return AuthResponse(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Refresh access token
  static Future<AuthResponse> refreshToken(String refreshToken) async {
    try {
      final response = await ApiClient.post(
        '/token/refresh/',
        body: {'refresh': refreshToken},
      );

      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response)) {
        return AuthResponse(
          success: true,
          accessToken: data['access'] ?? data['access_token'],
          refreshToken: data['refresh'] ?? data['refresh_token'],
          message: data['message'] ?? 'Token refreshed successfully',
        );
      } else {
        return AuthResponse(
          success: false,
          message: data['error'] ?? data['detail'] ?? 'Token refresh failed',
        );
      }
    } catch (e) {
      debugPrint('AuthApiService refreshToken error: $e');
      return AuthResponse(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Forgot password - send reset email
  static Future<AuthResponse> forgotPassword(String email) async {
    debugPrint('AuthApiService: forgotPassword called with email: $email');
    try {
      debugPrint(
        'AuthApiService: Making POST request to /users/password-reset-request/',
      );
      final response = await ApiClient.post(
        '/users/password-reset-request/',
        body: {'email': email},
      );

      debugPrint(
        'AuthApiService: Response received - Status: ${response.statusCode}',
      );
      debugPrint('AuthApiService: Response body: ${response.body}');

      final data = ApiClient.handleResponse(response);
      debugPrint('AuthApiService: Parsed data: $data');

      if (ApiClient.isSuccess(response)) {
        debugPrint('AuthApiService: Response indicates success');
        return AuthResponse(
          success: true,
          message: data['message'] ?? 'Password reset email sent',
        );
      } else {
        debugPrint('AuthApiService: Response indicates failure');
        return AuthResponse(
          success: false,
          message: data['error'] ?? 'Password reset request failed',
        );
      }
    } catch (e) {
      debugPrint('AuthApiService forgotPassword error: $e');
      debugPrint('AuthApiService forgotPassword error type: ${e.runtimeType}');
      return AuthResponse(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Reset password with token
  static Future<AuthResponse> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      final response = await ApiClient.post(
        '/users/reset-password/',
        body: {'token': token, 'new_password': newPassword},
      );

      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response)) {
        return AuthResponse(
          success: true,
          message: data['message'] ?? 'Password reset successfully',
        );
      } else {
        return AuthResponse(
          success: false,
          message: data['error'] ?? 'Password reset failed',
        );
      }
    } catch (e) {
      debugPrint('AuthApiService resetPassword error: $e');
      return AuthResponse(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Change password for authenticated user
  static Future<AuthResponse> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await ApiClient.post(
        '/users/change-password/',
        body: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
        token: token,
      );

      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response)) {
        return AuthResponse(
          success: true,
          message: data['message'] ?? 'Password changed successfully',
        );
      } else {
        return AuthResponse(
          success: false,
          message: data['error'] ?? 'Password change failed',
        );
      }
    } catch (e) {
      debugPrint('AuthApiService changePassword error: $e');
      return AuthResponse(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Verify email with verification code
  static Future<AuthResponse> verifyEmail({
    required String token,
    required String verificationCode,
  }) async {
    try {
      final response = await ApiClient.post(
        '/users/verify-email/',
        body: {'token': token, 'verification_code': verificationCode},
      );

      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response)) {
        return AuthResponse(
          success: true,
          message: data['message'] ?? 'Email verified successfully',
        );
      } else {
        return AuthResponse(
          success: false,
          message: data['error'] ?? 'Email verification failed',
        );
      }
    } catch (e) {
      debugPrint('AuthApiService verifyEmail error: $e');
      return AuthResponse(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Resend verification email
  static Future<AuthResponse> resendVerification(String email) async {
    try {
      final response = await ApiClient.post(
        '/users/resend-verification/',
        body: {'email': email},
      );

      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response)) {
        return AuthResponse(
          success: true,
          message: data['message'] ?? 'Verification email sent',
        );
      } else {
        return AuthResponse(
          success: false,
          message: data['error'] ?? 'Verification resend failed',
        );
      }
    } catch (e) {
      debugPrint('AuthApiService resendVerification error: $e');
      return AuthResponse(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Get user profile
  static Future<AuthResponse> getProfile(String token) async {
    try {
      final response = await ApiClient.get('/users/profile/', token: token);

      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response)) {
        // Extract data from the nested structure
        final userInfo = data['data']['user_info'] ?? {};
        final registrationData = data['data']['registration_data'] ?? {};
        final profileData = data['data']['profile_data'] ?? {};

        // Debug logging
        debugPrint('AuthApiService: Raw profile data: $data');
        debugPrint('AuthApiService: User info: $userInfo');
        debugPrint('AuthApiService: Registration data: $registrationData');
        debugPrint('AuthApiService: Profile data: $profileData');

        // Convert snake_case to camelCase for User model compatibility
        final Map<String, dynamic> convertedData = {
          'id': userInfo['id'],
          'email': userInfo['email'],
          'userType': userInfo['user_type'],
          'firstName': registrationData['first_name'] ?? '',
          'lastName': registrationData['last_name'] ?? '',
          'phone': profileData['phone_number'],
          'address': profileData['address'],
          'city': profileData['city'],
          'zipCode': profileData['zip_code'],
          'country': profileData['country'],
          'profilePicture': profileData['profile_picture'],
          'dateOfBirth': profileData['date_of_birth'],
          'isActive': true,
          'isVerified': true,
          'createdAt': userInfo['date_joined'],
        };

        // Debug logging for converted data
        debugPrint('AuthApiService: Converted data: $convertedData');

        return AuthResponse(
          success: true,
          user: User.fromJson(convertedData),
          message: 'Profile retrieved successfully',
        );
      } else {
        return AuthResponse(
          success: false,
          message: data['error'] ?? 'Failed to get profile',
        );
      }
    } catch (e) {
      debugPrint('AuthApiService getProfile error: $e');
      return AuthResponse(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Update user profile
  static Future<AuthResponse> updateProfile({
    required String token,
    required Map<String, dynamic> userData,
  }) async {
    try {
      final response = await ApiClient.put(
        '/profile/',
        body: userData,
        token: token,
      );

      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response)) {
        return AuthResponse(
          success: true,
          user: User.fromJson(data),
          message: data['message'] ?? 'Profile updated successfully',
        );
      } else {
        return AuthResponse(
          success: false,
          message: data['error'] ?? 'Profile update failed',
          errors: data['details'],
        );
      }
    } catch (e) {
      debugPrint('AuthApiService updateProfile error: $e');
      return AuthResponse(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Change user email address
  static Future<AuthResponse> changeEmail({
    required String token,
    required String newEmail,
    required String confirmEmail,
    required String currentPassword,
  }) async {
    try {
      final response = await ApiClient.post(
        '/users/change-email/',
        body: {
          'new_email': newEmail,
          'confirm_email': confirmEmail,
          'current_password': currentPassword,
        },
        token: token,
      );

      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response)) {
        return AuthResponse(
          success: true,
          message: data['message'] ?? 'Email changed successfully',
          user: data['data'] != null ? User.fromJson(data['data']) : null,
        );
      } else {
        return AuthResponse(
          success: false,
          message: data['error'] ?? 'Email change failed',
          errors: data['details'],
        );
      }
    } catch (e) {
      debugPrint('AuthApiService changeEmail error: $e');
      return AuthResponse(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Get user type options for registration
  static Future<List<Map<String, String>>> getUserTypeOptions() async {
    try {
      final response = await ApiClient.get('/users/register/user-types/');
      final data = ApiClient.handleResponse(response);

      if (ApiClient.isSuccess(response) && data['success'] == true) {
        final Map<String, dynamic> userTypesData = data['data']['user_types'];
        final List<Map<String, String>> options = [];

        // Convert the backend response format to frontend format
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

      // Fallback to default options if API fails (never include library_admin in fallback)
      return [
        {'value': 'customer', 'label': 'Customer'},
        {'value': 'delivery_admin', 'label': 'Delivery Administrator'},
      ];
    } catch (e) {
      debugPrint('AuthApiService getUserTypeOptions error: $e');
      // Return default options (never include library_admin in fallback)
      return [
        {'value': 'customer', 'label': 'Customer'},
        {'value': 'delivery_admin', 'label': 'Delivery Administrator'},
      ];
    }
  }
}

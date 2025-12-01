import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/auth_response.dart';
import '../../../core/services/error_handler.dart';

class AuthApiService {
  final String baseUrl;
  final Map<String, String> headers;

  AuthApiService({required this.baseUrl, required this.headers});

  // Login
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/login/'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      final data = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return AuthResponse.fromJson(data);
      } else {
        final errorMessage = ErrorHandler.handleApiError(
          response.statusCode,
          data,
        );
        return AuthResponse(
          success: false,
          message: errorMessage,
          errors: data['errors'],
        );
      }
    } catch (e, stackTrace) {
      final errorMessage = ErrorHandler.handleNetworkError(e);
      ErrorHandler.logError('AuthApiService.login', e, stackTrace);
      return AuthResponse(success: false, message: errorMessage);
    }
  }

  // Register
  Future<AuthResponse> register({
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
      final response = await http.post(
        Uri.parse('$baseUrl/users/register/'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
          'first_name': firstName,
          'last_name': lastName,
          'user_type': userType,
          'phone': phone,
          'address': address,
          'city': city,
          'zip_code': zipCode,
          'country': country,
        }),
      );

      final data = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 201) {
        return AuthResponse.fromJson(data);
      } else {
        final errorMessage = ErrorHandler.handleApiError(
          response.statusCode,
          data,
        );

        // For validation errors, format them nicely
        if (response.statusCode == 422 && data['errors'] != null) {
          final validationErrors = ErrorHandler.formatValidationErrors(
            data['errors'],
          );
          return AuthResponse(
            success: false,
            message: validationErrors,
            errors: data['errors'],
          );
        }

        return AuthResponse(
          success: false,
          message: errorMessage,
          errors: data['errors'],
        );
      }
    } catch (e, stackTrace) {
      final errorMessage = ErrorHandler.handleNetworkError(e);
      ErrorHandler.logError('AuthApiService.register', e, stackTrace);
      return AuthResponse(success: false, message: errorMessage);
    }
  }

  // Logout
  Future<AuthResponse> logout(String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/logout/'),
        headers: {
          ...headers,
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return AuthResponse.fromJson(data);
      } else {
        return AuthResponse(
          success: false,
          message: data['message'] ?? 'Logout failed',
        );
      }
    } catch (e) {
      return AuthResponse(success: false, message: 'Network error: $e');
    }
  }

  // Refresh Token
  Future<AuthResponse> refreshToken(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/refresh/'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: json.encode({'refresh_token': refreshToken}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return AuthResponse.fromJson(data);
      } else {
        return AuthResponse(
          success: false,
          message: data['message'] ?? 'Token refresh failed',
        );
      }
    } catch (e) {
      return AuthResponse(success: false, message: 'Network error: $e');
    }
  }

  // Forgot Password
  Future<AuthResponse> forgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/forgot-password/'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return AuthResponse.fromJson(data);
      } else {
        return AuthResponse(
          success: false,
          message: data['message'] ?? 'Password reset request failed',
        );
      }
    } catch (e) {
      return AuthResponse(success: false, message: 'Network error: $e');
    }
  }

  // Reset Password
  Future<AuthResponse> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/reset-password/'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: json.encode({'token': token, 'new_password': newPassword}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return AuthResponse.fromJson(data);
      } else {
        return AuthResponse(
          success: false,
          message: data['message'] ?? 'Password reset failed',
        );
      }
    } catch (e) {
      return AuthResponse(success: false, message: 'Network error: $e');
    }
  }

  // Change Password
  Future<AuthResponse> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/change-password/'),
        headers: {
          ...headers,
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return AuthResponse.fromJson(data);
      } else {
        return AuthResponse(
          success: false,
          message: data['message'] ?? 'Password change failed',
        );
      }
    } catch (e) {
      return AuthResponse(success: false, message: 'Network error: $e');
    }
  }

  // Verify Email
  Future<AuthResponse> verifyEmail({
    required String token,
    required String verificationCode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/verify-email/'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: json.encode({
          'token': token,
          'verification_code': verificationCode,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return AuthResponse.fromJson(data);
      } else {
        return AuthResponse(
          success: false,
          message: data['message'] ?? 'Email verification failed',
        );
      }
    } catch (e) {
      return AuthResponse(success: false, message: 'Network error: $e');
    }
  }

  // Resend Verification
  Future<AuthResponse> resendVerification(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/resend-verification/'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return AuthResponse.fromJson(data);
      } else {
        return AuthResponse(
          success: false,
          message: data['message'] ?? 'Verification resend failed',
        );
      }
    } catch (e) {
      return AuthResponse(success: false, message: 'Network error: $e');
    }
  }

  // Get User Profile
  Future<AuthResponse> getUserProfile(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/profile/'),
        headers: {...headers, 'Authorization': 'Bearer $token'},
      );

      final data = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return AuthResponse.fromJson(data);
      } else {
        final errorMessage = ErrorHandler.handleApiError(
          response.statusCode,
          data,
        );
        return AuthResponse(success: false, message: errorMessage);
      }
    } catch (e, stackTrace) {
      final errorMessage = ErrorHandler.handleNetworkError(e);
      ErrorHandler.logError('AuthApiService.getUserProfile', e, stackTrace);
      return AuthResponse(success: false, message: errorMessage);
    }
  }

  // Update User Profile
  Future<AuthResponse> updateUserProfile({
    required String token,
    required Map<String, dynamic> userData,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/users/profile/'),
        headers: {
          ...headers,
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(userData),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return AuthResponse.fromJson(data);
      } else {
        return AuthResponse(
          success: false,
          message: data['message'] ?? 'Profile update failed',
          errors: data['errors'],
        );
      }
    } catch (e) {
      return AuthResponse(success: false, message: 'Network error: $e');
    }
  }
}

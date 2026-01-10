import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/profile_service.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileProvider extends ChangeNotifier {
  final ProfileService _profileService;

  bool _isLoading = false;
  String? _errorMessage;
  String? _token;

  ProfileProvider(this._profileService);

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get token => _token;

  // Test connectivity to the backend
  Future<bool> testConnectivity() async {
    return await _profileService.testConnectivity();
  }

  // Set authentication token
  void setToken(String? token) {
    _token = token;
    debugPrint(
      'ProfileProvider: Token set to ${token != null ? '${token.substring(0, 20)}...' : 'null'}',
    );
    notifyListeners();
  }

  // Force refresh token from AuthProvider
  void refreshTokenFromAuthProvider(BuildContext context) {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final newToken = authProvider.token;
      if (newToken != null && newToken != _token) {
        setToken(newToken);
        debugPrint('ProfileProvider: Token refreshed from AuthProvider');
      }
    } catch (e) {
      debugPrint(
        'ProfileProvider: Error refreshing token from AuthProvider: $e',
      );
    }
  }

  // Auto-refresh token from AuthProvider (call this periodically)
  void autoRefreshToken(BuildContext context) {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentToken = authProvider.token;

      if (currentToken != _token) {
        setToken(currentToken);
        debugPrint('ProfileProvider: Token auto-refreshed from AuthProvider');
      }
    } catch (e) {
      debugPrint('ProfileProvider: Error in auto-refresh: $e');
    }
  }

  // Load profile data from server
  Future<bool> loadProfile({String? token, BuildContext? context}) async {
    _setLoading(true);
    _clearError();

    // Always try to get the latest token from AuthProvider if context is available
    if (context != null) {
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final latestToken = authProvider.token;
        if (latestToken != null && latestToken != _token) {
          setToken(latestToken);
        }
      } catch (e) {
        debugPrint(
          'ProfileProvider: Error getting token from AuthProvider: $e',
        );
      }
    }

    final authToken = token ?? _token;
    if (authToken == null) {
      _setError('Authentication token not available');
      _setLoading(false);
      return false;
    }

    try {
      debugPrint(
        'ProfileProvider: Calling ProfileService.getProfile with token: ${authToken.substring(0, 20)}...',
      );
      final success = await _profileService.getProfile(authToken);
      debugPrint(
        'ProfileProvider: ProfileService.getProfile returned: $success',
      );

      if (success) {
        debugPrint(
          'ProfileProvider: Profile loaded successfully, refreshing AuthProvider',
        );
        // If we have a context, refresh the AuthProvider with fresh data
        if (context != null && context.mounted) {
          final authProvider = Provider.of<AuthProvider>(
            context,
            listen: false,
          );
          await authProvider.refreshUserData();
          debugPrint('ProfileProvider: AuthProvider refreshed with fresh data');
        }
        _setLoading(false);
        return true;
      } else {
        debugPrint('ProfileProvider: ProfileService.getProfile failed');
        _setError('Failed to load profile data');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      debugPrint('ProfileProvider: Exception in loadProfile: $e');
      _setError('Error loading profile: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Update user profile with partial updates support
  Future<bool> updateProfile(
    Map<String, dynamic> profileData, {
    String? token,
    String? userType,
    BuildContext? context,
  }) async {
    _setLoading(true);
    _clearError();

    // Always try to get the latest token from AuthProvider if context is available
    if (context != null) {
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final latestToken = authProvider.token;
        if (latestToken != null && latestToken != _token) {
          setToken(latestToken);
        }
      } catch (e) {
        debugPrint(
          'ProfileProvider: Error getting token from AuthProvider: $e',
        );
      }
    }

    final authToken = token ?? _token;
    if (authToken == null) {
      _setError('Authentication token not available');
      _setLoading(false);
      return false;
    }

    // Store the token for future use
    if (token != null && token != _token) {
      setToken(token);
    }

    // Convert camelCase to snake_case for backend compatibility and filter only changed fields
    final Map<String, dynamic> convertedData = {};
    profileData.forEach((key, value) {
      String snakeKey = key;
      // Handle field name conversion for backend compatibility
      switch (key) {
        case 'firstName':
          snakeKey = 'first_name';
          break;
        case 'lastName':
          snakeKey = 'last_name';
          break;
        case 'phoneNumber':
        case 'phone':
          snakeKey = 'phone_number';
          break;
        case 'zipCode':
          snakeKey = 'zip_code';
          break;
        case 'first_name':
        case 'last_name':
        case 'phone_number':
        case 'zip_code':
        case 'address':
        case 'city':
        case 'country':
        case 'email':
        case 'date_of_birth':
          // Already in correct snake_case format
          snakeKey = key;
          break;
        default:
          // Keep other keys as-is
          snakeKey = key;
          break;
      }

      // Only include fields that have actual values (not empty strings)
      if (value != null && value.toString().trim().isNotEmpty) {
        convertedData[snakeKey] = value;
      } else if (value == null || value.toString().trim().isEmpty) {
        // For optional fields, include null to clear them
        if ([
          'phone_number',
          'address',
          'city',
          'zip_code',
          'country',
          'date_of_birth',
        ].contains(snakeKey)) {
          convertedData[snakeKey] = null;
        }
      }
    });

    debugPrint(
      'ProfileProvider: Updating profile with token: ${authToken.substring(0, 20)}...',
    );
    debugPrint('ProfileProvider: Original data: $profileData');
    debugPrint(
      'ProfileProvider: Converted data (only changed fields): $convertedData',
    );
    debugPrint(
      'ProfileProvider: Phone field - Original: ${profileData['phone_number']}, Converted: ${convertedData['phone_number']}',
    );

    try {
      final success = await _profileService.updateProfile(
        authToken,
        convertedData,
        userType: userType,
      );

      if (success) {
        // If we have a context, refresh the AuthProvider with fresh data
        if (context != null && context.mounted) {
          final authProvider = Provider.of<AuthProvider>(
            context,
            listen: false,
          );
          await authProvider.refreshUserData();
        }
        debugPrint('ProfileProvider: Profile updated successfully');
        _setLoading(false);
        return true;
      } else {
        _setError(_profileService.errorMessage ?? 'Failed to update profile');
        debugPrint(
          'ProfileProvider: Update failed - ${_profileService.errorMessage}',
        );
        _setLoading(false);
        return false;
      }
    } catch (e) {
      debugPrint('ProfileProvider: Error updating profile: $e');
      _setError('Network error: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Change email
  Future<bool> changeEmail({
    required String newEmail,
    required String confirmEmail,
    required String currentPassword,
    String? token,
  }) async {
    _setLoading(true);
    _clearError();

    final authToken = token ?? _token;
    if (authToken == null) {
      _setError('Authentication token not available');
      _setLoading(false);
      return false;
    }

    try {
      final success = await _profileService.changeEmail(
        token: authToken,
        newEmail: newEmail,
        confirmEmail: confirmEmail,
        currentPassword: currentPassword,
      );

      if (success) {
        debugPrint('ProfileProvider: Email changed successfully');
        _setLoading(false);
        return true;
      } else {
        _setError(_profileService.errorMessage ?? 'Failed to change email');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      debugPrint('ProfileProvider: Error changing email: $e');
      _setError('Network error: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Change user password
  Future<bool> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final success = await _profileService.changePassword(
        token,
        currentPassword,
        newPassword,
        confirmPassword,
      );

      if (success) {
        debugPrint('ProfileProvider: Password changed successfully');
        _setLoading(false);
        return true;
      } else {
        _setError(_profileService.errorMessage ?? 'Failed to change password');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Error changing password: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Upload profile picture
  Future<bool> uploadProfilePicture(String imagePath, {String? token}) async {
    _setLoading(true);
    _clearError();

    final authToken = token ?? _token;
    if (authToken == null) {
      _setError('Authentication token not available');
      _setLoading(false);
      return false;
    }

    try {
      final success = await _profileService.uploadProfilePicture(
        authToken,
        imagePath,
      );

      if (success) {
        debugPrint('ProfileProvider: Profile picture uploaded successfully');
        _setLoading(false);
        return true;
      } else {
        _setError(
          _profileService.errorMessage ?? 'Failed to upload profile picture',
        );
        _setLoading(false);
        return false;
      }
    } catch (e) {
      debugPrint('ProfileProvider: Error uploading profile picture: $e');
      _setError('Network error: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> uploadProfilePictureBytes(
    List<int> imageBytes, {
    String? fileName,
    String? token,
  }) async {
    _setLoading(true);
    _clearError();

    final authToken = token ?? _token;
    if (authToken == null) {
      _setError('Authentication token not available');
      _setLoading(false);
      return false;
    }

    try {
      final success = await _profileService.uploadProfilePictureBytes(
        authToken,
        imageBytes,
        fileName: fileName ?? 'profile_picture.jpg',
      );

      if (success) {
        debugPrint('ProfileProvider: Profile picture uploaded successfully');
        _setLoading(false);
        return true;
      } else {
        _setError(
          _profileService.errorMessage ?? 'Failed to upload profile picture',
        );
        _setLoading(false);
        return false;
      }
    } catch (e) {
      debugPrint('ProfileProvider: Error uploading profile picture: $e');
      _setError('Network error: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Get user profile data
  Future<Map<String, dynamic>?> getUserProfile({String? token}) async {
    _setLoading(true);
    _clearError();

    final authToken = token ?? _token;
    if (authToken == null) {
      _setError('Authentication token not available');
      _setLoading(false);
      return null;
    }

    try {
      final profileData = await _profileService.getUserProfile(authToken);
      _setLoading(false);
      return profileData;
    } catch (e) {
      debugPrint('ProfileProvider: Error getting user profile: $e');
      _setError('Network error: ${e.toString()}');
      _setLoading(false);
      return null;
    }
  }

  // Update notification preferences
  Future<bool> updateNotificationPreferences({
    required String token,
    required Map<String, bool> preferences,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final success = await _profileService.updateNotificationPreferences(
        token: token,
        preferences: preferences,
      );

      if (success) {
        debugPrint(
          'ProfileProvider: Notification preferences updated successfully',
        );
        _setLoading(false);
        return true;
      } else {
        _setError(
          _profileService.errorMessage ??
              'Failed to update notification preferences',
        );
        _setLoading(false);
        return false;
      }
    } catch (e) {
      debugPrint(
        'ProfileProvider: Error updating notification preferences: $e',
      );
      _setError('Network error: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Update privacy settings
  Future<bool> updatePrivacySettings({
    required String token,
    required Map<String, dynamic> settings,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final success = await _profileService.updatePrivacySettings(
        token: token,
        settings: settings,
      );

      if (success) {
        debugPrint('ProfileProvider: Privacy settings updated successfully');
        _setLoading(false);
        return true;
      } else {
        _setError(
          _profileService.errorMessage ?? 'Failed to update privacy settings',
        );
        _setLoading(false);
        return false;
      }
    } catch (e) {
      debugPrint('ProfileProvider: Error updating privacy settings: $e');
      _setError('Network error: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Delete account
  Future<bool> deleteAccount(String token, String password) async {
    _setLoading(true);
    _clearError();

    try {
      final success = await _profileService.deleteAccount(token, password);

      if (success) {
        debugPrint('ProfileProvider: Account deleted successfully');
        _setLoading(false);
        return true;
      } else {
        _setError(_profileService.errorMessage ?? 'Failed to delete account');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      debugPrint('ProfileProvider: Error deleting account: $e');
      _setError('Network error: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  // Clear all data
  void clear() {
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}

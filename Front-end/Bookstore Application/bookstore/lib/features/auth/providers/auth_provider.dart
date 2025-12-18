import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/auth_response.dart';
import '../services/auth_api_service.dart';
import '../../../core/utils/jwt_utils.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  String? _token;
  String? _refreshToken;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _tokenRefreshTimer;
  bool _isRefreshing = false;

  // Getters
  User? get user => _user;
  String? get token => _token;
  String? get refreshToken => _refreshToken;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get userRole => _user?.userType;

  // SharedPreferences keys
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey = 'user_data';
  static const String _isFirstTimeKey = 'is_first_time';

  AuthProvider() {
    _initializeAuthProvider();
  }

  @override
  void dispose() {
    _tokenRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeAuthProvider() async {
    await _loadStoredAuthData();
  }

  // Load stored authentication data on app startup
  Future<void> _loadStoredAuthData() async {
    _setLoading(true);
    try {
      // Add timeout to prevent getting stuck
      await Future.any([
        _performLoadStoredAuthData(),
        Future.delayed(const Duration(seconds: 5)),
      ]);
    } catch (e) {
      debugPrint('AuthProvider initialization error: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _performLoadStoredAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString(_tokenKey);
    final storedRefreshToken = prefs.getString(_refreshTokenKey);
    final storedUserData = prefs.getString(_userKey);

    debugPrint('AuthProvider: Checking stored authentication data');
    debugPrint('AuthProvider: Stored token exists: ${storedToken != null}');
    debugPrint(
      'AuthProvider: Stored user data exists: ${storedUserData != null}',
    );

    if (storedToken != null && storedUserData != null) {
      _token = storedToken;
      _refreshToken = storedRefreshToken;

      try {
        // Parse stored user data first
        final userData = jsonDecode(storedUserData);
        debugPrint(
          'AuthProvider: Loading stored user data from SharedPreferences',
        );
        _user = User.fromJson(userData);
        debugPrint('AuthProvider: Loaded user - userType: ${_user?.userType}');

        // Check token expiration
        final isAccessTokenExpired = JwtUtils.isTokenExpired(storedToken);
        final isRefreshTokenExpired =
            storedRefreshToken == null ||
            JwtUtils.isTokenExpired(storedRefreshToken);

        if (isAccessTokenExpired && !isRefreshTokenExpired) {
          // Access token expired but refresh token is valid - refresh automatically
          // Note: storedRefreshToken is guaranteed to be non-null here because
          // isRefreshTokenExpired would be true if storedRefreshToken was null
          debugPrint(
            'AuthProvider: Access token expired, attempting automatic refresh...',
          );
          final refreshSuccess = await _refreshTokenWithRetry();
          if (refreshSuccess) {
            _isAuthenticated = true;
            notifyListeners();
            _startTokenRefreshTimer();
            return;
          } else {
            debugPrint(
              'AuthProvider: Token refresh failed, clearing auth data',
            );
            await clearAuthData();
            notifyListeners();
            return;
          }
        } else if (isAccessTokenExpired && isRefreshTokenExpired) {
          // Both tokens expired - user needs to login
          debugPrint('AuthProvider: Both tokens expired, user needs to login');
          await clearAuthData();
          notifyListeners();
          return;
        } else if (!isAccessTokenExpired) {
          // Access token is still valid
          debugPrint('AuthProvider: Access token is still valid');
          _isAuthenticated = true;
          notifyListeners();
          _startTokenRefreshTimer();

          // Verify token with API in background (non-blocking)
          _verifyTokenInBackground(storedToken);
        }
      } catch (parseError) {
        debugPrint('Error parsing stored user data: ${parseError.toString()}');
        await clearAuthData();
        notifyListeners();
      }
    } else {
      debugPrint('AuthProvider: No stored authentication data found');
      debugPrint('AuthProvider: User will need to log in');
      // Ensure we notify listeners even when no stored data is found
      notifyListeners();
    }
  }

  // Verify token in background without blocking the UI
  void _verifyTokenInBackground(String token) async {
    try {
      final response = await AuthApiService.getProfile(token).timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('Auth API timeout - keeping cached credentials');
          return const AuthResponse(success: false, message: 'Timeout');
        },
      );

      if (response.success && response.user != null) {
        _user = response.user;
        await _saveUserData(_user!);
        notifyListeners();
      } else {
        // Token might be expired, try to refresh
        if (_refreshToken != null && !JwtUtils.isTokenExpired(_refreshToken!)) {
          debugPrint('AuthProvider: Token invalid, attempting refresh...');
          final refreshSuccess = await _refreshTokenWithRetry();
          if (!refreshSuccess) {
            await clearAuthData();
            notifyListeners();
          }
        } else {
          // Both tokens invalid, clear stored data
          await clearAuthData();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Background token verification failed: ${e.toString()}');
      // Keep using cached credentials on error - don't force logout
    }
  }

  // Refresh token with retry logic
  Future<bool> _refreshTokenWithRetry({int maxRetries = 3}) async {
    if (_isRefreshing) {
      debugPrint('AuthProvider: Token refresh already in progress');
      return false;
    }

    if (_refreshToken == null || _refreshToken!.isEmpty) {
      debugPrint('AuthProvider: No refresh token available');
      return false;
    }

    // Check if refresh token is expired
    if (JwtUtils.isTokenExpired(_refreshToken!)) {
      debugPrint('AuthProvider: Refresh token is expired');
      return false;
    }

    _isRefreshing = true;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint(
          'AuthProvider: Attempting token refresh (attempt $attempt/$maxRetries)...',
        );

        final response = await AuthApiService.refreshToken(_refreshToken!)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                debugPrint('AuthProvider: Token refresh timeout');
                return const AuthResponse(success: false, message: 'Timeout');
              },
            );

        if (response.success && response.accessToken != null) {
          debugPrint('AuthProvider: Token refreshed successfully');
          _token = response.accessToken;

          // Update refresh token if a new one is provided
          if (response.refreshToken != null) {
            _refreshToken = response.refreshToken;
          }

          await _saveAuthData();
          _isRefreshing = false;
          _startTokenRefreshTimer();
          notifyListeners();
          return true;
        } else {
          debugPrint('AuthProvider: Token refresh failed: ${response.message}');
          if (attempt < maxRetries) {
            // Wait before retrying (exponential backoff)
            final delay = Duration(seconds: attempt * 2);
            debugPrint(
              'AuthProvider: Retrying in ${delay.inSeconds} seconds...',
            );
            await Future.delayed(delay);
          }
        }
      } catch (e) {
        debugPrint('AuthProvider: Token refresh error (attempt $attempt): $e');
        if (attempt < maxRetries) {
          // Wait before retrying (exponential backoff)
          final delay = Duration(seconds: attempt * 2);
          debugPrint('AuthProvider: Retrying in ${delay.inSeconds} seconds...');
          await Future.delayed(delay);
        }
      }
    }

    _isRefreshing = false;
    debugPrint('AuthProvider: Token refresh failed after $maxRetries attempts');
    return false;
  }

  // Start timer to automatically refresh token before expiration
  void _startTokenRefreshTimer() {
    _tokenRefreshTimer?.cancel();

    if (_token == null) return;

    final timeUntilExpiration = JwtUtils.getTimeUntilExpiration(_token!);
    if (timeUntilExpiration == null) return;

    // Refresh token 1 hour before expiration (or immediately if less than 1 hour remaining)
    final refreshDelay = timeUntilExpiration.inHours > 1
        ? timeUntilExpiration - const Duration(hours: 1)
        : const Duration(minutes: 5);

    if (refreshDelay.inSeconds > 0) {
      debugPrint(
        'AuthProvider: Scheduling token refresh in ${refreshDelay.inHours} hours',
      );
      _tokenRefreshTimer = Timer(refreshDelay, () {
        debugPrint('AuthProvider: Automatic token refresh triggered');
        _refreshTokenWithRetry();
      });
    } else {
      // Token expires soon, refresh immediately
      debugPrint('AuthProvider: Token expires soon, refreshing immediately');
      _refreshTokenWithRetry();
    }
  }

  // Public method to refresh token (can be called externally)
  Future<bool> refreshAccessToken() async {
    return await _refreshTokenWithRetry();
  }

  // Login method
  Future<bool> login(String email, String password) async {
    debugPrint('AuthProvider: Login method called with email: $email');
    _setLoading(true);
    _clearError();

    try {
      debugPrint('AuthProvider: Calling AuthApiService.login...');
      final response = await AuthApiService.login(
        email: email,
        password: password,
      );

      debugPrint('AuthProvider: AuthApiService response received');
      debugPrint('AuthProvider: Response success: ${response.success}');
      debugPrint('AuthProvider: Response message: ${response.message}');
      debugPrint(
        'AuthProvider: Access token present: ${response.accessToken != null}',
      );

      if (response.success && response.accessToken != null) {
        debugPrint('AuthProvider: Login successful, storing tokens');
        debugPrint(
          'AuthProvider: Access token: ${response.accessToken!.substring(0, 20)}...',
        );
        debugPrint(
          'AuthProvider: Refresh token: ${response.refreshToken?.substring(0, 20) ?? 'null'}...',
        );

        _token = response.accessToken;
        _refreshToken = response.refreshToken;
        _user = response.user;
        _isAuthenticated = true;

        debugPrint(
          'AuthProvider: User object set - userType: ${_user?.userType}',
        );
        debugPrint('AuthProvider: User role getter returns: $userRole');
        debugPrint(
          'AuthProvider: isDeliveryAdmin: ${_user?.isDeliveryManager}',
        );
        debugPrint('AuthProvider: isLibraryAdmin: ${_user?.isLibraryManager}');
        debugPrint('AuthProvider: isCustomer: ${_user?.isCustomer}');

        // Save to SharedPreferences first
        await _saveAuthData();
        debugPrint('AuthProvider: Tokens saved to SharedPreferences');

        // Start automatic token refresh timer
        _startTokenRefreshTimer();

        // Notify listeners immediately after setting the token
        notifyListeners();
        debugPrint('AuthProvider: Listeners notified after token set');

        // Refresh user data from server to get complete profile
        await refreshUserData();

        // Notify listeners again after user data refresh
        notifyListeners();
        debugPrint('AuthProvider: Listeners notified after user data refresh');

        _setLoading(false);
        return true;
      } else {
        debugPrint('AuthProvider: Login failed - ${response.message}');
        _setError(response.message);
        _setLoading(false);
        return false;
      }
    } catch (e) {
      debugPrint('AuthProvider: Login exception: $e');
      _setError(
        'Network error: Unable to connect to server. Please check your internet connection.',
      );
      _setLoading(false);
      return false;
    }
  }

  // Register method
  Future<bool> register({
    required String email,
    required String firstName,
    required String lastName,
    required String password,
    required String confirmPassword,
    String? phone,
    String userType = 'customer',
  }) async {
    _setLoading(true);
    _clearError();

    // Validate password confirmation
    if (password != confirmPassword) {
      _setError('Passwords do not match');
      _setLoading(false);
      return false;
    }

    try {
      final response = await AuthApiService.register(
        email: email,
        firstName: firstName,
        lastName: lastName,
        password: password,
        phone: phone,
        userType: userType,
      );

      if (response.success) {
        // Clear any error messages from previous attempts
        _clearError();
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _setError(response.message);
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Logout method
  Future<void> logout() async {
    if (_refreshToken != null) {
      try {
        await AuthApiService.logout(_refreshToken!);
      } catch (e) {
        debugPrint('Logout API call failed: $e');
        // Continue with local logout even if API call fails
      }
    }
    await clearAuthData();
    // Notify listeners to trigger provider updates with null token
    notifyListeners();
  }

  // Clear authentication data
  Future<void> clearAuthData() async {
    debugPrint('AuthProvider: Clearing all authentication data');
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = null;
    _user = null;
    _token = null;
    _refreshToken = null;
    _isAuthenticated = false;
    _isRefreshing = false;
    _clearError();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userKey);
    debugPrint(
      'AuthProvider: Authentication data cleared from SharedPreferences',
    );
  }

  // Save authentication data to SharedPreferences
  Future<void> _saveAuthData() async {
    if (_token != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, _token!);
      debugPrint('AuthProvider: Access token saved to SharedPreferences');

      // Save refresh token if available
      if (_refreshToken != null) {
        await prefs.setString(_refreshTokenKey, _refreshToken!);
        debugPrint('AuthProvider: Refresh token saved to SharedPreferences');
      }

      // Save user data if available
      if (_user != null) {
        await _saveUserData(_user!);
        debugPrint('AuthProvider: User data saved to SharedPreferences');
      }
    }
  }

  // Save user data to SharedPreferences
  Future<void> _saveUserData(User user) async {
    final prefs = await SharedPreferences.getInstance();
    // Use proper JSON serialization
    final userData = jsonEncode(user.toJson());
    await prefs.setString(_userKey, userData);

    // Debug logging
    debugPrint('AuthProvider: Saving user data to SharedPreferences:');
    debugPrint('  - firstName: ${user.firstName}');
    debugPrint('  - lastName: ${user.lastName}');
    debugPrint('  - phone: ${user.phone}');
    debugPrint('  - address: ${user.address}');
    debugPrint('  - city: ${user.city}');
    debugPrint('  - zipCode: ${user.zipCode}');
    debugPrint('  - country: ${user.country}');
    debugPrint('  - dateOfBirth: ${user.dateOfBirth}');
  }

  // Check if this is first time opening the app
  Future<bool> isFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isFirstTimeKey) ?? true;
  }

  // Mark that the app has been opened before
  Future<void> setNotFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isFirstTimeKey, false);
  }

  // Refresh user data
  Future<void> refreshUserData() async {
    // Only refresh if we have a valid, non-empty token
    if (_token != null && _token!.isNotEmpty && _isAuthenticated) {
      try {
        debugPrint('AuthProvider: Refreshing user data from server...');
        final response = await AuthApiService.getProfile(_token!);
        if (response.success && response.user != null) {
          debugPrint('AuthProvider: User data refreshed successfully');
          debugPrint(
            'AuthProvider: User data - firstName: ${response.user!.firstName}, lastName: ${response.user!.lastName}',
          );
          debugPrint(
            'AuthProvider: User data - phone: ${response.user!.phone}, dateOfBirth: ${response.user!.dateOfBirth}',
          );
          debugPrint(
            'AuthProvider: User data - address: ${response.user!.address}, city: ${response.user!.city}',
          );
          _user = response.user;
          await _saveUserData(_user!);
          notifyListeners();
        } else {
          debugPrint(
            'AuthProvider: Failed to refresh user data - ${response.message}',
          );
        }
      } catch (e) {
        debugPrint('AuthProvider: Error refreshing user data: $e');
      }
    } else {
      debugPrint(
        'AuthProvider: Skipping user data refresh - user not authenticated',
      );
    }
  }

  // Update user profile data locally
  void updateUserProfile(Map<String, dynamic> profileData) {
    if (_user != null) {
      // Create a new User object with updated data
      _user = User(
        id: _user!.id,
        firstName: profileData.containsKey('first_name')
            ? profileData['first_name']
            : _user!.firstName,
        lastName: profileData.containsKey('last_name')
            ? profileData['last_name']
            : _user!.lastName,
        email: _user!.email, // Don't update email through profile update
        phone: profileData.containsKey('phone_number')
            ? profileData['phone_number']
            : _user!.phone,
        profilePicture: _user!.profilePicture, // Preserve profile picture
        userType: _user!.userType,
        isActive: _user!.isActive,
        isVerified: _user!.isVerified,
        createdAt: _user!.createdAt,
        updatedAt: DateTime.now(),
        lastLoginAt: _user!.lastLoginAt,
        preferences: _user!.preferences,
        address: profileData.containsKey('address')
            ? profileData['address']
            : _user!.address,
        city: profileData.containsKey('city')
            ? profileData['city']
            : _user!.city,
        zipCode: profileData.containsKey('zip_code')
            ? profileData['zip_code']
            : _user!.zipCode,
        country: profileData.containsKey('country')
            ? profileData['country']
            : _user!.country,
        dateOfBirth: profileData.containsKey('date_of_birth')
            ? (profileData['date_of_birth'] != null
                  ? DateTime.tryParse(profileData['date_of_birth'])
                  : null)
            : _user!.dateOfBirth,
        preferredLanguage: profileData.containsKey('preferred_language')
            ? profileData['preferred_language']
            : _user!.preferredLanguage,
      );

      // Save updated user data to SharedPreferences
      _saveUserData(_user!);
      notifyListeners();
    }
  }

  // Update token and notify all providers
  void updateToken(String? newToken) {
    if (_token != newToken) {
      _token = newToken;
      _isAuthenticated = newToken != null;

      // Save token immediately
      _saveAuthData();

      // Notify listeners to trigger provider updates
      notifyListeners();

      debugPrint(
        'AuthProvider: Token updated to ${newToken != null ? '${newToken.substring(0, 20)}...' : 'null'}',
      );
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

  // Get formatted error messages for UI
  String? getFormattedError() {
    return _errorMessage;
  }

  // Get current token for immediate use
  String? getCurrentToken() {
    return _token;
  }

  // Check if token is valid and not null
  bool get hasValidToken => _token != null && _token!.isNotEmpty;

  // Method to manually trigger provider updates (for use after login)
  void triggerProviderUpdates(BuildContext context) {
    if (_token != null) {
      debugPrint('DEBUG: AuthProvider manually triggering provider updates');
      // This will be called from the login screen after successful login
      // The actual provider updates are handled in app.dart via Consumer3
      notifyListeners();
    }
  }

  // Check if user has specific role
  bool hasRole(String role) {
    return _user?.userType == role;
  }

  bool get isCustomer => hasRole('customer');
  bool get isLibraryAdmin => hasRole('library_admin');
  bool get isDeliveryAdmin => hasRole('delivery_admin');

  // Force clear all data and reset to login state (for debugging)
  Future<void> forceResetToLogin() async {
    debugPrint('AuthProvider: Force resetting to login state');
    await clearAuthData();
    notifyListeners();
  }

  // Forgot password method
  Future<bool> forgotPassword(String email) async {
    debugPrint('DEBUG: AuthProvider.forgotPassword called with email: $email');
    _setLoading(true);
    _clearError();

    try {
      debugPrint('DEBUG: Calling AuthApiService.forgotPassword...');
      final response = await AuthApiService.forgotPassword(email);
      debugPrint('DEBUG: AuthApiService response received');
      debugPrint('DEBUG: Response success: ${response.success}');
      debugPrint('DEBUG: Response message: ${response.message}');

      if (response.success) {
        debugPrint('DEBUG: Password reset request successful');
        _setLoading(false);
        return true;
      } else {
        debugPrint('DEBUG: Password reset request failed: ${response.message}');
        _setError(response.message);
        _setLoading(false);
        return false;
      }
    } catch (e) {
      debugPrint('DEBUG: Exception in forgotPassword: $e');
      _setError('Network error: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Method to update token (for token refresh)
  void setToken(String newToken) {
    _token = newToken;
    _isAuthenticated = true;
    _saveAuthData(); // Save immediately
    _startTokenRefreshTimer(); // Restart timer
    notifyListeners();
    debugPrint('AuthProvider: Token updated via setToken method');
  }
}

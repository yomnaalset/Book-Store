import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/api_client.dart';

class ManagerSettingsProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic> _settings = {
    'language': 'en',
    'dark_mode': false,
    'email_notifications': true,
    'push_notifications': true,
    'sms_notifications': false,
    'items_per_page': 10,
    'auto_refresh': true,
    'refresh_interval': 30,
  };

  String? _authToken;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic> get settings => _settings;

  // Get specific settings
  String get language => _settings['language'] as String;
  bool get darkMode => _settings['dark_mode'] as bool;
  bool get emailNotifications => _settings['email_notifications'] as bool;
  bool get pushNotifications => _settings['push_notifications'] as bool;
  bool get smsNotifications => _settings['sms_notifications'] as bool;
  int get itemsPerPage => _settings['items_per_page'] as int;
  bool get autoRefresh => _settings['auto_refresh'] as bool;
  int get refreshInterval => _settings['refresh_interval'] as int;

  // SharedPreferences keys
  static const String _settingsKey = 'manager_settings';

  // Constructor
  ManagerSettingsProvider() {
    // Don't load settings automatically - only load when explicitly called
  }

  // Set auth token for API calls
  void setAuthToken(String? token) {
    _authToken = token;
  }

  // Load settings from server first, then fallback to SharedPreferences
  Future<void> loadSettings() async {
    _setLoading(true);
    _clearError();

    try {
      // Try to fetch settings from server first using new preferences endpoint
      try {
        final response = await ApiClient.get(
          '/preferences/settings/',
          token: _authToken,
        );
        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          if (responseData['success'] == true && responseData['data'] != null) {
            _settings = {..._settings, ...responseData['data']};
            debugPrint('ManagerSettingsProvider: Loaded settings from server');
          }
        }
      } catch (serverError) {
        debugPrint(
          'ManagerSettingsProvider: Server fetch failed, using local storage: $serverError',
        );

        // Fallback to local storage if server request fails
        final prefs = await SharedPreferences.getInstance();
        final storedSettings = prefs.getString(_settingsKey);

        if (storedSettings != null) {
          final Map<String, dynamic> loadedSettings = json.decode(
            storedSettings,
          );
          _settings = {..._settings, ...loadedSettings};
          debugPrint(
            'ManagerSettingsProvider: Loaded settings from local storage',
          );
        }
      }

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  // Update settings
  Future<void> updateSettings(Map<String, dynamic> newSettings) async {
    _setLoading(true);
    _clearError();

    try {
      // Update local settings first
      _settings = {..._settings, ...newSettings};

      // Try to save to server first using new preferences endpoint
      try {
        final response = await ApiClient.patch(
          '/preferences/settings/',
          body: _settings,
          token: _authToken,
        );
        if (response.statusCode == 200) {
          debugPrint('ManagerSettingsProvider: Settings saved to server');
        } else {
          throw Exception('Server returned status: ${response.statusCode}');
        }
      } catch (serverError) {
        debugPrint(
          'ManagerSettingsProvider: Server save failed, saving locally: $serverError',
        );
        // Continue with local save even if server fails
      }

      // Always save to SharedPreferences as backup
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_settingsKey, json.encode(_settings));

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  // Reset settings to default
  Future<void> resetToDefaults() async {
    _setLoading(true);
    _clearError();

    try {
      _settings = {
        'language': 'en',
        'dark_mode': false,
        'email_notifications': true,
        'push_notifications': true,
        'sms_notifications': false,
        'items_per_page': 10,
        'auto_refresh': true,
        'refresh_interval': 30,
      };

      // Try to reset on server first using new preferences endpoint
      try {
        final response = await ApiClient.post(
          '/preferences/settings/reset/',
          body: {'confirm_reset': true},
          token: _authToken,
        );
        if (response.statusCode == 200) {
          debugPrint('ManagerSettingsProvider: Settings reset on server');
        } else {
          throw Exception('Server returned status: ${response.statusCode}');
        }
      } catch (serverError) {
        debugPrint(
          'ManagerSettingsProvider: Server reset failed, resetting locally: $serverError',
        );
        // Continue with local reset even if server fails
      }

      // Always save to SharedPreferences as backup
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_settingsKey, json.encode(_settings));

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  // Utility methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}

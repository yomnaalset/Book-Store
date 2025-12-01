import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../core/services/api_config.dart';

class UserSettingsProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  String? _authToken;

  // API base URL - use ApiConfig for proper URL resolution
  String get _baseUrl => ApiConfig.getBaseUrl();

  // Notification Settings
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _smsNotifications = false;
  bool _orderUpdates = true;
  bool _bookAvailability = true;
  bool _borrowReminders = true;
  bool _deliveryUpdates = true;
  bool _promotionalEmails = false;
  bool _newsletter = false;

  // Privacy Settings
  bool _profileVisibility = true;
  bool _showEmail = false;
  bool _showPhone = false;
  bool _showAddress = false;
  bool _dataCollection = true;
  bool _analytics = true;
  bool _marketing = false;
  bool _thirdPartySharing = false;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Notification Settings Getters
  bool get emailNotifications => _emailNotifications;
  bool get pushNotifications => _pushNotifications;
  bool get smsNotifications => _smsNotifications;
  bool get orderUpdates => _orderUpdates;
  bool get bookAvailability => _bookAvailability;
  bool get borrowReminders => _borrowReminders;
  bool get deliveryUpdates => _deliveryUpdates;
  bool get promotionalEmails => _promotionalEmails;
  bool get newsletter => _newsletter;

  // Privacy Settings Getters
  bool get profileVisibility => _profileVisibility;
  bool get showEmail => _showEmail;
  bool get showPhone => _showPhone;
  bool get showAddress => _showAddress;
  bool get dataCollection => _dataCollection;
  bool get analytics => _analytics;
  bool get marketing => _marketing;
  bool get thirdPartySharing => _thirdPartySharing;

  // SharedPreferences keys
  static const String _notificationSettingsKey = 'user_notification_settings';
  static const String _privacySettingsKey = 'user_privacy_settings';

  // Constructor
  UserSettingsProvider() {
    // Don't automatically load settings - wait for explicit call with token
    debugPrint('UserSettingsProvider: Constructor called');
  }

  // Refresh all settings (useful when app becomes active)
  Future<void> refreshSettings() async {
    await loadAllSettings();
  }

  // Load settings with token (explicit method for screens)
  Future<void> loadSettingsWithToken(String token) async {
    debugPrint('UserSettingsProvider: loadSettingsWithToken() called');
    await loadAllSettings(token: token);
  }

  // Force save all current settings to server
  Future<void> forceSaveAllSettings() async {
    if (_authToken == null) {
      debugPrint(
        'UserSettingsProvider: No auth token available for force save',
      );
      return;
    }

    debugPrint('UserSettingsProvider: Force saving all settings to server...');

    try {
      // Save notification settings
      await _updateNotificationSettingsAPI({
        'email_notifications': _emailNotifications,
        'push_notifications': _pushNotifications,
        'sms_notifications': _smsNotifications,
        'order_updates': _orderUpdates,
        'book_availability': _bookAvailability,
        'borrow_reminders': _borrowReminders,
        'delivery_updates': _deliveryUpdates,
        'promotional_emails': _promotionalEmails,
        'newsletter': _newsletter,
      });

      // Save privacy settings
      await _updatePrivacySettingsAPI({
        'profile_visibility': _profileVisibility,
        'show_email': _showEmail,
        'show_phone': _showPhone,
        'show_address': _showAddress,
        'data_collection': _dataCollection,
        'analytics': _analytics,
        'marketing': _marketing,
        'third_party_sharing': _thirdPartySharing,
      });

      debugPrint('UserSettingsProvider: Force save completed successfully');
    } catch (e) {
      debugPrint('UserSettingsProvider: Force save failed: $e');
      rethrow;
    }
  }

  // Load all settings from API and SharedPreferences
  Future<void> loadAllSettings({String? token}) async {
    debugPrint(
      'UserSettingsProvider: loadAllSettings() called with token: ${token != null ? '${token.substring(0, 20)}...' : 'null'}',
    );

    _setLoading(true);
    _clearError();

    if (token != null) {
      _authToken = token;
      debugPrint(
        'UserSettingsProvider: Auth token set to: ${_authToken!.substring(0, 20)}...',
      );
    }

    try {
      // Try to load from API first
      if (_authToken != null) {
        debugPrint('UserSettingsProvider: Loading from API...');
        await Future.wait([
          _loadNotificationSettingsFromAPI(),
          _loadPrivacySettingsFromAPI(),
        ]);
        debugPrint('UserSettingsProvider: API loading completed successfully');
      } else {
        debugPrint(
          'UserSettingsProvider: No auth token, loading from SharedPreferences...',
        );
        // Fallback to SharedPreferences
        await Future.wait([
          _loadNotificationSettings(),
          _loadPrivacySettings(),
        ]);
        debugPrint('UserSettingsProvider: SharedPreferences loading completed');
      }
      _setLoading(false);
    } catch (e) {
      debugPrint('UserSettingsProvider: Error loading settings: $e');
      // Fallback to SharedPreferences if API fails
      try {
        debugPrint(
          'UserSettingsProvider: Attempting fallback to SharedPreferences...',
        );
        await Future.wait([
          _loadNotificationSettings(),
          _loadPrivacySettings(),
        ]);
        debugPrint(
          'UserSettingsProvider: Fallback to SharedPreferences successful',
        );
      } catch (fallbackError) {
        debugPrint(
          'UserSettingsProvider: Fallback also failed: $fallbackError',
        );
        _setError('Failed to load settings');
      }
      _setLoading(false);
    }
  }

  // Load notification settings from API
  Future<void> _loadNotificationSettingsFromAPI() async {
    if (_authToken == null) throw Exception('No auth token available');

    debugPrint(
      'UserSettingsProvider: Making API call to notification preferences...',
    );
    debugPrint(
      'UserSettingsProvider: URL: $_baseUrl/preferences/notifications/',
    );
    debugPrint(
      'UserSettingsProvider: Token: ${_authToken!.substring(0, 20)}...',
    );

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/preferences/notifications/'),
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'application/json',
        },
      );

      debugPrint(
        'UserSettingsProvider: Notification preferences API response: ${response.statusCode}',
      );
      debugPrint(
        'UserSettingsProvider: Notification preferences API body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final settings = data['data'];
          _emailNotifications = settings['email_notifications'] ?? true;
          _pushNotifications = settings['push_notifications'] ?? true;
          _smsNotifications = settings['sms_notifications'] ?? false;
          _orderUpdates = settings['order_updates'] ?? true;
          _bookAvailability = settings['book_availability'] ?? true;
          _borrowReminders = settings['borrow_reminders'] ?? true;
          _deliveryUpdates = settings['delivery_updates'] ?? true;
          _promotionalEmails = settings['promotional_emails'] ?? false;
          _newsletter = settings['newsletter'] ?? false;

          // Save to SharedPreferences as backup
          await _saveNotificationSettingsToLocal();

          debugPrint(
            'UserSettingsProvider: Notification preferences loaded from API successfully',
          );
          notifyListeners();
        } else {
          throw Exception(
            data['message'] ?? 'Failed to load notification preferences',
          );
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['message'] ?? 'Failed to load notification preferences',
        );
      }
    } catch (e) {
      debugPrint(
        'UserSettingsProvider: Error loading notification preferences from API: $e',
      );
      rethrow;
    }
  }

  // Load notification settings from SharedPreferences
  Future<void> _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final storedSettings = prefs.getString(_notificationSettingsKey);

    if (storedSettings != null) {
      final Map<String, dynamic> loadedSettings = json.decode(storedSettings);
      _emailNotifications = loadedSettings['emailNotifications'] ?? true;
      _pushNotifications = loadedSettings['pushNotifications'] ?? true;
      _smsNotifications = loadedSettings['smsNotifications'] ?? false;
      _orderUpdates = loadedSettings['orderUpdates'] ?? true;
      _bookAvailability = loadedSettings['bookAvailability'] ?? true;
      _borrowReminders = loadedSettings['borrowReminders'] ?? true;
      _deliveryUpdates = loadedSettings['deliveryUpdates'] ?? true;
      _promotionalEmails = loadedSettings['promotionalEmails'] ?? false;
      _newsletter = loadedSettings['newsletter'] ?? false;
    }
  }

  // Load privacy settings from API
  Future<void> _loadPrivacySettingsFromAPI() async {
    if (_authToken == null) throw Exception('No auth token available');

    debugPrint(
      'UserSettingsProvider: Making API call to privacy preferences...',
    );
    debugPrint('UserSettingsProvider: URL: $_baseUrl/preferences/privacy/');
    debugPrint(
      'UserSettingsProvider: Token: ${_authToken!.substring(0, 20)}...',
    );

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/preferences/privacy/'),
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'application/json',
        },
      );

      debugPrint(
        'UserSettingsProvider: Privacy preferences API response: ${response.statusCode}',
      );
      debugPrint(
        'UserSettingsProvider: Privacy preferences API body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final settings = data['data'];
          _profileVisibility = settings['profile_visibility'] ?? true;
          _showEmail = settings['show_email'] ?? false;
          _showPhone = settings['show_phone'] ?? false;
          _showAddress = settings['show_address'] ?? false;
          _dataCollection = settings['data_collection'] ?? true;
          _analytics = settings['analytics'] ?? true;
          _marketing = settings['marketing'] ?? false;
          _thirdPartySharing = settings['third_party_sharing'] ?? false;

          // Save to SharedPreferences as backup
          await _savePrivacySettingsToLocal();

          debugPrint(
            'UserSettingsProvider: Privacy preferences loaded from API successfully',
          );
          notifyListeners();
        } else {
          throw Exception(
            data['message'] ?? 'Failed to load privacy preferences',
          );
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['message'] ?? 'Failed to load privacy preferences',
        );
      }
    } catch (e) {
      debugPrint(
        'UserSettingsProvider: Error loading privacy preferences from API: $e',
      );
      rethrow;
    }
  }

  // Load privacy settings from SharedPreferences
  Future<void> _loadPrivacySettings() async {
    final prefs = await SharedPreferences.getInstance();
    final storedSettings = prefs.getString(_privacySettingsKey);

    if (storedSettings != null) {
      final Map<String, dynamic> loadedSettings = json.decode(storedSettings);
      _profileVisibility = loadedSettings['profileVisibility'] ?? true;
      _showEmail = loadedSettings['showEmail'] ?? false;
      _showPhone = loadedSettings['showPhone'] ?? false;
      _showAddress = loadedSettings['showAddress'] ?? false;
      _dataCollection = loadedSettings['dataCollection'] ?? true;
      _analytics = loadedSettings['analytics'] ?? true;
      _marketing = loadedSettings['marketing'] ?? false;
      _thirdPartySharing = loadedSettings['thirdPartySharing'] ?? false;
    }
  }

  // Update notification settings
  Future<void> updateNotificationSettings({
    bool? emailNotifications,
    bool? pushNotifications,
    bool? smsNotifications,
    bool? orderUpdates,
    bool? bookAvailability,
    bool? borrowReminders,
    bool? deliveryUpdates,
    bool? promotionalEmails,
    bool? newsletter,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Update local state first
      if (emailNotifications != null) _emailNotifications = emailNotifications;
      if (pushNotifications != null) _pushNotifications = pushNotifications;
      if (smsNotifications != null) _smsNotifications = smsNotifications;
      if (orderUpdates != null) _orderUpdates = orderUpdates;
      if (bookAvailability != null) _bookAvailability = bookAvailability;
      if (borrowReminders != null) _borrowReminders = borrowReminders;
      if (deliveryUpdates != null) _deliveryUpdates = deliveryUpdates;
      if (promotionalEmails != null) _promotionalEmails = promotionalEmails;
      if (newsletter != null) _newsletter = newsletter;

      // Try to save to API first
      if (_authToken != null) {
        try {
          await _updateNotificationSettingsAPI({
            if (emailNotifications != null)
              'email_notifications': emailNotifications,
            if (pushNotifications != null)
              'push_notifications': pushNotifications,
            if (smsNotifications != null) 'sms_notifications': smsNotifications,
            if (orderUpdates != null) 'order_updates': orderUpdates,
            if (bookAvailability != null) 'book_availability': bookAvailability,
            if (borrowReminders != null) 'borrow_reminders': borrowReminders,
            if (deliveryUpdates != null) 'delivery_updates': deliveryUpdates,
            if (promotionalEmails != null)
              'promotional_emails': promotionalEmails,
            if (newsletter != null) 'newsletter': newsletter,
          });
        } catch (e) {
          debugPrint(
            'UserSettingsProvider: API update failed, saving locally: $e',
          );
          // Continue with local save if API fails
        }
      }

      // Save to SharedPreferences as backup
      await _saveNotificationSettingsToLocal();

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  // Update privacy settings
  Future<void> updatePrivacySettings({
    bool? profileVisibility,
    bool? showEmail,
    bool? showPhone,
    bool? showAddress,
    bool? dataCollection,
    bool? analytics,
    bool? marketing,
    bool? thirdPartySharing,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Update local state first
      if (profileVisibility != null) _profileVisibility = profileVisibility;
      if (showEmail != null) _showEmail = showEmail;
      if (showPhone != null) _showPhone = showPhone;
      if (showAddress != null) _showAddress = showAddress;
      if (dataCollection != null) _dataCollection = dataCollection;
      if (analytics != null) _analytics = analytics;
      if (marketing != null) _marketing = marketing;
      if (thirdPartySharing != null) _thirdPartySharing = thirdPartySharing;

      // Try to save to API first
      if (_authToken != null) {
        try {
          await _updatePrivacySettingsAPI({
            if (profileVisibility != null)
              'profile_visibility': profileVisibility,
            if (showEmail != null) 'show_email': showEmail,
            if (showPhone != null) 'show_phone': showPhone,
            if (showAddress != null) 'show_address': showAddress,
            if (dataCollection != null) 'data_collection': dataCollection,
            if (analytics != null) 'analytics': analytics,
            if (marketing != null) 'marketing': marketing,
            if (thirdPartySharing != null)
              'third_party_sharing': thirdPartySharing,
          });
        } catch (e) {
          debugPrint(
            'UserSettingsProvider: API update failed, saving locally: $e',
          );
          // Continue with local save if API fails
        }
      }

      // Save to SharedPreferences as backup
      await _savePrivacySettingsToLocal();

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  // Reset notification settings to default
  Future<void> resetNotificationSettings() async {
    await updateNotificationSettings(
      emailNotifications: true,
      pushNotifications: true,
      smsNotifications: false,
      orderUpdates: true,
      bookAvailability: true,
      borrowReminders: true,
      deliveryUpdates: true,
      promotionalEmails: false,
      newsletter: false,
    );
  }

  // Reset privacy settings to default
  Future<void> resetPrivacySettings() async {
    await updatePrivacySettings(
      profileVisibility: true,
      showEmail: false,
      showPhone: false,
      showAddress: false,
      dataCollection: true,
      analytics: true,
      marketing: false,
      thirdPartySharing: false,
    );
  }

  // API helper methods
  Future<void> _updateNotificationSettingsAPI(
    Map<String, bool> settings,
  ) async {
    if (_authToken == null) throw Exception('No auth token available');

    final response = await http.put(
      Uri.parse('$_baseUrl/preferences/notifications/'),
      headers: {
        'Authorization': 'Bearer $_authToken',
        'Content-Type': 'application/json',
      },
      body: json.encode(settings),
    );

    debugPrint(
      'UserSettingsProvider: Update notification preferences API response: ${response.statusCode}',
    );
    debugPrint(
      'UserSettingsProvider: Update notification preferences API body: ${response.body}',
    );

    if (response.statusCode != 200) {
      final errorData = json.decode(response.body);
      throw Exception(
        errorData['message'] ?? 'Failed to update notification preferences',
      );
    }
  }

  Future<void> _updatePrivacySettingsAPI(Map<String, bool> settings) async {
    if (_authToken == null) throw Exception('No auth token available');

    final response = await http.put(
      Uri.parse('$_baseUrl/preferences/privacy/'),
      headers: {
        'Authorization': 'Bearer $_authToken',
        'Content-Type': 'application/json',
      },
      body: json.encode(settings),
    );

    debugPrint(
      'UserSettingsProvider: Update privacy preferences API response: ${response.statusCode}',
    );
    debugPrint(
      'UserSettingsProvider: Update privacy preferences API body: ${response.body}',
    );

    if (response.statusCode != 200) {
      final errorData = json.decode(response.body);
      throw Exception(
        errorData['message'] ?? 'Failed to update privacy preferences',
      );
    }
  }

  // Local storage helper methods
  Future<void> _saveNotificationSettingsToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = {
      'emailNotifications': _emailNotifications,
      'pushNotifications': _pushNotifications,
      'smsNotifications': _smsNotifications,
      'orderUpdates': _orderUpdates,
      'bookAvailability': _bookAvailability,
      'borrowReminders': _borrowReminders,
      'deliveryUpdates': _deliveryUpdates,
      'promotionalEmails': _promotionalEmails,
      'newsletter': _newsletter,
    };
    await prefs.setString(_notificationSettingsKey, json.encode(settings));
  }

  Future<void> _savePrivacySettingsToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = {
      'profileVisibility': _profileVisibility,
      'showEmail': _showEmail,
      'showPhone': _showPhone,
      'showAddress': _showAddress,
      'dataCollection': _dataCollection,
      'analytics': _analytics,
      'marketing': _marketing,
      'thirdPartySharing': _thirdPartySharing,
    };
    await prefs.setString(_privacySettingsKey, json.encode(settings));
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

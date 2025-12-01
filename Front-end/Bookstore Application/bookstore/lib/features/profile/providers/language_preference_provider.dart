import 'package:flutter/material.dart';
import '../services/language_preference_service.dart';
import '../../../core/translations.dart';

class LanguagePreferenceProvider extends ChangeNotifier {
  final LanguagePreferenceService _languageService;
  final TranslationsProvider _translationsProvider;

  String? _currentLanguage;
  List<Map<String, dynamic>> _availableLanguages = [];
  bool _isLoading = false;
  String? _errorMessage;

  LanguagePreferenceProvider({
    required LanguagePreferenceService languageService,
    required TranslationsProvider translationsProvider,
  }) : _languageService = languageService,
       _translationsProvider = translationsProvider;

  // Getters
  String? get currentLanguage => _currentLanguage;
  List<Map<String, dynamic>> get availableLanguages => _availableLanguages;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Load available language options
  Future<void> loadLanguageOptions() async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _languageService.getLanguageOptions();

      if (response['success'] == true) {
        final data = response['data'];
        _availableLanguages = List<Map<String, dynamic>>.from(
          data['languages'],
        );
        _currentLanguage = data['current_language'];
        notifyListeners();
      } else {
        _setError(response['message'] ?? 'Failed to load language options');
      }
    } catch (e) {
      _setError('Error loading language options: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Load current user's language preference
  Future<void> loadCurrentLanguagePreference(String token) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _languageService.getCurrentLanguagePreference(
        token,
      );

      if (response['success'] == true) {
        final data = response['data'];
        _currentLanguage = data['preferred_language'];
        notifyListeners();
      } else {
        _setError(response['message'] ?? 'Failed to load language preference');
      }
    } catch (e) {
      _setError('Error loading language preference: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Update language preference
  Future<bool> updateLanguagePreference(String token, String language) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _languageService.updateLanguagePreference(
        token,
        language,
      );

      if (response['success'] == true) {
        _currentLanguage = language;

        // Update the TranslationsProvider with the new locale
        await _translationsProvider.changeLocale(Locale(language));

        notifyListeners();
        return true;
      } else {
        _setError(
          response['message'] ?? 'Failed to update language preference',
        );
        return false;
      }
    } catch (e) {
      _setError('Error updating language preference: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Get language display name
  String getLanguageDisplayName(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'ar':
        return 'العربية';
      default:
        return languageCode;
    }
  }

  // Get current language display name
  String get currentLanguageDisplayName {
    if (_currentLanguage == null) return 'English';
    return getLanguageDisplayName(_currentLanguage!);
  }

  // Check if language is RTL
  bool isRTL(String languageCode) {
    return languageCode == 'ar';
  }

  // Check if current language is RTL
  bool get isCurrentLanguageRTL {
    return _currentLanguage != null && isRTL(_currentLanguage!);
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
}

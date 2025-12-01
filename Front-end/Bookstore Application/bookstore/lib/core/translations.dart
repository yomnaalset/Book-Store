import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'localization/app_localizations.dart';

/// Manages app language and translations
class TranslationsProvider extends ChangeNotifier {
  static const String _languageKey = 'app_language';

  // Default locale
  Locale _currentLocale = const Locale('en', 'US');

  // Getters
  Locale get currentLocale => _currentLocale;
  List<Locale> get supportedLocales => AppLocalizations.supportedLocales;

  // Constructor - Load saved language preference
  TranslationsProvider() {
    _loadSavedLocale();
  }

  // Load saved locale from SharedPreferences
  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguageCode = prefs.getString(_languageKey);

    if (savedLanguageCode != null) {
      for (final locale in AppLocalizations.supportedLocales) {
        if (locale.languageCode == savedLanguageCode) {
          _currentLocale = locale;
          notifyListeners();
          break;
        }
      }
    }
  }

  // Load saved locale from SharedPreferences - public method for use by app startup
  Future<void> loadSavedLocale() async {
    await _loadSavedLocale();
  }

  // Change app language
  Future<void> changeLocale(Locale newLocale) async {
    // Check if locale is supported
    if (supportedLocales.any(
      (locale) => locale.languageCode == newLocale.languageCode,
    )) {
      _currentLocale = newLocale;

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, newLocale.languageCode);

      notifyListeners();
    }
  }

  // Get display name of language based on locale
  String getLanguageDisplayName(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'ar':
        return 'العربية';
      default:
        return locale.languageCode;
    }
  }

  // Get current language display name
  String get currentLanguageDisplayName =>
      getLanguageDisplayName(_currentLocale);
}

// Create a globally accessible class for app translations
class AppTranslations {
  static AppLocalizations of(BuildContext context) {
    return AppLocalizations.of(context);
  }

  // Convenience method for translations
  static String t(BuildContext context, String key) {
    return AppLocalizations.of(context).get(key);
  }
}

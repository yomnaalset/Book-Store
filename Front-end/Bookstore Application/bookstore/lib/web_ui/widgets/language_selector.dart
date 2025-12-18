import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/translations.dart';
import '../../core/localization/app_localizations.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/profile/providers/language_preference_provider.dart';
import '../../core/constants/app_colors.dart';

/// Language selector widget for admin panel header
/// Provides quick access to switch between Arabic (RTL) and English (LTR)
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final translationsProvider = Provider.of<TranslationsProvider>(context);
    final currentLocale = translationsProvider.currentLocale;
    final currentLanguage = currentLocale.languageCode;

    return PopupMenuButton<String>(
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.language, color: Theme.of(context).colorScheme.onSurface),
          const SizedBox(width: 4),
          Text(
            currentLanguage.toUpperCase(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      tooltip: localizations.language,
      onSelected: (String languageCode) async {
        if (languageCode != currentLanguage) {
          await _changeLanguage(
            context,
            languageCode,
            translationsProvider,
            localizations,
          );
        }
      },
      itemBuilder: (BuildContext context) => [
        PopupMenuItem<String>(
          value: 'en',
          child: Row(
            children: [
              Icon(
                Icons.check,
                size: 20,
                color: currentLanguage == 'en'
                    ? Theme.of(context).primaryColor
                    : Colors.transparent,
              ),
              const SizedBox(width: 8),
              Text(localizations.englishLanguage),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'ar',
          child: Row(
            children: [
              Icon(
                Icons.check,
                size: 20,
                color: currentLanguage == 'ar'
                    ? Theme.of(context).primaryColor
                    : Colors.transparent,
              ),
              const SizedBox(width: 8),
              Text(localizations.arabicLanguage),
            ],
          ),
        ),
      ],
    );
  }

  /// Changes the app language and updates RTL/LTR layout
  Future<void> _changeLanguage(
    BuildContext context,
    String languageCode,
    TranslationsProvider translationsProvider,
    AppLocalizations localizations,
  ) async {
    try {
      // Capture context-dependent values before async gap
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      final languageProvider = token != null
          ? Provider.of<LanguagePreferenceProvider>(context, listen: false)
          : null;

      // Determine the new locale
      final newLocale = languageCode == 'ar'
          ? const Locale('ar', 'SA')
          : const Locale('en', 'US');

      // Update TranslationsProvider - this triggers:
      // 1. RTL/LTR layout switch (handled in app.dart builder)
      // 2. Translation file loading (handled by AppLocalizations.load())
      await translationsProvider.changeLocale(newLocale);

      // Optionally sync with server if user is authenticated
      if (token != null && languageProvider != null && context.mounted) {
        try {
          await languageProvider.updateLanguagePreference(token, languageCode);
        } catch (e) {
          // Silently fail - local change still works
          debugPrint('Failed to sync language to server: $e');
        }
      }

      // Show success message
      if (context.mounted) {
        final successMessage = languageCode == 'en'
            ? localizations.languageChangedToEnglish
            : localizations.languageChangedToArabic;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localizations.error}: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

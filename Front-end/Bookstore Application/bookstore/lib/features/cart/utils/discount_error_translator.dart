import '../../../core/localization/app_localizations.dart';

/// Helper class to translate discount code error messages
/// Since the backend sends English error messages, we translate them
class DiscountErrorTranslator {
  /// Translate discount error message based on error code or message pattern
  static String translateError(
    String? errorMessage,
    String? errorCode,
    AppLocalizations localizations,
  ) {
    // If we have an error code, use it for translation
    if (errorCode != null) {
      switch (errorCode) {
        case 'code_expired':
          return localizations.discountCodeExpired;
        case 'code_inactive':
          return localizations.discountCodeInactive;
        case 'already_applied':
          return localizations.discountCodeAlreadyApplied;
        case 'usage_limit_exceeded':
          return localizations.discountCodeUsageLimitExceeded;
        case 'invalid_code':
          return localizations.invalidDiscountCode;
        default:
          break;
      }
    }

    // If no error code, try to match message patterns
    if (errorMessage == null) {
      return localizations.invalidDiscountCode;
    }

    final messageLower = errorMessage.toLowerCase();

    if (messageLower.contains('expired')) {
      return localizations.discountCodeExpired;
    }
    if (messageLower.contains('no longer active') ||
        messageLower.contains('inactive')) {
      return localizations.discountCodeInactive;
    }
    if (messageLower.contains('already applied') ||
        messageLower.contains('already used')) {
      return localizations.discountCodeAlreadyApplied;
    }
    if (messageLower.contains('usage limit') ||
        messageLower.contains('maximum number of times')) {
      return localizations.discountCodeUsageLimitExceeded;
    }
    if (messageLower.contains('invalid')) {
      return localizations.invalidDiscountCode;
    }

    // Default: return original message if no pattern matches
    return errorMessage;
  }
}

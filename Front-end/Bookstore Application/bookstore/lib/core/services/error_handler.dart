import 'dart:io';

import 'package:flutter/foundation.dart';

class ErrorHandler {
  // Handles network-related errors
  static String handleNetworkError(dynamic error) {
    if (error is SocketException) {
      return 'No internet connection. Please check your network settings.';
    } else if (error is HttpException) {
      return 'Could not reach the server. Please try again later.';
    } else if (error is FormatException) {
      return 'Invalid response format from the server.';
    } else {
      return 'Network error: ${error.toString()}';
    }
  }

  // Handles API response errors
  static String handleApiError(int statusCode, Map<String, dynamic>? data) {
    switch (statusCode) {
      case 400:
        return data?['message'] ?? 'Invalid request. Please check your input.';
      case 401:
        return 'Authentication failed. Please log in again.';
      case 403:
        return 'You are not authorized to perform this action.';
      case 404:
        return 'Resource not found.';
      case 422:
        return data?['message'] ?? 'Validation error. Please check your input.';
      case 500:
      case 501:
      case 502:
      case 503:
        return 'Server error. Please try again later.';
      default:
        return data?['message'] ?? 'An unexpected error occurred.';
    }
  }

  // Logs errors to console or error reporting service
  static void logError(String source, dynamic error, StackTrace? stackTrace) {
    if (kDebugMode) {
      debugPrint('ERROR in $source: $error');
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    }

    // In a production app, you would log to a service like Firebase Crashlytics
    // For example:
    // FirebaseCrashlytics.instance.recordError(error, stackTrace);
  }

  // Formats validation errors from the API
  static String formatValidationErrors(Map<String, dynamic>? errors) {
    if (errors == null || errors.isEmpty) {
      return 'Validation failed.';
    }

    final List<String> formattedErrors = [];
    errors.forEach((field, messages) {
      if (messages is List) {
        formattedErrors.add('$field: ${messages.join(', ')}');
      } else {
        formattedErrors.add('$field: $messages');
      }
    });

    return formattedErrors.join('\n');
  }
}

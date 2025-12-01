import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/profile/providers/profile_provider.dart';
import '../../features/books/providers/books_provider.dart';
import '../../features/books/providers/authors_provider.dart' as books_authors;
import '../../features/books/providers/categories_provider.dart'
    as books_categories;
import '../../features/borrow/providers/borrow_provider.dart';
import '../../features/borrow/providers/borrowing_provider.dart';
import '../../features/notifications/providers/notifications_provider.dart';
import '../../features/admin/providers/library_manager/library_provider.dart';
import '../../features/admin/providers/library_manager/books_provider.dart'
    as admin_books;
import '../../features/admin/providers/library_manager/authors_provider.dart'
    as admin_authors;
import '../../features/admin/providers/categories_provider.dart'
    as admin_categories;
import '../../features/admin/providers/complaints_provider.dart';
import '../../features/admin/providers/reports_provider.dart';
import '../../features/admin/providers/delivery_provider.dart';
import '../../features/admin/providers/library_manager/ads_provider.dart';
import '../../features/admin/discounts/providers/discounts_provider.dart';
import '../../features/orders/providers/orders_provider.dart';
import '../../features/admin/orders/providers/orders_provider.dart'
    as admin_orders_provider;
import '../../features/admin/providers/notifications_provider.dart'
    as admin_notifications_provider;
import '../../features/admin/providers/manager_settings_provider.dart';
import '../../features/admin/providers/admin_borrowing_provider.dart';
import '../../features/delivery_manager/providers/delivery_status_provider.dart';
import '../../features/delivery_manager/providers/delivery_tasks_provider.dart';
import '../../features/delivery_manager/providers/notifications_provider.dart';
import '../../features/delivery/providers/delivery_settings_provider.dart';

/// Service to manage authentication tokens across all providers
class AuthService {
  static String? _lastToken;
  static DateTime? _lastUpdateTime;

  static void updateProvidersWithToken(BuildContext context, String? token) {
    try {
      // Avoid redundant updates with the same token
      if (_lastToken == token &&
          _lastUpdateTime != null &&
          DateTime.now().difference(_lastUpdateTime!).inSeconds < 5) {
        debugPrint('DEBUG: AuthService - Skipping redundant token update');
        return;
      }

      _lastToken = token;
      _lastUpdateTime = DateTime.now();

      debugPrint(
        'DEBUG: AuthService.updateProvidersWithToken called with token: ${token != null ? '${token.substring(0, 20)}...' : 'null'}',
      );

      // Update all providers that need authentication
      if (context.mounted) {
        // Profile provider - ensure it gets the token
        _updateProvider<ProfileProvider>(context, (provider) {
          provider.setToken(token);
          debugPrint('DEBUG: AuthService - ProfileProvider token updated');
        });

        // Books providers
        _updateProvider<BooksProvider>(
          context,
          (provider) => provider.setToken(token),
        );
        _updateProvider<books_authors.AuthorsProvider>(
          context,
          (provider) => provider.setToken(token),
        );
        _updateProvider<books_categories.CategoriesProvider>(
          context,
          (provider) => provider.setToken(token),
        );
        _updateProvider<BorrowProvider>(
          context,
          (provider) => provider.setToken(token),
        );
        _updateProvider<BorrowingProvider>(
          context,
          (provider) => provider.setToken(token),
        );
        _updateProvider<OrdersProvider>(
          context,
          (provider) => provider.setToken(token),
        );
        _updateProvider<NotificationsProvider>(context, (provider) {
          if (token != null && token.isNotEmpty) {
            provider.setToken(token);
            // Only refresh unread count when user is actually authenticated
            final authProvider = context.read<AuthProvider>();
            if (authProvider.isAuthenticated) {
              // Refresh unread count when user logs in
              provider.refreshUnreadCount();
            }
          }
        });

        // Admin providers
        _updateProvider<LibraryProvider>(
          context,
          (provider) => provider.setToken(token),
        );
        _updateProvider<admin_books.BooksProvider>(
          context,
          (provider) => provider.setToken(token),
        );
        _updateProvider<admin_authors.AuthorsProvider>(
          context,
          (provider) => provider.setToken(token),
        );
        _updateProvider<admin_categories.CategoriesProvider>(
          context,
          (provider) => provider.setToken(token),
        );
        _updateProvider<ComplaintsProvider>(
          context,
          (provider) => provider.setToken(token),
        );
        _updateProvider<ReportsProvider>(
          context,
          (provider) => provider.setToken(token),
        );
        _updateProvider<DeliveryProvider>(
          context,
          (provider) => provider.setToken(token),
        );
        _updateProvider<AdsProvider>(
          context,
          (provider) => provider.setToken(token),
        );
        _updateProvider<DiscountsProvider>(
          context,
          (provider) => provider.setToken(token),
        );
        _updateProvider<admin_orders_provider.OrdersProvider>(
          context,
          (provider) => provider.setToken(token),
        );
        _updateProvider<admin_notifications_provider.NotificationsProvider>(
          context,
          (provider) => provider.setToken(token),
        );
        _updateProvider<AdminBorrowingProvider>(context, (provider) {
          if (token != null) {
            provider.setToken(token);
          }
        });
        _updateProvider<ManagerSettingsProvider>(
          context,
          (provider) => provider.setAuthToken(token),
        );

        // Delivery providers
        _updateProvider<DeliveryStatusProvider>(
          context,
          (provider) => provider.setToken(token),
        );
        _updateProvider<DeliveryTasksProvider>(
          context,
          (provider) => provider.setToken(token),
        );
        _updateProvider<DeliveryNotificationsProvider>(
          context,
          (provider) => provider.setToken(token),
        );
        _updateProvider<DeliverySettingsProvider>(
          context,
          (provider) => provider.setToken(token, context: context),
        );

        debugPrint('DEBUG: AuthService completed updating all providers');
      }
    } catch (e) {
      debugPrint('DEBUG: AuthService error updating providers: $e');
    }
  }

  /// Helper method to safely update a provider with token
  static void _updateProvider<T>(
    BuildContext context,
    void Function(T) updateFunction,
  ) {
    try {
      final provider = context.read<T>();
      if (provider != null) {
        updateFunction(provider);
        debugPrint('DEBUG: AuthService successfully updated ${T.toString()}');
      } else {
        debugPrint('DEBUG: AuthService - ${T.toString()} provider is null');
      }
    } catch (e) {
      debugPrint('DEBUG: AuthService error updating ${T.toString()}: $e');
    }
  }

  /// Clear tokens from all providers (for logout)
  static void clearProvidersTokens(BuildContext context) {
    _lastToken = null;
    _lastUpdateTime = null;
    updateProvidersWithToken(context, null);
  }

  /// Force refresh all providers with current token
  static void forceRefreshProviders(BuildContext context, String? token) {
    _lastToken = null; // Reset to force update
    updateProvidersWithToken(context, token);
  }

  /// Validate token across all providers
  static Future<bool> validateTokenAcrossProviders(BuildContext context) async {
    try {
      // Import AuthProvider at the top of the file
      final authProvider = context.read<AuthProvider>();
      if (authProvider.token == null) return false;

      // Test a simple API call to validate token
      final reportsProvider = context.read<ReportsProvider>();
      reportsProvider.setToken(authProvider.token);

      // Try to make a simple API call
      await reportsProvider.getDashboardStats();
      return true;
    } catch (e) {
      debugPrint('Token validation failed: $e');
      return false;
    }
  }

  /// Get user profile data from server
  static Future<void> getUserProfile(BuildContext context) async {
    try {
      final authProvider = context.read<AuthProvider>();
      // Only refresh if user is authenticated with a valid token
      if (authProvider.token != null &&
          authProvider.token!.isNotEmpty &&
          authProvider.isAuthenticated) {
        debugPrint('AuthService: Refreshing user profile data...');
        await authProvider.refreshUserData();
        debugPrint('AuthService: User profile data refreshed successfully');
      } else {
        debugPrint(
          'AuthService: No authentication token available or user not authenticated',
        );
      }
    } catch (e) {
      debugPrint('AuthService: Error refreshing user profile: $e');
    }
  }
}

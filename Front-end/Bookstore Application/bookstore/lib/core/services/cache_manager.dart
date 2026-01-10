import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache management service for clearing stored data
class CacheManager {
  static const String _tag = 'CacheManager';

  /// Clear all cached data and force refresh from API
  static Future<void> clearAllCache() async {
    try {
      debugPrint('$_tag: Starting cache clear...');

      // Clear SharedPreferences (except user auth data)
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      // Preserve auth-related keys
      const preserveKeys = {
        'auth_token',
        'refresh_token',
        'user_data',
        'is_first_time',
      };

      for (String key in keys) {
        if (!preserveKeys.contains(key)) {
          await prefs.remove(key);
          debugPrint('$_tag: Removed cached key: $key');
        }
      }

      debugPrint('$_tag: Cache cleared successfully');
    } catch (e) {
      debugPrint('$_tag: Error clearing cache: $e');
    }
  }

  /// Clear only books-related cache
  static Future<void> clearBooksCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Remove books-related cached data
      const booksCacheKeys = [
        'cached_books',
        'cached_new_books',
        'cached_popular_books',
        'cached_borrowed_books',
        'books_cache_timestamp',
        'books_last_refresh',
      ];

      for (String key in booksCacheKeys) {
        await prefs.remove(key);
        debugPrint('$_tag: Removed books cache: $key');
      }

      debugPrint('$_tag: Books cache cleared');
    } catch (e) {
      debugPrint('$_tag: Error clearing books cache: $e');
    }
  }

  /// Clear only ads-related cache
  static Future<void> clearAdsCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Remove ads-related cached data
      const adsCacheKeys = [
        'cached_ads',
        'cached_public_ads',
        'ads_cache_timestamp',
        'ads_last_refresh',
      ];

      for (String key in adsCacheKeys) {
        await prefs.remove(key);
        debugPrint('$_tag: Removed ads cache: $key');
      }

      debugPrint('$_tag: Ads cache cleared');
    } catch (e) {
      debugPrint('$_tag: Error clearing ads cache: $e');
    }
  }

  /// Force refresh all providers with fresh API data
  static Future<void> forceRefreshAll() async {
    debugPrint('$_tag: Force refresh initiated');
    await clearAllCache();
    debugPrint('$_tag: All cache cleared, providers will fetch fresh data');
  }
}

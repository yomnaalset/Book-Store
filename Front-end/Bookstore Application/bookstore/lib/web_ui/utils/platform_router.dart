import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../admin/admin_web_dashboard.dart';
import '../delivery/delivery_web_dashboard.dart';
import '../../features/books/screens/home/home_screen.dart';

/// Determines the appropriate home screen based on platform and user role
class PlatformRouter {
  /// Returns the appropriate home widget based on platform and user role
  static Widget getHomeForUser(String? userRole) {
    // On web, use web dashboards for admin users
    if (kIsWeb) {
      if (userRole == 'admin' || userRole == 'library_admin') {
        return const AdminWebDashboard();
      }
      if (userRole == 'delivery_admin') {
        return const DeliveryWebDashboard();
      }
    }

    // On mobile, admin users are routed via getRouteForUser() which handles
    // navigation to mobile admin dashboards. This method is mainly for web.
    // For mobile, the routing happens through named routes in app_routes.dart
    
    // Otherwise (Normal User) -> Show existing Mobile Screens
    return const HomeScreen();
  }

  /// Gets the route name for navigation based on platform and user role
  static String getRouteForUser(String? userRole) {
    // Route admin users to their dashboards on both web and mobile
    if (userRole == 'admin') {
      return '/admin/dashboard';
    }
    if (userRole == 'library_admin') {
      return '/library/dashboard';
    }
    if (userRole == 'delivery_admin') {
      return '/delivery/dashboard';
    }

    // Otherwise (Normal User) -> Route to Mobile Home
    return '/home';
  }
}


import 'package:flutter/material.dart';

class DashboardCard {
  final String id;
  final String title;
  final String value;
  final String? subtitle;
  final String? description;
  final IconData? icon;
  final Color? color;
  final String? trend; // 'up', 'down', 'stable'
  final double? trendValue;
  final String? trendPeriod;
  final String? route;
  final Map<String, dynamic>? additionalData;
  final DateTime? lastUpdated;

  // Trend constants
  static const String trendUp = 'up';
  static const String trendDown = 'down';
  static const String trendStable = 'stable';

  DashboardCard({
    required this.id,
    required this.title,
    required this.value,
    this.subtitle,
    this.description,
    this.icon,
    this.color,
    this.trend,
    this.trendValue,
    this.trendPeriod,
    this.route,
    this.additionalData,
    this.lastUpdated,
  });

  factory DashboardCard.fromJson(Map<String, dynamic> json) {
    return DashboardCard(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      value: json['value']?.toString() ?? '0',
      subtitle: json['subtitle'],
      description: json['description'],
      icon: json['iconData'] != null
          ? IconData(json['iconData'], fontFamily: 'MaterialIcons')
          : null,
      color: json['color'] != null ? Color(json['color']) : null,
      trend: json['trend'],
      trendValue: json['trendValue'] != null
          ? double.tryParse(json['trendValue'].toString())
          : null,
      trendPeriod: json['trendPeriod'] ?? json['trend_period'],
      route: json['route'],
      additionalData: json['additionalData'] ?? json['additional_data'],
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : json['last_updated'] != null
          ? DateTime.parse(json['last_updated'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'value': value,
      'subtitle': subtitle,
      'description': description,
      'iconData': icon?.codePoint,
      'color': color?.toARGB32(),
      'trend': trend,
      'trendValue': trendValue,
      'trendPeriod': trendPeriod,
      'route': route,
      'additionalData': additionalData,
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }

  DashboardCard copyWith({
    String? id,
    String? title,
    String? value,
    String? subtitle,
    String? description,
    IconData? icon,
    Color? color,
    String? trend,
    double? trendValue,
    String? trendPeriod,
    String? route,
    Map<String, dynamic>? additionalData,
    DateTime? lastUpdated,
  }) {
    return DashboardCard(
      id: id ?? this.id,
      title: title ?? this.title,
      value: value ?? this.value,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      trend: trend ?? this.trend,
      trendValue: trendValue ?? this.trendValue,
      trendPeriod: trendPeriod ?? this.trendPeriod,
      route: route ?? this.route,
      additionalData: additionalData ?? this.additionalData,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  // Helper methods
  bool get hasTrend {
    return trend != null && trendValue != null;
  }

  bool get isPositiveTrend {
    return trend == trendUp;
  }

  bool get isNegativeTrend {
    return trend == trendDown;
  }

  bool get isStableTrend {
    return trend == trendStable;
  }

  String get formattedTrendValue {
    if (trendValue == null) return '';
    final sign = isPositiveTrend
        ? '+'
        : isNegativeTrend
        ? '-'
        : '';
    return '$sign${trendValue!.toStringAsFixed(1)}%';
  }

  // Factory methods for common card types
  factory DashboardCard.bookStats({
    required int totalBooks,
    required int availableBooks,
    String? trend,
    double? trendValue,
  }) {
    return DashboardCard(
      id: 'books',
      title: 'Total Books',
      value: totalBooks.toString(),
      subtitle: '$availableBooks available',
      icon: Icons.book,
      color: Colors.blue,
      trend: trend,
      trendValue: trendValue,
      route: '/admin/books',
    );
  }

  factory DashboardCard.orderStats({
    required int totalOrders,
    required int pendingOrders,
    String? trend,
    double? trendValue,
  }) {
    return DashboardCard(
      id: 'orders',
      title: 'Total Orders',
      value: totalOrders.toString(),
      subtitle: '$pendingOrders pending',
      icon: Icons.shopping_cart,
      color: Colors.green,
      trend: trend,
      trendValue: trendValue,
      route: '/admin/orders',
    );
  }

  factory DashboardCard.userStats({
    required int totalUsers,
    required int activeUsers,
    String? trend,
    double? trendValue,
  }) {
    return DashboardCard(
      id: 'users',
      title: 'Total Users',
      value: totalUsers.toString(),
      subtitle: '$activeUsers active',
      icon: Icons.people,
      color: Colors.orange,
      trend: trend,
      trendValue: trendValue,
      route: '/admin/users',
    );
  }

  factory DashboardCard.revenueStats({
    required double totalRevenue,
    required double monthlyRevenue,
    String? trend,
    double? trendValue,
  }) {
    return DashboardCard(
      id: 'revenue',
      title: 'Total Revenue',
      value: '\$${totalRevenue.toStringAsFixed(2)}',
      subtitle: '\$${monthlyRevenue.toStringAsFixed(2)} this month',
      icon: Icons.attach_money,
      color: Colors.purple,
      trend: trend,
      trendValue: trendValue,
      route: '/admin/reports/revenue',
    );
  }

  factory DashboardCard.authorStats({
    required int totalAuthors,
    String? trend,
    double? trendValue,
  }) {
    return DashboardCard(
      id: 'authors',
      title: 'Total Authors',
      value: totalAuthors.toString(),
      subtitle: 'Active authors',
      icon: Icons.person,
      color: Colors.indigo,
      trend: trend,
      trendValue: trendValue,
      route: '/admin/authors',
    );
  }

  factory DashboardCard.categoryStats({
    required int totalCategories,
    String? trend,
    double? trendValue,
  }) {
    return DashboardCard(
      id: 'categories',
      title: 'Total Categories',
      value: totalCategories.toString(),
      subtitle: 'Active categories',
      icon: Icons.category,
      color: Colors.teal,
      trend: trend,
      trendValue: trendValue,
      route: '/admin/categories',
    );
  }

  factory DashboardCard.ratingStats({
    required int totalRatings,
    required double avgRating,
  }) {
    return DashboardCard(
      id: 'ratings',
      title: 'Book Ratings',
      value: avgRating.toStringAsFixed(1),
      subtitle: '$totalRatings total ratings',
      icon: Icons.star,
      color: Colors.amber,
      route: '/admin/ratings',
    );
  }
}

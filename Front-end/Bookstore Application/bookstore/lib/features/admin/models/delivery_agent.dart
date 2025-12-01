import 'package:flutter/material.dart';

class DeliveryAgent {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String? address;
  final String? vehicleType;
  final String? vehicleNumber;
  final String status;
  final double? rating;
  final int totalDeliveries;
  final int completedDeliveries;
  final int activeDeliveries;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isAvailable;
  final double? latitude;
  final double? longitude;
  final String? profileImage;
  final String? notes;

  DeliveryAgent({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.address,
    this.vehicleType,
    this.vehicleNumber,
    required this.status,
    this.rating,
    this.totalDeliveries = 0,
    this.completedDeliveries = 0,
    this.activeDeliveries = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isAvailable = true,
    this.latitude,
    this.longitude,
    this.profileImage,
    this.notes,
  });

  factory DeliveryAgent.fromJson(Map<String, dynamic> json) {
    // Get status from multiple possible fields (status, delivery_status, status_display)
    String status = json['status'] ?? 
                    json['delivery_status'] ?? 
                    json['status_display'] ?? 
                    'offline';
    
    // Normalize status to lowercase for consistency
    status = status.toLowerCase();
    
    return DeliveryAgent(
      id: json['id'] ?? 0,
      name: json['name'] ?? json['full_name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? json['phone_number'] ?? '',
      address: json['address'],
      vehicleType: json['vehicleType'] ?? json['vehicle_type'],
      vehicleNumber: json['vehicleNumber'] ?? json['vehicle_number'],
      status: status,
      rating: json['rating'] != null
          ? double.tryParse(json['rating'].toString())
          : null,
      totalDeliveries: json['totalDeliveries'] ?? json['total_deliveries'] ?? 0,
      completedDeliveries:
          json['completedDeliveries'] ?? json['completed_deliveries'] ?? 0,
      activeDeliveries:
          json['activeDeliveries'] ?? json['active_deliveries'] ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      isAvailable: json['isAvailable'] ?? json['is_available'] ?? true,
      latitude: json['latitude'] != null
          ? double.tryParse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.tryParse(json['longitude'].toString())
          : null,
      profileImage: json['profileImage'] ?? json['profile_image'],
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'vehicleType': vehicleType,
      'vehicleNumber': vehicleNumber,
      'status': status,
      'rating': rating,
      'totalDeliveries': totalDeliveries,
      'completedDeliveries': completedDeliveries,
      'activeDeliveries': activeDeliveries,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isAvailable': isAvailable,
      'latitude': latitude,
      'longitude': longitude,
      'profileImage': profileImage,
      'notes': notes,
    };
  }

  DeliveryAgent copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? vehicleType,
    String? vehicleNumber,
    String? status,
    double? rating,
    int? totalDeliveries,
    int? completedDeliveries,
    int? activeDeliveries,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isAvailable,
    double? latitude,
    double? longitude,
    String? profileImage,
    String? notes,
  }) {
    return DeliveryAgent(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      completedDeliveries: completedDeliveries ?? this.completedDeliveries,
      activeDeliveries: activeDeliveries ?? this.activeDeliveries,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isAvailable: isAvailable ?? this.isAvailable,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      profileImage: profileImage ?? this.profileImage,
      notes: notes ?? this.notes,
    );
  }

  // Helper getters
  String get displayName => name;
  String get contactInfo => '$phone • $email';

  double get completionRate {
    if (totalDeliveries == 0) return 0.0;
    return (completedDeliveries + activeDeliveries) / totalDeliveries;
  }

  bool get isActive => status.toLowerCase() == 'active';
  bool get isOnline => isActive && isAvailable;

  String get statusDisplay {
    switch (status.toLowerCase()) {
      case 'active':
      case 'online':
        return 'Online';
      case 'inactive':
      case 'offline':
        return 'Offline';
      case 'busy':
        return 'Busy';
      default:
        return 'Offline';
    }
  }
  
  // Get status color for UI display
  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'active':
      case 'online':
        return Colors.green;
      case 'busy':
        return Colors.orange;
      case 'inactive':
      case 'offline':
      default:
        return Colors.grey;
    }
  }
  
  // Check if manager is online
  bool get isOnlineStatus => status.toLowerCase() == 'online' || status.toLowerCase() == 'active';
  
  // Check if manager is busy
  bool get isBusyStatus => status.toLowerCase() == 'busy';
  
  // Check if manager is offline
  bool get isOfflineStatus => status.toLowerCase() == 'offline' || status.toLowerCase() == 'inactive';

  String get vehicleInfo {
    if (vehicleType != null && vehicleNumber != null) {
      return '$vehicleType - $vehicleNumber';
    } else if (vehicleType != null) {
      return vehicleType!;
    } else if (vehicleNumber != null) {
      return vehicleNumber!;
    }
    return 'No vehicle info';
  }

  String get ratingDisplay {
    if (rating == null) return 'No rating';
    return '${rating!.toStringAsFixed(1)} ⭐';
  }

  String get performanceDisplay {
    return '${(completionRate * 100).toStringAsFixed(1)}% completion';
  }
}

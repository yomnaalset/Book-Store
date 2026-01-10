/// DeliveryRequest model for borrow requests.
/// For customers: Only includes status, delivery manager name, and location (only when in_delivery).
/// For admins: Includes full information including location data.
class BorrowDeliveryRequest {
  final int id;
  final String status;
  final String statusDisplay;
  final String? deliveryManagerName;
  final String? deliveryManagerEmail;
  final String? deliveryManagerPhone;
  final double?
  latitude; // Only available when status is 'in_delivery' (customer) or always (admin)
  final double?
  longitude; // Only available when status is 'in_delivery' (customer) or always (admin)
  final double?
  lastLatitude; // Admin: Delivery manager's current location latitude
  final double?
  lastLongitude; // Admin: Delivery manager's current location longitude
  final DateTime? locationUpdatedAt; // Admin: When location was last updated

  BorrowDeliveryRequest({
    required this.id,
    required this.status,
    required this.statusDisplay,
    this.deliveryManagerName,
    this.deliveryManagerEmail,
    this.deliveryManagerPhone,
    this.latitude,
    this.longitude,
    this.lastLatitude,
    this.lastLongitude,
    this.locationUpdatedAt,
  });

  factory BorrowDeliveryRequest.fromJson(Map<String, dynamic> json) {
    return BorrowDeliveryRequest(
      id: json['id'] ?? 0,
      status: json['status'] ?? 'pending',
      statusDisplay: json['status_display'] ?? json['status'] ?? 'Pending',
      deliveryManagerName: json['delivery_manager_name'],
      deliveryManagerEmail: json['delivery_manager_email'],
      deliveryManagerPhone: json['delivery_manager_phone'],
      latitude: json['latitude'] != null
          ? double.tryParse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.tryParse(json['longitude'].toString())
          : null,
      lastLatitude: json['last_latitude'] != null
          ? double.tryParse(json['last_latitude'].toString())
          : null,
      lastLongitude: json['last_longitude'] != null
          ? double.tryParse(json['last_longitude'].toString())
          : null,
      locationUpdatedAt: json['location_updated_at'] != null
          ? DateTime.tryParse(json['location_updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'status_display': statusDisplay,
      'delivery_manager_name': deliveryManagerName,
      'delivery_manager_email': deliveryManagerEmail,
      'delivery_manager_phone': deliveryManagerPhone,
      'latitude': latitude,
      'longitude': longitude,
      'last_latitude': lastLatitude,
      'last_longitude': lastLongitude,
      'location_updated_at': locationUpdatedAt?.toIso8601String(),
    };
  }

  /// Get customer-friendly status message based on DeliveryRequest status
  String getCustomerStatusMessage() {
    switch (status.toLowerCase()) {
      case 'assigned':
        return 'Order assigned to Delivery Manager';
      case 'accepted':
        return 'Delivery Manager accepted order';
      case 'in_delivery':
        return 'Order in delivery';
      case 'completed':
        return 'Order delivered';
      default:
        return statusDisplay;
    }
  }

  /// Check if location tracking is available
  /// For customers: only when status is 'in_delivery'
  /// For admins: when location data exists
  bool get hasLocationData {
    return (lastLatitude != null && lastLongitude != null) ||
        (latitude != null && longitude != null);
  }

  /// Check if location tracking is available
  /// Button should appear ONLY when delivery begins (status = 'in_delivery')
  /// Button should disappear when delivery is complete (status = 'completed')
  bool get canTrackLocation {
    final statusLower = status.toLowerCase();
    final hasLocation =
        (lastLatitude != null && lastLongitude != null) ||
        (latitude != null && longitude != null);

    // Location button is ONLY available when delivery is actively in progress
    // Show button: status = 'in_delivery'
    // Hide button: status = 'completed' or any other status
    return statusLower == 'in_delivery' && hasLocation;
  }
}

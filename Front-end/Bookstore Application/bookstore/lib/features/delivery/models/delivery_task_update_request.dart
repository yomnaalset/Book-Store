class DeliveryTaskUpdateRequest {
  final String status;
  final String? notes;
  final DateTime? estimatedDeliveryTime;
  final double? latitude;
  final double? longitude;
  final String? deliveryPersonId;
  final String? proofOfDelivery;
  final String? failureReason;
  final Map<String, dynamic>? metadata;

  DeliveryTaskUpdateRequest({
    required this.status,
    this.notes,
    this.estimatedDeliveryTime,
    this.latitude,
    this.longitude,
    this.deliveryPersonId,
    this.proofOfDelivery,
    this.failureReason,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'notes': notes,
      'estimated_delivery_time': estimatedDeliveryTime?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'delivery_person_id': deliveryPersonId,
      'proof_of_delivery': proofOfDelivery,
      'failure_reason': failureReason,
      'metadata': metadata,
    };
  }

  factory DeliveryTaskUpdateRequest.fromJson(Map<String, dynamic> json) {
    return DeliveryTaskUpdateRequest(
      status: json['status'],
      notes: json['notes'],
      estimatedDeliveryTime: json['estimated_delivery_time'] != null
          ? DateTime.parse(json['estimated_delivery_time'])
          : null,
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      deliveryPersonId: json['delivery_person_id'],
      proofOfDelivery: json['proof_of_delivery'],
      failureReason: json['failure_reason'],
      metadata: json['metadata'],
    );
  }
}

class ProofOfDelivery {
  final String id;
  final String deliveryTaskId;
  final String deliveredBy;
  final String? receivedBy;
  final String? signature;
  final List<String>? photos;
  final String? notes;
  final DateTime deliveredAt;
  final double? latitude;
  final double? longitude;

  ProofOfDelivery({
    required this.id,
    required this.deliveryTaskId,
    required this.deliveredBy,
    this.receivedBy,
    this.signature,
    this.photos,
    this.notes,
    required this.deliveredAt,
    this.latitude,
    this.longitude,
  });

  factory ProofOfDelivery.fromJson(Map<String, dynamic> json) {
    return ProofOfDelivery(
      id: json['id'],
      deliveryTaskId: json['delivery_task_id'],
      deliveredBy: json['delivered_by'],
      receivedBy: json['received_by'],
      signature: json['signature'],
      photos: json['photos'] != null ? List<String>.from(json['photos']) : null,
      notes: json['notes'],
      deliveredAt: DateTime.parse(json['delivered_at']),
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'delivery_task_id': deliveryTaskId,
      'delivered_by': deliveredBy,
      'received_by': receivedBy,
      'signature': signature,
      'photos': photos,
      'notes': notes,
      'delivered_at': deliveredAt.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class DeliveryETACalculation {
  final String deliveryTaskId;
  final DateTime estimatedArrival;
  final int estimatedDurationMinutes;
  final double distanceKm;
  final String trafficCondition;
  final String weatherCondition;
  final List<Map<String, dynamic>>? routeSteps;
  final Map<String, dynamic>? additionalInfo;

  DeliveryETACalculation({
    required this.deliveryTaskId,
    required this.estimatedArrival,
    required this.estimatedDurationMinutes,
    required this.distanceKm,
    required this.trafficCondition,
    required this.weatherCondition,
    this.routeSteps,
    this.additionalInfo,
  });

  factory DeliveryETACalculation.fromJson(Map<String, dynamic> json) {
    return DeliveryETACalculation(
      deliveryTaskId: json['delivery_task_id'],
      estimatedArrival: DateTime.parse(json['estimated_arrival']),
      estimatedDurationMinutes: json['estimated_duration_minutes'],
      distanceKm: json['distance_km'].toDouble(),
      trafficCondition: json['traffic_condition'],
      weatherCondition: json['weather_condition'],
      routeSteps: json['route_steps'] != null
          ? List<Map<String, dynamic>>.from(json['route_steps'])
          : null,
      additionalInfo: json['additional_info'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'delivery_task_id': deliveryTaskId,
      'estimated_arrival': estimatedArrival.toIso8601String(),
      'estimated_duration_minutes': estimatedDurationMinutes,
      'distance_km': distanceKm,
      'traffic_condition': trafficCondition,
      'weather_condition': weatherCondition,
      'route_steps': routeSteps,
      'additional_info': additionalInfo,
    };
  }

  // Helper methods
  String get formattedDuration {
    final hours = estimatedDurationMinutes ~/ 60;
    final minutes = estimatedDurationMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String get formattedDistance {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()}m';
    }
    return '${distanceKm.toStringAsFixed(1)}km';
  }

  bool get isDelayed {
    return estimatedArrival.isAfter(
      DateTime.now().add(Duration(minutes: estimatedDurationMinutes + 15)),
    );
  }

  bool get isOnTime {
    final now = DateTime.now();
    final expectedArrival = now.add(
      Duration(minutes: estimatedDurationMinutes),
    );
    final timeDifference = estimatedArrival
        .difference(expectedArrival)
        .inMinutes
        .abs();
    return timeDifference <= 15; // Within 15 minutes is considered on time
  }
}

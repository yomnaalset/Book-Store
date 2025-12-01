class DeliveryETA {
  final String taskId;
  final int estimatedMinutes;
  final double distance;
  final String unit;
  final DateTime estimatedArrival;
  final DateTime calculatedAt;

  DeliveryETA({
    required this.taskId,
    required this.estimatedMinutes,
    required this.distance,
    this.unit = 'km',
    required this.estimatedArrival,
    required this.calculatedAt,
  });

  factory DeliveryETA.fromJson(Map<String, dynamic> json) {
    return DeliveryETA(
      taskId: json['taskId']?.toString() ?? json['task_id']?.toString() ?? '',
      estimatedMinutes:
          json['estimatedMinutes'] ?? json['estimated_minutes'] ?? 0,
      distance: (json['distance'] is num) ? json['distance'].toDouble() : 0.0,
      unit: json['unit'] ?? 'km',
      estimatedArrival: json['estimatedArrival'] != null
          ? DateTime.parse(json['estimatedArrival'])
          : json['estimated_arrival'] != null
          ? DateTime.parse(json['estimated_arrival'])
          : DateTime.now().add(
              Duration(minutes: json['estimatedMinutes'] ?? 0),
            ),
      calculatedAt: json['calculatedAt'] != null
          ? DateTime.parse(json['calculatedAt'])
          : json['calculated_at'] != null
          ? DateTime.parse(json['calculated_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'estimatedMinutes': estimatedMinutes,
      'distance': distance,
      'unit': unit,
      'estimatedArrival': estimatedArrival.toIso8601String(),
      'calculatedAt': calculatedAt.toIso8601String(),
    };
  }

  String get formattedETA {
    if (estimatedMinutes < 1) {
      return 'Less than a minute';
    } else if (estimatedMinutes < 60) {
      return '$estimatedMinutes minutes';
    } else {
      final hours = estimatedMinutes ~/ 60;
      final minutes = estimatedMinutes % 60;
      if (minutes == 0) {
        return '$hours hour${hours > 1 ? 's' : ''}';
      } else {
        return '$hours hour${hours > 1 ? 's' : ''} $minutes minute${minutes > 1 ? 's' : ''}';
      }
    }
  }

  String get formattedDistance {
    if (distance < 0.1) {
      return 'Very close';
    } else {
      return '${distance.toStringAsFixed(1)} $unit';
    }
  }
}

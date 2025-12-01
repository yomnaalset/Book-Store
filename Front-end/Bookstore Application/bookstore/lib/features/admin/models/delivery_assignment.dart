import 'delivery_agent.dart';
import 'delivery_order.dart';

class DeliveryAssignment {
  final int id;
  final int orderId;
  final DeliveryOrder? order;
  final int deliveryManagerId;
  final DeliveryAgent? deliveryManager;
  final String status;
  final String deliveryAddress;
  final DateTime scheduledDate;
  final DateTime? deliveredDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? trackingNumber;
  final double? latitude;
  final double? longitude;
  final String? proofOfDelivery;
  final String? failureReason;
  final int retryCount;
  final DateTime? eta;
  final List<Map<String, dynamic>>? statusHistory;

  DeliveryAssignment({
    required this.id,
    required this.orderId,
    this.order,
    required this.deliveryManagerId,
    this.deliveryManager,
    required this.status,
    required this.deliveryAddress,
    required this.scheduledDate,
    this.deliveredDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.trackingNumber,
    this.latitude,
    this.longitude,
    this.proofOfDelivery,
    this.failureReason,
    this.retryCount = 0,
    this.eta,
    this.statusHistory,
  });

  factory DeliveryAssignment.fromJson(Map<String, dynamic> json) {
    return DeliveryAssignment(
      id: json['id'] ?? 0,
      orderId: json['orderId'] ?? json['order_id'] ?? 0,
      order: json['order'] != null
          ? DeliveryOrder.fromJson(json['order'])
          : null,
      deliveryManagerId:
          json['deliveryManagerId'] ?? json['delivery_manager_id'] ?? 0,
      deliveryManager: json['deliveryManager'] != null
          ? DeliveryAgent.fromJson(json['deliveryManager'])
          : json['delivery_manager'] != null
          ? DeliveryAgent.fromJson(json['delivery_manager'])
          : null,
      status: json['status'] ?? 'pending',
      deliveryAddress:
          json['deliveryAddress'] ?? json['delivery_address'] ?? '',
      scheduledDate: json['scheduledDate'] != null
          ? DateTime.parse(json['scheduledDate'])
          : json['scheduled_date'] != null
          ? DateTime.parse(json['scheduled_date'])
          : DateTime.now().add(const Duration(days: 1)),
      deliveredDate: json['deliveredDate'] != null
          ? DateTime.parse(json['deliveredDate'])
          : json['delivered_date'] != null
          ? DateTime.parse(json['delivered_date'])
          : null,
      notes: json['notes'],
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
      trackingNumber: json['trackingNumber'] ?? json['tracking_number'],
      latitude: json['latitude'] != null
          ? double.tryParse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.tryParse(json['longitude'].toString())
          : null,
      proofOfDelivery: json['proofOfDelivery'] ?? json['proof_of_delivery'],
      failureReason: json['failureReason'] ?? json['failure_reason'],
      retryCount: json['retryCount'] ?? json['retry_count'] ?? 0,
      eta: json['eta'] != null ? DateTime.parse(json['eta']) : null,
      statusHistory: json['statusHistory'] != null
          ? List<Map<String, dynamic>>.from(json['statusHistory'])
          : json['status_history'] != null
          ? List<Map<String, dynamic>>.from(json['status_history'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderId': orderId,
      'order': order?.toJson(),
      'deliveryManagerId': deliveryManagerId,
      'deliveryManager': deliveryManager?.toJson(),
      'status': status,
      'deliveryAddress': deliveryAddress,
      'scheduledDate': scheduledDate.toIso8601String(),
      'deliveredDate': deliveredDate?.toIso8601String(),
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'trackingNumber': trackingNumber,
      'latitude': latitude,
      'longitude': longitude,
      'proofOfDelivery': proofOfDelivery,
      'failureReason': failureReason,
      'retryCount': retryCount,
      'eta': eta?.toIso8601String(),
      'statusHistory': statusHistory,
    };
  }

  DeliveryAssignment copyWith({
    int? id,
    int? orderId,
    DeliveryOrder? order,
    int? deliveryManagerId,
    DeliveryAgent? deliveryManager,
    String? status,
    String? deliveryAddress,
    DateTime? scheduledDate,
    DateTime? deliveredDate,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? trackingNumber,
    double? latitude,
    double? longitude,
    String? proofOfDelivery,
    String? failureReason,
    int? retryCount,
    DateTime? eta,
    List<Map<String, dynamic>>? statusHistory,
  }) {
    return DeliveryAssignment(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      order: order ?? this.order,
      deliveryManagerId: deliveryManagerId ?? this.deliveryManagerId,
      deliveryManager: deliveryManager ?? this.deliveryManager,
      status: status ?? this.status,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      deliveredDate: deliveredDate ?? this.deliveredDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      proofOfDelivery: proofOfDelivery ?? this.proofOfDelivery,
      failureReason: failureReason ?? this.failureReason,
      retryCount: retryCount ?? this.retryCount,
      eta: eta ?? this.eta,
      statusHistory: statusHistory ?? this.statusHistory,
    );
  }

  // Helper getters
  String? get agentName => deliveryManager?.name;
  String? get agentPhone => deliveryManager?.phone;
  String? get agentEmail => deliveryManager?.email;

  bool get isCompleted => status.toLowerCase() == 'delivered';
  bool get isInProgress =>
      status.toLowerCase() == 'in_progress' ||
      status.toLowerCase() == 'in progress';
  bool get isPending => status.toLowerCase() == 'pending';
  bool get isCancelled => status.toLowerCase() == 'cancelled';

  Duration? get deliveryDuration {
    if (deliveredDate != null) {
      return deliveredDate!.difference(scheduledDate);
    }
    return null;
  }

  bool get isOverdue {
    if (isCompleted) return false;
    return DateTime.now().isAfter(scheduledDate);
  }
}

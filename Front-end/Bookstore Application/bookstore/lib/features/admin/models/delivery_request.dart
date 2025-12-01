import '../../orders/models/order.dart';

class DeliveryRequest {
  final String id;
  final int orderId;
  final Order? order;
  final String status;
  final String? deliveryAgentId;
  final DateTime requestDate;
  final DateTime? scheduledDate;
  final DateTime? deliveredDate;
  final String? notes;
  final bool isUrgent;
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

  DeliveryRequest({
    required this.id,
    required this.orderId,
    this.order,
    required this.status,
    this.deliveryAgentId,
    required this.requestDate,
    this.scheduledDate,
    this.deliveredDate,
    this.notes,
    this.isUrgent = false,
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

  factory DeliveryRequest.fromJson(Map<String, dynamic> json) {
    return DeliveryRequest(
      id: json['id']?.toString() ?? '',
      orderId: json['orderId'] ?? json['order_id'] ?? json['id'] ?? 0,
      order: json['order'] != null ? Order.fromJson(json['order']) : null,
      status: json['status'] ?? 'pending',
      deliveryAgentId:
          json['deliveryAgentId']?.toString() ??
          json['delivery_agent_id']?.toString() ??
          json['delivery_manager_id']?.toString(),
      requestDate: json['requestDate'] != null
          ? DateTime.parse(json['requestDate'])
          : json['request_date'] != null
          ? DateTime.parse(json['request_date'])
          : DateTime.now(),
      scheduledDate: json['scheduledDate'] != null
          ? DateTime.parse(json['scheduledDate'])
          : json['scheduled_date'] != null
          ? DateTime.parse(json['scheduled_date'])
          : null,
      deliveredDate: json['deliveredDate'] != null
          ? DateTime.parse(json['deliveredDate'])
          : json['delivered_date'] != null
          ? DateTime.parse(json['delivered_date'])
          : null,
      notes: json['notes'],
      isUrgent: json['isUrgent'] ?? json['is_urgent'] ?? false,
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
      'status': status,
      'deliveryAgentId': deliveryAgentId,
      'requestDate': requestDate.toIso8601String(),
      'scheduledDate': scheduledDate?.toIso8601String(),
      'deliveredDate': deliveredDate?.toIso8601String(),
      'notes': notes,
      'isUrgent': isUrgent,
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

  DeliveryRequest copyWith({
    String? id,
    int? orderId,
    Order? order,
    String? status,
    String? deliveryAgentId,
    DateTime? requestDate,
    DateTime? scheduledDate,
    DateTime? deliveredDate,
    String? notes,
    bool? isUrgent,
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
    return DeliveryRequest(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      order: order ?? this.order,
      status: status ?? this.status,
      deliveryAgentId: deliveryAgentId ?? this.deliveryAgentId,
      requestDate: requestDate ?? this.requestDate,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      deliveredDate: deliveredDate ?? this.deliveredDate,
      notes: notes ?? this.notes,
      isUrgent: isUrgent ?? this.isUrgent,
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
  bool get isCompleted => status.toLowerCase() == 'delivered';
  bool get isInProgress =>
      status.toLowerCase() == 'in_progress' ||
      status.toLowerCase() == 'in progress';
  bool get isPending => status.toLowerCase() == 'pending';
  bool get isCancelled => status.toLowerCase() == 'cancelled';
  bool get isAssigned => deliveryAgentId != null && deliveryAgentId!.isNotEmpty;

  Duration? get deliveryDuration {
    if (deliveredDate != null) {
      return deliveredDate!.difference(requestDate);
    }
    return null;
  }

  bool get isOverdue {
    if (isCompleted) return false;
    if (scheduledDate == null) return false;
    return DateTime.now().isAfter(scheduledDate!);
  }

  String get statusDisplay {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'pending_assignment':
        return 'Pending Assignment';
      case 'assigned':
        return 'Assigned';
      case 'in_progress':
      case 'in progress':
        return 'In Progress';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
}

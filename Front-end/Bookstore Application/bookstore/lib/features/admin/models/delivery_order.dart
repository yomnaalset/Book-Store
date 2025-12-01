import '../../orders/models/order.dart';
import 'delivery_agent.dart';

class DeliveryOrder {
  final String id;
  final int orderId;
  final Order? order;
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final String deliveryAddress;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? notes;
  final DeliveryAgent? deliveryAgent;
  final String? trackingNumber;
  final DateTime? scheduledDate;
  final DateTime? deliveredDate;
  final double? latitude;
  final double? longitude;
  final String? proofOfDelivery;
  final String? failureReason;
  final int retryCount;
  final DateTime? eta;
  final List<Map<String, dynamic>>? statusHistory;

  DeliveryOrder({
    required this.id,
    required this.orderId,
    this.order,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
    this.deliveryAgent,
    this.trackingNumber,
    this.scheduledDate,
    this.deliveredDate,
    this.latitude,
    this.longitude,
    this.proofOfDelivery,
    this.failureReason,
    this.retryCount = 0,
    this.eta,
    this.statusHistory,
  });

  factory DeliveryOrder.fromJson(Map<String, dynamic> json) {
    return DeliveryOrder(
      id: json['id']?.toString() ?? '',
      orderId: json['orderId'] ?? json['order_id'] ?? 0,
      order: json['order'] != null ? Order.fromJson(json['order']) : null,
      customerName: json['customerName'] ?? json['customer_name'] ?? '',
      customerEmail: json['customerEmail'] ?? json['customer_email'] ?? '',
      customerPhone: json['customerPhone'] ?? json['customer_phone'] ?? '',
      deliveryAddress:
          json['deliveryAddress'] ?? json['delivery_address'] ?? '',
      status: json['status'] ?? 'pending',
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
      notes: json['notes'],
      deliveryAgent: json['deliveryAgent'] != null
          ? DeliveryAgent.fromJson(json['deliveryAgent'])
          : json['delivery_agent'] != null
          ? DeliveryAgent.fromJson(json['delivery_agent'])
          : null,
      trackingNumber: json['trackingNumber'] ?? json['tracking_number'],
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
      'customerName': customerName,
      'customerEmail': customerEmail,
      'customerPhone': customerPhone,
      'deliveryAddress': deliveryAddress,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'notes': notes,
      'deliveryAgent': deliveryAgent?.toJson(),
      'trackingNumber': trackingNumber,
      'scheduledDate': scheduledDate?.toIso8601String(),
      'deliveredDate': deliveredDate?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'proofOfDelivery': proofOfDelivery,
      'failureReason': failureReason,
      'retryCount': retryCount,
      'eta': eta?.toIso8601String(),
      'statusHistory': statusHistory,
    };
  }

  DeliveryOrder copyWith({
    String? id,
    int? orderId,
    Order? order,
    String? customerName,
    String? customerEmail,
    String? customerPhone,
    String? deliveryAddress,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
    DeliveryAgent? deliveryAgent,
    String? trackingNumber,
    DateTime? scheduledDate,
    DateTime? deliveredDate,
    double? latitude,
    double? longitude,
    String? proofOfDelivery,
    String? failureReason,
    int? retryCount,
    DateTime? eta,
    List<Map<String, dynamic>>? statusHistory,
  }) {
    return DeliveryOrder(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      order: order ?? this.order,
      customerName: customerName ?? this.customerName,
      customerEmail: customerEmail ?? this.customerEmail,
      customerPhone: customerPhone ?? this.customerPhone,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
      deliveryAgent: deliveryAgent ?? this.deliveryAgent,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      deliveredDate: deliveredDate ?? this.deliveredDate,
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

  Duration? get deliveryDuration {
    if (deliveredDate != null && scheduledDate != null) {
      return deliveredDate!.difference(scheduledDate!);
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
        return 'Pending';
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

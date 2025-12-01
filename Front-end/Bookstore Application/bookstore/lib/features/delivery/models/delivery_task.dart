class DeliveryTask {
  static const String statusPending = 'pending';
  static const String statusAssigned = 'assigned';
  static const String statusAccepted = 'accepted';
  static const String statusPickedUp = 'picked_up';
  static const String statusInTransit = 'in_transit';
  static const String statusDelivered = 'delivered';
  static const String statusCompleted = 'completed';
  static const String statusFailed = 'failed';
  static const String statusCancelled = 'cancelled';
  static const String statusReturned = 'returned';
  static const String statusOverdue = 'overdue';

  final String id;
  final String orderId;
  final String status;
  final String? deliveryPersonId;
  final String? customerId;
  final String? customerName;
  final String? customerPhone;
  final String? customerAddress;
  final String? customerEmail;
  final double? latitude;
  final double? longitude;
  final DateTime? scheduledDate;
  final DateTime? deliveredDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isUrgent;
  final String? notes;
  final List<String>? items;
  final String? taskType;
  final String? taskNumber;
  final String? deliveryAddress;
  final DateTime? estimatedDeliveryTime;
  final Duration? timeRemaining;
  final String? failureReason;
  final dynamic customer;
  final List<dynamic>? orderItems;
  final DateTime? assignedAt;
  final DateTime? acceptedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final DateTime? completedAt;
  final String? deliveryNotes;
  final int? retryCount;
  final DateTime? eta;
  final List<Map<String, dynamic>>? statusHistory;
  final String? proofOfDelivery;
  final String? deliveryCity;

  DeliveryTask({
    required this.id,
    required this.orderId,
    required this.status,
    this.deliveryPersonId,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.customerEmail,
    this.latitude,
    this.longitude,
    this.scheduledDate,
    this.deliveredDate,
    required this.createdAt,
    required this.updatedAt,
    this.isUrgent = false,
    this.notes,
    this.items,
    this.taskType,
    this.taskNumber,
    this.deliveryAddress,
    this.estimatedDeliveryTime,
    this.timeRemaining,
    this.failureReason,
    this.customer,
    this.orderItems,
    this.assignedAt,
    this.acceptedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.completedAt,
    this.deliveryNotes,
    this.retryCount,
    this.eta,
    this.statusHistory,
    this.proofOfDelivery,
    this.deliveryCity,
  });

  factory DeliveryTask.fromJson(Map<String, dynamic> json) {
    final DateTime? estimatedDeliveryTime =
        json['estimatedDeliveryTime'] != null
        ? DateTime.parse(json['estimatedDeliveryTime'])
        : json['estimated_delivery_time'] != null
        ? DateTime.parse(json['estimated_delivery_time'])
        : null;

    return DeliveryTask(
      id: json['id']?.toString() ?? '',
      orderId:
          json['orderId']?.toString() ??
          json['order_id']?.toString() ??
          json['order_number']?.toString() ??
          '',
      status: json['status'] ?? 'pending',
      deliveryPersonId:
          json['deliveryPersonId']?.toString() ??
          json['delivery_person_id']?.toString(),
      customerId:
          json['customerId']?.toString() ??
          json['customer_id']?.toString() ??
          json['customer']?.toString(),
      customerName: json['customerName'] ?? json['customer_name'],
      customerPhone: json['customerPhone'] ?? json['customer_phone'],
      customerAddress:
          json['customerAddress'] ??
          json['customer_address'] ??
          json['delivery_address'],
      customerEmail: json['customerEmail'] ?? json['customer_email'],
      latitude: json['latitude'] != null
          ? double.tryParse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.tryParse(json['longitude'].toString())
          : null,
      scheduledDate: json['scheduledDate'] != null
          ? DateTime.parse(json['scheduledDate'])
          : json['scheduled_date'] != null
          ? DateTime.parse(json['scheduled_date'])
          : json['preferred_delivery_time'] != null
          ? DateTime.parse(json['preferred_delivery_time'])
          : null,
      deliveredDate: json['deliveredDate'] != null
          ? DateTime.parse(json['deliveredDate'])
          : json['delivered_date'] != null
          ? DateTime.parse(json['delivered_date'])
          : null,
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
      isUrgent: json['isUrgent'] ?? json['is_urgent'] ?? false,
      notes: json['notes'],
      items: json['items'] != null ? List<String>.from(json['items']) : null,
      taskType: json['taskType'] ?? json['task_type'] ?? json['request_type'],
      taskNumber:
          json['taskNumber'] ?? json['task_number'] ?? json['order_number'],
      deliveryAddress:
          json['deliveryAddress'] ??
          json['delivery_address'] ??
          json['customerAddress'] ??
          json['customer_address'],
      estimatedDeliveryTime: estimatedDeliveryTime,
      timeRemaining: json['timeRemaining'] != null
          ? Duration(minutes: json['timeRemaining'])
          : json['time_remaining'] != null
          ? Duration(minutes: json['time_remaining'])
          : null,
      failureReason: json['failureReason'] ?? json['failure_reason'],
      customer: json['customer'],
      orderItems: json['orderItems'] ?? json['order_items'],
      assignedAt: json['assignedAt'] != null
          ? DateTime.parse(json['assignedAt'])
          : json['assigned_at'] != null
          ? DateTime.parse(json['assigned_at'])
          : null,
      acceptedAt: json['acceptedAt'] != null
          ? DateTime.parse(json['acceptedAt'])
          : json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'])
          : null,
      pickedUpAt: json['pickedUpAt'] != null
          ? DateTime.parse(json['pickedUpAt'])
          : json['picked_up_at'] != null
          ? DateTime.parse(json['picked_up_at'])
          : null,
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.parse(json['deliveredAt'])
          : json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'])
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      deliveryNotes: json['deliveryNotes'] ?? json['delivery_notes'],
      retryCount: json['retryCount'] ?? json['retry_count'],
      eta: json['eta'] != null ? DateTime.parse(json['eta']) : null,
      statusHistory: json['statusHistory'] != null
          ? List<Map<String, dynamic>>.from(json['statusHistory'])
          : json['status_history'] != null
          ? List<Map<String, dynamic>>.from(json['status_history'])
          : null,
      proofOfDelivery: json['proofOfDelivery'] ?? json['proof_of_delivery'],
      deliveryCity: json['deliveryCity'] ?? json['delivery_city'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderId': orderId,
      'status': status,
      'deliveryPersonId': deliveryPersonId,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
      'customerEmail': customerEmail,
      'latitude': latitude,
      'longitude': longitude,
      'scheduledDate': scheduledDate?.toIso8601String(),
      'deliveredDate': deliveredDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isUrgent': isUrgent,
      'notes': notes,
      'items': items,
      'taskType': taskType,
      'taskNumber': taskNumber,
      'deliveryAddress': deliveryAddress,
      'estimatedDeliveryTime': estimatedDeliveryTime?.toIso8601String(),
      'timeRemaining': timeRemaining?.inMinutes,
      'failureReason': failureReason,
      'customer': customer,
      'orderItems': orderItems,
      'assignedAt': assignedAt?.toIso8601String(),
      'acceptedAt': acceptedAt?.toIso8601String(),
      'pickedUpAt': pickedUpAt?.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'deliveryNotes': deliveryNotes,
      'retryCount': retryCount,
      'eta': eta?.toIso8601String(),
      'statusHistory': statusHistory,
      'proofOfDelivery': proofOfDelivery,
      'deliveryCity': deliveryCity,
    };
  }

  // Compatibility getters for task_detail_screen.dart
  String get taskId => id;
  String? get orderNumber => orderId;

  // Status check methods
  bool get canAccept => status == statusPending;
  bool get canPickup => status == statusAssigned;
  bool get canStartTransit => status == statusAssigned;
  bool get canDeliver => status == statusInTransit;
  bool get canComplete => status == statusDelivered;
  bool get isAccepted => status == statusAccepted;
  bool get isPickedUp => status == statusPickedUp;
  bool get isInTransit => status == statusInTransit;

  DeliveryTask copyWith({
    String? id,
    String? orderId,
    String? status,
    String? deliveryPersonId,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    String? customerEmail,
    double? latitude,
    double? longitude,
    DateTime? scheduledDate,
    DateTime? deliveredDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isUrgent,
    String? notes,
    List<String>? items,
    String? taskType,
    String? taskNumber,
    String? deliveryAddress,
    DateTime? estimatedDeliveryTime,
    Duration? timeRemaining,
    String? failureReason,
    dynamic customer,
    List<dynamic>? orderItems,
  }) {
    return DeliveryTask(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      status: status ?? this.status,
      deliveryPersonId: deliveryPersonId ?? this.deliveryPersonId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAddress: customerAddress ?? this.customerAddress,
      customerEmail: customerEmail ?? this.customerEmail,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      deliveredDate: deliveredDate ?? this.deliveredDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isUrgent: isUrgent ?? this.isUrgent,
      notes: notes ?? this.notes,
      items: items ?? this.items,
      taskType: taskType ?? this.taskType,
      taskNumber: taskNumber ?? this.taskNumber,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      estimatedDeliveryTime:
          estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      timeRemaining: timeRemaining ?? this.timeRemaining,
      failureReason: failureReason ?? this.failureReason,
      customer: customer ?? this.customer,
      orderItems: orderItems ?? this.orderItems,
    );
  }
}

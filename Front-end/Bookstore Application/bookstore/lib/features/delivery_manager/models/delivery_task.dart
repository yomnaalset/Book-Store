class DeliveryTask {
  final String id;
  final String taskNumber;
  final String taskType;
  final String status;
  final String orderId;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final String customerAddress;
  final String deliveryAddress;
  final String deliveryCity;
  final String? notes;
  final DateTime? assignedAt;
  final DateTime? acceptedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final DateTime? completedAt;
  final DateTime? estimatedDeliveryTime;
  final String? deliveryNotes;
  final String? failureReason;
  final int retryCount;
  final List<Map<String, dynamic>> items;
  final DateTime? eta;
  final List<Map<String, dynamic>> statusHistory;
  final Map<String, dynamic>? proofOfDelivery;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? assignedTo;
  final DateTime? scheduledDate;
  final DateTime? completedDate;
  final String? deliveryInstructions;
  final double? latitude;
  final double? longitude;

  // Status constants
  static const String statusPending = 'pending';
  static const String statusAssigned = 'assigned';
  static const String statusAccepted = 'accepted';
  static const String statusPickedUp = 'picked_up';
  static const String statusInProgress = 'in_progress';
  static const String statusInTransit = 'in_transit';
  static const String statusDelivered = 'delivered';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';
  static const String statusFailed = 'failed';

  // Task type constants
  static const String taskTypePickup = 'pickup';
  static const String taskTypeDelivery = 'delivery';
  static const String taskTypeReturn = 'return';

  DeliveryTask({
    required this.id,
    required this.taskNumber,
    required this.taskType,
    required this.status,
    required this.orderId,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    required this.customerAddress,
    required this.deliveryAddress,
    required this.deliveryCity,
    this.notes,
    this.assignedAt,
    this.acceptedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.completedAt,
    this.estimatedDeliveryTime,
    this.deliveryNotes,
    this.failureReason,
    this.retryCount = 0,
    this.items = const [],
    this.eta,
    this.statusHistory = const [],
    this.proofOfDelivery,
    required this.createdAt,
    required this.updatedAt,
    this.assignedTo,
    this.scheduledDate,
    this.completedDate,
    this.deliveryInstructions,
    this.latitude,
    this.longitude,
  });

  factory DeliveryTask.fromJson(Map<String, dynamic> json) {
    return DeliveryTask(
      id: json['id']?.toString() ?? '',
      taskNumber: json['taskNumber'] ?? json['task_number'] ?? '',
      taskType: json['taskType'] ?? json['task_type'] ?? '',
      status: json['status'] ?? '',
      orderId: json['orderId'] ?? json['order_id'] ?? '',
      customerId: json['customerId'] ?? json['customer_id'] ?? '',
      customerName: json['customerName'] ?? json['customer_name'] ?? '',
      customerPhone: json['customerPhone'] ?? json['customer_phone'] ?? '',
      customerEmail: json['customerEmail'] ?? json['customer_email'] ?? '',
      customerAddress:
          json['customerAddress'] ?? json['customer_address'] ?? '',
      deliveryAddress:
          json['deliveryAddress'] ?? json['delivery_address'] ?? '',
      deliveryCity: json['deliveryCity'] ?? json['delivery_city'] ?? '',
      notes: json['notes'],
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
      estimatedDeliveryTime: json['estimatedDeliveryTime'] != null
          ? DateTime.parse(json['estimatedDeliveryTime'])
          : json['estimated_delivery_time'] != null
          ? DateTime.parse(json['estimated_delivery_time'])
          : null,
      deliveryNotes: json['deliveryNotes'] ?? json['delivery_notes'],
      failureReason: json['failureReason'] ?? json['failure_reason'],
      retryCount: json['retryCount'] ?? json['retry_count'] ?? 0,
      items:
          (json['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      eta: json['eta'] != null ? DateTime.parse(json['eta']) : null,
      statusHistory:
          (json['statusHistory'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [],
      proofOfDelivery: json['proofOfDelivery'] ?? json['proof_of_delivery'],
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
      assignedTo: json['assignedTo'] ?? json['assigned_to'],
      scheduledDate: json['scheduledDate'] != null
          ? DateTime.parse(json['scheduledDate'])
          : json['scheduled_date'] != null
          ? DateTime.parse(json['scheduled_date'])
          : null,
      completedDate: json['completedDate'] != null
          ? DateTime.parse(json['completedDate'])
          : json['completed_date'] != null
          ? DateTime.parse(json['completed_date'])
          : null,
      deliveryInstructions:
          json['deliveryInstructions'] ?? json['delivery_instructions'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'taskNumber': taskNumber,
      'taskType': taskType,
      'status': status,
      'orderId': orderId,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'assignedTo': assignedTo,
      'scheduledDate': scheduledDate?.toIso8601String(),
      'completedDate': completedDate?.toIso8601String(),
      'deliveryInstructions': deliveryInstructions,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  // Getter methods for computed properties
  String get taskId => id;

  Map<String, dynamic> get customer => {
    'id': customerId,
    'name': customerName,
    'phone': customerPhone,
    'email': customerEmail,
    'address': customerAddress,
  };

  List<Map<String, dynamic>> get orderItems => items;

  Duration? get timeRemaining {
    if (estimatedDeliveryTime == null) return null;
    final now = DateTime.now();
    final remaining = estimatedDeliveryTime!.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get canAccept => status == statusPending;
  bool get isAccepted => status == statusAccepted;
  bool get isPickedUp => status == statusInProgress && pickedUpAt != null;
  bool get isInTransit =>
      status == statusInProgress && pickedUpAt != null && deliveredAt == null;
  bool get canPickup => status == statusAccepted;
  bool get canStartTransit => isPickedUp;
  bool get canDeliver => isInTransit;
  bool get canComplete => status == statusInProgress && deliveredAt != null;

  DeliveryTask copyWith({
    String? id,
    String? taskNumber,
    String? taskType,
    String? status,
    String? orderId,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    String? deliveryAddress,
    String? deliveryCity,
    String? notes,
    DateTime? assignedAt,
    DateTime? acceptedAt,
    DateTime? pickedUpAt,
    DateTime? deliveredAt,
    DateTime? completedAt,
    DateTime? estimatedDeliveryTime,
    String? deliveryNotes,
    String? failureReason,
    int? retryCount,
    List<Map<String, dynamic>>? items,
    DateTime? eta,
    List<Map<String, dynamic>>? statusHistory,
    Map<String, dynamic>? proofOfDelivery,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? assignedTo,
    DateTime? scheduledDate,
    DateTime? completedDate,
    String? deliveryInstructions,
    double? latitude,
    double? longitude,
  }) {
    return DeliveryTask(
      id: id ?? this.id,
      taskNumber: taskNumber ?? this.taskNumber,
      taskType: taskType ?? this.taskType,
      status: status ?? this.status,
      orderId: orderId ?? this.orderId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      customerAddress: customerAddress ?? this.customerAddress,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryCity: deliveryCity ?? this.deliveryCity,
      notes: notes ?? this.notes,
      assignedAt: assignedAt ?? this.assignedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      completedAt: completedAt ?? this.completedAt,
      estimatedDeliveryTime:
          estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      deliveryNotes: deliveryNotes ?? this.deliveryNotes,
      failureReason: failureReason ?? this.failureReason,
      retryCount: retryCount ?? this.retryCount,
      items: items ?? this.items,
      eta: eta ?? this.eta,
      statusHistory: statusHistory ?? this.statusHistory,
      proofOfDelivery: proofOfDelivery ?? this.proofOfDelivery,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      assignedTo: assignedTo ?? this.assignedTo,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      completedDate: completedDate ?? this.completedDate,
      deliveryInstructions: deliveryInstructions ?? this.deliveryInstructions,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

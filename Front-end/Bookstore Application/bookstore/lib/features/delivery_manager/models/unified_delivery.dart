class UnifiedDelivery {
  final int id;
  final String deliveryType; // 'purchase', 'borrow', 'return'
  final String deliveryTypeDisplay;
  final String
  deliveryStatus; // 'waiting_for_approval', 'rejected', 'ready', 'in_progress', 'completed'
  final String deliveryStatusDisplay;
  final int? orderId;
  final String? orderNumber;
  final Map<String, dynamic>? order;
  final int customerId;
  final Map<String, dynamic>? customer;
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final int? deliveryManagerId;
  final Map<String, dynamic>? deliveryManager;
  final String? deliveryManagerName;
  final String? availabilityStatus; // 'online', 'offline', 'busy'
  final String deliveryAddress;
  final String? deliveryCity;
  final double? currentLatitude;
  final double? currentLongitude;
  final String? rejectionReason;
  final DateTime? assignedAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? notes;

  // Action flags
  final bool canApprove;
  final bool canReject;
  final bool canStart;
  final bool canComplete;

  // Status constants
  static const String statusWaitingForApproval = 'waiting_for_approval';
  static const String statusRejected = 'rejected';
  static const String statusReady = 'ready';
  static const String statusInProgress = 'in_progress';
  static const String statusCompleted = 'completed';

  // Type constants
  static const String typePurchase = 'purchase';
  static const String typeBorrow = 'borrow';
  static const String typeReturn = 'return';

  UnifiedDelivery({
    required this.id,
    required this.deliveryType,
    required this.deliveryTypeDisplay,
    required this.deliveryStatus,
    required this.deliveryStatusDisplay,
    this.orderId,
    this.orderNumber,
    this.order,
    required this.customerId,
    this.customer,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.deliveryManagerId,
    this.deliveryManager,
    this.deliveryManagerName,
    this.availabilityStatus,
    required this.deliveryAddress,
    this.deliveryCity,
    this.currentLatitude,
    this.currentLongitude,
    this.rejectionReason,
    this.assignedAt,
    this.approvedAt,
    this.rejectedAt,
    this.startedAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
    required this.canApprove,
    required this.canReject,
    required this.canStart,
    required this.canComplete,
  });

  // Helper methods for parsing JSON
  static int _parseCustomerId(Map<String, dynamic> json) {
    if (json['customer'] is int) {
      return json['customer'] as int;
    } else if (json['customer'] is Map) {
      final customerMap = json['customer'] as Map<String, dynamic>;
      return customerMap['id'] as int? ?? 0;
    } else if (json['customer_id'] != null) {
      return json['customer_id'] as int;
    }
    return 0;
  }

  static int? _parseDeliveryManagerId(Map<String, dynamic> json) {
    if (json['delivery_manager'] is int) {
      return json['delivery_manager'] as int;
    } else if (json['delivery_manager'] is Map) {
      final managerMap = json['delivery_manager'] as Map<String, dynamic>;
      return managerMap['id'] as int?;
    }
    return null;
  }

  factory UnifiedDelivery.fromJson(Map<String, dynamic> json) {
    // Handle status field - API returns 'status' but model expects 'delivery_status'
    final status = json['status'] ?? json['delivery_status'] ?? 'pending';
    final statusDisplay =
        json['status_display'] ?? json['delivery_status_display'] ?? status;

    // Handle delivery_address - can be null or empty string
    final deliveryAddress = json['delivery_address']?.toString() ?? '';

    // Handle latitude/longitude - API might return them as 'latitude'/'longitude' or 'current_latitude'/'current_longitude'
    final latitude = json['latitude'] ?? json['current_latitude'];
    final longitude = json['longitude'] ?? json['current_longitude'];

    return UnifiedDelivery(
      id: json['id'] as int,
      deliveryType: (json['delivery_type'] ?? 'purchase') as String,
      deliveryTypeDisplay:
          (json['delivery_type_display'] ??
                  json['delivery_type'] ??
                  'Purchase Delivery')
              as String,
      deliveryStatus: status as String,
      deliveryStatusDisplay: statusDisplay as String,
      orderId: json['order'] != null
          ? (json['order'] is int
                ? json['order'] as int
                : (json['order'] as Map<String, dynamic>?)?['id'] as int?)
          : null,
      orderNumber: json['order_number'] as String?,
      order: json['order'] is Map
          ? json['order'] as Map<String, dynamic>?
          : null,
      customerId: _parseCustomerId(json),
      customer: json['customer'] is Map
          ? json['customer'] as Map<String, dynamic>?
          : null,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      customerEmail: json['customer_email'] as String?,
      deliveryManagerId: _parseDeliveryManagerId(json),
      deliveryManager: json['delivery_manager'] is Map
          ? json['delivery_manager'] as Map<String, dynamic>?
          : null,
      deliveryManagerName: json['delivery_manager_name'] as String?,
      availabilityStatus: json['availability_status'] as String?,
      deliveryAddress: deliveryAddress,
      deliveryCity: json['delivery_city'] as String?,
      currentLatitude: latitude != null
          ? double.tryParse(latitude.toString())
          : null,
      currentLongitude: longitude != null
          ? double.tryParse(longitude.toString())
          : null,
      rejectionReason: json['rejection_reason'] as String?,
      assignedAt: json['assigned_at'] != null
          ? DateTime.tryParse(json['assigned_at'].toString())
          : null,
      approvedAt: json['approved_at'] != null
          ? DateTime.tryParse(json['approved_at'].toString())
          : null,
      rejectedAt: json['rejected_at'] != null
          ? DateTime.tryParse(json['rejected_at'].toString())
          : null,
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'].toString())
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
      createdAt:
          DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now(),
      notes: json['notes'] as String?,
      canApprove: json['can_approve'] as bool? ?? false,
      canReject: json['can_reject'] as bool? ?? false,
      canStart: json['can_start'] as bool? ?? false,
      canComplete: json['can_complete'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'delivery_type': deliveryType,
      'delivery_type_display': deliveryTypeDisplay,
      'delivery_status': deliveryStatus,
      'delivery_status_display': deliveryStatusDisplay,
      'order_id': orderId,
      'order_number': orderNumber,
      'order': order,
      'customer_id': customerId,
      'customer': customer,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_email': customerEmail,
      'delivery_manager_id': deliveryManagerId,
      'delivery_manager': deliveryManager,
      'delivery_manager_name': deliveryManagerName,
      'availability_status': availabilityStatus,
      'delivery_address': deliveryAddress,
      'delivery_city': deliveryCity,
      'current_latitude': currentLatitude,
      'current_longitude': currentLongitude,
      'rejection_reason': rejectionReason,
      'assigned_at': assignedAt?.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
      'rejected_at': rejectedAt?.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'notes': notes,
      'can_approve': canApprove,
      'can_reject': canReject,
      'can_start': canStart,
      'can_complete': canComplete,
    };
  }

  // Helper methods
  bool get isWaitingForApproval => deliveryStatus == statusWaitingForApproval;
  bool get isRejected => deliveryStatus == statusRejected;
  bool get isReady => deliveryStatus == statusReady;
  bool get isInProgress => deliveryStatus == statusInProgress;
  bool get isCompleted => deliveryStatus == statusCompleted;

  bool get isPurchase => deliveryType == typePurchase;
  bool get isBorrow => deliveryType == typeBorrow;
  bool get isReturn => deliveryType == typeReturn;
}

class DeliveryOrder {
  static const String statusPending = 'pending';
  static const String statusConfirmed = 'confirmed';
  static const String statusDelivered = 'delivered';
  static const String statusReturned = 'returned';

  static const String typePurchase = 'purchase';
  static const String typeBorrowing = 'borrowing';
  static const String typeReturnCollection = 'return_collection';

  static const Map<String, String> statusLabels = {
    statusPending: 'Pending',
    statusConfirmed: 'Confirmed',
    statusDelivered: 'Delivered',
    statusReturned: 'Returned',
  };

  static const Map<String, String> typeLabels = {
    typePurchase: 'Purchase',
    typeBorrowing: 'Borrowing',
    typeReturnCollection: 'Return Collection',
  };

  final int? id;
  final String orderNumber;
  final int customerId;
  final String customerName;
  final String customerEmail;
  final int? paymentId;
  final double totalAmount;
  final String orderType;
  final String status;
  final int? borrowRequestId;
  final String deliveryAddress;
  final String deliveryCity;
  final String? deliveryNotes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<DeliveryOrderItem>? items;
  final DeliveryAssignment? assignment;

  DeliveryOrder({
    this.id,
    required this.orderNumber,
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    this.paymentId,
    required this.totalAmount,
    required this.orderType,
    required this.status,
    this.borrowRequestId,
    required this.deliveryAddress,
    required this.deliveryCity,
    this.deliveryNotes,
    required this.createdAt,
    required this.updatedAt,
    this.items,
    this.assignment,
  });

  factory DeliveryOrder.fromJson(Map<String, dynamic> json) {
    return DeliveryOrder(
      id: json['id'],
      orderNumber: json['order_number'] ?? '',
      customerId: json['customer_id'] ?? json['customer']['id'],
      customerName: json['customer_name'] ?? json['customer']['name'] ?? '',
      customerEmail: json['customer_email'] ?? json['customer']['email'] ?? '',
      paymentId: json['payment_id'],
      totalAmount: double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
      orderType: json['order_type'] ?? typePurchase,
      status: json['status'] ?? statusPending,
      borrowRequestId: json['borrow_request_id'],
      deliveryAddress: json['delivery_address'] ?? '',
      deliveryCity: json['delivery_city'] ?? '',
      deliveryNotes: json['delivery_notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      items: json['items'] != null
          ? (json['items'] as List)
              .map((item) => DeliveryOrderItem.fromJson(item))
              .toList()
          : null,
      assignment: json['delivery_assignment'] != null
          ? DeliveryAssignment.fromJson(json['delivery_assignment'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_number': orderNumber,
      'customer_id': customerId,
      'payment_id': paymentId,
      'total_amount': totalAmount,
      'order_type': orderType,
      'status': status,
      'borrow_request_id': borrowRequestId,
      'delivery_address': deliveryAddress,
      'delivery_city': deliveryCity,
      'delivery_notes': deliveryNotes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get statusLabel {
    return statusLabels[status] ?? status;
  }

  String get typeLabel {
    return typeLabels[orderType] ?? orderType;
  }

  bool get canBeDelivered {
    return status == statusConfirmed;
  }

  bool get canBeReturned {
    return status == statusDelivered && orderType == typeBorrowing;
  }
}

class DeliveryOrderItem {
  final int? id;
  final int orderId;
  final int bookId;
  final String bookTitle;
  final String bookAuthor;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  DeliveryOrderItem({
    this.id,
    required this.orderId,
    required this.bookId,
    required this.bookTitle,
    required this.bookAuthor,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory DeliveryOrderItem.fromJson(Map<String, dynamic> json) {
    return DeliveryOrderItem(
      id: json['id'],
      orderId: json['order_id'],
      bookId: json['book_id'] ?? json['book']['id'],
      bookTitle: json['book_title'] ?? json['book']['title'] ?? '',
      bookAuthor: json['book_author'] ?? json['book']['author'] ?? '',
      quantity: json['quantity'] ?? 1,
      unitPrice: double.tryParse(json['unit_price']?.toString() ?? '0') ?? 0.0,
      totalPrice: double.tryParse(json['total_price']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'book_id': bookId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
    };
  }
}

class DeliveryAssignment {
  final int? id;
  final int orderId;
  final int deliveryPersonId;
  final String deliveryPersonName;
  final String? deliveryPersonPhone;
  final DateTime assignedAt;
  final DateTime estimatedDeliveryTime;
  final DateTime? actualDeliveryTime;
  final String? deliveryNotes;
  final List<DeliveryStatusHistory>? statusHistory;

  DeliveryAssignment({
    this.id,
    required this.orderId,
    required this.deliveryPersonId,
    required this.deliveryPersonName,
    this.deliveryPersonPhone,
    required this.assignedAt,
    required this.estimatedDeliveryTime,
    this.actualDeliveryTime,
    this.deliveryNotes,
    this.statusHistory,
  });

  factory DeliveryAssignment.fromJson(Map<String, dynamic> json) {
    return DeliveryAssignment(
      id: json['id'],
      orderId: json['order_id'],
      deliveryPersonId: json['delivery_person_id'] ?? json['delivery_person']['id'],
      deliveryPersonName: json['delivery_person_name'] ?? json['delivery_person']['name'] ?? '',
      deliveryPersonPhone: json['delivery_person_phone'] ?? json['delivery_person']['phone'],
      assignedAt: DateTime.parse(json['assigned_at']),
      estimatedDeliveryTime: DateTime.parse(json['estimated_delivery_time']),
      actualDeliveryTime: json['actual_delivery_time'] != null
          ? DateTime.parse(json['actual_delivery_time'])
          : null,
      deliveryNotes: json['delivery_notes'],
      statusHistory: json['status_history'] != null
          ? (json['status_history'] as List)
              .map((status) => DeliveryStatusHistory.fromJson(status))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'delivery_person_id': deliveryPersonId,
      'assigned_at': assignedAt.toIso8601String(),
      'estimated_delivery_time': estimatedDeliveryTime.toIso8601String(),
      'actual_delivery_time': actualDeliveryTime?.toIso8601String(),
      'delivery_notes': deliveryNotes,
    };
  }

  bool get isDelivered {
    return actualDeliveryTime != null;
  }

  bool get isOverdue {
    if (isDelivered) return false;
    return DateTime.now().isAfter(estimatedDeliveryTime);
  }

  String get currentStatus {
    if (statusHistory == null || statusHistory!.isEmpty) {
      return DeliveryStatusHistory.statusAssigned;
    }
    return statusHistory!.last.status;
  }
}

class DeliveryStatusHistory {
  static const String statusAssigned = 'assigned';
  static const String statusPickedUp = 'picked_up';
  static const String statusInTransit = 'in_transit';
  static const String statusOutForDelivery = 'out_for_delivery';
  static const String statusDelivered = 'delivered';
  static const String statusFailed = 'failed';

  static const Map<String, String> statusLabels = {
    statusAssigned: 'Assigned',
    statusPickedUp: 'Picked Up',
    statusInTransit: 'In Transit',
    statusOutForDelivery: 'Out for Delivery',
    statusDelivered: 'Delivered',
    statusFailed: 'Delivery Failed',
  };

  final int? id;
  final int deliveryAssignmentId;
  final String status;
  final String? notes;
  final DateTime timestamp;

  DeliveryStatusHistory({
    this.id,
    required this.deliveryAssignmentId,
    required this.status,
    this.notes,
    required this.timestamp,
  });

  factory DeliveryStatusHistory.fromJson(Map<String, dynamic> json) {
    return DeliveryStatusHistory(
      id: json['id'],
      deliveryAssignmentId: json['delivery_assignment_id'],
      status: json['status'] ?? statusAssigned,
      notes: json['notes'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'delivery_assignment_id': deliveryAssignmentId,
      'status': status,
      'notes': notes,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  String get statusLabel {
    return statusLabels[status] ?? status;
  }
}

class DeliveryRequest {
  static const String typePickup = 'pickup';
  static const String typeDelivery = 'delivery';
  static const String typeReturn = 'return';

  static const String statusPending = 'pending';
  static const String statusAssigned = 'assigned';
  static const String statusInProgress = 'in_progress';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';

  static const Map<String, String> typeLabels = {
    typePickup: 'Pickup Request',
    typeDelivery: 'Delivery Request',
    typeReturn: 'Return Request',
  };

  static const Map<String, String> statusLabels = {
    statusPending: 'Pending',
    statusAssigned: 'Assigned',
    statusInProgress: 'In Progress',
    statusCompleted: 'Completed',
    statusCancelled: 'Cancelled',
  };

  final int? id;
  final int customerId;
  final String customerName;
  final String customerEmail;
  final String requestType;
  final String pickupAddress;
  final String deliveryAddress;
  final String pickupCity;
  final String deliveryCity;
  final DateTime preferredPickupTime;
  final DateTime preferredDeliveryTime;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  DeliveryRequest({
    this.id,
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    required this.requestType,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.pickupCity,
    required this.deliveryCity,
    required this.preferredPickupTime,
    required this.preferredDeliveryTime,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DeliveryRequest.fromJson(Map<String, dynamic> json) {
    return DeliveryRequest(
      id: json['id'],
      customerId: json['customer_id'] ?? json['customer']['id'],
      customerName: json['customer_name'] ?? json['customer']['name'] ?? '',
      customerEmail: json['customer_email'] ?? json['customer']['email'] ?? '',
      requestType: json['request_type'] ?? typeDelivery,
      pickupAddress: json['pickup_address'] ?? '',
      deliveryAddress: json['delivery_address'] ?? '',
      pickupCity: json['pickup_city'] ?? '',
      deliveryCity: json['delivery_city'] ?? '',
      preferredPickupTime: DateTime.parse(json['preferred_pickup_time']),
      preferredDeliveryTime: DateTime.parse(json['preferred_delivery_time']),
      status: json['status'] ?? statusPending,
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'request_type': requestType,
      'pickup_address': pickupAddress,
      'delivery_address': deliveryAddress,
      'pickup_city': pickupCity,
      'delivery_city': deliveryCity,
      'preferred_pickup_time': preferredPickupTime.toIso8601String(),
      'preferred_delivery_time': preferredDeliveryTime.toIso8601String(),
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get typeLabel {
    return typeLabels[requestType] ?? requestType;
  }

  String get statusLabel {
    return statusLabels[status] ?? status;
  }

  bool get canBeAssigned {
    return status == statusPending;
  }

  bool get canBeCancelled {
    return status == statusPending || status == statusAssigned;
  }
}

class DeliveryAgent {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final bool isAvailable;
  final String? currentLocation;
  final int activeDeliveries;
  final double rating;
  final DateTime lastActive;

  DeliveryAgent({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.isAvailable,
    this.currentLocation,
    required this.activeDeliveries,
    required this.rating,
    required this.lastActive,
  });

  factory DeliveryAgent.fromJson(Map<String, dynamic> json) {
    return DeliveryAgent(
      id: json['id'],
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      isAvailable: json['is_available'] ?? false,
      currentLocation: json['current_location'],
      activeDeliveries: json['active_deliveries'] ?? 0,
      rating: double.tryParse(json['rating']?.toString() ?? '0') ?? 0.0,
      lastActive: DateTime.parse(json['last_active']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'is_available': isAvailable,
      'current_location': currentLocation,
      'active_deliveries': activeDeliveries,
      'rating': rating,
      'last_active': lastActive.toIso8601String(),
    };
  }

  String get availabilityStatus {
    if (!isAvailable) return 'Unavailable';
    if (activeDeliveries == 0) return 'Available';
    return 'Busy ($activeDeliveries active)';
  }
}
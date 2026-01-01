import 'package:flutter/foundation.dart';
import 'user.dart';
import 'book.dart';
import 'delivery_assignment.dart';

// Helper function to safely parse double values from JSON
double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value) ?? 0.0;
  }
  return 0.0;
}

class LegacyOrder {
  final int id;
  final int userId;
  final User? user;
  final String status;
  final double totalAmount;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? deliveryAddress;
  final String? billingAddress;
  final String? paymentMethod;
  final String? paymentStatus;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final String? trackingNumber;
  final List<LegacyOrderItem> items;
  final String? discountCode;
  final double? discountAmount;
  final double? finalAmount;
  final DeliveryAssignment? deliveryAssignment;
  final String? orderNumber;
  final String? deliveryCity;
  final String? deliveryNotes;

  LegacyOrder({
    required this.id,
    required this.userId,
    this.user,
    required this.status,
    required this.totalAmount,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.deliveryAddress,
    this.billingAddress,
    this.paymentMethod,
    this.paymentStatus,
    this.shippedAt,
    this.deliveredAt,
    this.trackingNumber,
    this.items = const [],
    this.discountCode,
    this.discountAmount,
    this.finalAmount,
    this.deliveryAssignment,
    this.orderNumber,
    this.deliveryCity,
    this.deliveryNotes,
  });

  factory LegacyOrder.fromJson(Map<String, dynamic> json) {
    try {
      // Handle different response formats:
      // 1. OrderListSerializer format: customer_name, customer_email, payment_type, payment_status
      // 2. OrderDetailSerializer format: customer object, payment object

      User? user;
      try {
        if (json['customer'] != null) {
          // OrderDetailSerializer format - full customer object
          if (json['customer'] is Map<String, dynamic>) {
            user = User.fromJson(json['customer']);
          } else if (json['customer'] is int) {
            // If customer is just an ID, create minimal user
            user = User(
              id: json['customer'],
              firstName: json['customer_name']?.split(' ').first ?? '',
              lastName:
                  json['customer_name']?.split(' ').skip(1).join(' ') ?? '',
              email: json['customer_email'] ?? '',
              phone: null,
              address: null,
              profileImage: null,
              role: 'customer',
              isActive: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              preferredLanguage: null,
              lastLoginAt: null,
            );
          }
        } else if (json['customer_name'] != null ||
            json['customer_email'] != null) {
          // OrderListSerializer format - create a minimal user object
          user = User(
            id: json['customer_id'] ?? 0,
            firstName: json['customer_name']?.split(' ').first ?? '',
            lastName: json['customer_name']?.split(' ').skip(1).join(' ') ?? '',
            email: json['customer_email'] ?? '',
            phone: null,
            address: null,
            profileImage: null,
            role: 'customer',
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            preferredLanguage: null,
            lastLoginAt: null,
          );
        }
      } catch (e) {
        debugPrint('Error parsing customer: $e');
        debugPrint('Customer data: ${json['customer']}');
      }

      return LegacyOrder(
        id: json['id'] ?? 0,
        userId: json['userId'] is int
            ? json['userId']
            : json['user_id'] is int
            ? json['user_id']
            : json['customer_id'] is int
            ? json['customer_id']
            : json['customer'] is Map<String, dynamic>
            ? (json['customer']['id'] ?? 0)
            : json['customer'] is int
            ? json['customer']
            : 0,
        user: user,
        status: json['status'] ?? 'pending',
        totalAmount: _parseDouble(
          json['totalAmount'] ?? json['total_amount'] ?? 0.0,
        ),
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
        deliveryAddress: json['deliveryAddress'] ?? json['delivery_address'],
        billingAddress: json['billingAddress'] ?? json['billing_address'],
        paymentMethod:
            json['paymentMethod'] ??
            json['payment_method'] ??
            json['payment_type'] ?? // OrderListSerializer format
            (json['payment'] != null && json['payment'] is Map<String, dynamic>
                ? json['payment']['payment_type_display']
                : null) ??
            'Not specified',
        paymentStatus:
            json['paymentStatus'] ??
            json['payment_status'] ??
            (json['payment'] != null && json['payment'] is Map<String, dynamic>
                ? json['payment']['status_display']
                : null) ??
            'Pending',
        shippedAt: json['shippedAt'] != null
            ? DateTime.parse(json['shippedAt'])
            : json['shipped_at'] != null
            ? DateTime.parse(json['shipped_at'])
            : null,
        deliveredAt: json['deliveredAt'] != null
            ? DateTime.parse(json['deliveredAt'])
            : json['delivered_at'] != null
            ? DateTime.parse(json['delivered_at'])
            : null,
        trackingNumber: json['trackingNumber'] ?? json['tracking_number'],
        items: json['items'] != null
            ? (json['items'] as List)
                  .map((item) => LegacyOrderItem.fromJson(item))
                  .toList()
            : [],
        discountCode: json['discountCode'] ?? json['discount_code'],
        discountAmount: json['discountAmount'] != null
            ? _parseDouble(json['discountAmount'])
            : json['discount_amount'] != null
            ? _parseDouble(json['discount_amount'])
            : null,
        finalAmount: json['finalAmount'] != null
            ? _parseDouble(json['finalAmount'])
            : json['final_amount'] != null
            ? _parseDouble(json['final_amount'])
            : null,
        deliveryAssignment:
            json['delivery_assignment'] != null &&
                json['delivery_assignment'] is Map<String, dynamic>
            ? DeliveryAssignment.fromJson(json['delivery_assignment'])
            : null,
        orderNumber: json['orderNumber'] ?? json['order_number'],
        deliveryCity: json['deliveryCity'] ?? json['delivery_city'],
        deliveryNotes: json['deliveryNotes'] ?? json['delivery_notes'],
      );
    } catch (e, stackTrace) {
      debugPrint('❌ CRITICAL ERROR parsing Order: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('Problematic JSON: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'user': user?.toJson(),
      'status': status,
      'totalAmount': totalAmount,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'deliveryAddress': deliveryAddress,
      'billingAddress': billingAddress,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'shippedAt': shippedAt?.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
      'trackingNumber': trackingNumber,
      'items': items.map((item) => item.toJson()).toList(),
      'discountCode': discountCode,
      'discountAmount': discountAmount,
      'finalAmount': finalAmount,
      'deliveryAssignment': deliveryAssignment?.toJson(),
      'orderNumber': orderNumber,
      'deliveryCity': deliveryCity,
      'deliveryNotes': deliveryNotes,
    };
  }

  LegacyOrder copyWith({
    int? id,
    int? userId,
    User? user,
    String? status,
    double? totalAmount,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? deliveryAddress,
    String? billingAddress,
    String? paymentMethod,
    String? paymentStatus,
    DateTime? shippedAt,
    DateTime? deliveredAt,
    String? trackingNumber,
    List<LegacyOrderItem>? items,
    String? discountCode,
    double? discountAmount,
    double? finalAmount,
    DeliveryAssignment? deliveryAssignment,
    String? orderNumber,
    String? deliveryCity,
    String? deliveryNotes,
  }) {
    return LegacyOrder(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      user: user ?? this.user,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      billingAddress: billingAddress ?? this.billingAddress,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      shippedAt: shippedAt ?? this.shippedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      items: items ?? this.items,
      discountCode: discountCode ?? this.discountCode,
      discountAmount: discountAmount ?? this.discountAmount,
      finalAmount: finalAmount ?? this.finalAmount,
      deliveryAssignment: deliveryAssignment ?? this.deliveryAssignment,
      orderNumber: orderNumber ?? this.orderNumber,
      deliveryCity: deliveryCity ?? this.deliveryCity,
      deliveryNotes: deliveryNotes ?? this.deliveryNotes,
    );
  }

  // Helper getters
  String get customerName => user?.fullName ?? 'Unknown Customer';
  String get customerEmail => user?.email ?? '';
  String get customerPhone => user?.phone ?? '';

  bool get isPending => status.toLowerCase() == 'pending';
  bool get isConfirmed => status.toLowerCase() == 'confirmed';
  bool get isShipped => status.toLowerCase() == 'shipped';
  bool get isDelivered => status.toLowerCase() == 'delivered';
  bool get isCancelled => status.toLowerCase() == 'cancelled';
  bool get isPendingAssignment => status.toLowerCase() == 'pending_assignment';
  bool get isAssignedToDelivery =>
      status.toLowerCase() == 'assigned_to_delivery';
  bool get isInDelivery => status.toLowerCase() == 'in_delivery';

  int get itemCount => items.length;
  double get subtotal => items.fold(0.0, (sum, item) => sum + item.totalPrice);

  // Delivery assignment helpers
  bool get hasDeliveryAssignment => deliveryAssignment != null;
  String? get deliveryAgentId =>
      deliveryAssignment?.deliveryManagerId.toString();
  String? get deliveryAgentName => deliveryAssignment?.deliveryManager?.name;

  String get statusDisplay {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'pending_assignment':
        return 'Pending Assignment';
      case 'assigned_to_delivery':
        return 'Assigned to Delivery';
      case 'in_delivery':
        return 'In Delivery';
      case 'confirmed':
        return 'Confirmed';
      case 'shipped':
        return 'Shipped';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  // Getters for convenience
  double get total => totalAmount;
  double get finalTotal => finalAmount ?? totalAmount;
}

class LegacyOrderItem {
  final int id;
  final int bookId;
  final String bookTitle;
  final String? bookAuthor;
  final String? bookImage;
  final double price;
  final int quantity;
  final double totalPrice;
  final Book? book;
  final bool isBorrowed;

  LegacyOrderItem({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    this.bookAuthor,
    this.bookImage,
    required this.price,
    required this.quantity,
    required this.totalPrice,
    this.book,
    this.isBorrowed = false,
  });

  factory LegacyOrderItem.fromJson(Map<String, dynamic> json) {
    // Parse book object if it exists
    Book? bookObj;
    if (json['book'] != null && json['book'] is Map<String, dynamic>) {
      bookObj = Book.fromJson(json['book']);
    }

    // Extract book ID from various sources
    int bookId = json['bookId'] ?? json['book_id'] ?? 0;
    if (bookId == 0 && bookObj != null) {
      // Book.id is a String, so we need to parse it to int
      bookId = int.tryParse(bookObj.id) ?? 0;
    }

    // Extract book title from various sources
    String bookTitle = json['bookTitle'] ?? json['book_title'] ?? '';
    if (bookTitle.isEmpty && bookObj != null) {
      bookTitle = bookObj.title;
    }

    // Extract book author from various sources
    String? bookAuthor = json['bookAuthor'] ?? json['book_author'];
    if (bookAuthor == null && bookObj != null && bookObj.author != null) {
      bookAuthor = bookObj.author!.name;
    }

    return LegacyOrderItem(
      id: json['id'] ?? 0,
      bookId: bookId,
      bookTitle: bookTitle,
      bookAuthor: bookAuthor,
      bookImage: json['bookImage'] ?? json['book_image'],
      price: _parseDouble(json['price'] ?? json['unit_price'] ?? 0.0),
      quantity: json['quantity'] ?? 0,
      totalPrice: _parseDouble(
        json['totalPrice'] ?? json['total_price'] ?? 0.0,
      ),
      book: bookObj,
      isBorrowed: json['isBorrowed'] ?? json['is_borrowed'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookId': bookId,
      'bookTitle': bookTitle,
      'bookAuthor': bookAuthor,
      'bookImage': bookImage,
      'price': price,
      'quantity': quantity,
      'totalPrice': totalPrice,
      'book': book?.toJson(),
      'isBorrowed': isBorrowed,
    };
  }
}

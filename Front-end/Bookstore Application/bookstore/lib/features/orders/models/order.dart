import 'package:flutter/foundation.dart';
import '../../books/models/book.dart';
import 'order_note.dart';

class Order {
  final String id;
  final String orderNumber;
  final String userId;
  final String customerName;
  final String customerEmail;
  final String status;
  final String orderType; // Added order_type field
  final String? paymentMethod;
  final double totalAmount;
  final double shippingCost;
  final double taxAmount;
  final String? couponCode;
  final double? discountAmount;
  final String? notes; // Legacy field for backward compatibility
  final List<OrderNote>? orderNotes; // New field for notes with author info
  final String? cancellationReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<OrderItem> items;
  final int? totalQuantity;
  final OrderAddress? shippingAddress;
  final OrderAddress? billingAddress;
  final PaymentInfo? paymentInfo;
  final DeliveryAssignment? deliveryAssignment;
  final String? bookTitle; // For borrowing orders
  final String? bookAuthor; // For borrowing orders (author name/pseudonym)

  Order({
    required this.id,
    required this.orderNumber,
    required this.userId,
    required this.customerName,
    required this.customerEmail,
    required this.status,
    required this.orderType, // Added orderType parameter
    this.paymentMethod,
    required this.totalAmount,
    required this.shippingCost,
    required this.taxAmount,
    this.couponCode,
    this.discountAmount,
    this.notes,
    this.orderNotes,
    this.cancellationReason,
    this.canEditNotes,
    this.canDeleteNotes,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
    this.totalQuantity,
    this.shippingAddress,
    this.billingAddress,
    this.paymentInfo,
    this.deliveryAssignment,
    this.bookTitle,
    this.bookAuthor,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    try {
      // Check if this is a borrow order - skip debug prints for borrow orders
      final orderType = json['order_type'] ?? 'purchase';
      final isBorrowOrder =
          orderType.toString().toLowerCase() == 'borrowing' ||
          (json['order_number']?.toString().toUpperCase().startsWith('BR') ??
              false);

      // Debug prints only for purchase orders
      if (!isBorrowOrder) {
        debugPrint('DEBUG: Received order JSON: $json');
        debugPrint(
          'DEBUG: Discount code: ${json['discount_code'] ?? json['coupon_code']}, Discount amount: ${json['discount_amount']}',
        );
      }

      // Handle both backend API structure and frontend structure
      final customerData = json['customer'] as Map<String, dynamic>?;
      final paymentData = json['payment'] as Map<String, dynamic>?;
      final profileData = customerData?['profile'] as Map<String, dynamic>?;

      // Debug prints only for purchase orders
      if (!isBorrowOrder) {
        debugPrint('DEBUG: Customer data: $customerData');
        if (customerData != null) {
          debugPrint('DEBUG: Customer full_name: ${customerData['full_name']}');
          debugPrint(
            'DEBUG: Customer get_full_name: ${customerData['get_full_name']}',
          );
        }

        if (profileData != null) {
          debugPrint('DEBUG: Profile data: $profileData');
          debugPrint(
            'DEBUG: Phone number from profile: ${profileData['phone_number']}',
          );
        }
      }

      // Extract customer phone from profile data or directly from customer object
      String? customerPhone;
      if (profileData != null && profileData['phone_number'] != null) {
        customerPhone = profileData['phone_number']?.toString();
      } else if (customerData != null && customerData['phone_number'] != null) {
        customerPhone = customerData['phone_number']?.toString();
      } else if (json['customer_phone'] != null) {
        customerPhone = json['customer_phone']?.toString();
      }

      final order = Order(
        id: json['id']?.toString() ?? '',
        orderNumber: json['order_number'] ?? '',
        userId:
            customerData?['id']?.toString() ??
            json['user_id']?.toString() ??
            '',
        customerName:
            customerData?['full_name'] ??
            customerData?['get_full_name'] ??
            json['customer_name'] ??
            'Unknown',
        customerEmail: customerData?['email'] ?? json['customer_email'] ?? '',
        status: json['status'] ?? 'pending',
        orderType: json['order_type'] ?? 'purchase', // Default to purchase
        paymentMethod: json['payment_method'],
        totalAmount: _parseDouble(json['total_amount']),
        shippingCost: _parseDouble(
          json['delivery_cost'] ?? json['shipping_cost'],
        ),
        taxAmount: json['tax_amount'] != null
            ? _parseDouble(json['tax_amount'])
            : 0.0, // Will be calculated after items are parsed if needed
        couponCode: json['discount_code'] ?? json['coupon_code'],
        discountAmount: json['discount_amount'] != null
            ? _parseDouble(json['discount_amount'])
            : null,
        notes:
            json['delivery_notes'] ??
            (json['notes'] is String ? json['notes'] : null), // Legacy field
        orderNotes: () {
          // Debug: Check what we're getting for notes
          debugPrint(
            'DEBUG: Parsing notes from JSON - json[\'notes\']: ${json['notes']}',
          );
          debugPrint(
            'DEBUG: json[\'notes\'] type: ${json['notes']?.runtimeType}',
          );

          if (json['notes'] != null && json['notes'] is List) {
            final notesList = json['notes'] as List;
            debugPrint('DEBUG: Notes is a List with ${notesList.length} items');

            final parsedNotes = notesList
                .map((note) {
                  try {
                    if (note is Map<String, dynamic>) {
                      debugPrint('DEBUG: Parsing note: $note');
                      final parsed = OrderNote.fromJson(note);
                      debugPrint(
                        'DEBUG: Parsed note - id: ${parsed.id}, content: ${parsed.content}, author: ${parsed.authorName}',
                      );
                      return parsed;
                    }
                    debugPrint('DEBUG: Note is not a Map: ${note.runtimeType}');
                    return null;
                  } catch (e) {
                    debugPrint('Error parsing OrderNote: $e, note: $note');
                    return null;
                  }
                })
                .whereType<OrderNote>()
                .toList();

            debugPrint(
              'DEBUG: Successfully parsed ${parsedNotes.length} notes',
            );
            return parsedNotes.isNotEmpty ? parsedNotes : null;
          } else {
            debugPrint('DEBUG: Notes is not a List or is null');
          }
          return null;
        }(),
        cancellationReason: json['cancellation_reason'],
        createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
        updatedAt: _parseDateTime(json['updated_at']) ?? DateTime.now(),
        items: () {
          final itemsData = json['items'] as List<dynamic>?;
          // Check if this is a borrow order - skip debug prints for borrow orders
          final orderType = json['order_type'] ?? 'purchase';
          final isBorrowOrder =
              orderType.toString().toLowerCase() == 'borrowing' ||
              (json['order_number']?.toString().toUpperCase().startsWith(
                    'BR',
                  ) ??
                  false);

          // Debug prints only for purchase orders
          if (!isBorrowOrder) {
            debugPrint('DEBUG: Order items data: $itemsData');
          }

          if (itemsData == null) {
            if (!isBorrowOrder) {
              debugPrint('DEBUG: No items data found in Order JSON');
            }
            return <OrderItem>[];
          }

          if (!isBorrowOrder) {
            debugPrint('DEBUG: Found ${itemsData.length} items in Order JSON');
          }
          return itemsData.map((item) => OrderItem.fromJson(item)).toList();
        }(),
        totalQuantity: json['total_quantity'],
        shippingAddress:
            json['delivery_address'] != null &&
                json['delivery_address'] is String
            ? OrderAddress.fromDeliveryAddress(
                json['delivery_address'],
                json['delivery_city'] ?? '',
              )
            : json['delivery_address'] != null &&
                  json['delivery_address'] is Map<String, dynamic>
            ? OrderAddress.fromJson(json['delivery_address'])
            : json['shipping_address'] != null
            ? OrderAddress.fromJson(json['shipping_address'])
            : null,
        billingAddress: json['billing_address'] != null
            ? OrderAddress.fromJson(json['billing_address'])
            : null,
        paymentInfo: paymentData != null
            ? PaymentInfo.fromJson(paymentData)
            : json['payment_info'] != null
            ? PaymentInfo.fromJson(json['payment_info'])
            : json['payment_method'] != null
            ? PaymentInfo(
                id: json['id']?.toString(),
                paymentMethod: json['payment_method'],
                status: json['status'] ?? 'pending',
                processedAt: json['created_at'] != null
                    ? DateTime.parse(json['created_at'])
                    : null,
              )
            : null,
        deliveryAssignment:
            json['delivery_assignment'] != null &&
                json['delivery_assignment'] is Map<String, dynamic>
            ? DeliveryAssignment.fromJson(json['delivery_assignment'])
            : null,
        canEditNotes: json['can_edit_notes'] ?? true,
        canDeleteNotes: json['can_delete_notes'] ?? true,
        bookTitle: json['book_title'] as String?,
        bookAuthor: json['book_author'] as String?,
      );

      // Store the phone number separately since it's not in the constructor
      order._customerPhone = customerPhone;

      // Calculate tax if not provided: 8% of subtotal from items
      if (json['tax_amount'] == null && order.items.isNotEmpty) {
        final calculatedSubtotal = order.subtotal;
        final calculatedTax = calculatedSubtotal * 0.08; // 8% tax rate
        // Create a new order with calculated tax
        return order.copyWith(taxAmount: calculatedTax);
      }

      return order;
    } catch (e) {
      throw Exception('Failed to parse Order from JSON: $e. JSON data: $json');
    }
  }

  // Helper method to safely parse double values from JSON
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
  }

  // Helper method to safely parse DateTime values from JSON
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        debugPrint('DEBUG: Error parsing date: $value, error: $e');
        return null;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_number': orderNumber,
      'user_id': userId,
      'customer_name': customerName,
      'customer_email': customerEmail,
      'status': status,
      'order_type': orderType,
      'payment_method': paymentMethod,
      'total_amount': totalAmount,
      'tax_amount': taxAmount,
      'discount_amount': discountAmount,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
      'total_quantity': totalQuantity,
      'billing_address': billingAddress?.toJson(),
      'payment_info': paymentInfo?.toJson(),
      'delivery_assignment': deliveryAssignment?.toJson(),
    };
  }

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get finalTotal =>
      subtotal + shippingCost + taxAmount - (discountAmount ?? 0.0);

  // Methods from the old Order class for compatibility
  bool get isPending => status.toLowerCase() == 'pending';
  bool get isConfirmed => status.toLowerCase() == 'confirmed';
  bool get isShipped => status.toLowerCase() == 'shipped';
  bool get isDelivered => status.toLowerCase() == 'delivered';
  bool get isCancelled => status.toLowerCase() == 'cancelled';
  bool get isPendingAssignment => status.toLowerCase() == 'pending_assignment';
  bool get isAssignedToDelivery =>
      status.toLowerCase() == 'assigned_to_delivery';
  bool get isInDelivery => status.toLowerCase() == 'in_delivery';
  bool get isRejectedByAdmin => status.toLowerCase() == 'rejected_by_admin';
  bool get isWaitingForDeliveryManager =>
      status.toLowerCase() == 'waiting_for_delivery_manager';
  bool get isRejectedByDeliveryManager =>
      status.toLowerCase() == 'rejected_by_delivery_manager';
  bool get isCompleted => status.toLowerCase() == 'completed';

  // Order type checking methods
  bool get isPurchaseOrder => orderType.toLowerCase() == 'purchase';
  bool get isBorrowingOrder => orderType.toLowerCase() == 'borrowing';
  bool get isReturnOrder => orderType.toLowerCase() == 'return_collection';

  String get orderTypeDisplay {
    switch (orderType.toLowerCase()) {
      case 'purchase':
        return 'Purchase Order';
      case 'borrowing':
        return 'Borrowing Request';
      case 'return_collection':
        return 'Return Request';
      default:
        return orderType;
    }
  }

  // Legacy property accessors for compatibility
  String get customerPhone {
    if (_customerPhone != null) {
      return _customerPhone!;
    }
    // Try to extract from profile data
    return '';
  }

  String? _customerPhone;
  String? get paymentStatus => paymentInfo?.status;
  String? get deliveryCity => shippingAddress?.city;
  String? get deliveryNotes => notes;

  // Get notes list (prefer new orderNotes, fallback to legacy notes)
  List<OrderNote> get notesList {
    // First, check if we have new orderNotes
    if (orderNotes != null && orderNotes!.isNotEmpty) {
      return orderNotes!;
    }
    // If we have legacy notes, create a single OrderNote from it
    if (notes != null && notes!.isNotEmpty) {
      return [
        OrderNote(
          id: 0,
          content: notes!,
          createdAt: updatedAt,
          updatedAt: updatedAt,
        ),
      ];
    }
    // Return empty list if no notes
    return [];
  }

  bool get hasNotes {
    // Check if we have new orderNotes
    if (orderNotes != null && orderNotes!.isNotEmpty) {
      return true;
    }
    // Check if we have legacy notes
    if (notes != null && notes!.isNotEmpty) {
      return true;
    }
    return false;
  }

  // Permission flags from backend
  bool? canEditNotes;
  bool? canDeleteNotes;

  String? get deliveryAddress => shippingAddress?.address1;
  DateTime? get deliveredAt => null;
  bool get hasDeliveryAssignment => deliveryAssignment != null;
  String? get deliveryAgentId => deliveryAssignment?.deliveryManagerId;
  String? get discountCode => couponCode;

  String get formattedDiscountAmount {
    if (discountAmount == null || discountAmount == 0) {
      return 'No discount';
    }
    return '\$${discountAmount!.toStringAsFixed(2)}';
  }

  bool get hasDiscount => discountAmount != null && discountAmount! > 0;

  String get deliveryAgentName => deliveryAssignment?.deliveryManagerName ?? '';
  String? get shippingAddressText => shippingAddress != null
      ? "${shippingAddress?.address1}, ${shippingAddress?.city}"
      : null;

  String get statusDisplay {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending Review';
      case 'rejected_by_admin':
        return 'Rejected by Admin';
      case 'waiting_for_delivery_manager':
        return 'Waiting for Delivery Manager';
      case 'rejected_by_delivery_manager':
        return 'Rejected by Delivery Manager';
      case 'in_delivery':
        return 'In Delivery';
      case 'completed':
        return 'Completed';
      case 'assigned_to_delivery':
        return 'Assigned to Delivery';
      case 'confirmed':
        return 'Confirmed';
      case 'shipped':
        return 'Shipped';
      case 'delivered':
        return 'Delivered';
      case 'returned':
        return 'Returned';
      default:
        return status;
    }
  }

  // Add copyWith method for compatibility
  Order copyWith({
    // Override specific properties that need type checking
    dynamic shippingAddr,
    String? id,
    String? orderNumber,
    String? userId,
    String? customerName,
    String? customerEmail,
    String? status,
    String? orderType,
    String? paymentMethod,
    double? totalAmount,
    double? shippingCost,
    double? taxAmount,
    String? couponCode,
    double? discountAmount,
    String? notes,
    List<OrderNote>? orderNotes,
    String? cancellationReason,
    bool? canEditNotes,
    bool? canDeleteNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<OrderItem>? items,
    int? totalQuantity,
    OrderAddress? shippingAddress,
    OrderAddress? billingAddress,
    PaymentInfo? paymentInfo,
    DeliveryAssignment? deliveryAssignment,
    String? bookTitle,
    String? bookAuthor,
  }) {
    return Order(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      userId: userId ?? this.userId,
      customerName: customerName ?? this.customerName,
      customerEmail: customerEmail ?? this.customerEmail,
      status: status ?? this.status,
      orderType: orderType ?? this.orderType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      totalAmount: totalAmount ?? this.totalAmount,
      shippingCost: shippingCost ?? this.shippingCost,
      taxAmount: taxAmount ?? this.taxAmount,
      couponCode: couponCode ?? this.couponCode,
      discountAmount: discountAmount ?? this.discountAmount,
      notes: notes ?? this.notes,
      orderNotes: orderNotes ?? this.orderNotes,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      canEditNotes: canEditNotes ?? this.canEditNotes,
      canDeleteNotes: canDeleteNotes ?? this.canDeleteNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      shippingAddress: shippingAddr is OrderAddress
          ? shippingAddr
          : shippingAddress ?? this.shippingAddress,
      billingAddress: billingAddress ?? this.billingAddress,
      paymentInfo: paymentInfo ?? this.paymentInfo,
      deliveryAssignment: deliveryAssignment ?? this.deliveryAssignment,
      bookTitle: bookTitle ?? this.bookTitle,
      bookAuthor: bookAuthor ?? this.bookAuthor,
    );
  }
}

class OrderItem {
  final String id;
  final String orderId;
  final Book book;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  // Legacy properties for compatibility
  bool get isBorrowed => false;
  String get bookTitle => book.title;
  String? get bookAuthor => book.author?.name;
  String? get bookImage => book.primaryImageUrl;
  double get price => unitPrice;

  OrderItem({
    required this.id,
    required this.orderId,
    required this.book,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    try {
      debugPrint('DEBUG: Parsing OrderItem from JSON: $json');

      // Parse book information
      final bookData = json['book'] as Map<String, dynamic>?;
      if (bookData == null) {
        debugPrint('DEBUG: No book data found in OrderItem JSON');
        throw Exception('Book data is required for OrderItem');
      }

      final book = Book.fromJson(bookData);
      debugPrint('DEBUG: Parsed book: ${book.title}');

      final orderItem = OrderItem(
        id: json['id']?.toString() ?? '',
        orderId: json['order_id']?.toString() ?? '',
        book: book,
        quantity: json['quantity'] ?? 1,
        unitPrice: Order._parseDouble(json['unit_price']),
        totalPrice: Order._parseDouble(json['total_price']),
      );

      debugPrint(
        'DEBUG: Created OrderItem: ${orderItem.book.title} x ${orderItem.quantity} = \$${orderItem.totalPrice}',
      );
      return orderItem;
    } catch (e) {
      debugPrint('DEBUG: Error parsing OrderItem: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'book': book.toJson(),
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
    };
  }
}

class OrderAddress {
  final String? id;
  final String? firstName;
  final String? lastName;
  final String? company;
  final String? address1;
  final String? address2;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;
  final String? phone;

  OrderAddress({
    this.id,
    this.firstName,
    this.lastName,
    this.company,
    this.address1,
    this.address2,
    this.city,
    this.state,
    this.postalCode,
    this.country,
    this.phone,
  });

  factory OrderAddress.fromJson(Map<String, dynamic> json) {
    return OrderAddress(
      id: json['id']?.toString(),
      firstName: json['first_name'],
      lastName: json['last_name'],
      company: json['company'],
      address1: json['address1'],
      address2: json['address2'],
      city: json['city'],
      state: json['state'],
      postalCode: json['postal_code'],
      country: json['country'],
      phone: json['phone'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'company': company,
      'address1': address1,
      'address2': address2,
      'city': city,
      'state': state,
      'postal_code': postalCode,
      'country': country,
      'phone': phone,
    };
  }

  String get fullName => '${firstName ?? ''} ${lastName ?? ''}'.trim();
  String get fullAddress =>
      '${address1 ?? ''}, ${city ?? ''}, ${state ?? ''} ${postalCode ?? ''}'
          .trim();

  factory OrderAddress.fromDeliveryAddress(String address, String city) {
    return OrderAddress(address1: address, city: city);
  }
}

class PaymentInfo {
  final String? id;
  final String paymentMethod;
  final String? transactionId;
  final String? cardLast4;
  final String? cardBrand;
  final String status;
  final DateTime? processedAt;

  PaymentInfo({
    this.id,
    required this.paymentMethod,
    this.transactionId,
    this.cardLast4,
    this.cardBrand,
    required this.status,
    this.processedAt,
  });

  factory PaymentInfo.fromJson(Map<String, dynamic> json) {
    return PaymentInfo(
      id: json['id']?.toString(),
      paymentMethod:
          json['payment_type'] ?? json['payment_method'] ?? 'unknown',
      transactionId: json['transaction_id'],
      cardLast4: json['card_last4'],
      cardBrand: json['card_brand'],
      status: json['status'] ?? 'pending',
      processedAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : json['processed_at'] != null
          ? DateTime.parse(json['processed_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'payment_method': paymentMethod,
      'transaction_id': transactionId,
      'card_last4': cardLast4,
      'card_brand': cardBrand,
      'status': status,
      'processed_at': processedAt?.toIso8601String(),
    };
  }
}

// Helper class for backward compatibility
class DeliveryManager {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String status;

  DeliveryManager({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    this.status = 'available',
  });
}

class DeliveryAssignment {
  final String id;
  final String orderId;
  final String deliveryManagerId;
  final String deliveryManagerName;
  final String? deliveryManagerPhone;
  final String? deliveryManagerEmail;
  final String status;
  final DateTime assignedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? assignedByName;

  // Legacy properties for compatibility
  DateTime get scheduledDate => assignedAt;

  // For backward compatibility with the old model
  DeliveryManager? get deliveryManager => DeliveryManager(
    id: deliveryManagerId,
    name: deliveryManagerName,
    phone: deliveryManagerPhone ?? '',
    email: deliveryManagerEmail ?? '',
  );

  // Alias for backward compatibility
  DeliveryManager? get deliveryPerson => deliveryManager;

  DeliveryAssignment({
    required this.id,
    required this.orderId,
    required this.deliveryManagerId,
    required this.deliveryManagerName,
    this.deliveryManagerPhone,
    this.deliveryManagerEmail,
    required this.status,
    required this.assignedAt,
    this.startedAt,
    this.completedAt,
    this.assignedByName,
  });

  factory DeliveryAssignment.fromJson(Map<String, dynamic> json) {
    // Handle delivery_manager as either an ID (int/string) or an object with id field
    String deliveryManagerId = '';
    String? deliveryManagerPhone;
    String? deliveryManagerEmail;
    String deliveryManagerName = 'Unknown';

    if (json['delivery_manager'] != null) {
      if (json['delivery_manager'] is Map<String, dynamic>) {
        // It's an object, extract all fields
        final managerData = json['delivery_manager'] as Map<String, dynamic>;
        deliveryManagerId = managerData['id']?.toString() ?? '';
        deliveryManagerName =
            managerData['full_name'] ??
            managerData['get_full_name'] ??
            managerData['name'] ??
            'Unknown';
        deliveryManagerPhone = managerData['phone']?.toString();
        deliveryManagerEmail = managerData['email']?.toString();
      } else {
        // It's already an ID
        deliveryManagerId = json['delivery_manager'].toString();
      }
    }

    // Fallback to delivery_manager_name if name wasn't extracted from object
    if (deliveryManagerName == 'Unknown' &&
        json['delivery_manager_name'] != null) {
      deliveryManagerName = json['delivery_manager_name'];
    }

    // Also check for phone and email at the top level
    deliveryManagerPhone ??= json['delivery_manager_phone']?.toString();
    deliveryManagerEmail ??= json['delivery_manager_email']?.toString();

    return DeliveryAssignment(
      id: json['id']?.toString() ?? '',
      orderId: json['order']?.toString() ?? '',
      deliveryManagerId: deliveryManagerId,
      deliveryManagerName: deliveryManagerName,
      deliveryManagerPhone: deliveryManagerPhone,
      deliveryManagerEmail: deliveryManagerEmail,
      status: json['status'] ?? 'assigned',
      assignedAt: json['assigned_at'] != null
          ? DateTime.parse(json['assigned_at'])
          : DateTime.now(),
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'])
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      assignedByName: json['assigned_by_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order': orderId,
      'delivery_manager': deliveryManagerId,
      'delivery_manager_name': deliveryManagerName,
      'status': status,
      'assigned_at': assignedAt.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'assigned_by_name': assignedByName,
    };
  }
}

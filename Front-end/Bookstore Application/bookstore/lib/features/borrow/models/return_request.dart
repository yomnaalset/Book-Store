import 'package:flutter/foundation.dart';
import 'borrow_request.dart';
import 'user.dart';
import 'delivery_request.dart';

class ReturnRequest {
  final String id;
  final BorrowRequest borrowRequest;
  final String status;
  final String? deliveryManagerId;
  final String? deliveryManagerName;
  final String? deliveryManagerEmail;
  final String? deliveryManagerPhone;
  final BorrowDeliveryRequest?
  deliveryRequest; // Delivery status for return requests (legacy - do not use for status)
  final String?
  deliveryRequestStatus; // CRITICAL: Primary status source from API (delivery_request_status)
  final double fineAmount;
  final String? fineInvoiceId;
  final int? fineId; // Return fine ID
  final int? fineDaysLate; // Days late for fine
  final String? finePaymentMethod; // Payment method for fine
  final String? finePaymentStatus; // Payment status for fine
  final String? returnNotes;
  // Penalty and payment information
  final double? penaltyAmount;
  final int? overdueDays;
  final bool? hasPenalty;
  final String? paymentMethod;
  final String? paymentStatus;
  final DateTime? dueDate;
  final bool? isFinalized;
  final DateTime requestedAt;
  final DateTime? acceptedAt;
  final DateTime? pickedUpAt;
  final DateTime? completedAt;
  final DateTime updatedAt;

  ReturnRequest({
    required this.id,
    required this.borrowRequest,
    required this.status,
    this.deliveryManagerId,
    this.deliveryManagerName,
    this.deliveryManagerEmail,
    this.deliveryManagerPhone,
    this.deliveryRequest,
    this.deliveryRequestStatus, // CRITICAL: Primary status source
    required this.fineAmount,
    this.fineInvoiceId,
    this.fineId,
    this.fineDaysLate,
    this.finePaymentMethod,
    this.finePaymentStatus,
    this.returnNotes,
    required this.requestedAt,
    this.acceptedAt,
    this.pickedUpAt,
    this.completedAt,
    required this.updatedAt,
    this.penaltyAmount,
    this.overdueDays,
    this.hasPenalty,
    this.paymentMethod,
    this.paymentStatus,
    this.dueDate,
    this.isFinalized,
  });

  /// Parse fine amount from JSON - handles both string and numeric values
  static double _parseFineAmount(dynamic value) {
    if (value == null) return 0.0;

    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      if (value.isEmpty) return 0.0;
      return double.tryParse(value) ?? 0.0;
    }

    // Fallback: try to convert to string then parse
    return double.tryParse(value.toString()) ?? 0.0;
  }

  factory ReturnRequest.fromJson(Map<String, dynamic> json) {
    // Handle both old format (borrow_request) and new format (borrowing)
    BorrowRequest? borrowReq;
    try {
      if (json['borrowing'] != null) {
        // New format: borrowing is a nested object or ID
        if (json['borrowing'] is Map) {
          borrowReq = BorrowRequest.fromJson(json['borrowing']);
        } else {
          // If borrowing is just an ID, create a BorrowRequest with data from serializer fields
          final borrowingId = json['borrowing_id'] ?? json['borrowing'] ?? 0;

          // Create customer object if email/phone are available
          User? customer;
          if (json['borrowing_customer_email'] != null) {
            final customerName =
                json['borrowing_customer_name']?.toString() ?? '';
            final nameParts = customerName.split(' ');
            customer = User(
              id: json['borrowing_customer_id'] is int
                  ? json['borrowing_customer_id']
                  : int.tryParse(
                          json['borrowing_customer_id']?.toString() ?? '0',
                        ) ??
                        0,
              email: json['borrowing_customer_email'],
              firstName: nameParts.isNotEmpty ? nameParts.first : '',
              lastName: nameParts.length > 1
                  ? nameParts.sublist(1).join(' ')
                  : '',
              phone: json['borrowing_customer_phone'],
            );
          }

          borrowReq = BorrowRequest(
            id: borrowingId,
            durationDays: json['borrowing_duration_days'] ?? 0,
            requestDate: json['created_at'] != null
                ? DateTime.parse(json['created_at'])
                : DateTime.now(),
            status: json['status'] ?? 'unknown',
            customer: customer,
            customerName: json['borrowing_customer_name'],
            bookTitle: json['borrowing_book_name'],
            dueDate: json['expected_return_date'] != null
                ? DateTime.parse(json['expected_return_date'])
                : null,
          );
        }
      } else if (json['borrow_request'] != null) {
        // Old format compatibility
        borrowReq = BorrowRequest.fromJson(json['borrow_request']);
      }
    } catch (e) {
      debugPrint('Error parsing borrowing/borrow_request: $e');
    }

    // Create a BorrowRequest if none was parsed, using serializer fields
    if (borrowReq == null) {
      final borrowingId = json['borrowing_id'] ?? json['borrowing'] ?? 0;

      // Create customer object if email/phone are available
      User? customer;
      if (json['borrowing_customer_email'] != null) {
        final customerName = json['borrowing_customer_name']?.toString() ?? '';
        final nameParts = customerName.split(' ');
        customer = User(
          id: json['borrowing_customer_id'] is int
              ? json['borrowing_customer_id']
              : int.tryParse(
                      json['borrowing_customer_id']?.toString() ?? '0',
                    ) ??
                    0,
          email: json['borrowing_customer_email'],
          firstName: nameParts.isNotEmpty ? nameParts.first : '',
          lastName: nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '',
          phone: json['borrowing_customer_phone'],
        );
      }

      borrowReq = BorrowRequest(
        id: borrowingId is int
            ? borrowingId
            : int.tryParse(borrowingId.toString()) ?? 0,
        durationDays: json['borrowing_duration_days'] ?? 0,
        requestDate: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
        status: json['status'] ?? 'unknown',
        customer: customer,
        customerName: json['borrowing_customer_name'],
        bookTitle: json['borrowing_book_name'],
        dueDate: json['expected_return_date'] != null
            ? DateTime.parse(json['expected_return_date'])
            : null,
      );
    } else {
      // Update BorrowRequest with serializer fields if they exist and are missing
      if (json['borrowing_customer_name'] != null &&
          (borrowReq.customerName == null || borrowReq.customerName!.isEmpty)) {
        borrowReq = borrowReq.copyWith(
          customerName: json['borrowing_customer_name'],
        );
      }
      if (json['borrowing_book_name'] != null &&
          (borrowReq.bookTitle == null || borrowReq.bookTitle!.isEmpty)) {
        borrowReq = borrowReq.copyWith(bookTitle: json['borrowing_book_name']);
      }
      // Update customer phone from ReturnRequest serializer field if available
      // This ensures we use the phone number from the database even if it's not in the nested borrowing object
      // Determine the phone number to use - prioritize top-level field, then nested customer phone
      String? phoneToUse;
      if (json['borrowing_customer_phone'] != null &&
          json['borrowing_customer_phone'].toString().trim().isNotEmpty) {
        phoneToUse = json['borrowing_customer_phone'].toString().trim();
      } else if (borrowReq.customer?.phone != null &&
          borrowReq.customer!.phone!.trim().isNotEmpty) {
        phoneToUse = borrowReq.customer!.phone!.trim();
      }

      // Update customer with phone number if we found one
      if (phoneToUse != null && phoneToUse.isNotEmpty) {
        if (borrowReq.customer != null) {
          // Update existing customer with phone number
          final updatedCustomer = User(
            id: borrowReq.customer!.id,
            firstName: borrowReq.customer!.firstName,
            lastName: borrowReq.customer!.lastName,
            email: borrowReq.customer!.email,
            phone: phoneToUse,
            address: borrowReq.customer!.address,
            city: borrowReq.customer!.city,
            profileImageUrl: borrowReq.customer!.profileImageUrl,
            dateJoined: borrowReq.customer!.dateJoined,
            isActive: borrowReq.customer!.isActive,
            role: borrowReq.customer!.role,
          );
          borrowReq = borrowReq.copyWith(customer: updatedCustomer);
        } else if (json['borrowing_customer_email'] != null) {
          // Create customer object if phone is available but customer doesn't exist
          final customerName =
              json['borrowing_customer_name']?.toString() ?? '';
          final nameParts = customerName.split(' ');
          final customer = User(
            id: json['borrowing_customer_id'] is int
                ? json['borrowing_customer_id']
                : int.tryParse(
                        json['borrowing_customer_id']?.toString() ?? '0',
                      ) ??
                      0,
            email: json['borrowing_customer_email'],
            firstName: nameParts.isNotEmpty ? nameParts.first : '',
            lastName: nameParts.length > 1
                ? nameParts.sublist(1).join(' ')
                : '',
            phone: phoneToUse,
          );
          borrowReq = borrowReq.copyWith(customer: customer);
        }
      }
    }

    // Parse fine information if available
    int? fineId;
    int? fineDaysLate;
    String? finePaymentMethod;
    String? finePaymentStatus;

    if (json['fine'] != null && json['fine'] is Map) {
      final fineData = json['fine'] as Map<String, dynamic>;
      fineId = fineData['id'] is int
          ? fineData['id']
          : int.tryParse(fineData['id']?.toString() ?? '');
      fineDaysLate = fineData['days_late'] is int
          ? fineData['days_late']
          : int.tryParse(fineData['days_late']?.toString() ?? '');
      finePaymentMethod = fineData['payment_method']?.toString();
      finePaymentStatus = fineData['payment_status']?.toString();
    }

    // Parse penalty and payment information
    // Priority: fine object > borrowing.fine_amount > top-level fine_amount > penalty_amount
    double? penaltyAmount;

    // 1. Check inside 'fine' object first (most accurate source)
    if (json['fine'] != null && json['fine'] is Map) {
      final fineData = json['fine'] as Map<String, dynamic>;
      final fineAmount = fineData['fine_amount'];
      if (fineAmount != null) {
        penaltyAmount = fineAmount is double
            ? fineAmount
            : fineAmount is int
            ? fineAmount.toDouble()
            : double.tryParse(fineAmount.toString());
      }
    }

    // 2. Check inside 'borrowing' object (backend returns fine_amount here)
    if (penaltyAmount == null &&
        json['borrowing'] != null &&
        json['borrowing'] is Map) {
      final borrowingData = json['borrowing'] as Map<String, dynamic>;
      final fineAmount = borrowingData['fine_amount'];
      if (fineAmount != null) {
        penaltyAmount = fineAmount is double
            ? fineAmount
            : fineAmount is int
            ? fineAmount.toDouble()
            : double.tryParse(fineAmount.toString());
      }
    }

    // 3. Check top-level fields
    if (penaltyAmount == null) {
      final penaltyValue = json['penalty_amount'] ?? json['fine_amount'];
      if (penaltyValue != null) {
        penaltyAmount = penaltyValue is double
            ? penaltyValue
            : penaltyValue is int
            ? penaltyValue.toDouble()
            : double.tryParse(penaltyValue.toString());
      }
    }

    int? overdueDays;
    if (json['overdue_days'] != null) {
      overdueDays = json['overdue_days'] is int
          ? json['overdue_days']
          : int.tryParse(json['overdue_days'].toString());
    }

    bool? hasPenalty;
    if (json['has_penalty'] != null) {
      hasPenalty = json['has_penalty'] is bool
          ? json['has_penalty']
          : json['has_penalty'].toString().toLowerCase() == 'true';
    }

    // Use fine payment method/status if available, otherwise use top-level
    String? paymentMethod =
        finePaymentMethod ?? json['payment_method']?.toString();
    String? paymentStatus =
        finePaymentStatus ?? json['payment_status']?.toString();

    DateTime? dueDate;
    if (json['due_date'] != null) {
      try {
        dueDate = DateTime.parse(json['due_date']);
      } catch (e) {
        debugPrint('Error parsing due_date: $e');
      }
    }

    bool? isFinalized;
    if (json['is_finalized'] != null) {
      isFinalized = json['is_finalized'] is bool
          ? json['is_finalized']
          : json['is_finalized'].toString().toLowerCase() == 'true';
    }

    // Parse delivery_request if available (for unified delivery status)
    BorrowDeliveryRequest? deliveryRequest;
    if (json['delivery_request'] != null && json['delivery_request'] is Map) {
      try {
        deliveryRequest = BorrowDeliveryRequest.fromJson(
          json['delivery_request'] as Map<String, dynamic>,
        );
      } catch (e) {
        debugPrint('Error parsing delivery_request for ReturnRequest: $e');
      }
    }

    // UNIFIED DELIVERY STATUS: Use delivery_request_status if available
    final deliveryRequestStatusField = json['delivery_request_status'];
    String finalStatus;

    // DEBUG: Log all status-related fields
    debugPrint('=== ReturnRequest.fromJson DEBUG ===');
    debugPrint('  json[id]: ${json['id']}');
    debugPrint('  json[status]: ${json['status']}');
    debugPrint('  json[delivery_request_status]: $deliveryRequestStatusField');
    debugPrint('  json[delivery_manager]: ${json['delivery_manager']}');
    debugPrint(
      '  json[delivery_manager_name]: ${json['delivery_manager_name']}',
    );
    debugPrint('=== END ReturnRequest DEBUG ===');

    if (deliveryRequestStatusField != null) {
      // Use delivery_request_status as primary (unified delivery status approach)
      // Both finalStatus and any other status field should use the same unified value
      finalStatus = deliveryRequestStatusField;
      debugPrint(
        'ReturnRequest: Using delivery_request_status as primary: $finalStatus',
      );
    } else {
      // Fallback to original status only when delivery_request_status is not available
      finalStatus = json['status'] ?? 'PENDING';
      debugPrint('ReturnRequest: Using fallback status: $finalStatus');
    }

    return ReturnRequest(
      id: json['id']?.toString() ?? '',
      borrowRequest: borrowReq,
      status: finalStatus, // Use delivery_request_status if available
      deliveryManagerId: json['delivery_manager']?.toString(),
      deliveryManagerName: json['delivery_manager_name'],
      deliveryManagerEmail: json['delivery_manager_email'],
      deliveryManagerPhone: json['delivery_manager_phone'],
      deliveryRequest: deliveryRequest,
      deliveryRequestStatus: deliveryRequestStatusField
          ?.toString(), // CRITICAL: Store as separate field
      fineAmount: _parseFineAmount(json['fine_amount'] ?? 0),
      fineInvoiceId: json['fine_invoice_id'],
      fineId: fineId,
      fineDaysLate: fineDaysLate,
      finePaymentMethod: finePaymentMethod,
      finePaymentStatus: finePaymentStatus,
      returnNotes: json['return_notes'],
      requestedAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : json['requested_at'] != null
          ? DateTime.parse(json['requested_at'])
          : DateTime.now(),
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'])
          : null,
      pickedUpAt: json['picked_up_at'] != null
          ? DateTime.parse(json['picked_up_at'])
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      penaltyAmount: penaltyAmount,
      overdueDays: overdueDays,
      hasPenalty: hasPenalty,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      dueDate: dueDate,
      isFinalized: isFinalized,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'borrow_request': borrowRequest.toJson(),
      'status': status,
      'delivery_manager': deliveryManagerId,
      'delivery_manager_name': deliveryManagerName,
      'delivery_manager_email': deliveryManagerEmail,
      'delivery_manager_phone': deliveryManagerPhone,
      'fine_amount': fineAmount,
      'fine_invoice_id': fineInvoiceId,
      'return_notes': returnNotes,
      'requested_at': requestedAt.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
      'picked_up_at': pickedUpAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // New status values (matching backend ReturnStatus)
  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isAssigned => status == 'ASSIGNED';
  bool get isAccepted => status == 'ACCEPTED';
  bool get isInProgress => status == 'IN_PROGRESS';
  bool get isCompleted => status == 'COMPLETED';

  // Legacy status values (for backward compatibility)
  bool get isPendingPickup => status == 'pending_pickup' || isPending;
  bool get isInReturn => status == 'in_return' || isInProgress;
  bool get isReturningToLibrary =>
      status == 'returning_to_library' || isInProgress;
  bool get isReturnedSuccessfully =>
      status == 'returned_successfully' || isCompleted;
  bool get isLateReturn => status == 'late_return';
  bool get isReturnRequested => status == 'return_requested' || isPending;
  bool get isReturnApproved => status == 'return_approved' || isApproved;
  bool get isReturnAssigned => status == 'return_assigned' || isAssigned;
  bool get hasFine => fineAmount > 0;

  String get statusDisplay {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'Pending';
      case 'APPROVED':
        return 'Approved';
      case 'ASSIGNED':
        return 'Assigned';
      case 'ACCEPTED':
        return 'Accepted';
      case 'IN_PROGRESS':
        return 'In Progress';
      case 'COMPLETED':
        return 'Completed';
      // Legacy status values
      case 'RETURN_REQUESTED':
        return 'Return Requested';
      case 'RETURN_APPROVED':
        return 'Return Approved';
      case 'RETURN_ASSIGNED':
        return 'Return Assigned';
      case 'PENDING_PICKUP':
        return 'Pending Pickup';
      case 'IN_RETURN':
        return 'In Return';
      case 'RETURNING_TO_LIBRARY':
        return 'Returning to Library';
      case 'RETURNED_SUCCESSFULLY':
        return 'Returned Successfully';
      case 'LATE_RETURN':
        return 'Late Return (with Fine)';
      default:
        return status;
    }
  }
}

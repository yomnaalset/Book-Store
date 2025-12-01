import 'package:flutter/foundation.dart';
import 'borrow_request.dart';
import 'user.dart';

class ReturnRequest {
  final String id;
  final BorrowRequest borrowRequest;
  final String status;
  final String? deliveryManagerId;
  final String? deliveryManagerName;
  final String? deliveryManagerEmail;
  final String? deliveryManagerPhone;
  final double fineAmount;
  final String? fineInvoiceId;
  final String? returnNotes;
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
    required this.fineAmount,
    this.fineInvoiceId,
    this.returnNotes,
    required this.requestedAt,
    this.acceptedAt,
    this.pickedUpAt,
    this.completedAt,
    required this.updatedAt,
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
          // Debug: Check if customer phone is in nested borrowing
          debugPrint(
            'ReturnRequest.fromJson: Nested borrowing customer phone: ${json['borrowing']?['customer']?['phone']}',
          );
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
      debugPrint(
        'ReturnRequest.fromJson: borrowing_customer_phone from serializer: ${json['borrowing_customer_phone']}',
      );
      debugPrint(
        'ReturnRequest.fromJson: Current customer phone from nested borrowing: ${borrowReq.customer?.phone}',
      );
      debugPrint(
        'ReturnRequest.fromJson: Nested borrowing customer phone: ${json['borrowing']?['customer']?['phone']}',
      );

      // Determine the phone number to use - prioritize top-level field, then nested customer phone
      String? phoneToUse;
      if (json['borrowing_customer_phone'] != null &&
          json['borrowing_customer_phone'].toString().trim().isNotEmpty) {
        phoneToUse = json['borrowing_customer_phone'].toString().trim();
        debugPrint(
          'ReturnRequest.fromJson: Using phone from borrowing_customer_phone: $phoneToUse',
        );
      } else if (borrowReq.customer?.phone != null &&
          borrowReq.customer!.phone!.trim().isNotEmpty) {
        phoneToUse = borrowReq.customer!.phone!.trim();
        debugPrint(
          'ReturnRequest.fromJson: Using phone from nested customer: $phoneToUse',
        );
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
          debugPrint(
            'ReturnRequest.fromJson: Customer phone updated successfully to: $phoneToUse',
          );
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
          debugPrint(
            'ReturnRequest.fromJson: Created customer with phone: $phoneToUse',
          );
        }
      } else {
        debugPrint(
          'ReturnRequest.fromJson: No phone number available from any source',
        );
      }
    }

    return ReturnRequest(
      id: json['id']?.toString() ?? '',
      borrowRequest: borrowReq,
      status: json['status'] ?? 'PENDING',
      deliveryManagerId: json['delivery_manager']?.toString(),
      deliveryManagerName: json['delivery_manager_name'],
      deliveryManagerEmail: json['delivery_manager_email'],
      deliveryManagerPhone: json['delivery_manager_phone'],
      fineAmount: _parseFineAmount(json['fine_amount'] ?? 0),
      fineInvoiceId: json['fine_invoice_id'],
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

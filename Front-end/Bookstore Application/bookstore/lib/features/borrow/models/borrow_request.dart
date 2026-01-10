import 'package:flutter/foundation.dart';
import 'book.dart';
import 'user.dart';
import 'delivery_request.dart';

class TimelineEvent {
  final String status;
  final DateTime date;
  final String description;

  TimelineEvent({
    required this.status,
    required this.date,
    required this.description,
  });

  factory TimelineEvent.fromJson(Map<String, dynamic> json) {
    return TimelineEvent(
      status: json['status'] ?? '',
      date: DateTime.parse(json['date']),
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'date': date.toIso8601String(),
      'description': description,
    };
  }
}

class BorrowRequest {
  final int id;
  final User? customer;
  final String? customerName;
  final Book? book;
  final String? bookTitle;
  final int durationDays;
  final DateTime requestDate;
  final DateTime? approvalDate;
  final DateTime? dueDate;
  final DateTime? returnDate;
  final DateTime? finalReturnDate;
  final String status;
  final String? statusDisplay;
  // Admin-specific: separate borrow_status and delivery_status
  final String?
  borrowStatus; // Official BorrowRequest status (from backend borrow_status field)
  final String? borrowStatusDisplay;
  final String? rejectionReason;
  final double? fineAmount;
  final String? fineStatus; // 'paid' or 'unpaid'
  final String? paymentMethod; // 'cash' or 'mastercard'
  final bool isOverdue;
  final String? deliveryNotes;
  final String? pickupNotes;
  final String? userId;
  final String? bookId;
  final String? notes;
  final DateTime? deliveryDate;
  final String? deliveryAddress;
  final String? additionalNotes;
  final List<TimelineEvent>? timeline;
  final bool? canRequestReturn;
  final User? deliveryPerson;
  final User? approvedBy;
  final int? daysRemaining;
  final int? daysOverdue;
  final BorrowDeliveryRequest?
  deliveryRequest; // DeliveryRequest info when status is approved/assigned_to_delivery

  BorrowRequest({
    required this.id,
    this.customer,
    this.customerName,
    this.book,
    this.bookTitle,
    required this.durationDays,
    required this.requestDate,
    this.approvalDate,
    this.dueDate,
    this.returnDate,
    this.finalReturnDate,
    required this.status,
    this.statusDisplay,
    this.borrowStatus,
    this.borrowStatusDisplay,
    this.rejectionReason,
    this.fineAmount,
    this.fineStatus,
    this.paymentMethod,
    this.isOverdue = false,
    this.deliveryNotes,
    this.pickupNotes,
    this.userId,
    this.bookId,
    this.notes,
    this.deliveryDate,
    this.deliveryAddress,
    this.additionalNotes,
    this.timeline,
    this.canRequestReturn,
    this.deliveryPerson,
    this.approvedBy,
    this.daysRemaining,
    this.daysOverdue,
    this.deliveryRequest,
  });

  /// Parse fine amount from JSON - handles both string and numeric values
  static double? _parseFineAmount(dynamic value) {
    if (value == null) return null;

    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      if (value.isEmpty) return null;
      return double.tryParse(value);
    }

    // Fallback: try to convert to string then parse
    return double.tryParse(value.toString());
  }

  factory BorrowRequest.fromJson(Map<String, dynamic> json) {
    // Debug: Log status parsing for troubleshooting
    final borrowStatusFromJson = json['borrow_status'];
    final statusFromJson = json['status'];
    final deliveryRequestStatus = json['delivery_request']?['status'];
    final deliveryRequestStatusField =
        json['delivery_request_status']; // New unified field

    if (borrowStatusFromJson != null ||
        statusFromJson != null ||
        deliveryRequestStatusField != null) {
      debugPrint('DEBUG: BorrowRequest.fromJson - Parsing status:');
      debugPrint('  - borrow_status from API: $borrowStatusFromJson');
      debugPrint('  - status from API: $statusFromJson');
      debugPrint('  - delivery_request.status: $deliveryRequestStatus');
      debugPrint(
        '  - delivery_request_status field: $deliveryRequestStatusField',
      );
    }

    // UNIFIED DELIVERY STATUS: Use delivery_request_status if available (primary source)
    // This becomes the source of truth for customers and delivery managers
    String finalStatus;
    String? finalBorrowStatus;

    if (deliveryRequestStatusField != null) {
      // Use delivery_request_status as primary (unified delivery status approach)
      finalStatus =
          deliveryRequestStatusField; // Use the status from the DeliveryRequest
      finalBorrowStatus =
          deliveryRequestStatusField; // Do not use the old status - use unified status
      debugPrint('  - Using delivery_request_status as primary: $finalStatus');
      debugPrint(
        '  - Both finalStatus and finalBorrowStatus set to unified status',
      );
    } else {
      // Fallback only if there is no delivery_request
      finalStatus = borrowStatusFromJson ?? statusFromJson ?? 'pending';
      finalBorrowStatus = finalStatus; // Use same value for consistency
      debugPrint('  - Using fallback logic: $finalStatus');
    }

    debugPrint('  - Final status used: $finalStatus');
    debugPrint('  - Final borrowStatus used: $finalBorrowStatus');

    return BorrowRequest(
      id: json['id'] ?? 0,
      customer: json['customer'] != null
          ? User.fromJson(json['customer'])
          : null,
      customerName:
          json['customer']?['full_name'] ??
          json['customer_name'] ??
          json['customer']?['name'],
      book: json['book'] != null ? Book.fromJson(json['book']) : null,
      bookTitle: json['book_title'] ?? json['book']?['name'],
      durationDays: json['borrow_period_days'] ?? json['duration_days'] ?? 0,
      requestDate: DateTime.parse(
        json['request_date'] ?? DateTime.now().toIso8601String(),
      ),
      approvalDate: json['approved_date'] != null
          ? DateTime.parse(json['approved_date'])
          : null,
      dueDate: json['expected_return_date'] != null
          ? DateTime.parse(json['expected_return_date'])
          : json['due_date'] != null
          ? DateTime.parse(json['due_date'])
          : null,
      returnDate: json['actual_return_date'] != null
          ? DateTime.parse(json['actual_return_date'])
          : json['return_date'] != null
          ? DateTime.parse(json['return_date'])
          : null,
      finalReturnDate: json['final_return_date'] != null
          ? DateTime.parse(json['final_return_date'])
          : null,
      status:
          finalStatus, // Primary status (delivery_request_status or fallback)
      statusDisplay: json['borrow_status_display'] ?? json['status_display'],
      borrowStatus:
          finalBorrowStatus, // Keep separate for admin (original borrow status)
      borrowStatusDisplay:
          json['borrow_status_display'] ?? json['status_display'],
      rejectionReason: json['rejection_reason'],
      fineAmount: _parseFineAmount(json['fine_amount']),
      fineStatus: json['fine_status'],
      paymentMethod: json['payment_method'],
      isOverdue: json['is_overdue'] ?? false,
      deliveryNotes: json['delivery_notes'],
      pickupNotes: json['pickup_notes'],
      userId: json['user_id']?.toString(),
      bookId: json['book_id']?.toString(),
      notes: json['notes'],
      deliveryDate: json['delivery_date'] != null
          ? DateTime.parse(json['delivery_date'])
          : null,
      deliveryAddress: json['delivery_address'],
      additionalNotes: json['additional_notes'],
      timeline: json['timeline'] != null
          ? (json['timeline'] as List)
                .map((item) => TimelineEvent.fromJson(item))
                .toList()
          : null,
      canRequestReturn: json['can_request_return'],
      deliveryPerson: json['delivery_person'] != null
          ? User.fromJson(json['delivery_person'])
          : null,
      approvedBy: json['approved_by'] != null
          ? User.fromJson(json['approved_by'])
          : null,
      daysRemaining: json['days_remaining'],
      daysOverdue: json['days_overdue'],
      deliveryRequest: json['delivery_request'] != null
          ? BorrowDeliveryRequest.fromJson(json['delivery_request'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer': customer?.toJson(),
      'customer_name': customerName,
      'book': book?.toJson(),
      'book_title': bookTitle,
      'duration_days': durationDays,
      'request_date': requestDate.toIso8601String(),
      'approval_date': approvalDate?.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'return_date': returnDate?.toIso8601String(),
      'final_return_date': finalReturnDate?.toIso8601String(),
      'status': status,
      'rejection_reason': rejectionReason,
      'fine_amount': fineAmount,
      'fine_status': fineStatus,
      'payment_method': paymentMethod,
      'is_overdue': isOverdue,
      'delivery_notes': deliveryNotes,
      'pickup_notes': pickupNotes,
      'user_id': userId,
      'book_id': bookId,
      'notes': notes,
      'delivery_date': deliveryDate?.toIso8601String(),
      'delivery_address': deliveryAddress,
      'additional_notes': additionalNotes,
      'timeline': timeline?.map((event) => event.toJson()).toList(),
    };
  }

  BorrowRequest copyWith({
    int? id,
    User? customer,
    String? customerName,
    Book? book,
    String? bookTitle,
    int? durationDays,
    DateTime? requestDate,
    DateTime? approvalDate,
    DateTime? dueDate,
    DateTime? returnDate,
    DateTime? finalReturnDate,
    String? status,
    String? rejectionReason,
    double? fineAmount,
    String? fineStatus,
    String? paymentMethod,
    bool? isOverdue,
    String? deliveryNotes,
    String? pickupNotes,
    String? userId,
    String? bookId,
    String? notes,
    DateTime? deliveryDate,
    String? deliveryAddress,
    String? additionalNotes,
    List<TimelineEvent>? timeline,
  }) {
    return BorrowRequest(
      id: id ?? this.id,
      customer: customer ?? this.customer,
      customerName: customerName ?? this.customerName,
      book: book ?? this.book,
      bookTitle: bookTitle ?? this.bookTitle,
      durationDays: durationDays ?? this.durationDays,
      requestDate: requestDate ?? this.requestDate,
      approvalDate: approvalDate ?? this.approvalDate,
      dueDate: dueDate ?? this.dueDate,
      returnDate: returnDate ?? this.returnDate,
      finalReturnDate: finalReturnDate ?? this.finalReturnDate,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      fineAmount: fineAmount ?? this.fineAmount,
      fineStatus: fineStatus ?? this.fineStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isOverdue: isOverdue ?? this.isOverdue,
      deliveryNotes: deliveryNotes ?? this.deliveryNotes,
      pickupNotes: pickupNotes ?? this.pickupNotes,
      userId: userId ?? this.userId,
      bookId: bookId ?? this.bookId,
      notes: notes ?? this.notes,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      additionalNotes: additionalNotes ?? this.additionalNotes,
      timeline: timeline ?? this.timeline,
    );
  }
}

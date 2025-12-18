/// Model for customer fines in the borrowing system
/// Stage 6: Fine Management
class Fine {
  final int id;
  final String bookTitle;
  final double fineAmount;
  final String fineStatus; // 'paid', 'unpaid', 'pending_cash_payment', 'failed'
  final String? paymentMethod; // 'cash' or 'mastercard'
  final String borrowPeriod;
  final DateTime? expectedReturnDate;
  final DateTime? actualReturnDate;
  final int daysLate;
  final int daysOverdue;
  final DateTime createdAt;
  final int? borrowRequestId;
  final String? customerName;

  Fine({
    required this.id,
    required this.bookTitle,
    required this.fineAmount,
    required this.fineStatus,
    this.paymentMethod,
    required this.borrowPeriod,
    this.expectedReturnDate,
    this.actualReturnDate,
    required this.daysLate,
    this.daysOverdue = 0,
    required this.createdAt,
    this.borrowRequestId,
    this.customerName,
  });

  factory Fine.fromJson(Map<String, dynamic> json) {
    return Fine(
      id: json['id'] ?? 0,
      bookTitle: json['book_title'] ?? json['book_name'] ?? '',
      fineAmount: (json['fine_amount'] as num?)?.toDouble() ?? 
                  (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      fineStatus: json['fine_status'] ?? json['status'] ?? 'unpaid',
      paymentMethod: json['payment_method'],
      borrowPeriod: json['borrow_period'] ?? '',
      expectedReturnDate: json['expected_return_date'] != null
          ? DateTime.parse(json['expected_return_date'])
          : null,
      actualReturnDate: json['actual_return_date'] != null
          ? DateTime.parse(json['actual_return_date'])
          : null,
      daysLate: json['days_late'] ?? 0,
      daysOverdue: json['days_overdue'] ?? json['days_late'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      borrowRequestId: json['borrow_request_id'] ?? json['borrowing_id'],
      customerName: json['customer_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'book_title': bookTitle,
      'fine_amount': fineAmount,
      'fine_status': fineStatus,
      'payment_method': paymentMethod,
      'borrow_period': borrowPeriod,
      'expected_return_date': expectedReturnDate?.toIso8601String(),
      'actual_return_date': actualReturnDate?.toIso8601String(),
      'days_late': daysLate,
      'days_overdue': daysOverdue,
      'created_at': createdAt.toIso8601String(),
      'borrow_request_id': borrowRequestId,
      'customer_name': customerName,
    };
  }

  bool get isPaid => fineStatus == 'paid';
  bool get isUnpaid => fineStatus == 'unpaid';
  bool get isPendingCashPayment => fineStatus == 'pending_cash_payment';
  bool get isFailed => fineStatus == 'failed';
  bool get isCashPayment => paymentMethod == 'cash';
  bool get isMasterCardPayment => paymentMethod == 'mastercard';

  Fine copyWith({
    int? id,
    String? bookTitle,
    double? fineAmount,
    String? fineStatus,
    String? paymentMethod,
    String? borrowPeriod,
    DateTime? expectedReturnDate,
    DateTime? actualReturnDate,
    int? daysLate,
    int? daysOverdue,
    DateTime? createdAt,
    int? borrowRequestId,
    String? customerName,
  }) {
    return Fine(
      id: id ?? this.id,
      bookTitle: bookTitle ?? this.bookTitle,
      fineAmount: fineAmount ?? this.fineAmount,
      fineStatus: fineStatus ?? this.fineStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      borrowPeriod: borrowPeriod ?? this.borrowPeriod,
      expectedReturnDate: expectedReturnDate ?? this.expectedReturnDate,
      actualReturnDate: actualReturnDate ?? this.actualReturnDate,
      daysLate: daysLate ?? this.daysLate,
      daysOverdue: daysOverdue ?? this.daysOverdue,
      createdAt: createdAt ?? this.createdAt,
      borrowRequestId: borrowRequestId ?? this.borrowRequestId,
      customerName: customerName ?? this.customerName,
    );
  }
}

/// Summary of customer's fines
class FineSummary {
  final double totalUnpaid;
  final int totalFines;
  final bool hasUnpaidFines;
  final bool canSubmitRequest;

  FineSummary({
    required this.totalUnpaid,
    required this.totalFines,
    required this.hasUnpaidFines,
    required this.canSubmitRequest,
  });

  factory FineSummary.fromJson(Map<String, dynamic> json) {
    return FineSummary(
      totalUnpaid: (json['total_unpaid'] as num?)?.toDouble() ?? 0.0,
      totalFines: json['total_fines'] ?? 0,
      hasUnpaidFines: json['has_unpaid_fines'] ?? false,
      canSubmitRequest: json['can_submit_request'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_unpaid': totalUnpaid,
      'total_fines': totalFines,
      'has_unpaid_fines': hasUnpaidFines,
      'can_submit_request': canSubmitRequest,
    };
  }
}

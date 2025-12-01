/// Model for customer fines in the borrowing system
/// Stage 6: Fine Management
class Fine {
  final int id;
  final String bookTitle;
  final double fineAmount;
  final String fineStatus; // 'paid' or 'unpaid'
  final String borrowPeriod;
  final DateTime? expectedReturnDate;
  final DateTime? actualReturnDate;
  final int daysLate;
  final DateTime createdAt;

  Fine({
    required this.id,
    required this.bookTitle,
    required this.fineAmount,
    required this.fineStatus,
    required this.borrowPeriod,
    this.expectedReturnDate,
    this.actualReturnDate,
    required this.daysLate,
    required this.createdAt,
  });

  factory Fine.fromJson(Map<String, dynamic> json) {
    return Fine(
      id: json['id'] ?? 0,
      bookTitle: json['book_title'] ?? '',
      fineAmount: (json['fine_amount'] as num?)?.toDouble() ?? 0.0,
      fineStatus: json['fine_status'] ?? 'unpaid',
      borrowPeriod: json['borrow_period'] ?? '',
      expectedReturnDate: json['expected_return_date'] != null
          ? DateTime.parse(json['expected_return_date'])
          : null,
      actualReturnDate: json['actual_return_date'] != null
          ? DateTime.parse(json['actual_return_date'])
          : null,
      daysLate: json['days_late'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'book_title': bookTitle,
      'fine_amount': fineAmount,
      'fine_status': fineStatus,
      'borrow_period': borrowPeriod,
      'expected_return_date': expectedReturnDate?.toIso8601String(),
      'actual_return_date': actualReturnDate?.toIso8601String(),
      'days_late': daysLate,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isPaid => fineStatus == 'paid';
  bool get isUnpaid => fineStatus == 'unpaid';

  Fine copyWith({
    int? id,
    String? bookTitle,
    double? fineAmount,
    String? fineStatus,
    String? borrowPeriod,
    DateTime? expectedReturnDate,
    DateTime? actualReturnDate,
    int? daysLate,
    DateTime? createdAt,
  }) {
    return Fine(
      id: id ?? this.id,
      bookTitle: bookTitle ?? this.bookTitle,
      fineAmount: fineAmount ?? this.fineAmount,
      fineStatus: fineStatus ?? this.fineStatus,
      borrowPeriod: borrowPeriod ?? this.borrowPeriod,
      expectedReturnDate: expectedReturnDate ?? this.expectedReturnDate,
      actualReturnDate: actualReturnDate ?? this.actualReturnDate,
      daysLate: daysLate ?? this.daysLate,
      createdAt: createdAt ?? this.createdAt,
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

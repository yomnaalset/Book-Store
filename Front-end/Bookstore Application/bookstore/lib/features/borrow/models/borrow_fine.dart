class BorrowFine {
  final String id;
  final String borrowRequestId;
  final String userId;
  final double amount;
  final String status;
  final DateTime createdAt;
  final DateTime? paidAt;
  final DateTime? paidDate;
  final String? paymentMethod;
  final String? transactionId;
  final String? notes;
  final String? reason;
  final String? paidByName;

  BorrowFine({
    required this.id,
    required this.borrowRequestId,
    required this.userId,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.paidAt,
    this.paidDate,
    this.paymentMethod,
    this.transactionId,
    this.notes,
    this.reason,
    this.paidByName,
  });

  factory BorrowFine.fromJson(Map<String, dynamic> json) {
    return BorrowFine(
      id: json['id']?.toString() ?? '',
      borrowRequestId:
          json['borrowRequestId']?.toString() ??
          json['borrow_request_id']?.toString() ??
          '',
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      amount: json['amount'] is num ? json['amount'].toDouble() : 0.0,
      status: json['status'] ?? 'pending',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      paidAt: json['paidAt'] != null
          ? DateTime.parse(json['paidAt'])
          : json['paid_at'] != null
          ? DateTime.parse(json['paid_at'])
          : null,
      paidDate: json['paidDate'] != null
          ? DateTime.parse(json['paidDate'])
          : json['paid_date'] != null
          ? DateTime.parse(json['paid_date'])
          : null,
      paymentMethod: json['paymentMethod'] ?? json['payment_method'],
      transactionId:
          json['transactionId']?.toString() ??
          json['transaction_id']?.toString(),
      notes: json['notes'],
      reason: json['reason'],
      paidByName: json['paidByName'] ?? json['paid_by_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'borrowRequestId': borrowRequestId,
      'userId': userId,
      'amount': amount,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'paidAt': paidAt?.toIso8601String(),
      'paidDate': paidDate?.toIso8601String(),
      'paymentMethod': paymentMethod,
      'transactionId': transactionId,
      'notes': notes,
      'reason': reason,
      'paidByName': paidByName,
    };
  }

  BorrowFine copyWith({
    String? id,
    String? borrowRequestId,
    String? userId,
    double? amount,
    String? status,
    DateTime? createdAt,
    DateTime? paidAt,
    DateTime? paidDate,
    String? paymentMethod,
    String? transactionId,
    String? notes,
    String? reason,
    String? paidByName,
  }) {
    return BorrowFine(
      id: id ?? this.id,
      borrowRequestId: borrowRequestId ?? this.borrowRequestId,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      paidAt: paidAt ?? this.paidAt,
      paidDate: paidDate ?? this.paidDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionId: transactionId ?? this.transactionId,
      notes: notes ?? this.notes,
      reason: reason ?? this.reason,
      paidByName: paidByName ?? this.paidByName,
    );
  }
}

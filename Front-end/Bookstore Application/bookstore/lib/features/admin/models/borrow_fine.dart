class BorrowFine {
  final String id;
  final String borrowRequestId;
  final String userId;
  final double amount;
  final String status;
  final DateTime createdAt;
  final DateTime? paidAt;
  final String? paymentMethod;
  final String? transactionId;
  final String? notes;

  BorrowFine({
    required this.id,
    required this.borrowRequestId,
    required this.userId,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.paidAt,
    this.paymentMethod,
    this.transactionId,
    this.notes,
  });

  factory BorrowFine.fromJson(Map<String, dynamic> json) {
    return BorrowFine(
      id: json['id']?.toString() ?? '',
      borrowRequestId: json['borrowRequestId']?.toString() ?? json['borrow_request_id']?.toString() ?? '',
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
      paymentMethod: json['paymentMethod'] ?? json['payment_method'],
      transactionId: json['transactionId']?.toString() ?? json['transaction_id']?.toString(),
      notes: json['notes'],
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
      'paymentMethod': paymentMethod,
      'transactionId': transactionId,
      'notes': notes,
    };
  }
}

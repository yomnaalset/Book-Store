class BorrowExtension {
  final String id;
  final String borrowRequestId;
  final String userId;
  final String status;
  final DateTime requestDate;
  final DateTime? approvalDate;
  final DateTime originalDueDate;
  final DateTime newDueDate;
  final String? reason;
  final String? notes;

  BorrowExtension({
    required this.id,
    required this.borrowRequestId,
    required this.userId,
    required this.status,
    required this.requestDate,
    this.approvalDate,
    required this.originalDueDate,
    required this.newDueDate,
    this.reason,
    this.notes,
  });

  factory BorrowExtension.fromJson(Map<String, dynamic> json) {
    return BorrowExtension(
      id: json['id']?.toString() ?? '',
      borrowRequestId:
          json['borrowRequestId']?.toString() ??
          json['borrow_request_id']?.toString() ??
          '',
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      status: json['status'] ?? 'pending',
      requestDate: json['requestDate'] != null
          ? DateTime.parse(json['requestDate'])
          : json['request_date'] != null
          ? DateTime.parse(json['request_date'])
          : DateTime.now(),
      approvalDate: json['approvalDate'] != null
          ? DateTime.parse(json['approvalDate'])
          : json['approval_date'] != null
          ? DateTime.parse(json['approval_date'])
          : null,
      originalDueDate: json['originalDueDate'] != null
          ? DateTime.parse(json['originalDueDate'])
          : json['original_due_date'] != null
          ? DateTime.parse(json['original_due_date'])
          : DateTime.now(),
      newDueDate: json['newDueDate'] != null
          ? DateTime.parse(json['newDueDate'])
          : json['new_due_date'] != null
          ? DateTime.parse(json['new_due_date'])
          : DateTime.now().add(const Duration(days: 7)),
      reason: json['reason'],
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'borrowRequestId': borrowRequestId,
      'userId': userId,
      'status': status,
      'requestDate': requestDate.toIso8601String(),
      'approvalDate': approvalDate?.toIso8601String(),
      'originalDueDate': originalDueDate.toIso8601String(),
      'newDueDate': newDueDate.toIso8601String(),
      'reason': reason,
      'notes': notes,
    };
  }

  BorrowExtension copyWith({
    String? id,
    String? borrowRequestId,
    String? userId,
    String? status,
    DateTime? requestDate,
    DateTime? approvalDate,
    DateTime? originalDueDate,
    DateTime? newDueDate,
    String? reason,
    String? notes,
  }) {
    return BorrowExtension(
      id: id ?? this.id,
      borrowRequestId: borrowRequestId ?? this.borrowRequestId,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      requestDate: requestDate ?? this.requestDate,
      approvalDate: approvalDate ?? this.approvalDate,
      originalDueDate: originalDueDate ?? this.originalDueDate,
      newDueDate: newDueDate ?? this.newDueDate,
      reason: reason ?? this.reason,
      notes: notes ?? this.notes,
    );
  }
}

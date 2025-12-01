import 'book.dart';

class BorrowRequest {
  final String id;
  final String userId;
  final String bookId;
  final Book? book;
  final String status;
  final DateTime requestDate;
  final DateTime? approvalDate;
  final DateTime dueDate;
  final DateTime? expectedReturnDate;
  final DateTime? returnDate;
  final DateTime? finalReturnDate;
  final int borrowPeriodDays;
  final String? notes;
  final bool isOverdue;
  final double? fineAmount;
  final String? customerName;
  final String? bookTitle;
  final DateTime? createdAt;

  BorrowRequest({
    required this.id,
    required this.userId,
    required this.bookId,
    this.book,
    required this.status,
    required this.requestDate,
    this.approvalDate,
    required this.dueDate,
    this.expectedReturnDate,
    this.returnDate,
    this.finalReturnDate,
    required this.borrowPeriodDays,
    this.notes,
    this.isOverdue = false,
    this.fineAmount,
    this.customerName,
    this.bookTitle,
    this.createdAt,
  });

  factory BorrowRequest.fromJson(Map<String, dynamic> json) {
    return BorrowRequest(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      bookId: json['bookId']?.toString() ?? json['book_id']?.toString() ?? '',
      book: json['book'] != null ? Book.fromJson(json['book']) : null,
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
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'])
          : json['due_date'] != null
          ? DateTime.parse(json['due_date'])
          : DateTime.now().add(const Duration(days: 14)),
      expectedReturnDate: json['expectedReturnDate'] != null
          ? DateTime.parse(json['expectedReturnDate'])
          : json['expected_return_date'] != null
          ? DateTime.parse(json['expected_return_date'])
          : null,
      returnDate: json['returnDate'] != null
          ? DateTime.parse(json['returnDate'])
          : json['return_date'] != null
          ? DateTime.parse(json['return_date'])
          : null,
      finalReturnDate: json['finalReturnDate'] != null
          ? DateTime.parse(json['finalReturnDate'])
          : json['final_return_date'] != null
          ? DateTime.parse(json['final_return_date'])
          : null,
      borrowPeriodDays:
          json['borrow_period_days'] ?? json['borrowPeriodDays'] ?? 14,
      notes: json['notes'],
      isOverdue: json['isOverdue'] ?? json['is_overdue'] ?? false,
      fineAmount: json['fineAmount'] != null
          ? double.tryParse(json['fineAmount'].toString())
          : json['fine_amount'] != null
          ? double.tryParse(json['fine_amount'].toString())
          : null,
      customerName: json['customerName'] ?? json['customer_name'],
      bookTitle: json['bookTitle'] ?? json['book_title'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'bookId': bookId,
      'book': book?.toJson(),
      'status': status,
      'requestDate': requestDate.toIso8601String(),
      'approvalDate': approvalDate?.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'expectedReturnDate': expectedReturnDate?.toIso8601String(),
      'returnDate': returnDate?.toIso8601String(),
      'finalReturnDate': finalReturnDate?.toIso8601String(),
      'borrow_period_days': borrowPeriodDays,
      'notes': notes,
      'isOverdue': isOverdue,
      'fineAmount': fineAmount,
      'customerName': customerName,
      'bookTitle': bookTitle,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  BorrowRequest copyWith({
    String? id,
    String? userId,
    String? bookId,
    Book? book,
    String? status,
    DateTime? requestDate,
    DateTime? approvalDate,
    DateTime? dueDate,
    DateTime? expectedReturnDate,
    DateTime? returnDate,
    DateTime? finalReturnDate,
    int? borrowPeriodDays,
    String? notes,
    bool? isOverdue,
    double? fineAmount,
    String? customerName,
    String? bookTitle,
    DateTime? createdAt,
  }) {
    return BorrowRequest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bookId: bookId ?? this.bookId,
      book: book ?? this.book,
      status: status ?? this.status,
      requestDate: requestDate ?? this.requestDate,
      approvalDate: approvalDate ?? this.approvalDate,
      dueDate: dueDate ?? this.dueDate,
      expectedReturnDate: expectedReturnDate ?? this.expectedReturnDate,
      returnDate: returnDate ?? this.returnDate,
      finalReturnDate: finalReturnDate ?? this.finalReturnDate,
      borrowPeriodDays: borrowPeriodDays ?? this.borrowPeriodDays,
      notes: notes ?? this.notes,
      isOverdue: isOverdue ?? this.isOverdue,
      fineAmount: fineAmount ?? this.fineAmount,
      customerName: customerName ?? this.customerName,
      bookTitle: bookTitle ?? this.bookTitle,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Compatibility getters
  DateTime? get deliveryDate => approvalDate;
}

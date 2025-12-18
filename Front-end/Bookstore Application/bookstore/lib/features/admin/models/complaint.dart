class Complaint {
  final int id;
  final int userId;
  final String subject;
  final String description;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? customerName;
  final String? customerEmail;
  final String? notes;

  Complaint({
    required this.id,
    required this.userId,
    required this.subject,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.customerName,
    this.customerEmail,
    this.notes,
  });

  factory Complaint.fromJson(Map<String, dynamic> json) {
    return Complaint(
      id: json['id'] as int,
      userId: json['customer'] as int? ?? json['user_id'] as int,
      subject: json['title'] as String? ?? json['subject'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      customerName: json['customer_name'] as String?,
      customerEmail: json['customer_email'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer': userId,
      'title': subject,
      'description': description,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'customer_name': customerName,
      'customer_email': customerEmail,
      'notes': notes,
    };
  }

  Complaint copyWith({
    int? id,
    int? userId,
    String? subject,
    String? description,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? customerName,
    String? customerEmail,
    String? notes,
  }) {
    return Complaint(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customerName: customerName ?? this.customerName,
      customerEmail: customerEmail ?? this.customerEmail,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() {
    return 'Complaint(id: $id, subject: $subject, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Complaint && other.id == id;
  }

  // Status constants
  static const String statusPending = 'pending';
  static const String statusOpen = 'open';
  static const String statusInProgress = 'in_progress';
  static const String statusReplied =
      'replied'; // Maps to 'in_progress' in backend
  static const String statusResolved = 'resolved';
  static const String statusClosed = 'closed';

  // Status labels for display
  static const Map<String, String> statusLabels = {
    statusPending: 'Pending',
    statusOpen: 'Open',
    statusInProgress: 'In Progress',
    statusReplied: 'Replied',
    statusResolved: 'Resolved',
    statusClosed: 'Closed',
  };

  // Getters for convenience
  String get title => subject;

  @override
  int get hashCode => id.hashCode;
}

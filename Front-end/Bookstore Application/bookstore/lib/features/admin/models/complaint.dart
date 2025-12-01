class Complaint {
  final int id;
  final int userId;
  final String type;
  final String subject;
  final String description;
  final String status;
  final String priority;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? customerName;
  final String? customerEmail;
  final int? assignedToId;
  final String? assignedToName;
  final String? resolution;
  final DateTime? resolvedAt;
  final String? notes;

  Complaint({
    required this.id,
    required this.userId,
    required this.type,
    required this.subject,
    required this.description,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    this.customerName,
    this.customerEmail,
    this.assignedToId,
    this.assignedToName,
    this.resolution,
    this.resolvedAt,
    this.notes,
  });

  factory Complaint.fromJson(Map<String, dynamic> json) {
    return Complaint(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      type: json['type'] as String,
      subject: json['subject'] as String,
      description: json['description'] as String,
      status: json['status'] as String,
      priority: json['priority'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      customerName: json['customer_name'] as String?,
      customerEmail: json['customer_email'] as String?,
      assignedToId: json['assigned_to_id'] as int?,
      assignedToName: json['assigned_to_name'] as String?,
      resolution: json['resolution'] as String?,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'subject': subject,
      'description': description,
      'status': status,
      'priority': priority,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'customer_name': customerName,
      'customer_email': customerEmail,
      'assigned_to_id': assignedToId,
      'assigned_to_name': assignedToName,
      'resolution': resolution,
      'resolved_at': resolvedAt?.toIso8601String(),
      'notes': notes,
    };
  }

  Complaint copyWith({
    int? id,
    int? userId,
    String? type,
    String? subject,
    String? description,
    String? status,
    String? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? customerName,
    String? customerEmail,
    int? assignedToId,
    String? assignedToName,
    String? resolution,
    DateTime? resolvedAt,
    String? notes,
  }) {
    return Complaint(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customerName: customerName ?? this.customerName,
      customerEmail: customerEmail ?? this.customerEmail,
      assignedToId: assignedToId ?? this.assignedToId,
      assignedToName: assignedToName ?? this.assignedToName,
      resolution: resolution ?? this.resolution,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() {
    return 'Complaint(id: $id, type: $type, subject: $subject, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Complaint && other.id == id;
  }

  // Status constants
  static const String statusPending = 'pending';
  static const String statusInProgress = 'in_progress';
  static const String statusResolved = 'resolved';
  static const String statusClosed = 'closed';

  // Getters for convenience
  String get title => subject;
  String? get assignedTo => assignedToName;

  @override
  int get hashCode => id.hashCode;
}

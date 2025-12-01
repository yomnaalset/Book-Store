class Complaint {
  static const String statusNew = 'new';
  static const String statusUnderReview = 'under_review';
  static const String statusInProgress = 'in_progress';
  static const String statusResolved = 'resolved';
  static const String statusClosed = 'closed';
  static const String statusRejected = 'rejected';

  static const String typeComplaint = 'complaint';
  static const String typeFeedback = 'feedback';
  static const String typeSuggestion = 'suggestion';
  static const String typeBugReport = 'bug_report';
  static const String typeFeatureRequest = 'feature_request';

  static const String priorityLow = 'low';
  static const String priorityMedium = 'medium';
  static const String priorityHigh = 'high';
  static const String priorityUrgent = 'urgent';

  static const Map<String, String> statusLabels = {
    statusNew: 'New',
    statusUnderReview: 'Under Review',
    statusInProgress: 'In Progress',
    statusResolved: 'Resolved',
    statusClosed: 'Closed',
    statusRejected: 'Rejected',
  };

  static const Map<String, String> typeLabels = {
    typeComplaint: 'Complaint',
    typeFeedback: 'Feedback',
    typeSuggestion: 'Suggestion',
    typeBugReport: 'Bug Report',
    typeFeatureRequest: 'Feature Request',
  };

  static const Map<String, String> priorityLabels = {
    priorityLow: 'Low',
    priorityMedium: 'Medium',
    priorityHigh: 'High',
    priorityUrgent: 'Urgent',
  };

  final int? id;
  final String title;
  final String description;
  final String type;
  final String status;
  final String priority;
  final int customerId;
  final String customerName;
  final String customerEmail;
  final int? assignedTo;
  final String? assignedToName;
  final String? resolution;
  final DateTime? resolvedAt;
  final int? resolvedBy;
  final String? resolvedByName;
  final List<String>? attachments;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ComplaintResponse>? responses;

  Complaint({
    this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.status,
    required this.priority,
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    this.assignedTo,
    this.assignedToName,
    this.resolution,
    this.resolvedAt,
    this.resolvedBy,
    this.resolvedByName,
    this.attachments,
    required this.createdAt,
    required this.updatedAt,
    this.responses,
  });

  factory Complaint.fromJson(Map<String, dynamic> json) {
    return Complaint(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      type: json['type'] ?? typeComplaint,
      status: json['status'] ?? statusNew,
      priority: json['priority'] ?? priorityMedium,
      customerId: json['customer_id'] ?? json['customer']['id'],
      customerName: json['customer_name'] ?? json['customer']['name'] ?? '',
      customerEmail: json['customer_email'] ?? json['customer']['email'] ?? '',
      assignedTo: json['assigned_to'],
      assignedToName: json['assigned_to_name'],
      resolution: json['resolution'],
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'])
          : null,
      resolvedBy: json['resolved_by'],
      resolvedByName: json['resolved_by_name'],
      attachments: json['attachments'] != null
          ? List<String>.from(json['attachments'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      responses: json['responses'] != null
          ? (json['responses'] as List)
              .map((response) => ComplaintResponse.fromJson(response))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type,
      'status': status,
      'priority': priority,
      'customer_id': customerId,
      'assigned_to': assignedTo,
      'resolution': resolution,
      'resolved_at': resolvedAt?.toIso8601String(),
      'resolved_by': resolvedBy,
      'attachments': attachments,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get statusLabel {
    return statusLabels[status] ?? status;
  }

  String get typeLabel {
    return typeLabels[type] ?? type;
  }

  String get priorityLabel {
    return priorityLabels[priority] ?? priority;
  }

  bool get isOpen {
    return status != statusResolved && status != statusClosed && status != statusRejected;
  }

  bool get canBeAssigned {
    return status == statusNew || status == statusUnderReview;
  }

  bool get canBeResolved {
    return status == statusInProgress || status == statusUnderReview;
  }

  bool get canBeClosed {
    return status == statusResolved;
  }

  bool get canBeReopened {
    return status == statusClosed || status == statusRejected;
  }

  Duration get responseTime {
    if (responses == null || responses!.isEmpty) {
      return DateTime.now().difference(createdAt);
    }
    return responses!.first.createdAt.difference(createdAt);
  }

  Duration? get resolutionTime {
    if (resolvedAt == null) return null;
    return resolvedAt!.difference(createdAt);
  }

  Complaint copyWith({
    int? id,
    String? title,
    String? description,
    String? type,
    String? status,
    String? priority,
    int? customerId,
    String? customerName,
    String? customerEmail,
    int? assignedTo,
    String? assignedToName,
    String? resolution,
    DateTime? resolvedAt,
    int? resolvedBy,
    String? resolvedByName,
    List<String>? attachments,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ComplaintResponse>? responses,
  }) {
    return Complaint(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerEmail: customerEmail ?? this.customerEmail,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      resolution: resolution ?? this.resolution,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      resolvedByName: resolvedByName ?? this.resolvedByName,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      responses: responses ?? this.responses,
    );
  }
}

class ComplaintResponse {
  final int? id;
  final int complaintId;
  final String message;
  final int responderId;
  final String responderName;
  final String responderRole;
  final bool isInternal;
  final List<String>? attachments;
  final DateTime createdAt;
  final DateTime updatedAt;

  ComplaintResponse({
    this.id,
    required this.complaintId,
    required this.message,
    required this.responderId,
    required this.responderName,
    required this.responderRole,
    this.isInternal = false,
    this.attachments,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ComplaintResponse.fromJson(Map<String, dynamic> json) {
    return ComplaintResponse(
      id: json['id'],
      complaintId: json['complaint_id'],
      message: json['message'] ?? '',
      responderId: json['responder_id'] ?? json['responder']['id'],
      responderName: json['responder_name'] ?? json['responder']['name'] ?? '',
      responderRole: json['responder_role'] ?? json['responder']['user_type'] ?? '',
      isInternal: json['is_internal'] ?? false,
      attachments: json['attachments'] != null
          ? List<String>.from(json['attachments'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'complaint_id': complaintId,
      'message': message,
      'responder_id': responderId,
      'responder_role': responderRole,
      'is_internal': isInternal,
      'attachments': attachments,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isFromCustomer {
    return responderRole == 'customer';
  }

  bool get isFromAdmin {
    return responderRole == 'library_admin' || responderRole == 'delivery_admin';
  }
}

class ComplaintStatistics {
  final int totalComplaints;
  final int newComplaints;
  final int underReviewComplaints;
  final int inProgressComplaints;
  final int resolvedComplaints;
  final int closedComplaints;
  final int rejectedComplaints;
  final double averageResponseTime; // in hours
  final double averageResolutionTime; // in hours
  final Map<String, int> complaintsByType;
  final Map<String, int> complaintsByPriority;
  final DateTime periodStart;
  final DateTime periodEnd;

  ComplaintStatistics({
    required this.totalComplaints,
    required this.newComplaints,
    required this.underReviewComplaints,
    required this.inProgressComplaints,
    required this.resolvedComplaints,
    required this.closedComplaints,
    required this.rejectedComplaints,
    required this.averageResponseTime,
    required this.averageResolutionTime,
    required this.complaintsByType,
    required this.complaintsByPriority,
    required this.periodStart,
    required this.periodEnd,
  });

  factory ComplaintStatistics.fromJson(Map<String, dynamic> json) {
    return ComplaintStatistics(
      totalComplaints: json['total_complaints'] ?? 0,
      newComplaints: json['new_complaints'] ?? 0,
      underReviewComplaints: json['under_review_complaints'] ?? 0,
      inProgressComplaints: json['in_progress_complaints'] ?? 0,
      resolvedComplaints: json['resolved_complaints'] ?? 0,
      closedComplaints: json['closed_complaints'] ?? 0,
      rejectedComplaints: json['rejected_complaints'] ?? 0,
      averageResponseTime: double.tryParse(json['average_response_time']?.toString() ?? '0') ?? 0.0,
      averageResolutionTime: double.tryParse(json['average_resolution_time']?.toString() ?? '0') ?? 0.0,
      complaintsByType: Map<String, int>.from(json['complaints_by_type'] ?? {}),
      complaintsByPriority: Map<String, int>.from(json['complaints_by_priority'] ?? {}),
      periodStart: DateTime.parse(json['period_start']),
      periodEnd: DateTime.parse(json['period_end']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_complaints': totalComplaints,
      'new_complaints': newComplaints,
      'under_review_complaints': underReviewComplaints,
      'in_progress_complaints': inProgressComplaints,
      'resolved_complaints': resolvedComplaints,
      'closed_complaints': closedComplaints,
      'rejected_complaints': rejectedComplaints,
      'average_response_time': averageResponseTime,
      'average_resolution_time': averageResolutionTime,
      'complaints_by_type': complaintsByType,
      'complaints_by_priority': complaintsByPriority,
      'period_start': periodStart.toIso8601String(),
      'period_end': periodEnd.toIso8601String(),
    };
  }

  double get resolutionRate {
    if (totalComplaints == 0) return 0.0;
    return ((resolvedComplaints + closedComplaints) / totalComplaints) * 100;
  }

  int get openComplaints {
    return newComplaints + underReviewComplaints + inProgressComplaints;
  }
}
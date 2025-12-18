class Complaint {
  static const String statusNew = 'new';
  static const String statusUnderReview = 'under_review';
  static const String statusInProgress = 'in_progress';
  static const String statusResolved = 'resolved';
  static const String statusClosed = 'closed';
  static const String statusRejected = 'rejected';

  static const Map<String, String> statusLabels = {
    statusNew: 'New',
    statusUnderReview: 'Under Review',
    statusInProgress: 'In Progress',
    statusResolved: 'Resolved',
    statusClosed: 'Closed',
    statusRejected: 'Rejected',
  };

  final int? id;
  final String title;
  final String description;
  final String status;
  final int customerId;
  final String customerName;
  final String customerEmail;
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
    required this.status,
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    this.resolvedBy,
    this.resolvedByName,
    this.attachments,
    required this.createdAt,
    required this.updatedAt,
    this.responses,
  });

  factory Complaint.fromJson(Map<String, dynamic> json) {
    // Safely extract customer_id
    int? customerIdValue;
    if (json['customer_id'] != null) {
      customerIdValue = json['customer_id'] is int
          ? json['customer_id'] as int
          : int.tryParse(json['customer_id'].toString());
    } else if (json['customer'] != null) {
      if (json['customer'] is Map) {
        final customer = json['customer'] as Map<String, dynamic>;
        if (customer['id'] != null) {
          customerIdValue = customer['id'] is int
              ? customer['id'] as int
              : int.tryParse(customer['id'].toString());
        }
      } else if (json['customer'] is int) {
        customerIdValue = json['customer'] as int;
      }
    }

    if (customerIdValue == null) {
      throw Exception(
        'customer_id is required but was null in response. JSON keys: ${json.keys.toList()}',
      );
    }

    return Complaint(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? statusNew,
      customerId: customerIdValue,
      customerName:
          json['customer_name'] ??
          (json['customer'] != null && json['customer'] is Map
              ? (json['customer'] as Map)['name'] ?? ''
              : ''),
      customerEmail:
          json['customer_email'] ??
          (json['customer'] != null && json['customer'] is Map
              ? (json['customer'] as Map)['email'] ?? ''
              : ''),
      resolvedBy: json['resolved_by'],
      resolvedByName: json['resolved_by_name'],
      attachments: json['attachments'] != null
          ? List<String>.from(json['attachments'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
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
      'status': status,
      'customer_id': customerId,
      'resolved_by': resolvedBy,
      'attachments': attachments,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get statusLabel {
    return statusLabels[status] ?? status;
  }

  bool get isOpen {
    return status != statusResolved &&
        status != statusClosed &&
        status != statusRejected;
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

  Complaint copyWith({
    int? id,
    String? title,
    String? description,
    String? type,
    String? status,
    int? customerId,
    String? customerName,
    String? customerEmail,
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
      status: status ?? this.status,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerEmail: customerEmail ?? this.customerEmail,
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
    // Safely extract complaint_id
    int? complaintIdValue;
    if (json['complaint_id'] != null) {
      complaintIdValue = json['complaint_id'] is int
          ? json['complaint_id'] as int
          : int.tryParse(json['complaint_id'].toString());
    } else if (json['complaint'] != null) {
      if (json['complaint'] is Map) {
        final complaint = json['complaint'] as Map<String, dynamic>;
        if (complaint['id'] != null) {
          complaintIdValue = complaint['id'] is int
              ? complaint['id'] as int
              : int.tryParse(complaint['id'].toString());
        }
      } else if (json['complaint'] is int) {
        complaintIdValue = json['complaint'] as int;
      }
    }

    if (complaintIdValue == null) {
      throw Exception(
        'complaint_id is required but was null in response. JSON keys: ${json.keys.toList()}',
      );
    }

    // Safely extract responder_id
    int? responderIdValue;
    if (json['responder_id'] != null) {
      responderIdValue = json['responder_id'] is int
          ? json['responder_id'] as int
          : int.tryParse(json['responder_id'].toString());
    } else if (json['responder'] != null) {
      if (json['responder'] is Map) {
        final responder = json['responder'] as Map<String, dynamic>;
        if (responder['id'] != null) {
          responderIdValue = responder['id'] is int
              ? responder['id'] as int
              : int.tryParse(responder['id'].toString());
        }
      } else if (json['responder'] is int) {
        responderIdValue = json['responder'] as int;
      }
    }

    if (responderIdValue == null) {
      throw Exception(
        'responder_id is required but was null in response. JSON keys: ${json.keys.toList()}',
      );
    }

    return ComplaintResponse(
      id: json['id'],
      complaintId: complaintIdValue,
      message: json['message'] ?? json['response_text'] ?? '',
      responderId: responderIdValue,
      responderName:
          json['responder_name'] ??
          (json['responder'] != null && json['responder'] is Map
              ? (json['responder'] as Map)['name'] ?? ''
              : ''),
      responderRole:
          json['responder_role'] ??
          (json['responder'] != null && json['responder'] is Map
              ? (json['responder'] as Map)['user_type'] ?? ''
              : ''),
      isInternal: json['is_internal'] ?? false,
      attachments: json['attachments'] != null
          ? List<String>.from(json['attachments'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
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
    return responderRole == 'library_admin' ||
        responderRole == 'delivery_admin';
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
      averageResponseTime:
          double.tryParse(json['average_response_time']?.toString() ?? '0') ??
          0.0,
      averageResolutionTime:
          double.tryParse(json['average_resolution_time']?.toString() ?? '0') ??
          0.0,
      complaintsByType: Map<String, int>.from(json['complaints_by_type'] ?? {}),
      complaintsByPriority: Map<String, int>.from(
        json['complaints_by_priority'] ?? {},
      ),
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

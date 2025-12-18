class CustomerComplaint {
  final int id;
  final String complaintId;
  final String message; // Backend: description
  final String status; // Backend: status (open, in_progress, resolved, closed)
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? title; // Backend: title
  final String complaintType; // Backend: complaint_type ('app' or 'delivery')
  final List<CustomerComplaintResponse>? responses; // Admin responses

  // Status mapping: Frontend -> Backend
  static const String statusPending = 'pending'; // Maps to 'open'
  static const String statusUnderReview =
      'under_review'; // Maps to 'in_progress'
  static const String statusResolved = 'resolved';

  static const Map<String, String> statusLabels = {
    statusPending: 'Pending',
    statusUnderReview: 'Under Review',
    statusResolved: 'Resolved',
  };

  // Complaint type constants
  static const String typeApp = 'app';
  static const String typeDelivery = 'delivery';

  static const Map<String, String> typeLabels = {
    typeApp: 'App-related',
    typeDelivery: 'Delivery service-related',
  };

  CustomerComplaint({
    required this.id,
    required this.complaintId,
    required this.message,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.title,
    this.complaintType = typeApp,
    this.responses,
  });

  factory CustomerComplaint.fromJson(Map<String, dynamic> json) {
    return CustomerComplaint(
      id: json['id'] as int,
      complaintId: json['complaint_id'] as String? ?? '',
      message:
          json['description'] as String? ?? json['message'] as String? ?? '',
      status: mapBackendStatusToFrontend(json['status'] as String? ?? 'open'),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      title: json['title'] as String?,
      complaintType: json['complaint_type'] as String? ?? typeApp,
      responses: json['responses'] != null
          ? (json['responses'] as List)
                .map((response) => CustomerComplaintResponse.fromJson(response))
                .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'complaint_id': complaintId,
      'description': message,
      'status': mapFrontendStatusToBackend(status),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (title != null) 'title': title,
      'complaint_type': complaintType,
    };
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'title': title ?? 'Complaint',
      'description': message,
      'complaint_type': complaintType,
    };
  }

  CustomerComplaint copyWith({
    int? id,
    String? complaintId,
    String? message,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? title,
    String? complaintType,
    List<CustomerComplaintResponse>? responses,
  }) {
    return CustomerComplaint(
      id: id ?? this.id,
      complaintId: complaintId ?? this.complaintId,
      message: message ?? this.message,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      title: title ?? this.title,
      complaintType: complaintType ?? this.complaintType,
      responses: responses ?? this.responses,
    );
  }

  // Helper methods for status mapping
  static String mapBackendStatusToFrontend(String backendStatus) {
    switch (backendStatus) {
      case 'open':
        return statusPending;
      case 'in_progress':
        return statusUnderReview;
      case 'resolved':
      case 'closed':
        return statusResolved;
      default:
        return statusPending;
    }
  }

  static String mapFrontendStatusToBackend(String frontendStatus) {
    switch (frontendStatus) {
      case statusPending:
        return 'open';
      case statusUnderReview:
        return 'in_progress';
      case statusResolved:
        return 'resolved';
      default:
        return 'open';
    }
  }

  // Check if complaint can be edited (only if pending)
  bool get canEdit => status == statusPending;

  // Get display label for status
  String get statusLabel => statusLabels[status] ?? 'Pending';
}

class CustomerComplaintResponse {
  final int id;
  final String response; // Backend: response_text
  final String responderName; // Backend: responder_name
  final DateTime createdAt;

  CustomerComplaintResponse({
    required this.id,
    required this.response,
    required this.responderName,
    required this.createdAt,
  });

  factory CustomerComplaintResponse.fromJson(Map<String, dynamic> json) {
    return CustomerComplaintResponse(
      id: json['id'] as int,
      response:
          json['response_text'] as String? ?? json['response'] as String? ?? '',
      responderName: json['responder_name'] as String? ?? 'Admin',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'response_text': response,
      'responder_name': responderName,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

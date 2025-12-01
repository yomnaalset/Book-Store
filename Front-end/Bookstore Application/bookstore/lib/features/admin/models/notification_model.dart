class NotificationModel {
  final String? id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? data;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.data,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    // Safely parse the created_at date
    DateTime createdAt;
    try {
      final createdAtStr = json['created_at']?.toString();
      if (createdAtStr != null && createdAtStr.isNotEmpty) {
        createdAt = DateTime.parse(createdAtStr);
      } else {
        createdAt = DateTime.now();
      }
    } catch (e) {
      // If parsing fails, use current time as fallback
      createdAt = DateTime.now();
    }

    return NotificationModel(
      id: json['id']?.toString(),
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      type: (json['notification_type'] ?? json['type'] ?? 'system').toString(),
      isRead:
          json['is_read'] == true ||
          json['is_read'] == 'true' ||
          json['is_read'] == 1,
      createdAt: createdAt,
      data: json['data'] is Map<String, dynamic> ? json['data'] : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'data': data,
    };
  }
}

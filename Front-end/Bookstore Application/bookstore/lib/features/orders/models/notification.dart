class NotificationModel {
  static const String typeNewBorrowRequest = 'new_borrow_request';
  static const String typeExtensionRequest = 'extension_request';
  static const String typeOverdueBorrow = 'overdue_borrow';
  static const String typeFineGenerated = 'fine_generated';
  static const String typeFinePaid = 'fine_paid';
  static const String typeDeliveryAssigned = 'delivery_assigned';
  static const String typeDeliveryCompleted = 'delivery_completed';
  static const String typeReturnRequested = 'return_requested';
  static const String typeBookReturned = 'book_returned';
  static const String typeNewComplaint = 'new_complaint';
  static const String typeComplaintResolved = 'complaint_resolved';
  static const String typeNewOrder = 'new_order';
  static const String typeOrderCancelled = 'order_cancelled';
  static const String typeSystemAlert = 'system_alert';
  static const String typePromotion = 'promotion';
  static const String typeReminder = 'reminder';

  static const String priorityLow = 'low';
  static const String priorityMedium = 'medium';
  static const String priorityHigh = 'high';
  static const String priorityUrgent = 'urgent';

  static const Map<String, String> typeLabels = {
    typeNewBorrowRequest: 'New Borrow Request',
    typeExtensionRequest: 'Extension Request',
    typeOverdueBorrow: 'Overdue Borrow',
    typeFineGenerated: 'Fine Generated',
    typeFinePaid: 'Fine Paid',
    typeDeliveryAssigned: 'Delivery Assigned',
    typeDeliveryCompleted: 'Delivery Completed',
    typeReturnRequested: 'Return Requested',
    typeBookReturned: 'Book Returned',
    typeNewComplaint: 'New Complaint',
    typeComplaintResolved: 'Complaint Resolved',
    typeNewOrder: 'New Order',
    typeOrderCancelled: 'Order Cancelled',
    typeSystemAlert: 'System Alert',
    typePromotion: 'Promotion',
    typeReminder: 'Reminder',
  };

  static const Map<String, String> priorityLabels = {
    priorityLow: 'Low',
    priorityMedium: 'Medium',
    priorityHigh: 'High',
    priorityUrgent: 'Urgent',
  };

  final int? id;
  final String title;
  final String message;
  final String type;
  final String priority;
  final int recipientId;
  final String recipientRole;
  final bool isRead;
  final Map<String, dynamic>? data;
  final String? actionUrl;
  final DateTime? readAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  NotificationModel({
    this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.priority,
    required this.recipientId,
    required this.recipientRole,
    this.isRead = false,
    this.data,
    this.actionUrl,
    this.readAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? typeSystemAlert,
      priority: json['priority'] ?? priorityMedium,
      recipientId: json['recipient_id'],
      recipientRole: json['recipient_role'] ?? '',
      isRead: json['is_read'] ?? false,
      data: json['data'] != null ? Map<String, dynamic>.from(json['data']) : null,
      actionUrl: json['action_url'],
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'priority': priority,
      'recipient_id': recipientId,
      'recipient_role': recipientRole,
      'is_read': isRead,
      'data': data,
      'action_url': actionUrl,
      'read_at': readAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get typeLabel {
    return typeLabels[type] ?? type;
  }

  String get priorityLabel {
    return priorityLabels[priority] ?? priority;
  }

  bool get isUrgent {
    return priority == priorityUrgent;
  }

  bool get isHigh {
    return priority == priorityHigh;
  }

  bool get hasAction {
    return actionUrl != null && actionUrl!.isNotEmpty;
  }

  Duration get age {
    return DateTime.now().difference(createdAt);
  }

  String get timeAgo {
    final duration = age;
    
    if (duration.inDays > 0) {
      return '${duration.inDays}d ago';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ago';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  NotificationModel copyWith({
    int? id,
    String? title,
    String? message,
    String? type,
    String? priority,
    int? recipientId,
    String? recipientRole,
    bool? isRead,
    Map<String, dynamic>? data,
    String? actionUrl,
    DateTime? readAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      recipientId: recipientId ?? this.recipientId,
      recipientRole: recipientRole ?? this.recipientRole,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
      actionUrl: actionUrl ?? this.actionUrl,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  NotificationModel markAsRead() {
    return copyWith(
      isRead: true,
      readAt: DateTime.now(),
    );
  }
}

class NotificationFilter {
  final String? type;
  final String? priority;
  final bool? isRead;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? search;

  NotificationFilter({
    this.type,
    this.priority,
    this.isRead,
    this.startDate,
    this.endDate,
    this.search,
  });

  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{};
    
    if (type != null) params['type'] = type;
    if (priority != null) params['priority'] = priority;
    if (isRead != null) params['is_read'] = isRead;
    if (startDate != null) params['start_date'] = startDate!.toIso8601String().split('T')[0];
    if (endDate != null) params['end_date'] = endDate!.toIso8601String().split('T')[0];
    if (search != null && search!.isNotEmpty) params['search'] = search;
    
    return params;
  }

  NotificationFilter copyWith({
    String? type,
    String? priority,
    bool? isRead,
    DateTime? startDate,
    DateTime? endDate,
    String? search,
  }) {
    return NotificationFilter(
      type: type ?? this.type,
      priority: priority ?? this.priority,
      isRead: isRead ?? this.isRead,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      search: search ?? this.search,
    );
  }

  bool get hasActiveFilters {
    return type != null ||
           priority != null ||
           isRead != null ||
           startDate != null ||
           endDate != null ||
           (search != null && search!.isNotEmpty);
  }

  NotificationFilter clear() {
    return NotificationFilter();
  }
}

class NotificationStatistics {
  final int totalNotifications;
  final int unreadNotifications;
  final int readNotifications;
  final Map<String, int> notificationsByType;
  final Map<String, int> notificationsByPriority;
  final double averageReadTime; // in hours
  final DateTime periodStart;
  final DateTime periodEnd;

  NotificationStatistics({
    required this.totalNotifications,
    required this.unreadNotifications,
    required this.readNotifications,
    required this.notificationsByType,
    required this.notificationsByPriority,
    required this.averageReadTime,
    required this.periodStart,
    required this.periodEnd,
  });

  factory NotificationStatistics.fromJson(Map<String, dynamic> json) {
    return NotificationStatistics(
      totalNotifications: json['total_notifications'] ?? 0,
      unreadNotifications: json['unread_notifications'] ?? 0,
      readNotifications: json['read_notifications'] ?? 0,
      notificationsByType: Map<String, int>.from(json['notifications_by_type'] ?? {}),
      notificationsByPriority: Map<String, int>.from(json['notifications_by_priority'] ?? {}),
      averageReadTime: double.tryParse(json['average_read_time']?.toString() ?? '0') ?? 0.0,
      periodStart: DateTime.parse(json['period_start']),
      periodEnd: DateTime.parse(json['period_end']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_notifications': totalNotifications,
      'unread_notifications': unreadNotifications,
      'read_notifications': readNotifications,
      'notifications_by_type': notificationsByType,
      'notifications_by_priority': notificationsByPriority,
      'average_read_time': averageReadTime,
      'period_start': periodStart.toIso8601String(),
      'period_end': periodEnd.toIso8601String(),
    };
  }

  double get readRate {
    if (totalNotifications == 0) return 0.0;
    return (readNotifications / totalNotifications) * 100;
  }

  int get urgentNotifications {
    return notificationsByPriority[NotificationModel.priorityUrgent] ?? 0;
  }

  int get highPriorityNotifications {
    return notificationsByPriority[NotificationModel.priorityHigh] ?? 0;
  }
}

class NotificationSettings {
  final bool emailNotifications;
  final bool pushNotifications;
  final bool borrowRequestNotifications;
  final bool extensionRequestNotifications;
  final bool overdueNotifications;
  final bool fineNotifications;
  final bool deliveryNotifications;
  final bool complaintNotifications;
  final bool systemAlertNotifications;
  final bool promotionNotifications;
  final String quietHoursStart;
  final String quietHoursEnd;
  final bool weekendNotifications;

  NotificationSettings({
    this.emailNotifications = true,
    this.pushNotifications = true,
    this.borrowRequestNotifications = true,
    this.extensionRequestNotifications = true,
    this.overdueNotifications = true,
    this.fineNotifications = true,
    this.deliveryNotifications = true,
    this.complaintNotifications = true,
    this.systemAlertNotifications = true,
    this.promotionNotifications = false,
    this.quietHoursStart = '22:00',
    this.quietHoursEnd = '08:00',
    this.weekendNotifications = false,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      emailNotifications: json['email_notifications'] ?? true,
      pushNotifications: json['push_notifications'] ?? true,
      borrowRequestNotifications: json['borrow_request_notifications'] ?? true,
      extensionRequestNotifications: json['extension_request_notifications'] ?? true,
      overdueNotifications: json['overdue_notifications'] ?? true,
      fineNotifications: json['fine_notifications'] ?? true,
      deliveryNotifications: json['delivery_notifications'] ?? true,
      complaintNotifications: json['complaint_notifications'] ?? true,
      systemAlertNotifications: json['system_alert_notifications'] ?? true,
      promotionNotifications: json['promotion_notifications'] ?? false,
      quietHoursStart: json['quiet_hours_start'] ?? '22:00',
      quietHoursEnd: json['quiet_hours_end'] ?? '08:00',
      weekendNotifications: json['weekend_notifications'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email_notifications': emailNotifications,
      'push_notifications': pushNotifications,
      'borrow_request_notifications': borrowRequestNotifications,
      'extension_request_notifications': extensionRequestNotifications,
      'overdue_notifications': overdueNotifications,
      'fine_notifications': fineNotifications,
      'delivery_notifications': deliveryNotifications,
      'complaint_notifications': complaintNotifications,
      'system_alert_notifications': systemAlertNotifications,
      'promotion_notifications': promotionNotifications,
      'quiet_hours_start': quietHoursStart,
      'quiet_hours_end': quietHoursEnd,
      'weekend_notifications': weekendNotifications,
    };
  }

  NotificationSettings copyWith({
    bool? emailNotifications,
    bool? pushNotifications,
    bool? borrowRequestNotifications,
    bool? extensionRequestNotifications,
    bool? overdueNotifications,
    bool? fineNotifications,
    bool? deliveryNotifications,
    bool? complaintNotifications,
    bool? systemAlertNotifications,
    bool? promotionNotifications,
    String? quietHoursStart,
    String? quietHoursEnd,
    bool? weekendNotifications,
  }) {
    return NotificationSettings(
      emailNotifications: emailNotifications ?? this.emailNotifications,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      borrowRequestNotifications: borrowRequestNotifications ?? this.borrowRequestNotifications,
      extensionRequestNotifications: extensionRequestNotifications ?? this.extensionRequestNotifications,
      overdueNotifications: overdueNotifications ?? this.overdueNotifications,
      fineNotifications: fineNotifications ?? this.fineNotifications,
      deliveryNotifications: deliveryNotifications ?? this.deliveryNotifications,
      complaintNotifications: complaintNotifications ?? this.complaintNotifications,
      systemAlertNotifications: systemAlertNotifications ?? this.systemAlertNotifications,
      promotionNotifications: promotionNotifications ?? this.promotionNotifications,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      weekendNotifications: weekendNotifications ?? this.weekendNotifications,
    );
  }
}
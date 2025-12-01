class Ad {
  final String id;
  final String title;
  final String? content;
  final String? imageUrl;
  final String status; // 'active', 'inactive', 'scheduled', 'expired'
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdById;
  final String? adType; // Type of advertisement: 'general' or 'discount_code'
  final String? discountCode; // Optional discount code for special offers

  // Status constants
  static const String statusInactive = 'inactive';
  static const String statusActive = 'active';
  static const String statusScheduled = 'scheduled';
  static const String statusExpired = 'expired';

  // Ad type constants
  static const String adTypeGeneral = 'general';
  static const String adTypeDiscountCode = 'discount_code';

  Ad({
    required this.id,
    required this.title,
    this.content,
    this.imageUrl,
    required this.status,
    this.startDate,
    this.endDate,
    required this.createdAt,
    required this.updatedAt,
    required this.createdById,
    this.adType,
    this.discountCode,
  });

  factory Ad.fromJson(Map<String, dynamic> json) {
    return Ad(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      content: json['content'],
      imageUrl: json['image_url'] ?? json['image'],
      status: json['status'] ?? statusInactive,
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'])
          : null,
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      createdById:
          json['created_by']?.toString() ??
          json['created_by_id']?.toString() ??
          '',
      adType: json['ad_type'] ?? json['adType'],
      discountCode: json['discount_code'] ?? json['discountCode'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'image': imageUrl,
      'status': status,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by_id': createdById,
      'ad_type': adType,
      'discount_code': discountCode,
    };
  }

  Ad copyWith({
    String? id,
    String? title,
    String? content,
    String? imageUrl,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdById,
    String? adType,
    String? discountCode,
  }) {
    return Ad(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdById: createdById ?? this.createdById,
      adType: adType ?? this.adType,
      discountCode: discountCode ?? this.discountCode,
    );
  }

  // Helper methods
  bool get isCurrentlyActive {
    if (status != statusActive) return false;

    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;

    return true;
  }

  bool get isExpired {
    return endDate != null && DateTime.now().isAfter(endDate!);
  }

  bool get isScheduled {
    return startDate != null && DateTime.now().isBefore(startDate!);
  }

  // Check if this advertisement contains a discount code
  bool get hasDiscountCode {
    return discountCode != null && discountCode!.isNotEmpty;
  }

  // Ad type helpers
  bool get isGeneralAd => adType == null || adType == adTypeGeneral;
  bool get isDiscountCodeAd => adType == adTypeDiscountCode;

  String get adTypeDisplayName {
    if (adType == adTypeDiscountCode) return 'Discount Code Ad';
    return 'General Ad';
  }
}

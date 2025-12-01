import 'package:json_annotation/json_annotation.dart';

part 'ad.g.dart';

@JsonSerializable()
class Ad {
  final int id;
  final String title;
  final String? imageUrl;
  final String status;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? content;
  final String? adType; // Type of advertisement: 'general' or 'discount_code'
  final String? discountCode; // Optional discount code for special offers

  // Status constants (aligned with backend)
  static const String statusDraft = 'inactive';
  static const String statusPublished = 'active';
  static const String statusUnpublished = 'inactive';
  static const String statusExpired = 'expired';
  static const String statusScheduled = 'scheduled';

  // Ad type constants
  static const String adTypeGeneral = 'general';
  static const String adTypeDiscountCode = 'discount_code';

  Ad({
    required this.id,
    required this.title,
    this.imageUrl,
    required this.status,
    this.startDate,
    this.endDate,
    this.createdAt,
    this.updatedAt,
    this.content,
    this.adType,
    this.discountCode,
  });

  factory Ad.fromJson(Map<String, dynamic> json) {
    // Handle field mapping from backend
    final mappedJson = Map<String, dynamic>.from(json);

    // Map image fields (prioritize image_url over image)
    if (mappedJson.containsKey('image_url') &&
        mappedJson['image_url'] != null) {
      mappedJson['imageUrl'] = mappedJson['image_url'];
    } else if (mappedJson.containsKey('image') && mappedJson['image'] != null) {
      mappedJson['imageUrl'] = mappedJson['image'];
    }

    // Map date fields
    if (mappedJson.containsKey('start_date') &&
        !mappedJson.containsKey('startDate')) {
      mappedJson['startDate'] = mappedJson['start_date'];
    }
    if (mappedJson.containsKey('end_date') &&
        !mappedJson.containsKey('endDate')) {
      mappedJson['endDate'] = mappedJson['end_date'];
    }
    if (mappedJson.containsKey('created_at') &&
        !mappedJson.containsKey('createdAt')) {
      mappedJson['createdAt'] = mappedJson['created_at'];
    }
    if (mappedJson.containsKey('updated_at') &&
        !mappedJson.containsKey('updatedAt')) {
      mappedJson['updatedAt'] = mappedJson['updated_at'];
    }
    if (mappedJson.containsKey('ad_type') &&
        !mappedJson.containsKey('adType')) {
      mappedJson['adType'] = mappedJson['ad_type'];
    }
    if (mappedJson.containsKey('discount_code') &&
        !mappedJson.containsKey('discountCode')) {
      mappedJson['discountCode'] = mappedJson['discount_code'];
    }

    // Handle missing updated_at field (backend list serializer doesn't include it)
    if (!mappedJson.containsKey('updatedAt') &&
        mappedJson.containsKey('createdAt')) {
      // Use createdAt as fallback for updatedAt if not provided
      mappedJson['updatedAt'] = mappedJson['createdAt'];
    }

    return _$AdFromJson(mappedJson);
  }

  Map<String, dynamic> toJson({bool includeId = false}) {
    final json = _$AdToJson(this);

    // Map frontend fields to backend fields
    if (json.containsKey('imageUrl')) {
      if (json['imageUrl'] != null) {
        json['image'] = json['imageUrl'];
      }
      json.remove('imageUrl');
    }
    if (json.containsKey('startDate')) {
      json['start_date'] = json['startDate'];
      json.remove('startDate');
    }
    if (json.containsKey('endDate')) {
      json['end_date'] = json['endDate'];
      json.remove('endDate');
    }
    if (json.containsKey('adType')) {
      json['ad_type'] = json['adType'];
      json.remove('adType');
    }
    if (json.containsKey('discountCode')) {
      json['discount_code'] = json['discountCode'];
      json.remove('discountCode');
    }

    // Remove fields that shouldn't be sent to create endpoint
    // Only remove id if this is for creation (not update)
    if (!includeId) {
      json.remove('id');
    }
    if (json.containsKey('createdAt')) json.remove('createdAt');
    if (json.containsKey('updatedAt')) json.remove('updatedAt');

    return json;
  }

  Ad copyWith({
    int? id,
    String? title,
    String? imageUrl,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? content,
    String? adType,
    String? discountCode,
  }) {
    return Ad(
      id: id ?? this.id,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      content: content ?? this.content,
      adType: adType ?? this.adType,
      discountCode: discountCode ?? this.discountCode,
    );
  }

  bool get isPublished => status == statusPublished;
  bool get isDraft => status == statusDraft;
  bool get isExpired => status == statusExpired;
  bool get isActive =>
      isPublished && (endDate == null || endDate!.isAfter(DateTime.now()));

  // Check if this advertisement contains a discount code
  bool get hasDiscountCode {
    return discountCode != null && discountCode!.isNotEmpty;
  }

  // Ad type helpers
  bool get isGeneralAd => adType == null || adType == adTypeGeneral;
  bool get isDiscountCodeAd => adType == adTypeDiscountCode;

  // Status labels
  Map<String, String> get statusLabels => {
    statusDraft: 'Draft',
    statusPublished: 'Active',
    statusExpired: 'Expired',
    statusScheduled: 'Scheduled',
  };

  // Ad type labels
  Map<String, String> get adTypeLabels => {
    adTypeGeneral: 'General Advertisement',
    adTypeDiscountCode: 'Discount Code Advertisement',
  };

  String get adTypeDisplayName {
    return adTypeLabels[adType ?? adTypeGeneral] ?? 'General Advertisement';
  }
}

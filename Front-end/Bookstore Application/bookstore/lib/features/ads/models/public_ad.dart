import 'package:json_annotation/json_annotation.dart';

part 'public_ad.g.dart';

@JsonSerializable()
class PublicAd {
  final int id;
  final String title;
  final String content;
  final String? imageUrl;
  final String adType;
  final String? discountCode;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final DateTime createdAt;

  // Status constants
  static const String statusActive = 'active';
  static const String statusInactive = 'inactive';
  static const String statusScheduled = 'scheduled';
  static const String statusExpired = 'expired';

  // Ad type constants
  static const String adTypeGeneral = 'general';
  static const String adTypeDiscountCode = 'discount_code';

  PublicAd({
    required this.id,
    required this.title,
    required this.content,
    this.imageUrl,
    required this.adType,
    this.discountCode,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.createdAt,
  });

  factory PublicAd.fromJson(Map<String, dynamic> json) {
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
    if (mappedJson.containsKey('ad_type') &&
        !mappedJson.containsKey('adType')) {
      mappedJson['adType'] = mappedJson['ad_type'];
    }
    if (mappedJson.containsKey('discount_code') &&
        !mappedJson.containsKey('discountCode')) {
      mappedJson['discountCode'] = mappedJson['discount_code'];
    }

    return _$PublicAdFromJson(mappedJson);
  }

  Map<String, dynamic> toJson() => _$PublicAdToJson(this);

  PublicAd copyWith({
    int? id,
    String? title,
    String? content,
    String? imageUrl,
    String? adType,
    String? discountCode,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    DateTime? createdAt,
  }) {
    return PublicAd(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      adType: adType ?? this.adType,
      discountCode: discountCode ?? this.discountCode,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Helper methods
  bool get isActive => status == statusActive;
  bool get isExpired =>
      status == statusExpired || endDate.isBefore(DateTime.now());
  bool get isScheduled => status == statusScheduled;
  bool get isInactive => status == statusInactive;

  bool get hasDiscountCode => discountCode != null && discountCode!.isNotEmpty;
  bool get isGeneralAd => adType == adTypeGeneral;
  bool get isDiscountCodeAd => adType == adTypeDiscountCode;

  // Status labels
  Map<String, String> get statusLabels => {
    statusActive: 'Active',
    statusInactive: 'Inactive',
    statusScheduled: 'Scheduled',
    statusExpired: 'Expired',
  };

  // Ad type labels
  Map<String, String> get adTypeLabels => {
    adTypeGeneral: 'General Advertisement',
    adTypeDiscountCode: 'Discount Code Advertisement',
  };

  String get statusDisplayName {
    return statusLabels[status] ?? 'Unknown';
  }

  String get adTypeDisplayName {
    return adTypeLabels[adType] ?? 'General Advertisement';
  }

  // Check if the ad is currently visible to users
  bool get isVisible {
    return isActive && !isExpired;
  }

  // Get remaining time until expiration
  Duration? get timeUntilExpiration {
    if (isExpired) return null;
    return endDate.difference(DateTime.now());
  }

  // Format remaining time as a readable string
  String get timeUntilExpirationText {
    final duration = timeUntilExpiration;
    if (duration == null) return 'Expired';

    if (duration.inDays > 0) {
      return '${duration.inDays} day${duration.inDays == 1 ? '' : 's'} left';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hour${duration.inHours == 1 ? '' : 's'} left';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes} minute${duration.inMinutes == 1 ? '' : 's'} left';
    } else {
      return 'Expires soon';
    }
  }
}

class Discount {
  final String id;
  final String code;
  final String title;
  final String? description;
  final String type; // 'percentage', 'fixed_amount'
  final double value; // percentage (0-100) or fixed amount
  final double? minimumAmount;
  final double? maximumDiscount;
  final int? usageLimit;
  final int? usageCount;
  final bool isActive;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String>? applicableCategories;
  final List<String>? applicableBooks;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Type constants
  static const String typePercentage = 'percentage';
  static const String typeFixedAmount = 'fixed_amount';

  Discount({
    required this.id,
    required this.code,
    required this.title,
    this.description,
    required this.type,
    required this.value,
    this.minimumAmount,
    this.maximumDiscount,
    this.usageLimit,
    this.usageCount = 0,
    this.isActive = true,
    this.startDate,
    this.endDate,
    this.applicableCategories,
    this.applicableBooks,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Discount.fromJson(Map<String, dynamic> json) {
    return Discount(
      id: json['id']?.toString() ?? '',
      code: json['code'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      type: json['type'] ?? typePercentage,
      value: json['value'] != null
          ? double.tryParse(json['value'].toString()) ?? 0.0
          : json['discount_percentage'] != null
          ? double.tryParse(json['discount_percentage'].toString()) ?? 0.0
          : 0.0,
      minimumAmount: json['minimumAmount'] != null
          ? double.tryParse(json['minimumAmount'].toString())
          : json['minimum_amount'] != null
          ? double.tryParse(json['minimum_amount'].toString())
          : null,
      maximumDiscount: json['maximumDiscount'] != null
          ? double.tryParse(json['maximumDiscount'].toString())
          : json['maximum_discount'] != null
          ? double.tryParse(json['maximum_discount'].toString())
          : null,
      usageLimit:
          json['usageLimit'] ??
          json['usage_limit'] ??
          json['usage_limit_per_customer'],
      usageCount: json['usageCount'] ?? json['usage_count'] ?? 0,
      isActive: json['isActive'] ?? json['is_active'] ?? true,
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'])
          : json['start_date'] != null
          ? DateTime.parse(json['start_date'])
          : null,
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'])
          : json['end_date'] != null
          ? DateTime.parse(json['end_date'])
          : json['expiration_date'] != null
          ? DateTime.parse(json['expiration_date'])
          : null,
      applicableCategories: json['applicableCategories'] != null
          ? List<String>.from(json['applicableCategories'])
          : json['applicable_categories'] != null
          ? List<String>.from(json['applicable_categories'])
          : null,
      applicableBooks: json['applicableBooks'] != null
          ? List<String>.from(json['applicableBooks'])
          : json['applicable_books'] != null
          ? List<String>.from(json['applicable_books'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'discount_percentage': value, // Backend field name
      'usage_limit_per_customer': usageLimit, // Backend field name
      'expiration_date': endDate != null
          ? '${endDate!.toIso8601String().split('.')[0]}Z'
          : null, // Backend field name - format for Django
      'is_active': isActive, // Backend field name
    };
  }

  Discount copyWith({
    String? id,
    String? code,
    String? title,
    String? description,
    String? type,
    double? value,
    double? minimumAmount,
    double? maximumDiscount,
    int? usageLimit,
    int? usageCount,
    bool? isActive,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? applicableCategories,
    List<String>? applicableBooks,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Discount(
      id: id ?? this.id,
      code: code ?? this.code,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      value: value ?? this.value,
      minimumAmount: minimumAmount ?? this.minimumAmount,
      maximumDiscount: maximumDiscount ?? this.maximumDiscount,
      usageLimit: usageLimit ?? this.usageLimit,
      usageCount: usageCount ?? this.usageCount,
      isActive: isActive ?? this.isActive,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      applicableCategories: applicableCategories ?? this.applicableCategories,
      applicableBooks: applicableBooks ?? this.applicableBooks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Compatibility getters for different naming conventions
  double get percentage => type == typePercentage ? value : 0.0;
  double get discountPercentage => percentage;

  DateTime? get expirationDate => endDate;

  int? get maxUsesPerCustomer => usageLimit;
  int? get usageLimitPerCustomer => usageLimit;

  bool get discountIsActive => isActive;

  // Helper methods
  bool get isCurrentlyValid {
    if (!isActive) return false;

    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;

    if (usageLimit != null && (usageCount ?? 0) >= usageLimit!) return false;

    return true;
  }

  bool get isExpired {
    return endDate != null && DateTime.now().isAfter(endDate!);
  }

  bool get isUsageLimitReached {
    return usageLimit != null && (usageCount ?? 0) >= usageLimit!;
  }

  double calculateDiscount(double amount) {
    if (!isCurrentlyValid) return 0.0;
    if (minimumAmount != null && amount < minimumAmount!) return 0.0;

    double discount = 0.0;

    if (type == typePercentage) {
      discount = amount * (value / 100);
    } else if (type == typeFixedAmount) {
      discount = value;
    }

    if (maximumDiscount != null && discount > maximumDiscount!) {
      discount = maximumDiscount!;
    }

    return discount;
  }
}

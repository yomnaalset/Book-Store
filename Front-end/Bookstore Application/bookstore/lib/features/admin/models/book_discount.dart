class BookDiscount {
  final String id;
  final String code;
  final String discountType; // 'fixed_price' only
  final int bookId;
  final String bookName;
  final double? bookPrice;
  final String? bookThumbnail;
  final double discountedPrice;
  final int usageLimitPerCustomer;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? usageCount;
  final String? status;
  final double? finalPrice;
  final int? createdById;

  // Type constants
  static const String typeFixedPrice = 'fixed_price';

  BookDiscount({
    required this.id,
    required this.code,
    required this.discountType,
    required this.bookId,
    required this.bookName,
    this.bookPrice,
    this.bookThumbnail,
    required this.discountedPrice,
    required this.usageLimitPerCustomer,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.usageCount,
    this.status,
    this.finalPrice,
    this.createdById,
  });

  factory BookDiscount.fromJson(Map<String, dynamic> json) {
    return BookDiscount(
      id: json['id']?.toString() ?? '',
      code: json['code'] ?? '',
      discountType: json['discount_type'] ?? typeFixedPrice,
      bookId: json['book'] ?? json['book_id'] ?? 0,
      bookName: json['book_name'] ?? '',
      bookPrice: json['book_price'] != null
          ? double.tryParse(json['book_price'].toString())
          : null,
      bookThumbnail: json['book_thumbnail'],
      discountedPrice: json['discounted_price'] != null
          ? double.tryParse(json['discounted_price'].toString()) ?? 0.0
          : 0.0,
      usageLimitPerCustomer: json['usage_limit_per_customer'] ?? 1,
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'])
          : DateTime.now(),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'])
          : DateTime.now().add(const Duration(days: 30)),
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      usageCount: json['usage_count'],
      status: json['status'],
      finalPrice: json['final_price'] != null
          ? double.tryParse(json['final_price'].toString())
          : null,
      createdById: json['created_by_id'] ?? json['created_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'discount_type': discountType,
      'book': bookId,
      'discounted_price': discountedPrice,
      'usage_limit_per_customer': usageLimitPerCustomer,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'is_active': isActive,
      'created_by': createdById,
    };
  }

  BookDiscount copyWith({
    String? id,
    String? code,
    String? discountType,
    int? bookId,
    String? bookName,
    double? bookPrice,
    String? bookThumbnail,
    double? discountedPrice,
    int? usageLimitPerCustomer,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? usageCount,
    String? status,
    double? finalPrice,
    int? createdById,
  }) {
    return BookDiscount(
      id: id ?? this.id,
      code: code ?? this.code,
      discountType: discountType ?? this.discountType,
      bookId: bookId ?? this.bookId,
      bookName: bookName ?? this.bookName,
      bookPrice: bookPrice ?? this.bookPrice,
      bookThumbnail: bookThumbnail ?? this.bookThumbnail,
      discountedPrice: discountedPrice ?? this.discountedPrice,
      usageLimitPerCustomer:
          usageLimitPerCustomer ?? this.usageLimitPerCustomer,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      usageCount: usageCount ?? this.usageCount,
      status: status ?? this.status,
      finalPrice: finalPrice ?? this.finalPrice,
      createdById: createdById ?? this.createdById,
    );
  }

  // Helper methods
  bool get isCurrentlyValid {
    if (!isActive) return false;

    final now = DateTime.now();
    if (now.isBefore(startDate)) return false;
    if (now.isAfter(endDate)) return false;

    if (usageCount != null && usageCount! >= usageLimitPerCustomer) {
      return false;
    }

    return true;
  }

  bool get isExpired {
    return DateTime.now().isAfter(endDate);
  }

  bool get isNotStarted {
    return DateTime.now().isBefore(startDate);
  }

  bool get isUsageLimitReached {
    return usageCount != null && usageCount! >= usageLimitPerCustomer;
  }

  double calculateDiscountAmount(double originalPrice) {
    if (!isCurrentlyValid) return 0.0;
    return originalPrice - discountedPrice;
  }

  double calculateFinalPrice(double originalPrice) {
    if (!isCurrentlyValid) return originalPrice;
    return discountedPrice;
  }

  String get displayValue {
    return '\$${discountedPrice.toStringAsFixed(2)}';
  }
}

class AvailableBook {
  final int id;
  final String name;
  final String authorName;
  final String categoryName;
  final double? price;
  final String? thumbnail;
  final bool isAvailable;
  final bool hasActiveDiscount;

  AvailableBook({
    required this.id,
    required this.name,
    required this.authorName,
    required this.categoryName,
    this.price,
    this.thumbnail,
    this.isAvailable = true,
    this.hasActiveDiscount = false,
  });

  factory AvailableBook.fromJson(Map<String, dynamic> json) {
    return AvailableBook(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      authorName: json['author_name'] ?? '',
      categoryName: json['category_name'] ?? '',
      price: json['price'] != null
          ? double.tryParse(json['price'].toString())
          : null,
      thumbnail: json['thumbnail'],
      isAvailable: json['is_available'] ?? true,
      hasActiveDiscount: json['has_active_discount'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'author_name': authorName,
      'category_name': categoryName,
      'price': price,
      'thumbnail': thumbnail,
      'is_available': isAvailable,
      'has_active_discount': hasActiveDiscount,
    };
  }
}

class BookDiscountsResponse {
  final List<BookDiscount> activeDiscounts;
  final List<BookDiscount> expiredDiscounts;
  final List<BookDiscount> inactiveDiscounts;
  final List<BookDiscount> notStartedDiscounts;
  final int totalCount;
  final int activeCount;
  final int expiredCount;
  final int inactiveCount;
  final int notStartedCount;

  BookDiscountsResponse({
    required this.activeDiscounts,
    required this.expiredDiscounts,
    required this.inactiveDiscounts,
    required this.notStartedDiscounts,
    required this.totalCount,
    required this.activeCount,
    required this.expiredCount,
    required this.inactiveCount,
    required this.notStartedCount,
  });

  factory BookDiscountsResponse.fromJson(Map<String, dynamic> json) {
    return BookDiscountsResponse(
      activeDiscounts:
          (json['active_discounts'] as List?)
              ?.map((item) => BookDiscount.fromJson(item))
              .toList() ??
          [],
      expiredDiscounts:
          (json['expired_discounts'] as List?)
              ?.map((item) => BookDiscount.fromJson(item))
              .toList() ??
          [],
      inactiveDiscounts:
          (json['inactive_discounts'] as List?)
              ?.map((item) => BookDiscount.fromJson(item))
              .toList() ??
          [],
      notStartedDiscounts:
          (json['not_started_discounts'] as List?)
              ?.map((item) => BookDiscount.fromJson(item))
              .toList() ??
          [],
      totalCount: json['total_count'] ?? 0,
      activeCount: json['active_count'] ?? 0,
      expiredCount: json['expired_count'] ?? 0,
      inactiveCount: json['inactive_count'] ?? 0,
      notStartedCount: json['not_started_count'] ?? 0,
    );
  }

  List<BookDiscount> get allDiscounts {
    return [
      ...activeDiscounts,
      ...expiredDiscounts,
      ...inactiveDiscounts,
      ...notStartedDiscounts,
    ];
  }
}

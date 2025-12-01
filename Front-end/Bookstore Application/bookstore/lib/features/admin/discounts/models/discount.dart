class Discount {
  final int? id;
  final String code;
  final double percentage;
  final DateTime expirationDate;
  final int maxUsesPerCustomer;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Discount({
    this.id,
    required this.code,
    required this.percentage,
    required this.expirationDate,
    required this.maxUsesPerCustomer,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory Discount.fromJson(Map<String, dynamic> json) {
    return Discount(
      id: json['id'],
      code: json['code'],
      percentage: double.parse(json['discount_percentage'].toString()),
      expirationDate: DateTime.parse(json['expiration_date']),
      maxUsesPerCustomer: json['usage_limit_per_customer'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'discount_percentage': percentage,
      'expiration_date': expirationDate.toIso8601String(),
      'usage_limit_per_customer': maxUsesPerCustomer,
      'is_active': isActive,
    };
  }

  Discount copyWith({
    int? id,
    String? code,
    double? percentage,
    DateTime? expirationDate,
    int? maxUsesPerCustomer,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Discount(
      id: id ?? this.id,
      code: code ?? this.code,
      percentage: percentage ?? this.percentage,
      expirationDate: expirationDate ?? this.expirationDate,
      maxUsesPerCustomer: maxUsesPerCustomer ?? this.maxUsesPerCustomer,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

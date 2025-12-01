class Category {
  final String id;
  final String name;
  final String? description;
  final String? icon;
  final String? image;
  final int? bookCount;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Category({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    this.image,
    this.bookCount,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      icon: json['icon'],
      image: json['image'],
      bookCount: json['bookCount'] ?? json['book_count'],
      isActive: json['isActive'] ?? json['is_active'] ?? true,
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
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'image': image,
      'bookCount': bookCount,
      'is_active': isActive, // Backend expects snake_case
      'created_at': createdAt.toIso8601String(), // Backend expects snake_case
      'updated_at': updatedAt.toIso8601String(), // Backend expects snake_case
    };
  }
}

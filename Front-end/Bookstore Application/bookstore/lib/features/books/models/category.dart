class Category {
  final int? id;
  final String name;
  final String? description;
  final int? booksCount;
  final int? availableBooksCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Category({
    this.id,
    required this.name,
    this.description,
    this.booksCount,
    this.availableBooksCount,
    this.createdAt,
    this.updatedAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      booksCount: json['books_count'],
      availableBooksCount: json['available_books_count'],
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
      'name': name,
      'description': description,
      'books_count': booksCount,
      'available_books_count': availableBooksCount,
    };
  }

  Category copyWith({
    int? id,
    String? name,
    String? description,
    int? booksCount,
    int? availableBooksCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      booksCount: booksCount ?? this.booksCount,
      availableBooksCount: availableBooksCount ?? this.availableBooksCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

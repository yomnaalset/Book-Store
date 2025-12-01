class Author {
  final String id;
  final String name;
  final String? biography;
  final String? photo;
  final String? country;
  final String? birthDate;
  final String? deathDate;
  final int? bookCount;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Author({
    required this.id,
    required this.name,
    this.biography,
    this.photo,
    this.country,
    this.birthDate,
    this.deathDate,
    this.bookCount,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Author.fromJson(Map<String, dynamic> json) {
    return Author(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      biography: json['biography'] ?? json['bio'],
      photo: json['photo'],
      country:
          json['country'] ?? json['nationality'], // Handle both field names
      birthDate: json['birthDate'] ?? json['birth_date'],
      deathDate: json['deathDate'] ?? json['death_date'],
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
      'bio':
          biography ??
          '', // Backend expects 'bio' not 'biography', but not null
      'photo': photo,
      'nationality':
          country ??
          '', // Backend expects 'nationality' not 'country', but not null
      'birth_date': birthDate != null
          ? birthDate!.split('T')[0]
          : null, // Backend expects YYYY-MM-DD format
      'death_date': deathDate != null
          ? deathDate!.split('T')[0]
          : null, // Backend expects YYYY-MM-DD format
      'book_count': bookCount, // Backend expects snake_case
      'is_active': isActive, // Backend expects snake_case
      'created_at': createdAt.toIso8601String(), // Backend expects snake_case
      'updated_at': updatedAt.toIso8601String(), // Backend expects snake_case
    };
  }

  // Compatibility getter for bio
  String? get bio => biography;
}

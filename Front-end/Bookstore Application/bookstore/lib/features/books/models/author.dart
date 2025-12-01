class Author {
  final int? id;
  final String name;
  final String? bio;
  final String? photo;
  final String? photoUrl;
  final String? birthDate;
  final String? deathDate;
  final String? nationality;
  final bool isActive;
  final int? booksCount;
  final int? availableBooksCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Author({
    this.id,
    required this.name,
    this.bio,
    this.photo,
    this.photoUrl,
    this.birthDate,
    this.deathDate,
    this.nationality,
    this.isActive = true,
    this.booksCount,
    this.availableBooksCount,
    this.createdAt,
    this.updatedAt,
  });

  factory Author.fromJson(Map<String, dynamic> json) {
    return Author(
      id: json['id'],
      name: json['name'],
      bio: json['bio'],
      photo: json['photo'],
      photoUrl: json['photo_url'] ?? json['photoUrl'],
      birthDate: json['birth_date'] ?? json['birthDate'],
      deathDate: json['death_date'] ?? json['deathDate'],
      nationality: json['nationality'],
      isActive: json['is_active'] ?? json['isActive'] ?? true,
      booksCount: json['books_count'] ?? json['booksCount'],
      availableBooksCount:
          json['available_books_count'] ?? json['availableBooksCount'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'bio': bio,
      'photo': photo,
      'photo_url': photoUrl,
      'birth_date': birthDate,
      'death_date': deathDate,
      'nationality': nationality,
      'is_active': isActive,
      'books_count': booksCount,
      'available_books_count': availableBooksCount,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Compatibility getter for UI code
  String? get biography => bio;
  String? get imageUrl => photoUrl;

  Author copyWith({
    int? id,
    String? name,
    String? bio,
    String? photo,
    String? photoUrl,
    String? birthDate,
    String? deathDate,
    String? nationality,
    bool? isActive,
    int? booksCount,
    int? availableBooksCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Author(
      id: id ?? this.id,
      name: name ?? this.name,
      bio: bio ?? this.bio,
      photo: photo ?? this.photo,
      photoUrl: photoUrl ?? this.photoUrl,
      birthDate: birthDate ?? this.birthDate,
      deathDate: deathDate ?? this.deathDate,
      nationality: nationality ?? this.nationality,
      isActive: isActive ?? this.isActive,
      booksCount: booksCount ?? this.booksCount,
      availableBooksCount: availableBooksCount ?? this.availableBooksCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

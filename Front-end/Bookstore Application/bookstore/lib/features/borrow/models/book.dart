import '../../../core/services/api_config.dart';

class Book {
  final int id;
  final String title;
  final String? author;
  final List<String>? authors;
  final String? coverImageUrl;
  final String? description;
  final double? price;
  final int? totalCopies;
  final int? availableCopies;
  final String? isbn;
  final String? publisher;
  final DateTime? publicationDate;
  final String? genre;
  final String? language;
  final int? pages;
  final double? rating;
  final int? borrowCount;

  Book({
    required this.id,
    required this.title,
    this.author,
    this.authors,
    this.coverImageUrl,
    this.description,
    this.price,
    this.totalCopies,
    this.availableCopies,
    this.isbn,
    this.publisher,
    this.publicationDate,
    this.genre,
    this.language,
    this.pages,
    this.rating,
    this.borrowCount,
  });

  /// Parse double value from JSON - handles both string and numeric values
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      if (value.isEmpty) return null;
      return double.tryParse(value);
    }
    return double.tryParse(value.toString());
  }

  factory Book.fromJson(Map<String, dynamic> json) {
    // Get the raw image URL from various possible field names
    final rawImageUrl =
        json['cover_image_url'] ??
        json['cover_image'] ??
        json['primary_image_url'] ??
        json['image_url'];

    // Build full URL from relative path if needed
    final coverImageUrl = rawImageUrl != null
        ? ApiConfig.buildImageUrl(rawImageUrl) ?? rawImageUrl
        : null;

    return Book(
      id: json['id'] ?? 0,
      title: json['title'] ?? json['name'] ?? '',
      author: json['author']?['name'] ?? json['author'],
      authors: json['authors'] != null
          ? List<String>.from(
              json['authors'].map((a) => a['name'] ?? a.toString()),
            )
          : null,
      coverImageUrl: coverImageUrl,
      description: json['description'],
      price: _parseDouble(json['price']),
      totalCopies: json['total_copies'],
      availableCopies: json['available_copies'],
      isbn: json['isbn'],
      publisher: json['publisher'],
      publicationDate: json['publication_date'] != null
          ? DateTime.parse(json['publication_date'])
          : null,
      genre: json['genre'],
      language: json['language'],
      pages: json['pages'],
      rating: _parseDouble(json['rating']),
      borrowCount: json['borrow_count'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'authors': authors,
      'cover_image_url': coverImageUrl,
      'description': description,
      'price': price,
      'total_copies': totalCopies,
      'available_copies': availableCopies,
      'rating': rating,
      'borrow_count': borrowCount,
    };
  }
}

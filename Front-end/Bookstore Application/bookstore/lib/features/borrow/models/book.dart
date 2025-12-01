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

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      author: json['author']?['name'] ?? json['author'],
      authors: json['authors'] != null
          ? List<String>.from(
              json['authors'].map((a) => a['name'] ?? a.toString()),
            )
          : null,
      coverImageUrl: json['cover_image_url'] ?? json['cover_image'],
      description: json['description'],
      price: json['price']?.toDouble(),
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
      rating: json['rating']?.toDouble(),
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

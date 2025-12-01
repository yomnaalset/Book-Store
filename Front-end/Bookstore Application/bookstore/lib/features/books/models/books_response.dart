import 'book.dart';

class BooksResponse {
  final List<Book> books;
  final int totalItems;
  final int totalPages;
  final int currentPage;
  final int itemsPerPage;
  final bool hasNextPage;
  final bool hasPreviousPage;
  final Map<String, dynamic>? metadata;

  BooksResponse({
    required this.books,
    required this.totalItems,
    required this.totalPages,
    required this.currentPage,
    required this.itemsPerPage,
    required this.hasNextPage,
    required this.hasPreviousPage,
    this.metadata,
  });

  factory BooksResponse.fromJson(Map<String, dynamic> json) {
    final booksData = json['books'] ?? json['data'] ?? [];
    final books = (booksData as List)
        .map((bookJson) => Book.fromJson(bookJson))
        .toList();

    return BooksResponse(
      books: books,
      totalItems:
          json['totalItems'] ??
          json['total'] ??
          json['total_items'] ??
          books.length,
      totalPages: json['totalPages'] ?? json['total_pages'] ?? 1,
      currentPage:
          json['currentPage'] ?? json['current_page'] ?? json['page'] ?? 1,
      itemsPerPage:
          json['itemsPerPage'] ??
          json['items_per_page'] ??
          json['per_page'] ??
          books.length,
      hasNextPage: json['hasNextPage'] ?? json['has_next_page'] ?? false,
      hasPreviousPage:
          json['hasPreviousPage'] ?? json['has_previous_page'] ?? false,
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'books': books.map((book) => book.toJson()).toList(),
      'totalItems': totalItems,
      'totalPages': totalPages,
      'currentPage': currentPage,
      'itemsPerPage': itemsPerPage,
      'hasNextPage': hasNextPage,
      'hasPreviousPage': hasPreviousPage,
      'metadata': metadata,
    };
  }

  // Helper methods
  bool get isEmpty => books.isEmpty;
  bool get isNotEmpty => books.isNotEmpty;
  int get length => books.length;

  // Pagination helpers
  bool get canLoadMore => hasNextPage;
  bool get canLoadPrevious => hasPreviousPage;
  int get nextPage => hasNextPage ? currentPage + 1 : currentPage;
  int get previousPage => hasPreviousPage ? currentPage - 1 : currentPage;

  // Filter helpers
  List<Book> get availableBooks =>
      books.where((book) => book.isAvailable == true).toList();
  List<Book> get newBooks => books.where((book) => book.isNew == true).toList();
  List<Book> get borrowableBooks =>
      books.where((book) => book.isAvailableForBorrow == true).toList();

  // Search and filter methods
  List<Book> searchByTitle(String query) {
    if (query.isEmpty) return books;
    return books
        .where((book) => book.title.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  List<Book> filterByCategory(String categoryId) {
    return books
        .where((book) => book.category?.id.toString() == categoryId)
        .toList();
  }

  List<Book> filterByAuthor(String authorId) {
    return books
        .where((book) => book.author?.id.toString() == authorId)
        .toList();
  }

  List<Book> filterByPriceRange(double minPrice, double maxPrice) {
    return books.where((book) {
      final price = book.priceAsDouble;
      return price >= minPrice && price <= maxPrice;
    }).toList();
  }

  List<Book> sortByTitle({bool ascending = true}) {
    final sortedBooks = List<Book>.from(books);
    sortedBooks.sort(
      (a, b) =>
          ascending ? a.title.compareTo(b.title) : b.title.compareTo(a.title),
    );
    return sortedBooks;
  }

  List<Book> sortByPrice({bool ascending = true}) {
    final sortedBooks = List<Book>.from(books);
    sortedBooks.sort(
      (a, b) => ascending
          ? a.priceAsDouble.compareTo(b.priceAsDouble)
          : b.priceAsDouble.compareTo(a.priceAsDouble),
    );
    return sortedBooks;
  }

  List<Book> sortByRating({bool ascending = false}) {
    final sortedBooks = List<Book>.from(books);
    sortedBooks.sort((a, b) {
      final ratingA = a.averageRating ?? 0.0;
      final ratingB = b.averageRating ?? 0.0;
      return ascending
          ? ratingA.compareTo(ratingB)
          : ratingB.compareTo(ratingA);
    });
    return sortedBooks;
  }

  List<Book> sortByDate({bool ascending = false}) {
    final sortedBooks = List<Book>.from(books);
    sortedBooks.sort((a, b) {
      final dateA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return ascending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
    });
    return sortedBooks;
  }

  // Copy with method for pagination
  BooksResponse copyWith({
    List<Book>? books,
    int? totalItems,
    int? totalPages,
    int? currentPage,
    int? itemsPerPage,
    bool? hasNextPage,
    bool? hasPreviousPage,
    Map<String, dynamic>? metadata,
  }) {
    return BooksResponse(
      books: books ?? this.books,
      totalItems: totalItems ?? this.totalItems,
      totalPages: totalPages ?? this.totalPages,
      currentPage: currentPage ?? this.currentPage,
      itemsPerPage: itemsPerPage ?? this.itemsPerPage,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      hasPreviousPage: hasPreviousPage ?? this.hasPreviousPage,
      metadata: metadata ?? this.metadata,
    );
  }

  // Static factory methods
  static BooksResponse empty() {
    return BooksResponse(
      books: [],
      totalItems: 0,
      totalPages: 0,
      currentPage: 1,
      itemsPerPage: 0,
      hasNextPage: false,
      hasPreviousPage: false,
    );
  }

  static BooksResponse fromBooks(
    List<Book> books, {
    int page = 1,
    int itemsPerPage = 20,
  }) {
    final totalItems = books.length;
    final totalPages = (totalItems / itemsPerPage).ceil();

    return BooksResponse(
      books: books,
      totalItems: totalItems,
      totalPages: totalPages,
      currentPage: page,
      itemsPerPage: itemsPerPage,
      hasNextPage: page < totalPages,
      hasPreviousPage: page > 1,
    );
  }
}

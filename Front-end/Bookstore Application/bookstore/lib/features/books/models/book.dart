import 'author.dart';
import 'category.dart' as book_category;

class Book {
  final String id;
  final String title;
  final String? description;
  final Author? author;
  final book_category.Category? category;
  final String? primaryImageUrl;
  final List<String>? additionalImages;
  final String? price;
  final String? borrowPrice;
  final int? availableCopies;
  final double? averageRating;
  final int? evaluationsCount;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool? isNew;
  final bool? isAvailable;
  final bool? isAvailableForBorrow;
  final int? quantity;
  final int? borrowCount;
  final List<String>? images;
  final String? name;
  final String? availabilityStatus;
  // Discount fields
  final double? originalPrice;
  final double? discountedPrice;
  final double? discountAmount;
  final double? discountPercentage;
  final bool? hasActiveDiscount;

  Book({
    required this.id,
    required this.title,
    this.description,
    this.author,
    this.category,
    this.primaryImageUrl,
    this.additionalImages,
    this.price,
    this.borrowPrice,
    this.availableCopies,
    this.averageRating,
    this.evaluationsCount,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.isNew,
    this.isAvailable,
    this.isAvailableForBorrow,
    this.quantity,
    this.borrowCount,
    this.images,
    this.name,
    this.availabilityStatus,
    this.originalPrice,
    this.discountedPrice,
    this.discountAmount,
    this.discountPercentage,
    this.hasActiveDiscount,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? json['name'] ?? '',
      description: json['description'],
      author: json['author'] != null
          ? (json['author'] is Map<String, dynamic>
                ? Author.fromJson(json['author'])
                : Author(
                    id: json['author'] is int
                        ? json['author']
                        : int.tryParse(json['author']?.toString() ?? '0'),
                    name: json['author_name'] ?? '',
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ))
          : (json['author_name'] != null || json['author_id'] != null)
          ? Author(
              id: json['author_id'] is int
                  ? json['author_id']
                  : int.tryParse(json['author_id']?.toString() ?? '0'),
              name: json['author_name'] ?? '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            )
          : null,
      category: json['category'] != null
          ? (json['category'] is Map<String, dynamic>
                ? book_category.Category.fromJson(json['category'])
                : book_category.Category(
                    id: json['category'] is int
                        ? json['category']
                        : int.tryParse(json['category']?.toString() ?? '0'),
                    name: json['category_name'] ?? '',
                  ))
          : (json['category_name'] != null || json['category_id'] != null)
          ? book_category.Category(
              id: json['category_id'] is int
                  ? json['category_id']
                  : int.tryParse(json['category_id']?.toString() ?? '0'),
              name: json['category_name'] ?? '',
            )
          : null,
      primaryImageUrl:
          json['primaryImageUrl'] ??
          json['primary_image_url'] ??
          json['coverUrl'] ??
          json['cover_url'],
      additionalImages: json['additionalImages'] != null
          ? List<String>.from(json['additionalImages'])
          : json['additional_images'] != null
          ? List<String>.from(json['additional_images'])
          : null,
      price: json['price']?.toString(),
      borrowPrice:
          json['borrowPrice']?.toString() ?? json['borrow_price']?.toString(),
      availableCopies: json['availableCopies'] ?? json['available_copies'],
      averageRating: json['averageRating'] != null
          ? double.tryParse(json['averageRating'].toString())
          : json['average_rating'] != null
          ? double.tryParse(json['average_rating'].toString())
          : null,
      evaluationsCount: json['evaluationsCount'] ?? json['evaluations_count'],
      isActive: json['isActive'] ?? json['is_active'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      isNew: json['isNew'] ?? json['is_new'],
      isAvailable: json['isAvailable'] ?? json['is_available'],
      isAvailableForBorrow:
          json['isAvailableForBorrow'] ?? json['is_available_for_borrow'],
      quantity: json['quantity'],
      borrowCount: json['borrowCount'] ?? json['borrow_count'],
      images: json['images'] != null
          ? List<String>.from(json['images'])
          : json['additionalImages'] != null
          ? List<String>.from(json['additionalImages'])
          : json['additional_images'] != null
          ? List<String>.from(json['additional_images'])
          : null,
      name: json['name'] ?? json['title'],
      availabilityStatus: json['availability_status'],
      // Discount fields
      originalPrice: json['original_price'] != null
          ? double.tryParse(json['original_price'].toString())
          : null,
      discountedPrice: json['discounted_price'] != null
          ? double.tryParse(json['discounted_price'].toString())
          : null,
      discountAmount: json['discount_amount'] != null
          ? double.tryParse(json['discount_amount'].toString())
          : null,
      discountPercentage: json['discount_percentage'] != null
          ? double.tryParse(json['discount_percentage'].toString())
          : null,
      hasActiveDiscount: json['has_active_discount'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'author': author?.toJson(),
      'category': category?.toJson(),
      'primaryImageUrl': primaryImageUrl,
      'additionalImages': additionalImages,
      'price': price,
      'borrowPrice': borrowPrice,
      'availableCopies': availableCopies,
      'averageRating': averageRating,
      'evaluationsCount': evaluationsCount,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isNew': isNew,
      'isAvailable': isAvailable,
      'isAvailableForBorrow': isAvailableForBorrow,
      'quantity': quantity,
      'borrowCount': borrowCount,
      'images': images,
      'name': name,
      'availability_status': availabilityStatus,
      'original_price': originalPrice,
      'discounted_price': discountedPrice,
      'discount_amount': discountAmount,
      'discount_percentage': discountPercentage,
      'has_active_discount': hasActiveDiscount,
    };
  }

  // Compatibility getters
  double get priceAsDouble {
    return double.tryParse(price ?? '0.0') ?? 0.0;
  }

  double get borrowPriceAsDouble {
    return double.tryParse(borrowPrice ?? '0.0') ?? 0.0;
  }

  // Compatibility getters for UI code
  String? get coverImageUrl => primaryImageUrl;
  double? get rating => averageRating;
  int? get reviewCount => evaluationsCount;
  double? get discountPrice => discountedPrice;
  int? get stock => availableCopies;
  String? get isbn => null; // Not in backend model
  String? get publisher => null; // Not in backend model
  String? get publicationDate => null; // Not in backend model
  int? get pages => null; // Not in backend model
  String? get language => null; // Not in backend model
  double? get weight => null; // Not in backend model

  // Override price getter to return double instead of String
  double? get priceAsCompatibleDouble => priceAsDouble;

  // Compatibility getter for UI code that expects authors list
  List<Author> get authors => author != null ? [author!] : [];

  // Discount helper methods
  bool get hasDiscount {
    // Check if we have discount data
    if (discountedPrice != null &&
        originalPrice != null &&
        discountedPrice! < originalPrice!) {
      return true;
    }
    // Also check if backend says there's an active discount
    if (hasActiveDiscount == true &&
        discountedPrice != null &&
        originalPrice != null) {
      return true;
    }
    return false;
  }

  double get finalPrice => hasDiscount ? discountedPrice! : priceAsDouble;

  double get savingsAmount =>
      hasDiscount ? (originalPrice! - discountedPrice!) : 0.0;

  double get savingsPercentage => hasDiscount && originalPrice! > 0
      ? ((originalPrice! - discountedPrice!) / originalPrice!) * 100
      : 0.0;

  Book copyWith({
    String? id,
    String? title,
    String? description,
    Author? author,
    book_category.Category? category,
    String? primaryImageUrl,
    List<String>? additionalImages,
    String? price,
    String? borrowPrice,
    int? availableCopies,
    double? averageRating,
    int? evaluationsCount,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isNew,
    bool? isAvailable,
    bool? isAvailableForBorrow,
    int? quantity,
    int? borrowCount,
    List<String>? images,
    String? name,
    String? availabilityStatus,
    double? originalPrice,
    double? discountedPrice,
    double? discountAmount,
    double? discountPercentage,
    bool? hasActiveDiscount,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      author: author ?? this.author,
      category: category ?? this.category,
      primaryImageUrl: primaryImageUrl ?? this.primaryImageUrl,
      additionalImages: additionalImages ?? this.additionalImages,
      price: price ?? this.price,
      borrowPrice: borrowPrice ?? this.borrowPrice,
      availableCopies: availableCopies ?? this.availableCopies,
      averageRating: averageRating ?? this.averageRating,
      evaluationsCount: evaluationsCount ?? this.evaluationsCount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isNew: isNew ?? this.isNew,
      isAvailable: isAvailable ?? this.isAvailable,
      isAvailableForBorrow: isAvailableForBorrow ?? this.isAvailableForBorrow,
      quantity: quantity ?? this.quantity,
      borrowCount: borrowCount ?? this.borrowCount,
      images: images ?? this.images,
      name: name ?? this.name,
      availabilityStatus: availabilityStatus ?? this.availabilityStatus,
      originalPrice: originalPrice ?? this.originalPrice,
      discountedPrice: discountedPrice ?? this.discountedPrice,
      discountAmount: discountAmount ?? this.discountAmount,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      hasActiveDiscount: hasActiveDiscount ?? this.hasActiveDiscount,
    );
  }

  // Empty book factory
  factory Book.empty() {
    return Book(
      id: '',
      title: '',
      isActive: false,
      isNew: false,
      isAvailable: false,
      isAvailableForBorrow: false,
      quantity: 0,
      borrowCount: 0,
    );
  }
}

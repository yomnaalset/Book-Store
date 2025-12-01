import 'package:flutter/foundation.dart' as foundation;
import 'author.dart';
import 'category.dart';

class Book {
  final String id;
  final String title;
  final String? description;
  final Author? author;
  final Category? category;
  final String? primaryImageUrl;
  final List<String>? additionalImages;
  final String? price;
  final String? borrowPrice;
  final int? availableCopies;
  final double? averageRating;
  final int? evaluationsCount;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String>? images;
  final bool? isAvailable;
  final bool? isAvailableForBorrow;
  final int? quantity;
  final int? borrowCount;
  final bool? isNew;

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
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.images,
    this.isAvailable,
    this.isAvailableForBorrow,
    this.quantity,
    this.borrowCount,
    this.isNew,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? json['name'] ?? '',
      description: json['description'],
      author: (json['author_id'] != null && json['author_name'] != null)
          ? Author.fromJson({
              'id': json['author_id'],
              'name': json['author_name'],
            })
          : (json['author'] != null && json['author'] is Map<String, dynamic>)
          ? Author.fromJson(json['author'])
          : null,
      category: (json['category_id'] != null && json['category_name'] != null)
          ? Category.fromJson({
              'id': json['category_id'],
              'name': json['category_name'],
            })
          : (json['category'] != null &&
                json['category'] is Map<String, dynamic>)
          ? Category.fromJson(json['category'])
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
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      images: json['images'] != null ? List<String>.from(json['images']) : null,
      isAvailable: json['isAvailable'] ?? json['is_available'],
      isAvailableForBorrow:
          json['isAvailableForBorrow'] ?? json['is_available_for_borrow'],
      quantity: json['quantity'],
      borrowCount: json['borrowCount'] ?? json['borrow_count'],
      isNew: json['isNew'] ?? json['is_new'],
    );
  }

  Map<String, dynamic> toJson() {
    foundation.debugPrint(
      'DEBUG: Book toJson - author: ${author?.id}, category: ${category?.id}',
    );
    return {
      'id': id,
      'name': title, // Backend expects 'name' not 'title'
      'description': description,
      'author': author?.id, // Backend expects author ID, not full object
      'category': category?.id, // Backend expects category ID, not full object
      'primary_image_url': primaryImageUrl, // Backend expects snake_case
      'additional_images': additionalImages, // Backend expects snake_case
      'price': price,
      'borrow_price': borrowPrice, // Backend expects snake_case
      'available_copies': availableCopies, // Backend expects snake_case
      'average_rating': averageRating, // Backend expects snake_case
      'evaluations_count': evaluationsCount, // Backend expects snake_case
      'is_active': isActive, // Backend expects snake_case
      'created_at': createdAt.toIso8601String(), // Backend expects snake_case
      'updated_at': updatedAt.toIso8601String(), // Backend expects snake_case
      'images': images,
      'is_available': isAvailable, // Backend expects snake_case
      'is_available_for_borrow':
          isAvailableForBorrow, // Backend expects snake_case
      'quantity': quantity,
      'borrow_count': borrowCount, // Backend expects snake_case
      'is_new': isNew, // Backend expects snake_case
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
  double? get discountPrice => null; // Not implemented in backend model
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
}

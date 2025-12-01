import '../../../features/books/models/book.dart';

// Helper function to safely parse double values from JSON
double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value) ?? 0.0;
  }
  return 0.0;
}

class CartItem {
  final String id;
  final Book book;
  int quantity;
  final double price;
  final double? discountPrice;
  final DateTime addedAt;

  CartItem({
    required this.id,
    required this.book,
    required this.quantity,
    required this.price,
    this.discountPrice,
    required this.addedAt,
  });

  double get totalPrice => (discountPrice ?? price) * quantity;
  double get originalTotalPrice => price * quantity;
  double get totalSavings => originalTotalPrice - totalPrice;
  bool get hasDiscount => discountPrice != null && discountPrice! < price;

  Map<String, dynamic> toJson() => {
    'id': id,
    'book': book.toJson(),
    'quantity': quantity,
    'price': price,
    'discount_price': discountPrice,
    'added_at': addedAt.toIso8601String(),
  };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    id: json['id']?.toString() ?? '',
    book: Book.fromJson(json['book']),
    quantity: json['quantity'] is int
        ? json['quantity']
        : (json['quantity'] is String
              ? int.tryParse(json['quantity']) ?? 1
              : 1),
    price: _parseDouble(json['price'] ?? 0.0),
    discountPrice: json['discount_price'] != null
        ? _parseDouble(json['discount_price'])
        : null,
    addedAt: json['added_at'] != null
        ? (json['added_at'] is String
              ? DateTime.tryParse(json['added_at']) ?? DateTime.now()
              : DateTime.now())
        : DateTime.now(),
  );

  CartItem copyWith({
    String? id,
    Book? book,
    int? quantity,
    double? price,
    double? discountPrice,
    DateTime? addedAt,
  }) {
    return CartItem(
      id: id ?? this.id,
      book: book ?? this.book,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      discountPrice: discountPrice ?? this.discountPrice,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'CartItem{id: $id, book: ${book.title}, quantity: $quantity, price: $price}';
  }
}

import 'reply.dart';

class Review {
  final int id;
  final int userId;
  final String? userName;
  final int bookId;
  final int? rating;
  final String? comment;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? likesCount;
  final bool? isLiked;
  final List<Reply>? replies;

  Review({
    required this.id,
    required this.userId,
    this.userName,
    required this.bookId,
    this.rating,
    this.comment,
    this.createdAt,
    this.updatedAt,
    this.likesCount,
    this.isLiked,
    this.replies,
  });

  factory Review.fromJson(Map<String, dynamic> json) => Review(
    id: json['id'] ?? 0,
    userId: int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
    userName: json['user_name'],
    bookId: json['book_id'] ?? 0,
    rating: json['rating'],
    comment: json['comment'],
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'])
        : null,
    updatedAt: json['updated_at'] != null
        ? DateTime.parse(json['updated_at'])
        : null,
    likesCount: json['likes_count'] ?? 0,
    isLiked: json['is_liked'] ?? false,
    replies: json['replies'] != null
        ? (json['replies'] as List)
              .map((replyJson) => Reply.fromJson(replyJson))
              .toList()
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'user_name': userName,
    'book_id': bookId,
    'rating': rating,
    'comment': comment,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'likes_count': likesCount,
    'is_liked': isLiked,
    'replies': replies?.map((reply) => reply.toJson()).toList(),
  };
}

class Reply {
  final int id;
  final int userId;
  final String? userName;
  final String? userEmail;
  final int reviewId;
  final String content;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? likesCount;
  final bool? isLiked;

  Reply({
    required this.id,
    required this.userId,
    this.userName,
    this.userEmail,
    required this.reviewId,
    required this.content,
    this.createdAt,
    this.updatedAt,
    this.likesCount,
    this.isLiked,
  });

  factory Reply.fromJson(Map<String, dynamic> json) => Reply(
    id: json['id'] ?? 0,
    userId: json['user'] ?? 0,
    userName: json['user_name'],
    userEmail: json['user_email'],
    reviewId: json['review'] ?? 0,
    content: json['content'] ?? '',
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'])
        : null,
    updatedAt: json['updated_at'] != null
        ? DateTime.parse(json['updated_at'])
        : null,
    likesCount: json['likes_count'],
    isLiked: json['is_liked'],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user': userId,
    'user_name': userName,
    'user_email': userEmail,
    'review': reviewId,
    'content': content,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'likes_count': likesCount,
    'is_liked': isLiked,
  };
}

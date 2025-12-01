import 'package:flutter/foundation.dart';

class OrderNote {
  final int id;
  final String content;
  final int? authorId;
  final String? authorName;
  final String? authorEmail;
  final String? authorType;
  final bool? canEdit;
  final bool? canDelete;
  final DateTime createdAt;
  final DateTime updatedAt;

  OrderNote({
    required this.id,
    required this.content,
    this.authorId,
    this.authorName,
    this.authorEmail,
    this.authorType,
    this.canEdit,
    this.canDelete,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OrderNote.fromJson(Map<String, dynamic> json) {
    return OrderNote(
      id: json['id'] ?? 0,
      content: json['content'] ?? '',
      authorId: json['author'] != null ? int.tryParse(json['author'].toString()) : null,
      authorName: json['author_name'],
      authorEmail: json['author_email'],
      authorType: json['author_type'],
      canEdit: json['can_edit'] ?? false,
      canDelete: json['can_delete'] ?? false,
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updated_at']) ?? DateTime.now(),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        debugPrint('Error parsing date: $value');
        return null;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'author': authorId,
      'author_name': authorName,
      'author_email': authorEmail,
      'author_type': authorType,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get authorDisplayName {
    if (authorName != null && authorName!.isNotEmpty) {
      return authorName!;
    }
    if (authorEmail != null && authorEmail!.isNotEmpty) {
      return authorEmail!;
    }
    return 'Unknown';
  }

  String get authorTypeDisplay {
    switch (authorType) {
      case 'customer':
        return 'Customer';
      case 'library_admin':
        return 'Admin';
      case 'delivery_admin':
        return 'Delivery Manager';
      default:
        return authorType ?? 'Unknown';
    }
  }
}


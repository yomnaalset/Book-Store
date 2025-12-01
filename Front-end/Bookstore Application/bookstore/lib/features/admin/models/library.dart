class Library {
  final String id;
  final String name;
  final String details;
  final String? logoUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdById;
  final String? createdByEmail;
  final String? createdByFirstName;
  final String? createdByLastName;
  final String? lastUpdatedById;
  final String? lastUpdatedByEmail;
  final String? lastUpdatedByFirstName;
  final String? lastUpdatedByLastName;

  Library({
    required this.id,
    required this.name,
    required this.details,
    this.logoUrl,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.createdById,
    this.createdByEmail,
    this.createdByFirstName,
    this.createdByLastName,
    this.lastUpdatedById,
    this.lastUpdatedByEmail,
    this.lastUpdatedByFirstName,
    this.lastUpdatedByLastName,
  });

  factory Library.fromJson(Map<String, dynamic> json) {
    return Library(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      details: json['details'] ?? '',
      logoUrl: json['logo'] ?? json['logo_url'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      createdById: _extractUserId(json['created_by']),
      createdByEmail: _extractUserEmail(json['created_by']),
      createdByFirstName: _extractUserFirstName(json['created_by']),
      createdByLastName: _extractUserLastName(json['created_by']),
      lastUpdatedById: _extractUserId(json['last_updated_by']),
      lastUpdatedByEmail: _extractUserEmail(json['last_updated_by']),
      lastUpdatedByFirstName: _extractUserFirstName(json['last_updated_by']),
      lastUpdatedByLastName: _extractUserLastName(json['last_updated_by']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'details': details,
      'logo': logoUrl,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by': createdById != null
          ? {
              'id': createdById,
              'email': createdByEmail,
              'first_name': createdByFirstName,
              'last_name': createdByLastName,
            }
          : null,
      'last_updated_by': lastUpdatedById != null
          ? {
              'id': lastUpdatedById,
              'email': lastUpdatedByEmail,
              'first_name': lastUpdatedByFirstName,
              'last_name': lastUpdatedByLastName,
            }
          : null,
    };
  }

  Library copyWith({
    String? id,
    String? name,
    String? details,
    String? logoUrl,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdById,
    String? createdByEmail,
    String? createdByFirstName,
    String? createdByLastName,
    String? lastUpdatedById,
    String? lastUpdatedByEmail,
    String? lastUpdatedByFirstName,
    String? lastUpdatedByLastName,
  }) {
    return Library(
      id: id ?? this.id,
      name: name ?? this.name,
      details: details ?? this.details,
      logoUrl: logoUrl ?? this.logoUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdById: createdById ?? this.createdById,
      createdByEmail: createdByEmail ?? this.createdByEmail,
      createdByFirstName: createdByFirstName ?? this.createdByFirstName,
      createdByLastName: createdByLastName ?? this.createdByLastName,
      lastUpdatedById: lastUpdatedById ?? this.lastUpdatedById,
      lastUpdatedByEmail: lastUpdatedByEmail ?? this.lastUpdatedByEmail,
      lastUpdatedByFirstName:
          lastUpdatedByFirstName ?? this.lastUpdatedByFirstName,
      lastUpdatedByLastName:
          lastUpdatedByLastName ?? this.lastUpdatedByLastName,
    );
  }

  // Helper methods
  String get createdByName =>
      '${createdByFirstName ?? ''} ${createdByLastName ?? ''}'.trim();

  String get lastUpdatedByName =>
      '${lastUpdatedByFirstName ?? ''} ${lastUpdatedByLastName ?? ''}'.trim();

  bool get hasLogo => logoUrl != null && logoUrl!.isNotEmpty;

  bool get isCreated => createdById != null && createdById!.isNotEmpty;

  // Helper methods to extract user data from different formats
  static String? _extractUserId(dynamic userData) {
    if (userData == null) return null;
    if (userData is Map<String, dynamic>) {
      return userData['id']?.toString();
    } else if (userData is int) {
      return userData.toString();
    }
    return null;
  }

  static String? _extractUserEmail(dynamic userData) {
    if (userData == null) return null;
    if (userData is Map<String, dynamic>) {
      return userData['email'];
    }
    return null;
  }

  static String? _extractUserFirstName(dynamic userData) {
    if (userData == null) return null;
    if (userData is Map<String, dynamic>) {
      return userData['first_name'];
    }
    return null;
  }

  static String? _extractUserLastName(dynamic userData) {
    if (userData == null) return null;
    if (userData is Map<String, dynamic>) {
      return userData['last_name'];
    }
    return null;
  }
}

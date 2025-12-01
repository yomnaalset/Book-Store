class User {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final String? address;
  final String? profileImage;
  final String role;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? preferredLanguage;
  final DateTime? lastLoginAt;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    this.address,
    this.profileImage,
    required this.role,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.preferredLanguage,
    this.lastLoginAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      firstName:
          json['firstName'] ??
          json['first_name'] ??
          (json['full_name'] != null
              ? json['full_name'].split(' ').first
              : '') ??
          '',
      lastName:
          json['lastName'] ??
          json['last_name'] ??
          (json['full_name'] != null
              ? json['full_name'].split(' ').skip(1).join(' ')
              : '') ??
          '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? json['phone_number'],
      address: json['address'],
      profileImage:
          json['profileImage'] ??
          json['profile_image'] ??
          json['profile_picture'],
      role: json['role'] ?? json['user_type'] ?? 'customer',
      isActive: json['isActive'] ?? json['is_active'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : json['date_joined'] != null
          ? DateTime.parse(json['date_joined'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : json['last_updated'] != null
          ? DateTime.parse(json['last_updated'])
          : DateTime.now(),
      preferredLanguage:
          json['preferredLanguage'] ?? json['preferred_language'],
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.parse(json['lastLoginAt'])
          : json['last_login_at'] != null
          ? DateTime.parse(json['last_login_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'address': address,
      'profileImage': profileImage,
      'role': role,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'preferredLanguage': preferredLanguage,
      'lastLoginAt': lastLoginAt?.toIso8601String(),
    };
  }

  User copyWith({
    int? id,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? address,
    String? profileImage,
    String? role,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? preferredLanguage,
    DateTime? lastLoginAt,
  }) {
    return User(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      profileImage: profileImage ?? this.profileImage,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  // Helper getters
  String get fullName => '$firstName $lastName';
  String get displayName => fullName;
  String get initials =>
      '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}';

  bool get isAdmin => role.toLowerCase() == 'admin';
  bool get isManager => role.toLowerCase() == 'manager';
  bool get isCustomer => role.toLowerCase() == 'customer';
  bool get isDeliveryManager => role.toLowerCase() == 'delivery_manager';

  String get roleDisplay {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Administrator';
      case 'manager':
        return 'Manager';
      case 'customer':
        return 'Customer';
      case 'delivery_manager':
        return 'Delivery Manager';
      default:
        return role;
    }
  }

  String get statusDisplay => isActive ? 'Active' : 'Inactive';

  String get contactInfo {
    if (phone != null && phone!.isNotEmpty) {
      return '$email • $phone';
    }
    return email;
  }
}

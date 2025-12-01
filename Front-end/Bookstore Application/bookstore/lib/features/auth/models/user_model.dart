import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

@JsonSerializable()
class User {
  final int? id;
  final String email;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? profilePicture;
  final String userType;
  final bool isActive;
  final bool isVerified;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;
  final Map<String, dynamic>? preferences;
  final String? address;
  final String? city;
  final String? zipCode;
  final String? country;
  final DateTime? dateOfBirth;
  final String? preferredLanguage;
  final String? deliveryStatus; // For delivery administrators

  const User({
    this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.profilePicture,
    required this.userType,
    this.isActive = true,
    this.isVerified = false,
    this.createdAt,
    this.updatedAt,
    this.lastLoginAt,
    this.preferences,
    this.address,
    this.city,
    this.zipCode,
    this.country,
    this.dateOfBirth,
    this.preferredLanguage,
    this.deliveryStatus,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);

  // Computed properties
  String get fullName => '$firstName $lastName';
  String get displayName => fullName;
  String get initials => '${firstName[0]}${lastName[0]}'.toUpperCase();

  bool get isCustomer => userType == 'customer';
  bool get isLibraryManager => userType == 'library_admin';
  bool get isDeliveryManager => userType == 'delivery_admin';
  bool get isAdmin => userType == 'admin';

  // User type constants
  static const String typeCustomer = 'customer';
  static const String typeLibraryAdmin = 'library_admin';
  static const String typeDeliveryAdmin = 'delivery_admin';
  static const String typeAdmin = 'admin';

  // User type choices
  static const List<Map<String, String>> userTypeChoices = [
    {'value': 'customer', 'label': 'Customer'},
    {'value': 'library_admin', 'label': 'Library Manager'},
    {'value': 'delivery_admin', 'label': 'Delivery Manager'},
    {'value': 'admin', 'label': 'Admin'},
  ];

  User copyWith({
    int? id,
    String? email,
    String? firstName,
    String? lastName,
    String? phone,
    String? profilePicture,
    String? userType,
    bool? isActive,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
    Map<String, dynamic>? preferences,
    String? address,
    String? city,
    String? zipCode,
    String? country,
    DateTime? dateOfBirth,
    String? preferredLanguage,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      profilePicture: profilePicture ?? this.profilePicture,
      userType: userType ?? this.userType,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      preferences: preferences ?? this.preferences,
      address: address ?? this.address,
      city: city ?? this.city,
      zipCode: zipCode ?? this.zipCode,
      country: country ?? this.country,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'User(id: $id, email: $email, fullName: $fullName, userType: $userType)';
  }
}

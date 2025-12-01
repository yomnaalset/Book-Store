import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
class User {
  final int id;
  final String email;
  @JsonKey(name: 'first_name')
  final String firstName;
  @JsonKey(name: 'last_name')
  final String lastName;
  @JsonKey(name: 'user_type')
  final String userType;
  @JsonKey(name: 'preferred_language')
  final String preferredLanguage;
  @JsonKey(name: 'profile_picture')
  final String? profilePicture;
  @JsonKey(name: 'date_joined')
  final String dateJoined;
  @JsonKey(name: 'is_active')
  final bool isActive;

  User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.userType,
    required this.preferredLanguage,
    this.profilePicture,
    required this.dateJoined,
    required this.isActive,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);

  String get fullName => '$firstName $lastName';
  
  // Compatibility method
  String getFullName() => fullName;

  bool get isCustomer => userType == 'customer';
  bool get isLibraryAdmin => userType == 'library_admin';
  bool get isDeliveryAdmin => userType == 'delivery_admin';
}

@JsonSerializable()
class AuthResponse {
  final String? token;
  final String? refresh;
  final User? user;
  final String? message;
  final Map<String, dynamic>? errors;

  AuthResponse({
    this.token,
    this.refresh,
    this.user,
    this.message,
    this.errors,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseFromJson(json);
  Map<String, dynamic> toJson() => _$AuthResponseToJson(this);

  bool get isSuccess =>
      user != null; // For registration, we only need a user (no token required)
}

@JsonSerializable()
class RegisterRequest {
  final String email;
  @JsonKey(name: 'first_name')
  final String firstName;
  @JsonKey(name: 'last_name')
  final String lastName;
  final String password;
  @JsonKey(name: 'password_confirm')
  final String passwordConfirm;
  @JsonKey(name: 'user_type')
  final String userType;
  @JsonKey(name: 'preferred_language')
  final String? preferredLanguage;

  RegisterRequest({
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.password,
    required this.passwordConfirm,
    required this.userType,
    this.preferredLanguage,
  });

  factory RegisterRequest.fromJson(Map<String, dynamic> json) =>
      _$RegisterRequestFromJson(json);
  Map<String, dynamic> toJson() => _$RegisterRequestToJson(this);
}

@JsonSerializable()
class LoginRequest {
  final String email;
  final String password;

  LoginRequest({required this.email, required this.password});

  factory LoginRequest.fromJson(Map<String, dynamic> json) =>
      _$LoginRequestFromJson(json);
  Map<String, dynamic> toJson() => _$LoginRequestToJson(this);
}

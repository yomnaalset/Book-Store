import 'package:json_annotation/json_annotation.dart';
import 'user_model.dart';

part 'auth_response.g.dart';

@JsonSerializable()
class AuthResponse {
  final bool success;
  final String message;
  final User? user;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final Map<String, dynamic>? errors;

  const AuthResponse({
    required this.success,
    required this.message,
    this.user,
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.errors,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseFromJson(json);
  Map<String, dynamic> toJson() => _$AuthResponseToJson(this);

  bool get isSuccess => success;
  bool get hasUser => user != null;
  bool get hasToken => accessToken != null && accessToken!.isNotEmpty;
  bool get isTokenExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  @override
  String toString() {
    return 'AuthResponse(success: $success, message: $message, hasUser: $hasUser, hasToken: $hasToken)';
  }
}

class LoginRequest {
  final String email;
  final String password;
  final bool rememberMe;

  LoginRequest({
    required this.email,
    required this.password,
    this.rememberMe = false,
  });

  Map<String, dynamic> toJson() {
    return {'email': email, 'password': password, 'remember_me': rememberMe};
  }
}

class RegisterRequest {
  final String name;
  final String email;
  final String password;
  final String confirmPassword;
  final String? phone;
  final String? address;
  final String role;

  RegisterRequest({
    required this.name,
    required this.email,
    required this.password,
    required this.confirmPassword,
    this.phone,
    this.address,
    this.role = 'customer',
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'password': password,
      'password_confirmation': confirmPassword,
      'phone': phone,
      'address': address,
      'role': role,
    };
  }

  // Validation
  bool get isValid {
    return name.isNotEmpty &&
        email.isNotEmpty &&
        password.isNotEmpty &&
        password == confirmPassword &&
        _isValidEmail(email) &&
        password.length >= 6;
  }

  String? get validationError {
    if (name.isEmpty) return 'Name is required';
    if (email.isEmpty) return 'Email is required';
    if (!_isValidEmail(email)) return 'Invalid email format';
    if (password.isEmpty) return 'Password is required';
    if (password.length < 6) return 'Password must be at least 6 characters';
    if (password != confirmPassword) return 'Passwords do not match';
    return null;
  }

  bool _isValidEmail(String email) {
    // ignore: deprecated_member_use
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
}

class ForgotPasswordRequest {
  final String email;

  ForgotPasswordRequest({required this.email});

  Map<String, dynamic> toJson() {
    return {'email': email};
  }
}

class ResetPasswordRequest {
  final String email;
  final String token;
  final String password;
  final String confirmPassword;

  ResetPasswordRequest({
    required this.email,
    required this.token,
    required this.password,
    required this.confirmPassword,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'token': token,
      'password': password,
      'password_confirmation': confirmPassword,
    };
  }

  bool get isValid {
    return email.isNotEmpty &&
        token.isNotEmpty &&
        password.isNotEmpty &&
        password == confirmPassword &&
        password.length >= 6;
  }
}

class ChangePasswordRequest {
  final String currentPassword;
  final String newPassword;
  final String confirmPassword;

  ChangePasswordRequest({
    required this.currentPassword,
    required this.newPassword,
    required this.confirmPassword,
  });

  Map<String, dynamic> toJson() {
    return {
      'current_password': currentPassword,
      'new_password': newPassword,
      'new_password_confirmation': confirmPassword,
    };
  }

  bool get isValid {
    return currentPassword.isNotEmpty &&
        newPassword.isNotEmpty &&
        newPassword == confirmPassword &&
        newPassword.length >= 6 &&
        currentPassword != newPassword;
  }
}

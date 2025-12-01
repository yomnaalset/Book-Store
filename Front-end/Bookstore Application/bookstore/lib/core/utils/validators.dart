class Validators {
  // Email validation
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    // ignore: deprecated_member_use
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  // Password validation
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  // Phone validation
  static String? phone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    // ignore: deprecated_member_use
    final phoneRegex = RegExp(r'^\+?[1-9]\d{1,14}$');
    if (!phoneRegex.hasMatch(value.replaceAll(' ', ''))) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  // Optional phone validation
  static String? optionalPhone(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field, so empty is valid
    }
    // ignore: deprecated_member_use
    final phoneRegex = RegExp(r'^\+?[1-9]\d{1,14}$');
    if (!phoneRegex.hasMatch(value.replaceAll(' ', ''))) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  // Required field validation
  static String? required(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) {
      return '${fieldName ?? 'This field'} is required';
    }
    return null;
  }

  // Name validation
  static String? name(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }
    if (value.length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  // URL validation
  static String? url(String? value) {
    if (value == null || value.isEmpty) {
      return 'URL is required';
    }
    // ignore: deprecated_member_use
    final urlRegex = RegExp(
      r'^https?:\/\/[\w\-]+(\.[\w\-]+)+([\w\-\.,@?^=%&:/~\+#]*[\w\-\@?^=%&/~\+#])?$',
    );
    if (!urlRegex.hasMatch(value)) {
      return 'Please enter a valid URL';
    }
    return null;
  }

  // OTP validation
  static String? otp(String? value) {
    if (value == null || value.isEmpty) {
      return 'OTP is required';
    }
    if (value.length != 6) {
      return 'OTP must be 6 digits';
    }
    // ignore: deprecated_member_use
    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      return 'OTP must contain only numbers';
    }
    return null;
  }

  // Amount validation
  static String? amount(String? value) {
    if (value == null || value.isEmpty) {
      return 'Amount is required';
    }
    final amount = double.tryParse(value);
    if (amount == null) {
      return 'Please enter a valid amount';
    }
    if (amount < 0) {
      return 'Amount cannot be negative';
    }
    return null;
  }

  // Quantity validation
  static String? quantity(String? value) {
    if (value == null || value.isEmpty) {
      return 'Quantity is required';
    }
    final quantity = int.tryParse(value);
    if (quantity == null) {
      return 'Please enter a valid quantity';
    }
    if (quantity < 1) {
      return 'Quantity must be at least 1';
    }
    return null;
  }

  // Rating validation
  static String? rating(String? value) {
    if (value == null || value.isEmpty) {
      return 'Rating is required';
    }
    final rating = double.tryParse(value);
    if (rating == null) {
      return 'Please enter a valid rating';
    }
    if (rating < 1 || rating > 5) {
      return 'Rating must be between 1 and 5';
    }
    return null;
  }

  // Confirm password validation
  static String? confirmPassword(String? value, String? password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  // Min length validation
  static String? minLength(String? value, int minLength) {
    if (value == null || value.isEmpty) {
      return 'This field is required';
    }
    if (value.length < minLength) {
      return 'Must be at least $minLength characters';
    }
    return null;
  }

  // Max length validation
  static String? maxLength(String? value, int maxLength) {
    if (value != null && value.length > maxLength) {
      return 'Must be no more than $maxLength characters';
    }
    return null;
  }

  // Range validation
  static String? range(String? value, double min, double max) {
    if (value == null || value.isEmpty) {
      return 'This field is required';
    }
    final numValue = double.tryParse(value);
    if (numValue == null) {
      return 'Please enter a valid number';
    }
    if (numValue < min || numValue > max) {
      return 'Must be between $min and $max';
    }
    return null;
  }

  // Date validation
  static String? date(String? value) {
    if (value == null || value.isEmpty) {
      return 'Date is required';
    }
    final date = DateTime.tryParse(value);
    if (date == null) {
      return 'Please enter a valid date';
    }
    return null;
  }

  // Future date validation
  static String? futureDate(String? value) {
    final dateError = date(value);
    if (dateError != null) return dateError;

    final parsedDate = DateTime.parse(value!);
    if (parsedDate.isBefore(DateTime.now())) {
      return 'Date must be in the future';
    }
    return null;
  }

  // Past date validation
  static String? pastDate(String? value) {
    final dateError = date(value);
    if (dateError != null) return dateError;

    final parsedDate = DateTime.parse(value!);
    if (parsedDate.isAfter(DateTime.now())) {
      return 'Date must be in the past';
    }
    return null;
  }
}

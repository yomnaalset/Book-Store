import 'package:intl/intl.dart';

class Formatters {
  // Date formatters
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat _fullDateFormat = DateFormat('EEEE, MMMM d, y');
  static final DateFormat _shortDateFormat = DateFormat('MMM d, y');
  static final DateFormat _isoFormat = DateFormat('yyyy-MM-dd');

  // Currency formatters
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: '\$',
  );
  static final NumberFormat _currencyFormatNoSymbol = NumberFormat.currency(
    symbol: '',
  );

  // Number formatters
  static final NumberFormat _numberFormat = NumberFormat('#,##0');
  static final NumberFormat _decimalFormat = NumberFormat('#,##0.00');
  static final NumberFormat _percentFormat = NumberFormat.percentPattern();

  // Date formatting
  static String formatDate(DateTime date) {
    return _dateFormat.format(date);
  }

  static String formatTime(DateTime time) {
    return _timeFormat.format(time);
  }

  static String formatDateTime(DateTime dateTime) {
    return _dateTimeFormat.format(dateTime);
  }

  static String formatFullDate(DateTime date) {
    return _fullDateFormat.format(date);
  }

  static String formatShortDate(DateTime date) {
    return _shortDateFormat.format(date);
  }

  static String formatISODate(DateTime date) {
    return _isoFormat.format(date);
  }

  // Relative time formatting
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years year${years == 1 ? '' : 's'} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months == 1 ? '' : 's'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  // Currency formatting
  static String formatCurrency(double amount) {
    return _currencyFormat.format(amount);
  }

  static String formatCurrencyNoSymbol(double amount) {
    return _currencyFormatNoSymbol.format(amount);
  }

  static String formatCurrencyCompact(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      return amount.toStringAsFixed(0);
    }
  }

  // Number formatting
  static String formatNumber(int number) {
    return _numberFormat.format(number);
  }

  static String formatDecimal(double number) {
    return _decimalFormat.format(number);
  }

  static String formatPercent(double number) {
    return _percentFormat.format(number);
  }

  // Phone number formatting
  static String formatPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    // ignore: deprecated_member_use
    final digits = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    if (digits.length == 10) {
      return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
    } else if (digits.length == 11 && digits.startsWith('1')) {
      return '+1 (${digits.substring(1, 4)}) ${digits.substring(4, 7)}-${digits.substring(7)}';
    } else {
      return phoneNumber; // Return original if format is not recognized
    }
  }

  // File size formatting
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  // Duration formatting
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  // Duration formatting (short)
  static String formatDurationShort(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  // Text formatting
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  static String capitalizeWords(String text) {
    return text.split(' ').map((word) => capitalize(word)).join(' ');
  }

  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  static String truncateWords(String text, int maxWords) {
    final words = text.split(' ');
    if (words.length <= maxWords) return text;
    return '${words.take(maxWords).join(' ')}...';
  }

  // Address formatting
  static String formatAddress({
    String? street,
    String? city,
    String? state,
    String? zipCode,
    String? country,
  }) {
    final parts = <String>[];

    if (street != null && street.isNotEmpty) parts.add(street);
    if (city != null && city.isNotEmpty) parts.add(city);
    if (state != null && state.isNotEmpty) parts.add(state);
    if (zipCode != null && zipCode.isNotEmpty) parts.add(zipCode);
    if (country != null && country.isNotEmpty) parts.add(country);

    return parts.join(', ');
  }

  // ISBN formatting
  static String formatISBN(String isbn) {
    // Remove all non-digit characters
    // ignore: deprecated_member_use
    final digits = isbn.replaceAll(RegExp(r'[^\d]'), '');

    if (digits.length == 10) {
      return '${digits.substring(0, 1)}-${digits.substring(1, 4)}-${digits.substring(4, 9)}-${digits.substring(9)}';
    } else if (digits.length == 13) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 4)}-${digits.substring(4, 7)}-${digits.substring(7, 12)}-${digits.substring(12)}';
    } else {
      return isbn; // Return original if format is not recognized
    }
  }

  // Credit card formatting
  static String formatCreditCard(String cardNumber) {
    // Remove all non-digit characters
    // ignore: deprecated_member_use
    final digits = cardNumber.replaceAll(RegExp(r'[^\d]'), '');

    if (digits.length == 16) {
      return '${digits.substring(0, 4)} ${digits.substring(4, 8)} ${digits.substring(8, 12)} ${digits.substring(12)}';
    } else if (digits.length == 15) {
      return '${digits.substring(0, 4)} ${digits.substring(4, 10)} ${digits.substring(10)}';
    } else {
      return cardNumber; // Return original if format is not recognized
    }
  }

  // Mask sensitive data
  static String maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;

    final username = parts[0];
    final domain = parts[1];

    if (username.length <= 2) return email;

    final maskedUsername =
        '${username[0]}${'*' * (username.length - 2)}${username[username.length - 1]}';
    return '$maskedUsername@$domain';
  }

  static String maskPhone(String phone) {
    // ignore: deprecated_member_use
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 4) return phone;

    final visibleDigits = digits.substring(digits.length - 4);
    final maskedDigits = '*' * (digits.length - 4);
    return '$maskedDigits$visibleDigits';
  }

  static String maskCreditCard(String cardNumber) {
    // ignore: deprecated_member_use
    final digits = cardNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 4) return cardNumber;

    final visibleDigits = digits.substring(digits.length - 4);
    final maskedDigits = '*' * (digits.length - 4);
    return '$maskedDigits$visibleDigits';
  }
}

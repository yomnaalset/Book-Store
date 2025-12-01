class User {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final String? address;
  final String? city;
  final String? profileImageUrl;
  final DateTime? dateJoined;
  final bool isActive;
  final String? role;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    this.address,
    this.city,
    this.profileImageUrl,
    this.dateJoined,
    this.isActive = true,
    this.role,
  });

  String get name => '$firstName $lastName';
  String get fullName => name;

  factory User.fromJson(Map<String, dynamic> json) {
    // Handle full_name if provided, otherwise use first_name and last_name
    String firstName = '';
    String lastName = '';

    // Prioritize first_name and last_name if both are available
    final jsonFirstName = json['first_name'] ?? json['firstName'] ?? '';
    final jsonLastName = json['last_name'] ?? json['lastName'] ?? '';

    if (jsonFirstName.toString().trim().isNotEmpty ||
        jsonLastName.toString().trim().isNotEmpty) {
      // Use first_name and last_name directly if available
      firstName = jsonFirstName.toString().trim();
      lastName = jsonLastName.toString().trim();
    } else if (json['full_name'] != null &&
        json['full_name'].toString().isNotEmpty) {
      // If full_name is provided and first/last are not, try to split it
      final fullName = json['full_name'].toString().trim();
      // Don't use email as full_name
      if (!fullName.contains('@') && fullName.isNotEmpty) {
        final nameParts = fullName.split(' ');
        if (nameParts.length >= 2) {
          firstName = nameParts[0];
          lastName = nameParts.sublist(1).join(' ');
        } else if (nameParts.length == 1) {
          firstName = nameParts[0];
          lastName = '';
        }
      }
    }

    return User(
      id: json['id'] ?? 0,
      firstName: firstName,
      lastName: lastName,
      email: json['email'] ?? '',
      phone: json['phone'],
      address: json['address'],
      city: json['city'],
      profileImageUrl: json['profile_image_url'] ?? json['profileImageUrl'],
      dateJoined: json['date_joined'] != null
          ? DateTime.parse(json['date_joined'])
          : null,
      isActive: json['is_active'] ?? json['isActive'] ?? true,
      role: json['role'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'address': address,
      'city': city,
      'profile_image_url': profileImageUrl,
      'date_joined': dateJoined?.toIso8601String(),
      'is_active': isActive,
      'role': role,
    };
  }
}

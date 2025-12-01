class UserAddress {
  final String id;
  final String title;
  final String address;
  final String city;
  final String state;
  final String postalCode;
  final String phone;
  final bool isDefault;

  const UserAddress({
    required this.id,
    required this.title,
    required this.address,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.phone,
    this.isDefault = false,
  });

  String get fullAddress => '$address, $city, $state $postalCode';

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'address': address,
    'city': city,
    'state': state,
    'postal_code': postalCode,
    'phone': phone,
    'is_default': isDefault,
  };

  factory UserAddress.fromJson(Map<String, dynamic> json) => UserAddress(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    address: json['address'] ?? '',
    city: json['city'] ?? '',
    state: json['state'] ?? '',
    postalCode: json['postal_code'] ?? '',
    phone: json['phone'] ?? '',
    isDefault: json['is_default'] ?? false,
  );
}

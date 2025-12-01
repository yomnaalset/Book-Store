class Library {
  final int? id;
  final String name;
  final String address;
  final String openingHours;
  final String contactInformation;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Library({
    this.id,
    required this.name,
    required this.address,
    required this.openingHours,
    required this.contactInformation,
    this.createdAt,
    this.updatedAt,
  });

  factory Library.fromJson(Map<String, dynamic> json) {
    return Library(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      openingHours: json['opening_hours'],
      contactInformation: json['contact_information'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'opening_hours': openingHours,
      'contact_information': contactInformation,
    };
  }

  Library copyWith({
    int? id,
    String? name,
    String? address,
    String? openingHours,
    String? contactInformation,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Library(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      openingHours: openingHours ?? this.openingHours,
      contactInformation: contactInformation ?? this.contactInformation,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
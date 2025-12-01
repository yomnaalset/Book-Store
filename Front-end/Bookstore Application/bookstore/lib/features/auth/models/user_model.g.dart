// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
  id: (json['id'] as num?)?.toInt(),
  email: json['email'] as String,
  firstName: json['firstName'] as String,
  lastName: json['lastName'] as String,
  phone: json['phone'] as String?,
  profilePicture: json['profilePicture'] as String?,
  userType: json['userType'] as String,
  isActive: json['isActive'] as bool? ?? true,
  isVerified: json['isVerified'] as bool? ?? false,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
  lastLoginAt: json['lastLoginAt'] == null
      ? null
      : DateTime.parse(json['lastLoginAt'] as String),
  preferences: json['preferences'] as Map<String, dynamic>?,
  address: json['address'] as String?,
  city: json['city'] as String?,
  zipCode: json['zipCode'] as String?,
  country: json['country'] as String?,
  dateOfBirth: json['dateOfBirth'] == null
      ? null
      : DateTime.parse(json['dateOfBirth'] as String),
  preferredLanguage: json['preferredLanguage'] as String?,
  deliveryStatus: json['deliveryStatus'] as String?,
);

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'firstName': instance.firstName,
  'lastName': instance.lastName,
  'phone': instance.phone,
  'profilePicture': instance.profilePicture,
  'userType': instance.userType,
  'isActive': instance.isActive,
  'isVerified': instance.isVerified,
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
  'lastLoginAt': instance.lastLoginAt?.toIso8601String(),
  'preferences': instance.preferences,
  'address': instance.address,
  'city': instance.city,
  'zipCode': instance.zipCode,
  'country': instance.country,
  'dateOfBirth': instance.dateOfBirth?.toIso8601String(),
  'preferredLanguage': instance.preferredLanguage,
  'deliveryStatus': instance.deliveryStatus,
};

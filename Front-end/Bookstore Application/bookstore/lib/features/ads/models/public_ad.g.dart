// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'public_ad.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PublicAd _$PublicAdFromJson(Map<String, dynamic> json) => PublicAd(
  id: json['id'] as int,
  title: json['title'] as String,
  content: json['content'] as String,
  imageUrl: json['imageUrl'] as String?,
  adType: json['adType'] as String,
  discountCode: json['discountCode'] as String?,
  startDate: DateTime.parse(json['startDate'] as String),
  endDate: DateTime.parse(json['endDate'] as String),
  status: json['status'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$PublicAdToJson(PublicAd instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'content': instance.content,
  'imageUrl': instance.imageUrl,
  'adType': instance.adType,
  'discountCode': instance.discountCode,
  'startDate': instance.startDate.toIso8601String(),
  'endDate': instance.endDate.toIso8601String(),
  'status': instance.status,
  'createdAt': instance.createdAt.toIso8601String(),
};

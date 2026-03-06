// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Order _$OrderFromJson(Map<String, dynamic> json) => _Order(
  id: (json['id'] as num?)?.toInt(),
  imagePath: json['imagePath'] as String? ?? '',
  shopName: json['shopName'] as String? ?? '',
  amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
  orderTime: json['orderTime'] as String?,
  orderNumber: json['orderNumber'] as String? ?? '',
  createdAt: json['createdAt'] as String? ?? '',
  updatedAt: json['updatedAt'] as String? ?? '',
);

Map<String, dynamic> _$OrderToJson(_Order instance) => <String, dynamic>{
  'id': ?instance.id,
  'imagePath': instance.imagePath,
  'shopName': instance.shopName,
  'amount': instance.amount,
  'orderTime': ?instance.orderTime,
  'orderNumber': instance.orderNumber,
  'createdAt': instance.createdAt,
  'updatedAt': instance.updatedAt,
};

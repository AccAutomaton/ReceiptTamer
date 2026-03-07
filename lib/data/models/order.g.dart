// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Order _$OrderFromJson(Map<String, dynamic> json) => _Order(
  id: (json['id'] as num?)?.toInt(),
  imagePath: json['image_path'] as String? ?? '',
  shopName: json['shop_name'] as String? ?? '',
  amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
  orderDate: json['order_date'] as String?,
  mealTime: json['meal_time'] as String?,
  orderNumber: json['order_number'] as String? ?? '',
  createdAt: json['created_at'] as String? ?? '',
  updatedAt: json['updated_at'] as String? ?? '',
);

Map<String, dynamic> _$OrderToJson(_Order instance) => <String, dynamic>{
  'id': ?instance.id,
  'image_path': instance.imagePath,
  'shop_name': instance.shopName,
  'amount': instance.amount,
  'order_date': ?instance.orderDate,
  'meal_time': ?instance.mealTime,
  'order_number': instance.orderNumber,
  'created_at': instance.createdAt,
  'updated_at': instance.updatedAt,
};

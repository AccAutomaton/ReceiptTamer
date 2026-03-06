// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invoice.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Invoice _$InvoiceFromJson(Map<String, dynamic> json) => _Invoice(
  id: (json['id'] as num?)?.toInt(),
  imagePath: json['imagePath'] as String? ?? '',
  orderId: (json['orderId'] as num?)?.toInt(),
  invoiceNumber: json['invoiceNumber'] as String? ?? '',
  invoiceDate: json['invoiceDate'] as String?,
  totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
  createdAt: json['createdAt'] as String? ?? '',
  updatedAt: json['updatedAt'] as String? ?? '',
);

Map<String, dynamic> _$InvoiceToJson(_Invoice instance) => <String, dynamic>{
  'id': ?instance.id,
  'imagePath': instance.imagePath,
  'orderId': ?instance.orderId,
  'invoiceNumber': instance.invoiceNumber,
  'invoiceDate': ?instance.invoiceDate,
  'totalAmount': instance.totalAmount,
  'createdAt': instance.createdAt,
  'updatedAt': instance.updatedAt,
};

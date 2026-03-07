// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invoice.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Invoice _$InvoiceFromJson(Map<String, dynamic> json) => _Invoice(
  id: (json['id'] as num?)?.toInt(),
  imagePath: json['image_path'] as String? ?? '',
  orderId: (json['order_id'] as num?)?.toInt(),
  invoiceNumber: json['invoice_number'] as String? ?? '',
  invoiceDate: json['invoice_date'] as String?,
  totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
  createdAt: json['created_at'] as String? ?? '',
  updatedAt: json['updated_at'] as String? ?? '',
);

Map<String, dynamic> _$InvoiceToJson(_Invoice instance) => <String, dynamic>{
  'id': ?instance.id,
  'image_path': instance.imagePath,
  'order_id': ?instance.orderId,
  'invoice_number': instance.invoiceNumber,
  'invoice_date': ?instance.invoiceDate,
  'total_amount': instance.totalAmount,
  'created_at': instance.createdAt,
  'updated_at': instance.updatedAt,
};

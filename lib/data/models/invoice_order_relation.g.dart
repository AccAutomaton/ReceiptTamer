// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invoice_order_relation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_InvoiceOrderRelation _$InvoiceOrderRelationFromJson(
  Map<String, dynamic> json,
) => _InvoiceOrderRelation(
  invoiceId: (json['invoice_id'] as num).toInt(),
  orderId: (json['order_id'] as num).toInt(),
);

Map<String, dynamic> _$InvoiceOrderRelationToJson(
  _InvoiceOrderRelation instance,
) => <String, dynamic>{
  'invoice_id': instance.invoiceId,
  'order_id': instance.orderId,
};

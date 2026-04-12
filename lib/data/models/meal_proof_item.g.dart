// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_proof_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MealProofItem _$MealProofItemFromJson(Map<String, dynamic> json) =>
    _MealProofItem(
      order: Order.fromJson(json['order'] as Map<String, dynamic>),
      invoice: json['invoice'] == null
          ? null
          : Invoice.fromJson(json['invoice'] as Map<String, dynamic>),
      proratedInvoiceAmount:
          (json['proratedInvoiceAmount'] as num?)?.toDouble() ?? 0.0,
      totalInvoiceAmount:
          (json['totalInvoiceAmount'] as num?)?.toDouble() ?? 0.0,
      isProRated: json['isProRated'] as bool? ?? false,
    );

Map<String, dynamic> _$MealProofItemToJson(_MealProofItem instance) =>
    <String, dynamic>{
      'order': instance.order,
      'invoice': instance.invoice,
      'proratedInvoiceAmount': instance.proratedInvoiceAmount,
      'totalInvoiceAmount': instance.totalInvoiceAmount,
      'isProRated': instance.isProRated,
    };

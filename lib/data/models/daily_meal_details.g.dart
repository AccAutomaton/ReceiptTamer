// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_meal_details.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DailyMealDetails _$DailyMealDetailsFromJson(Map<String, dynamic> json) =>
    _DailyMealDetails(
      date: json['date'] as String,
      breakfastPaid: (json['breakfastPaid'] as num?)?.toDouble() ?? 0.0,
      breakfastInvoice: (json['breakfastInvoice'] as num?)?.toDouble() ?? 0.0,
      lunchPaid: (json['lunchPaid'] as num?)?.toDouble() ?? 0.0,
      lunchInvoice: (json['lunchInvoice'] as num?)?.toDouble() ?? 0.0,
      dinnerPaid: (json['dinnerPaid'] as num?)?.toDouble() ?? 0.0,
      dinnerInvoice: (json['dinnerInvoice'] as num?)?.toDouble() ?? 0.0,
    );

Map<String, dynamic> _$DailyMealDetailsToJson(_DailyMealDetails instance) =>
    <String, dynamic>{
      'date': instance.date,
      'breakfastPaid': instance.breakfastPaid,
      'breakfastInvoice': instance.breakfastInvoice,
      'lunchPaid': instance.lunchPaid,
      'lunchInvoice': instance.lunchInvoice,
      'dinnerPaid': instance.dinnerPaid,
      'dinnerInvoice': instance.dinnerInvoice,
    };

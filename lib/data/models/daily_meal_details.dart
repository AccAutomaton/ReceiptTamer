import 'package:freezed_annotation/freezed_annotation.dart';

part 'daily_meal_details.freezed.dart';
part 'daily_meal_details.g.dart';

/// Daily meal details for export
/// Represents a single day's meal expense breakdown by meal time
/// Each meal has both paid amount (order amount) and invoice amount
@freezed
abstract class DailyMealDetails with _$DailyMealDetails {
  const factory DailyMealDetails({
    required String date, // Format: yyyy-MM-dd
    @Default(0.0) double breakfastPaid,
    @Default(0.0) double breakfastInvoice,
    @Default(0.0) double lunchPaid,
    @Default(0.0) double lunchInvoice,
    @Default(0.0) double dinnerPaid,
    @Default(0.0) double dinnerInvoice,
  }) = _DailyMealDetails;

  factory DailyMealDetails.fromJson(Map<String, dynamic> json) =>
      _$DailyMealDetailsFromJson(json);
}

/// Extension methods for DailyMealDetails
extension DailyMealDetailsX on DailyMealDetails {
  /// Get the date string for display (yyyy年MM月dd日)
  String get dateDisplay {
    try {
      final parts = date.split('-');
      if (parts.length >= 3) {
        return '${parts[0]}年${parts[1]}月${parts[2]}日';
      }
    } catch (e) {
      // ignore
    }
    return date;
  }

  /// Get total paid amount for the day
  double get totalPaid => breakfastPaid + lunchPaid + dinnerPaid;

  /// Get total invoice amount for the day
  double get totalInvoice => breakfastInvoice + lunchInvoice + dinnerInvoice;

  /// Check if this day has any meal records
  bool get hasAnyMeal => breakfastPaid > 0 || lunchPaid > 0 || dinnerPaid > 0;
}
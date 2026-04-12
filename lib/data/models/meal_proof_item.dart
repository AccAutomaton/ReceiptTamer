import 'package:freezed_annotation/freezed_annotation.dart';

import 'invoice.dart';
import 'order.dart';
import '../../core/utils/date_formatter.dart';

part 'meal_proof_item.freezed.dart';
part 'meal_proof_item.g.dart';

/// Meal proof item for export
/// Represents a single meal record with associated invoice information
@freezed
abstract class MealProofItem with _$MealProofItem {
  const factory MealProofItem({
    required Order order,
    Invoice? invoice,
    @Default(0.0) double proratedInvoiceAmount,
    @Default(0.0) double totalInvoiceAmount,
    @Default(false) bool isProRated,
  }) = _MealProofItem;

  factory MealProofItem.fromJson(Map<String, dynamic> json) =>
      _$MealProofItemFromJson(json);
}

/// Extension methods for MealProofItem
extension MealProofItemX on MealProofItem {
  /// Get the display string for invoice amount
  /// Format: "xx.xx元" or "xx.xx/xx.xx元" (if prorated)
  /// Returns empty string if no invoice associated
  String get invoiceAmountDisplay {
    if (invoice == null) return '';
    if (isProRated) {
      return '${proratedInvoiceAmount.toStringAsFixed(2)}/${totalInvoiceAmount.toStringAsFixed(2)}元';
    }
    return '${totalInvoiceAmount.toStringAsFixed(2)}元';
  }

  /// Get the date string for display (yyyy年MM月dd日)
  String get dateDisplay {
    final dateStr = order.orderDate;
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final parts = dateStr.split('-');
      if (parts.length >= 3) {
        return '${parts[0]}年${parts[1]}月${parts[2]}日';
      }
    } catch (e) {
      // ignore
    }
    return dateStr;
  }

  /// Get the meal time display string (早餐/午餐/晚餐)
  String get mealTimeDisplay {
    final mealTime = DateFormatter.mealTimeFromString(order.mealTime);
    return DateFormatter.mealTimeToDisplayName(mealTime);
  }

  /// Get the amount display string (实付xx.xx元)
  String get amountDisplay {
    return '实付${order.amount.toStringAsFixed(2)}元';
  }
}
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

/// Meal time enum for categorizing orders by time of day
enum MealTime {
  breakfast, // 早餐: 0:00-10:00
  lunch, // 午餐: 10:00-16:00
  dinner, // 晚餐: 16:00-24:00
}

/// Date formatting utility class
class DateFormatter {
  /// Format date for display (e.g., 2024年01月15日)
  static String formatDisplay(DateTime? date) {
    if (date == null) return '-';
    return DateFormat(AppConstants.dateFormatDisplay).format(date);
  }

  /// Format date with time for display (e.g., 2024年01月15日 14:30)
  static String formatDisplayWithTime(DateTime? date) {
    if (date == null) return '-';
    return DateFormat(AppConstants.dateFormatDisplayWithTime).format(date);
  }

  /// Format date for storage (e.g., 2024-01-15)
  static String formatStorage(DateTime date) {
    return DateFormat(AppConstants.dateFormatStorage).format(date);
  }

  /// Format date with time for storage (e.g., 2024-01-15 14:30:25)
  static String formatStorageWithTime(DateTime date) {
    return DateFormat(AppConstants.dateFormatStorageWithTime).format(date);
  }

  /// Format date for input fields (e.g., 2024/01/15)
  static String formatInput(DateTime date) {
    return DateFormat(AppConstants.dateFormatInput).format(date);
  }

  /// Parse date from storage format
  static DateTime? parseStorage(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    try {
      // Try parsing with time first
      var date = DateFormat(AppConstants.dateFormatStorageWithTime).parse(dateString, true);
      return date;
    } catch (e) {
      try {
        // Try parsing without time
        var date = DateFormat(AppConstants.dateFormatStorage).parse(dateString, true);
        return date;
      } catch (e) {
        return null;
      }
    }
  }

  /// Parse date from input format
  static DateTime? parseInput(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    try {
      return DateFormat(AppConstants.dateFormatInput).parse(dateString, true);
    } catch (e) {
      return null;
    }
  }

  /// Format amount with currency symbol
  static String formatAmount(double amount) {
    return '¥${amount.toStringAsFixed(2)}';
  }

  /// Format amount without currency symbol
  static String formatAmountPlain(double amount) {
    return amount.toStringAsFixed(2);
  }

  /// Get current timestamp as storage format string
  static String currentTimestamp() {
    return formatStorageWithTime(DateTime.now());
  }

  /// Get today's date as storage format string
  static String todayDate() {
    return formatStorage(DateTime.now());
  }

  /// Check if date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Check if date is within current month
  static bool isThisMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  /// Get month name in Chinese
  static String getMonthName(int month) {
    const months = [
      '一月', '二月', '三月', '四月', '五月', '六月',
      '七月', '八月', '九月', '十月', '十一月', '十二月'
    ];
    if (month < 1 || month > 12) return '';
    return months[month - 1];
  }

  /// Get date range for a month
  static (DateTime start, DateTime end) getMonthRange(int year, int month) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);
    return (start, end);
  }

  /// Get this month's date range
  static (DateTime start, DateTime end) getThisMonthRange() {
    final now = DateTime.now();
    return getMonthRange(now.year, now.month);
  }

  /// Get last month's date range
  static (DateTime start, DateTime end) getLastMonthRange() {
    final now = DateTime.now();
    if (now.month == 1) {
      return getMonthRange(now.year - 1, 12);
    }
    return getMonthRange(now.year, now.month - 1);
  }

  /// Get this year's date range
  static (DateTime start, DateTime end) getThisYearRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1);
    final end = DateTime(now.year, 12, 31, 23, 59, 59);
    return (start, end);
  }

  // ==================== MealTime helpers ====================

  /// Convert string to MealTime enum
  static MealTime? mealTimeFromString(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final e in MealTime.values) {
      if (e.name == value) return e;
    }
    return null;
  }

  /// Convert MealTime enum to display name in Chinese
  static String mealTimeToDisplayName(MealTime? mealTime) {
    switch (mealTime) {
      case MealTime.breakfast:
        return '早餐';
      case MealTime.lunch:
        return '午餐';
      case MealTime.dinner:
        return '晚餐';
      case null:
        return '-';
    }
  }

  /// Convert hour (0-23) to MealTime
  static MealTime fromHourToMealTime(int hour) {
    if (hour >= 0 && hour < 10) {
      return MealTime.breakfast;
    } else if (hour >= 10 && hour < 16) {
      return MealTime.lunch;
    } else {
      return MealTime.dinner;
    }
  }

  /// Parse datetime string and extract date and meal time
  /// Returns (date string in yyyy-MM-dd format, MealTime)
  static (String?, MealTime?) parseDateTimeToOrderDateAndMealTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return (null, null);

    final dateTime = parseStorage(dateTimeStr);
    if (dateTime == null) return (null, null);

    final dateString = formatStorage(dateTime);
    final mealTime = fromHourToMealTime(dateTime.hour);

    return (dateString, mealTime);
  }
}

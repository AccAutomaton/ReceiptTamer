import 'package:catering_receipt_recorder/data/models/order.dart';

/// Group orders by year and month
class MonthGroup {
  final int year;
  final int month;
  final List<Order> orders;

  const MonthGroup({
    required this.year,
    required this.month,
    required this.orders,
  });

  /// Calculate total amount of all orders in this group
  double get totalAmount => orders.fold(0.0, (sum, o) => sum + o.amount);

  /// Number of orders in this group
  int get count => orders.length;

  /// Display name like "2024年3月"
  String get displayName => '$year年$month月';

  /// Unique key for this group
  String get key => '$year-$month';
}
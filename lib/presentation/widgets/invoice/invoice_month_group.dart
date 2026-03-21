import 'package:receipt_tamer/data/models/invoice.dart';

/// Group invoices by year and month
class InvoiceMonthGroup {
  final int year;
  final int month;
  final List<Invoice> invoices;
  final Map<int, int> invoiceOrderCounts; // invoiceId -> order count

  const InvoiceMonthGroup({
    required this.year,
    required this.month,
    required this.invoices,
    this.invoiceOrderCounts = const {},
  });

  /// Calculate total amount of all invoices in this group
  double get totalAmount => invoices.fold(0.0, (sum, i) => sum + i.totalAmount);

  /// Number of invoices in this group
  int get count => invoices.length;

  /// Display name like "2024年3月"
  String get displayName => '$year年$month月';

  /// Unique key for this group
  String get key => '$year-$month';

  /// Get order count for a specific invoice
  int getOrderCount(int invoiceId) => invoiceOrderCounts[invoiceId] ?? 0;
}
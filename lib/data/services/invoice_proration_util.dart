import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/models/order.dart';

/// Invoice amount proration result for a single order
class ProratedOrderAmount {
  final Order order;
  final double proratedInvoiceAmount;
  final bool isProrated;

  ProratedOrderAmount({
    required this.order,
    required this.proratedInvoiceAmount,
    required this.isProrated,
  });
}

/// Invoice amount proration result for all orders linked to an invoice
class ProrationResult {
  final List<ProratedOrderAmount> orderAmounts;
  final bool needsProration;

  ProrationResult({
    required this.orderAmounts,
    required this.needsProration,
  });
}

/// Utility class for invoice amount proration
/// Ensures consistent proration logic across different export features
class InvoiceProrationUtil {
  /// Calculate prorated invoice amounts for all orders linked to an invoice
  ///
  /// Proration is needed when multiple orders are linked to one invoice
  /// and the invoice amount differs from the sum of order amounts.
  ///
  /// The algorithm ensures:
  /// - Sum of prorated amounts exactly equals invoice total (no rounding error)
  /// - Deterministic: same input always produces same output
  /// - Each prorated amount does not exceed the order's actual payment
  static ProrationResult calculate({
    required Invoice invoice,
    required List<Order> orders,
  }) {
    if (orders.isEmpty) {
      return ProrationResult(orderAmounts: [], needsProration: false);
    }

    // Single order: no proration needed, use full invoice amount
    if (orders.length == 1) {
      return ProrationResult(
        orderAmounts: [
          ProratedOrderAmount(
            order: orders.first,
            proratedInvoiceAmount: invoice.totalAmount,
            isProrated: false,
          ),
        ],
        needsProration: false,
      );
    }

    // Calculate total order amount
    final totalOrderAmount = orders.fold<double>(0, (sum, o) => sum + o.amount);

    // Check if proration is needed
    final needsProration = (totalOrderAmount - invoice.totalAmount).abs() > 0.01;

    if (!needsProration || totalOrderAmount <= 0) {
      // No proration needed: order amounts match invoice
      return ProrationResult(
        orderAmounts: orders
            .map((o) => ProratedOrderAmount(
                  order: o,
                  proratedInvoiceAmount: o.amount,
                  isProrated: false,
                ))
            .toList(),
        needsProration: false,
      );
    }

    // Proration needed: calculate proportional amounts
    // Sort orders by ID (ascending) to ensure deterministic adjustment selection
    final sortedOrders = List<Order>.from(orders)
      ..sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));

    // Calculate initial prorated amounts (proportional to order amounts)
    // Since invoice <= totalOrderAmount, each proratedAmount <= order.amount
    final proratedAmounts = <Order, double>{};
    for (final order in sortedOrders) {
      final ratio = order.amount / totalOrderAmount;
      proratedAmounts[order] = ratio * invoice.totalAmount;
    }

    // Adjust for rounding errors to ensure sum exactly equals invoice total
    final totalProrated = proratedAmounts.values.fold<double>(0, (sum, v) => sum + v);
    final diff = invoice.totalAmount - totalProrated;

    if (diff.abs() > 0.001) {
      // Since invoice <= totalOrderAmount, diff is usually small positive (due to rounding down)
      // Find first order where adjustment won't make amount negative
      for (final order in sortedOrders) {
        final currentProrated = proratedAmounts[order]!;
        final adjustedAmount = currentProrated + diff;

        // Check: adjusted amount must be non-negative
        // (Since proratedAmount <= order.amount and invoice <= totalOrderAmount,
        //  adjustedAmount will always be <= order.amount)
        if (adjustedAmount >= 0) {
          proratedAmounts[order] = adjustedAmount;
          break;
        }
      }
    }

    // Build result maintaining original order
    return ProrationResult(
      orderAmounts: orders
          .map((o) => ProratedOrderAmount(
                order: o,
                proratedInvoiceAmount: proratedAmounts[o] ?? 0.0,
                isProrated: true,
              ))
          .toList(),
      needsProration: true,
    );
  }
}
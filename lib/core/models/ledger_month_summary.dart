/// Lightweight, read-only summary used by paged ledger screens.
///
/// This is not persisted and does not change the database or backup schema.
class LedgerMonthSummary {
  const LedgerMonthSummary({
    required this.monthKey,
    required this.itemCount,
    required this.totalAmount,
    required this.linkedItemCount,
  });

  /// Calendar month in `yyyy-MM` format.
  final String monthKey;
  final int itemCount;
  final double totalAmount;
  final int linkedItemCount;

  int get pendingItemCount => itemCount - linkedItemCount;
}

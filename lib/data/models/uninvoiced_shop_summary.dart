/// Aggregated uninvoiced order information for one shop.
class UninvoicedShopSummary {
  final String shopKey;
  final String displayName;
  final int orderCount;
  final double totalAmount;

  const UninvoicedShopSummary({
    required this.shopKey,
    required this.displayName,
    required this.orderCount,
    required this.totalAmount,
  });

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is UninvoicedShopSummary &&
            other.shopKey == shopKey &&
            other.displayName == displayName &&
            other.orderCount == orderCount &&
            other.totalAmount == totalAmount;
  }

  @override
  int get hashCode =>
      Object.hash(shopKey, displayName, orderCount, totalAmount);
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/order.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../data/repositories/order_repository.dart';
import 'invoice_provider.dart';
import 'order_provider.dart';

/// One read-only order row shown on the home screen.
class RecentOrderItem {
  const RecentOrderItem({
    required this.id,
    required this.collectedAt,
    required this.title,
    required this.amount,
    required this.referenceNumber,
    required this.hasInvoice,
    this.mealTime,
  });

  final int? id;
  final DateTime? collectedAt;
  final String title;
  final double amount;
  final String referenceNumber;
  final bool hasInvoice;
  final String? mealTime;
}

/// Lightweight, read-only data required by the home screen.
class HomeOverview {
  const HomeOverview({
    required this.orderCount,
    required this.invoiceCount,
    required this.uninvoicedOrderCount,
    required this.uninvoicedShopCount,
    required this.recentOrders,
  });

  const HomeOverview.empty()
    : orderCount = 0,
      invoiceCount = 0,
      uninvoicedOrderCount = 0,
      uninvoicedShopCount = 0,
      recentOrders = const [];

  final int orderCount;
  final int invoiceCount;
  final int uninvoicedOrderCount;
  final int uninvoicedShopCount;
  final List<RecentOrderItem> recentOrders;
}

/// Loads the home overview without touching the state of either main ledger.
class HomeOverviewLoader {
  const HomeOverviewLoader({
    required OrderRepository orderRepository,
    required InvoiceRepository invoiceRepository,
  }) : _orderRepository = orderRepository,
       _invoiceRepository = invoiceRepository;

  static const recentOrderLimit = 10;

  final OrderRepository _orderRepository;
  final InvoiceRepository _invoiceRepository;

  Future<HomeOverview> load() async {
    final orderCountFuture = _orderRepository.getCount();
    final invoiceCountFuture = _invoiceRepository.getCount();
    final shopSummariesFuture = _orderRepository.getUninvoicedShopSummaries();
    final ordersFuture = _orderRepository.getRecentlyCreated(
      limit: recentOrderLimit,
    );

    final orders = await ordersFuture;

    final orderIds = orders
        .map((order) => order.id)
        .whereType<int>()
        .toList(growable: false);
    final orderRelationCountsFuture = _orderRepository
        .getInvoiceCountsForOrders(orderIds);

    final shopSummaries = await shopSummariesFuture;
    final orderRelationCounts = await orderRelationCountsFuture;

    final recentOrders = <RecentOrderItem>[
      for (final order in orders)
        _fromOrder(order, orderRelationCounts[order.id] ?? 0),
    ]..sort(_compareRecentOrders);

    return HomeOverview(
      orderCount: await orderCountFuture,
      invoiceCount: await invoiceCountFuture,
      uninvoicedOrderCount: shopSummaries.fold(
        0,
        (total, summary) => total + summary.orderCount,
      ),
      uninvoicedShopCount: shopSummaries.length,
      recentOrders: List.unmodifiable(recentOrders.take(recentOrderLimit)),
    );
  }

  static RecentOrderItem _fromOrder(Order order, int relationCount) {
    return RecentOrderItem(
      id: order.id,
      collectedAt: _parseCollectionTime(order.createdAt),
      title: order.shopName.trim().isEmpty ? '未命名店铺' : order.shopName.trim(),
      amount: order.amount,
      referenceNumber: order.orderNumber.trim(),
      hasInvoice: relationCount > 0,
      mealTime: order.mealTime,
    );
  }

  static DateTime? _parseCollectionTime(String value) {
    final parsed = DateTime.tryParse(value.trim());
    return parsed?.toLocal();
  }

  static int _compareRecentOrders(RecentOrderItem left, RecentOrderItem right) {
    final leftTime = left.collectedAt?.millisecondsSinceEpoch ?? -1;
    final rightTime = right.collectedAt?.millisecondsSinceEpoch ?? -1;
    final timeOrder = rightTime.compareTo(leftTime);
    if (timeOrder != 0) return timeOrder;

    return (right.id ?? -1).compareTo(left.id ?? -1);
  }
}

final homeOverviewProvider = FutureProvider<HomeOverview>((ref) {
  // Main ledgers remain independently loaded, but a completed mutation there
  // replaces the list instance. Watching only that identity refreshes the
  // read-only home projection without copying its data into either notifier.
  ref.watch(orderProvider.select((state) => state.orders));
  ref.watch(invoiceProvider.select((state) => state.invoices));

  return HomeOverviewLoader(
    orderRepository: ref.watch(orderRepositoryProvider),
    invoiceRepository: ref.watch(invoiceRepositoryProvider),
  ).load();
});

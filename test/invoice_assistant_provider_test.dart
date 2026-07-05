import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/data/models/uninvoiced_shop_summary.dart';
import 'package:receipt_tamer/data/repositories/order_repository.dart';
import 'package:receipt_tamer/presentation/providers/invoice_assistant_provider.dart';
import 'package:receipt_tamer/presentation/providers/order_provider.dart';

void main() {
  test('does not apply a default date range', () async {
    final repository = _FakeOrderRepository();
    final container = ProviderContainer(
      overrides: [orderRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final initialState = container.read(invoiceAssistantProvider);
    expect(initialState.startDate, isNull);
    expect(initialState.endDate, isNull);

    await container.read(invoiceAssistantProvider.notifier).loadSummaries();

    expect(repository.lastSummaryStartDate, isNull);
    expect(repository.lastSummaryEndDate, isNull);
  });

  test('loads shop summaries and cached orders for a selected shop', () async {
    final repository = _FakeOrderRepository();
    final container = ProviderContainer(
      overrides: [orderRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container
        .read(invoiceAssistantProvider.notifier)
        .loadSummaries(
          startDate: DateTime(2026, 6, 1),
          endDate: DateTime(2026, 6, 30),
        );

    var state = container.read(invoiceAssistantProvider);
    expect(state.summaries.map((summary) => summary.displayName), ['云上小馆']);
    expect(state.summaries.single.totalAmount, 36);

    await container
        .read(invoiceAssistantProvider.notifier)
        .loadOrdersForShop('云上小馆');

    state = container.read(invoiceAssistantProvider);
    expect(state.expandedShopKey, '云上小馆');
    expect(state.ordersByShop['云上小馆']!.map((order) => order.id), [2, 1]);
  });

  test(
    'selects orders from one shop and tracks selected total amount',
    () async {
      final repository = _FakeOrderRepository();
      final container = ProviderContainer(
        overrides: [orderRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container
          .read(invoiceAssistantProvider.notifier)
          .loadOrdersForShop('云上小馆');

      container
          .read(invoiceAssistantProvider.notifier)
          .toggleOrderSelection(shopKey: '云上小馆', order: repository.orders[0]);
      container
          .read(invoiceAssistantProvider.notifier)
          .selectAllForShop('云上小馆');

      final state = container.read(invoiceAssistantProvider);
      expect(state.selectedShopKey, '云上小馆');
      expect(state.selectedOrderIds, {1, 2});
      expect(state.selectedTotalAmount, 36);
    },
  );
}

class _FakeOrderRepository extends OrderRepository {
  DateTime? lastSummaryStartDate;
  DateTime? lastSummaryEndDate;

  final orders = [
    _order(id: 1, shopName: '云上小馆', amount: 12, orderDate: '2026-06-01'),
    _order(id: 2, shopName: '云上小馆', amount: 24, orderDate: '2026-06-12'),
  ];

  @override
  Future<List<UninvoicedShopSummary>> getUninvoicedShopSummaries({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    lastSummaryStartDate = startDate;
    lastSummaryEndDate = endDate;
    return const [
      UninvoicedShopSummary(
        shopKey: '云上小馆',
        displayName: '云上小馆',
        orderCount: 2,
        totalAmount: 36,
      ),
    ];
  }

  @override
  Future<List<Order>> getUninvoicedOrdersForShop(
    String shopKey, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return orders.reversed.toList();
  }
}

Order _order({
  required int id,
  required String shopName,
  required double amount,
  required String orderDate,
}) {
  return Order(
    id: id,
    imagePath: 'order_$id.jpg',
    shopName: shopName,
    amount: amount,
    orderDate: orderDate,
    mealTime: 'lunch',
    orderNumber: 'order-$id',
    createdAt: '${orderDate}T12:00:00',
    updatedAt: '${orderDate}T12:00:00',
  );
}

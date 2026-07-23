import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/data/repositories/invoice_repository.dart';
import 'package:receipt_tamer/data/repositories/order_repository.dart';
import 'package:receipt_tamer/presentation/providers/invoice_provider.dart';
import 'package:receipt_tamer/presentation/providers/order_provider.dart';
import 'package:receipt_tamer/presentation/screens/invoices/invoice_detail_screen.dart';
import 'package:receipt_tamer/presentation/screens/invoices/invoices_screen.dart';
import 'package:receipt_tamer/presentation/screens/invoices/order_selector_screen.dart';
import 'package:receipt_tamer/presentation/screens/orders/order_detail_screen.dart';
import 'package:receipt_tamer/presentation/screens/orders/invoice_selector_screen.dart';

void main() {
  testWidgets(
    'order selector totals include selected orders hidden by filters',
    (tester) async {
      final selectedOrder = _order(id: 1, amount: 42);
      final visibleOrder = _order(id: 2, amount: 8);
      final orderRepository = _FakeOrderRepository(
        records: {1: selectedOrder, 2: visibleOrder},
        visibleOrders: [visibleOrder],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orderRepositoryProvider.overrideWithValue(orderRepository),
          ],
          child: const MaterialApp(
            home: OrderSelectorScreen(selectedOrderIds: [1]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('已选择 1 个订单'), findsOneWidget);
      expect(find.text('合计: ¥42.00'), findsOneWidget);
      expect(find.text('Shop 1'), findsNothing);
      expect(find.text('Shop 2'), findsOneWidget);
    },
  );

  testWidgets(
    'linked order requires explicit transfer confirmation before selection',
    (tester) async {
      _useLargeTestSurface(tester);
      final linkedOrder = _order(id: 1, amount: 42);
      final sourceInvoice = _invoice(id: 7, invoiceNumber: 'SOURCE-7');
      final orderRepository = _FakeOrderRepository(
        records: {1: linkedOrder},
        visibleOrders: [linkedOrder],
        invoiceIdsByOrder: {
          1: {7},
        },
      );
      final invoiceRepository = _FakeInvoiceRepository(invoice: sourceInvoice);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orderRepositoryProvider.overrideWithValue(orderRepository),
            invoiceRepositoryProvider.overrideWithValue(invoiceRepository),
          ],
          child: const MaterialApp(home: OrderSelectorScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
      expect(find.text('当前关联：发票 SOURCE-7'), findsOneWidget);
      expect(find.text('转移关联'), findsOneWidget);
      expect(find.text('未选择订单'), findsOneWidget);

      await tester.tap(find.text('转移关联'));
      await tester.pumpAndSettle();

      expect(find.text('确认转移关联'), findsOneWidget);
      expect(find.text('这会把 1 笔订单从原发票移到 本次新发票，合计 ¥42.00。'), findsOneWidget);
      expect(find.text('发票 SOURCE-7  →  本次新发票'), findsOneWidget);

      await tester.tap(find.text('确认转移'));
      await tester.pumpAndSettle();

      expect(find.text('已选择 1 个订单'), findsOneWidget);
      expect(find.text('转移关联'), findsNothing);
    },
  );

  testWidgets('current invoice relation is not treated as a transfer', (
    tester,
  ) async {
    final linkedOrder = _order(id: 1, amount: 42);
    final currentInvoice = _invoice(id: 7);
    final orderRepository = _FakeOrderRepository(
      records: {1: linkedOrder},
      visibleOrders: [linkedOrder],
      invoiceIdsByOrder: {
        1: {7},
      },
    );
    final invoiceRepository = _FakeInvoiceRepository(invoice: currentInvoice);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderRepositoryProvider.overrideWithValue(orderRepository),
          invoiceRepositoryProvider.overrideWithValue(invoiceRepository),
        ],
        child: const MaterialApp(
          home: OrderSelectorScreen(selectedOrderIds: [1], excludeInvoiceId: 7),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('已选择 1 个订单'), findsOneWidget);
    expect(find.text('转移关联'), findsNothing);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNotNull);
  });

  testWidgets('order-side invoice selection also confirms relation transfer', (
    tester,
  ) async {
    _useLargeTestSurface(tester);
    final sourceInvoice = _invoice(
      id: 7,
      invoiceNumber: 'SOURCE-7',
      sellerName: '原销售方',
    );
    final targetInvoice = _invoice(
      id: 8,
      invoiceNumber: 'TARGET-8',
      sellerName: '目标销售方',
    );
    final orderRepository = _FakeOrderRepository(
      records: {1: _order(id: 1, amount: 36)},
      invoiceIdsByOrder: {
        1: {7},
      },
    );
    final invoiceRepository = _FakeInvoiceRepository(
      invoice: sourceInvoice,
      searchResults: [targetInvoice],
      orderIdsByInvoice: const {8: []},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderRepositoryProvider.overrideWithValue(orderRepository),
          invoiceRepositoryProvider.overrideWithValue(invoiceRepository),
        ],
        child: const MaterialApp(home: InvoiceSelectorScreen(orderId: 1)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('目标销售方'));
    await tester.pumpAndSettle();

    expect(find.text('确认转移关联'), findsOneWidget);
    expect(find.text('发票 SOURCE-7  →  发票 TARGET-8'), findsOneWidget);
    expect(invoiceRepository.updatedInvoiceId, isNull);

    await tester.tap(find.text('确认转移'));
    await tester.pumpAndSettle();

    expect(invoiceRepository.updatedInvoiceId, 8);
    expect(invoiceRepository.updatedOrderIds, [1]);
  });

  testWidgets('missing records show retryable detail states', (tester) async {
    final orderRepository = _FakeOrderRepository(records: {});
    final invoiceRepository = _FakeInvoiceRepository(invoice: null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [orderRepositoryProvider.overrideWithValue(orderRepository)],
        child: const MaterialApp(home: OrderDetailScreen(orderId: 404)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('订单不存在或已被删除'), findsOneWidget);
    expect(find.text('重新加载'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          invoiceRepositoryProvider.overrideWithValue(invoiceRepository),
        ],
        child: const MaterialApp(home: InvoiceDetailScreen(invoiceId: 404)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('发票不存在或已被删除'), findsOneWidget);
    expect(find.text('重新加载'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('detail screens explicitly show missing attachments', (
    tester,
  ) async {
    final orderRepository = _FakeOrderRepository(
      records: {1: _order(id: 1, imagePath: 'missing-order-image.jpg')},
    );
    final invoiceRepository = _FakeInvoiceRepository(
      invoice: _invoice(id: 7, imagePath: 'missing-invoice-image.jpg'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderRepositoryProvider.overrideWithValue(orderRepository),
          invoiceRepositoryProvider.overrideWithValue(invoiceRepository),
        ],
        child: const MaterialApp(home: OrderDetailScreen(orderId: 1)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('图片不存在'), findsOneWidget);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderRepositoryProvider.overrideWithValue(orderRepository),
          invoiceRepositoryProvider.overrideWithValue(invoiceRepository),
        ],
        child: const MaterialApp(home: InvoiceDetailScreen(invoiceId: 7)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('图片不存在'), findsOneWidget);
  });

  testWidgets('invoice detail reloads related orders after returning', (
    tester,
  ) async {
    _useLargeTestSurface(tester);
    final orderRepository = _FakeOrderRepository(records: {1: _order(id: 1)});
    final invoiceRepository = _FakeInvoiceRepository(
      invoice: _invoice(id: 7),
      orderIds: [1],
    );
    final router = GoRouter(
      initialLocation: '/invoices/7',
      routes: [
        GoRoute(
          path: '/invoices/:id',
          builder: (context, state) => const InvoiceDetailScreen(invoiceId: 7),
        ),
        GoRoute(
          path: '/orders/:id',
          builder: (context, state) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () {
                  orderRepository.records.remove(1);
                  context.pop();
                },
                child: const Text('删除模拟订单并返回'),
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderRepositoryProvider.overrideWithValue(orderRepository),
          invoiceRepositoryProvider.overrideWithValue(invoiceRepository),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Shop 1'), findsOneWidget);

    await tester.ensureVisible(find.text('Shop 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shop 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除模拟订单并返回'));
    await tester.pumpAndSettle();

    expect(find.text('Shop 1'), findsNothing);
  });

  testWidgets('invoice list uses one keyword for number-or-seller search', (
    tester,
  ) async {
    _useLargeTestSurface(tester);
    final invoiceRepository = _FakeInvoiceRepository(
      invoice: _invoice(id: 7, invoiceNumber: 'FP-7788'),
      searchResults: [_invoice(id: 7, invoiceNumber: 'FP-7788')],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          invoiceRepositoryProvider.overrideWithValue(invoiceRepository),
        ],
        child: const MaterialApp(home: InvoicesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();
    expect(find.text('输入销售方名称或发票号码'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'FP-7788');
    await tester.tap(find.text('搜索'));
    await tester.pumpAndSettle();

    expect(invoiceRepository.lastKeywordSearch, 'FP-7788');
    expect(find.text('发票号 FP-7788'), findsOneWidget);
  });
}

void _useLargeTestSurface(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1080, 1920);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Order _order({
  required int id,
  double amount = 10,
  String imagePath = 'missing-order.jpg',
}) {
  return Order(
    id: id,
    imagePath: imagePath,
    shopName: 'Shop $id',
    amount: amount,
    orderDate: '2026-07-17',
    mealTime: 'lunch',
    orderNumber: 'ORDER-$id',
    createdAt: '2026-07-17T12:00:00',
    updatedAt: '2026-07-17T12:00:00',
  );
}

Invoice _invoice({
  required int id,
  String imagePath = 'missing-invoice.jpg',
  String invoiceNumber = 'INVOICE-7',
  String sellerName = 'Seller',
}) {
  return Invoice(
    id: id,
    imagePath: imagePath,
    invoiceNumber: invoiceNumber,
    invoiceDate: '2026-07-17',
    totalAmount: 10,
    sellerName: sellerName,
    createdAt: '2026-07-17T12:00:00',
    updatedAt: '2026-07-17T12:00:00',
  );
}

class _FakeOrderRepository extends OrderRepository {
  _FakeOrderRepository({
    required this.records,
    this.visibleOrders = const [],
    this.invoiceIdsByOrder = const {},
  });

  final Map<int, Order> records;
  final List<Order> visibleOrders;
  final Map<int, Set<int>> invoiceIdsByOrder;

  @override
  Future<Order?> getById(int id) async => records[id];

  @override
  Future<List<Order>> getByIds(List<int> ids) async => [
    for (final id in ids)
      if (records[id] != null) records[id]!,
  ];

  @override
  Future<List<Order>> getAll({int? limit, int? offset}) async =>
      records.values.toList(growable: false);

  @override
  Future<List<int>> getInvoiceIdsForOrder(int orderId) async =>
      invoiceIdsByOrder[orderId]?.toList(growable: false) ?? const [];

  @override
  Future<Map<int, Set<int>>> getInvoiceIdsForOrders(List<int> orderIds) async {
    return {
      for (final orderId in orderIds) orderId: {...?invoiceIdsByOrder[orderId]},
    };
  }

  @override
  Future<List<Order>> searchWithInvoiceRelation({
    String? keyword,
    double? minAmount,
    double? maxAmount,
    DateTime? startDate,
    DateTime? endDate,
    bool? hasInvoice,
    int? excludeInvoiceId,
  }) async => visibleOrders;
}

class _FakeInvoiceRepository extends InvoiceRepository {
  _FakeInvoiceRepository({
    required this.invoice,
    this.orderIds = const [],
    this.searchResults = const [],
    this.orderIdsByInvoice = const {},
  });

  final Invoice? invoice;
  final List<int> orderIds;
  final List<Invoice> searchResults;
  final Map<int, List<int>> orderIdsByInvoice;
  String? lastKeywordSearch;
  int? updatedInvoiceId;
  List<int>? updatedOrderIds;

  @override
  Future<Invoice?> getById(int id) async => invoice?.id == id ? invoice : null;

  @override
  Future<List<int>> getOrderIdsForInvoice(int invoiceId) async =>
      List.of(orderIdsByInvoice[invoiceId] ?? orderIds);

  @override
  Future<int> getOrderCountForInvoice(int invoiceId) async =>
      (orderIdsByInvoice[invoiceId] ?? orderIds).length;

  @override
  Future<void> updateOrderRelations(int invoiceId, List<int> orderIds) async {
    updatedInvoiceId = invoiceId;
    updatedOrderIds = List.of(orderIds);
  }

  @override
  Future<List<Invoice>> getByOrderId(
    int orderId, {
    int? limit,
    int? offset,
  }) async => const [];

  @override
  Future<List<Invoice>> getAll({int? limit, int? offset}) async => const [];

  @override
  Future<Map<int, int>> getOrderCountsForInvoices(List<int> invoiceIds) async {
    return {for (final invoiceId in invoiceIds) invoiceId: 0};
  }

  @override
  Future<List<Invoice>> search({
    String? keyword,
    String? invoiceNumber,
    String? sellerName,
    int? orderId,
    double? minAmount,
    double? maxAmount,
    DateTime? startDate,
    DateTime? endDate,
    bool? hasLinkedOrder,
    int? limit,
    int? offset,
  }) async {
    lastKeywordSearch = keyword;
    return searchResults;
  }
}

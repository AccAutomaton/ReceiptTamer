import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:receipt_tamer/core/theme/app_theme.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/data/models/uninvoiced_shop_summary.dart';
import 'package:receipt_tamer/data/repositories/invoice_repository.dart';
import 'package:receipt_tamer/data/repositories/order_repository.dart';
import 'package:receipt_tamer/presentation/providers/home_overview_provider.dart';
import 'package:receipt_tamer/presentation/providers/invoice_provider.dart';
import 'package:receipt_tamer/presentation/providers/order_provider.dart';
import 'package:receipt_tamer/presentation/screens/home/home_screen.dart';
import 'package:receipt_tamer/presentation/widgets/common/scroll_edge_fog.dart';

void main() {
  test(
    'home loader keeps the latest ten orders and batches their relations',
    () async {
      final orders = List<Order>.generate(
        12,
        (index) => Order(
          id: index + 1,
          shopName: '订单店铺 ${index + 1}',
          amount: 10 + index.toDouble(),
          orderNumber: 'ORDER-${index + 1}',
          mealTime: 'lunch',
          createdAt:
              '2026-07-10T12:${(30 - index).toString().padLeft(2, '0')}:00',
        ),
      );
      final invoices = List<Invoice>.generate(
        7,
        (index) => Invoice(
          id: index + 101,
          sellerName: '发票销售方 ${index + 1}',
          totalAmount: 20 + index.toDouble(),
          invoiceNumber: 'INVOICE-${index + 1}',
          createdAt:
              '2026-07-10T12:${(19 - index * 2).toString().padLeft(2, '0')}:00',
        ),
      );
      final orderRepository = _HomeOrderRepository(orders);
      final invoiceRepository = _HomeInvoiceRepository(invoices);

      final overview = await HomeOverviewLoader(
        orderRepository: orderRepository,
        invoiceRepository: invoiceRepository,
      ).load();

      expect(
        orderRepository.requestedLimit,
        HomeOverviewLoader.recentOrderLimit,
      );
      expect(invoiceRepository.requestedLimit, isNull);
      expect(orderRepository.relationBatches, [
        orders.take(10).map((item) => item.id),
      ]);
      expect(invoiceRepository.relationBatches, isEmpty);
      expect(overview.orderCount, 12);
      expect(overview.invoiceCount, 7);
      expect(overview.uninvoicedShopCount, 2);
      expect(overview.uninvoicedOrderCount, 3);
      expect(overview.recentOrders, hasLength(10));
      expect(overview.recentOrders.map((item) => item.id), [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
      ]);
      expect(overview.recentOrders.first.hasInvoice, isTrue);
      expect(overview.recentOrders[1].hasInvoice, isFalse);
    },
  );

  test(
    'home projection refreshes after a main-ledger mutation completes',
    () async {
      final orderRepository = _HomeOrderRepository([
        const Order(
          id: 1,
          shopName: '原有订单',
          amount: 12,
          createdAt: '2026-07-10T12:00:00',
        ),
      ]);
      final invoiceRepository = _HomeInvoiceRepository(const []);
      final container = ProviderContainer(
        overrides: [
          orderRepositoryProvider.overrideWithValue(orderRepository),
          invoiceRepositoryProvider.overrideWithValue(invoiceRepository),
        ],
      );
      addTearDown(container.dispose);

      final initial = await container.read(homeOverviewProvider.future);
      orderRepository.items.add(
        const Order(
          id: 2,
          shopName: '新收录订单',
          amount: 18,
          createdAt: '2026-07-10T12:01:00',
        ),
      );
      await container.read(orderProvider.notifier).loadOrders();
      final refreshed = await container.read(homeOverviewProvider.future);

      expect(initial.orderCount, 1);
      expect(refreshed.orderCount, 2);
      expect(refreshed.recentOrders.first.id, 2);
    },
  );

  testWidgets(
    'home keeps one scroll, aligned assistant columns, ten orders, and both edge fogs',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = _router();
      addTearDown(router.dispose);
      await tester.pumpWidget(_testApp(router: router));
      await tester.pumpAndSettle();

      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(find.byKey(ScrollEdgeFog.topFogKey), findsOneWidget);
      expect(find.byKey(ScrollEdgeFog.bottomFogKey), findsOneWidget);
      expect(find.text('用餐证明导出'), findsOneWidget);
      expect(find.text('待关联订单'), findsOneWidget);
      expect(find.text('发票导出'), findsOneWidget);
      expect(find.text('报销材料导出'), findsNothing);
      expect(find.text('最近订单'), findsOneWidget);
      expect(find.text('最近收录'), findsNothing);
      expect(find.text('查看更多'), findsOneWidget);
      expect(find.text('10 条'), findsNothing);
      expect(
        find.byKey(const ValueKey('home-reimbursement-action')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('home-recent-orders-sheet')),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'recent-order-',
              ),
        ),
        findsNWidgets(10),
      );

      const assistantColumnKeys = [
        ValueKey('home-assistant-icon-column'),
        ValueKey('home-assistant-copy-column'),
        ValueKey('home-assistant-action-column'),
      ];
      const statisticColumnKeys = [
        ValueKey('home-order-stat-column'),
        ValueKey('home-invoice-stat-column'),
        ValueKey('home-uninvoiced-stat-column'),
      ];
      for (var index = 0; index < assistantColumnKeys.length; index++) {
        final assistantColumn = find.byKey(assistantColumnKeys[index]);
        final statisticColumn = find.byKey(statisticColumnKeys[index]);
        expect(
          tester.getSize(assistantColumn).width,
          closeTo(tester.getSize(statisticColumn).width, 0.1),
        );
        expect(
          tester.getCenter(assistantColumn).dx,
          closeTo(tester.getCenter(statisticColumn).dx, 0.1),
        );
      }
      expect(
        tester.getCenter(find.byIcon(Icons.receipt_long_outlined)).dx,
        closeTo(
          tester
              .getCenter(
                find.byKey(const ValueKey('home-assistant-icon-column')),
              )
              .dx,
          0.1,
        ),
      );

      final assistant = find.byKey(
        const ValueKey('home-invoice-assistant-action'),
      );
      expect(
        find.descendant(
          of: assistant,
          matching: find.byKey(const ValueKey('home-assistant-icon-seal')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: assistant,
          matching: find.byKey(const ValueKey('home-assistant-action-mark')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: assistant, matching: find.byType(VerticalDivider)),
        findsNothing,
      );
      final mealProof = find.byKey(const ValueKey('home-meal-proof-action'));
      final invoiceExport = find.byKey(
        const ValueKey('home-invoice-export-action'),
      );
      expect(
        tester.getTopLeft(assistant).dy,
        lessThan(tester.getTopLeft(mealProof).dy),
      );
      expect(
        tester.getTopLeft(mealProof).dy,
        closeTo(tester.getTopLeft(invoiceExport).dy, 0.1),
      );
      expect(
        tester.getTopLeft(mealProof).dx,
        lessThan(tester.getTopLeft(invoiceExport).dx),
      );
      final mealProofIcon = find.descendant(
        of: mealProof,
        matching: find.byIcon(Icons.restaurant_menu),
      );
      final invoiceExportArrow = find.descendant(
        of: invoiceExport,
        matching: find.byIcon(Icons.arrow_forward),
      );
      expect(
        tester.getTopLeft(mealProofIcon).dx - tester.getTopLeft(mealProof).dx,
        closeTo(12, 0.1),
      );
      expect(
        tester.getTopRight(invoiceExport).dx -
            tester.getTopRight(invoiceExportArrow).dx,
        closeTo(12, 0.1),
      );
      expect(
        tester.getSize(assistant).width,
        greaterThan(tester.getSize(mealProof).width),
      );

      final directoryBottom = tester
          .getBottomLeft(find.byKey(const ValueKey('home-directory-card')))
          .dy;
      final recentTop = tester
          .getTopLeft(find.byKey(const ValueKey('home-recent-orders-sheet')))
          .dy;
      expect(recentTop - directoryBottom, greaterThanOrEqualTo(13.5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('home routes every directory action and settings entry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_testApp(router: router));
    await tester.pumpAndSettle();

    const targets = <(ValueKey<String>, String)>[
      (ValueKey('home-recent-orders-more'), '/orders'),
      (ValueKey('home-meal-proof-action'), '/export/meal-proof'),
      (ValueKey('home-invoice-assistant-action'), '/invoice-assistant'),
      (ValueKey('home-invoice-export-action'), '/export/invoice'),
      (ValueKey('home-settings-action'), '/settings'),
    ];

    for (final (key, target) in targets) {
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
      expect(find.text('destination:$target'), findsOneWidget);

      router.go('/');
      await tester.pumpAndSettle();
    }
  });

  testWidgets('empty home presents the lightweight first-use checklist', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeOverviewProvider.overrideWithValue(
            const AsyncData(HomeOverview.empty()),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('home-first-use-checklist')),
      findsOneWidget,
    );
    expect(find.text('第一次使用，从这三步开始'), findsOneWidget);
    expect(find.text('导入一笔订单'), findsOneWidget);
    expect(find.text('选择识别方式'), findsOneWidget);
    expect(find.text('关联发票并导出'), findsOneWidget);
  });

  testWidgets('home reflows at 360px with 2.0 text scaling', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_testApp(router: router, textScale: 2));
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsOneWidget);
    expect(find.text('用餐证明导出'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-recent-orders-sheet')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Widget _testApp({required GoRouter router, double textScale = 1}) {
  return ProviderScope(
    overrides: [
      homeOverviewProvider.overrideWithValue(AsyncData(_fixtureOverview)),
    ],
    child: MaterialApp.router(
      theme: AppTheme.lightTheme,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  );
}

GoRouter _router() {
  Widget destination(BuildContext context, GoRouterState state) {
    return Scaffold(body: Center(child: Text('destination:${state.uri.path}')));
  }

  return GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/settings', builder: destination),
      GoRoute(path: '/invoice-assistant', builder: destination),
      GoRoute(path: '/export', builder: destination),
      GoRoute(path: '/export/meal-proof', builder: destination),
      GoRoute(path: '/export/invoice', builder: destination),
      GoRoute(path: '/orders', builder: destination),
      GoRoute(path: '/orders/:id', builder: destination),
      GoRoute(path: '/invoices/:id', builder: destination),
    ],
  );
}

final _fixtureOverview = HomeOverview(
  orderCount: 7,
  invoiceCount: 3,
  uninvoicedOrderCount: 3,
  uninvoicedShopCount: 2,
  recentOrders: List.unmodifiable(
    List<RecentOrderItem>.generate(
      10,
      (index) => RecentOrderItem(
        id: index + 1,
        collectedAt: DateTime(2026, 7, 10 - index),
        title: index.isEven ? '青禾餐食 · 测试店' : '云帆餐饮服务有限公司',
        amount: 20 + index.toDouble(),
        referenceNumber: 'ORDER-00$index',
        hasInvoice: index.isEven,
        mealTime: index.isEven ? 'lunch' : 'dinner',
      ),
    ),
  ),
);

class _HomeOrderRepository extends OrderRepository {
  _HomeOrderRepository(this.items);

  final List<Order> items;
  int? requestedLimit;
  final List<Iterable<int?>> relationBatches = [];

  @override
  Future<int> getCount() async => items.length;

  @override
  Future<List<Order>> getAll({int? limit, int? offset}) async {
    final start = (offset ?? 0).clamp(0, items.length);
    final end = limit == null
        ? items.length
        : (start + limit).clamp(start, items.length);
    return List<Order>.of(items.sublist(start, end));
  }

  @override
  Future<List<Order>> getRecentlyCreated({int limit = 10}) async {
    requestedLimit = limit;
    final sorted = [...items]
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return sorted.take(limit).toList(growable: false);
  }

  @override
  Future<List<UninvoicedShopSummary>> getUninvoicedShopSummaries({
    DateTime? startDate,
    DateTime? endDate,
  }) async => const [
    UninvoicedShopSummary(
      shopKey: 'A',
      displayName: '店铺 A',
      orderCount: 2,
      totalAmount: 20,
    ),
    UninvoicedShopSummary(
      shopKey: 'B',
      displayName: '店铺 B',
      orderCount: 1,
      totalAmount: 10,
    ),
  ];

  @override
  Future<Map<int, int>> getInvoiceCountsForOrders(List<int> orderIds) async {
    relationBatches.add(orderIds);
    return {for (final id in orderIds) id: id.isOdd ? 1 : 0};
  }
}

class _HomeInvoiceRepository extends InvoiceRepository {
  _HomeInvoiceRepository(this.items);

  final List<Invoice> items;
  int? requestedLimit;
  final List<Iterable<int?>> relationBatches = [];

  @override
  Future<int> getCount() async => items.length;

  @override
  Future<List<Invoice>> getRecentlyCreated({int limit = 10}) async {
    requestedLimit = limit;
    final sorted = [...items]
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return sorted.take(limit).toList(growable: false);
  }

  @override
  Future<Map<int, int>> getOrderCountsForInvoices(List<int> invoiceIds) async {
    relationBatches.add(invoiceIds);
    return {for (final id in invoiceIds) id: id.isOdd ? 2 : 0};
  }
}

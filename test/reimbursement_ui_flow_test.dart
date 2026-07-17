import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:receipt_tamer/core/theme/app_theme.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/data/models/uninvoiced_shop_summary.dart';
import 'package:receipt_tamer/data/repositories/invoice_repository.dart';
import 'package:receipt_tamer/data/repositories/order_repository.dart';
import 'package:receipt_tamer/presentation/providers/invoice_export_provider.dart';
import 'package:receipt_tamer/presentation/providers/invoice_provider.dart';
import 'package:receipt_tamer/presentation/providers/ledger_data_revision_provider.dart';
import 'package:receipt_tamer/presentation/providers/order_provider.dart';
import 'package:receipt_tamer/presentation/providers/export_provider.dart';
import 'package:receipt_tamer/presentation/providers/reimbursement_provider.dart';
import 'package:receipt_tamer/presentation/screens/export/export_options_screen.dart';
import 'package:receipt_tamer/presentation/screens/export/reimbursement_check_screen.dart';
import 'package:receipt_tamer/presentation/screens/export/reimbursement_screen.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_button.dart';
import 'package:receipt_tamer/presentation/widgets/main_shell.dart';
import 'package:receipt_tamer/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const storageChannel = MethodChannel('com.acautomaton.receipt.tamer/storage');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'update_last_check_time': DateTime.now().millisecondsSinceEpoch,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
          if (call.method == 'listSubDirectories') return <dynamic>[];
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  test('生产路由保持四个主分支，并把设置与报销子步骤放在壳外', () {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    final router = fixture.container.read(routerProvider);
    addTearDown(router.dispose);

    final rootRoutes = router.configuration.routes;
    final shell = rootRoutes.whereType<StatefulShellRoute>().single;
    expect(shell.branches, hasLength(4));
    expect(
      shell.branches.map((branch) => (branch.routes.single as GoRoute).path),
      <String>['/', '/orders', '/invoices', '/export'],
    );

    final reimbursementRoute = shell.branches.last.routes.single as GoRoute;
    expect(reimbursementRoute.name, 'export');

    final settingsRoute = rootRoutes.whereType<GoRoute>().singleWhere(
      (route) => route.path == '/settings',
    );
    expect(settingsRoute.name, 'settings');
    expect(
      shell.branches
          .expand((branch) => branch.routes)
          .whereType<GoRoute>()
          .any((route) => route.path == '/settings'),
      isFalse,
    );

    for (final path in <String>[
      '/export',
      '/export/check',
      '/export/options',
    ]) {
      expect(
        router.configuration.findMatch(Uri.parse(path)).isError,
        isFalse,
        reason: '$path 应该由生产路由直接匹配',
      );
    }
  });

  test('同票联动提示只统计本次实际新增和移除的订单', () async {
    final fixture = _Fixture(
      orders: <Order>[
        _order(1, '2026-07-12'),
        _order(2, '2026-07-11'),
        _order(3, '2026-07-10'),
        _order(4, '2026-07-09'),
        _order(5, '2026-07-08'),
      ],
      invoiceIdsByOrder: const <int, Set<int>>{
        1: <int>{101},
        2: <int>{101},
        3: <int>{102},
        4: <int>{102},
        5: <int>{102},
      },
      orderIdsByInvoice: const <int, Set<int>>{
        101: <int>{1, 2},
        102: <int>{3, 4, 5},
      },
    );
    addTearDown(fixture.dispose);
    final notifier = fixture.container.read(exportProvider.notifier);

    await notifier.loadAvailableOrders();

    expect(await notifier.toggleSelection(1), '另有 1 笔同票订单一并选中');
    expect(fixture.container.read(exportProvider).totalSelectedCount, 2);

    expect(await notifier.toggleSelection(3), '另有 2 笔同票订单一并选中');
    expect(fixture.container.read(exportProvider).totalSelectedCount, 5);

    expect(await notifier.toggleSelection(3), '另有 2 笔同票订单一并取消');
    expect(fixture.container.read(exportProvider).totalSelectedCount, 2);

    expect(await notifier.toggleSelection(1), '另有 1 笔同票订单一并取消');
    expect(fixture.container.read(exportProvider).totalSelectedCount, 0);
  });

  test('全选和反选按集合差值计算，并保持订单计数去重', () async {
    expect(
      const ExportState(
        selectedIds: <int>{1, 2},
        cascadeIds: <int>{2, 3},
      ).totalSelectedCount,
      3,
    );

    final fixture = _Fixture(
      orders: <Order>[
        _order(1, '2026-07-12'),
        _order(2, '2026-06-11'),
        _order(3, '2026-07-10'),
        _order(4, '2026-06-09'),
        _order(5, '2026-06-08'),
      ],
      invoiceIdsByOrder: const <int, Set<int>>{
        1: <int>{101},
        2: <int>{101},
        3: <int>{102},
        4: <int>{102},
        5: <int>{102},
      },
      orderIdsByInvoice: const <int, Set<int>>{
        101: <int>{1, 2},
        102: <int>{3, 4, 5},
      },
    );
    addTearDown(fixture.dispose);
    final notifier = fixture.container.read(exportProvider.notifier);

    await notifier.setDateRange(DateTime(2026, 7, 1), DateTime(2026, 7, 31));
    expect(await notifier.toggleSelection(1), '另有 1 笔同票订单一并选中');

    expect(await notifier.selectAll(), '另有 2 笔同票订单一并选中');
    expect(fixture.container.read(exportProvider).totalSelectedCount, 5);

    expect(await notifier.invertSelection(), isNull);
    expect(fixture.container.read(exportProvider).totalSelectedCount, 0);
  });

  testWidgets('生产路由打开报销、关联检查和无参数材料选项', (tester) async {
    _usePhoneViewport(tester);
    final fixture = _Fixture(
      orders: <Order>[
        _order(1, '2026-06-10'),
        _order(2, '2026-06-11'),
        _order(3, '2026-05-31'),
      ],
      invoiceIdsByOrder: const <int, Set<int>>{
        1: <int>{101},
        2: <int>{102},
      },
      orderIdsByInvoice: const <int, Set<int>>{
        101: <int>{1, 3},
        102: <int>{2},
      },
    );
    await fixture.notifier.initializeRange(
      DateTime(2026, 6, 1),
      DateTime(2026, 6, 30),
    );
    final router = fixture.container.read(routerProvider);

    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      router.dispose();
      fixture.dispose();
    });

    router.go('/export');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
        ),
      ),
    );
    await _pumpRoute(tester);

    expect(find.byType(MainShell), findsOneWidget);
    expect(find.byType(ReimbursementScreen), findsOneWidget);

    router.go('/export/check');
    await _pumpRoute(tester);
    expect(find.byType(ReimbursementCheckScreen), findsOneWidget);

    router.go('/export/options');
    await _pumpRoute(tester);
    expect(find.byType(ExportOptionsScreen), findsOneWidget);
    expect(find.text('2 张发票 · 3 笔订单'), findsOneWidget);
  });

  testWidgets('报销首页默认按订单选择，同票订单联动并可切换按发票导出', (tester) async {
    _usePhoneViewport(tester);
    final fixture = _Fixture(
      orders: <Order>[
        _order(1, '2026-07-12'),
        _order(2, '2026-07-10'),
        _order(3, '2026-07-08'),
      ],
      invoices: <Invoice>[
        _invoice(101, '2026-07-13'),
        _invoice(102, '2026-07-11'),
      ],
      invoiceIdsByOrder: const <int, Set<int>>{
        1: <int>{101},
        2: <int>{102},
        3: <int>{101},
      },
      orderIdsByInvoice: const <int, Set<int>>{
        101: <int>{1, 3},
        102: <int>{2},
      },
    );
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      _screenApp(fixture.container, const ReimbursementScreen()),
    );
    await tester.pumpAndSettle();

    expect(fixture.state.hasRange, isFalse);
    expect(find.text('按订单导出'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reimbursement-order-ledger')),
      findsOneWidget,
    );
    final basisControl = find.byKey(
      const ValueKey('reimbursement-export-basis'),
    );
    expect(tester.getCenter(basisControl).dx, closeTo(206, 0.5));
    expect(
      find.byKey(const ValueKey('clear-reimbursement-date-filter')),
      findsNothing,
    );
    expect(find.text('报销周期'), findsNothing);
    expect(find.text('选择订单后，同票订单将一并选中'), findsNothing);

    final firstOrder = find.byKey(const ValueKey('reimbursement-order-1'));
    await tester.ensureVisible(firstOrder);
    await tester.tap(firstOrder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));

    final cascadeNotice = find.byKey(
      const ValueKey('reimbursement-cascade-notice'),
    );
    expect(cascadeNotice, findsOneWidget);
    expect(find.text('另有 1 笔同票订单一并选中'), findsOneWidget);
    expect(
      tester.getTopLeft(cascadeNotice).dy,
      lessThan(tester.getTopLeft(basisControl).dy),
    );
    final noticeMaterial = tester.widget<Material>(cascadeNotice);
    expect(noticeMaterial.elevation, 0);
    expect(noticeMaterial.color, isNot(AppPalette.actionPrimary));

    expect(find.text('同票带入'), findsOneWidget);
    expect(find.text('2 笔订单 · 1 张发票'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 240));
    expect(cascadeNotice, findsNothing);

    await tester.tap(basisControl);
    await tester.pumpAndSettle();
    final basisPicker = find.byKey(
      const ValueKey('reimbursement-basis-picker'),
    );
    expect(basisPicker, findsOneWidget);
    expect(tester.getCenter(basisPicker).dx, closeTo(206, 0.5));
    expect(
      tester.getTopLeft(basisPicker).dy,
      greaterThan(tester.getBottomLeft(basisControl).dy),
    );
    expect(find.text('同票订单一并选中'), findsOneWidget);
    expect(find.text('关联订单自动带入'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('reimbursement-basis-invoices')),
    );
    await tester.pumpAndSettle();

    expect(find.text('按发票导出'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reimbursement-invoice-ledger')),
      findsOneWidget,
    );
    expect(find.text('关联 2 笔订单'), findsOneWidget);

    final firstInvoice = find.byKey(
      const ValueKey('reimbursement-invoice-101'),
    );
    await tester.ensureVisible(firstInvoice);
    await tester.tap(firstInvoice);
    await tester.pumpAndSettle();
    expect(find.text('1 张发票 · 2 笔订单'), findsOneWidget);
  });

  testWidgets('仅数据写入修订会自动重载已初始化的报销依据', (tester) async {
    _usePhoneViewport(tester);
    final sourceOrders = <Order>[_order(1, '2026-07-12')];
    final sourceInvoices = <Invoice>[_invoice(101, '2026-07-13')];
    final invoiceIdsByOrder = <int, Set<int>>{
      1: <int>{101},
    };
    final orderIdsByInvoice = <int, Set<int>>{
      101: <int>{1},
    };
    final fixture = _Fixture(
      orders: sourceOrders,
      invoices: sourceInvoices,
      invoiceIdsByOrder: invoiceIdsByOrder,
      orderIdsByInvoice: orderIdsByInvoice,
    );
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      _screenApp(fixture.container, const ReimbursementScreen()),
    );
    await tester.pumpAndSettle();

    final rangeStart = DateTime(2026, 7, 1);
    final rangeEnd = DateTime(2026, 7, 31);
    final orderExportNotifier = fixture.container.read(exportProvider.notifier);
    await orderExportNotifier.setDateRange(rangeStart, rangeEnd);
    await orderExportNotifier.toggleSelection(1);
    expect(fixture.container.read(exportProvider).totalSelectedCount, 1);
    expect(
      fixture.container.read(invoiceExportProvider).isInitialized,
      isFalse,
    );

    sourceOrders.add(_order(2, '2026-07-11'));
    invoiceIdsByOrder[2] = <int>{101};
    orderIdsByInvoice[101]!.add(2);
    await fixture.container
        .read(orderProvider.notifier)
        .loadOrders(refresh: true);
    await tester.pumpAndSettle();

    var orderExportState = fixture.container.read(exportProvider);
    expect(
      orderExportState.availableOrders.map((order) => order.id),
      isNot(contains(2)),
      reason: '普通读取、筛选或搜索不应清空并重载报销选择',
    );
    expect(orderExportState.totalSelectedCount, 1);
    final automaticReloadGate = Completer<void>();
    fixture.orders.nextLoadGate = automaticReloadGate;
    fixture.container.read(ledgerDataRevisionProvider.notifier).markChanged();
    await tester.pump();
    expect(fixture.container.read(exportProvider).isLoading, isTrue);

    await tester.tap(
      find.byKey(const ValueKey('reimbursement-order-1')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(
      fixture.container.read(exportProvider).totalSelectedCount,
      1,
      reason: '自动重载期间旧账页不得接受新的选择操作',
    );

    automaticReloadGate.complete();
    await tester.pumpAndSettle();

    orderExportState = fixture.container.read(exportProvider);
    expect(
      orderExportState.availableOrders.map((order) => order.id),
      containsAll(<int>[1, 2]),
    );
    expect(orderExportState.startDate, rangeStart);
    expect(orderExportState.endDate, rangeEnd);
    expect(orderExportState.totalSelectedCount, 0);
    expect(
      fixture.container.read(invoiceExportProvider).isInitialized,
      isFalse,
      reason: '尚未打开的导出依据不应被主数据刷新提前初始化',
    );

    await tester.tap(find.byKey(const ValueKey('reimbursement-export-basis')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('reimbursement-basis-invoices')),
    );
    await tester.pumpAndSettle();

    final invoiceExportNotifier = fixture.container.read(
      invoiceExportProvider.notifier,
    );
    await invoiceExportNotifier.setDateRange(rangeStart, rangeEnd);
    invoiceExportNotifier.toggleSelection(101);
    await orderExportNotifier.toggleSelection(1);
    expect(fixture.container.read(exportProvider).totalSelectedCount, 2);
    expect(
      fixture.container.read(invoiceExportProvider).selectedInvoiceIds,
      <int>{101},
    );

    sourceOrders.add(_order(3, '2026-07-10'));
    sourceInvoices.add(_invoice(102, '2026-07-10'));
    invoiceIdsByOrder[3] = <int>{102};
    orderIdsByInvoice[102] = <int>{3};
    await fixture.container
        .read(invoiceProvider.notifier)
        .loadInvoices(refresh: true);
    await tester.pumpAndSettle();

    orderExportState = fixture.container.read(exportProvider);
    var invoiceExportState = fixture.container.read(invoiceExportProvider);
    expect(
      orderExportState.availableOrders.map((order) => order.id),
      isNot(contains(3)),
    );
    expect(
      invoiceExportState.availableInvoices.map((invoice) => invoice.id),
      isNot(contains(102)),
    );
    expect(orderExportState.totalSelectedCount, 2);
    expect(invoiceExportState.selectedInvoiceIds, <int>{101});

    fixture.container.read(ledgerDataRevisionProvider.notifier).markChanged();
    await tester.pumpAndSettle();

    orderExportState = fixture.container.read(exportProvider);
    invoiceExportState = fixture.container.read(invoiceExportProvider);
    expect(
      orderExportState.availableOrders.map((order) => order.id),
      containsAll(<int>[1, 2, 3]),
      reason: '任一主数据刷新都应重载所有已经初始化的报销依据',
    );
    expect(
      invoiceExportState.availableInvoices.map((invoice) => invoice.id),
      containsAll(<int>[101, 102]),
    );
    expect(orderExportState.startDate, rangeStart);
    expect(orderExportState.endDate, rangeEnd);
    expect(invoiceExportState.startDate, rangeStart);
    expect(invoiceExportState.endDate, rangeEnd);
    expect(orderExportState.totalSelectedCount, 0);
    expect(invoiceExportState.selectedInvoiceIds, isEmpty);
    expect(invoiceExportState.selectedOrderIds, isEmpty);
  });

  testWidgets('未关联订单会在关联检查页阻断继续', (tester) async {
    _usePhoneViewport(tester);
    final fixture = _Fixture(orders: <Order>[_order(1, '2026-04-08')]);
    addTearDown(fixture.dispose);
    await fixture.notifier.initializeRange(
      DateTime(2026, 4, 1),
      DateTime(2026, 4, 30),
    );

    await tester.pumpWidget(
      _screenApp(fixture.container, const ReimbursementCheckScreen()),
    );
    await tester.pump();

    expect(find.text('1 笔订单未关联发票'), findsOneWidget);
    expect(find.text('1 笔订单未关联'), findsOneWidget);
    expect(find.text('关联发票后，请重新检查。'), findsOneWidget);
    final button = tester.widget<AppButton>(
      find.byKey(const ValueKey('continue_reimbursement_build')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('范围内没有订单时不显示底部处理提示', (tester) async {
    _usePhoneViewport(tester);
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await fixture.notifier.initializeRange(
      DateTime(2026, 4, 1),
      DateTime(2026, 4, 30),
    );

    await tester.pumpWidget(
      _screenApp(fixture.container, const ReimbursementCheckScreen()),
    );
    await tester.pump();

    expect(find.text('范围内没有订单'), findsNWidgets(2));
    expect(find.text('关联发票后，请重新检查。'), findsNothing);
    expect(find.text('请确认是否包含范围外订单。'), findsNothing);
    expect(find.text('默认导出用餐证明、发票和用餐明细。'), findsNothing);
  });

  testWidgets('检查失败时隐藏原始错误和底部处理提示', (tester) async {
    _usePhoneViewport(tester);
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await fixture.notifier.initializeRange(
      DateTime(2026, 4, 30),
      DateTime(2026, 4, 1),
    );

    await tester.pumpWidget(
      _screenApp(fixture.container, const ReimbursementCheckScreen()),
    );
    await tester.pump();

    expect(find.text('加载失败'), findsOneWidget);
    expect(find.text('开始日期不能晚于结束日期'), findsNothing);
    expect(find.text('关联发票后，请重新检查。'), findsNothing);
    expect(find.text('请确认是否包含范围外订单。'), findsNothing);
    expect(find.text('默认导出用餐证明、发票和用餐明细。'), findsNothing);
  });

  testWidgets('范围外订单须确认后才可继续，并说明默认导出内容', (tester) async {
    _usePhoneViewport(tester);
    final fixture = _Fixture(
      orders: <Order>[_order(1, '2026-04-08'), _order(3, '2026-03-30')],
      invoiceIdsByOrder: const <int, Set<int>>{
        1: <int>{101},
      },
      orderIdsByInvoice: const <int, Set<int>>{
        101: <int>{1, 3},
      },
    );
    addTearDown(fixture.dispose);
    await fixture.notifier.initializeRange(
      DateTime(2026, 4, 1),
      DateTime(2026, 4, 30),
    );

    await tester.pumpWidget(
      _screenApp(fixture.container, const ReimbursementCheckScreen()),
    );
    await tester.pump();

    expect(find.text('范围外关联订单 1 笔'), findsOneWidget);
    expect(find.text('确认范围外订单'), findsOneWidget);
    expect(find.text('请确认是否包含范围外订单。'), findsOneWidget);
    expect(
      tester
          .widget<AppButton>(
            find.byKey(const ValueKey('continue_reimbursement_build')),
          )
          .onPressed,
      isNull,
    );

    final confirmation = find.byType(CheckboxListTile);
    await tester.ensureVisible(confirmation);
    await tester.pump();
    await tester.tap(confirmation);
    await tester.pump();

    expect(fixture.state.closureAccepted, isTrue);
    expect(find.text('下一步'), findsOneWidget);
    expect(
      tester
          .widget<AppButton>(
            find.byKey(const ValueKey('continue_reimbursement_build')),
          )
          .onPressed,
      isNotNull,
    );
    expect(find.text('默认导出用餐证明、发票和用餐明细。'), findsOneWidget);
  });

  testWidgets('材料选项默认全开并读取报销关系闭包', (tester) async {
    _usePhoneViewport(tester);
    final fixture = _Fixture(
      orders: <Order>[
        _order(1, '2026-06-10'),
        _order(2, '2026-06-11'),
        _order(3, '2026-05-31'),
      ],
      invoiceIdsByOrder: const <int, Set<int>>{
        1: <int>{101},
        2: <int>{102},
      },
      orderIdsByInvoice: const <int, Set<int>>{
        101: <int>{1, 3},
        102: <int>{2},
      },
    );
    addTearDown(fixture.dispose);
    await fixture.notifier.initializeRange(
      DateTime(2026, 6, 1),
      DateTime(2026, 6, 30),
    );

    await tester.pumpWidget(
      _screenApp(fixture.container, const ExportOptionsScreen()),
    );
    await tester.pump();

    expect(find.text('2 张发票 · 3 笔订单'), findsOneWidget);
    expect(find.text('用餐证明'), findsOneWidget);
    expect(find.text('发票'), findsOneWidget);
    expect(find.text('用餐明细'), findsOneWidget);

    final exportTypeCheckboxes = tester
        .widgetList<Checkbox>(find.byType(Checkbox))
        .toList(growable: false);
    expect(exportTypeCheckboxes, hasLength(3));
    expect(
      exportTypeCheckboxes.every((checkbox) => checkbox.value == true),
      isTrue,
    );
  });
}

Future<void> _pumpRoute(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

Widget _screenApp(ProviderContainer container, Widget screen) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(theme: AppTheme.lightTheme, home: screen),
  );
}

void _usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Order _order(int id, String date) {
  return Order(
    id: id,
    orderDate: date,
    amount: id * 10,
    shopName: '店铺$id',
    createdAt: '${date}T12:00:00',
    updatedAt: '${date}T12:00:00',
  );
}

Invoice _invoice(int id, String date) {
  return Invoice(
    id: id,
    invoiceDate: date,
    totalAmount: id.toDouble(),
    sellerName: '开票方$id',
    invoiceNumber: 'INV-$id',
    createdAt: '${date}T12:00:00',
    updatedAt: '${date}T12:00:00',
  );
}

class _Fixture {
  _Fixture({
    List<Order> orders = const <Order>[],
    List<Invoice> invoices = const <Invoice>[],
    Map<int, Set<int>> invoiceIdsByOrder = const <int, Set<int>>{},
    Map<int, Set<int>> orderIdsByInvoice = const <int, Set<int>>{},
  }) : orders = _FakeOrderRepository(
         orders: orders,
         invoiceIdsByOrder: invoiceIdsByOrder,
       ),
       invoices = _FakeInvoiceRepository(
         invoices: invoices,
         orderIdsByInvoice: orderIdsByInvoice,
       ) {
    container = ProviderContainer(
      overrides: [
        orderRepositoryProvider.overrideWithValue(this.orders),
        invoiceRepositoryProvider.overrideWithValue(this.invoices),
      ],
    );
  }

  final _FakeOrderRepository orders;
  final _FakeInvoiceRepository invoices;
  late final ProviderContainer container;

  ReimbursementNotifier get notifier =>
      container.read(reimbursementProvider.notifier);

  ReimbursementState get state => container.read(reimbursementProvider);

  void dispose() => container.dispose();
}

class _FakeOrderRepository extends OrderRepository {
  _FakeOrderRepository({required this.orders, required this.invoiceIdsByOrder});

  final List<Order> orders;
  final Map<int, Set<int>> invoiceIdsByOrder;
  Completer<void>? nextLoadGate;

  @override
  Future<List<Order>> getAll({int? limit, int? offset}) async {
    await _waitForNextLoad();
    return orders;
  }

  @override
  Future<int> getCount() async => orders.length;

  @override
  Future<List<Order>> getRecentlyCreated({int limit = 10}) async =>
      orders.take(limit).toList(growable: false);

  @override
  Future<List<Order>> getByDateRange(DateTime start, DateTime end) async {
    await _waitForNextLoad();
    return orders
        .where((order) {
          final date = DateTime.tryParse(order.orderDate ?? '');
          return date != null && !date.isBefore(start) && !date.isAfter(end);
        })
        .toList(growable: false);
  }

  Future<void> _waitForNextLoad() async {
    final gate = nextLoadGate;
    nextLoadGate = null;
    if (gate != null) await gate.future;
  }

  @override
  Future<List<Order>> getByIds(List<int> ids) async {
    final idSet = ids.toSet();
    return orders
        .where((order) => idSet.contains(order.id))
        .toList(growable: false);
  }

  @override
  Future<Map<int, Set<int>>> getInvoiceIdsForOrders(List<int> orderIds) async {
    return <int, Set<int>>{
      for (final orderId in orderIds)
        orderId: Set<int>.of(invoiceIdsByOrder[orderId] ?? const <int>{}),
    };
  }

  @override
  Future<Map<int, int>> getInvoiceCountsForOrders(List<int> orderIds) async {
    return <int, int>{
      for (final orderId in orderIds)
        orderId: invoiceIdsByOrder[orderId]?.length ?? 0,
    };
  }

  @override
  Future<List<UninvoicedShopSummary>> getUninvoicedShopSummaries({
    DateTime? startDate,
    DateTime? endDate,
  }) async => const <UninvoicedShopSummary>[];
}

class _FakeInvoiceRepository extends InvoiceRepository {
  _FakeInvoiceRepository({
    required this.invoices,
    required this.orderIdsByInvoice,
  });

  final List<Invoice> invoices;
  final Map<int, Set<int>> orderIdsByInvoice;

  @override
  Future<List<Invoice>> getAll({int? limit, int? offset}) async => invoices;

  @override
  Future<int> getCount() async => invoices.length;

  @override
  Future<List<Invoice>> getRecentlyCreated({int limit = 10}) async =>
      invoices.take(limit).toList(growable: false);

  @override
  Future<List<Invoice>> getByDateRange(DateTime start, DateTime end) async {
    return invoices
        .where((invoice) {
          final date = DateTime.tryParse(invoice.invoiceDate ?? '');
          return date != null && !date.isBefore(start) && !date.isAfter(end);
        })
        .toList(growable: false);
  }

  @override
  Future<Map<int, Set<int>>> getOrderIdsForInvoices(
    List<int> invoiceIds,
  ) async {
    return <int, Set<int>>{
      for (final invoiceId in invoiceIds)
        invoiceId: Set<int>.of(orderIdsByInvoice[invoiceId] ?? const <int>{}),
    };
  }

  @override
  Future<Map<int, int>> getOrderCountsForInvoices(List<int> invoiceIds) async {
    return <int, int>{
      for (final invoiceId in invoiceIds)
        invoiceId: orderIdsByInvoice[invoiceId]?.length ?? 0,
    };
  }
}

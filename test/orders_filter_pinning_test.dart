import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/core/theme/app_theme.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/data/repositories/order_repository.dart';
import 'package:receipt_tamer/presentation/providers/order_provider.dart';
import 'package:receipt_tamer/presentation/screens/orders/orders_screen.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_button.dart';
import 'package:receipt_tamer/presentation/widgets/common/ledger_month_sheet.dart';
import 'package:receipt_tamer/presentation/widgets/common/scroll_edge_fog.dart';

void main() {
  testWidgets('订单筛选条固定在滚动账页之外', (tester) async {
    _setViewport(tester);
    await _pumpOrdersScreen(tester, _OrderRepository(_manyOrders));

    final strip = find.byType(LedgerFilterStrip);
    final list = find.byType(CustomScrollView);
    final appBarFinder = find.byType(AppBar);
    final appBar = tester.widget<AppBar>(appBarFinder);
    final firstChip = find.byType(LedgerFilterChip).first;
    expect(strip, findsOneWidget);
    expect(
      appBar.forceMaterialTransparency,
      isTrue,
      reason: '顶栏必须透出整页背景，不能用实色 Material 画出横向分界',
    );
    expect(
      tester.getRect(strip).top,
      closeTo(tester.getRect(appBarFinder).bottom, 0.01),
      reason: '筛选区应紧接顶栏底部，不应再保留 28dp 顶部占位',
    );
    expect(
      tester.getTopLeft(firstChip).dx,
      closeTo(16, 0.01),
      reason: '第一枚筛选框应与标题及账页的 16dp 左边线对齐',
    );
    expect(
      find.ancestor(of: strip, matching: list),
      findsNothing,
      reason: '筛选条不能成为订单账页的滚动内容',
    );
    _expectRoundedLedgerViewportClip(tester, scrollView: list);

    final edgeFog = tester.widget<ScrollEdgeFog>(find.byType(ScrollEdgeFog));
    expect(edgeFog.showTop, isTrue, reason: '账页顶部渐隐效果必须保留');
    expect(edgeFog.topHeight, ledgerMonthFadeSafeTop);
    expect(
      edgeFog.fadeTopToTransparent,
      isTrue,
      reason: '顶部应用透明度遮罩渐隐，不应叠加一层实色页面雾边',
    );
    expect(find.byKey(ScrollEdgeFog.topFogKey), findsNothing);
    expect(find.byKey(ScrollEdgeFog.topGuardKey), findsNothing);
    expect(find.byKey(ScrollEdgeFog.bottomFogKey), findsOneWidget);
    final topMask = find.descendant(
      of: find.byType(ScrollEdgeFog),
      matching: find.byKey(ScrollEdgeFog.topTransparencyMaskKey),
    );
    expect(topMask, findsOneWidget);
    expect(tester.widget<ShaderMask>(topMask).blendMode, BlendMode.dstIn);
    final refreshIndicator = find.byType(RefreshIndicator);
    expect(
      find.ancestor(of: topMask, matching: refreshIndicator),
      findsOneWidget,
      reason: '透明遮罩只能淡出账页内容，不能将下拉刷新圆圈一起淡出',
    );
    expect(
      find.ancestor(of: refreshIndicator, matching: topMask),
      findsNothing,
    );

    final stripTopLeft = tester.getTopLeft(strip);
    final firstChipLeft = tester.getTopLeft(firstChip).dx;
    await tester.drag(list, const Offset(0, -420));
    await tester.pumpAndSettle();

    final scrollView = tester.widget<CustomScrollView>(list);
    expect(scrollView.controller!.offset, greaterThan(0));
    expect(tester.getTopLeft(strip).dy, stripTopLeft.dy);
    expect(tester.getTopLeft(firstChip).dx, firstChipLeft);
  });

  testWidgets('订单初始加载和全部为空时沿用原空态且不伪造筛选条', (tester) async {
    _setViewport(tester);
    final repository = _PendingOrderRepository();

    await tester.pumpWidget(_ordersApp(repository));
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(LedgerFilterStrip), findsNothing);

    repository.complete(const []);
    await tester.pumpAndSettle();

    expect(find.text('暂无订单'), findsOneWidget);
    expect(find.byType(LedgerFilterStrip), findsNothing);
  });

  testWidgets('订单搜索空结果仍保留固定筛选条并可由全部恢复', (tester) async {
    _setViewport(tester);
    await _pumpOrdersScreen(tester, _SearchOrderRepository(_orders));

    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '不存在的订单');
    await tester.tap(find.widgetWithText(AppButton, '搜索'));
    await tester.pumpAndSettle();

    final strip = find.byType(LedgerFilterStrip);
    expect(find.text('无匹配订单'), findsOneWidget);
    expect(strip, findsOneWidget);
    expect(
      find.byKey(const ValueKey('order-active-search-filter')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('清除筛选：搜索 不存在的订单'), findsOneWidget);
    expect(find.widgetWithText(LedgerFilterChip, '搜索：不存在的订单'), findsOneWidget);
    expect(
      find.ancestor(of: strip, matching: find.byType(CustomScrollView)),
      findsNothing,
    );

    expect(find.text('清除筛选'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('order-active-search-filter')));
    await tester.pumpAndSettle();

    expect(find.text('无匹配订单'), findsNothing);
    expect(
      find.byKey(const ValueKey('order-active-search-filter')),
      findsNothing,
    );
    expect(find.text('2026 年 7 月'), findsOneWidget);
    expect(find.widgetWithText(LedgerFilterChip, '全部 2'), findsOneWidget);
  });

  testWidgets('今日订单持续显示为可清除筛选标签', (tester) async {
    _setViewport(tester);
    await _pumpOrdersScreen(tester, _OrderRepository(_orders));

    await tester.tap(find.byTooltip('筛选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('今日订单'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('order-active-today-filter')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('清除筛选：今日'), findsOneWidget);
    expect(find.widgetWithText(LedgerFilterChip, '今日'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('order-active-today-filter')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('order-active-today-filter')),
      findsNothing,
    );
  });

  testWidgets('订单筛选激活后下拉刷新仍执行当前筛选且筛选条固定', (tester) async {
    _setViewport(tester);
    final repository = _RefreshTrackingOrderRepository(_manyOrders);
    await _pumpOrdersScreen(tester, repository);

    await tester.tap(
      find.widgetWithText(LedgerFilterChip, '未关联 ${_manyOrders.length}'),
    );
    await tester.pumpAndSettle();

    expect(repository.unlinkedSearchCount, 1);
    final strip = find.byType(LedgerFilterStrip);
    final stripTop = tester.getTopLeft(strip).dy;

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 320));
    await tester.pumpAndSettle();

    expect(repository.unlinkedSearchCount, 2);
    expect(tester.getTopLeft(strip).dy, closeTo(stripTop, 0.01));
    expect(
      find.widgetWithText(LedgerFilterChip, '未关联 ${_manyOrders.length}'),
      findsOneWidget,
    );
  });
}

void _expectRoundedLedgerViewportClip(
  WidgetTester tester, {
  required Finder scrollView,
}) {
  final viewportClip = find.byType(LedgerViewportClip);
  expect(viewportClip, findsOneWidget);
  expect(
    find.ancestor(of: scrollView, matching: viewportClip),
    findsOneWidget,
    reason: '整个订单滚动视口必须裁掉粘性月份栏圆角外的底层账页',
  );

  final widget = tester.widget<LedgerViewportClip>(viewportClip);
  expect(widget.horizontalInset, 16);
  expect(widget.topRadius, ledgerMonthSheetRadius);

  final clipPathFinder = find
      .descendant(of: viewportClip, matching: find.byType(ClipPath))
      .first;
  final clipPath = tester.widget<ClipPath>(clipPathFinder);
  final size = tester.getSize(clipPathFinder);
  final path = clipPath.clipper!.getClip(size);
  final inset = widget.horizontalInset;
  final radius = widget.topRadius;

  expect(
    path.contains(Offset(inset + 1, 1)),
    isFalse,
    reason: '左上圆角外必须露出连续页面背景，不能泄漏滚动账页的方形底色',
  );
  expect(
    path.contains(Offset(size.width - inset - 1, 1)),
    isFalse,
    reason: '右上圆角外必须露出连续页面背景，不能泄漏滚动账页的方形底色',
  );
  expect(path.contains(Offset(inset + radius, 1)), isTrue);
  expect(path.contains(Offset(size.width - inset - radius, 1)), isTrue);
  expect(
    path.contains(Offset(1, radius + 1)),
    isTrue,
    reason: '裁剪只能挖掉顶部圆角缺口，不能永久吞掉账页左侧滚动区',
  );
  expect(
    path.contains(Offset(size.width - 1, radius + 1)),
    isTrue,
    reason: '裁剪只能挖掉顶部圆角缺口，不能永久吞掉账页右侧滚动区',
  );
}

Future<void> _pumpOrdersScreen(
  WidgetTester tester,
  OrderRepository repository,
) async {
  await tester.pumpWidget(_ordersApp(repository));
  await tester.pumpAndSettle();
}

Widget _ordersApp(OrderRepository repository) {
  return ProviderScope(
    overrides: [orderRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(theme: AppTheme.lightTheme, home: const OrdersScreen()),
  );
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

const _orders = [
  Order(
    id: 1,
    shopName: '七月订单',
    amount: 20,
    orderDate: '2026-07-01',
    createdAt: '2026-07-01T12:00:00',
  ),
  Order(
    id: 2,
    shopName: '六月订单',
    amount: 30,
    orderDate: '2026-06-01',
    createdAt: '2026-06-01T12:00:00',
  ),
];

final _manyOrders = <Order>[
  for (var index = 1; index <= 18; index++)
    Order(
      id: index,
      shopName: '七月订单 $index',
      amount: 20 + index.toDouble(),
      orderDate: '2026-07-${index.toString().padLeft(2, '0')}',
      createdAt: '2026-07-01T12:00:00',
    ),
  const Order(
    id: 19,
    shopName: '六月订单',
    amount: 30,
    orderDate: '2026-06-01',
    createdAt: '2026-06-01T12:00:00',
  ),
];

class _OrderRepository extends OrderRepository {
  _OrderRepository(this.orders);

  final List<Order> orders;

  @override
  Future<List<Order>> getAll({int? limit, int? offset}) async => orders;

  @override
  Future<List<Order>> getTodayOrders() async => orders;
}

class _SearchOrderRepository extends _OrderRepository {
  _SearchOrderRepository(super.orders);

  @override
  Future<List<Order>> search({
    String? shopName,
    String? orderNumber,
    double? minAmount,
    double? maxAmount,
    DateTime? startDate,
    DateTime? endDate,
    bool? hasLinkedInvoice,
    int? limit,
    int? offset,
  }) async {
    if (shopName != null || orderNumber != null) return const [];
    return orders;
  }
}

class _RefreshTrackingOrderRepository extends _OrderRepository {
  _RefreshTrackingOrderRepository(super.orders);

  int unlinkedSearchCount = 0;

  @override
  Future<List<Order>> search({
    String? shopName,
    String? orderNumber,
    double? minAmount,
    double? maxAmount,
    DateTime? startDate,
    DateTime? endDate,
    bool? hasLinkedInvoice,
    int? limit,
    int? offset,
  }) async {
    if (hasLinkedInvoice == false) {
      unlinkedSearchCount++;
    }
    return orders;
  }
}

class _PendingOrderRepository extends OrderRepository {
  final Completer<List<Order>> _orders = Completer<List<Order>>();

  void complete(List<Order> orders) => _orders.complete(orders);

  @override
  Future<List<Order>> getAll({int? limit, int? offset}) => _orders.future;
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/repositories/invoice_repository.dart';
import 'package:receipt_tamer/presentation/providers/invoice_provider.dart';
import 'package:receipt_tamer/presentation/screens/invoices/invoices_screen.dart';
import 'package:receipt_tamer/presentation/widgets/common/empty_state.dart';
import 'package:receipt_tamer/presentation/widgets/common/ledger_month_sheet.dart';
import 'package:receipt_tamer/presentation/widgets/common/scroll_edge_fog.dart';

void main() {
  testWidgets('发票筛选条在账页滚动时保持固定', (tester) async {
    _setViewport(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          invoiceRepositoryProvider.overrideWithValue(
            _InvoiceListRepository(_manyInvoices),
          ),
        ],
        child: const MaterialApp(home: InvoicesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final strip = find.byType(LedgerFilterStrip);
    final appBarFinder = find.byType(AppBar);
    final appBar = tester.widget<AppBar>(appBarFinder);
    final firstChip = find.byType(LedgerFilterChip).first;
    final initialTop = tester.getTopLeft(strip).dy;
    final initialFirstChipLeft = tester.getTopLeft(firstChip).dx;
    final scrollView = tester.widget<CustomScrollView>(
      find.byType(CustomScrollView),
    );
    _expectRoundedLedgerViewportClip(
      tester,
      scrollView: find.byType(CustomScrollView),
    );
    final edgeFog = tester.widget<ScrollEdgeFog>(find.byType(ScrollEdgeFog));

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
      initialFirstChipLeft,
      closeTo(16, 0.01),
      reason: '第一枚筛选框应与标题及账页的 16dp 左边线对齐',
    );
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

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(scrollView.controller!.offset, greaterThan(0));
    expect(tester.getTopLeft(strip).dy, closeTo(initialTop, 0.01));
    expect(
      tester.getTopLeft(firstChip).dx,
      closeTo(initialFirstChipLeft, 0.01),
    );
  });

  testWidgets('发票初次加载及真正空态不显示无意义筛选条', (tester) async {
    _setViewport(tester);
    final repository = _DelayedEmptyInvoiceRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [invoiceRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: InvoicesScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(LedgerFilterStrip), findsNothing);

    repository.completeInitialLoad();
    await tester.pumpAndSettle();

    expect(find.byType(EmptyInvoices), findsOneWidget);
    expect(find.byType(LedgerFilterStrip), findsNothing);
  });

  testWidgets('发票筛选及搜索为空时仍保留固定筛选条并可由全部恢复', (tester) async {
    _setViewport(tester);
    final repository = _InvoiceListRepository(_manyInvoices);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [invoiceRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: InvoicesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final initialTop = tester.getTopLeft(find.byType(LedgerFilterStrip)).dy;
    await tester.tap(find.widgetWithText(LedgerFilterChip, '未关联 0'));
    await tester.pumpAndSettle();

    expect(find.text('无匹配发票'), findsOneWidget);
    expect(find.byType(LedgerFilterStrip), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(LedgerFilterStrip)).dy,
      closeTo(initialTop, 0.01),
    );

    expect(find.text('清除筛选'), findsNothing);
    await tester.tap(
      find.widgetWithText(LedgerFilterChip, '全部 ${_manyInvoices.length}'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '不存在的发票');
    await tester.tap(find.text('搜索'));
    await tester.pumpAndSettle();

    expect(repository.lastKeyword, '不存在的发票');
    expect(find.text('无匹配发票'), findsOneWidget);
    expect(find.byType(LedgerFilterStrip), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(LedgerFilterStrip)).dy,
      closeTo(initialTop, 0.01),
    );
    expect(find.text('清除筛选'), findsNothing);
    await tester.tap(
      find.widgetWithText(LedgerFilterChip, '全部 ${_manyInvoices.length}'),
    );
    await tester.pumpAndSettle();
    expect(find.text('无匹配发票'), findsNothing);
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
    reason: '整个发票滚动视口必须裁掉粘性月份栏圆角外的底层账页',
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

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

final _manyInvoices = <Invoice>[
  for (var day = 1; day <= 12; day++)
    Invoice(
      id: day,
      sellerName: '七月销售方 $day',
      totalAmount: 20 + day.toDouble(),
      invoiceDate: '2026-07-${day.toString().padLeft(2, '0')}',
      createdAt: '2026-07-01T12:00:00',
    ),
  const Invoice(
    id: 13,
    sellerName: '六月销售方',
    totalAmount: 30,
    invoiceDate: '2026-06-01',
    createdAt: '2026-06-01T12:00:00',
  ),
];

class _InvoiceListRepository extends InvoiceRepository {
  _InvoiceListRepository(this.invoices);

  final List<Invoice> invoices;
  String? lastKeyword;

  @override
  Future<List<Invoice>> getAll({int? limit, int? offset}) async => invoices;

  @override
  Future<Map<int, int>> getOrderCountsForInvoices(List<int> invoiceIds) async {
    return {for (final invoiceId in invoiceIds) invoiceId: 1};
  }

  @override
  Future<List<Invoice>> getWithoutOrders() async => [];

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
    lastKeyword = keyword;
    return [];
  }
}

class _DelayedEmptyInvoiceRepository extends InvoiceRepository {
  final Completer<List<Invoice>> _initialLoad = Completer<List<Invoice>>();

  void completeInitialLoad() => _initialLoad.complete(const []);

  @override
  Future<List<Invoice>> getAll({int? limit, int? offset}) =>
      _initialLoad.future;
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/core/theme/app_theme.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/data/repositories/invoice_repository.dart';
import 'package:receipt_tamer/data/repositories/order_repository.dart';
import 'package:receipt_tamer/presentation/providers/invoice_provider.dart';
import 'package:receipt_tamer/presentation/providers/order_provider.dart';
import 'package:receipt_tamer/presentation/screens/invoices/invoices_screen.dart';
import 'package:receipt_tamer/presentation/screens/orders/orders_screen.dart';
import 'package:receipt_tamer/presentation/widgets/common/ledger_month_sheet.dart';
import 'package:receipt_tamer/presentation/widgets/invoice/invoice_card.dart';
import 'package:receipt_tamer/presentation/widgets/order/month_fast_scroll_bar.dart';
import 'package:receipt_tamer/presentation/widgets/order/order_card.dart';

void main() {
  testWidgets(
    'orders fast scrollbar avoids bottom nav and balances the card gutter',
    (tester) async {
      _setViewport(tester);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orderRepositoryProvider.overrideWithValue(
              _FakeOrderRepository(_orders),
            ),
          ],
          child: const MaterialApp(home: OrdersScreen()),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      _expectFastScrollLayout(tester);
      expect(find.byType(OrderCard), findsNothing);
    },
  );

  testWidgets(
    'invoices fast scrollbar avoids bottom nav and balances the card gutter',
    (tester) async {
      _setViewport(tester);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            invoiceRepositoryProvider.overrideWithValue(
              _FakeInvoiceRepository(_invoices),
            ),
          ],
          child: const MaterialApp(home: InvoicesScreen()),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      _expectFastScrollLayout(tester);
      expect(find.byType(InvoiceCard), findsNothing);
      expect(find.text('1 张'), findsNWidgets(2));
    },
  );

  testWidgets('orders ledger has no overflow at 360 width and 2x text', (
    tester,
  ) async {
    _setCompactViewport(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderRepositoryProvider.overrideWithValue(
            _FakeOrderRepository(_orders),
          ),
        ],
        child: _largeTextApp(home: const OrdersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LedgerMonthSheetSliver), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('month rail jumps to the real ledger sheet anchor', (
    tester,
  ) async {
    _setCompactViewport(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderRepositoryProvider.overrideWithValue(
            _FakeOrderRepository(_manyOrders),
          ),
        ],
        child: _largeTextApp(home: const OrdersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final scrollView = tester.widget<CustomScrollView>(
      find.byType(CustomScrollView),
    );
    final railRect = tester.getRect(find.byType(MonthFastScrollBar));

    await tester.tapAt(Offset(railRect.center.dx, railRect.bottom - 2));
    await tester.pumpAndSettle();

    expect(scrollView.controller!.offset, greaterThan(0));
    expect(find.text('2026 年 6 月'), findsOneWidget);
  });

  testWidgets('invoices ledger has no overflow at 360 width and 2x text', (
    tester,
  ) async {
    _setCompactViewport(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          invoiceRepositoryProvider.overrideWithValue(
            _FakeInvoiceRepository(_invoices),
          ),
        ],
        child: _largeTextApp(home: const InvoicesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LedgerMonthSheetSliver), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('订单筛选在空结果中仍可清除并恢复全部', (tester) async {
    _setViewport(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderRepositoryProvider.overrideWithValue(
            _FilteringOrderRepository(_orders),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const OrdersScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('订单列表'), findsOneWidget);
    expect(find.widgetWithText(LedgerFilterChip, '月份'), findsOneWidget);

    await tester.tap(find.widgetWithText(LedgerFilterChip, '月份'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('未选择').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('1月'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('未选择').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('1月'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();

    final monthLabel = '${DateTime.now().year}.01';
    expect(find.widgetWithText(LedgerFilterChip, monthLabel), findsOneWidget);
    final selectedMonthChip = find.widgetWithText(LedgerFilterChip, monthLabel);
    await tester.ensureVisible(selectedMonthChip);
    await tester.tap(selectedMonthChip);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(LedgerFilterChip, '月份'), findsOneWidget);

    await tester.tap(find.widgetWithText(LedgerFilterChip, '未关联 2'));
    await tester.pumpAndSettle();

    expect(find.text('无匹配订单'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.text('无匹配订单'), findsOneWidget);
    final clearChip = find.widgetWithText(LedgerFilterChip, '清除筛选');
    expect(clearChip, findsOneWidget);
    final clearRect = tester.getRect(clearChip);
    final stripRect = tester.getRect(find.byType(LedgerFilterStrip));
    expect(clearRect.left, greaterThanOrEqualTo(stripRect.left));
    expect(clearRect.right, lessThanOrEqualTo(stripRect.right));
    expect(
      clearRect.left,
      lessThan(
        tester.getRect(find.widgetWithText(LedgerFilterChip, '全部 2')).left,
      ),
    );
    await tester.tap(clearChip);
    await tester.pumpAndSettle();

    expect(find.text('无匹配订单'), findsNothing);
    expect(find.byType(LedgerMonthSheetSliver), findsNWidgets(2));
  });

  testWidgets('发票列表提供月份筛选并可从选中项恢复全部', (tester) async {
    _setViewport(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          invoiceRepositoryProvider.overrideWithValue(
            _FilteringInvoiceRepository(_invoices),
          ),
        ],
        child: const MaterialApp(home: InvoicesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('发票列表'), findsOneWidget);
    expect(find.widgetWithText(LedgerFilterChip, '月份'), findsOneWidget);

    await tester.tap(find.widgetWithText(LedgerFilterChip, '未关联 0'));
    await tester.pumpAndSettle();
    expect(find.text('无匹配发票'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.text('无匹配发票'), findsOneWidget);

    final clearChip = find.widgetWithText(LedgerFilterChip, '清除筛选');
    final clearRect = tester.getRect(clearChip);
    final stripRect = tester.getRect(find.byType(LedgerFilterStrip));
    expect(clearRect.left, greaterThanOrEqualTo(stripRect.left));
    expect(clearRect.right, lessThanOrEqualTo(stripRect.right));
    expect(
      clearRect.left,
      lessThan(
        tester.getRect(find.widgetWithText(LedgerFilterChip, '全部 2')).left,
      ),
    );
    await tester.tap(clearChip);
    await tester.pumpAndSettle();

    expect(find.text('无匹配发票'), findsNothing);
    expect(find.byType(LedgerMonthSheetSliver), findsNWidgets(2));
  });
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void _setCompactViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _largeTextApp({required Widget home}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    builder: (context, child) {
      return MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      );
    },
    home: home,
  );
}

void _expectFastScrollLayout(WidgetTester tester) {
  final scrollBarRect = tester.getRect(find.byType(MonthFastScrollBar));
  final layoutRect = tester.getRect(find.byType(MonthFastScrollLayout));
  final headerRect = tester.getRect(
    find.byKey(LedgerMonthSheetSliver.headerSurfaceKey).first,
  );
  final entriesRect = tester.getRect(
    find.byKey(LedgerMonthSheetSliver.entriesSurfaceKey).first,
  );
  final viewportBottom = tester.view.physicalSize.height;

  expect(
    scrollBarRect.bottom,
    viewportBottom - AppGlassTokens.navCenterButtonSize - 44,
  );
  expect(headerRect.left - layoutRect.left, 16);
  expect(entriesRect.left, headerRect.left);
  expect(entriesRect.right, headerRect.right);
  expect(scrollBarRect.left - headerRect.right, 4);
  expect(layoutRect.right - scrollBarRect.center.dx, 16);
}

const _orders = [
  Order(
    id: 1,
    shopName: 'A',
    amount: 20,
    orderDate: '2026-06-01',
    createdAt: '2026-06-01T12:00:00',
  ),
  Order(
    id: 2,
    shopName: 'B',
    amount: 30,
    orderDate: '2026-05-01',
    createdAt: '2026-05-01T12:00:00',
  ),
];

final _manyOrders = <Order>[
  for (var index = 1; index <= 9; index++)
    Order(
      id: index,
      shopName: '七月订单 $index',
      amount: 20 + index.toDouble(),
      orderDate: '2026-07-${index.toString().padLeft(2, '0')}',
      createdAt: '2026-07-01T12:00:00',
    ),
  const Order(
    id: 10,
    shopName: '六月订单',
    amount: 30,
    orderDate: '2026-06-01',
    createdAt: '2026-06-01T12:00:00',
  ),
];

const _invoices = [
  Invoice(
    id: 1,
    sellerName: 'A',
    totalAmount: 20,
    invoiceDate: '2026-06-01',
    createdAt: '2026-06-01T12:00:00',
  ),
  Invoice(
    id: 2,
    sellerName: 'B',
    totalAmount: 30,
    invoiceDate: '2026-05-01',
    createdAt: '2026-05-01T12:00:00',
  ),
];

class _FakeOrderRepository extends OrderRepository {
  _FakeOrderRepository(this._orders);

  final List<Order> _orders;

  @override
  Future<List<Order>> getAll({int? limit, int? offset}) async => _orders;
}

class _FakeInvoiceRepository extends InvoiceRepository {
  _FakeInvoiceRepository(this._invoices);

  final List<Invoice> _invoices;

  @override
  Future<List<Invoice>> getAll({int? limit, int? offset}) async => _invoices;

  @override
  Future<List<Invoice>> getByOrderId(
    int orderId, {
    int? limit,
    int? offset,
  }) async => _invoices;

  @override
  Future<List<int>> getOrderIdsForInvoice(int invoiceId) async => [1];

  @override
  Future<Map<int, int>> getOrderCountsForInvoices(List<int> invoiceIds) async {
    return {for (final invoiceId in invoiceIds) invoiceId: 1};
  }
}

class _FilteringOrderRepository extends _FakeOrderRepository {
  _FilteringOrderRepository(super._orders);

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
    if (hasLinkedInvoice == false) return [];
    return _orders;
  }
}

class _FilteringInvoiceRepository extends _FakeInvoiceRepository {
  _FilteringInvoiceRepository(super._invoices);

  @override
  Future<List<Invoice>> getWithoutOrders() async => [];
}

import 'dart:ffi' show Abi;
import 'dart:io' show Platform;
import 'dart:ui' show FrameTiming;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kProfileMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:receipt_tamer/core/models/ledger_month_summary.dart';
import 'package:receipt_tamer/core/theme/app_theme.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/data/repositories/invoice_repository.dart';
import 'package:receipt_tamer/data/repositories/order_repository.dart';
import 'package:receipt_tamer/presentation/providers/invoice_provider.dart'
    show invoiceRepositoryProvider;
import 'package:receipt_tamer/presentation/providers/order_provider.dart'
    show orderRepositoryProvider;
import 'package:receipt_tamer/presentation/screens/invoices/invoices_screen.dart';
import 'package:receipt_tamer/presentation/screens/orders/orders_screen.dart';
import 'package:receipt_tamer/presentation/widgets/common/liquid_glass_background.dart';
import 'package:receipt_tamer/presentation/widgets/order/month_fast_scroll_bar.dart';

import 'support/frame_timing_report.dart';

const _runHarness = bool.fromEnvironment('LEDGER_PROFILE_RUN');
const _certify = bool.fromEnvironment('LEDGER_PROFILE_CERTIFY');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '1000 订单 / 500 发票 / 36 月账簿帧时验收',
    (tester) async {
      final environment = await _readProfileEnvironment();
      if (_certify) {
        expect(environment.profileMode, isTrue, reason: '认证必须使用 profile mode');
        expect(
          environment.isPhysicalDevice,
          isTrue,
          reason: '认证必须在 Android 物理设备上运行',
        );
        expect(
          environment.isArm64Process,
          isTrue,
          reason: '认证进程必须实际运行于 androidArm64 ABI',
        );
      }

      final orders = _ProfileOrderRepository();
      final invoices = _ProfileInvoiceRepository();
      final samples = <LedgerFrameSample>[];
      var action = 'warmup';
      var collecting = false;

      void record(List<FrameTiming> timings) {
        if (!collecting) return;
        for (final timing in timings) {
          samples.add(
            LedgerFrameSample(
              action: action,
              buildMicroseconds: timing.buildDuration.inMicroseconds,
              rasterMicroseconds: timing.rasterDuration.inMicroseconds,
            ),
          );
        }
      }

      binding.addTimingsCallback(record);
      addTearDown(() => binding.removeTimingsCallback(record));

      await tester.pumpWidget(
        _profileApp(orders, invoices, const OrdersScreen()),
      );
      await tester.pumpAndSettle();

      // Warm every expensive branch and scroll path before collecting, matching
      // the acceptance target's "after warm-up" definition.
      await _exerciseLedger(
        tester,
        actionLabel: 'warmup-orders',
        setAction: (value) => action = value,
        forwardCount: 4,
        reverseCount: 2,
      );
      await tester.pumpWidget(
        _profileApp(orders, invoices, const InvoicesScreen()),
      );
      await tester.pumpAndSettle();
      await _exerciseLedger(
        tester,
        actionLabel: 'warmup-invoices',
        setAction: (value) => action = value,
        forwardCount: 4,
        reverseCount: 2,
      );
      await _dragMonthRail(tester);
      await tester.pumpWidget(
        _profileApp(orders, invoices, const OrdersScreen()),
      );
      await tester.pumpAndSettle();
      collecting = true;

      await _exerciseLedger(
        tester,
        actionLabel: 'orders-scroll',
        setAction: (value) => action = value,
      );

      action = 'branch-switch';
      await tester.pumpWidget(
        _profileApp(orders, invoices, const InvoicesScreen()),
      );
      await tester.pumpAndSettle();
      await _exerciseLedger(
        tester,
        actionLabel: 'invoices-scroll',
        setAction: (value) => action = value,
      );

      action = 'month-jump';
      await _dragMonthRail(tester);

      collecting = false;
      expect(samples, isNotEmpty);
      final report = LedgerFrameTimingReport.fromSamples(samples);
      expect(
        report.framesByAction['month-jump'] ?? 0,
        greaterThan(0),
        reason: '月份快速滚动必须实际产生 FrameTiming 样本',
      );
      binding.reportData = {
        'ledgerFrameTiming': report.toJson(environment: environment),
      };
      debugPrint(
        'LEDGER_FRAME_RESULT ${report.toJsonLine(environment: environment)}',
      );

      if (_certify) {
        expect(
          report.meetsTargets,
          isTrue,
          reason: report.toJsonLine(environment: environment),
        );
      }
    },
    skip: !_runHarness,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Widget _profileApp(
  OrderRepository orders,
  InvoiceRepository invoices,
  Widget screen,
) => ProviderScope(
  overrides: [
    orderRepositoryProvider.overrideWithValue(orders),
    invoiceRepositoryProvider.overrideWithValue(invoices),
  ],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.lightTheme,
    home: LiquidGlassBackground(child: screen),
  ),
);

Future<void> _exerciseLedger(
  WidgetTester tester, {
  required String actionLabel,
  required ValueChanged<String> setAction,
  int forwardCount = 18,
  int reverseCount = 6,
}) async {
  final scrollable = find.byType(CustomScrollView);
  expect(scrollable, findsOneWidget);
  for (var index = 0; index < forwardCount; index++) {
    setAction(actionLabel);
    await tester.fling(scrollable, const Offset(0, -620), 1800);
    await tester.pump(const Duration(milliseconds: 220));
  }
  for (var index = 0; index < reverseCount; index++) {
    setAction('$actionLabel-reverse');
    await tester.fling(scrollable, const Offset(0, 520), 1600);
    await tester.pump(const Duration(milliseconds: 180));
  }
}

Future<void> _dragMonthRail(WidgetTester tester) async {
  final monthRail = find.byType(MonthFastScrollBar);
  expect(monthRail, findsOneWidget, reason: '性能验收必须覆盖月份快速滚动');
  final rect = tester.getRect(monthRail);
  await tester.dragFrom(
    Offset(rect.center.dx, rect.top + 24),
    Offset(0, rect.height - 56),
    touchSlopY: 0,
  );
  await tester.pumpAndSettle();
}

Future<LedgerProfileEnvironment> _readProfileEnvironment() async {
  if (!Platform.isAndroid) {
    throw StateError('账簿 profile 帧时验收仅支持 Android 设备');
  }

  final androidInfo = await DeviceInfoPlugin().androidInfo;
  return LedgerProfileEnvironment(
    profileMode: kProfileMode,
    isPhysicalDevice: androidInfo.isPhysicalDevice,
    processAbi: Abi.current(),
    supportedAbis: List.unmodifiable(androidInfo.supportedAbis),
  );
}

class _ProfileOrderRepository extends OrderRepository {
  final List<Order> _items = _orders();

  @override
  Future<List<Order>> getAll({int? limit, int? offset}) async =>
      _page(_items, limit: limit, offset: offset);

  @override
  Future<int> getCount() async => _items.length;

  @override
  Future<List<LedgerMonthSummary>> getMonthSummaries() async =>
      _summaries<Order>(
        _items,
        (item) => item.orderDate!,
        (item) => item.amount,
      );

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
    final filtered = _items
        .where((item) {
          final date = DateTime.parse(item.orderDate!);
          return (startDate == null || !date.isBefore(startDate)) &&
              (endDate == null || !date.isAfter(endDate)) &&
              (hasLinkedInvoice == null || item.hasInvoice == hasLinkedInvoice);
        })
        .toList(growable: false);
    return _page(filtered, limit: limit, offset: offset);
  }
}

class _ProfileInvoiceRepository extends InvoiceRepository {
  final List<Invoice> _items = _invoices();

  @override
  Future<List<Invoice>> getAll({int? limit, int? offset}) async =>
      _page(_items, limit: limit, offset: offset);

  @override
  Future<int> getCount() async => _items.length;

  @override
  Future<List<LedgerMonthSummary>> getMonthSummaries() async =>
      _summaries<Invoice>(
        _items,
        (item) => item.invoiceDate!,
        (item) => item.totalAmount,
      );

  @override
  Future<Map<int, int>> getOrderCountsForInvoices(List<int> invoiceIds) async =>
      {for (final id in invoiceIds) id: id.isEven ? 2 : 1};

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
    final filtered = _items
        .where((item) {
          final date = DateTime.parse(item.invoiceDate!);
          return (startDate == null || !date.isBefore(startDate)) &&
              (endDate == null || !date.isAfter(endDate));
        })
        .toList(growable: false);
    return _page(filtered, limit: limit, offset: offset);
  }
}

List<Order> _orders() => List<Order>.generate(1000, (index) {
  final date = DateTime(2026, 7 - (index % 36), 28 - (index % 28));
  return Order(
    id: 1000 - index,
    imagePath: '/fixture/order-$index.webp',
    shopName: '性能店铺 ${index % 64 + 1}',
    amount: (index % 73) + 1.25,
    orderDate: _date(date),
    mealTime: const ['dinner', 'lunch', 'breakfast'][index % 3],
    orderNumber: 'PERF-O-$index',
    createdAt: date.toIso8601String(),
    updatedAt: date.toIso8601String(),
    hasInvoice: index.isEven,
  );
});

List<Invoice> _invoices() => List<Invoice>.generate(500, (index) {
  final date = DateTime(2026, 7 - (index % 36), 28 - (index % 28));
  return Invoice(
    id: 500 - index,
    imagePath: index.isEven
        ? '/fixture/invoice-$index.pdf'
        : '/fixture/invoice-$index.webp',
    invoiceNumber: 'PERF-I-$index',
    invoiceDate: _date(date),
    totalAmount: (index % 137) + 30.5,
    sellerName: '性能销售方 ${index % 48 + 1}',
    createdAt: date.toIso8601String(),
    updatedAt: date.toIso8601String(),
  );
});

List<LedgerMonthSummary> _summaries<T>(
  List<T> items,
  String Function(T) dateOf,
  double Function(T) amountOf,
) {
  final counts = <String, int>{};
  final totals = <String, double>{};
  for (final item in items) {
    final key = dateOf(item).substring(0, 7);
    counts.update(key, (value) => value + 1, ifAbsent: () => 1);
    totals.update(
      key,
      (value) => value + amountOf(item),
      ifAbsent: () => amountOf(item),
    );
  }
  final keys = counts.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final key in keys)
      LedgerMonthSummary(
        monthKey: key,
        itemCount: counts[key]!,
        totalAmount: totals[key]!,
        linkedItemCount: counts[key]! ~/ 2,
      ),
  ];
}

List<T> _page<T>(List<T> items, {int? limit, int? offset}) {
  final start = (offset ?? 0).clamp(0, items.length);
  final end = limit == null
      ? items.length
      : (start + limit).clamp(start, items.length);
  return items.sublist(start, end);
}

String _date(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

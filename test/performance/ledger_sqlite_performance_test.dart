import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ledger_performance_fixture.dart';

const int ledgerPageSize = 40;

const _strictSqlGate = bool.fromEnvironment(
  'LEDGER_SQL_STRICT',
  defaultValue: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final inMemory in <bool>[true, false]) {
    final storageLabel = inMemory ? '内存 SQLite' : '临时文件 SQLite';

    test(
      '$storageLabel：1000 订单、500 发票、36 个月账簿查询验收',
      () async {
        final fixture = await LedgerPerformanceFixture.open(inMemory: inMemory);
        addTearDown(fixture.close);

        final budgets = _SqlBudgets.forMode(strict: _strictSqlGate);
        expect(
          fixture.seedDuration,
          lessThanOrEqualTo(budgets.seed),
          reason: '批量夹具写入超过 ${budgets.seed.inMilliseconds}ms',
        );

        final rowCounts = await Future.wait([
          fixture.orders.getCount(),
          fixture.invoices.getCount(),
        ]);
        expect(rowCounts, [
          LedgerPerformanceFixture.orderCount,
          LedgerPerformanceFixture.invoiceCount,
        ]);

        final pagination = _LatencySeries('40 条分页');
        final orderIds = <int>{};
        for (
          var offset = 0;
          offset < LedgerPerformanceFixture.orderCount;
          offset += ledgerPageSize
        ) {
          final page = await pagination.measure(
            () => fixture.orders.getAll(limit: ledgerPageSize, offset: offset),
          );
          expect(page, hasLength(ledgerPageSize));
          orderIds.addAll(page.map((order) => order.id!));
        }
        expect(orderIds, hasLength(LedgerPerformanceFixture.orderCount));

        final invoiceIds = <int>{};
        for (
          var offset = 0;
          offset < LedgerPerformanceFixture.invoiceCount;
          offset += ledgerPageSize
        ) {
          final page = await pagination.measure(
            () =>
                fixture.invoices.getAll(limit: ledgerPageSize, offset: offset),
          );
          final expectedLength = math.min(
            ledgerPageSize,
            LedgerPerformanceFixture.invoiceCount - offset,
          );
          expect(page, hasLength(expectedLength));
          invoiceIds.addAll(page.map((invoice) => invoice.id!));
        }
        expect(invoiceIds, hasLength(LedgerPerformanceFixture.invoiceCount));

        final summaries = _LatencySeries('月份轻量汇总');
        for (var iteration = 0; iteration < 12; iteration++) {
          final orderMonths = await summaries.measure(
            fixture.orders.getMonthSummaries,
          );
          final invoiceMonths = await summaries.measure(
            fixture.invoices.getMonthSummaries,
          );
          expect(orderMonths, hasLength(LedgerPerformanceFixture.monthCount));
          expect(invoiceMonths, hasLength(LedgerPerformanceFixture.monthCount));
          expect(
            orderMonths.fold<int>(0, (sum, month) => sum + month.itemCount),
            LedgerPerformanceFixture.orderCount,
          );
          expect(
            orderMonths.fold<int>(
              0,
              (sum, month) => sum + month.linkedItemCount,
            ),
            LedgerPerformanceFixture.linkedOrderCount,
          );
          expect(
            invoiceMonths.fold<int>(0, (sum, month) => sum + month.itemCount),
            LedgerPerformanceFixture.invoiceCount,
          );
          expect(
            invoiceMonths.fold<int>(
              0,
              (sum, month) => sum + month.linkedItemCount,
            ),
            LedgerPerformanceFixture.invoiceCount,
          );
          for (final month in orderMonths) {
            expect(
              month.itemCount,
              fixture.orderMonthCounts[month.monthKey],
              reason: '${month.monthKey} 订单月份计数应来自轻量汇总查询',
            );
          }
          for (final month in invoiceMonths) {
            expect(
              month.itemCount,
              fixture.invoiceMonthCounts[month.monthKey],
              reason: '${month.monthKey} 发票月份计数应来自轻量汇总查询',
            );
          }
        }

        final continuous = _LatencySeries('连续筛选查询');
        for (var iteration = 0; iteration < 120; iteration++) {
          switch (iteration % 4) {
            case 0:
              final rows = await continuous.measure(
                () => fixture.orders.search(
                  shopName: '性能店铺 ${(iteration % 64) + 1}',
                  limit: ledgerPageSize,
                  offset: 0,
                ),
              );
              expect(rows.length, lessThanOrEqualTo(ledgerPageSize));
            case 1:
              final rows = await continuous.measure(
                () => fixture.orders.search(
                  minAmount: 10,
                  maxAmount: 65,
                  hasLinkedInvoice: iteration.isEven,
                  startDate: DateTime(2024, 1, 1),
                  endDate: DateTime(2026, 6, 30),
                  limit: ledgerPageSize,
                  offset: (iteration * ledgerPageSize) % 400,
                ),
              );
              expect(rows.length, lessThanOrEqualTo(ledgerPageSize));
            case 2:
              final rows = await continuous.measure(
                () => fixture.invoices.search(
                  sellerName: '性能销售方 ${(iteration % 48) + 1}',
                  limit: ledgerPageSize,
                  offset: 0,
                ),
              );
              expect(rows.length, lessThanOrEqualTo(ledgerPageSize));
            case 3:
              final rows = await continuous.measure(
                () => fixture.invoices.search(
                  minAmount: 40,
                  maxAmount: 150,
                  hasLinkedOrder: true,
                  startDate: DateTime(2024, 1, 1),
                  endDate: DateTime(2026, 6, 30),
                  limit: ledgerPageSize,
                  offset: (iteration * ledgerPageSize) % 200,
                ),
              );
              expect(rows.length, lessThanOrEqualTo(ledgerPageSize));
          }
        }

        final relations = _LatencySeries('批量关系查询');
        final allOrderIds = List<int>.generate(
          LedgerPerformanceFixture.orderCount,
          (index) => index + 1,
          growable: false,
        );
        final allInvoiceIds = List<int>.generate(
          LedgerPerformanceFixture.invoiceCount,
          (index) => index + 1,
          growable: false,
        );
        for (var iteration = 0; iteration < 6; iteration++) {
          final invoiceCounts = await relations.measure(
            () => fixture.relations.getInvoiceCountsForOrders(allOrderIds),
          );
          expect(
            invoiceCounts,
            hasLength(LedgerPerformanceFixture.linkedOrderCount),
          );
          expect(invoiceCounts.values, everyElement(1));

          final orderCounts = await relations.measure(
            () => fixture.relations.getOrderCountsForInvoices(allInvoiceIds),
          );
          expect(orderCounts, hasLength(LedgerPerformanceFixture.invoiceCount));
          expect(
            orderCounts.values.where((count) => count == 2),
            hasLength(250),
          );
          expect(
            orderCounts.values.where((count) => count == 1),
            hasLength(250),
          );

          final invoicesByOrder = await relations.measure(
            () => fixture.relations.getInvoiceIdsForOrders(allOrderIds),
          );
          expect(
            invoicesByOrder,
            hasLength(LedgerPerformanceFixture.orderCount),
          );
          expect(
            invoicesByOrder.values.where((ids) => ids.isNotEmpty),
            hasLength(LedgerPerformanceFixture.linkedOrderCount),
          );

          final ordersByInvoice = await relations.measure(
            () => fixture.relations.getOrderIdsForInvoices(allInvoiceIds),
          );
          expect(
            ordersByInvoice,
            hasLength(LedgerPerformanceFixture.invoiceCount),
          );
        }

        _expectWithin(pagination, budgets.paginationP90);
        _expectWithin(summaries, budgets.summaryP90);
        _expectWithin(continuous, budgets.continuousP90);
        _expectWithin(relations, budgets.relationP90);

        debugPrint(
          'LEDGER_SQL_RESULT storage=${inMemory ? 'memory' : 'file'} '
          'mode=${_strictSqlGate ? 'strict' : 'portable'} '
          'seed_ms=${fixture.seedDuration.inMicroseconds / 1000} '
          '${pagination.report} ${summaries.report} '
          '${continuous.report} ${relations.report}',
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}

void _expectWithin(_LatencySeries series, Duration p90Budget) {
  expect(series.samples, isNotEmpty);
  expect(
    series.p90Milliseconds,
    lessThanOrEqualTo(p90Budget.inMicroseconds / 1000),
    reason:
        '${series.label} p90=${series.p90Milliseconds.toStringAsFixed(2)}ms '
        '超过 ${p90Budget.inMicroseconds / 1000}ms',
  );
}

class _LatencySeries {
  _LatencySeries(this.label);

  final String label;
  final List<int> _microseconds = [];

  List<int> get samples => List.unmodifiable(_microseconds);

  Future<T> measure<T>(Future<T> Function() action) async {
    final stopwatch = Stopwatch()..start();
    try {
      return await action();
    } finally {
      stopwatch.stop();
      _microseconds.add(stopwatch.elapsedMicroseconds);
    }
  }

  double get p50Milliseconds => _percentile(0.50) / 1000;
  double get p90Milliseconds => _percentile(0.90) / 1000;
  double get p99Milliseconds => _percentile(0.99) / 1000;

  int _percentile(double percentile) {
    final sorted = [..._microseconds]..sort();
    final index = ((sorted.length - 1) * percentile).ceil();
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  String get report =>
      '${label.replaceAll(' ', '_')}='
      '{n:${_microseconds.length},p50_ms:${p50Milliseconds.toStringAsFixed(2)},'
      'p90_ms:${p90Milliseconds.toStringAsFixed(2)},'
      'p99_ms:${p99Milliseconds.toStringAsFixed(2)}}';
}

class _SqlBudgets {
  const _SqlBudgets({
    required this.seed,
    required this.paginationP90,
    required this.summaryP90,
    required this.continuousP90,
    required this.relationP90,
  });

  factory _SqlBudgets.forMode({required bool strict}) => strict
      ? const _SqlBudgets(
          seed: Duration(seconds: 3),
          paginationP90: Duration(milliseconds: 25),
          summaryP90: Duration(milliseconds: 50),
          continuousP90: Duration(milliseconds: 50),
          relationP90: Duration(milliseconds: 75),
        )
      : const _SqlBudgets(
          seed: Duration(seconds: 10),
          paginationP90: Duration(milliseconds: 100),
          summaryP90: Duration(milliseconds: 150),
          continuousP90: Duration(milliseconds: 150),
          relationP90: Duration(milliseconds: 200),
        );

  final Duration seed;
  final Duration paginationP90;
  final Duration summaryP90;
  final Duration continuousP90;
  final Duration relationP90;
}

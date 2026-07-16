import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/data/repositories/invoice_repository.dart';
import 'package:receipt_tamer/data/repositories/order_repository.dart';
import 'package:receipt_tamer/presentation/providers/invoice_provider.dart'
    as invoice_providers;
import 'package:receipt_tamer/presentation/providers/order_provider.dart'
    as order_providers;
import 'package:receipt_tamer/presentation/providers/reimbursement_provider.dart';

void main() {
  test('初始状态不预设报销日期范围', () {
    final fixture = _ReimbursementFixture();
    addTearDown(fixture.dispose);

    final state = fixture.container.read(reimbursementProvider);

    expect(state.startDate, isNull);
    expect(state.endDate, isNull);
    expect(state.hasRange, isFalse);
    expect(state.rangeOrders, isEmpty);
    expect(state.invoiceIds, isEmpty);
    expect(state.closureOrderIds, isEmpty);
    expect(state.canContinue, isFalse);
    expect(fixture.orders.dateRangeCallCount, 0);
  });

  test('任意跨月范围批量建立订单与发票闭包', () async {
    final fixture = _ReimbursementFixture(
      orders: [
        _order(1, '2026-01-31', amount: 12.5),
        _order(2, '2026-02-01', amount: 20),
        _order(3, '2026-02-02', amount: 99),
      ],
      invoiceIdsByOrder: {
        1: {101},
        2: {102},
      },
      orderIdsByInvoice: {
        101: {1},
        102: {2},
      },
    );
    addTearDown(fixture.dispose);

    await fixture.notifier.initializeRange(
      DateTime(2026, 1, 31, 20),
      DateTime(2026, 2, 1, 8),
    );
    final state = fixture.state;

    expect(state.startDate, DateTime(2026, 1, 31));
    expect(state.endDate, DateTime(2026, 2, 1));
    expect(state.rangeOrders.map((order) => order.id), [1, 2]);
    expect(state.unlinkedOrders, isEmpty);
    expect(state.invoiceIds, {101, 102});
    expect(state.outOfRangeOrderIds, isEmpty);
    expect(state.closureOrderIds, {1, 2});
    expect(state.totalAmount, 32.5);
    expect(state.canContinue, isTrue);
    expect(fixture.orders.batchRelationCallCount, 1);
    expect(fixture.orders.lastBatchOrderIds, [1, 2]);
    expect(fixture.invoices.batchRelationCallCount, 1);
    expect(fixture.invoices.lastBatchInvoiceIds, unorderedEquals([101, 102]));
  });

  test('范围内存在未关联订单时阻断继续', () async {
    final fixture = _ReimbursementFixture(
      orders: [_order(1, '2026-03-01'), _order(2, '2026-03-02')],
      invoiceIdsByOrder: {
        1: {101},
      },
      orderIdsByInvoice: {
        101: {1},
      },
    );
    addTearDown(fixture.dispose);

    await fixture.notifier.initializeRange(
      DateTime(2026, 3, 1),
      DateTime(2026, 3, 31),
    );

    expect(fixture.state.unlinkedOrders.map((order) => order.id), [2]);
    expect(fixture.state.invoiceIds, {101});
    expect(fixture.state.canContinue, isFalse);
  });

  test('区间外关联订单必须显式接受，拒绝后再次阻断', () async {
    final fixture = _ReimbursementFixture(
      orders: [
        _order(1, '2026-04-08', amount: 18),
        _order(3, '2026-03-30', amount: 22),
      ],
      invoiceIdsByOrder: {
        1: {101},
      },
      orderIdsByInvoice: {
        101: {1, 3},
      },
    );
    addTearDown(fixture.dispose);

    await fixture.notifier.initializeRange(
      DateTime(2026, 4, 1),
      DateTime(2026, 4, 30),
    );

    expect(fixture.state.outOfRangeOrderIds, {3});
    expect(fixture.state.closureOrderIds, {1, 3});
    expect(fixture.state.closureOrders.map((order) => order.id), [1, 3]);
    expect(fixture.state.totalAmount, 40);
    expect(fixture.state.closureAccepted, isFalse);
    expect(fixture.state.canContinue, isFalse);

    fixture.notifier.setClosureAccepted(true);
    expect(fixture.state.closureAccepted, isTrue);
    expect(fixture.state.canContinue, isTrue);

    fixture.notifier.setClosureAccepted(false);
    expect(fixture.state.closureAccepted, isFalse);
    expect(fixture.state.canContinue, isFalse);
  });

  test('空范围保留用户选择但不能继续', () async {
    final fixture = _ReimbursementFixture();
    addTearDown(fixture.dispose);

    await fixture.notifier.initializeRange(
      DateTime(2026, 5, 1),
      DateTime(2026, 5, 31),
    );

    expect(fixture.state.hasRange, isTrue);
    expect(fixture.state.rangeOrders, isEmpty);
    expect(fixture.state.errorMessage, isNull);
    expect(fixture.state.totalAmount, 0);
    expect(fixture.state.canContinue, isFalse);
  });

  test('仓库错误进入可恢复错误态，refresh 可重新计算且 reset 清空会话', () async {
    final failure = StateError('测试查询失败');
    final fixture = _ReimbursementFixture(
      orders: [_order(1, '2026-06-10')],
      invoiceIdsByOrder: {
        1: {101},
      },
      orderIdsByInvoice: {
        101: {1},
      },
      dateRangeError: failure,
    );
    addTearDown(fixture.dispose);

    await fixture.notifier.initializeRange(
      DateTime(2026, 6, 1),
      DateTime(2026, 6, 30),
    );

    expect(fixture.state.isLoading, isFalse);
    expect(fixture.state.errorMessage, contains('测试查询失败'));
    expect(fixture.state.rangeOrders, isEmpty);
    expect(fixture.state.canContinue, isFalse);

    fixture.orders.dateRangeError = null;
    await fixture.notifier.refresh();
    expect(fixture.state.errorMessage, isNull);
    expect(fixture.state.rangeOrders.map((order) => order.id), [1]);
    expect(fixture.state.canContinue, isTrue);

    fixture.notifier.reset();
    expect(fixture.state.hasRange, isFalse);
    expect(fixture.state.rangeOrders, isEmpty);
    expect(fixture.state.closureAccepted, isFalse);
  });

  test('开始日期晚于结束日期时不访问仓库', () async {
    final fixture = _ReimbursementFixture();
    addTearDown(fixture.dispose);

    await fixture.notifier.initializeRange(
      DateTime(2026, 7, 2),
      DateTime(2026, 7, 1),
    );

    expect(fixture.state.errorMessage, '开始日期不能晚于结束日期');
    expect(fixture.state.canContinue, isFalse);
    expect(fixture.orders.dateRangeCallCount, 0);
  });
}

Order _order(int id, String date, {double amount = 10}) {
  return Order(
    id: id,
    orderDate: date,
    amount: amount,
    shopName: '店铺$id',
    createdAt: '${date}T12:00:00',
    updatedAt: '${date}T12:00:00',
  );
}

class _ReimbursementFixture {
  _ReimbursementFixture({
    List<Order> orders = const [],
    Map<int, Set<int>> invoiceIdsByOrder = const {},
    Map<int, Set<int>> orderIdsByInvoice = const {},
    Object? dateRangeError,
  }) : orders = _FakeOrderRepository(
         orders: orders,
         invoiceIdsByOrder: invoiceIdsByOrder,
         dateRangeError: dateRangeError,
       ),
       invoices = _FakeInvoiceRepository(orderIdsByInvoice: orderIdsByInvoice) {
    container = ProviderContainer(
      overrides: [
        order_providers.orderRepositoryProvider.overrideWithValue(this.orders),
        invoice_providers.invoiceRepositoryProvider.overrideWithValue(invoices),
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
  _FakeOrderRepository({
    required this.orders,
    required this.invoiceIdsByOrder,
    this.dateRangeError,
  });

  final List<Order> orders;
  final Map<int, Set<int>> invoiceIdsByOrder;
  Object? dateRangeError;
  int dateRangeCallCount = 0;
  int batchRelationCallCount = 0;
  List<int> lastBatchOrderIds = const [];

  @override
  Future<List<Order>> getByDateRange(DateTime start, DateTime end) async {
    dateRangeCallCount++;
    final error = dateRangeError;
    if (error != null) throw error;

    return orders
        .where((order) {
          final date = DateTime.tryParse(order.orderDate ?? '');
          return date != null && !date.isBefore(start) && !date.isAfter(end);
        })
        .toList(growable: false);
  }

  @override
  Future<Map<int, Set<int>>> getInvoiceIdsForOrders(List<int> orderIds) async {
    batchRelationCallCount++;
    lastBatchOrderIds = List.of(orderIds);
    return {
      for (final orderId in orderIds)
        orderId: Set.of(invoiceIdsByOrder[orderId] ?? const {}),
    };
  }

  @override
  Future<List<Order>> getByIds(List<int> ids) async {
    final idSet = ids.toSet();
    return orders.where((order) => idSet.contains(order.id)).toList();
  }
}

class _FakeInvoiceRepository extends InvoiceRepository {
  _FakeInvoiceRepository({required this.orderIdsByInvoice});

  final Map<int, Set<int>> orderIdsByInvoice;
  int batchRelationCallCount = 0;
  List<int> lastBatchInvoiceIds = const [];

  @override
  Future<Map<int, Set<int>>> getOrderIdsForInvoices(
    List<int> invoiceIds,
  ) async {
    batchRelationCallCount++;
    lastBatchInvoiceIds = List.of(invoiceIds);
    return {
      for (final invoiceId in invoiceIds)
        invoiceId: Set.of(orderIdsByInvoice[invoiceId] ?? const {}),
    };
  }
}

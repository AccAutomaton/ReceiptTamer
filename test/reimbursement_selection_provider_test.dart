import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/data/repositories/invoice_repository.dart';
import 'package:receipt_tamer/data/repositories/order_repository.dart';
import 'package:receipt_tamer/presentation/providers/export_provider.dart';
import 'package:receipt_tamer/presentation/providers/invoice_export_provider.dart';
import 'package:receipt_tamer/presentation/providers/invoice_provider.dart';
import 'package:receipt_tamer/presentation/providers/order_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('订单日期筛选和手动刷新保留隐藏选择，批量操作只改变当前可见项', () async {
    final fixture = _Fixture(
      orders: <Order>[_order(1, '2026-07-12'), _order(2, '2026-06-11')],
      invoiceIdsByOrder: const <int, Set<int>>{
        1: <int>{101},
        2: <int>{102},
      },
      orderIdsByInvoice: const <int, Set<int>>{
        101: <int>{1},
        102: <int>{2},
      },
    );
    addTearDown(fixture.dispose);
    final notifier = fixture.container.read(exportProvider.notifier);

    await notifier.loadAvailableOrders();
    await notifier.toggleSelection(1);
    await notifier.setDateRange(DateTime(2026, 6, 1), DateTime(2026, 6, 30));

    var state = fixture.container.read(exportProvider);
    expect(state.availableOrders.map((order) => order.id), <int?>[2]);
    expect(state.allSelectedIds, <int>{1});
    expect(state.hiddenSelectedCount, 1);
    expect(state.selectedTotal, 10);
    expect(state.selectedInvoiceIds, <int>{101});

    await notifier.selectAll();
    expect(fixture.container.read(exportProvider).allSelectedIds, <int>{1, 2});
    await notifier.invertSelection();
    state = fixture.container.read(exportProvider);
    expect(state.allSelectedIds, <int>{1});
    expect(state.hiddenSelectedCount, 1);

    await notifier.loadAvailableOrders();
    expect(fixture.container.read(exportProvider).allSelectedIds, <int>{1});
    await notifier.clearDateRange();
    state = fixture.container.read(exportProvider);
    expect(state.visibleOrderIds, <int>{1, 2});
    expect(state.hiddenSelectedCount, 0);
    expect(state.allSelectedIds, <int>{1});
  });

  test('并发订单切换按触发顺序执行，不会由较晚完成的查询覆盖新状态', () async {
    final fixture = _Fixture(
      orders: <Order>[_order(1, '2026-07-12'), _order(2, '2026-07-11')],
      invoiceIdsByOrder: const <int, Set<int>>{
        1: <int>{101},
        2: <int>{101},
      },
      orderIdsByInvoice: const <int, Set<int>>{
        101: <int>{1, 2},
      },
    );
    addTearDown(fixture.dispose);
    final notifier = fixture.container.read(exportProvider.notifier);
    await notifier.loadAvailableOrders();

    await Future.wait(<Future<String?>>[
      notifier.toggleSelection(1),
      notifier.toggleSelection(2),
    ]);

    expect(fixture.container.read(exportProvider).allSelectedIds, isEmpty);
  });

  test('发票日期筛选保留隐藏选择，金额与关联订单仍按完整选择计算', () async {
    final fixture = _Fixture(
      invoices: <Invoice>[
        _invoice(101, '2026-07-13'),
        _invoice(102, '2026-06-11'),
      ],
      orderIdsByInvoice: const <int, Set<int>>{
        101: <int>{1, 3},
        102: <int>{2},
      },
    );
    addTearDown(fixture.dispose);
    final notifier = fixture.container.read(invoiceExportProvider.notifier);

    await notifier.loadAvailableInvoices();
    notifier.toggleSelection(101);
    await notifier.setDateRange(DateTime(2026, 6, 1), DateTime(2026, 6, 30));

    var state = fixture.container.read(invoiceExportProvider);
    expect(state.visibleInvoiceIds, <int>{102});
    expect(state.selectedInvoiceIds, <int>{101});
    expect(state.selectedOrderIds, <int>{1, 3});
    expect(state.hiddenSelectedCount, 1);
    expect(state.selectedTotal, 101);

    notifier.selectAll();
    expect(
      fixture.container.read(invoiceExportProvider).selectedInvoiceIds,
      <int>{101, 102},
    );
    notifier.invertSelection();
    state = fixture.container.read(invoiceExportProvider);
    expect(state.selectedInvoiceIds, <int>{101});
    expect(state.hiddenSelectedCount, 1);

    await notifier.clearDateRange();
    state = fixture.container.read(invoiceExportProvider);
    expect(state.visibleInvoiceIds, <int>{101, 102});
    expect(state.hiddenSelectedCount, 0);
    expect(state.selectedInvoiceIds, <int>{101});
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
  }) {
    container = ProviderContainer(
      overrides: [
        orderRepositoryProvider.overrideWithValue(
          _FakeOrderRepository(
            orders: orders,
            invoiceIdsByOrder: invoiceIdsByOrder,
          ),
        ),
        invoiceRepositoryProvider.overrideWithValue(
          _FakeInvoiceRepository(
            invoices: invoices,
            orderIdsByInvoice: orderIdsByInvoice,
          ),
        ),
      ],
    );
  }

  late final ProviderContainer container;

  void dispose() => container.dispose();
}

class _FakeOrderRepository extends OrderRepository {
  _FakeOrderRepository({required this.orders, required this.invoiceIdsByOrder});

  final List<Order> orders;
  final Map<int, Set<int>> invoiceIdsByOrder;

  @override
  Future<List<Order>> getAll({int? limit, int? offset}) async => orders;

  @override
  Future<List<Order>> getByDateRange(DateTime start, DateTime end) async {
    return orders
        .where((order) {
          final date = DateTime.tryParse(order.orderDate ?? '');
          return date != null && !date.isBefore(start) && !date.isAfter(end);
        })
        .toList(growable: false);
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
  Future<Invoice?> getById(int id) async {
    for (final invoice in invoices) {
      if (invoice.id == id) return invoice;
    }
    return null;
  }

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
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/data/repositories/invoice_repository.dart';
import 'package:receipt_tamer/data/repositories/order_repository.dart';
import 'package:receipt_tamer/presentation/providers/invoice_provider.dart';
import 'package:receipt_tamer/presentation/providers/order_provider.dart';

void main() {
  test('creating a linked invoice refreshes order invoice status', () async {
    final orderRepository = _FakeOrderRepository([
      _order(id: 1, hasInvoice: false),
    ]);
    final invoiceRepository = _FakeInvoiceRepository(orderRepository);
    final container = _container(orderRepository, invoiceRepository);
    addTearDown(container.dispose);

    await container.read(orderProvider.notifier).loadOrders();
    expect(container.read(orderProvider).orders.single.hasInvoice, isFalse);

    final success = await container
        .read(invoiceProvider.notifier)
        .createInvoice(_invoice(), orderIds: [1]);

    expect(success, isTrue);
    expect(orderRepository.getAllCalls, 2);
    expect(container.read(orderProvider).orders.single.hasInvoice, isTrue);
  });

  test('updating invoice relations refreshes order invoice status', () async {
    final orderRepository = _FakeOrderRepository([
      _order(id: 1, hasInvoice: false),
    ]);
    final invoiceRepository = _FakeInvoiceRepository(orderRepository)
      ..seedInvoice(id: 7);
    final container = _container(orderRepository, invoiceRepository);
    addTearDown(container.dispose);

    await container.read(orderProvider.notifier).loadOrders();
    expect(container.read(orderProvider).orders.single.hasInvoice, isFalse);

    await container.read(invoiceProvider.notifier).updateOrderRelations(7, [1]);

    expect(orderRepository.getAllCalls, 2);
    expect(container.read(orderProvider).orders.single.hasInvoice, isTrue);
  });

  test('updating invoice relations refreshes invoice list state', () async {
    final orderRepository = _FakeOrderRepository([
      _order(id: 1, hasInvoice: false),
    ]);
    final invoiceRepository = _FakeInvoiceRepository(orderRepository)
      ..seedInvoice(id: 7);
    final container = _container(orderRepository, invoiceRepository);
    addTearDown(container.dispose);

    await container.read(invoiceProvider.notifier).loadInvoices();
    expect(invoiceRepository.getAllCalls, 1);

    await container.read(invoiceProvider.notifier).updateOrderRelations(7, [1]);

    expect(invoiceRepository.getAllCalls, 2);
    expect(container.read(invoiceProvider).invoices.single.id, 7);
  });

  test('deleting a linked invoice refreshes order invoice status', () async {
    final orderRepository = _FakeOrderRepository([
      _order(id: 1, hasInvoice: true),
    ]);
    final invoiceRepository = _FakeInvoiceRepository(orderRepository)
      ..seedInvoice(id: 7, orderIds: [1]);
    final container = _container(orderRepository, invoiceRepository);
    addTearDown(container.dispose);

    await container.read(orderProvider.notifier).loadOrders();
    expect(container.read(orderProvider).orders.single.hasInvoice, isTrue);

    final success = await container
        .read(invoiceProvider.notifier)
        .deleteInvoice(7);

    expect(success, isTrue);
    expect(orderRepository.getAllCalls, 2);
    expect(container.read(orderProvider).orders.single.hasInvoice, isFalse);
  });

  test('deleting a linked order refreshes invoice list state', () async {
    final orderRepository = _FakeOrderRepository([
      _order(id: 1, hasInvoice: true),
    ])..linkInvoice(orderId: 1, invoiceId: 7);
    final invoiceRepository = _FakeInvoiceRepository(orderRepository)
      ..seedInvoice(id: 7, orderIds: [1]);
    final container = _container(orderRepository, invoiceRepository);
    addTearDown(container.dispose);

    await container.read(invoiceProvider.notifier).loadInvoices();
    expect(invoiceRepository.getAllCalls, 1);

    final success = await container.read(orderProvider.notifier).deleteOrder(1);

    expect(success, isTrue);
    expect(invoiceRepository.getAllCalls, 2);
  });

  test(
    'updating an order preserves its creation time and invoice badge',
    () async {
      final orderRepository = _FakeOrderRepository([
        _order(id: 1, hasInvoice: true),
      ]);
      final invoiceRepository = _FakeInvoiceRepository(orderRepository);
      final container = _container(orderRepository, invoiceRepository);
      addTearDown(container.dispose);

      await container.read(orderProvider.notifier).loadOrders();
      final success = await container
          .read(orderProvider.notifier)
          .updateOrder(
            _order(
              id: 1,
              hasInvoice: false,
            ).copyWith(shopName: 'Updated shop', createdAt: ''),
          );

      expect(success, isTrue);
      expect(
        orderRepository.lastUpdatedOrder?.createdAt,
        '2026-05-31T12:00:00',
      );
      expect(orderRepository.lastUpdatedOrder?.hasInvoice, isTrue);
      expect(
        container.read(orderProvider).orders.single.createdAt,
        '2026-05-31T12:00:00',
      );
      expect(container.read(orderProvider).orders.single.hasInvoice, isTrue);
    },
  );

  test('updating an invoice preserves its creation time', () async {
    final orderRepository = _FakeOrderRepository([]);
    final invoiceRepository = _FakeInvoiceRepository(orderRepository)
      ..seedInvoice(id: 7);
    final container = _container(orderRepository, invoiceRepository);
    addTearDown(container.dispose);

    await container.read(invoiceProvider.notifier).loadInvoices();
    final success = await container
        .read(invoiceProvider.notifier)
        .updateInvoice(
          _invoice(id: 7).copyWith(sellerName: 'Updated seller', createdAt: ''),
          orderIds: const [],
        );

    expect(success, isTrue);
    expect(
      invoiceRepository.lastUpdatedInvoice?.createdAt,
      '2026-05-31T12:00:00',
    );
    expect(
      container.read(invoiceProvider).invoices.single.createdAt,
      '2026-05-31T12:00:00',
    );
  });
}

ProviderContainer _container(
  _FakeOrderRepository orderRepository,
  _FakeInvoiceRepository invoiceRepository,
) {
  return ProviderContainer(
    overrides: [
      orderRepositoryProvider.overrideWithValue(orderRepository),
      invoiceRepositoryProvider.overrideWithValue(invoiceRepository),
    ],
  );
}

Order _order({required int id, required bool hasInvoice}) {
  return Order(
    id: id,
    imagePath: 'order_$id.jpg',
    shopName: 'Shop $id',
    amount: 10,
    orderDate: '2026-05-31',
    mealTime: 'lunch',
    orderNumber: 'order-$id',
    createdAt: '2026-05-31T12:00:00',
    updatedAt: '2026-05-31T12:00:00',
    hasInvoice: hasInvoice,
  );
}

Invoice _invoice({int? id}) {
  return Invoice(
    id: id,
    imagePath: 'invoice.pdf',
    invoiceNumber: 'invoice-${id ?? 'new'}',
    invoiceDate: '2026-05-31',
    totalAmount: 10,
    sellerName: 'Seller',
    createdAt: '2026-05-31T12:00:00',
    updatedAt: '2026-05-31T12:00:00',
  );
}

class _FakeOrderRepository extends OrderRepository {
  _FakeOrderRepository(this._orders);

  List<Order> _orders;
  int getAllCalls = 0;
  Order? lastUpdatedOrder;
  final Map<int, List<int>> _invoiceIdsByOrderId = {};

  @override
  Future<List<Order>> getAll({int? limit, int? offset}) async {
    getAllCalls++;
    return _orders;
  }

  @override
  Future<int> update(Order order) async {
    lastUpdatedOrder = order;
    final index = _orders.indexWhere((candidate) => candidate.id == order.id);
    if (index < 0) return 0;
    _orders[index] = order;
    return 1;
  }

  @override
  Future<int> delete(int id) async {
    final before = _orders.length;
    _orders = _orders.where((order) => order.id != id).toList();
    _invoiceIdsByOrderId.remove(id);
    return before == _orders.length ? 0 : 1;
  }

  @override
  Future<List<int>> getInvoiceIdsForOrder(int orderId) async {
    return [...?_invoiceIdsByOrderId[orderId]];
  }

  void linkInvoice({required int orderId, required int invoiceId}) {
    _invoiceIdsByOrderId[orderId] = [invoiceId];
  }

  void setHasInvoice(int orderId, bool hasInvoice) {
    _orders = [
      for (final order in _orders)
        if (order.id == orderId)
          order.copyWith(hasInvoice: hasInvoice)
        else
          order,
    ];
  }
}

class _FakeInvoiceRepository extends InvoiceRepository {
  _FakeInvoiceRepository(this._orderRepository);

  final _FakeOrderRepository _orderRepository;
  final Map<int, Invoice> _invoices = {};
  final Map<int, List<int>> _relations = {};
  int _nextInvoiceId = 1;
  int getAllCalls = 0;
  Invoice? lastUpdatedInvoice;

  void seedInvoice({required int id, List<int> orderIds = const []}) {
    _invoices[id] = _invoice(id: id);
    _relations[id] = [...orderIds];
  }

  @override
  Future<int> create(Invoice invoice, {List<int>? orderIds}) async {
    final id = _nextInvoiceId++;
    _invoices[id] = invoice.copyWith(id: id);
    _replaceRelations(id, orderIds ?? const []);
    return id;
  }

  @override
  Future<int> delete(int id) async {
    final orderIds = _relations.remove(id) ?? const [];
    for (final orderId in orderIds) {
      _orderRepository.setHasInvoice(orderId, false);
    }
    return _invoices.remove(id) == null ? 0 : 1;
  }

  @override
  Future<List<Invoice>> getAll({int? limit, int? offset}) async {
    getAllCalls++;
    return _invoices.values.toList();
  }

  @override
  Future<int> update(Invoice invoice, {List<int>? orderIds}) async {
    final id = invoice.id;
    if (id == null || !_invoices.containsKey(id)) return 0;
    lastUpdatedInvoice = invoice;
    _invoices[id] = invoice;
    if (orderIds != null) {
      _replaceRelations(id, orderIds);
    }
    return 1;
  }

  @override
  Future<List<Invoice>> getByOrderId(
    int orderId, {
    int? limit,
    int? offset,
  }) async {
    return [
      for (final entry in _relations.entries)
        if (entry.value.contains(orderId)) _invoices[entry.key]!,
    ];
  }

  @override
  Future<List<int>> getOrderIdsForInvoice(int invoiceId) async {
    return [...?_relations[invoiceId]];
  }

  @override
  Future<int> getCount() async {
    return _invoices.length;
  }

  @override
  Future<int> getOrderCountForInvoice(int invoiceId) async {
    return _relations[invoiceId]?.length ?? 0;
  }

  @override
  Future<Map<int, int>> getOrderCountsForInvoices(List<int> invoiceIds) async {
    return {
      for (final invoiceId in invoiceIds)
        invoiceId: _relations[invoiceId]?.length ?? 0,
    };
  }

  @override
  Future<void> updateOrderRelations(int invoiceId, List<int> orderIds) async {
    _replaceRelations(invoiceId, orderIds);
  }

  void _replaceRelations(int invoiceId, List<int> orderIds) {
    final previousOrderIds = _relations[invoiceId] ?? const [];
    for (final orderId in previousOrderIds) {
      _orderRepository.setHasInvoice(orderId, false);
    }
    _relations[invoiceId] = [...orderIds];
    for (final orderId in orderIds) {
      _orderRepository.setHasInvoice(orderId, true);
    }
  }
}

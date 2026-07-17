import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/data/repositories/invoice_repository.dart';
import 'package:receipt_tamer/data/repositories/order_repository.dart';
import 'package:receipt_tamer/presentation/providers/invoice_provider.dart';
import 'package:receipt_tamer/presentation/providers/ledger_data_revision_provider.dart';
import 'package:receipt_tamer/presentation/providers/order_provider.dart';

void main() {
  test(
    'ordinary order and invoice reads do not advance the revision',
    () async {
      final orderRepository = _RevisionOrderRepository([_order(id: 1)]);
      final invoiceRepository = _RevisionInvoiceRepository([_invoice(id: 7)]);
      final container = ProviderContainer(
        overrides: [
          orderRepositoryProvider.overrideWithValue(orderRepository),
          invoiceRepositoryProvider.overrideWithValue(invoiceRepository),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(ledgerDataRevisionProvider), 0);
      await container.read(orderProvider.notifier).loadOrders();
      await container.read(orderProvider.notifier).getOrderById(1);
      await container.read(invoiceProvider.notifier).loadInvoices();
      await container.read(invoiceProvider.notifier).getInvoiceById(7);

      expect(container.read(ledgerDataRevisionProvider), 0);
    },
  );

  test('successful order writes advance the revision once each', () async {
    final repository = _RevisionOrderRepository([_order(id: 1)]);
    final container = ProviderContainer(
      overrides: [orderRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(orderProvider.notifier).loadOrders();
    expect(
      await container.read(orderProvider.notifier).createOrder(_order()),
      isTrue,
    );
    expect(container.read(ledgerDataRevisionProvider), 1);

    expect(
      await container
          .read(orderProvider.notifier)
          .updateOrder(_order(id: 2).copyWith(shopName: 'Updated')),
      isTrue,
    );
    expect(container.read(ledgerDataRevisionProvider), 2);

    expect(await container.read(orderProvider.notifier).deleteOrder(2), isTrue);
    expect(container.read(ledgerDataRevisionProvider), 3);
  });

  test('rejected order writes do not advance the revision', () async {
    final repository = _RevisionOrderRepository([_order(id: 1)])
      ..acceptWrites = false;
    final container = ProviderContainer(
      overrides: [orderRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(orderProvider.notifier).loadOrders();
    expect(
      await container.read(orderProvider.notifier).createOrder(_order()),
      isFalse,
    );
    expect(
      await container.read(orderProvider.notifier).updateOrder(_order(id: 1)),
      isFalse,
    );
    expect(
      await container.read(orderProvider.notifier).deleteOrder(1),
      isFalse,
    );

    expect(container.read(ledgerDataRevisionProvider), 0);
  });

  test('successful invoice and relation writes advance the revision', () async {
    final repository = _RevisionInvoiceRepository([_invoice(id: 7)]);
    final container = ProviderContainer(
      overrides: [invoiceRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(invoiceProvider.notifier).loadInvoices();
    expect(
      await container.read(invoiceProvider.notifier).createInvoice(_invoice()),
      isTrue,
    );
    expect(container.read(ledgerDataRevisionProvider), 1);

    expect(
      await container
          .read(invoiceProvider.notifier)
          .updateInvoice(_invoice(id: 8).copyWith(sellerName: 'Updated')),
      isTrue,
    );
    expect(container.read(ledgerDataRevisionProvider), 2);

    await container
        .read(invoiceProvider.notifier)
        .updateOrderRelations(8, const []);
    expect(container.read(ledgerDataRevisionProvider), 3);

    expect(
      await container.read(invoiceProvider.notifier).deleteInvoice(8),
      isTrue,
    );
    expect(container.read(ledgerDataRevisionProvider), 4);
  });

  test(
    'failed invoice and relation writes do not advance the revision',
    () async {
      final repository = _RevisionInvoiceRepository([_invoice(id: 7)])
        ..acceptWrites = false;
      final container = ProviderContainer(
        overrides: [invoiceRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container.read(invoiceProvider.notifier).loadInvoices();
      expect(
        await container
            .read(invoiceProvider.notifier)
            .createInvoice(_invoice()),
        isFalse,
      );
      expect(
        await container
            .read(invoiceProvider.notifier)
            .updateInvoice(_invoice(id: 7)),
        isFalse,
      );
      expect(
        await container.read(invoiceProvider.notifier).deleteInvoice(7),
        isFalse,
      );
      await expectLater(
        container
            .read(invoiceProvider.notifier)
            .updateOrderRelations(7, const []),
        throwsStateError,
      );

      expect(container.read(ledgerDataRevisionProvider), 0);
    },
  );
}

Order _order({int? id}) {
  return Order(
    id: id,
    imagePath: 'order.jpg',
    shopName: 'Shop',
    amount: 10,
    orderDate: '2026-07-17',
    mealTime: 'lunch',
    orderNumber: 'order-${id ?? 'new'}',
    createdAt: '2026-07-17T12:00:00',
    updatedAt: '2026-07-17T12:00:00',
  );
}

Invoice _invoice({int? id}) {
  return Invoice(
    id: id,
    imagePath: 'invoice.pdf',
    invoiceNumber: 'invoice-${id ?? 'new'}',
    invoiceDate: '2026-07-17',
    totalAmount: 10,
    sellerName: 'Seller',
    createdAt: '2026-07-17T12:00:00',
    updatedAt: '2026-07-17T12:00:00',
  );
}

class _RevisionOrderRepository extends OrderRepository {
  _RevisionOrderRepository(List<Order> orders) : _orders = [...orders];

  List<Order> _orders;
  bool acceptWrites = true;
  int _nextId = 2;

  @override
  Future<List<Order>> getAll({int? limit, int? offset}) async => [..._orders];

  @override
  Future<Order?> getById(int id) async {
    for (final order in _orders) {
      if (order.id == id) return order;
    }
    return null;
  }

  @override
  Future<int> create(Order order) async {
    if (!acceptWrites) return 0;
    final id = _nextId++;
    _orders.add(order.copyWith(id: id));
    return id;
  }

  @override
  Future<int> update(Order order) async {
    if (!acceptWrites) return 0;
    final index = _orders.indexWhere((candidate) => candidate.id == order.id);
    if (index < 0) return 0;
    _orders[index] = order;
    return 1;
  }

  @override
  Future<int> delete(int id) async {
    if (!acceptWrites) return 0;
    final originalLength = _orders.length;
    _orders = _orders.where((order) => order.id != id).toList();
    return originalLength == _orders.length ? 0 : 1;
  }

  @override
  Future<List<int>> getInvoiceIdsForOrder(int orderId) async => const [];
}

class _RevisionInvoiceRepository extends InvoiceRepository {
  _RevisionInvoiceRepository(List<Invoice> invoices)
    : _invoices = {for (final invoice in invoices) invoice.id!: invoice};

  final Map<int, Invoice> _invoices;
  bool acceptWrites = true;
  int _nextId = 8;

  @override
  Future<List<Invoice>> getAll({int? limit, int? offset}) async {
    return _invoices.values.toList();
  }

  @override
  Future<Invoice?> getById(int id) async => _invoices[id];

  @override
  Future<int> create(Invoice invoice, {List<int>? orderIds}) async {
    if (!acceptWrites) return 0;
    final id = _nextId++;
    _invoices[id] = invoice.copyWith(id: id);
    return id;
  }

  @override
  Future<int> update(Invoice invoice, {List<int>? orderIds}) async {
    if (!acceptWrites ||
        invoice.id == null ||
        !_invoices.containsKey(invoice.id)) {
      return 0;
    }
    _invoices[invoice.id!] = invoice;
    return 1;
  }

  @override
  Future<int> delete(int id) async {
    if (!acceptWrites) return 0;
    return _invoices.remove(id) == null ? 0 : 1;
  }

  @override
  Future<List<int>> getOrderIdsForInvoice(int invoiceId) async => const [];

  @override
  Future<void> updateOrderRelations(int invoiceId, List<int> orderIds) async {
    if (!acceptWrites) throw StateError('simulated relation write failure');
  }
}

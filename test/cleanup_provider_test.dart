import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:receipt_tamer/core/constants/app_constants.dart';
import 'package:receipt_tamer/data/datasources/database/invoice_order_relation_table.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/data/repositories/invoice_repository.dart';
import 'package:receipt_tamer/data/repositories/order_repository.dart';
import 'package:receipt_tamer/data/services/cleanup_service.dart';
import 'package:receipt_tamer/presentation/providers/cleanup_provider.dart'
    as cleanup;
import 'package:receipt_tamer/presentation/providers/invoice_provider.dart'
    as invoices;
import 'package:receipt_tamer/presentation/providers/ledger_data_revision_provider.dart';
import 'package:receipt_tamer/presentation/providers/order_provider.dart'
    as orders;
import 'package:receipt_tamer/presentation/screens/cleanup/order_cleanup_screen.dart';
import 'package:receipt_tamer/presentation/screens/cleanup/invoice_cleanup_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late _FakeOrderRepository orderRepository;
  late _FakeInvoiceRepository invoiceRepository;
  late _FakeCleanupService cleanupService;
  late ProviderContainer container;

  setUp(() {
    orderRepository = _FakeOrderRepository([
      _order(id: 1, amount: 10, date: '2026-07-01'),
      _order(id: 2, amount: 20, date: '2026-06-01'),
    ]);
    invoiceRepository = _FakeInvoiceRepository([
      _invoice(id: 7, amount: 30, date: '2026-07-01'),
    ]);
    cleanupService = _FakeCleanupService(
      orderRepository: orderRepository,
      invoiceRepository: invoiceRepository,
      orderCascadeIds: const {2},
    );
    container = ProviderContainer(
      overrides: [
        cleanup.orderRepositoryProvider.overrideWithValue(orderRepository),
        cleanup.invoiceRepositoryProvider.overrideWithValue(invoiceRepository),
        cleanup.cleanupServiceProvider.overrideWithValue(cleanupService),
        orders.orderRepositoryProvider.overrideWithValue(orderRepository),
        invoices.invoiceRepositoryProvider.overrideWithValue(invoiceRepository),
      ],
    );
    addTearDown(container.dispose);
  });

  test('entering or switching cleanup mode resets cascade option', () async {
    final notifier = container.read(cleanup.cleanupProvider.notifier);

    await notifier.loadAvailableItems();
    await notifier.toggleDeleteRelatedItems();
    expect(container.read(cleanup.cleanupProvider).deleteRelatedItems, isTrue);

    notifier.setMode(cleanup.CleanupMode.invoices);

    final state = container.read(cleanup.cleanupProvider);
    expect(state.mode, cleanup.CleanupMode.invoices);
    expect(state.deleteRelatedItems, isFalse);
    expect(state.selectedIds, isEmpty);
    expect(state.cascadeIds, isEmpty);
  });

  test('changing date filter immediately trims the prior selection', () async {
    final notifier = container.read(cleanup.cleanupProvider.notifier);
    await notifier.loadAvailableItems();
    await notifier.toggleSelection(1);
    expect(container.read(cleanup.cleanupProvider).selectedIds, {1});

    final loading = notifier.setDateRange(
      DateTime(2026, 7, 1),
      DateTime(2026, 7, 31),
    );

    expect(container.read(cleanup.cleanupProvider).selectedIds, isEmpty);
    expect(container.read(cleanup.cleanupProvider).cascadeIds, isEmpty);
    await loading;
    expect(
      container
          .read(cleanup.cleanupProvider)
          .availableOrders
          .map((item) => item.id),
      [1],
    );
  });

  test(
    'hidden cascade keeps filtered list strict and contributes full amount',
    () async {
      final notifier = container.read(cleanup.cleanupProvider.notifier);
      await notifier.setDateRange(DateTime(2026, 7, 1), DateTime(2026, 7, 31));
      await notifier.toggleDeleteRelatedItems();

      final message = await notifier.toggleSelection(1);
      final state = container.read(cleanup.cleanupProvider);

      expect(state.availableOrders.map((item) => item.id), [1]);
      expect(state.visibleSelectedIds, {1});
      expect(state.cascadeIds, {2});
      expect(state.hiddenCascadeCount, 1);
      expect(state.totalSelectedCount, 2);
      expect(state.selectedTotalAmount, 30);
      expect(message, contains('当前筛选范围外'));
    },
  );

  test(
    'execute cleanup passes only visible direct IDs to the service',
    () async {
      final notifier = container.read(cleanup.cleanupProvider.notifier);
      await notifier.setDateRange(DateTime(2026, 7, 1), DateTime(2026, 7, 31));
      await notifier.toggleDeleteRelatedItems();
      await notifier.toggleSelection(1);

      final result = await notifier.executeCleanup();

      expect(result?.ordersDeleted, 2);
      expect(cleanupService.lastDeletedOrderIds, {1});
      expect(container.read(ledgerDataRevisionProvider), 1);
      expect(container.read(cleanup.cleanupProvider).availableOrders, isEmpty);
      expect(container.read(cleanup.cleanupProvider).isDeleting, isFalse);
    },
  );

  test(
    'successful deletion remains successful when post-delete refresh fails',
    () async {
      final notifier = container.read(cleanup.cleanupProvider.notifier);
      await notifier.loadAvailableItems();
      await notifier.toggleSelection(1);
      orderRepository.failReads = true;

      final result = await notifier.executeCleanup();
      final stateAfterDelete = container.read(cleanup.cleanupProvider);

      expect(result?.ordersDeleted, 1);
      expect(cleanupService.lastDeletedOrderIds, {1});
      expect(container.read(ledgerDataRevisionProvider), 1);
      expect(stateAfterDelete.errorMessage, isNull);
      expect(stateAfterDelete.refreshWarningMessage, contains('清理已完成'));
      expect(stateAfterDelete.selectedIds, isEmpty);
      expect(stateAfterDelete.isDeleting, isFalse);

      orderRepository.failReads = false;
      await notifier.retryRefreshAfterCleanup();

      final refreshedState = container.read(cleanup.cleanupProvider);
      expect(refreshedState.refreshWarningMessage, isNull);
      expect(refreshedState.availableOrders.map((item) => item.id), [2]);
    },
  );

  test(
    'invoice cascade amount also includes records outside visible filter',
    () async {
      invoiceRepository.invoices.add(
        _invoice(id: 8, amount: 40, date: '2026-06-01'),
      );
      cleanupService.invoiceCascadeIds = const {8};
      final notifier = container.read(cleanup.cleanupProvider.notifier);
      notifier.setMode(cleanup.CleanupMode.invoices);
      await notifier.setDateRange(DateTime(2026, 7, 1), DateTime(2026, 7, 31));
      await notifier.toggleDeleteRelatedItems();
      await notifier.toggleSelection(7);

      final state = container.read(cleanup.cleanupProvider);
      expect(state.availableInvoices.map((item) => item.id), [7]);
      expect(state.cascadeIds, {8});
      expect(state.hiddenCascadeCount, 1);
      expect(state.selectedTotalAmount, 70);
    },
  );

  test(
    'real cleanup service deletes exactly the disclosed order cascade',
    () async {
      final graph = await _CleanupGraphHarness.create(
        orders: [
          _graphOrder(id: 1, amount: 10),
          _graphOrder(id: 2, amount: 20),
          _graphOrder(id: 3, amount: 30),
        ],
        invoices: [
          _graphInvoice(id: 1, amount: 15),
          _graphInvoice(id: 2, amount: 35),
        ],
        relations: const [
          [1, 1],
          [1, 2],
          [2, 2],
          [2, 3],
        ],
      );
      addTearDown(graph.close);
      final graphContainer = _graphContainer(graph);
      addTearDown(graphContainer.dispose);
      final notifier = graphContainer.read(cleanup.cleanupProvider.notifier);

      await notifier.loadAvailableItems();
      await notifier.toggleDeleteRelatedItems();
      await notifier.toggleSelection(1);

      final disclosed = graphContainer.read(cleanup.cleanupProvider);
      expect(disclosed.visibleSelectedIds, {1});
      expect(disclosed.cascadeIds, {2});
      expect(disclosed.allSelectedIds, {1, 2});
      expect(disclosed.selectedTotalAmount, 30);
      expect(await notifier.getRelatedInvoiceCount(), 2);

      final result = await notifier.executeCleanup();

      expect(result?.cascadeOrderIds, {2});
      expect(result?.ordersDeleted, 2);
      expect(result?.invoicesDeleted, 2);
      expect((await graph.orderRepository.getAll()).map((item) => item.id), [
        3,
      ]);
      expect(await graph.invoiceRepository.getAll(), isEmpty);
    },
  );

  test(
    'real cleanup service deletes exactly the disclosed invoice cascade',
    () async {
      final graph = await _CleanupGraphHarness.create(
        orders: [
          _graphOrder(id: 1, amount: 10),
          _graphOrder(id: 2, amount: 20),
        ],
        invoices: [
          _graphInvoice(id: 1, amount: 15),
          _graphInvoice(id: 2, amount: 35),
          _graphInvoice(id: 3, amount: 55),
        ],
        relations: const [
          [1, 1],
          [2, 1],
          [2, 2],
          [3, 2],
        ],
      );
      addTearDown(graph.close);
      final graphContainer = _graphContainer(graph);
      addTearDown(graphContainer.dispose);
      final notifier = graphContainer.read(cleanup.cleanupProvider.notifier);

      notifier.setMode(cleanup.CleanupMode.invoices);
      await notifier.loadAvailableItems();
      await notifier.toggleDeleteRelatedItems();
      await notifier.toggleSelection(1);

      final disclosed = graphContainer.read(cleanup.cleanupProvider);
      expect(disclosed.visibleSelectedIds, {1});
      expect(disclosed.cascadeIds, {2});
      expect(disclosed.allSelectedIds, {1, 2});
      expect(disclosed.selectedTotalAmount, 50);
      expect(await notifier.getRelatedOrderCount(), 2);

      final result = await notifier.executeCleanup();

      expect(result?.cascadeInvoiceIds, {2});
      expect(result?.invoicesDeleted, 2);
      expect(result?.ordersDeleted, 2);
      expect((await graph.invoiceRepository.getAll()).map((item) => item.id), [
        3,
      ]);
      expect(await graph.orderRepository.getAll(), isEmpty);
    },
  );

  testWidgets('deleting the final item keeps results until user confirms', (
    tester,
  ) async {
    orderRepository.orders.removeWhere((item) => item.id == 2);
    final router = GoRouter(
      initialLocation: '/host',
      routes: [
        GoRoute(
          path: '/host',
          builder: (context, state) => const Scaffold(body: Text('Host')),
        ),
        GoRoute(
          path: '/cleanup',
          builder: (context, state) => const OrderCleanupScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.push('/cleanup');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Shop 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '确认删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(find.text('清理完成'), findsOneWidget);
    expect(find.byType(OrderCleanupScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('清理完成'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '确定'));
    await tester.pumpAndSettle();
    expect(find.text('Host'), findsOneWidget);
    expect(find.byType(OrderCleanupScreen), findsNothing);
  });

  testWidgets('final invoice cleanup also waits for result confirmation', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/host',
      routes: [
        GoRoute(
          path: '/host',
          builder: (context, state) => const Scaffold(body: Text('Host')),
        ),
        GoRoute(
          path: '/cleanup',
          builder: (context, state) => const InvoiceCleanupScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.push('/cleanup');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Seller 7'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '确认删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(find.text('清理完成'), findsOneWidget);
    expect(find.byType(InvoiceCleanupScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('清理完成'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '确定'));
    await tester.pumpAndSettle();
    expect(find.text('Host'), findsOneWidget);
    expect(find.byType(InvoiceCleanupScreen), findsNothing);
  });
}

Order _order({required int id, required double amount, required String date}) {
  return Order(
    id: id,
    imagePath: 'order_$id.jpg',
    shopName: 'Shop $id',
    amount: amount,
    orderDate: date,
    mealTime: 'lunch',
    orderNumber: 'order-$id',
    createdAt: '${date}T12:00:00',
    updatedAt: '${date}T12:00:00',
  );
}

Invoice _invoice({
  required int id,
  required double amount,
  required String date,
}) {
  return Invoice(
    id: id,
    imagePath: 'invoice_$id.pdf',
    invoiceNumber: 'invoice-$id',
    invoiceDate: date,
    totalAmount: amount,
    sellerName: 'Seller $id',
    createdAt: '${date}T12:00:00',
    updatedAt: '${date}T12:00:00',
  );
}

class _FakeOrderRepository extends OrderRepository {
  _FakeOrderRepository(this.orders);

  final List<Order> orders;
  bool failReads = false;

  @override
  Future<List<Order>> getAll({int? limit, int? offset}) async {
    if (failReads) throw StateError('simulated order refresh failure');
    return List<Order>.of(orders);
  }

  @override
  Future<List<Order>> getByDateRange(DateTime start, DateTime end) async {
    if (failReads) throw StateError('simulated order refresh failure');
    return orders.where((item) {
      final date = DateTime.parse(item.orderDate!);
      return !date.isBefore(start) && !date.isAfter(end);
    }).toList();
  }

  @override
  Future<List<int>> getInvoiceIdsForOrder(int orderId) async =>
      orderId == 1 || orderId == 2 ? const [7] : const [];
}

class _FakeInvoiceRepository extends InvoiceRepository {
  _FakeInvoiceRepository(this.invoices);

  final List<Invoice> invoices;

  @override
  Future<List<Invoice>> getAll({int? limit, int? offset}) async =>
      List<Invoice>.of(invoices);

  @override
  Future<List<Invoice>> getByDateRange(DateTime start, DateTime end) async {
    return invoices.where((item) {
      final date = DateTime.parse(item.invoiceDate!);
      return !date.isBefore(start) && !date.isAfter(end);
    }).toList();
  }

  @override
  Future<List<int>> getOrderIdsForInvoice(int invoiceId) async =>
      invoiceId == 7 ? const [1, 2] : const [];
}

class _FakeCleanupService extends CleanupService {
  _FakeCleanupService({
    required this.orderRepository,
    required this.invoiceRepository,
    this.orderCascadeIds = const {},
  });

  final _FakeOrderRepository orderRepository;
  final _FakeInvoiceRepository invoiceRepository;
  Set<int> orderCascadeIds;
  Set<int> invoiceCascadeIds = const {};
  Set<int>? lastDeletedOrderIds;
  Set<int>? lastDeletedInvoiceIds;

  @override
  Future<Set<int>> calculateCascadeOrders({
    required Set<int> selectedOrderIds,
    bool deleteInvoices = false,
  }) async =>
      deleteInvoices && selectedOrderIds.isNotEmpty ? orderCascadeIds : {};

  @override
  Future<Set<int>> calculateCascadeInvoices({
    required Set<int> selectedInvoiceIds,
    bool deleteOrders = false,
  }) async =>
      deleteOrders && selectedInvoiceIds.isNotEmpty ? invoiceCascadeIds : {};

  @override
  Future<Order?> getOrderById(int orderId) async =>
      orderRepository.orders.where((item) => item.id == orderId).firstOrNull;

  @override
  Future<Invoice?> getInvoiceById(int invoiceId) async => invoiceRepository
      .invoices
      .where((item) => item.id == invoiceId)
      .firstOrNull;

  @override
  Future<List<int>> getInvoiceIdsForOrder(int orderId) =>
      orderRepository.getInvoiceIdsForOrder(orderId);

  @override
  Future<List<int>> getOrderIdsForInvoice(int invoiceId) =>
      invoiceRepository.getOrderIdsForInvoice(invoiceId);

  @override
  Future<CleanupResult> deleteOrders({
    required Set<int> orderIds,
    bool deleteInvoices = false,
  }) async {
    lastDeletedOrderIds = Set<int>.of(orderIds);
    final allOrderIds = {...orderIds, if (deleteInvoices) ...orderCascadeIds};
    orderRepository.orders.removeWhere((item) => allOrderIds.contains(item.id));
    if (deleteInvoices) {
      invoiceRepository.invoices.removeWhere((item) => item.id == 7);
    }
    return CleanupResult(
      ordersDeleted: allOrderIds.length,
      invoicesDeleted: deleteInvoices ? 1 : 0,
    );
  }

  @override
  Future<CleanupResult> deleteInvoices({
    required Set<int> invoiceIds,
    bool deleteOrders = false,
  }) async {
    lastDeletedInvoiceIds = Set<int>.of(invoiceIds);
    invoiceRepository.invoices.removeWhere(
      (item) => invoiceIds.contains(item.id),
    );
    return CleanupResult(invoicesDeleted: invoiceIds.length);
  }
}

Order _graphOrder({required int id, required double amount}) => Order(
  id: id,
  shopName: 'Graph Shop $id',
  amount: amount,
  orderDate: '2026-07-01',
  createdAt: '2026-07-01T12:00:00',
  updatedAt: '2026-07-01T12:00:00',
);

Invoice _graphInvoice({required int id, required double amount}) => Invoice(
  id: id,
  invoiceNumber: 'graph-invoice-$id',
  invoiceDate: '2026-07-01',
  totalAmount: amount,
  sellerName: 'Graph Seller $id',
  createdAt: '2026-07-01T12:00:00',
  updatedAt: '2026-07-01T12:00:00',
);

ProviderContainer _graphContainer(_CleanupGraphHarness graph) {
  final service = CleanupService(
    orderRepository: graph.orderRepository,
    invoiceRepository: graph.invoiceRepository,
    relationTable: graph.relationTable,
    database: graph.database,
  );
  return ProviderContainer(
    overrides: [
      cleanup.orderRepositoryProvider.overrideWithValue(graph.orderRepository),
      cleanup.invoiceRepositoryProvider.overrideWithValue(
        graph.invoiceRepository,
      ),
      cleanup.cleanupServiceProvider.overrideWithValue(service),
      orders.orderRepositoryProvider.overrideWithValue(graph.orderRepository),
      invoices.invoiceRepositoryProvider.overrideWithValue(
        graph.invoiceRepository,
      ),
    ],
  );
}

class _CleanupGraphHarness {
  _CleanupGraphHarness({
    required this.database,
    required this.relationTable,
    required this.orderRepository,
    required this.invoiceRepository,
  });

  final Database database;
  final InvoiceOrderRelationTable relationTable;
  final _GraphOrderRepository orderRepository;
  final _GraphInvoiceRepository invoiceRepository;

  static Future<_CleanupGraphHarness> create({
    required List<Order> orders,
    required List<Invoice> invoices,
    required List<List<int>> relations,
  }) async {
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
    );
    await database.execute('''
      CREATE TABLE ${AppConstants.ordersTable} (
        ${AppConstants.colId} INTEGER PRIMARY KEY,
        ${AppConstants.colImagePath} TEXT NOT NULL DEFAULT ''
      )
    ''');
    await database.execute('''
      CREATE TABLE ${AppConstants.invoicesTable} (
        ${AppConstants.colId} INTEGER PRIMARY KEY,
        ${AppConstants.colImagePath} TEXT NOT NULL DEFAULT ''
      )
    ''');
    await database.execute('''
      CREATE TABLE ${AppConstants.invoiceOrderRelationsTable} (
        ${AppConstants.colInvoiceId} INTEGER NOT NULL,
        ${AppConstants.colOrderId} INTEGER NOT NULL,
        PRIMARY KEY (
          ${AppConstants.colInvoiceId},
          ${AppConstants.colOrderId}
        )
      )
    ''');
    for (final order in orders) {
      await database.insert(AppConstants.ordersTable, {
        AppConstants.colId: order.id,
        AppConstants.colImagePath: order.imagePath,
      });
    }
    for (final invoice in invoices) {
      await database.insert(AppConstants.invoicesTable, {
        AppConstants.colId: invoice.id,
        AppConstants.colImagePath: invoice.imagePath,
      });
    }
    for (final relation in relations) {
      await database.insert(AppConstants.invoiceOrderRelationsTable, {
        AppConstants.colInvoiceId: relation[0],
        AppConstants.colOrderId: relation[1],
      });
    }

    final relationTable = InvoiceOrderRelationTable(database: database);
    return _CleanupGraphHarness(
      database: database,
      relationTable: relationTable,
      orderRepository: _GraphOrderRepository(
        database: database,
        relationTable: relationTable,
        orders: List<Order>.of(orders),
      ),
      invoiceRepository: _GraphInvoiceRepository(
        database: database,
        relationTable: relationTable,
        invoices: List<Invoice>.of(invoices),
      ),
    );
  }

  Future<void> close() => database.close();
}

class _GraphOrderRepository extends OrderRepository {
  _GraphOrderRepository({
    required this.database,
    required this.relationTable,
    required this.orders,
  });

  final Database database;
  final InvoiceOrderRelationTable relationTable;
  final List<Order> orders;

  @override
  Future<List<Order>> getAll({int? limit, int? offset}) async {
    final remainingIds = await _remainingIds();
    return orders.where((item) => remainingIds.contains(item.id)).toList();
  }

  @override
  Future<List<Order>> getByDateRange(DateTime start, DateTime end) async {
    final remaining = await getAll();
    return remaining.where((item) {
      final date = DateTime.parse(item.orderDate!);
      return !date.isBefore(start) && !date.isAfter(end);
    }).toList();
  }

  @override
  Future<Order?> getById(int id) async {
    if (!(await _remainingIds()).contains(id)) return null;
    for (final order in orders) {
      if (order.id == id) return order;
    }
    return null;
  }

  @override
  Future<List<int>> getInvoiceIdsForOrder(int orderId) =>
      relationTable.getInvoiceIdsForOrder(orderId);

  @override
  Future<int> delete(int id) async {
    final existed = orders.any((item) => item.id == id);
    await relationTable.deleteByOrderId(id);
    await database.delete(
      AppConstants.ordersTable,
      where: '${AppConstants.colId} = ?',
      whereArgs: [id],
    );
    orders.removeWhere((item) => item.id == id);
    return existed ? 1 : 0;
  }

  Future<Set<int>> _remainingIds() async {
    final rows = await database.query(
      AppConstants.ordersTable,
      columns: [AppConstants.colId],
    );
    return rows.map((row) => row[AppConstants.colId] as int).toSet();
  }
}

class _GraphInvoiceRepository extends InvoiceRepository {
  _GraphInvoiceRepository({
    required this.database,
    required this.relationTable,
    required this.invoices,
  });

  final Database database;
  final InvoiceOrderRelationTable relationTable;
  final List<Invoice> invoices;

  @override
  Future<List<Invoice>> getAll({int? limit, int? offset}) async {
    final remainingIds = await _remainingIds();
    return invoices.where((item) => remainingIds.contains(item.id)).toList();
  }

  @override
  Future<List<Invoice>> getByDateRange(DateTime start, DateTime end) async {
    final remaining = await getAll();
    return remaining.where((item) {
      final date = DateTime.parse(item.invoiceDate!);
      return !date.isBefore(start) && !date.isAfter(end);
    }).toList();
  }

  @override
  Future<Invoice?> getById(int id) async {
    if (!(await _remainingIds()).contains(id)) return null;
    for (final invoice in invoices) {
      if (invoice.id == id) return invoice;
    }
    return null;
  }

  @override
  Future<List<int>> getOrderIdsForInvoice(int invoiceId) =>
      relationTable.getOrderIdsForInvoice(invoiceId);

  @override
  Future<int> delete(int id) async {
    final existed = invoices.any((item) => item.id == id);
    await relationTable.deleteByInvoiceId(id);
    await database.delete(
      AppConstants.invoicesTable,
      where: '${AppConstants.colId} = ?',
      whereArgs: [id],
    );
    invoices.removeWhere((item) => item.id == id);
    return existed ? 1 : 0;
  }

  Future<Set<int>> _remainingIds() async {
    final rows = await database.query(
      AppConstants.invoicesTable,
      columns: [AppConstants.colId],
    );
    return rows.map((row) => row[AppConstants.colId] as int).toSet();
  }
}

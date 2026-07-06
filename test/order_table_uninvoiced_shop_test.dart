import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/core/constants/app_constants.dart';
import 'package:receipt_tamer/data/datasources/database/order_table.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late OrderTable table;

  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await _createSchema(db);
    table = OrderTable(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'summarizes uninvoiced orders by shop within an order date range',
    () async {
      await _insertOrder(
        table,
        shopName: '云上小馆',
        amount: 12,
        orderDate: '2026-06-01',
      );
      await _insertOrder(
        table,
        shopName: '云上小馆',
        amount: 8,
        orderDate: '2026-06-12',
      );
      await _insertOrder(
        table,
        shopName: '',
        amount: 6,
        orderDate: '2026-06-02',
      );
      await _insertOrder(
        table,
        shopName: '月初咖啡',
        amount: 5,
        orderDate: '2026-05-31',
      );
      final linkedOrderId = await _insertOrder(
        table,
        shopName: '已开票餐厅',
        amount: 20,
        orderDate: '2026-06-15',
      );
      await _linkInvoice(db, linkedOrderId);

      final summaries = await table.getUninvoicedShopSummaries(
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 30),
      );

      expect(summaries, hasLength(2));
      expect(summaries[0].shopKey, '云上小馆');
      expect(summaries[0].displayName, '云上小馆');
      expect(summaries[0].orderCount, 2);
      expect(summaries[0].totalAmount, 20);
      expect(summaries[1].shopKey, '');
      expect(summaries[1].displayName, '未命名店铺');
      expect(summaries[1].orderCount, 1);
      expect(summaries[1].totalAmount, 6);
    },
  );

  test('loads uninvoiced order details for one shop newest first', () async {
    await _insertOrder(
      table,
      shopName: '云上小馆',
      amount: 12,
      orderDate: '2026-06-01',
    );
    final newerOrderId = await _insertOrder(
      table,
      shopName: '云上小馆',
      amount: 8,
      orderDate: '2026-06-12',
    );
    await _insertOrder(
      table,
      shopName: '其它店铺',
      amount: 6,
      orderDate: '2026-06-02',
    );
    final linkedOrderId = await _insertOrder(
      table,
      shopName: '云上小馆',
      amount: 20,
      orderDate: '2026-06-20',
    );
    await _linkInvoice(db, linkedOrderId);

    final orders = await table.getUninvoicedOrdersForShop(
      '云上小馆',
      startDate: DateTime(2026, 6, 1),
      endDate: DateTime(2026, 6, 30),
    );

    expect(orders.map((order) => order.id), [newerOrderId, 1]);
    expect(orders.map((order) => order.hasInvoice), everyElement(isFalse));
  });

  test(
    'shows an order as uninvoiced when its linked invoice was deleted',
    () async {
      final orderId = await _insertOrder(
        table,
        shopName: '残留关系餐厅',
        amount: 18,
        orderDate: '2026-06-18',
      );
      final invoiceId = await _linkInvoice(db, orderId);
      await db.delete(
        AppConstants.invoicesTable,
        where: '${AppConstants.colId} = ?',
        whereArgs: [invoiceId],
      );

      final orders = await table.getAll();

      expect(orders.single.id, orderId);
      expect(orders.single.hasInvoice, isFalse);
    },
  );

  test(
    'invoice relation filters ignore relations to deleted invoices',
    () async {
      final orderId = await _insertOrder(
        table,
        shopName: '筛选残留关系餐厅',
        amount: 22,
        orderDate: '2026-06-19',
      );
      final invoiceId = await _linkInvoice(db, orderId);
      await db.delete(
        AppConstants.invoicesTable,
        where: '${AppConstants.colId} = ?',
        whereArgs: [invoiceId],
      );

      final withInvoice = await table.searchWithInvoiceRelation(
        hasInvoice: true,
      );
      final withoutInvoice = await table.searchWithInvoiceRelation(
        hasInvoice: false,
      );

      expect(withInvoice, isEmpty);
      expect(withoutInvoice.map((order) => order.id), [orderId]);
    },
  );
}

Future<int> _insertOrder(
  OrderTable table, {
  required String shopName,
  required double amount,
  required String orderDate,
}) {
  return table.insert(
    Order(
      imagePath: 'order.jpg',
      shopName: shopName,
      amount: amount,
      orderDate: orderDate,
      mealTime: 'lunch',
      orderNumber: 'order-$shopName-$orderDate',
      createdAt: '${orderDate}T12:00:00',
      updatedAt: '${orderDate}T12:00:00',
    ),
  );
}

Future<int> _linkInvoice(Database db, int orderId) async {
  final invoiceId = await db.insert(AppConstants.invoicesTable, {
    AppConstants.colImagePath: 'invoice.pdf',
    AppConstants.colInvoiceNumber: 'invoice-$orderId',
    AppConstants.colInvoiceDate: '2026-06-20',
    AppConstants.colTotalAmount: 20.0,
    AppConstants.colSellerName: '已开票餐厅',
    AppConstants.colCreatedAt: '2026-06-20T12:00:00',
    AppConstants.colUpdatedAt: '2026-06-20T12:00:00',
  });
  await db.insert(AppConstants.invoiceOrderRelationsTable, {
    AppConstants.colInvoiceId: invoiceId,
    AppConstants.colOrderId: orderId,
  });
  return invoiceId;
}

Future<void> _createSchema(Database db) async {
  await db.execute('''
    CREATE TABLE ${AppConstants.ordersTable} (
      ${AppConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
      ${AppConstants.colImagePath} TEXT NOT NULL,
      ${AppConstants.colShopName} TEXT,
      ${AppConstants.colAmount} REAL,
      ${AppConstants.colOrderDate} TEXT,
      ${AppConstants.colMealTime} TEXT,
      ${AppConstants.colOrderNumber} TEXT,
      ${AppConstants.colCreatedAt} TEXT NOT NULL,
      ${AppConstants.colUpdatedAt} TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE ${AppConstants.invoicesTable} (
      ${AppConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
      ${AppConstants.colImagePath} TEXT NOT NULL,
      ${AppConstants.colInvoiceNumber} TEXT,
      ${AppConstants.colInvoiceDate} TEXT,
      ${AppConstants.colTotalAmount} REAL,
      ${AppConstants.colSellerName} TEXT DEFAULT '',
      ${AppConstants.colCreatedAt} TEXT NOT NULL,
      ${AppConstants.colUpdatedAt} TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE ${AppConstants.invoiceOrderRelationsTable} (
      ${AppConstants.colInvoiceId} INTEGER NOT NULL,
      ${AppConstants.colOrderId} INTEGER NOT NULL,
      PRIMARY KEY (${AppConstants.colInvoiceId}, ${AppConstants.colOrderId})
    )
  ''');
}

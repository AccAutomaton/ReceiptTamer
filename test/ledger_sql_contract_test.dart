import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/core/constants/app_constants.dart';
import 'package:receipt_tamer/data/datasources/database/invoice_order_relation_table.dart';
import 'package:receipt_tamer/data/datasources/database/invoice_table.dart';
import 'package:receipt_tamer/data/datasources/database/order_table.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late OrderTable orderTable;
  late InvoiceTable invoiceTable;
  late InvoiceOrderRelationTable relationTable;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await _createSchema(db);
    orderTable = OrderTable(database: db);
    invoiceTable = InvoiceTable(database: db);
    relationTable = InvoiceOrderRelationTable(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'month summaries may fall back to createdAt while ce04 searches use business dates only',
    () async {
      final emptyDateOrderId = await _insertOrder(
        db,
        orderDate: '',
        createdAt: '2026-06-04T08:00:00',
        amount: 12,
      );
      await _insertOrder(
        db,
        orderDate: 'not-a-date',
        createdAt: '2026-06-18T09:00:00',
        amount: 18,
      );
      await _insertOrder(
        db,
        orderDate: '2026-07-01',
        createdAt: '2026-05-01T09:00:00',
        amount: 70,
      );

      final emptyDateInvoiceId = await _insertInvoice(
        db,
        invoiceDate: '',
        createdAt: '2026-06-05T08:00:00',
        totalAmount: 15,
      );
      await _insertInvoice(
        db,
        invoiceDate: 'invalid-date',
        createdAt: '2026-06-19T09:00:00',
        totalAmount: 25,
      );
      await _insertInvoice(
        db,
        invoiceDate: '2026-07-02',
        createdAt: '2026-05-02T09:00:00',
        totalAmount: 80,
      );
      await _link(db, invoiceId: emptyDateInvoiceId, orderId: emptyDateOrderId);

      final orderJune = (await orderTable.getMonthSummaries()).singleWhere(
        (summary) => summary.monthKey == '2026-06',
      );
      final invoiceJune = (await invoiceTable.getMonthSummaries()).singleWhere(
        (summary) => summary.monthKey == '2026-06',
      );

      expect(orderJune.itemCount, 2);
      expect(orderJune.totalAmount, 30);
      expect(orderJune.linkedItemCount, 1);
      expect(invoiceJune.itemCount, 2);
      expect(invoiceJune.totalAmount, 40);
      expect(invoiceJune.linkedItemCount, 1);

      final juneOrders = await orderTable.search(
        startDate: DateTime(2026, 6),
        endDate: DateTime(2026, 6, 30),
      );
      final juneInvoices = await invoiceTable.search(
        startDate: DateTime(2026, 6),
        endDate: DateTime(2026, 6, 30),
      );

      expect(juneOrders, isEmpty);
      expect(juneInvoices, isEmpty);
    },
  );

  test(
    'ce04 date ranges use business dates and preserve invoice ascending order',
    () async {
      await _insertOrder(
        db,
        orderDate: 'invalid',
        createdAt: '2026-06-15T12:00:00',
      );
      final validOrderId = await _insertOrder(
        db,
        orderDate: '2026-06-20',
        createdAt: '2026-05-01T12:00:00',
      );
      await _insertInvoice(
        db,
        invoiceDate: '',
        createdAt: '2026-06-15T12:00:00',
      );
      final laterInvoiceId = await _insertInvoice(
        db,
        invoiceDate: '2026-06-20',
        createdAt: '2026-05-01T12:00:00',
      );
      final earlierInvoiceId = await _insertInvoice(
        db,
        invoiceDate: '2026-06-10',
        createdAt: '2026-07-01T12:00:00',
      );

      final orders = await orderTable.search(
        startDate: DateTime(2026, 6),
        endDate: DateTime(2026, 6, 30),
      );
      final invoices = await invoiceTable.getByDateRange(
        DateTime(2026, 6),
        DateTime(2026, 6, 30),
      );

      expect(orders.map((order) => order.id), [validOrderId]);
      expect(invoices.map((invoice) => invoice.id), [
        earlierInvoiceId,
        laterInvoiceId,
      ]);
    },
  );

  test(
    'getAll pagination preserves ce04 ordering and matches the unpaged result',
    () async {
      final breakfastId = await _insertOrder(
        db,
        orderDate: '2026-06-01',
        createdAt: '2026-06-01T00:00:00',
        mealTime: 'breakfast',
      );
      final lunchId = await _insertOrder(
        db,
        orderDate: '2026-06-01',
        createdAt: '2026-06-01T00:00:00',
        mealTime: 'lunch',
      );
      final firstDinnerId = await _insertOrder(
        db,
        orderDate: '2026-06-01',
        createdAt: '2026-06-01T00:00:00',
        mealTime: 'dinner',
      );
      final secondDinnerId = await _insertOrder(
        db,
        orderDate: '',
        createdAt: '2026-06-01T00:00:00',
        mealTime: 'dinner',
      );
      final newestFallbackId = await _insertOrder(
        db,
        orderDate: 'invalid',
        createdAt: '2026-06-02T00:00:00',
        mealTime: 'breakfast',
      );

      final orderPage1 = await orderTable.getAll(limit: 2, offset: 0);
      final orderPage2 = await orderTable.getAll(limit: 2, offset: 2);
      final orderPage3 = await orderTable.getAll(limit: 2, offset: 4);
      final pagedOrderIds = [
        ...orderPage1,
        ...orderPage2,
        ...orderPage3,
      ].map((order) => order.id).toList();

      expect(pagedOrderIds, [
        newestFallbackId,
        firstDinnerId,
        lunchId,
        breakfastId,
        secondDinnerId,
      ]);
      expect(
        (await orderTable.getAll()).map((order) => order.id),
        pagedOrderIds,
      );

      final firstInvoiceId = await _insertInvoice(
        db,
        invoiceDate: '2026-06-01',
        createdAt: '2026-06-01T00:00:00',
      );
      final secondInvoiceId = await _insertInvoice(
        db,
        invoiceDate: '2026-06-01',
        createdAt: '2026-06-01T01:00:00',
      );
      final sameDateFallbackId = await _insertInvoice(
        db,
        invoiceDate: '',
        createdAt: '2026-06-01T02:00:00',
      );
      final newestInvoiceId = await _insertInvoice(
        db,
        invoiceDate: 'invalid',
        createdAt: '2026-06-02T00:00:00',
      );
      final oldestInvoiceId = await _insertInvoice(
        db,
        invoiceDate: '2026-05-31',
        createdAt: '2026-06-03T00:00:00',
      );

      final invoicePage1 = await invoiceTable.getAll(limit: 2, offset: 0);
      final invoicePage2 = await invoiceTable.getAll(limit: 2, offset: 2);
      final invoicePage3 = await invoiceTable.getAll(limit: 2, offset: 4);
      final pagedInvoiceIds = [
        ...invoicePage1,
        ...invoicePage2,
        ...invoicePage3,
      ].map((invoice) => invoice.id).toList();

      expect(pagedInvoiceIds, [
        oldestInvoiceId,
        newestInvoiceId,
        sameDateFallbackId,
        secondInvoiceId,
        firstInvoiceId,
      ]);
      expect(
        (await invoiceTable.getAll()).map((invoice) => invoice.id),
        pagedInvoiceIds,
      );
    },
  );

  test(
    'home recent queries use collection time, limit results, and retain relations',
    () async {
      await _insertOrder(
        db,
        orderDate: '2026-12-31',
        createdAt: '2026-06-01T08:00:00',
        orderNumber: 'OLD-COLLECTION',
      );
      final secondNewestOrderId = await _insertOrder(
        db,
        orderDate: '2026-01-01',
        createdAt: '2026-07-02T08:00:00',
        orderNumber: 'SECOND-COLLECTION',
      );
      final newestOrderId = await _insertOrder(
        db,
        orderDate: '2025-01-01',
        createdAt: '2026-07-03T08:00:00',
        orderNumber: 'NEWEST-COLLECTION',
      );

      await _insertInvoice(
        db,
        invoiceDate: '2026-12-31',
        createdAt: '2026-06-01T08:00:00',
        invoiceNumber: 'OLD-INVOICE-COLLECTION',
      );
      final secondNewestInvoiceId = await _insertInvoice(
        db,
        invoiceDate: '2026-01-01',
        createdAt: '2026-07-02T08:00:00',
        invoiceNumber: 'SECOND-INVOICE-COLLECTION',
      );
      final newestInvoiceId = await _insertInvoice(
        db,
        invoiceDate: '2025-01-01',
        createdAt: '2026-07-03T08:00:00',
        invoiceNumber: 'NEWEST-INVOICE-COLLECTION',
      );
      await _link(db, invoiceId: newestInvoiceId, orderId: newestOrderId);

      final recentOrders = await orderTable.getRecentlyCreated(limit: 2);
      final recentInvoices = await invoiceTable.getRecentlyCreated(limit: 2);

      expect(recentOrders.map((order) => order.id), [
        newestOrderId,
        secondNewestOrderId,
      ]);
      expect(recentOrders.first.hasInvoice, isTrue);
      expect(recentInvoices.map((invoice) => invoice.id), [
        newestInvoiceId,
        secondNewestInvoiceId,
      ]);
    },
  );

  test('raw SQL pagination supports offset without a limit', () async {
    final newestOrderId = await _insertOrder(
      db,
      orderDate: '2026-06-03',
      orderNumber: 'ORDER-NEWEST',
    );
    final middleOrderId = await _insertOrder(
      db,
      orderDate: '2026-06-02',
      orderNumber: 'ORDER-MIDDLE',
    );
    final oldestOrderId = await _insertOrder(
      db,
      orderDate: '2026-06-01',
      orderNumber: 'ORDER-OLDEST',
    );

    expect((await orderTable.getAll(offset: 1)).map((order) => order.id), [
      middleOrderId,
      oldestOrderId,
    ]);
    expect((await orderTable.search(offset: 1)).map((order) => order.id), [
      middleOrderId,
      oldestOrderId,
    ]);
    expect((await orderTable.getAll()).map((order) => order.id), [
      newestOrderId,
      middleOrderId,
      oldestOrderId,
    ]);

    final oldestInvoiceId = await _insertInvoice(
      db,
      invoiceNumber: 'INVOICE-OLDEST',
      createdAt: '2026-06-01T00:00:00',
    );
    final middleInvoiceId = await _insertInvoice(
      db,
      invoiceNumber: 'INVOICE-MIDDLE',
      createdAt: '2026-06-02T00:00:00',
    );
    final newestInvoiceId = await _insertInvoice(
      db,
      invoiceNumber: 'INVOICE-NEWEST',
      createdAt: '2026-06-03T00:00:00',
    );
    await _link(db, invoiceId: newestInvoiceId, orderId: oldestOrderId);

    expect(
      (await invoiceTable.getByOrderId(
        oldestOrderId,
        offset: 1,
      )).map((invoice) => invoice.id),
      isEmpty,
    );
    expect(
      (await invoiceTable.search(offset: 1)).map((invoice) => invoice.id),
      [middleInvoiceId, oldestInvoiceId],
    );
  });

  test(
    'invoice search keeps ce04 AND matching and does not trim keywords',
    () async {
      await _insertInvoice(
        db,
        invoiceNumber: 'NO-001',
        sellerName: '青禾记账服务',
        createdAt: '2026-06-01T00:00:00',
      );
      await _insertInvoice(
        db,
        invoiceNumber: 'FP-青禾-002',
        sellerName: '其它销售方',
        createdAt: '2026-06-02T00:00:00',
      );
      final bothMatchId = await _insertInvoice(
        db,
        invoiceNumber: 'FP-青禾-003',
        sellerName: '青禾销售方',
        createdAt: '2026-06-03T00:00:00',
      );
      await _insertInvoice(
        db,
        invoiceNumber: 'NO-004',
        sellerName: '无关销售方',
        createdAt: '2026-06-04T00:00:00',
      );

      final exactMatches = await invoiceTable.search(
        invoiceNumber: '青禾',
        sellerName: '青禾',
      );
      final spacedMatches = await invoiceTable.search(
        invoiceNumber: ' 青禾 ',
        sellerName: ' 青禾 ',
      );

      expect(exactMatches.map((invoice) => invoice.id), [bothMatchId]);
      expect(spacedMatches, isEmpty);
    },
  );

  test('invoice search composes orderId and relation filters', () async {
    final targetOrderId = await _insertOrder(db);
    final otherOrderId = await _insertOrder(db);
    final targetInvoiceId = await _insertInvoice(db, invoiceNumber: 'TARGET');
    final otherInvoiceId = await _insertInvoice(db, invoiceNumber: 'OTHER');
    await _insertInvoice(db, invoiceNumber: 'UNLINKED');
    await _link(db, invoiceId: targetInvoiceId, orderId: targetOrderId);
    await _link(db, invoiceId: otherInvoiceId, orderId: otherOrderId);

    final orderMatches = await invoiceTable.search(orderId: targetOrderId);
    final linkedMatches = await invoiceTable.search(hasLinkedOrder: true);
    final combinedLinkedMatches = await invoiceTable.search(
      orderId: targetOrderId,
      hasLinkedOrder: true,
    );
    final combinedUnlinkedMatches = await invoiceTable.search(
      orderId: targetOrderId,
      hasLinkedOrder: false,
    );

    expect(orderMatches.map((invoice) => invoice.id), [targetInvoiceId]);
    expect(
      linkedMatches.map((invoice) => invoice.id),
      unorderedEquals([targetInvoiceId, otherInvoiceId]),
    );
    expect(combinedLinkedMatches.map((invoice) => invoice.id), [
      targetInvoiceId,
    ]);
    expect(combinedUnlinkedMatches, isEmpty);
  });

  test(
    'relation batch APIs split 1000 order ids and return correct maps',
    () async {
      final orderBatch = db.batch();
      for (var index = 1; index <= 1000; index++) {
        orderBatch.insert(
          AppConstants.ordersTable,
          _orderRow(orderNumber: 'ORDER-$index'),
        );
      }
      await orderBatch.commit(noResult: true);

      final firstInvoiceId = await _insertInvoice(db, invoiceNumber: 'BATCH-1');
      final secondInvoiceId = await _insertInvoice(
        db,
        invoiceNumber: 'BATCH-2',
      );
      final thirdInvoiceId = await _insertInvoice(db, invoiceNumber: 'BATCH-3');
      await relationTable.insertRelationsForInvoice(firstInvoiceId, [
        1,
        500,
        501,
      ]);
      await relationTable.insertRelationsForInvoice(secondInvoiceId, [1, 501]);
      await relationTable.insertRelationsForInvoice(thirdInvoiceId, [
        501,
        1000,
      ]);

      final orderIds = List<int>.generate(1000, (index) => 1000 - index);
      final counts = await relationTable.getInvoiceCountsForOrders(orderIds);
      final invoiceIds = await relationTable.getInvoiceIdsForOrders(orderIds);

      expect(counts, {1: 1, 500: 1, 501: 1, 1000: 1});
      expect(invoiceIds, hasLength(1000));
      expect(invoiceIds[1], {secondInvoiceId});
      expect(invoiceIds[2], isEmpty);
      expect(invoiceIds[500], {firstInvoiceId});
      expect(invoiceIds[501], {thirdInvoiceId});
      expect(invoiceIds[1000], {thirdInvoiceId});
    },
  );

  test(
    'legacy duplicate order relations keep the newest invoice and become unique',
    () async {
      final orderId = await _insertOrder(db);
      final olderInvoiceId = await _insertInvoice(
        db,
        invoiceNumber: 'OLDER',
        createdAt: '2026-06-01T00:00:00',
      );
      final newerInvoiceId = await _insertInvoice(
        db,
        invoiceNumber: 'NEWER',
        createdAt: '2026-06-02T00:00:00',
      );

      await db.execute(
        'DROP INDEX ${InvoiceOrderRelationTable.orderIdUniqueIndexName}',
      );
      await _link(db, invoiceId: olderInvoiceId, orderId: orderId);
      await _link(db, invoiceId: newerInvoiceId, orderId: orderId);

      final removedCount = await relationTable.enforceSingleInvoicePerOrder();

      expect(removedCount, 1);
      expect(await relationTable.getInvoiceIdsForOrder(orderId), [
        newerInvoiceId,
      ]);

      final indexes = await db.rawQuery(
        "PRAGMA index_list('${AppConstants.invoiceOrderRelationsTable}')",
      );
      final orderIndex = indexes.singleWhere(
        (index) =>
            index['name'] == InvoiceOrderRelationTable.orderIdUniqueIndexName,
      );
      expect((orderIndex['unique'] as num).toInt(), 1);
      expect(
        _link(db, invoiceId: olderInvoiceId, orderId: orderId),
        throwsA(isA<DatabaseException>()),
      );
    },
  );
}

Future<int> _insertOrder(
  Database db, {
  String? orderDate = '2026-06-01',
  String mealTime = 'lunch',
  String orderNumber = 'ORDER',
  String createdAt = '2026-06-01T00:00:00',
  double amount = 10,
}) {
  return db.insert(
    AppConstants.ordersTable,
    _orderRow(
      orderDate: orderDate,
      mealTime: mealTime,
      orderNumber: orderNumber,
      createdAt: createdAt,
      amount: amount,
    ),
  );
}

Map<String, Object?> _orderRow({
  String? orderDate = '2026-06-01',
  String mealTime = 'lunch',
  String orderNumber = 'ORDER',
  String createdAt = '2026-06-01T00:00:00',
  double amount = 10,
}) {
  return {
    AppConstants.colImagePath: 'order.jpg',
    AppConstants.colShopName: '测试店铺',
    AppConstants.colAmount: amount,
    AppConstants.colOrderDate: orderDate,
    AppConstants.colMealTime: mealTime,
    AppConstants.colOrderNumber: orderNumber,
    AppConstants.colCreatedAt: createdAt,
    AppConstants.colUpdatedAt: createdAt,
  };
}

Future<int> _insertInvoice(
  Database db, {
  String? invoiceDate = '2026-06-01',
  String invoiceNumber = 'INVOICE',
  String sellerName = '测试销售方',
  String createdAt = '2026-06-01T00:00:00',
  double totalAmount = 10,
}) {
  return db.insert(AppConstants.invoicesTable, {
    AppConstants.colImagePath: 'invoice.pdf',
    AppConstants.colInvoiceNumber: invoiceNumber,
    AppConstants.colInvoiceDate: invoiceDate,
    AppConstants.colTotalAmount: totalAmount,
    AppConstants.colSellerName: sellerName,
    AppConstants.colCreatedAt: createdAt,
    AppConstants.colUpdatedAt: createdAt,
  });
}

Future<void> _link(
  Database db, {
  required int invoiceId,
  required int orderId,
}) async {
  await db.insert(AppConstants.invoiceOrderRelationsTable, {
    AppConstants.colInvoiceId: invoiceId,
    AppConstants.colOrderId: orderId,
  });
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
  await db.execute('''
    CREATE UNIQUE INDEX ${InvoiceOrderRelationTable.orderIdUniqueIndexName}
    ON ${AppConstants.invoiceOrderRelationsTable}(${AppConstants.colOrderId})
  ''');
}

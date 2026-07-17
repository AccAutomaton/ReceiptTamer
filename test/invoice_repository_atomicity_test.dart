import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:receipt_tamer/core/constants/app_constants.dart';
import 'package:receipt_tamer/data/datasources/database/invoice_order_relation_table.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/repositories/invoice_repository.dart';

void main() {
  late Database database;
  late InvoiceRepository repository;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        singleInstance: false,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
        },
      ),
    );
    await _createSchema(database);
    repository = InvoiceRepository(database: database);
    await _insertOrder(database, 1);
    await _insertOrder(database, 2);
    await _insertOrder(database, 3);
  });

  tearDown(() => database.close());

  test('create rolls back the invoice when relation insertion fails', () async {
    await _failRelationInserts(database);

    await expectLater(
      repository.create(_invoice(), orderIds: const [1]),
      throwsA(isA<DatabaseException>()),
    );

    expect(await _rows(database, AppConstants.invoicesTable), isEmpty);
    expect(
      await _rows(database, AppConstants.invoiceOrderRelationsTable),
      isEmpty,
    );
  });

  test(
    'update rolls back the invoice when relation replacement fails',
    () async {
      final invoiceId = await repository.create(
        _invoice(invoiceNumber: 'before', sellerName: 'before seller'),
        orderIds: const [1],
      );
      final beforeInvoice = await _invoiceRow(database, invoiceId);
      final beforeRelations = await _relations(database);
      await _failRelationInserts(database);

      await expectLater(
        repository.update(
          Invoice.fromJson(
            beforeInvoice,
          ).copyWith(invoiceNumber: 'after', sellerName: 'after seller'),
          orderIds: const [2],
        ),
        throwsA(isA<DatabaseException>()),
      );

      expect(await _invoiceRow(database, invoiceId), beforeInvoice);
      expect(await _relations(database), beforeRelations);
    },
  );

  test(
    'update leaves relations unchanged when the invoice update fails',
    () async {
      final invoiceId = await repository.create(
        _invoice(invoiceNumber: 'before'),
        orderIds: const [1],
      );
      final beforeInvoice = await _invoiceRow(database, invoiceId);
      final beforeRelations = await _relations(database);
      await database.execute('''
      CREATE TRIGGER fail_invoice_update
      BEFORE UPDATE ON ${AppConstants.invoicesTable}
      BEGIN
        SELECT RAISE(ABORT, 'injected invoice update failure');
      END
    ''');

      await expectLater(
        repository.update(
          Invoice.fromJson(beforeInvoice).copyWith(invoiceNumber: 'after'),
          orderIds: const [2],
        ),
        throwsA(isA<DatabaseException>()),
      );

      expect(await _invoiceRow(database, invoiceId), beforeInvoice);
      expect(await _relations(database), beforeRelations);
    },
  );

  test(
    'delete rolls back the invoice when explicit relation cleanup fails',
    () async {
      final invoiceId = await repository.create(
        _invoice(invoiceNumber: 'retained'),
        orderIds: const [1],
      );
      final beforeInvoice = await _invoiceRow(database, invoiceId);
      final beforeRelations = await _relations(database);

      // Exercise the repository's explicit cleanup rather than FK CASCADE, as
      // can occur while handling a legacy or externally opened database.
      await database.execute('PRAGMA foreign_keys = OFF');
      await database.execute('''
      CREATE TRIGGER fail_relation_delete
      BEFORE DELETE ON ${AppConstants.invoiceOrderRelationsTable}
      BEGIN
        SELECT RAISE(ABORT, 'injected relation delete failure');
      END
    ''');

      await expectLater(
        repository.delete(invoiceId),
        throwsA(isA<DatabaseException>()),
      );

      expect(await _invoiceRow(database, invoiceId), beforeInvoice);
      expect(await _relations(database), beforeRelations);
    },
  );

  test(
    'create, update, and delete commit invoice and relation changes together',
    () async {
      final invoiceId = await repository.create(
        _invoice(invoiceNumber: 'created'),
        orderIds: const [1, 1, 2],
      );

      expect(
        (await _invoiceRow(database, invoiceId))['invoice_number'],
        'created',
      );
      expect(await _orderIdsForInvoice(database, invoiceId), [1, 2]);

      final current = Invoice.fromJson(await _invoiceRow(database, invoiceId));
      expect(
        await repository.update(
          current.copyWith(invoiceNumber: 'updated'),
          orderIds: const [3],
        ),
        1,
      );
      expect(
        (await _invoiceRow(database, invoiceId))['invoice_number'],
        'updated',
      );
      expect(await _orderIdsForInvoice(database, invoiceId), [3]);

      await repository.update(
        Invoice.fromJson(
          await _invoiceRow(database, invoiceId),
        ).copyWith(sellerName: 'metadata only'),
      );
      expect(await _orderIdsForInvoice(database, invoiceId), [3]);

      expect(await repository.delete(invoiceId), 1);
      expect(await _rows(database, AppConstants.invoicesTable), isEmpty);
      expect(await _relations(database), isEmpty);
      expect(await _rows(database, AppConstants.ordersTable), hasLength(3));
    },
  );
}

Invoice _invoice({
  String invoiceNumber = 'invoice',
  String sellerName = 'seller',
}) {
  return Invoice(
    imagePath: '/tmp/invoice.png',
    invoiceNumber: invoiceNumber,
    invoiceDate: '2026-07-17',
    totalAmount: 42,
    sellerName: sellerName,
    createdAt: '2026-07-17T10:00:00.000',
    updatedAt: '2026-07-17T10:00:00.000',
  );
}

Future<void> _failRelationInserts(Database database) {
  return database.execute('''
    CREATE TRIGGER fail_relation_insert
    BEFORE INSERT ON ${AppConstants.invoiceOrderRelationsTable}
    BEGIN
      SELECT RAISE(ABORT, 'injected relation insert failure');
    END
  ''');
}

Future<Map<String, Object?>> _invoiceRow(
  Database database,
  int invoiceId,
) async {
  final rows = await database.query(
    AppConstants.invoicesTable,
    where: '${AppConstants.colId} = ?',
    whereArgs: [invoiceId],
  );
  return Map<String, Object?>.of(rows.single);
}

Future<List<Map<String, Object?>>> _relations(Database database) async {
  return _rows(
    database,
    AppConstants.invoiceOrderRelationsTable,
    orderBy: '${AppConstants.colInvoiceId}, ${AppConstants.colOrderId}',
  );
}

Future<List<int>> _orderIdsForInvoice(Database database, int invoiceId) async {
  final rows = await database.query(
    AppConstants.invoiceOrderRelationsTable,
    columns: const [AppConstants.colOrderId],
    where: '${AppConstants.colInvoiceId} = ?',
    whereArgs: [invoiceId],
    orderBy: AppConstants.colOrderId,
  );
  return rows
      .map((row) => row[AppConstants.colOrderId] as int)
      .toList(growable: false);
}

Future<List<Map<String, Object?>>> _rows(
  Database database,
  String table, {
  String? orderBy,
}) async {
  final rows = await database.query(table, orderBy: orderBy);
  return rows.map(Map<String, Object?>.of).toList(growable: false);
}

Future<void> _insertOrder(Database database, int id) {
  return database.insert(AppConstants.ordersTable, {
    AppConstants.colId: id,
    AppConstants.colImagePath: '/tmp/order-$id.png',
    AppConstants.colShopName: 'shop $id',
    AppConstants.colAmount: 21.0,
    AppConstants.colOrderDate: '2026-07-17',
    AppConstants.colMealTime: 'lunch',
    AppConstants.colOrderNumber: 'order-$id',
    AppConstants.colCreatedAt: '2026-07-17T09:00:00.000',
    AppConstants.colUpdatedAt: '2026-07-17T09:00:00.000',
  });
}

Future<void> _createSchema(Database database) async {
  await database.execute('''
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
  await database.execute('''
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
  await database.execute('''
    CREATE TABLE ${AppConstants.invoiceOrderRelationsTable} (
      ${AppConstants.colInvoiceId} INTEGER NOT NULL,
      ${AppConstants.colOrderId} INTEGER NOT NULL,
      PRIMARY KEY (${AppConstants.colInvoiceId}, ${AppConstants.colOrderId}),
      FOREIGN KEY (${AppConstants.colInvoiceId})
        REFERENCES ${AppConstants.invoicesTable}(${AppConstants.colId})
        ON DELETE CASCADE,
      FOREIGN KEY (${AppConstants.colOrderId})
        REFERENCES ${AppConstants.ordersTable}(${AppConstants.colId})
        ON DELETE CASCADE
    )
  ''');
  await database.execute('''
    CREATE UNIQUE INDEX ${InvoiceOrderRelationTable.orderIdUniqueIndexName}
    ON ${AppConstants.invoiceOrderRelationsTable}(${AppConstants.colOrderId})
  ''');
}

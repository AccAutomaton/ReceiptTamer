import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:receipt_tamer/core/constants/app_constants.dart';
import 'package:receipt_tamer/data/datasources/database/invoice_order_relation_table.dart';
import 'package:receipt_tamer/data/datasources/database/invoice_table.dart';
import 'package:receipt_tamer/data/datasources/database/order_table.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Deterministic high-volume data used by the ledger performance gates.
///
/// This fixture deliberately mirrors the production version-1 schema instead
/// of going through [DatabaseHelper], whose singleton owns the user's normal
/// database path. No generated record is persisted outside the temporary test
/// database.
class LedgerPerformanceFixture {
  LedgerPerformanceFixture._({
    required this.database,
    required this.databasePath,
    required this.deleteDatabaseOnClose,
    required this.seedDuration,
    required this.orderMonthCounts,
    required this.invoiceMonthCounts,
    required this.linkedOrderIds,
  }) : orders = OrderTable(database: database),
       invoices = InvoiceTable(database: database),
       relations = InvoiceOrderRelationTable(database: database);

  static const orderCount = 1000;
  static const invoiceCount = 500;
  static const monthCount = 36;
  static const linkedOrderCount = 750;
  static const relationCount = 750;

  /// A fixed clock prevents the fixture from changing when a test crosses a
  /// calendar boundary.
  static final DateTime anchorMonth = DateTime.utc(2026, 6);

  final Database database;
  final String databasePath;
  final bool deleteDatabaseOnClose;
  final Duration seedDuration;
  final Map<String, int> orderMonthCounts;
  final Map<String, int> invoiceMonthCounts;
  final Set<int> linkedOrderIds;
  final OrderTable orders;
  final InvoiceTable invoices;
  final InvoiceOrderRelationTable relations;

  /// Opens an in-memory SQLite fixture by default. Set [inMemory] to false to
  /// exercise the same workload against a temporary file-backed SQLite DB.
  static Future<LedgerPerformanceFixture> open({bool inMemory = true}) async {
    sqfliteFfiInit();
    final path = inMemory
        ? inMemoryDatabasePath
        : p.join(
            Directory.systemTemp.path,
            'receipt_tamer_ledger_perf_${DateTime.now().microsecondsSinceEpoch}.db',
          );
    final database = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        singleInstance: false,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      ),
    );

    await _createProductionSchema(database);
    final stopwatch = Stopwatch()..start();
    final expectations = await _seed(database);
    stopwatch.stop();

    return LedgerPerformanceFixture._(
      database: database,
      databasePath: path,
      deleteDatabaseOnClose: !inMemory,
      seedDuration: stopwatch.elapsed,
      orderMonthCounts: expectations.orderMonthCounts,
      invoiceMonthCounts: expectations.invoiceMonthCounts,
      linkedOrderIds: expectations.linkedOrderIds,
    );
  }

  Future<void> close() async {
    await database.close();
    if (deleteDatabaseOnClose) {
      await databaseFactoryFfi.deleteDatabase(databasePath);
    }
  }

  static Future<_FixtureExpectations> _seed(Database database) async {
    final orderMonthCounts = <String, int>{};
    final invoiceMonthCounts = <String, int>{};
    final linkedOrderIds = <int>{};

    await database.transaction((transaction) async {
      final batch = transaction.batch();

      for (var index = 0; index < orderCount; index++) {
        final id = index + 1;
        final month = _monthAt(index % monthCount);
        final monthKey = _monthKey(month);
        final day = (index % 28) + 1;
        final date = '$monthKey-${day.toString().padLeft(2, '0')}';
        orderMonthCounts.update(
          monthKey,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
        batch.insert(AppConstants.ordersTable, {
          AppConstants.colId: id,
          AppConstants.colImagePath: '/fixture/orders/$id.webp',
          AppConstants.colShopName: '性能店铺 ${(index % 64) + 1}',
          AppConstants.colAmount: (index % 73) + 1 + (index % 4) * 0.25,
          AppConstants.colOrderDate: date,
          AppConstants.colMealTime: switch (index % 3) {
            0 => 'breakfast',
            1 => 'lunch',
            _ => 'dinner',
          },
          AppConstants.colOrderNumber:
              'PERF-O-${id.toString().padLeft(5, '0')}',
          AppConstants.colCreatedAt: '${date}T12:00:00.000Z',
          AppConstants.colUpdatedAt: '${date}T12:00:00.000Z',
        });
      }

      for (var index = 0; index < invoiceCount; index++) {
        final id = index + 1;
        final month = _monthAt(index % monthCount);
        final monthKey = _monthKey(month);
        final day = (index % 28) + 1;
        final date = '$monthKey-${day.toString().padLeft(2, '0')}';
        invoiceMonthCounts.update(
          monthKey,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
        batch.insert(AppConstants.invoicesTable, {
          AppConstants.colId: id,
          AppConstants.colImagePath: index.isEven
              ? '/fixture/invoices/$id.pdf'
              : '/fixture/invoices/$id.webp',
          AppConstants.colInvoiceNumber:
              'PERF-I-${id.toString().padLeft(5, '0')}',
          AppConstants.colInvoiceDate: date,
          AppConstants.colTotalAmount: (index % 137) + 30 + (index % 2) * 0.5,
          AppConstants.colSellerName: '性能销售方 ${(index % 48) + 1}',
          AppConstants.colCreatedAt: '${date}T13:00:00.000Z',
          AppConstants.colUpdatedAt: '${date}T13:00:00.000Z',
        });
      }

      // Every invoice owns one order. The first 250 invoices own a second
      // order, yielding 750 valid relations and 250 deliberately unlinked
      // orders for relation filters and monthly pending counts.
      for (var invoiceId = 1; invoiceId <= invoiceCount; invoiceId++) {
        batch.insert(AppConstants.invoiceOrderRelationsTable, {
          AppConstants.colInvoiceId: invoiceId,
          AppConstants.colOrderId: invoiceId,
        });
        linkedOrderIds.add(invoiceId);
        if (invoiceId <= 250) {
          final secondOrderId = invoiceId + invoiceCount;
          batch.insert(AppConstants.invoiceOrderRelationsTable, {
            AppConstants.colInvoiceId: invoiceId,
            AppConstants.colOrderId: secondOrderId,
          });
          linkedOrderIds.add(secondOrderId);
        }
      }

      await batch.commit(noResult: true);
    });

    return _FixtureExpectations(
      orderMonthCounts: Map.unmodifiable(orderMonthCounts),
      invoiceMonthCounts: Map.unmodifiable(invoiceMonthCounts),
      linkedOrderIds: Set.unmodifiable(linkedOrderIds),
    );
  }

  static DateTime _monthAt(int offset) =>
      DateTime.utc(anchorMonth.year, anchorMonth.month - offset);

  static String _monthKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

  static Future<void> _createProductionSchema(Database database) async {
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
    await database.execute(
      'CREATE INDEX idx_orders_created_at '
      'ON ${AppConstants.ordersTable}(${AppConstants.colCreatedAt} DESC)',
    );
    await database.execute(
      'CREATE INDEX idx_invoices_created_at '
      'ON ${AppConstants.invoicesTable}(${AppConstants.colCreatedAt} DESC)',
    );
    await database.execute(
      'CREATE INDEX idx_invoice_order_relations_invoice_id '
      'ON ${AppConstants.invoiceOrderRelationsTable}'
      '(${AppConstants.colInvoiceId})',
    );
    await database.execute(
      'CREATE INDEX idx_invoice_order_relations_order_id '
      'ON ${AppConstants.invoiceOrderRelationsTable}'
      '(${AppConstants.colOrderId})',
    );
  }
}

class _FixtureExpectations {
  const _FixtureExpectations({
    required this.orderMonthCounts,
    required this.invoiceMonthCounts,
    required this.linkedOrderIds,
  });

  final Map<String, int> orderMonthCounts;
  final Map<String, int> invoiceMonthCounts;
  final Set<int> linkedOrderIds;
}

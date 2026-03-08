import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../core/constants/app_constants.dart';

/// Database helper class for managing SQLite database
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  /// Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize database
  Future<Database> _initDatabase() async {
    // Use FFI for Windows/Mac, regular sqflite for mobile
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.databaseName);

    return await openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create tables when database is first created
  Future<void> _onCreate(Database db, int version) async {
    // Create orders table
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

    // Create invoices table
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

    // Create invoice_order_relations table
    await db.execute('''
      CREATE TABLE ${AppConstants.invoiceOrderRelationsTable} (
        ${AppConstants.colInvoiceId} INTEGER NOT NULL,
        ${AppConstants.colOrderId} INTEGER NOT NULL,
        PRIMARY KEY (${AppConstants.colInvoiceId}, ${AppConstants.colOrderId}),
        FOREIGN KEY (${AppConstants.colInvoiceId}) REFERENCES ${AppConstants.invoicesTable}(${AppConstants.colId}) ON DELETE CASCADE,
        FOREIGN KEY (${AppConstants.colOrderId}) REFERENCES ${AppConstants.ordersTable}(${AppConstants.colId}) ON DELETE CASCADE
      )
    ''');

    // Create indexes for better query performance
    await db.execute('''
      CREATE INDEX idx_orders_created_at ON ${AppConstants.ordersTable}(${AppConstants.colCreatedAt} DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_invoices_created_at ON ${AppConstants.invoicesTable}(${AppConstants.colCreatedAt} DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_invoice_order_relations_invoice_id
      ON ${AppConstants.invoiceOrderRelationsTable}(${AppConstants.colInvoiceId})
    ''');

    await db.execute('''
      CREATE INDEX idx_invoice_order_relations_order_id
      ON ${AppConstants.invoiceOrderRelationsTable}(${AppConstants.colOrderId})
    ''');
  }

  /// Upgrade database when version changes
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Version 1 to 2: Add seller_name column, create invoice_order_relations table,
      // migrate existing order_id data to relations table

      // Step 1: Create invoice_order_relations table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${AppConstants.invoiceOrderRelationsTable} (
          ${AppConstants.colInvoiceId} INTEGER NOT NULL,
          ${AppConstants.colOrderId} INTEGER NOT NULL,
          PRIMARY KEY (${AppConstants.colInvoiceId}, ${AppConstants.colOrderId}),
          FOREIGN KEY (${AppConstants.colInvoiceId}) REFERENCES ${AppConstants.invoicesTable}(${AppConstants.colId}) ON DELETE CASCADE,
          FOREIGN KEY (${AppConstants.colOrderId}) REFERENCES ${AppConstants.ordersTable}(${AppConstants.colId}) ON DELETE CASCADE
        )
      ''');

      // Step 2: Add seller_name column to invoices table
      await db.execute('''
        ALTER TABLE ${AppConstants.invoicesTable} ADD COLUMN ${AppConstants.colSellerName} TEXT DEFAULT ''
      ''');

      // Step 3: Migrate existing order_id data to invoice_order_relations table
      await db.execute('''
        INSERT INTO ${AppConstants.invoiceOrderRelationsTable} (${AppConstants.colInvoiceId}, ${AppConstants.colOrderId})
        SELECT ${AppConstants.colId}, ${AppConstants.colOrderId}
        FROM ${AppConstants.invoicesTable}
        WHERE ${AppConstants.colOrderId} IS NOT NULL AND ${AppConstants.colOrderId} > 0
      ''');

      // Step 4: Create index for relations table
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_invoice_order_relations_invoice_id
        ON ${AppConstants.invoiceOrderRelationsTable}(${AppConstants.colInvoiceId})
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_invoice_order_relations_order_id
        ON ${AppConstants.invoiceOrderRelationsTable}(${AppConstants.colOrderId})
      ''');

      // Note: We keep the order_id column in invoices table for backward compatibility
      // but it will no longer be used for new data
    }
  }

  /// Close database connection
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// Clear all data (for testing purposes)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete(AppConstants.invoicesTable);
    await db.delete(AppConstants.ordersTable);
  }

  /// Get database file size
  Future<int> getDatabaseSize() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.databaseName);
    final file = File(path);
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }
}

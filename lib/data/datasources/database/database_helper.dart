import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

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
        ${AppConstants.colOrderId} INTEGER,
        ${AppConstants.colInvoiceNumber} TEXT,
        ${AppConstants.colInvoiceDate} TEXT,
        ${AppConstants.colTotalAmount} REAL,
        ${AppConstants.colCreatedAt} TEXT NOT NULL,
        ${AppConstants.colUpdatedAt} TEXT NOT NULL,
        FOREIGN KEY (${AppConstants.colOrderId}) REFERENCES ${AppConstants.ordersTable}(${AppConstants.colId}) ON DELETE CASCADE
      )
    ''');

    // Create indexes for better query performance
    await db.execute('''
      CREATE INDEX idx_orders_created_at ON ${AppConstants.ordersTable}(${AppConstants.colCreatedAt} DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_invoices_order_id ON ${AppConstants.invoicesTable}(${AppConstants.colOrderId})
    ''');

    await db.execute('''
      CREATE INDEX idx_invoices_created_at ON ${AppConstants.invoicesTable}(${AppConstants.colCreatedAt} DESC)
    ''');
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Version 1 to 2: Split order_time into order_date and meal_time
    if (oldVersion < 2) {
      // Add new columns
      await db.execute('ALTER TABLE ${AppConstants.ordersTable} ADD COLUMN ${AppConstants.colOrderDate} TEXT');
      await db.execute('ALTER TABLE ${AppConstants.ordersTable} ADD COLUMN ${AppConstants.colMealTime} TEXT');

      // Migrate existing data: copy order_time to order_date (date part only)
      // Note: Using hardcoded column name 'order_time' since it's the old column name
      await db.execute('''
        UPDATE ${AppConstants.ordersTable}
        SET ${AppConstants.colOrderDate} = date(order_time)
        WHERE order_time IS NOT NULL
      ''');

      // Note: meal_time cannot be automatically derived from order_time since
      // we only stored the date part, not the time part.
      // Users can manually set meal_time later.
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

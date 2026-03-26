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
    // No migrations for initial release
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

  /// Get database file path
  Future<String> getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, AppConstants.databaseName);
  }

  /// Export database to a file
  /// Returns the exported file path, or null if export failed
  Future<String?> exportDatabase(String outputPath) async {
    try {
      final dbPath = await getDatabasePath();
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        return null;
      }

      // Close database before copying
      await close();

      // Copy database file
      await dbFile.copy(outputPath);

      return outputPath;
    } catch (e) {
      return null;
    }
  }

  /// Replace database with a new database file
  /// This will close the current database, replace the file, and reopen
  Future<bool> replaceDatabase(File newDbFile) async {
    try {
      if (!await newDbFile.exists()) {
        return false;
      }

      final dbPath = await getDatabasePath();

      // Close current database
      await close();

      // Delete old database file if exists
      final oldDbFile = File(dbPath);
      if (await oldDbFile.exists()) {
        await oldDbFile.delete();
      }

      // Copy new database to the database path
      await newDbFile.copy(dbPath);

      // Reopen database (this will trigger onUpgrade if needed)
      await database;

      return true;
    } catch (e) {
      return false;
    }
  }
}

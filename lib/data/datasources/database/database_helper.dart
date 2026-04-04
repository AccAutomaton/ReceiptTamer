import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/log_service.dart';
import '../../../core/services/log_config.dart';

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
    logService.i(LogConfig.moduleDb, '初始化数据库...');

    // Use FFI for Windows/Mac, regular sqflite for mobile
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      logService.i(LogConfig.moduleDb, '桌面平台使用 sqflite_ffi');
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.databaseName);
    logService.i(LogConfig.moduleDb, '数据库路径: $path');

    return await openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create tables when database is first created
  Future<void> _onCreate(Database db, int version) async {
    logService.i(LogConfig.moduleDb, '创建数据库表，版本: $version');
    final stopwatch = Stopwatch()..start();

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
    logService.i(LogConfig.moduleDb, '已创建 ${AppConstants.ordersTable} 表');

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
    logService.i(LogConfig.moduleDb, '已创建 ${AppConstants.invoicesTable} 表');

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
    logService.i(LogConfig.moduleDb, '已创建 ${AppConstants.invoiceOrderRelationsTable} 表');

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

    stopwatch.stop();
    logService.i(LogConfig.moduleDb, '数据库表创建成功，耗时: ${stopwatch.elapsedMilliseconds}ms');
  }

  /// Upgrade database when version changes
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    logService.i(LogConfig.moduleDb, '数据库升级，从版本 $oldVersion 到 $newVersion');
    // No migrations for initial release
  }

  /// Close database connection
  Future<void> close() async {
    logService.i(LogConfig.moduleDb, '关闭数据库连接');
    final db = await database;
    await db.close();
    _database = null;
    logService.i(LogConfig.moduleDb, '数据库连接已关闭');
  }

  /// Clear all data (for testing purposes)
  Future<void> clearAllData() async {
    logService.i(LogConfig.moduleDb, '清空数据库数据');
    final db = await database;
    await db.delete(AppConstants.invoicesTable);
    await db.delete(AppConstants.ordersTable);
    logService.i(LogConfig.moduleDb, '数据已清空');
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
      logService.i(LogConfig.moduleDb, '导出数据库到: $outputPath');
      final dbPath = await getDatabasePath();
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        logService.w(LogConfig.moduleDb, '数据库文件不存在，无法导出');
        return null;
      }

      // Close database before copying
      await close();

      // Copy database file
      await dbFile.copy(outputPath);

      logService.i(LogConfig.moduleDb, '数据库导出成功');
      return outputPath;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '导出数据库失败', e, stackTrace);
      return null;
    }
  }

  /// Replace database with a new database file
  /// This will close the current database, replace the file, and reopen
  Future<bool> replaceDatabase(File newDbFile) async {
    try {
      logService.i(LogConfig.moduleDb, '替换数据库: ${newDbFile.path}');

      if (!await newDbFile.exists()) {
        logService.w(LogConfig.moduleDb, '新数据库文件不存在');
        return false;
      }

      final dbPath = await getDatabasePath();

      // Close current database
      await close();

      // Delete old database file if exists
      final oldDbFile = File(dbPath);
      if (await oldDbFile.exists()) {
        await oldDbFile.delete();
        logService.i(LogConfig.moduleDb, '旧数据库文件已删除');
      }

      // Copy new database to the database path
      await newDbFile.copy(dbPath);

      // Reopen database (this will trigger onUpgrade if needed)
      await database;

      logService.i(LogConfig.moduleDb, '数据库替换成功');
      return true;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '替换数据库失败', e, stackTrace);
      return false;
    }
  }
}

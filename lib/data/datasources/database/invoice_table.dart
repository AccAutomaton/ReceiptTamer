import 'package:sqflite/sqflite.dart';

import '../../models/invoice.dart';
import '../../../core/constants/app_constants.dart';

/// Invoice table data access object
/// Handles all CRUD operations for the invoices table
class InvoiceTable {
  final Database database;

  InvoiceTable({required this.database});

  /// Insert a new invoice into the database
  Future<int> insert(Invoice invoice) async {
    return await database.insert(
      AppConstants.invoicesTable,
      invoice.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update an existing invoice in the database
  Future<int> update(Invoice invoice) async {
    return await database.update(
      AppConstants.invoicesTable,
      invoice.toJson(),
      where: '${AppConstants.colId} = ?',
      whereArgs: [invoice.id],
    );
  }

  /// Delete an invoice by ID
  Future<int> delete(int id) async {
    return await database.delete(
      AppConstants.invoicesTable,
      where: '${AppConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  /// Delete all invoices
  Future<int> deleteAll() async {
    return await database.delete(AppConstants.invoicesTable);
  }

  /// Delete invoices by order ID
  Future<int> deleteByOrderId(int orderId) async {
    return await database.delete(
      AppConstants.invoicesTable,
      where: '${AppConstants.colOrderId} = ?',
      whereArgs: [orderId],
    );
  }

  /// Get an invoice by ID
  Future<Invoice?> getById(int id) async {
    final List<Map<String, dynamic>> maps = await database.query(
      AppConstants.invoicesTable,
      where: '${AppConstants.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return Invoice.fromJson(maps.first);
  }

  /// Get all invoices, ordered by creation date (newest first)
  Future<List<Invoice>> getAll({int? limit, int? offset}) async {
    final List<Map<String, dynamic>> maps = await database.query(
      AppConstants.invoicesTable,
      orderBy: '${AppConstants.colCreatedAt} DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((map) => Invoice.fromJson(map)).toList();
  }

  /// Get invoices by order ID
  Future<List<Invoice>> getByOrderId(int orderId) async {
    final List<Map<String, dynamic>> maps = await database.query(
      AppConstants.invoicesTable,
      where: '${AppConstants.colOrderId} = ?',
      whereArgs: [orderId],
      orderBy: '${AppConstants.colCreatedAt} DESC',
    );

    return maps.map((map) => Invoice.fromJson(map)).toList();
  }

  /// Get invoices by invoice number (exact match)
  Future<List<Invoice>> getByInvoiceNumber(String invoiceNumber) async {
    final List<Map<String, dynamic>> maps = await database.query(
      AppConstants.invoicesTable,
      where: '${AppConstants.colInvoiceNumber} = ?',
      whereArgs: [invoiceNumber],
      orderBy: '${AppConstants.colCreatedAt} DESC',
    );

    return maps.map((map) => Invoice.fromJson(map)).toList();
  }

  /// Get invoices by invoice number (partial match)
  Future<List<Invoice>> searchByInvoiceNumber(String invoiceNumber) async {
    final List<Map<String, dynamic>> maps = await database.query(
      AppConstants.invoicesTable,
      where: '${AppConstants.colInvoiceNumber} LIKE ?',
      whereArgs: ['%$invoiceNumber%'],
      orderBy: '${AppConstants.colCreatedAt} DESC',
    );

    return maps.map((map) => Invoice.fromJson(map)).toList();
  }

  /// Get invoices by date range
  Future<List<Invoice>> getByDateRange(DateTime start, DateTime end) async {
    final startDate = start.toIso8601String();
    final endDate = end.toIso8601String();

    final List<Map<String, dynamic>> maps = await database.query(
      AppConstants.invoicesTable,
      where: '${AppConstants.colCreatedAt} BETWEEN ? AND ?',
      whereArgs: [startDate, endDate],
      orderBy: '${AppConstants.colCreatedAt} DESC',
    );

    return maps.map((map) => Invoice.fromJson(map)).toList();
  }

  /// Get invoices created today
  Future<List<Invoice>> getTodayInvoices() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return getByDateRange(startOfDay, endOfDay);
  }

  /// Get invoices created this month
  Future<List<Invoice>> getThisMonthInvoices() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 1)
        .subtract(const Duration(days: 1, seconds: 1));

    return getByDateRange(startOfMonth, endOfMonth);
  }

  /// Get invoices without linked orders
  Future<List<Invoice>> getWithoutOrders() async {
    final List<Map<String, dynamic>> maps = await database.query(
      AppConstants.invoicesTable,
      where: '${AppConstants.colOrderId} IS NULL OR ${AppConstants.colOrderId} = ?',
      whereArgs: [0],
      orderBy: '${AppConstants.colCreatedAt} DESC',
    );

    return maps.map((map) => Invoice.fromJson(map)).toList();
  }

  /// Get the total amount of all invoices
  Future<double> getTotalAmount() async {
    final result = await database.rawQuery(
      'SELECT SUM(${AppConstants.colTotalAmount}) as total FROM ${AppConstants.invoicesTable}',
    );

    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    return 0.0;
  }

  /// Get the total amount for a date range
  Future<double> getTotalAmountByDateRange(DateTime start, DateTime end) async {
    final startDate = start.toIso8601String();
    final endDate = end.toIso8601String();

    final result = await database.rawQuery(
      'SELECT SUM(${AppConstants.colTotalAmount}) as total FROM ${AppConstants.invoicesTable} '
      'WHERE ${AppConstants.colCreatedAt} BETWEEN ? AND ?',
      [startDate, endDate],
    );

    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    return 0.0;
  }

  /// Get invoice count
  Future<int> getCount() async {
    final result = await database.rawQuery(
      'SELECT COUNT(*) as count FROM ${AppConstants.invoicesTable}',
    );

    if (result.isNotEmpty && result.first['count'] != null) {
      return (result.first['count'] as int);
    }
    return 0;
  }

  /// Get invoice count by order ID
  Future<int> getCountByOrderId(int orderId) async {
    final result = await database.rawQuery(
      'SELECT COUNT(*) as count FROM ${AppConstants.invoicesTable} '
      'WHERE ${AppConstants.colOrderId} = ?',
      [orderId],
    );

    if (result.isNotEmpty && result.first['count'] != null) {
      return (result.first['count'] as int);
    }
    return 0;
  }

  /// Search invoices by multiple criteria
  Future<List<Invoice>> search({
    String? invoiceNumber,
    int? orderId,
    double? minAmount,
    double? maxAmount,
    DateTime? startDate,
    DateTime? endDate,
    bool? hasLinkedOrder,
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];

    if (invoiceNumber != null && invoiceNumber.isNotEmpty) {
      conditions.add('${AppConstants.colInvoiceNumber} LIKE ?');
      args.add('%$invoiceNumber%');
    }

    if (orderId != null) {
      conditions.add('${AppConstants.colOrderId} = ?');
      args.add(orderId);
    }

    if (minAmount != null) {
      conditions.add('${AppConstants.colTotalAmount} >= ?');
      args.add(minAmount);
    }

    if (maxAmount != null) {
      conditions.add('${AppConstants.colTotalAmount} <= ?');
      args.add(maxAmount);
    }

    if (startDate != null) {
      conditions.add('${AppConstants.colCreatedAt} >= ?');
      args.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      conditions.add('${AppConstants.colCreatedAt} <= ?');
      args.add(endDate.toIso8601String());
    }

    if (hasLinkedOrder == true) {
      conditions.add('${AppConstants.colOrderId} IS NOT NULL AND ${AppConstants.colOrderId} > 0');
    } else if (hasLinkedOrder == false) {
      conditions.add('${AppConstants.colOrderId} IS NULL OR ${AppConstants.colOrderId} = 0');
    }

    final whereClause = conditions.isNotEmpty
        ? conditions.join(' AND ')
        : '1=1';

    final List<Map<String, dynamic>> maps = await database.query(
      AppConstants.invoicesTable,
      where: whereClause,
      whereArgs: args.isEmpty ? null : args,
      orderBy: '${AppConstants.colCreatedAt} DESC',
    );

    return maps.map((map) => Invoice.fromJson(map)).toList();
  }

  /// Get invoices with their related order information (JOIN query)
  Future<List<Map<String, dynamic>>> getWithOrderInfo() async {
    final List<Map<String, dynamic>> maps = await database.rawQuery(
      '''
      SELECT i.*, o.${AppConstants.colShopName}, o.${AppConstants.colAmount} as order_amount,
             o.${AppConstants.colOrderTime}, o.${AppConstants.colOrderNumber}
      FROM ${AppConstants.invoicesTable} i
      LEFT JOIN ${AppConstants.ordersTable} o ON i.${AppConstants.colOrderId} = o.${AppConstants.colId}
      ORDER BY i.${AppConstants.colCreatedAt} DESC
      ''',
    );

    return maps;
  }
}

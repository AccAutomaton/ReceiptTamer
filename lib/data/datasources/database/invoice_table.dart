import 'package:sqflite/sqflite.dart';

import '../../models/invoice.dart';
import '../../../core/constants/app_constants.dart';

/// Invoice table data access object
/// Handles all CRUD operations for the invoices table
/// Note: Order relationships are managed through invoice_order_relations table
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

  /// Get invoices by order ID (through relation table)
  Future<List<Invoice>> getByOrderId(int orderId) async {
    final List<Map<String, dynamic>> maps = await database.rawQuery(
      '''
      SELECT i.* FROM ${AppConstants.invoicesTable} i
      INNER JOIN ${AppConstants.invoiceOrderRelationsTable} r
      ON i.${AppConstants.colId} = r.${AppConstants.colInvoiceId}
      WHERE r.${AppConstants.colOrderId} = ?
      ORDER BY i.${AppConstants.colCreatedAt} DESC
      ''',
      [orderId],
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

  /// Get invoices by invoice date range
  /// Uses invoice_date field (stored as ISO8601 format, e.g., '2024-01-15T00:00:00.000')
  /// Compares only the date portion (YYYY-MM-DD)
  Future<List<Invoice>> getByDateRange(DateTime start, DateTime end) async {
    // Format dates as 'yyyy-MM-dd' for comparison
    final startDate = _formatDate(start);
    final endDate = _formatDate(end);

    // Use SQLite's date() function to extract date portion from ISO8601 string
    // Or use substr() to get first 10 characters (YYYY-MM-DD)
    final List<Map<String, dynamic>> maps = await database.query(
      AppConstants.invoicesTable,
      where: 'substr(${AppConstants.colInvoiceDate}, 1, 10) >= ? AND substr(${AppConstants.colInvoiceDate}, 1, 10) <= ?',
      whereArgs: [startDate, endDate],
      orderBy: '${AppConstants.colInvoiceDate} ASC',
    );

    return maps.map((map) => Invoice.fromJson(map)).toList();
  }

  /// Format DateTime to 'yyyy-MM-dd' string
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Get invoices with invoice date today
  /// invoice_date is stored as ISO8601, so we extract the date portion for comparison
  Future<List<Invoice>> getTodayInvoices() async {
    final now = DateTime.now();
    final todayStr = _formatDate(now);

    final List<Map<String, dynamic>> maps = await database.query(
      AppConstants.invoicesTable,
      where: 'substr(${AppConstants.colInvoiceDate}, 1, 10) = ?',
      whereArgs: [todayStr],
      orderBy: '${AppConstants.colInvoiceDate} DESC',
    );

    return maps.map((map) => Invoice.fromJson(map)).toList();
  }

  /// Get invoices with invoice date in this month
  Future<List<Invoice>> getThisMonthInvoices() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0); // Last day of month

    return getByDateRange(startOfMonth, endOfMonth);
  }

  /// Get invoices without linked orders (no relations in the relation table)
  Future<List<Invoice>> getWithoutOrders() async {
    final List<Map<String, dynamic>> maps = await database.rawQuery(
      '''
      SELECT * FROM ${AppConstants.invoicesTable}
      WHERE ${AppConstants.colId} NOT IN (
        SELECT DISTINCT ${AppConstants.colInvoiceId} FROM ${AppConstants.invoiceOrderRelationsTable}
      )
      ORDER BY ${AppConstants.colCreatedAt} DESC
      ''',
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

  /// Get the total amount for a date range (based on invoice_date)
  /// invoice_date is stored as ISO8601, so we extract the date portion for comparison
  Future<double> getTotalAmountByDateRange(DateTime start, DateTime end) async {
    final startDate = _formatDate(start);
    final endDate = _formatDate(end);

    final result = await database.rawQuery(
      'SELECT SUM(${AppConstants.colTotalAmount}) as total FROM ${AppConstants.invoicesTable} '
      'WHERE substr(${AppConstants.colInvoiceDate}, 1, 10) >= ? AND substr(${AppConstants.colInvoiceDate}, 1, 10) <= ?',
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

  /// Get invoice count by order ID (through relation table)
  Future<int> getCountByOrderId(int orderId) async {
    final result = await database.rawQuery(
      '''
      SELECT COUNT(*) as count FROM ${AppConstants.invoiceOrderRelationsTable}
      WHERE ${AppConstants.colOrderId} = ?
      ''',
      [orderId],
    );

    if (result.isNotEmpty && result.first['count'] != null) {
      return (result.first['count'] as int);
    }
    return 0;
  }

  /// Search invoices by multiple criteria
  /// Note: orderId filter uses the invoice_order_relations table
  Future<List<Invoice>> search({
    String? invoiceNumber,
    String? sellerName,
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

    if (sellerName != null && sellerName.isNotEmpty) {
      conditions.add('${AppConstants.colSellerName} LIKE ?');
      args.add('%$sellerName%');
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
      conditions.add('substr(${AppConstants.colInvoiceDate}, 1, 10) >= ?');
      args.add(_formatDate(startDate));
    }

    if (endDate != null) {
      conditions.add('substr(${AppConstants.colInvoiceDate}, 1, 10) <= ?');
      args.add(_formatDate(endDate));
    }

    String whereClause = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';

    // Handle orderId filter through relation table
    if (orderId != null) {
      whereClause += conditions.isNotEmpty ? ' AND ' : 'WHERE ';
      whereClause += '${AppConstants.colId} IN (SELECT ${AppConstants.colInvoiceId} FROM ${AppConstants.invoiceOrderRelationsTable} WHERE ${AppConstants.colOrderId} = ?)';
      args.add(orderId);
    }

    // Handle hasLinkedOrder filter through relation table
    if (hasLinkedOrder == true) {
      whereClause += conditions.isNotEmpty ? ' AND ' : 'WHERE ';
      whereClause += '${AppConstants.colId} IN (SELECT DISTINCT ${AppConstants.colInvoiceId} FROM ${AppConstants.invoiceOrderRelationsTable})';
    } else if (hasLinkedOrder == false) {
      whereClause += conditions.isNotEmpty ? ' AND ' : 'WHERE ';
      whereClause += '${AppConstants.colId} NOT IN (SELECT DISTINCT ${AppConstants.colInvoiceId} FROM ${AppConstants.invoiceOrderRelationsTable})';
    }

    final List<Map<String, dynamic>> maps = await database.rawQuery(
      'SELECT * FROM ${AppConstants.invoicesTable} $whereClause ORDER BY ${AppConstants.colCreatedAt} DESC',
      args,
    );

    return maps.map((map) => Invoice.fromJson(map)).toList();
  }

  /// Get invoices with their related order information (JOIN query through relation table)
  /// Returns one row per invoice-order pair, so an invoice with multiple orders will appear multiple times
  Future<List<Map<String, dynamic>>> getWithOrderInfo() async {
    final List<Map<String, dynamic>> maps = await database.rawQuery(
      '''
      SELECT i.*, o.${AppConstants.colShopName}, o.${AppConstants.colAmount} as order_amount,
             o.${AppConstants.colOrderDate}, o.${AppConstants.colMealTime}, o.${AppConstants.colOrderNumber}
      FROM ${AppConstants.invoicesTable} i
      LEFT JOIN ${AppConstants.invoiceOrderRelationsTable} r ON i.${AppConstants.colId} = r.${AppConstants.colInvoiceId}
      LEFT JOIN ${AppConstants.ordersTable} o ON r.${AppConstants.colOrderId} = o.${AppConstants.colId}
      ORDER BY i.${AppConstants.colCreatedAt} DESC
      ''',
    );

    return maps;
  }


  /// Get seller names with count, ordered by count (highest first)
  /// Returns a list of maps with 'seller_name' and 'count' keys
  Future<List<Map<String, dynamic>>> getSellerNamesWithCount() async {
    final List<Map<String, dynamic>> maps = await database.rawQuery(
      'SELECT ${AppConstants.colSellerName} as seller_name, COUNT(*) as count '
      'FROM ${AppConstants.invoicesTable} '
      'WHERE ${AppConstants.colSellerName} IS NOT NULL AND ${AppConstants.colSellerName} != "" '
      'GROUP BY ${AppConstants.colSellerName} '
      'ORDER BY count DESC, ${AppConstants.colSellerName} ASC',
    );

    return maps;
  }
}

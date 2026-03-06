import 'package:sqflite/sqflite.dart';

import '../../models/order.dart';
import '../../../core/constants/app_constants.dart';

/// Order table data access object
/// Handles all CRUD operations for the orders table
class OrderTable {
  final Database database;

  OrderTable({required this.database});

  /// Insert a new order into the database
  Future<int> insert(Order order) async {
    return await database.insert(
      AppConstants.ordersTable,
      order.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update an existing order in the database
  Future<int> update(Order order) async {
    return await database.update(
      AppConstants.ordersTable,
      order.toJson(),
      where: '${AppConstants.colId} = ?',
      whereArgs: [order.id],
    );
  }

  /// Delete an order by ID
  Future<int> delete(int id) async {
    // Note: Due to foreign key constraint with ON DELETE CASCADE,
    // related invoices will be automatically deleted
    return await database.delete(
      AppConstants.ordersTable,
      where: '${AppConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  /// Delete all orders
  Future<int> deleteAll() async {
    return await database.delete(AppConstants.ordersTable);
  }

  /// Get an order by ID
  Future<Order?> getById(int id) async {
    final List<Map<String, dynamic>> maps = await database.query(
      AppConstants.ordersTable,
      where: '${AppConstants.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return Order.fromJson(maps.first);
  }

  /// Get all orders, ordered by creation date (newest first)
  Future<List<Order>> getAll({int? limit, int? offset}) async {
    final List<Map<String, dynamic>> maps = await database.query(
      AppConstants.ordersTable,
      orderBy: '${AppConstants.colCreatedAt} DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((map) => Order.fromJson(map)).toList();
  }

  /// Get orders by shop name (partial match)
  Future<List<Order>> getByShopName(String shopName) async {
    final List<Map<String, dynamic>> maps = await database.query(
      AppConstants.ordersTable,
      where: '${AppConstants.colShopName} LIKE ?',
      whereArgs: ['%$shopName%'],
      orderBy: '${AppConstants.colCreatedAt} DESC',
    );

    return maps.map((map) => Order.fromJson(map)).toList();
  }

  /// Get orders by order number (exact match)
  Future<List<Order>> getByOrderNumber(String orderNumber) async {
    final List<Map<String, dynamic>> maps = await database.query(
      AppConstants.ordersTable,
      where: '${AppConstants.colOrderNumber} = ?',
      whereArgs: [orderNumber],
      orderBy: '${AppConstants.colCreatedAt} DESC',
    );

    return maps.map((map) => Order.fromJson(map)).toList();
  }

  /// Get orders by date range
  Future<List<Order>> getByDateRange(DateTime start, DateTime end) async {
    final startDate = start.toIso8601String();
    final endDate = end.toIso8601String();

    final List<Map<String, dynamic>> maps = await database.query(
      AppConstants.ordersTable,
      where: '${AppConstants.colCreatedAt} BETWEEN ? AND ?',
      whereArgs: [startDate, endDate],
      orderBy: '${AppConstants.colCreatedAt} DESC',
    );

    return maps.map((map) => Order.fromJson(map)).toList();
  }

  /// Get orders created today
  Future<List<Order>> getTodayOrders() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return getByDateRange(startOfDay, endOfDay);
  }

  /// Get orders created this month
  Future<List<Order>> getThisMonthOrders() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 1)
        .subtract(const Duration(days: 1, seconds: 1));

    return getByDateRange(startOfMonth, endOfMonth);
  }

  /// Get the total amount of all orders
  Future<double> getTotalAmount() async {
    final result = await database.rawQuery(
      'SELECT SUM(${AppConstants.colAmount}) as total FROM ${AppConstants.ordersTable}',
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
      'SELECT SUM(${AppConstants.colAmount}) as total FROM ${AppConstants.ordersTable} '
      'WHERE ${AppConstants.colCreatedAt} BETWEEN ? AND ?',
      [startDate, endDate],
    );

    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    return 0.0;
  }

  /// Get order count
  Future<int> getCount() async {
    final result = await database.rawQuery(
      'SELECT COUNT(*) as count FROM ${AppConstants.ordersTable}',
    );

    if (result.isNotEmpty && result.first['count'] != null) {
      return (result.first['count'] as int);
    }
    return 0;
  }

  /// Get orders without linked invoices
  Future<List<Order>> getWithoutInvoices() async {
    final List<Map<String, dynamic>> maps = await database.rawQuery(
      'SELECT o.* FROM ${AppConstants.ordersTable} o '
      'LEFT JOIN ${AppConstants.invoicesTable} i ON o.${AppConstants.colId} = i.${AppConstants.colOrderId} '
      'WHERE i.${AppConstants.colId} IS NULL '
      'ORDER BY o.${AppConstants.colCreatedAt} DESC',
    );

    return maps.map((map) => Order.fromJson(map)).toList();
  }

  /// Search orders by multiple criteria
  Future<List<Order>> search({
    String? shopName,
    String? orderNumber,
    double? minAmount,
    double? maxAmount,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];

    if (shopName != null && shopName.isNotEmpty) {
      conditions.add('${AppConstants.colShopName} LIKE ?');
      args.add('%$shopName%');
    }

    if (orderNumber != null && orderNumber.isNotEmpty) {
      conditions.add('${AppConstants.colOrderNumber} LIKE ?');
      args.add('%$orderNumber%');
    }

    if (minAmount != null) {
      conditions.add('${AppConstants.colAmount} >= ?');
      args.add(minAmount);
    }

    if (maxAmount != null) {
      conditions.add('${AppConstants.colAmount} <= ?');
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

    final whereClause = conditions.isNotEmpty
        ? conditions.join(' AND ')
        : '1=1';

    final List<Map<String, dynamic>> maps = await database.query(
      AppConstants.ordersTable,
      where: whereClause,
      whereArgs: args.isEmpty ? null : args,
      orderBy: '${AppConstants.colCreatedAt} DESC',
    );

    return maps.map((map) => Order.fromJson(map)).toList();
  }
}

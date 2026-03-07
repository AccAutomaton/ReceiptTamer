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

  /// Get all orders, ordered by order date (newest first), then by meal time (dinner > lunch > breakfast)
  Future<List<Order>> getAll({int? limit, int? offset}) async {
    final List<Map<String, dynamic>> maps = await database.query(
      AppConstants.ordersTable,
      orderBy: '${AppConstants.colOrderDate} DESC, '
          'CASE ${AppConstants.colMealTime} '
          "WHEN 'dinner' THEN 1 "
          "WHEN 'lunch' THEN 2 "
          "WHEN 'breakfast' THEN 3 "
          'ELSE 4 END ASC',
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
      orderBy: '${AppConstants.colOrderDate} DESC, '
          'CASE ${AppConstants.colMealTime} '
          "WHEN 'dinner' THEN 1 "
          "WHEN 'lunch' THEN 2 "
          "WHEN 'breakfast' THEN 3 "
          'ELSE 4 END ASC',
    );

    return maps.map((map) => Order.fromJson(map)).toList();
  }

  /// Get orders by order number (exact match)
  Future<List<Order>> getByOrderNumber(String orderNumber) async {
    final List<Map<String, dynamic>> maps = await database.query(
      AppConstants.ordersTable,
      where: '${AppConstants.colOrderNumber} = ?',
      whereArgs: [orderNumber],
      orderBy: '${AppConstants.colOrderDate} DESC, '
          'CASE ${AppConstants.colMealTime} '
          "WHEN 'dinner' THEN 1 "
          "WHEN 'lunch' THEN 2 "
          "WHEN 'breakfast' THEN 3 "
          'ELSE 4 END ASC',
    );

    return maps.map((map) => Order.fromJson(map)).toList();
  }

  /// Get orders by order date range
  /// Uses order_date field (stored as 'yyyy-MM-dd' format)
  Future<List<Order>> getByDateRange(DateTime start, DateTime end) async {
    // Format dates as 'yyyy-MM-dd' for comparison with order_date field
    final startDate = _formatDate(start);
    final endDate = _formatDate(end);

    final List<Map<String, dynamic>> maps = await database.query(
      AppConstants.ordersTable,
      where: '${AppConstants.colOrderDate} >= ? AND ${AppConstants.colOrderDate} <= ?',
      whereArgs: [startDate, endDate],
      orderBy: '${AppConstants.colOrderDate} DESC, '
          'CASE ${AppConstants.colMealTime} '
          "WHEN 'dinner' THEN 1 "
          "WHEN 'lunch' THEN 2 "
          "WHEN 'breakfast' THEN 3 "
          'ELSE 4 END ASC',
    );

    return maps.map((map) => Order.fromJson(map)).toList();
  }

  /// Format DateTime to 'yyyy-MM-dd' string
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Get orders with order date today
  Future<List<Order>> getTodayOrders() async {
    final now = DateTime.now();
    final todayStr = _formatDate(now);

    final List<Map<String, dynamic>> maps = await database.query(
      AppConstants.ordersTable,
      where: '${AppConstants.colOrderDate} = ?',
      whereArgs: [todayStr],
      orderBy: '${AppConstants.colOrderDate} DESC, '
          'CASE ${AppConstants.colMealTime} '
          "WHEN 'dinner' THEN 1 "
          "WHEN 'lunch' THEN 2 "
          "WHEN 'breakfast' THEN 3 "
          'ELSE 4 END ASC',
    );

    return maps.map((map) => Order.fromJson(map)).toList();
  }

  /// Get orders with order date in this month
  Future<List<Order>> getThisMonthOrders() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0); // Last day of month

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

  /// Get the total amount for a date range (based on order_date)
  Future<double> getTotalAmountByDateRange(DateTime start, DateTime end) async {
    final startDate = _formatDate(start);
    final endDate = _formatDate(end);

    final result = await database.rawQuery(
      'SELECT SUM(${AppConstants.colAmount}) as total FROM ${AppConstants.ordersTable} '
      'WHERE ${AppConstants.colOrderDate} >= ? AND ${AppConstants.colOrderDate} <= ?',
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
      'ORDER BY o.${AppConstants.colOrderDate} DESC, '
      'CASE o.${AppConstants.colMealTime} '
      "WHEN 'dinner' THEN 1 "
      "WHEN 'lunch' THEN 2 "
      "WHEN 'breakfast' THEN 3 "
      'ELSE 4 END ASC',
    );

    return maps.map((map) => Order.fromJson(map)).toList();
  }

  /// Search orders by multiple criteria
  /// When both shopName and orderNumber are provided with the same value (keyword search),
  /// it performs an OR search on both fields.
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

    // Check if this is a keyword search (same value for shopName and orderNumber)
    // In this case, perform an OR search on both fields
    if (shopName != null &&
        shopName.isNotEmpty &&
        orderNumber != null &&
        orderNumber.isNotEmpty &&
        shopName == orderNumber) {
      conditions.add('(${AppConstants.colShopName} LIKE ? OR ${AppConstants.colOrderNumber} LIKE ?)');
      args.add('%$shopName%');
      args.add('%$orderNumber%');
    } else {
      // Separate criteria search - use AND logic
      if (shopName != null && shopName.isNotEmpty) {
        conditions.add('${AppConstants.colShopName} LIKE ?');
        args.add('%$shopName%');
      }

      if (orderNumber != null && orderNumber.isNotEmpty) {
        conditions.add('${AppConstants.colOrderNumber} LIKE ?');
        args.add('%$orderNumber%');
      }
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
      conditions.add('${AppConstants.colOrderDate} >= ?');
      args.add(_formatDate(startDate));
    }

    if (endDate != null) {
      conditions.add('${AppConstants.colOrderDate} <= ?');
      args.add(_formatDate(endDate));
    }

    final whereClause = conditions.isNotEmpty
        ? conditions.join(' AND ')
        : '1=1';

    final List<Map<String, dynamic>> maps = await database.query(
      AppConstants.ordersTable,
      where: whereClause,
      whereArgs: args.isEmpty ? null : args,
      orderBy: '${AppConstants.colOrderDate} DESC, '
          'CASE ${AppConstants.colMealTime} '
          "WHEN 'dinner' THEN 1 "
          "WHEN 'lunch' THEN 2 "
          "WHEN 'breakfast' THEN 3 "
          'ELSE 4 END ASC',
    );

    return maps.map((map) => Order.fromJson(map)).toList();
  }
}

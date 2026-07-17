import 'package:sqflite/sqflite.dart';

import '../../models/order.dart';
import '../../models/uninvoiced_shop_summary.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/log_service.dart';
import '../../../core/services/log_config.dart';
import '../../../core/models/ledger_month_summary.dart';

/// Order table data access object
/// Handles all CRUD operations for the orders table
class OrderTable {
  final Database database;

  OrderTable({required this.database});

  /// SQL fragment for LEFT JOIN with invoice relations to check if order has linked invoice
  static const String _validInvoiceOrderIdSubquery =
      'SELECT DISTINCT r.${AppConstants.colOrderId} '
      'FROM ${AppConstants.invoiceOrderRelationsTable} r '
      'INNER JOIN ${AppConstants.invoicesTable} i '
      'ON r.${AppConstants.colInvoiceId} = i.${AppConstants.colId}';

  static const String _invoiceJoinClause =
      'LEFT JOIN ($_validInvoiceOrderIdSubquery) r '
      'ON o.${AppConstants.colId} = r.${AppConstants.colOrderId}';

  /// SQL fragment for has_invoice computed column
  static const String _hasInvoiceColumn =
      'CASE WHEN r.${AppConstants.colOrderId} IS NOT NULL THEN 1 ELSE 0 END as has_invoice';

  /// The ledger shows the business date when it is valid, otherwise it falls
  /// back to the collection time. Every date filter must use the same rule so
  /// that a row visible in a month can also be found by that month filter.
  static const String _ledgerDateExpression =
      "COALESCE(date(NULLIF(trim(o.${AppConstants.colOrderDate}), '')), "
      "date(NULLIF(trim(o.${AppConstants.colCreatedAt}), '')))";
  static const String _unqualifiedLedgerDateExpression =
      "COALESCE(date(NULLIF(trim(${AppConstants.colOrderDate}), '')), "
      "date(NULLIF(trim(${AppConstants.colCreatedAt}), '')))";

  /// SQL fragment for ordering orders by date (newest first) then meal time (dinner > lunch > breakfast)
  static const String _orderByClause =
      'ORDER BY $_ledgerDateExpression DESC, '
      "CASE o.${AppConstants.colMealTime} "
      "WHEN 'dinner' THEN 1 "
      "WHEN 'lunch' THEN 2 "
      "WHEN 'breakfast' THEN 3 "
      'ELSE 4 END ASC, '
      'o.${AppConstants.colCreatedAt} DESC, '
      'o.${AppConstants.colId} DESC';

  static const String _normalizedShopKeyExpression =
      "trim(coalesce(o.${AppConstants.colShopName}, ''))";

  static String _paginationClause({int? limit, int? offset}) {
    if (limit == null && offset == null) return '';

    final effectiveLimit = limit ?? -1;
    if (offset == null) return 'LIMIT $effectiveLimit';
    return 'LIMIT $effectiveLimit OFFSET $offset';
  }

  /// Parse order from query result with has_invoice field
  Order _parseOrderWithInvoice(Map<String, dynamic> map) {
    return Order.fromJson(
      map,
    ).copyWith(hasInvoice: (map['has_invoice'] as int?) == 1);
  }

  /// Insert a new order into the database
  Future<int> insert(Order order) async {
    try {
      final id = await database.insert(
        AppConstants.ordersTable,
        order.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      logService.i(
        LogConfig.moduleDb,
        '订单已插入: id=$id, shop="${order.shopName}", amount=${order.amount}',
      );
      return id;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '订单插入失败', e, stackTrace);
      rethrow;
    }
  }

  /// Update an existing order in the database
  Future<int> update(Order order) async {
    try {
      final count = await database.update(
        AppConstants.ordersTable,
        order.toJson(),
        where: '${AppConstants.colId} = ?',
        whereArgs: [order.id],
      );
      logService.i(
        LogConfig.moduleDb,
        '订单已更新: id=${order.id}, rowsAffected=$count',
      );
      return count;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '订单更新失败', e, stackTrace);
      rethrow;
    }
  }

  /// Delete an order by ID
  /// Note: Relations in invoice_order_relations will be deleted automatically by CASCADE,
  /// but linked invoices will NOT be deleted - they remain independent.
  Future<int> delete(int id) async {
    try {
      final count = await database.delete(
        AppConstants.ordersTable,
        where: '${AppConstants.colId} = ?',
        whereArgs: [id],
      );
      logService.i(LogConfig.moduleDb, '订单已删除: id=$id, rowsAffected=$count');
      return count;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '订单删除失败', e, stackTrace);
      rethrow;
    }
  }

  /// Delete all orders
  Future<int> deleteAll() async {
    try {
      final count = await database.delete(AppConstants.ordersTable);
      logService.i(LogConfig.moduleDb, '所有订单已删除: count=$count');
      return count;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '删除所有订单失败', e, stackTrace);
      rethrow;
    }
  }

  /// Get an order by ID
  Future<Order?> getById(int id) async {
    try {
      final List<Map<String, dynamic>> maps = await database.query(
        AppConstants.ordersTable,
        where: '${AppConstants.colId} = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (maps.isEmpty) return null;
      return Order.fromJson(maps.first);
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '获取订单失败: id=$id', e, stackTrace);
      rethrow;
    }
  }

  /// 批量读取指定订单，避免关系闭包检查按 ID 循环访问数据库。
  Future<List<Order>> getByIds(List<int> ids) async {
    if (ids.isEmpty) return const [];

    try {
      final uniqueIds = ids.toSet().toList(growable: false);
      final orders = <Order>[];
      for (var offset = 0; offset < uniqueIds.length; offset += 500) {
        final end = offset + 500 < uniqueIds.length
            ? offset + 500
            : uniqueIds.length;
        final chunk = uniqueIds.sublist(offset, end);
        final placeholders = List.filled(chunk.length, '?').join(', ');
        final maps = await database.rawQuery(
          'SELECT o.*, $_hasInvoiceColumn '
          'FROM ${AppConstants.ordersTable} o '
          '$_invoiceJoinClause '
          'WHERE o.${AppConstants.colId} IN ($placeholders)',
          chunk,
        );
        orders.addAll(maps.map(_parseOrderWithInvoice));
      }
      return orders;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '批量获取订单失败', e, stackTrace);
      rethrow;
    }
  }

  /// Get all orders, ordered by order date (newest first), then by meal time (dinner > lunch > breakfast)
  Future<List<Order>> getAll({int? limit, int? offset}) async {
    try {
      final paginationClause = _paginationClause(limit: limit, offset: offset);

      final List<Map<String, dynamic>> maps = await database.rawQuery(
        'SELECT o.*, $_hasInvoiceColumn '
        'FROM ${AppConstants.ordersTable} o '
        '$_invoiceJoinClause '
        '$_orderByClause '
        '$paginationClause',
      );

      return maps.map(_parseOrderWithInvoice).toList();
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '获取所有订单失败', e, stackTrace);
      rethrow;
    }
  }

  /// Get recently collected orders, ordered by creation time.
  ///
  /// This query is intentionally separate from [getAll], whose ordering is
  /// based on the business date of an order. The home archive uses collection
  /// time so newly imported older receipts still appear first.
  Future<List<Order>> getRecentlyCreated({int limit = 10}) async {
    try {
      final List<Map<String, dynamic>> maps = await database.rawQuery(
        'SELECT o.*, $_hasInvoiceColumn '
        'FROM ${AppConstants.ordersTable} o '
        '$_invoiceJoinClause '
        'ORDER BY o.${AppConstants.colCreatedAt} DESC, '
        'o.${AppConstants.colId} DESC '
        'LIMIT ?',
        [limit],
      );

      return maps.map(_parseOrderWithInvoice).toList(growable: false);
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '获取最近收录订单失败', e, stackTrace);
      rethrow;
    }
  }

  /// Return a lightweight month index without loading every order model.
  Future<List<LedgerMonthSummary>> getMonthSummaries() async {
    try {
      final rows = await database.rawQuery(
        "SELECT COALESCE(strftime('%Y-%m', o.${AppConstants.colOrderDate}), "
        "strftime('%Y-%m', o.${AppConstants.colCreatedAt})) AS month_key, "
        'COUNT(*) AS item_count, '
        'COALESCE(SUM(o.${AppConstants.colAmount}), 0) AS total_amount, '
        'COUNT(r.${AppConstants.colOrderId}) AS linked_item_count '
        'FROM ${AppConstants.ordersTable} o '
        '$_invoiceJoinClause '
        'GROUP BY month_key ORDER BY month_key DESC',
      );

      return rows
          .where((row) => (row['month_key'] as String?)?.isNotEmpty ?? false)
          .map(
            (row) => LedgerMonthSummary(
              monthKey: row['month_key'] as String,
              itemCount: (row['item_count'] as num).toInt(),
              totalAmount: (row['total_amount'] as num).toDouble(),
              linkedItemCount: (row['linked_item_count'] as num).toInt(),
            ),
          )
          .toList(growable: false);
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '获取订单月份汇总失败', e, stackTrace);
      rethrow;
    }
  }

  /// Get orders by shop name (partial match)
  Future<List<Order>> getByShopName(String shopName) async {
    try {
      final List<Map<String, dynamic>> maps = await database.query(
        AppConstants.ordersTable,
        where: '${AppConstants.colShopName} LIKE ?',
        whereArgs: ['%$shopName%'],
        orderBy:
            '${AppConstants.colOrderDate} DESC, '
            'CASE ${AppConstants.colMealTime} '
            "WHEN 'dinner' THEN 1 "
            "WHEN 'lunch' THEN 2 "
            "WHEN 'breakfast' THEN 3 "
            'ELSE 4 END ASC',
      );

      return maps.map((map) => Order.fromJson(map)).toList();
    } catch (e, stackTrace) {
      logService.e(
        LogConfig.moduleDb,
        '按店铺名称查询订单失败: shopName="$shopName"',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get orders by order number (exact match)
  Future<List<Order>> getByOrderNumber(String orderNumber) async {
    try {
      final List<Map<String, dynamic>> maps = await database.query(
        AppConstants.ordersTable,
        where: '${AppConstants.colOrderNumber} = ?',
        whereArgs: [orderNumber],
        orderBy:
            '${AppConstants.colOrderDate} DESC, '
            'CASE ${AppConstants.colMealTime} '
            "WHEN 'dinner' THEN 1 "
            "WHEN 'lunch' THEN 2 "
            "WHEN 'breakfast' THEN 3 "
            'ELSE 4 END ASC',
      );

      return maps.map((map) => Order.fromJson(map)).toList();
    } catch (e, stackTrace) {
      logService.e(
        LogConfig.moduleDb,
        '按订单号查询订单失败: orderNumber="$orderNumber"',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get orders by ledger date range (business date, then collection time).
  Future<List<Order>> getByDateRange(DateTime start, DateTime end) async {
    try {
      final startDate = _formatDate(start);
      final endDate = _formatDate(end);

      final List<Map<String, dynamic>> maps = await database.rawQuery(
        'SELECT o.*, $_hasInvoiceColumn '
        'FROM ${AppConstants.ordersTable} o '
        '$_invoiceJoinClause '
        'WHERE $_ledgerDateExpression >= ? AND $_ledgerDateExpression <= ? '
        '$_orderByClause',
        [startDate, endDate],
      );

      return maps.map(_parseOrderWithInvoice).toList();
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '按日期范围查询订单失败', e, stackTrace);
      rethrow;
    }
  }

  /// Format DateTime to 'yyyy-MM-dd' string
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Get orders whose resolved ledger date is today.
  Future<List<Order>> getTodayOrders() async {
    try {
      final todayStr = _formatDate(DateTime.now());

      final List<Map<String, dynamic>> maps = await database.rawQuery(
        'SELECT o.*, $_hasInvoiceColumn '
        'FROM ${AppConstants.ordersTable} o '
        '$_invoiceJoinClause '
        'WHERE $_ledgerDateExpression = ? '
        '$_orderByClause',
        [todayStr],
      );

      return maps.map(_parseOrderWithInvoice).toList();
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '获取今日订单失败', e, stackTrace);
      rethrow;
    }
  }

  /// Get orders whose resolved ledger date is in this month.
  Future<List<Order>> getThisMonthOrders() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(
      now.year,
      now.month + 1,
      0,
    ); // Last day of month

    return getByDateRange(startOfMonth, endOfMonth);
  }

  /// Get the total amount of all orders
  Future<double> getTotalAmount() async {
    try {
      final result = await database.rawQuery(
        'SELECT SUM(${AppConstants.colAmount}) as total FROM ${AppConstants.ordersTable}',
      );

      if (result.isNotEmpty && result.first['total'] != null) {
        return (result.first['total'] as num).toDouble();
      }
      return 0.0;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '获取订单总金额失败', e, stackTrace);
      rethrow;
    }
  }

  /// Get the total amount for a resolved ledger date range.
  Future<double> getTotalAmountByDateRange(DateTime start, DateTime end) async {
    try {
      final startDate = _formatDate(start);
      final endDate = _formatDate(end);

      final result = await database.rawQuery(
        'SELECT SUM(${AppConstants.colAmount}) as total FROM ${AppConstants.ordersTable} '
        'WHERE $_unqualifiedLedgerDateExpression >= ? '
        'AND $_unqualifiedLedgerDateExpression <= ?',
        [startDate, endDate],
      );

      if (result.isNotEmpty && result.first['total'] != null) {
        return (result.first['total'] as num).toDouble();
      }
      return 0.0;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '按日期范围获取订单总金额失败', e, stackTrace);
      rethrow;
    }
  }

  /// Get order count
  Future<int> getCount() async {
    try {
      final result = await database.rawQuery(
        'SELECT COUNT(*) as count FROM ${AppConstants.ordersTable}',
      );

      if (result.isNotEmpty && result.first['count'] != null) {
        return (result.first['count'] as int);
      }
      return 0;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '获取订单数量失败', e, stackTrace);
      rethrow;
    }
  }

  /// Get orders without linked invoices (using relation table)
  Future<List<Order>> getWithoutInvoices() async {
    try {
      final List<Map<String, dynamic>> maps = await database.rawQuery(
        'SELECT o.* FROM ${AppConstants.ordersTable} o '
        'WHERE o.${AppConstants.colId} NOT IN ('
        '  $_validInvoiceOrderIdSubquery'
        ') '
        'ORDER BY $_ledgerDateExpression DESC, '
        'CASE o.${AppConstants.colMealTime} '
        "WHEN 'dinner' THEN 1 "
        "WHEN 'lunch' THEN 2 "
        "WHEN 'breakfast' THEN 3 "
        'ELSE 4 END ASC',
      );

      return maps.map((map) => Order.fromJson(map)).toList();
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '获取未关联发票的订单失败', e, stackTrace);
      rethrow;
    }
  }

  /// Get uninvoiced order summaries grouped by shop.
  Future<List<UninvoicedShopSummary>> getUninvoicedShopSummaries({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final conditions = <String>['r.${AppConstants.colOrderId} IS NULL'];
      final args = <dynamic>[];

      if (startDate != null) {
        conditions.add('$_ledgerDateExpression >= ?');
        args.add(_formatDate(startDate));
      }
      if (endDate != null) {
        conditions.add('$_ledgerDateExpression <= ?');
        args.add(_formatDate(endDate));
      }

      final whereClause = 'WHERE ${conditions.join(' AND ')}';

      final maps = await database.rawQuery('''
        SELECT
          $_normalizedShopKeyExpression AS shop_key,
          CASE
            WHEN $_normalizedShopKeyExpression = '' THEN '未命名店铺'
            ELSE $_normalizedShopKeyExpression
          END AS display_name,
          COUNT(*) AS order_count,
          COALESCE(SUM(o.${AppConstants.colAmount}), 0) AS total_amount
        FROM ${AppConstants.ordersTable} o
        $_invoiceJoinClause
        $whereClause
        GROUP BY shop_key
        ORDER BY total_amount DESC, order_count DESC, display_name ASC
        ''', args);

      return maps.map((map) {
        return UninvoicedShopSummary(
          shopKey: map['shop_key'] as String? ?? '',
          displayName: map['display_name'] as String? ?? '未命名店铺',
          orderCount: (map['order_count'] as num?)?.toInt() ?? 0,
          totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '获取未开票店铺汇总失败', e, stackTrace);
      rethrow;
    }
  }

  /// Get uninvoiced order details for a shop.
  Future<List<Order>> getUninvoicedOrdersForShop(
    String shopKey, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final conditions = <String>[
        'r.${AppConstants.colOrderId} IS NULL',
        '$_normalizedShopKeyExpression = ?',
      ];
      final args = <dynamic>[shopKey.trim()];

      if (startDate != null) {
        conditions.add('$_ledgerDateExpression >= ?');
        args.add(_formatDate(startDate));
      }
      if (endDate != null) {
        conditions.add('$_ledgerDateExpression <= ?');
        args.add(_formatDate(endDate));
      }

      final whereClause = 'WHERE ${conditions.join(' AND ')}';
      final maps = await database.rawQuery('''
        SELECT o.*, $_hasInvoiceColumn
        FROM ${AppConstants.ordersTable} o
        $_invoiceJoinClause
        $whereClause
        $_orderByClause
        ''', args);

      return maps.map(_parseOrderWithInvoice).toList();
    } catch (e, stackTrace) {
      logService.e(
        LogConfig.moduleDb,
        '获取店铺未开票订单失败: shopKey="$shopKey"',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Search orders by multiple criteria
  /// [hasLinkedInvoice] - null: all orders, true: only orders with invoices, false: only orders without invoices
  /// When both shopName and orderNumber are provided with the same value (keyword search),
  /// it performs an OR search on both fields.
  Future<List<Order>> search({
    String? shopName,
    String? orderNumber,
    double? minAmount,
    double? maxAmount,
    DateTime? startDate,
    DateTime? endDate,
    bool? hasLinkedInvoice,
    int? limit,
    int? offset,
  }) async {
    try {
      final conditions = <String>[];
      final args = <dynamic>[];

      // Check if this is a keyword search (same value for shopName and orderNumber)
      // In this case, perform an OR search on both fields
      if (shopName != null &&
          shopName.isNotEmpty &&
          orderNumber != null &&
          orderNumber.isNotEmpty &&
          shopName == orderNumber) {
        conditions.add(
          '(o.${AppConstants.colShopName} LIKE ? OR o.${AppConstants.colOrderNumber} LIKE ?)',
        );
        args.add('%$shopName%');
        args.add('%$orderNumber%');
      } else {
        // Separate criteria search - use AND logic
        if (shopName != null && shopName.isNotEmpty) {
          conditions.add('o.${AppConstants.colShopName} LIKE ?');
          args.add('%$shopName%');
        }

        if (orderNumber != null && orderNumber.isNotEmpty) {
          conditions.add('o.${AppConstants.colOrderNumber} LIKE ?');
          args.add('%$orderNumber%');
        }
      }

      if (minAmount != null) {
        conditions.add('o.${AppConstants.colAmount} >= ?');
        args.add(minAmount);
      }

      if (maxAmount != null) {
        conditions.add('o.${AppConstants.colAmount} <= ?');
        args.add(maxAmount);
      }

      if (startDate != null) {
        conditions.add('$_ledgerDateExpression >= ?');
        args.add(_formatDate(startDate));
      }

      if (endDate != null) {
        conditions.add('$_ledgerDateExpression <= ?');
        args.add(_formatDate(endDate));
      }

      // Filter by invoice relation status
      if (hasLinkedInvoice == true) {
        conditions.add('r.${AppConstants.colOrderId} IS NOT NULL');
      } else if (hasLinkedInvoice == false) {
        conditions.add('r.${AppConstants.colOrderId} IS NULL');
      }

      final whereClause = conditions.isNotEmpty
          ? 'WHERE ${conditions.join(' AND ')}'
          : '';
      final paginationClause = _paginationClause(limit: limit, offset: offset);

      final List<Map<String, dynamic>> maps = await database.rawQuery(
        'SELECT o.*, $_hasInvoiceColumn '
        'FROM ${AppConstants.ordersTable} o '
        '$_invoiceJoinClause '
        '$whereClause '
        '$_orderByClause '
        '$paginationClause',
        args,
      );

      return maps.map(_parseOrderWithInvoice).toList();
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '搜索订单失败', e, stackTrace);
      rethrow;
    }
  }

  /// Search orders with invoice relation filter
  /// [hasInvoice] - null: all orders, true: only orders with invoices, false: only orders without invoices
  /// [excludeInvoiceId] - the current invoice ID being edited
  /// When both shopName and orderNumber are provided with the same value (keyword search),
  /// it performs an OR search on both fields.
  /// Note: For "all" and "with invoice" filters, orders linked to the current invoice
  /// (excludeInvoiceId) are included and will be shown as selected in the UI.
  /// For "without invoice" filter, only truly unlinked orders are shown.
  Future<List<Order>> searchWithInvoiceRelation({
    String? keyword,
    double? minAmount,
    double? maxAmount,
    DateTime? startDate,
    DateTime? endDate,
    bool? hasInvoice,
    int? excludeInvoiceId,
  }) async {
    try {
      final conditions = <String>[];
      final args = <dynamic>[];

      // Keyword search (shopName OR orderNumber)
      if (keyword != null && keyword.isNotEmpty) {
        conditions.add(
          '(${AppConstants.colShopName} LIKE ? OR ${AppConstants.colOrderNumber} LIKE ?)',
        );
        args.add('%$keyword%');
        args.add('%$keyword%');
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
        conditions.add('$_ledgerDateExpression >= ?');
        args.add(_formatDate(startDate));
      }

      if (endDate != null) {
        conditions.add('$_ledgerDateExpression <= ?');
        args.add(_formatDate(endDate));
      }

      // Filter by invoice relation status
      String invoiceRelationClause = '';
      if (hasInvoice == true) {
        // "已关联": Show orders with invoices (including current invoice's orders)
        invoiceRelationClause =
            'o.${AppConstants.colId} IN ($_validInvoiceOrderIdSubquery)';
      } else if (hasInvoice == false) {
        // "未关联": Only show orders without ANY invoices (not including current invoice's orders)
        invoiceRelationClause =
            'o.${AppConstants.colId} NOT IN ($_validInvoiceOrderIdSubquery)';
      }
      // When hasInvoice is null ("全部"), no filter - all orders are shown

      // Build WHERE clause
      final allConditions = <String>[];
      if (conditions.isNotEmpty) {
        allConditions.add('(${conditions.join(' AND ')})');
      }
      if (invoiceRelationClause.isNotEmpty) {
        allConditions.add(invoiceRelationClause);
      }

      final whereClause = allConditions.isNotEmpty
          ? 'WHERE ${allConditions.join(' AND ')}'
          : '';

      // Build ORDER BY clause - put orders linked to current invoice first
      String orderByClause;
      if (excludeInvoiceId != null) {
        orderByClause =
            '''
          CASE WHEN o.${AppConstants.colId} IN (SELECT ${AppConstants.colOrderId} FROM ${AppConstants.invoiceOrderRelationsTable} WHERE ${AppConstants.colInvoiceId} = ?) THEN 0 ELSE 1 END,
          $_ledgerDateExpression DESC,
          CASE o.${AppConstants.colMealTime}
          WHEN 'dinner' THEN 1
          WHEN 'lunch' THEN 2
          WHEN 'breakfast' THEN 3
          ELSE 4 END ASC
        ''';
        args.add(excludeInvoiceId);
      } else {
        orderByClause =
            '''
          $_ledgerDateExpression DESC,
          CASE o.${AppConstants.colMealTime}
          WHEN 'dinner' THEN 1
          WHEN 'lunch' THEN 2
          WHEN 'breakfast' THEN 3
          ELSE 4 END ASC
        ''';
      }

      final List<Map<String, dynamic>> maps = await database.rawQuery(
        'SELECT o.* FROM ${AppConstants.ordersTable} o $whereClause '
        'ORDER BY $orderByClause',
        args,
      );

      return maps.map((map) => Order.fromJson(map)).toList();
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '搜索订单(含发票关联)失败', e, stackTrace);
      rethrow;
    }
  }

  /// Get orders with their invoice relation info
  /// Returns orders with additional `linked_invoice_id` field if linked
  /// [excludeInvoiceId] - exclude orders that are already linked to this invoice (for editing)
  Future<List<Map<String, dynamic>>> getOrdersWithInvoiceInfo({
    int? excludeInvoiceId,
  }) async {
    try {
      String excludeClause = '';
      final args = <dynamic>[];

      if (excludeInvoiceId != null) {
        excludeClause =
            'WHERE o.${AppConstants.colId} NOT IN (SELECT ${AppConstants.colOrderId} FROM ${AppConstants.invoiceOrderRelationsTable} WHERE ${AppConstants.colInvoiceId} = ?)';
        args.add(excludeInvoiceId);
      }

      final List<Map<String, dynamic>> maps = await database.rawQuery(
        'SELECT o.*, r.${AppConstants.colInvoiceId} as linked_invoice_id '
        'FROM ${AppConstants.ordersTable} o '
        'LEFT JOIN ('
        '  SELECT r.${AppConstants.colOrderId}, r.${AppConstants.colInvoiceId} '
        '  FROM ${AppConstants.invoiceOrderRelationsTable} r '
        '  INNER JOIN ${AppConstants.invoicesTable} i '
        '  ON r.${AppConstants.colInvoiceId} = i.${AppConstants.colId}'
        ') r ON o.${AppConstants.colId} = r.${AppConstants.colOrderId} '
        '$excludeClause '
        'ORDER BY o.${AppConstants.colOrderDate} DESC, '
        'CASE o.${AppConstants.colMealTime} '
        "WHEN 'dinner' THEN 1 "
        "WHEN 'lunch' THEN 2 "
        "WHEN 'breakfast' THEN 3 "
        'ELSE 4 END ASC',
        args,
      );

      return maps;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '获取订单(含发票信息)失败', e, stackTrace);
      rethrow;
    }
  }

  /// Get invoice IDs linked to a specific order
  Future<List<int>> getInvoiceIdsForOrder(int orderId) async {
    try {
      final List<Map<String, dynamic>> maps = await database.rawQuery(
        '''
        SELECT r.${AppConstants.colInvoiceId}
        FROM ${AppConstants.invoiceOrderRelationsTable} r
        INNER JOIN ${AppConstants.invoicesTable} i
        ON r.${AppConstants.colInvoiceId} = i.${AppConstants.colId}
        WHERE r.${AppConstants.colOrderId} = ?
        ''',
        [orderId],
      );

      return maps.map((map) => map[AppConstants.colInvoiceId] as int).toList();
    } catch (e, stackTrace) {
      logService.e(
        LogConfig.moduleDb,
        '获取订单关联的发票ID失败: orderId=$orderId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get shop names with count, ordered by count (highest first)
  /// Returns a list of maps with 'shop_name' and 'count' keys
  Future<List<Map<String, dynamic>>> getShopNamesWithCount() async {
    try {
      final List<Map<String, dynamic>> maps = await database.rawQuery(
        'SELECT ${AppConstants.colShopName} as shop_name, COUNT(*) as count '
        'FROM ${AppConstants.ordersTable} '
        'WHERE ${AppConstants.colShopName} IS NOT NULL AND ${AppConstants.colShopName} != "" '
        'GROUP BY ${AppConstants.colShopName} '
        'ORDER BY count DESC, ${AppConstants.colShopName} ASC',
      );

      return maps;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '获取店铺名称统计失败', e, stackTrace);
      rethrow;
    }
  }
}

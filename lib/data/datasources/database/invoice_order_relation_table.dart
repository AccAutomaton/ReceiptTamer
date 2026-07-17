import 'package:sqflite/sqflite.dart';

import '../../models/invoice_order_relation.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/log_service.dart';
import '../../../core/services/log_config.dart';

/// Invoice-Order relation table data access object
/// Handles all CRUD operations for the invoice_order_relations table
class InvoiceOrderRelationTable {
  final DatabaseExecutor database;

  InvoiceOrderRelationTable({required this.database});

  static const String orderIdUniqueIndexName =
      'idx_invoice_order_relations_order_id';

  static const String _validRelationFromClause =
      'FROM ${AppConstants.invoiceOrderRelationsTable} r '
      'INNER JOIN ${AppConstants.invoicesTable} i '
      'ON r.${AppConstants.colInvoiceId} = i.${AppConstants.colId} '
      'INNER JOIN ${AppConstants.ordersTable} o '
      'ON r.${AppConstants.colOrderId} = o.${AppConstants.colId}';

  static const String _orphanedRelationWhereClause =
      '${AppConstants.colInvoiceId} NOT IN (SELECT ${AppConstants.colId} FROM ${AppConstants.invoicesTable}) '
      'OR ${AppConstants.colOrderId} NOT IN (SELECT ${AppConstants.colId} FROM ${AppConstants.ordersTable})';

  /// Insert a new relation
  Future<int> insert(InvoiceOrderRelation relation) async {
    try {
      final id = await database.insert(
        AppConstants.invoiceOrderRelationsTable,
        relation.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      logService.i(
        LogConfig.moduleDb,
        '关联已插入: invoiceId=${relation.invoiceId}, orderId=${relation.orderId}',
      );
      return id;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '关联插入失败', e, stackTrace);
      rethrow;
    }
  }

  /// Insert multiple relations for an invoice
  Future<void> insertRelationsForInvoice(
    int invoiceId,
    List<int> orderIds,
  ) async {
    try {
      final uniqueOrderIds = orderIds.toSet().toList(growable: false);
      final batch = database.batch();
      for (final orderId in uniqueOrderIds) {
        batch.insert(
          AppConstants.invoiceOrderRelationsTable,
          InvoiceOrderRelation(invoiceId: invoiceId, orderId: orderId).toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
      logService.i(
        LogConfig.moduleDb,
        '发票关联已插入: invoiceId=$invoiceId, orderCount=${uniqueOrderIds.length}',
      );
    } catch (e, stackTrace) {
      logService.e(
        LogConfig.moduleDb,
        '批量插入发票关联失败: invoiceId=$invoiceId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Atomically replace all order relations for one invoice.
  ///
  /// The unique order index and REPLACE conflict policy move an order away
  /// from any previous invoice before linking it to [invoiceId].
  Future<void> replaceRelationsForInvoice(
    int invoiceId,
    List<int> orderIds,
  ) async {
    final uniqueOrderIds = orderIds.toSet().toList(growable: false);

    try {
      final executor = database;
      if (executor is Database) {
        await executor.transaction(
          (transaction) =>
              _replaceRelations(transaction, invoiceId, uniqueOrderIds),
        );
      } else {
        // A Transaction is already a DatabaseExecutor. Reuse it so callers
        // can include the owning invoice write in the same transaction.
        await _replaceRelations(executor, invoiceId, uniqueOrderIds);
      }

      logService.i(
        LogConfig.moduleDb,
        '发票关联已替换: invoiceId=$invoiceId, orderCount=${uniqueOrderIds.length}',
      );
    } catch (e, stackTrace) {
      logService.e(
        LogConfig.moduleDb,
        '替换发票关联失败: invoiceId=$invoiceId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  Future<void> _replaceRelations(
    DatabaseExecutor executor,
    int invoiceId,
    List<int> orderIds,
  ) async {
    await executor.delete(
      AppConstants.invoiceOrderRelationsTable,
      where: '${AppConstants.colInvoiceId} = ?',
      whereArgs: [invoiceId],
    );

    if (orderIds.isEmpty) return;

    final batch = executor.batch();
    for (final orderId in orderIds) {
      batch.insert(
        AppConstants.invoiceOrderRelationsTable,
        InvoiceOrderRelation(invoiceId: invoiceId, orderId: orderId).toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Delete all relations for an invoice
  Future<int> deleteByInvoiceId(int invoiceId) async {
    try {
      final count = await database.delete(
        AppConstants.invoiceOrderRelationsTable,
        where: '${AppConstants.colInvoiceId} = ?',
        whereArgs: [invoiceId],
      );
      logService.i(
        LogConfig.moduleDb,
        '发票关联已删除: invoiceId=$invoiceId, count=$count',
      );
      return count;
    } catch (e, stackTrace) {
      logService.e(
        LogConfig.moduleDb,
        '删除发票关联失败: invoiceId=$invoiceId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Delete all relations for an order
  Future<int> deleteByOrderId(int orderId) async {
    try {
      final count = await database.delete(
        AppConstants.invoiceOrderRelationsTable,
        where: '${AppConstants.colOrderId} = ?',
        whereArgs: [orderId],
      );
      logService.i(
        LogConfig.moduleDb,
        '订单关联已删除: orderId=$orderId, count=$count',
      );
      return count;
    } catch (e, stackTrace) {
      logService.e(
        LogConfig.moduleDb,
        '删除订单关联失败: orderId=$orderId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Delete a specific invoice-order relation
  Future<int> deleteRelation(int invoiceId, int orderId) async {
    try {
      final count = await database.delete(
        AppConstants.invoiceOrderRelationsTable,
        where:
            '${AppConstants.colInvoiceId} = ? AND ${AppConstants.colOrderId} = ?',
        whereArgs: [invoiceId, orderId],
      );
      logService.i(
        LogConfig.moduleDb,
        '关联已删除: invoiceId=$invoiceId, orderId=$orderId',
      );
      return count;
    } catch (e, stackTrace) {
      logService.e(
        LogConfig.moduleDb,
        '删除特定关联失败: invoiceId=$invoiceId, orderId=$orderId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Delete relations whose invoice or order row no longer exists.
  Future<int> deleteOrphanedRelations() async {
    try {
      final count = await database.delete(
        AppConstants.invoiceOrderRelationsTable,
        where: _orphanedRelationWhereClause,
      );
      if (count > 0) {
        logService.i(LogConfig.moduleDb, '已清理孤儿发票关联: count=$count');
      }
      return count;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '清理孤儿发票关联失败', e, stackTrace);
      rethrow;
    }
  }

  /// Repair legacy many-to-many rows and enforce invoice -> orders as 1:N.
  ///
  /// Version-1 databases only had a composite primary key, so the same order
  /// could appear under multiple invoices. For each duplicate order we keep
  /// the most recently updated/created invoice, then make order_id unique.
  Future<int> enforceSingleInvoicePerOrder() async {
    try {
      final duplicateOrders = await database.rawQuery('''
        SELECT ${AppConstants.colOrderId}, COUNT(*) AS relation_count
        FROM ${AppConstants.invoiceOrderRelationsTable}
        GROUP BY ${AppConstants.colOrderId}
        HAVING COUNT(*) > 1
      ''');

      var removedCount = 0;
      for (final duplicate in duplicateOrders) {
        final orderId = duplicate[AppConstants.colOrderId] as int;
        final candidates = await database.rawQuery(
          '''
          SELECT r.${AppConstants.colInvoiceId}
          FROM ${AppConstants.invoiceOrderRelationsTable} r
          INNER JOIN ${AppConstants.invoicesTable} i
            ON i.${AppConstants.colId} = r.${AppConstants.colInvoiceId}
          WHERE r.${AppConstants.colOrderId} = ?
          ORDER BY
            COALESCE(i.${AppConstants.colUpdatedAt}, '') DESC,
            COALESCE(i.${AppConstants.colCreatedAt}, '') DESC,
            r.${AppConstants.colInvoiceId} DESC
          LIMIT 1
          ''',
          [orderId],
        );
        if (candidates.isEmpty) continue;

        final retainedInvoiceId =
            candidates.first[AppConstants.colInvoiceId] as int;
        removedCount += await database.delete(
          AppConstants.invoiceOrderRelationsTable,
          where:
              '${AppConstants.colOrderId} = ? AND ${AppConstants.colInvoiceId} <> ?',
          whereArgs: [orderId, retainedInvoiceId],
        );
      }

      final indexes = await database.rawQuery(
        "PRAGMA index_list('${AppConstants.invoiceOrderRelationsTable}')",
      );
      Map<String, Object?>? orderIndex;
      for (final index in indexes) {
        if (index['name'] == orderIdUniqueIndexName) {
          orderIndex = index;
          break;
        }
      }

      final indexIsUnique = (orderIndex?['unique'] as num?)?.toInt() == 1;
      if (!indexIsUnique) {
        if (orderIndex != null) {
          await database.execute('DROP INDEX $orderIdUniqueIndexName');
        }
        await database.execute('''
          CREATE UNIQUE INDEX $orderIdUniqueIndexName
          ON ${AppConstants.invoiceOrderRelationsTable}(${AppConstants.colOrderId})
        ''');
        logService.i(LogConfig.moduleDb, '已建立订单单发票唯一索引');
      }

      if (removedCount > 0) {
        logService.i(
          LogConfig.moduleDb,
          '已修复重复订单关联: removed=$removedCount, orders=${duplicateOrders.length}',
        );
      }
      return removedCount;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '修复订单重复发票关联失败', e, stackTrace);
      rethrow;
    }
  }

  /// Get all order IDs for an invoice
  Future<List<int>> getOrderIdsForInvoice(int invoiceId) async {
    try {
      final List<Map<String, dynamic>> maps = await database.rawQuery(
        '''
        SELECT r.${AppConstants.colOrderId}
        $_validRelationFromClause
        WHERE r.${AppConstants.colInvoiceId} = ?
        ''',
        [invoiceId],
      );

      return maps.map((map) => map[AppConstants.colOrderId] as int).toList();
    } catch (e, stackTrace) {
      logService.e(
        LogConfig.moduleDb,
        '获取发票关联的订单ID失败: invoiceId=$invoiceId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  Future<Map<int, Set<int>>> getOrderIdsForInvoices(
    List<int> invoiceIds,
  ) async {
    if (invoiceIds.isEmpty) return {};

    try {
      final uniqueInvoiceIds = invoiceIds.toSet().toList(growable: false);
      final orderIdsByInvoice = <int, Set<int>>{
        for (final invoiceId in uniqueInvoiceIds) invoiceId: <int>{},
      };
      for (var offset = 0; offset < uniqueInvoiceIds.length; offset += 500) {
        final end = offset + 500 < uniqueInvoiceIds.length
            ? offset + 500
            : uniqueInvoiceIds.length;
        final chunk = uniqueInvoiceIds.sublist(offset, end);
        final placeholders = List.filled(chunk.length, '?').join(', ');
        final rows = await database.rawQuery(
          'SELECT r.${AppConstants.colInvoiceId}, '
          'r.${AppConstants.colOrderId} '
          '$_validRelationFromClause '
          'WHERE r.${AppConstants.colInvoiceId} IN ($placeholders)',
          chunk,
        );
        for (final row in rows) {
          final invoiceId = row[AppConstants.colInvoiceId] as int;
          final orderId = row[AppConstants.colOrderId] as int;
          orderIdsByInvoice[invoiceId]!.add(orderId);
        }
      }
      return orderIdsByInvoice;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '批量获取发票关联订单失败', e, stackTrace);
      rethrow;
    }
  }

  /// Get all invoice IDs for an order
  Future<List<int>> getInvoiceIdsForOrder(int orderId) async {
    try {
      final List<Map<String, dynamic>> maps = await database.rawQuery(
        '''
        SELECT r.${AppConstants.colInvoiceId}
        $_validRelationFromClause
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

  /// Get invoice IDs for many orders without issuing one query per row.
  Future<Map<int, Set<int>>> getInvoiceIdsForOrders(List<int> orderIds) async {
    if (orderIds.isEmpty) return {};

    try {
      final uniqueOrderIds = orderIds.toSet().toList(growable: false);
      final invoiceIdsByOrder = <int, Set<int>>{
        for (final orderId in uniqueOrderIds) orderId: <int>{},
      };
      for (var offset = 0; offset < uniqueOrderIds.length; offset += 500) {
        final end = offset + 500 < uniqueOrderIds.length
            ? offset + 500
            : uniqueOrderIds.length;
        final chunk = uniqueOrderIds.sublist(offset, end);
        final placeholders = List.filled(chunk.length, '?').join(', ');
        final rows = await database.rawQuery(
          'SELECT r.${AppConstants.colOrderId}, '
          'r.${AppConstants.colInvoiceId} '
          '$_validRelationFromClause '
          'WHERE r.${AppConstants.colOrderId} IN ($placeholders)',
          chunk,
        );
        for (final row in rows) {
          final orderId = row[AppConstants.colOrderId] as int;
          final invoiceId = row[AppConstants.colInvoiceId] as int;
          invoiceIdsByOrder[orderId]!.add(invoiceId);
        }
      }
      return invoiceIdsByOrder;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '批量获取订单关联发票失败', e, stackTrace);
      rethrow;
    }
  }

  /// Get all relations for an invoice
  Future<List<InvoiceOrderRelation>> getRelationsForInvoice(
    int invoiceId,
  ) async {
    try {
      final List<Map<String, dynamic>> maps = await database.rawQuery(
        '''
        SELECT r.*
        $_validRelationFromClause
        WHERE r.${AppConstants.colInvoiceId} = ?
        ''',
        [invoiceId],
      );

      return maps.map((map) => InvoiceOrderRelation.fromJson(map)).toList();
    } catch (e, stackTrace) {
      logService.e(
        LogConfig.moduleDb,
        '获取发票关联列表失败: invoiceId=$invoiceId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get all relations for an order
  Future<List<InvoiceOrderRelation>> getRelationsForOrder(int orderId) async {
    try {
      final List<Map<String, dynamic>> maps = await database.rawQuery(
        '''
        SELECT r.*
        $_validRelationFromClause
        WHERE r.${AppConstants.colOrderId} = ?
        ''',
        [orderId],
      );

      return maps.map((map) => InvoiceOrderRelation.fromJson(map)).toList();
    } catch (e, stackTrace) {
      logService.e(
        LogConfig.moduleDb,
        '获取订单关联列表失败: orderId=$orderId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Check if a relation exists
  Future<bool> relationExists(int invoiceId, int orderId) async {
    try {
      final List<Map<String, dynamic>> maps = await database.rawQuery(
        '''
        SELECT 1
        $_validRelationFromClause
        WHERE r.${AppConstants.colInvoiceId} = ?
          AND r.${AppConstants.colOrderId} = ?
        LIMIT 1
        ''',
        [invoiceId, orderId],
      );

      return maps.isNotEmpty;
    } catch (e, stackTrace) {
      logService.e(
        LogConfig.moduleDb,
        '检查关联是否存在失败: invoiceId=$invoiceId, orderId=$orderId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get count of orders for an invoice
  Future<int> getOrderCountForInvoice(int invoiceId) async {
    try {
      final result = await database.rawQuery(
        'SELECT COUNT(*) as count '
        '$_validRelationFromClause '
        'WHERE r.${AppConstants.colInvoiceId} = ?',
        [invoiceId],
      );

      if (result.isNotEmpty && result.first['count'] != null) {
        return result.first['count'] as int;
      }
      return 0;
    } catch (e, stackTrace) {
      logService.e(
        LogConfig.moduleDb,
        '获取发票关联订单数量失败: invoiceId=$invoiceId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get order counts for multiple invoices.
  Future<Map<int, int>> getOrderCountsForInvoices(List<int> invoiceIds) async {
    if (invoiceIds.isEmpty) return {};

    try {
      final uniqueInvoiceIds = invoiceIds.toSet().toList(growable: false);
      final counts = <int, int>{};
      for (var offset = 0; offset < uniqueInvoiceIds.length; offset += 500) {
        final end = offset + 500 < uniqueInvoiceIds.length
            ? offset + 500
            : uniqueInvoiceIds.length;
        final chunk = uniqueInvoiceIds.sublist(offset, end);
        final placeholders = List.filled(chunk.length, '?').join(', ');
        final result = await database.rawQuery(
          'SELECT r.${AppConstants.colInvoiceId}, COUNT(*) as count '
          '$_validRelationFromClause '
          'WHERE r.${AppConstants.colInvoiceId} IN ($placeholders) '
          'GROUP BY r.${AppConstants.colInvoiceId}',
          chunk,
        );
        for (final row in result) {
          counts[row[AppConstants.colInvoiceId] as int] = row['count'] as int;
        }
      }
      return counts;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '批量获取发票关联订单数量失败', e, stackTrace);
      rethrow;
    }
  }

  /// Get count of invoices for an order
  Future<int> getInvoiceCountForOrder(int orderId) async {
    try {
      final result = await database.rawQuery(
        'SELECT COUNT(*) as count '
        '$_validRelationFromClause '
        'WHERE r.${AppConstants.colOrderId} = ?',
        [orderId],
      );

      if (result.isNotEmpty && result.first['count'] != null) {
        return result.first['count'] as int;
      }
      return 0;
    } catch (e, stackTrace) {
      logService.e(
        LogConfig.moduleDb,
        '获取订单关联发票数量失败: orderId=$orderId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get invoice counts for multiple orders in a single query.
  Future<Map<int, int>> getInvoiceCountsForOrders(List<int> orderIds) async {
    if (orderIds.isEmpty) return {};

    try {
      final uniqueOrderIds = orderIds.toSet().toList(growable: false);
      final counts = <int, int>{};
      for (var offset = 0; offset < uniqueOrderIds.length; offset += 500) {
        final end = offset + 500 < uniqueOrderIds.length
            ? offset + 500
            : uniqueOrderIds.length;
        final chunk = uniqueOrderIds.sublist(offset, end);
        final placeholders = List.filled(chunk.length, '?').join(', ');
        final result = await database.rawQuery(
          'SELECT r.${AppConstants.colOrderId}, COUNT(*) as count '
          '$_validRelationFromClause '
          'WHERE r.${AppConstants.colOrderId} IN ($placeholders) '
          'GROUP BY r.${AppConstants.colOrderId}',
          chunk,
        );
        for (final row in result) {
          counts[row[AppConstants.colOrderId] as int] = row['count'] as int;
        }
      }
      return counts;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '批量获取订单关联发票数量失败', e, stackTrace);
      rethrow;
    }
  }
}

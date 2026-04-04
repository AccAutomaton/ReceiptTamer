import 'package:sqflite/sqflite.dart';

import '../../models/invoice_order_relation.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/log_service.dart';
import '../../../core/services/log_config.dart';

/// Invoice-Order relation table data access object
/// Handles all CRUD operations for the invoice_order_relations table
class InvoiceOrderRelationTable {
  final Database database;

  InvoiceOrderRelationTable({required this.database});

  /// Insert a new relation
  Future<int> insert(InvoiceOrderRelation relation) async {
    try {
      final id = await database.insert(
        AppConstants.invoiceOrderRelationsTable,
        relation.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      logService.i(LogConfig.moduleDb, '关联已插入: invoiceId=${relation.invoiceId}, orderId=${relation.orderId}');
      return id;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '关联插入失败', e, stackTrace);
      rethrow;
    }
  }

  /// Insert multiple relations for an invoice
  Future<void> insertRelationsForInvoice(int invoiceId, List<int> orderIds) async {
    try {
      final batch = database.batch();
      for (final orderId in orderIds) {
        batch.insert(
          AppConstants.invoiceOrderRelationsTable,
          InvoiceOrderRelation(invoiceId: invoiceId, orderId: orderId).toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
      logService.i(LogConfig.moduleDb, '发票关联已插入: invoiceId=$invoiceId, orderCount=${orderIds.length}');
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '批量插入发票关联失败: invoiceId=$invoiceId', e, stackTrace);
      rethrow;
    }
  }

  /// Delete all relations for an invoice
  Future<int> deleteByInvoiceId(int invoiceId) async {
    try {
      final count = await database.delete(
        AppConstants.invoiceOrderRelationsTable,
        where: '${AppConstants.colInvoiceId} = ?',
        whereArgs: [invoiceId],
      );
      logService.i(LogConfig.moduleDb, '发票关联已删除: invoiceId=$invoiceId, count=$count');
      return count;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '删除发票关联失败: invoiceId=$invoiceId', e, stackTrace);
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
      logService.i(LogConfig.moduleDb, '订单关联已删除: orderId=$orderId, count=$count');
      return count;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '删除订单关联失败: orderId=$orderId', e, stackTrace);
      rethrow;
    }
  }

  /// Delete a specific invoice-order relation
  Future<int> deleteRelation(int invoiceId, int orderId) async {
    try {
      final count = await database.delete(
        AppConstants.invoiceOrderRelationsTable,
        where: '${AppConstants.colInvoiceId} = ? AND ${AppConstants.colOrderId} = ?',
        whereArgs: [invoiceId, orderId],
      );
      logService.i(LogConfig.moduleDb, '关联已删除: invoiceId=$invoiceId, orderId=$orderId');
      return count;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '删除特定关联失败: invoiceId=$invoiceId, orderId=$orderId', e, stackTrace);
      rethrow;
    }
  }

  /// Get all order IDs for an invoice
  Future<List<int>> getOrderIdsForInvoice(int invoiceId) async {
    try {
      final List<Map<String, dynamic>> maps = await database.query(
        AppConstants.invoiceOrderRelationsTable,
        where: '${AppConstants.colInvoiceId} = ?',
        whereArgs: [invoiceId],
      );

      return maps.map((map) => map[AppConstants.colOrderId] as int).toList();
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '获取发票关联的订单ID失败: invoiceId=$invoiceId', e, stackTrace);
      rethrow;
    }
  }

  /// Get all invoice IDs for an order
  Future<List<int>> getInvoiceIdsForOrder(int orderId) async {
    try {
      final List<Map<String, dynamic>> maps = await database.query(
        AppConstants.invoiceOrderRelationsTable,
        where: '${AppConstants.colOrderId} = ?',
        whereArgs: [orderId],
      );

      return maps.map((map) => map[AppConstants.colInvoiceId] as int).toList();
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '获取订单关联的发票ID失败: orderId=$orderId', e, stackTrace);
      rethrow;
    }
  }

  /// Get all relations for an invoice
  Future<List<InvoiceOrderRelation>> getRelationsForInvoice(int invoiceId) async {
    try {
      final List<Map<String, dynamic>> maps = await database.query(
        AppConstants.invoiceOrderRelationsTable,
        where: '${AppConstants.colInvoiceId} = ?',
        whereArgs: [invoiceId],
      );

      return maps.map((map) => InvoiceOrderRelation.fromJson(map)).toList();
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '获取发票关联列表失败: invoiceId=$invoiceId', e, stackTrace);
      rethrow;
    }
  }

  /// Get all relations for an order
  Future<List<InvoiceOrderRelation>> getRelationsForOrder(int orderId) async {
    try {
      final List<Map<String, dynamic>> maps = await database.query(
        AppConstants.invoiceOrderRelationsTable,
        where: '${AppConstants.colOrderId} = ?',
        whereArgs: [orderId],
      );

      return maps.map((map) => InvoiceOrderRelation.fromJson(map)).toList();
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '获取订单关联列表失败: orderId=$orderId', e, stackTrace);
      rethrow;
    }
  }

  /// Check if a relation exists
  Future<bool> relationExists(int invoiceId, int orderId) async {
    try {
      final List<Map<String, dynamic>> maps = await database.query(
        AppConstants.invoiceOrderRelationsTable,
        where: '${AppConstants.colInvoiceId} = ? AND ${AppConstants.colOrderId} = ?',
        whereArgs: [invoiceId, orderId],
        limit: 1,
      );

      return maps.isNotEmpty;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '检查关联是否存在失败: invoiceId=$invoiceId, orderId=$orderId', e, stackTrace);
      rethrow;
    }
  }

  /// Get count of orders for an invoice
  Future<int> getOrderCountForInvoice(int invoiceId) async {
    try {
      final result = await database.rawQuery(
        'SELECT COUNT(*) as count FROM ${AppConstants.invoiceOrderRelationsTable} '
        'WHERE ${AppConstants.colInvoiceId} = ?',
        [invoiceId],
      );

      if (result.isNotEmpty && result.first['count'] != null) {
        return result.first['count'] as int;
      }
      return 0;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '获取发票关联订单数量失败: invoiceId=$invoiceId', e, stackTrace);
      rethrow;
    }
  }

  /// Get count of invoices for an order
  Future<int> getInvoiceCountForOrder(int orderId) async {
    try {
      final result = await database.rawQuery(
        'SELECT COUNT(*) as count FROM ${AppConstants.invoiceOrderRelationsTable} '
        'WHERE ${AppConstants.colOrderId} = ?',
        [orderId],
      );

      if (result.isNotEmpty && result.first['count'] != null) {
        return result.first['count'] as int;
      }
      return 0;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleDb, '获取订单关联发票数量失败: orderId=$orderId', e, stackTrace);
      rethrow;
    }
  }
}
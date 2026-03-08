import 'package:sqflite/sqflite.dart';

import '../../models/invoice_order_relation.dart';
import '../../../core/constants/app_constants.dart';

/// Invoice-Order relation table data access object
/// Handles all CRUD operations for the invoice_order_relations table
class InvoiceOrderRelationTable {
  final Database database;

  InvoiceOrderRelationTable({required this.database});

  /// Insert a new relation
  Future<int> insert(InvoiceOrderRelation relation) async {
    return await database.insert(
      AppConstants.invoiceOrderRelationsTable,
      relation.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert multiple relations for an invoice
  Future<void> insertRelationsForInvoice(int invoiceId, List<int> orderIds) async {
    final batch = database.batch();
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
    return await database.delete(
      AppConstants.invoiceOrderRelationsTable,
      where: '${AppConstants.colInvoiceId} = ?',
      whereArgs: [invoiceId],
    );
  }

  /// Delete all relations for an order
  Future<int> deleteByOrderId(int orderId) async {
    return await database.delete(
      AppConstants.invoiceOrderRelationsTable,
      where: '${AppConstants.colOrderId} = ?',
      whereArgs: [orderId],
    );
  }

  /// Get all order IDs for an invoice
  Future<List<int>> getOrderIdsForInvoice(int invoiceId) async {
    final List<Map<String, dynamic>> maps = await database.query(
      AppConstants.invoiceOrderRelationsTable,
      where: '${AppConstants.colInvoiceId} = ?',
      whereArgs: [invoiceId],
    );

    return maps.map((map) => map[AppConstants.colOrderId] as int).toList();
  }

  /// Get all invoice IDs for an order
  Future<List<int>> getInvoiceIdsForOrder(int orderId) async {
    final List<Map<String, dynamic>> maps = await database.query(
      AppConstants.invoiceOrderRelationsTable,
      where: '${AppConstants.colOrderId} = ?',
      whereArgs: [orderId],
    );

    return maps.map((map) => map[AppConstants.colInvoiceId] as int).toList();
  }

  /// Get all relations for an invoice
  Future<List<InvoiceOrderRelation>> getRelationsForInvoice(int invoiceId) async {
    final List<Map<String, dynamic>> maps = await database.query(
      AppConstants.invoiceOrderRelationsTable,
      where: '${AppConstants.colInvoiceId} = ?',
      whereArgs: [invoiceId],
    );

    return maps.map((map) => InvoiceOrderRelation.fromJson(map)).toList();
  }

  /// Get all relations for an order
  Future<List<InvoiceOrderRelation>> getRelationsForOrder(int orderId) async {
    final List<Map<String, dynamic>> maps = await database.query(
      AppConstants.invoiceOrderRelationsTable,
      where: '${AppConstants.colOrderId} = ?',
      whereArgs: [orderId],
    );

    return maps.map((map) => InvoiceOrderRelation.fromJson(map)).toList();
  }

  /// Check if a relation exists
  Future<bool> relationExists(int invoiceId, int orderId) async {
    final List<Map<String, dynamic>> maps = await database.query(
      AppConstants.invoiceOrderRelationsTable,
      where: '${AppConstants.colInvoiceId} = ? AND ${AppConstants.colOrderId} = ?',
      whereArgs: [invoiceId, orderId],
      limit: 1,
    );

    return maps.isNotEmpty;
  }

  /// Get count of orders for an invoice
  Future<int> getOrderCountForInvoice(int invoiceId) async {
    final result = await database.rawQuery(
      'SELECT COUNT(*) as count FROM ${AppConstants.invoiceOrderRelationsTable} '
      'WHERE ${AppConstants.colInvoiceId} = ?',
      [invoiceId],
    );

    if (result.isNotEmpty && result.first['count'] != null) {
      return result.first['count'] as int;
    }
    return 0;
  }

  /// Get count of invoices for an order
  Future<int> getInvoiceCountForOrder(int orderId) async {
    final result = await database.rawQuery(
      'SELECT COUNT(*) as count FROM ${AppConstants.invoiceOrderRelationsTable} '
      'WHERE ${AppConstants.colOrderId} = ?',
      [orderId],
    );

    if (result.isNotEmpty && result.first['count'] != null) {
      return result.first['count'] as int;
    }
    return 0;
  }
}
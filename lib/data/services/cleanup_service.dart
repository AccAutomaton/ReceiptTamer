import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/log_service.dart';
import '../../core/services/log_config.dart';
import '../models/order.dart';
import '../models/invoice.dart';
import '../repositories/order_repository.dart';
import '../repositories/invoice_repository.dart';
import '../datasources/database/database_helper.dart';
import '../datasources/database/invoice_order_relation_table.dart';
import 'image_service.dart';
import 'file_service.dart';

/// Result of a cleanup operation
class CleanupResult {
  final int ordersDeleted;
  final int invoicesDeleted;
  final int filesDeleted;
  final int spaceFreedBytes;
  final Set<int> cascadeOrderIds;
  final Set<int> cascadeInvoiceIds;
  final List<String> undeletedFilePaths;

  CleanupResult({
    this.ordersDeleted = 0,
    this.invoicesDeleted = 0,
    this.filesDeleted = 0,
    this.spaceFreedBytes = 0,
    Set<int>? cascadeOrderIds,
    Set<int>? cascadeInvoiceIds,
    List<String>? undeletedFilePaths,
  }) : cascadeOrderIds = cascadeOrderIds ?? {},
       cascadeInvoiceIds = cascadeInvoiceIds ?? {},
       undeletedFilePaths = List.unmodifiable(undeletedFilePaths ?? const []);

  int get filesFailedToDelete => undeletedFilePaths.length;
}

/// Service for cleaning up data with file deletion
/// Handles deleting orders/invoices with their associated files and relations
class CleanupService {
  final OrderRepository _orderRepository;
  final InvoiceRepository _invoiceRepository;
  final ImageService _imageService;
  final FileService _fileService;
  final DatabaseHelper _dbHelper;
  final InvoiceOrderRelationTable? _injectedRelationTable;
  final Database? _injectedDatabase;

  CleanupService({
    OrderRepository? orderRepository,
    InvoiceRepository? invoiceRepository,
    ImageService? imageService,
    FileService? fileService,
    DatabaseHelper? dbHelper,
    InvoiceOrderRelationTable? relationTable,
    Database? database,
  }) : _orderRepository = orderRepository ?? OrderRepository(),
       _invoiceRepository = invoiceRepository ?? InvoiceRepository(),
       _imageService = imageService ?? ImageService(),
       _fileService = fileService ?? FileService(),
       _dbHelper = dbHelper ?? DatabaseHelper(),
       _injectedRelationTable = relationTable,
       _injectedDatabase = database;

  Future<Database> get _database async {
    final injectedDatabase = _injectedDatabase;
    if (injectedDatabase != null) return injectedDatabase;

    final injectedRelationTable = _injectedRelationTable;
    final relationDatabase = injectedRelationTable?.database;
    if (relationDatabase is Database) return relationDatabase;

    return _dbHelper.database;
  }

  /// Get the invoice-order relation table instance
  Future<InvoiceOrderRelationTable> get _relationTable async {
    final injectedRelationTable = _injectedRelationTable;
    if (injectedRelationTable != null) return injectedRelationTable;

    final db = await _dbHelper.database;
    return InvoiceOrderRelationTable(database: db);
  }

  /// Calculate cascade order IDs when deleting orders with invoices
  /// Returns orders that would lose their invoice due to cascade delete
  Future<Set<int>> calculateCascadeOrders({
    required Set<int> selectedOrderIds,
    bool deleteInvoices = false,
  }) async {
    if (!deleteInvoices) return {};

    Set<int> cascadeOrders = {};
    Set<int> invoicesToDelete = {};

    // Find all invoices linked to selected orders
    final relationTable = await _relationTable;
    for (final orderId in selectedOrderIds) {
      final invoiceIds = await relationTable.getInvoiceIdsForOrder(orderId);
      invoicesToDelete.addAll(invoiceIds);
    }

    // For each invoice to be deleted, find orders not in selection
    for (final invoiceId in invoicesToDelete) {
      final linkedOrderIds = await relationTable.getOrderIdsForInvoice(
        invoiceId,
      );
      for (final linkedOrderId in linkedOrderIds) {
        if (!selectedOrderIds.contains(linkedOrderId)) {
          cascadeOrders.add(linkedOrderId);
        }
      }
    }

    return cascadeOrders;
  }

  /// Calculate cascade invoice IDs when deleting invoices with orders
  /// Returns invoices that would be affected when deleting orders
  Future<Set<int>> calculateCascadeInvoices({
    required Set<int> selectedInvoiceIds,
    bool deleteOrders = false,
  }) async {
    if (!deleteOrders) return {};

    Set<int> cascadeInvoices = {};
    Set<int> ordersToDelete = {};

    // Find all orders linked to selected invoices
    final relationTable = await _relationTable;
    for (final invoiceId in selectedInvoiceIds) {
      final orderIds = await relationTable.getOrderIdsForInvoice(invoiceId);
      ordersToDelete.addAll(orderIds);
    }

    // For each order to be deleted, find invoices not in selection
    for (final orderId in ordersToDelete) {
      final linkedInvoiceIds = await relationTable.getInvoiceIdsForOrder(
        orderId,
      );
      for (final linkedInvoiceId in linkedInvoiceIds) {
        if (!selectedInvoiceIds.contains(linkedInvoiceId)) {
          cascadeInvoices.add(linkedInvoiceId);
        }
      }
    }

    return cascadeInvoices;
  }

  /// Delete orders with their files and optionally related invoices
  Future<CleanupResult> deleteOrders({
    required Set<int> orderIds,
    bool deleteInvoices = false,
  }) async {
    logService.i(
      LogConfig.moduleFile,
      '开始清理订单数据: orderIds=$orderIds, deleteInvoices=$deleteInvoices',
    );

    late final _CommittedCleanup committed;
    try {
      final database = await _database;
      committed = await database.transaction((transaction) async {
        final initialInvoiceIds = deleteInvoices
            ? await _invoiceIdsForOrders(transaction, orderIds)
            : <int>{};
        final cascadeOrders = deleteInvoices
            ? (await _orderIdsForInvoices(
                transaction,
                initialInvoiceIds,
              )).difference(orderIds)
            : <int>{};
        final allOrderIds = {...orderIds, ...cascadeOrders};

        // Preserve the established one-hop behavior: invoices are collected
        // from the direct roots plus the disclosed sibling orders, but no
        // second order cascade is calculated from those invoices.
        final invoicesToDelete = deleteInvoices
            ? await _invoiceIdsForOrders(transaction, allOrderIds)
            : <int>{};
        final attachments = {
          ...await _attachmentPaths(
            transaction,
            AppConstants.ordersTable,
            allOrderIds,
          ),
          ...await _attachmentPaths(
            transaction,
            AppConstants.invoicesTable,
            invoicesToDelete,
          ),
        };

        logService.diag(LogConfig.moduleFile, '级联订单', cascadeOrders.toString());
        logService.diag(
          LogConfig.moduleFile,
          '所有待删除订单',
          allOrderIds.toString(),
        );
        logService.diag(
          LogConfig.moduleFile,
          '待删除发票',
          invoicesToDelete.toString(),
        );

        await _deleteRelations(
          transaction,
          orderIds: allOrderIds,
          invoiceIds: invoicesToDelete,
        );
        final ordersDeleted = await _deleteEntities(
          transaction,
          AppConstants.ordersTable,
          allOrderIds,
        );
        final invoicesDeleted = await _deleteEntities(
          transaction,
          AppConstants.invoicesTable,
          invoicesToDelete,
        );
        final unreferencedAttachments = await _unreferencedAttachmentPaths(
          transaction,
          attachments,
        );

        return _CommittedCleanup(
          ordersDeleted: ordersDeleted,
          invoicesDeleted: invoicesDeleted,
          cascadeOrderIds: cascadeOrders,
          cascadeInvoiceIds: invoicesToDelete,
          attachmentPaths: unreferencedAttachments,
        );
      });
    } catch (error, stackTrace) {
      logService.e(LogConfig.moduleDb, '订单清理事务失败', error, stackTrace);
      rethrow;
    }

    // Attachments are intentionally removed only after SQLite commits. A
    // failed database transaction therefore cannot strand live records with
    // missing files. Post-commit file failures are warnings, not a rollback
    // claim: leaving an unreferenced file is the safe failure mode.
    final fileCleanup = await _deleteAttachments(committed.attachmentPaths);

    logService.i(
      LogConfig.moduleFile,
      '订单清理完成: ordersDeleted=${committed.ordersDeleted}, '
      'invoicesDeleted=${committed.invoicesDeleted}, '
      'filesDeleted=${fileCleanup.filesDeleted}, '
      'filesRetained=${fileCleanup.undeletedFilePaths.length}',
    );

    return CleanupResult(
      ordersDeleted: committed.ordersDeleted,
      invoicesDeleted: committed.invoicesDeleted,
      filesDeleted: fileCleanup.filesDeleted,
      spaceFreedBytes: fileCleanup.spaceFreedBytes,
      cascadeOrderIds: committed.cascadeOrderIds,
      cascadeInvoiceIds: committed.cascadeInvoiceIds,
      undeletedFilePaths: fileCleanup.undeletedFilePaths,
    );
  }

  /// Delete invoices with their files and optionally related orders
  Future<CleanupResult> deleteInvoices({
    required Set<int> invoiceIds,
    bool deleteOrders = false,
  }) async {
    logService.i(
      LogConfig.moduleFile,
      '开始清理发票数据: invoiceIds=$invoiceIds, deleteOrders=$deleteOrders',
    );

    late final _CommittedCleanup committed;
    try {
      final database = await _database;
      committed = await database.transaction((transaction) async {
        final initialOrderIds = deleteOrders
            ? await _orderIdsForInvoices(transaction, invoiceIds)
            : <int>{};
        final cascadeInvoices = deleteOrders
            ? (await _invoiceIdsForOrders(
                transaction,
                initialOrderIds,
              )).difference(invoiceIds)
            : <int>{};
        final allInvoiceIds = {...invoiceIds, ...cascadeInvoices};

        // Match the existing one-hop invoice cascade: all orders attached to
        // the direct and disclosed invoice set are deleted, without expanding
        // to another invoice generation.
        final ordersToDelete = deleteOrders
            ? await _orderIdsForInvoices(transaction, allInvoiceIds)
            : <int>{};
        final attachments = {
          ...await _attachmentPaths(
            transaction,
            AppConstants.invoicesTable,
            allInvoiceIds,
          ),
          ...await _attachmentPaths(
            transaction,
            AppConstants.ordersTable,
            ordersToDelete,
          ),
        };

        await _deleteRelations(
          transaction,
          orderIds: ordersToDelete,
          invoiceIds: allInvoiceIds,
        );
        final invoicesDeleted = await _deleteEntities(
          transaction,
          AppConstants.invoicesTable,
          allInvoiceIds,
        );
        final ordersDeleted = await _deleteEntities(
          transaction,
          AppConstants.ordersTable,
          ordersToDelete,
        );
        final unreferencedAttachments = await _unreferencedAttachmentPaths(
          transaction,
          attachments,
        );

        return _CommittedCleanup(
          ordersDeleted: ordersDeleted,
          invoicesDeleted: invoicesDeleted,
          cascadeOrderIds: ordersToDelete,
          cascadeInvoiceIds: cascadeInvoices,
          attachmentPaths: unreferencedAttachments,
        );
      });
    } catch (error, stackTrace) {
      logService.e(LogConfig.moduleDb, '发票清理事务失败', error, stackTrace);
      rethrow;
    }

    final fileCleanup = await _deleteAttachments(committed.attachmentPaths);

    logService.i(
      LogConfig.moduleFile,
      '发票清理完成: invoicesDeleted=${committed.invoicesDeleted}, '
      'ordersDeleted=${committed.ordersDeleted}, '
      'filesDeleted=${fileCleanup.filesDeleted}, '
      'filesRetained=${fileCleanup.undeletedFilePaths.length}',
    );

    return CleanupResult(
      ordersDeleted: committed.ordersDeleted,
      invoicesDeleted: committed.invoicesDeleted,
      filesDeleted: fileCleanup.filesDeleted,
      spaceFreedBytes: fileCleanup.spaceFreedBytes,
      cascadeOrderIds: committed.cascadeOrderIds,
      cascadeInvoiceIds: committed.cascadeInvoiceIds,
      undeletedFilePaths: fileCleanup.undeletedFilePaths,
    );
  }

  Future<Set<int>> _invoiceIdsForOrders(
    DatabaseExecutor database,
    Set<int> orderIds,
  ) async {
    if (orderIds.isEmpty) return {};

    final invoiceIds = <int>{};
    for (final chunk in _chunks(orderIds)) {
      final placeholders = List.filled(chunk.length, '?').join(', ');
      final rows = await database.rawQuery('''
        SELECT DISTINCT r.${AppConstants.colInvoiceId}
        FROM ${AppConstants.invoiceOrderRelationsTable} r
        INNER JOIN ${AppConstants.invoicesTable} i
          ON i.${AppConstants.colId} = r.${AppConstants.colInvoiceId}
        INNER JOIN ${AppConstants.ordersTable} o
          ON o.${AppConstants.colId} = r.${AppConstants.colOrderId}
        WHERE r.${AppConstants.colOrderId} IN ($placeholders)
        ''', chunk);
      invoiceIds.addAll(
        rows.map((row) => row[AppConstants.colInvoiceId] as int),
      );
    }
    return invoiceIds;
  }

  Future<Set<int>> _orderIdsForInvoices(
    DatabaseExecutor database,
    Set<int> invoiceIds,
  ) async {
    if (invoiceIds.isEmpty) return {};

    final orderIds = <int>{};
    for (final chunk in _chunks(invoiceIds)) {
      final placeholders = List.filled(chunk.length, '?').join(', ');
      final rows = await database.rawQuery('''
        SELECT DISTINCT r.${AppConstants.colOrderId}
        FROM ${AppConstants.invoiceOrderRelationsTable} r
        INNER JOIN ${AppConstants.invoicesTable} i
          ON i.${AppConstants.colId} = r.${AppConstants.colInvoiceId}
        INNER JOIN ${AppConstants.ordersTable} o
          ON o.${AppConstants.colId} = r.${AppConstants.colOrderId}
        WHERE r.${AppConstants.colInvoiceId} IN ($placeholders)
        ''', chunk);
      orderIds.addAll(rows.map((row) => row[AppConstants.colOrderId] as int));
    }
    return orderIds;
  }

  Future<Set<String>> _attachmentPaths(
    DatabaseExecutor database,
    String table,
    Set<int> ids,
  ) async {
    if (ids.isEmpty) return {};

    final paths = <String>{};
    for (final chunk in _chunks(ids)) {
      final placeholders = List.filled(chunk.length, '?').join(', ');
      final rows = await database.query(
        table,
        columns: [AppConstants.colImagePath],
        where: '${AppConstants.colId} IN ($placeholders)',
        whereArgs: chunk,
      );
      for (final row in rows) {
        final path = row[AppConstants.colImagePath] as String?;
        if (path != null && path.trim().isNotEmpty) paths.add(path);
      }
    }
    return paths;
  }

  Future<Set<String>> _unreferencedAttachmentPaths(
    DatabaseExecutor database,
    Set<String> candidates,
  ) async {
    if (candidates.isEmpty) return {};

    final referenced = <String>{};
    for (final chunk in _chunks(candidates)) {
      final placeholders = List.filled(chunk.length, '?').join(', ');
      for (final table in [
        AppConstants.ordersTable,
        AppConstants.invoicesTable,
      ]) {
        final rows = await database.query(
          table,
          columns: [AppConstants.colImagePath],
          where: '${AppConstants.colImagePath} IN ($placeholders)',
          whereArgs: chunk,
        );
        referenced.addAll(
          rows.map((row) => row[AppConstants.colImagePath] as String),
        );
      }
    }
    return candidates.difference(referenced);
  }

  Future<void> _deleteRelations(
    DatabaseExecutor database, {
    required Set<int> orderIds,
    required Set<int> invoiceIds,
  }) async {
    await _deleteWhereIds(
      database,
      AppConstants.invoiceOrderRelationsTable,
      AppConstants.colOrderId,
      orderIds,
    );
    await _deleteWhereIds(
      database,
      AppConstants.invoiceOrderRelationsTable,
      AppConstants.colInvoiceId,
      invoiceIds,
    );
  }

  Future<int> _deleteEntities(
    DatabaseExecutor database,
    String table,
    Set<int> ids,
  ) {
    return _deleteWhereIds(database, table, AppConstants.colId, ids);
  }

  Future<int> _deleteWhereIds(
    DatabaseExecutor database,
    String table,
    String column,
    Set<int> ids,
  ) async {
    var deleted = 0;
    for (final chunk in _chunks(ids)) {
      final placeholders = List.filled(chunk.length, '?').join(', ');
      deleted += await database.delete(
        table,
        where: '$column IN ($placeholders)',
        whereArgs: chunk,
      );
    }
    return deleted;
  }

  Iterable<List<T>> _chunks<T>(Iterable<T> items) sync* {
    final values = items.toList(growable: false);
    for (var offset = 0; offset < values.length; offset += 500) {
      final end = offset + 500 < values.length ? offset + 500 : values.length;
      yield values.sublist(offset, end);
    }
  }

  Future<_FileCleanup> _deleteAttachments(Set<String> paths) async {
    var filesDeleted = 0;
    var spaceFreedBytes = 0;
    final undeletedFilePaths = <String>[];

    for (final path in paths) {
      var size = 0;
      try {
        size = await _getFileSize(path);
      } catch (error) {
        logService.w(LogConfig.moduleFile, '读取待删附件大小失败: $path, error=$error');
      }

      try {
        final deleted = await _deleteInvoiceFile(path);
        if (deleted) {
          filesDeleted++;
          spaceFreedBytes += size;
          logService.i(LogConfig.moduleFile, '清理附件已删除: $path');
        } else {
          undeletedFilePaths.add(path);
          logService.w(LogConfig.moduleFile, '清理附件删除失败，已保留孤儿文件: $path');
        }
      } catch (error, stackTrace) {
        undeletedFilePaths.add(path);
        logService.e(
          LogConfig.moduleFile,
          '清理附件删除异常，已保留孤儿文件: $path',
          error,
          stackTrace,
        );
      }
    }

    return _FileCleanup(
      filesDeleted: filesDeleted,
      spaceFreedBytes: spaceFreedBytes,
      undeletedFilePaths: undeletedFilePaths,
    );
  }

  /// Delete invoice file (image or PDF)
  Future<bool> _deleteInvoiceFile(String filePath) async {
    if (_imageService.isPdfPath(filePath)) {
      return await _fileService.deleteFile(filePath);
    } else {
      return await _imageService.deleteImage(filePath);
    }
  }

  /// Get file size for any file type
  Future<int> _getFileSize(String filePath) async {
    if (_imageService.isPdfPath(filePath)) {
      return await _fileService.getFileSize(filePath);
    } else {
      return await _imageService.getImageSize(filePath);
    }
  }

  /// Get related invoice IDs for an order
  Future<List<int>> getInvoiceIdsForOrder(int orderId) async {
    final relationTable = await _relationTable;
    return await relationTable.getInvoiceIdsForOrder(orderId);
  }

  /// Get related order IDs for an invoice
  Future<List<int>> getOrderIdsForInvoice(int invoiceId) async {
    final relationTable = await _relationTable;
    return await relationTable.getOrderIdsForInvoice(invoiceId);
  }

  /// Get order with its invoice relation info
  Future<Order?> getOrderById(int orderId) async {
    return await _orderRepository.getById(orderId);
  }

  /// Get invoice with its order relation info
  Future<Invoice?> getInvoiceById(int invoiceId) async {
    return await _invoiceRepository.getById(invoiceId);
  }
}

class _CommittedCleanup {
  const _CommittedCleanup({
    required this.ordersDeleted,
    required this.invoicesDeleted,
    required this.cascadeOrderIds,
    required this.cascadeInvoiceIds,
    required this.attachmentPaths,
  });

  final int ordersDeleted;
  final int invoicesDeleted;
  final Set<int> cascadeOrderIds;
  final Set<int> cascadeInvoiceIds;
  final Set<String> attachmentPaths;
}

class _FileCleanup {
  const _FileCleanup({
    required this.filesDeleted,
    required this.spaceFreedBytes,
    required this.undeletedFilePaths,
  });

  final int filesDeleted;
  final int spaceFreedBytes;
  final List<String> undeletedFilePaths;
}

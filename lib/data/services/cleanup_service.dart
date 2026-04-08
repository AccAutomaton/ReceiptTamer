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

  CleanupResult({
    this.ordersDeleted = 0,
    this.invoicesDeleted = 0,
    this.filesDeleted = 0,
    this.spaceFreedBytes = 0,
    Set<int>? cascadeOrderIds,
    Set<int>? cascadeInvoiceIds,
  })  : cascadeOrderIds = cascadeOrderIds ?? {},
        cascadeInvoiceIds = cascadeInvoiceIds ?? {};
}

/// Service for cleaning up data with file deletion
/// Handles deleting orders/invoices with their associated files and relations
class CleanupService {
  final OrderRepository _orderRepository;
  final InvoiceRepository _invoiceRepository;
  final ImageService _imageService;
  final FileService _fileService;
  final DatabaseHelper _dbHelper;

  CleanupService({
    OrderRepository? orderRepository,
    InvoiceRepository? invoiceRepository,
    ImageService? imageService,
    FileService? fileService,
    DatabaseHelper? dbHelper,
  })  : _orderRepository = orderRepository ?? OrderRepository(),
        _invoiceRepository = invoiceRepository ?? InvoiceRepository(),
        _imageService = imageService ?? ImageService(),
        _fileService = fileService ?? FileService(),
        _dbHelper = dbHelper ?? DatabaseHelper();

  /// Get the invoice-order relation table instance
  Future<InvoiceOrderRelationTable> get _relationTable async {
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
      final linkedOrderIds = await relationTable.getOrderIdsForInvoice(invoiceId);
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
      final linkedInvoiceIds = await relationTable.getInvoiceIdsForOrder(orderId);
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
    logService.i(LogConfig.moduleFile, '开始清理订单数据: orderIds=$orderIds, deleteInvoices=$deleteInvoices');

    int filesDeleted = 0;
    int spaceFreed = 0;
    Set<int> invoicesToDelete = {};

    // Step 1: Calculate cascade orders
    final cascadeOrders = await calculateCascadeOrders(
      selectedOrderIds: orderIds,
      deleteInvoices: deleteInvoices,
    );
    final allOrderIds = {...orderIds, ...cascadeOrders};
    logService.diag(LogConfig.moduleFile, '级联订单', cascadeOrders.toString());
    logService.diag(LogConfig.moduleFile, '所有待删除订单', allOrderIds.toString());

    // Step 2: Collect invoice IDs to delete
    if (deleteInvoices) {
      final relationTable = await _relationTable;
      for (final orderId in allOrderIds) {
        final invoiceIds = await relationTable.getInvoiceIdsForOrder(orderId);
        logService.diag(LogConfig.moduleFile, '订单$orderId关联的发票', invoiceIds.toString());
        invoicesToDelete.addAll(invoiceIds);
      }
      logService.diag(LogConfig.moduleFile, '待删除发票', invoicesToDelete.toString());
    }

    // Step 3: Delete order image files
    for (final orderId in allOrderIds) {
      final order = await _orderRepository.getById(orderId);
      logService.diag(LogConfig.moduleFile, '查询订单$orderId', order != null ? 'imagePath=${order.imagePath}' : 'null');
      if (order != null && order.imagePath.isNotEmpty) {
        logService.diag(LogConfig.moduleFile, '准备删除订单图片', order.imagePath);
        final size = await _imageService.getImageSize(order.imagePath);
        logService.diag(LogConfig.moduleFile, '图片大小', '$size bytes');
        final deleted = await _imageService.deleteImage(order.imagePath);
        logService.diag(LogConfig.moduleFile, '删除结果', deleted.toString());
        if (deleted) {
          filesDeleted++;
          spaceFreed += size;
          logService.i(LogConfig.moduleFile, '订单图片已删除: ${order.imagePath}');
        } else {
          logService.w(LogConfig.moduleFile, '订单图片删除失败: ${order.imagePath}');
        }
      }
    }

    // Step 4: Delete invoice files if cascade
    for (final invoiceId in invoicesToDelete) {
      final invoice = await _invoiceRepository.getById(invoiceId);
      logService.diag(LogConfig.moduleFile, '查询发票$invoiceId', invoice != null ? 'imagePath=${invoice.imagePath}' : 'null');
      if (invoice != null && invoice.imagePath.isNotEmpty) {
        final size = await _getFileSize(invoice.imagePath);
        if (await _deleteInvoiceFile(invoice.imagePath)) {
          filesDeleted++;
          spaceFreed += size;
          logService.i(LogConfig.moduleFile, '发票文件已删除: ${invoice.imagePath}');
        }
      }
    }

    // Step 5: Delete database records
    int ordersDeleted = 0;
    int invoicesDeleted = 0;

    // Delete orders (cascade will handle relations)
    for (final orderId in allOrderIds) {
      final count = await _orderRepository.delete(orderId);
      ordersDeleted += count;
    }

    // Delete invoices if cascade
    for (final invoiceId in invoicesToDelete) {
      final count = await _invoiceRepository.delete(invoiceId);
      invoicesDeleted += count;
    }

    logService.i(LogConfig.moduleFile, '订单清理完成: ordersDeleted=$ordersDeleted, invoicesDeleted=$invoicesDeleted, filesDeleted=$filesDeleted');

    return CleanupResult(
      ordersDeleted: ordersDeleted,
      invoicesDeleted: invoicesDeleted,
      filesDeleted: filesDeleted,
      spaceFreedBytes: spaceFreed,
      cascadeOrderIds: cascadeOrders,
      cascadeInvoiceIds: invoicesToDelete,
    );
  }

  /// Delete invoices with their files and optionally related orders
  Future<CleanupResult> deleteInvoices({
    required Set<int> invoiceIds,
    bool deleteOrders = false,
  }) async {
    logService.i(LogConfig.moduleFile, '开始清理发票数据: invoiceIds=$invoiceIds, deleteOrders=$deleteOrders');

    int filesDeleted = 0;
    int spaceFreed = 0;
    Set<int> ordersToDelete = {};

    // Step 1: Calculate cascade invoices (invoices that would lose their orders)
    final cascadeInvoices = await calculateCascadeInvoices(
      selectedInvoiceIds: invoiceIds,
      deleteOrders: deleteOrders,
    );
    final allInvoiceIds = {...invoiceIds, ...cascadeInvoices};

    // Step 2: Collect order IDs to delete
    if (deleteOrders) {
      final relationTable = await _relationTable;
      for (final invoiceId in allInvoiceIds) {
        final orderIds = await relationTable.getOrderIdsForInvoice(invoiceId);
        ordersToDelete.addAll(orderIds);
      }
    }

    // Step 3: Delete invoice files
    for (final invoiceId in allInvoiceIds) {
      final invoice = await _invoiceRepository.getById(invoiceId);
      if (invoice != null && invoice.imagePath.isNotEmpty) {
        final size = await _getFileSize(invoice.imagePath);
        if (await _deleteInvoiceFile(invoice.imagePath)) {
          filesDeleted++;
          spaceFreed += size;
          logService.i(LogConfig.moduleFile, '发票文件已删除: ${invoice.imagePath}');
        }
      }
    }

    // Step 4: Delete order image files if cascade
    for (final orderId in ordersToDelete) {
      final order = await _orderRepository.getById(orderId);
      if (order != null && order.imagePath.isNotEmpty) {
        final size = await _imageService.getImageSize(order.imagePath);
        if (await _imageService.deleteImage(order.imagePath)) {
          filesDeleted++;
          spaceFreed += size;
          logService.i(LogConfig.moduleFile, '订单图片已删除: ${order.imagePath}');
        }
      }
    }

    // Step 5: Delete database records
    int invoicesDeleted = 0;
    int ordersDeleted = 0;

    // Delete invoices (cascade will handle relations)
    for (final invoiceId in allInvoiceIds) {
      final count = await _invoiceRepository.delete(invoiceId);
      invoicesDeleted += count;
    }

    // Delete orders if cascade
    for (final orderId in ordersToDelete) {
      final count = await _orderRepository.delete(orderId);
      ordersDeleted += count;
    }

    logService.i(LogConfig.moduleFile, '发票清理完成: invoicesDeleted=$invoicesDeleted, ordersDeleted=$ordersDeleted, filesDeleted=$filesDeleted');

    return CleanupResult(
      ordersDeleted: ordersDeleted,
      invoicesDeleted: invoicesDeleted,
      filesDeleted: filesDeleted,
      spaceFreedBytes: spaceFreed,
      cascadeOrderIds: ordersToDelete,
      cascadeInvoiceIds: cascadeInvoices,
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
import '../datasources/database/database_helper.dart';
import '../datasources/database/invoice_table.dart';
import '../datasources/database/invoice_order_relation_table.dart';
import '../models/invoice.dart';

/// Invoice repository
/// Provides data access methods for invoices using the invoice table
/// Order relationships are managed through InvoiceOrderRelationTable
class InvoiceRepository {
  InvoiceRepository() : _dbHelper = DatabaseHelper();

  final DatabaseHelper _dbHelper;

  /// Get the invoice table instance
  Future<InvoiceTable> get _invoiceTable async {
    final db = await _dbHelper.database;
    return InvoiceTable(database: db);
  }

  /// Get the invoice-order relation table instance
  Future<InvoiceOrderRelationTable> get _relationTable async {
    final db = await _dbHelper.database;
    return InvoiceOrderRelationTable(database: db);
  }

  /// Create a new invoice with optional order relations
  Future<int> create(Invoice invoice, {List<int>? orderIds}) async {
    final table = await _invoiceTable;
    final id = await table.insert(invoice);

    // Create order relations if provided
    if (orderIds != null && orderIds.isNotEmpty) {
      final relationTable = await _relationTable;
      await relationTable.insertRelationsForInvoice(id, orderIds);
    }

    return id;
  }

  /// Update an existing invoice and its order relations
  Future<int> update(Invoice invoice, {List<int>? orderIds}) async {
    final table = await _invoiceTable;

    // Update order relations if provided
    if (orderIds != null && invoice.id != null) {
      final relationTable = await _relationTable;
      // Delete existing relations
      await relationTable.deleteByInvoiceId(invoice.id!);
      // Insert new relations
      if (orderIds.isNotEmpty) {
        await relationTable.insertRelationsForInvoice(invoice.id!, orderIds);
      }
    }

    return await table.update(invoice.copyWith(
      updatedAt: DateTime.now().toIso8601String(),
    ));
  }

  /// Delete an invoice by ID
  Future<int> delete(int id) async {
    // Relations will be deleted automatically by CASCADE
    final table = await _invoiceTable;
    return await table.delete(id);
  }

  /// Delete all invoices
  Future<int> deleteAll() async {
    final table = await _invoiceTable;
    return await table.deleteAll();
  }

  /// Get an invoice by ID
  Future<Invoice?> getById(int id) async {
    final table = await _invoiceTable;
    return await table.getById(id);
  }

  /// Get all invoices
  Future<List<Invoice>> getAll({int? limit, int? offset}) async {
    final table = await _invoiceTable;
    return await table.getAll(limit: limit, offset: offset);
  }

  /// Get invoices by order ID
  Future<List<Invoice>> getByOrderId(int orderId) async {
    final table = await _invoiceTable;
    return await table.getByOrderId(orderId);
  }

  /// Get invoices by invoice number (exact match)
  Future<List<Invoice>> getByInvoiceNumber(String invoiceNumber) async {
    final table = await _invoiceTable;
    return await table.getByInvoiceNumber(invoiceNumber);
  }

  /// Get invoices by invoice number (partial match)
  Future<List<Invoice>> searchByInvoiceNumber(String invoiceNumber) async {
    final table = await _invoiceTable;
    return await table.searchByInvoiceNumber(invoiceNumber);
  }

  /// Get invoices by date range
  Future<List<Invoice>> getByDateRange(DateTime start, DateTime end) async {
    final table = await _invoiceTable;
    return await table.getByDateRange(start, end);
  }

  /// Get invoices created today
  Future<List<Invoice>> getTodayInvoices() async {
    final table = await _invoiceTable;
    return await table.getTodayInvoices();
  }

  /// Get invoices created this month
  Future<List<Invoice>> getThisMonthInvoices() async {
    final table = await _invoiceTable;
    return await table.getThisMonthInvoices();
  }

  /// Get invoices without linked orders
  Future<List<Invoice>> getWithoutOrders() async {
    final table = await _invoiceTable;
    return await table.getWithoutOrders();
  }

  /// Get the total amount of all invoices
  Future<double> getTotalAmount() async {
    final table = await _invoiceTable;
    return await table.getTotalAmount();
  }

  /// Get the total amount for a date range
  Future<double> getTotalAmountByDateRange(DateTime start, DateTime end) async {
    final table = await _invoiceTable;
    return await table.getTotalAmountByDateRange(start, end);
  }

  /// Get invoice count
  Future<int> getCount() async {
    final table = await _invoiceTable;
    return await table.getCount();
  }

  /// Get invoice count by order ID
  Future<int> getCountByOrderId(int orderId) async {
    final table = await _invoiceTable;
    return await table.getCountByOrderId(orderId);
  }

  /// Search invoices by multiple criteria
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
    final table = await _invoiceTable;
    return await table.search(
      invoiceNumber: invoiceNumber,
      sellerName: sellerName,
      orderId: orderId,
      minAmount: minAmount,
      maxAmount: maxAmount,
      startDate: startDate,
      endDate: endDate,
      hasLinkedOrder: hasLinkedOrder,
    );
  }

  /// Get invoices with their related order information (JOIN query)
  Future<List<Map<String, dynamic>>> getWithOrderInfo() async {
    final table = await _invoiceTable;
    return await table.getWithOrderInfo();
  }

  /// Get order IDs for an invoice
  Future<List<int>> getOrderIdsForInvoice(int invoiceId) async {
    final relationTable = await _relationTable;
    return await relationTable.getOrderIdsForInvoice(invoiceId);
  }

  /// Update order relations for an invoice
  Future<void> updateOrderRelations(int invoiceId, List<int> orderIds) async {
    final relationTable = await _relationTable;
    await relationTable.deleteByInvoiceId(invoiceId);
    if (orderIds.isNotEmpty) {
      await relationTable.insertRelationsForInvoice(invoiceId, orderIds);
    }
  }

  /// Close database connection
  Future<void> close() async {
    await _dbHelper.close();
  }
}

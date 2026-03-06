import '../datasources/database/database_helper.dart';
import '../datasources/database/invoice_table.dart';
import '../models/invoice.dart';

/// Invoice repository
/// Provides data access methods for invoices using the invoice table
class InvoiceRepository {
  InvoiceRepository() : _dbHelper = DatabaseHelper();

  final DatabaseHelper _dbHelper;

  /// Get the invoice table instance
  Future<InvoiceTable> get _invoiceTable async {
    final db = await _dbHelper.database;
    return InvoiceTable(database: db);
  }

  /// Create a new invoice
  Future<int> create(Invoice invoice) async {
    final table = await _invoiceTable;
    return await table.insert(invoice);
  }

  /// Update an existing invoice
  Future<int> update(Invoice invoice) async {
    final table = await _invoiceTable;
    return await table.update(invoice.copyWith(
      updatedAt: DateTime.now().toIso8601String(),
    ));
  }

  /// Delete an invoice by ID
  Future<int> delete(int id) async {
    final table = await _invoiceTable;
    return await table.delete(id);
  }

  /// Delete all invoices
  Future<int> deleteAll() async {
    final table = await _invoiceTable;
    return await table.deleteAll();
  }

  /// Delete invoices by order ID
  Future<int> deleteByOrderId(int orderId) async {
    final table = await _invoiceTable;
    return await table.deleteByOrderId(orderId);
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

  /// Close database connection
  Future<void> close() async {
    await _dbHelper.close();
  }
}

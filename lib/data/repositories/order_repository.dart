import '../datasources/database/database_helper.dart';
import '../datasources/database/order_table.dart';
import '../models/order.dart';

/// Order repository
/// Provides data access methods for orders using the order table
class OrderRepository {
  OrderRepository() : _dbHelper = DatabaseHelper();

  final DatabaseHelper _dbHelper;

  /// Get the order table instance
  Future<OrderTable> get _orderTable async {
    final db = await _dbHelper.database;
    return OrderTable(database: db);
  }

  /// Create a new order
  Future<int> create(Order order) async {
    final table = await _orderTable;
    return await table.insert(order);
  }

  /// Update an existing order
  Future<int> update(Order order) async {
    final table = await _orderTable;
    return await table.update(order.copyWith(
      updatedAt: DateTime.now().toIso8601String(),
    ));
  }

  /// Delete an order by ID
  Future<int> delete(int id) async {
    final table = await _orderTable;
    return await table.delete(id);
  }

  /// Delete all orders
  Future<int> deleteAll() async {
    final table = await _orderTable;
    return await table.deleteAll();
  }

  /// Get an order by ID
  Future<Order?> getById(int id) async {
    final table = await _orderTable;
    return await table.getById(id);
  }

  /// Get all orders
  Future<List<Order>> getAll({int? limit, int? offset}) async {
    final table = await _orderTable;
    return await table.getAll(limit: limit, offset: offset);
  }

  /// Get orders by shop name (partial match)
  Future<List<Order>> getByShopName(String shopName) async {
    final table = await _orderTable;
    return await table.getByShopName(shopName);
  }

  /// Get orders by order number (exact match)
  Future<List<Order>> getByOrderNumber(String orderNumber) async {
    final table = await _orderTable;
    return await table.getByOrderNumber(orderNumber);
  }

  /// Get orders by date range
  Future<List<Order>> getByDateRange(DateTime start, DateTime end) async {
    final table = await _orderTable;
    return await table.getByDateRange(start, end);
  }

  /// Get orders created today
  Future<List<Order>> getTodayOrders() async {
    final table = await _orderTable;
    return await table.getTodayOrders();
  }

  /// Get orders created this month
  Future<List<Order>> getThisMonthOrders() async {
    final table = await _orderTable;
    return await table.getThisMonthOrders();
  }

  /// Get the total amount of all orders
  Future<double> getTotalAmount() async {
    final table = await _orderTable;
    return await table.getTotalAmount();
  }

  /// Get the total amount for a date range
  Future<double> getTotalAmountByDateRange(DateTime start, DateTime end) async {
    final table = await _orderTable;
    return await table.getTotalAmountByDateRange(start, end);
  }

  /// Get order count
  Future<int> getCount() async {
    final table = await _orderTable;
    return await table.getCount();
  }

  /// Get orders without linked invoices
  Future<List<Order>> getWithoutInvoices() async {
    final table = await _orderTable;
    return await table.getWithoutInvoices();
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
    final table = await _orderTable;
    return await table.search(
      shopName: shopName,
      orderNumber: orderNumber,
      minAmount: minAmount,
      maxAmount: maxAmount,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Close database connection
  Future<void> close() async {
    await _dbHelper.close();
  }
}

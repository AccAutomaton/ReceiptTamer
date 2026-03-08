import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';

/// Order state
class OrderState {
  final List<Order> orders;
  final bool isLoading;
  final String? errorMessage;
  final bool hasMore;
  final int currentPage;

  const OrderState({
    this.orders = const [],
    this.isLoading = false,
    this.errorMessage,
    this.hasMore = true,
    this.currentPage = 0,
  });

  OrderState copyWith({
    List<Order>? orders,
    bool? isLoading,
    String? errorMessage,
    bool? hasMore,
    int? currentPage,
  }) {
    return OrderState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

/// Order state notifier (Riverpod 3.x Notifier)
class OrderNotifier extends Notifier<OrderState> {
  @override
  OrderState build() {
    return const OrderState();
  }

  OrderRepository get _repository => ref.watch(orderRepositoryProvider);

  /// Load all orders
  Future<void> loadOrders({bool refresh = false}) async {
    if (refresh) {
      state = state.copyWith(
        isLoading: true,
        errorMessage: null,
        currentPage: 0,
      );
    } else {
      state = state.copyWith(isLoading: true);
    }

    try {
      final orders = await _repository.getAll();
      state = state.copyWith(
        orders: orders,
        isLoading: false,
        hasMore: false,
        currentPage: 0,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Load more orders (pagination)
  Future<void> loadMoreOrders() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);

    try {
      final offset = (state.currentPage + 1) * 20; // Page size
      final orders = await _repository.getAll(limit: 20, offset: offset);

      state = state.copyWith(
        orders: [...state.orders, ...orders],
        isLoading: false,
        hasMore: orders.length == 20,
        currentPage: state.currentPage + 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Get a specific order by ID
  Future<Order?> getOrderById(int id) async {
    try {
      return await _repository.getById(id);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return null;
    }
  }

  /// Create a new order
  Future<bool> createOrder(Order order) async {
    state = state.copyWith(isLoading: true);

    try {
      final id = await _repository.create(order);
      await loadOrders();
      return id > 0;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// Update an existing order
  Future<bool> updateOrder(Order order) async {
    state = state.copyWith(isLoading: true);

    try {
      final rowsAffected = await _repository.update(order);
      if (rowsAffected > 0) {
        // Update the order in the list
        final updatedOrders = state.orders.map((o) {
          return o.id == order.id ? order : o;
        }).toList();
        state = state.copyWith(orders: updatedOrders, isLoading: false);
        return true;
      }
      state = state.copyWith(isLoading: false);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// Delete an order
  Future<bool> deleteOrder(int id) async {
    state = state.copyWith(isLoading: true);

    try {
      final rowsAffected = await _repository.delete(id);
      if (rowsAffected > 0) {
        final updatedOrders = state.orders.where((o) => o.id != id).toList();
        state = state.copyWith(orders: updatedOrders, isLoading: false);
        return true;
      }
      state = state.copyWith(isLoading: false);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// Search orders
  Future<void> searchOrders({
    String? shopName,
    String? orderNumber,
    double? minAmount,
    double? maxAmount,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    state = state.copyWith(isLoading: true);

    try {
      final orders = await _repository.search(
        shopName: shopName,
        orderNumber: orderNumber,
        minAmount: minAmount,
        maxAmount: maxAmount,
        startDate: startDate,
        endDate: endDate,
      );

      state = state.copyWith(
        orders: orders,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Get today's orders
  Future<void> loadTodayOrders() async {
    state = state.copyWith(isLoading: true);

    try {
      final orders = await _repository.getTodayOrders();
      state = state.copyWith(
        orders: orders,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Get this month's orders
  Future<void> loadThisMonthOrders() async {
    state = state.copyWith(isLoading: true);

    try {
      final orders = await _repository.getThisMonthOrders();
      state = state.copyWith(
        orders: orders,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Get total amount
  Future<double> getTotalAmount() async {
    try {
      return await _repository.getTotalAmount();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return 0.0;
    }
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  // Direct repository access methods for export functionality
  Future<List<Order>> getAll() async {
    return await _repository.getAll();
  }

  Future<List<Order>> getAllForExport() async {
    return await _repository.getAll();
  }

  Future<List<Order>> getByDateRangeForExport(DateTime start, DateTime end) async {
    return await _repository.getByDateRange(start, end);
  }

  /// Search orders with invoice relation filter
  /// Used by the order selector for invoices
  Future<List<Order>> searchOrdersWithInvoiceRelation({
    String? keyword,
    double? minAmount,
    double? maxAmount,
    DateTime? startDate,
    DateTime? endDate,
    bool? hasInvoice,
    int? excludeInvoiceId,
  }) async {
    try {
      return await _repository.searchWithInvoiceRelation(
        keyword: keyword,
        minAmount: minAmount,
        maxAmount: maxAmount,
        startDate: startDate,
        endDate: endDate,
        hasInvoice: hasInvoice,
        excludeInvoiceId: excludeInvoiceId,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return [];
    }
  }

  /// Get orders with their invoice relation info
  Future<List<Map<String, dynamic>>> getOrdersWithInvoiceInfo({
    int? excludeInvoiceId,
  }) async {
    try {
      return await _repository.getOrdersWithInvoiceInfo(excludeInvoiceId: excludeInvoiceId);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return [];
    }
  }

  /// Get invoice IDs linked to a specific order
  Future<List<int>> getInvoiceIdsForOrder(int orderId) async {
    try {
      return await _repository.getInvoiceIdsForOrder(orderId);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return [];
    }
  }
}

/// Provider for OrderRepository
final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository();
});

/// Provider for OrderNotifier
final orderProvider = NotifierProvider<OrderNotifier, OrderState>(() {
  return OrderNotifier();
});

/// Provider for a specific order by ID
final orderByIdProvider = FutureProvider.family<Order?, int>((ref, id) async {
  final repository = ref.watch(orderRepositoryProvider);
  return await repository.getById(id);
});

/// Provider for today's order count
final todayOrderCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(orderRepositoryProvider);
  final orders = await repository.getTodayOrders();
  return orders.length;
});

/// Provider for total order amount
final totalOrderAmountProvider = FutureProvider<double>((ref) async {
  final repository = ref.watch(orderRepositoryProvider);
  return await repository.getTotalAmount();
});

/// Provider for order count
final orderCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(orderRepositoryProvider);
  return await repository.getCount();
});
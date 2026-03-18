import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/invoice.dart';
import '../../data/repositories/invoice_repository.dart';

/// Invoice state
class InvoiceState {
  final List<Invoice> invoices;
  final bool isLoading;
  final String? errorMessage;
  final bool hasMore;
  final int currentPage;
  final int? filterOrderId;

  const InvoiceState({
    this.invoices = const [],
    this.isLoading = false,
    this.errorMessage,
    this.hasMore = true,
    this.currentPage = 0,
    this.filterOrderId,
  });

  InvoiceState copyWith({
    List<Invoice>? invoices,
    bool? isLoading,
    String? errorMessage,
    bool? hasMore,
    int? currentPage,
    int? filterOrderId,
  }) {
    return InvoiceState(
      invoices: invoices ?? this.invoices,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      filterOrderId: filterOrderId ?? this.filterOrderId,
    );
  }
}

/// Invoice state notifier (Riverpod 3.x Notifier)
class InvoiceNotifier extends Notifier<InvoiceState> {
  @override
  InvoiceState build() {
    return const InvoiceState();
  }

  InvoiceRepository get _repository => ref.watch(invoiceRepositoryProvider);

  /// Load all invoices
  Future<void> loadInvoices({bool refresh = false, int? filterOrderId}) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      filterOrderId: filterOrderId,
      currentPage: 0,
    );

    try {
      List<Invoice> invoices;

      if (filterOrderId != null) {
        invoices = await _repository.getByOrderId(filterOrderId);
      } else {
        invoices = await _repository.getAll();
      }

      state = state.copyWith(
        invoices: invoices,
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

  /// Load more invoices (pagination)
  Future<void> loadMoreInvoices() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);

    try {
      final offset = (state.currentPage + 1) * 20; // Page size
      final invoices = await _repository.getAll(limit: 20, offset: offset);

      state = state.copyWith(
        invoices: [...state.invoices, ...invoices],
        isLoading: false,
        hasMore: invoices.length == 20,
        currentPage: state.currentPage + 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Get a specific invoice by ID
  Future<Invoice?> getInvoiceById(int id) async {
    try {
      return await _repository.getById(id);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return null;
    }
  }

  /// Create a new invoice
  Future<bool> createInvoice(Invoice invoice, {List<int>? orderIds}) async {
    state = state.copyWith(isLoading: true);

    try {
      final id = await _repository.create(invoice, orderIds: orderIds);
      if (state.filterOrderId != null) {
        await loadInvoices(filterOrderId: state.filterOrderId);
      } else {
        await loadInvoices();
      }
      // Invalidate count provider to refresh statistics
      ref.invalidate(invoiceCountProvider);
      return id > 0;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// Update an existing invoice
  Future<bool> updateInvoice(Invoice invoice, {List<int>? orderIds}) async {
    state = state.copyWith(isLoading: true);

    try {
      final rowsAffected = await _repository.update(invoice, orderIds: orderIds);
      if (rowsAffected > 0) {
        // Update the invoice in the list
        final updatedInvoices = state.invoices.map((i) {
          return i.id == invoice.id ? invoice : i;
        }).toList();
        state = state.copyWith(invoices: updatedInvoices, isLoading: false);
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

  /// Delete an invoice
  Future<bool> deleteInvoice(int id) async {
    state = state.copyWith(isLoading: true);

    try {
      final rowsAffected = await _repository.delete(id);
      if (rowsAffected > 0) {
        final updatedInvoices = state.invoices.where((i) => i.id != id).toList();
        state = state.copyWith(invoices: updatedInvoices, isLoading: false);
        // Invalidate count provider to refresh statistics
        ref.invalidate(invoiceCountProvider);
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

  /// Search invoices
  Future<void> searchInvoices({
    String? invoiceNumber,
    String? sellerName,
    int? orderId,
    double? minAmount,
    double? maxAmount,
    DateTime? startDate,
    DateTime? endDate,
    bool? hasLinkedOrder,
  }) async {
    state = state.copyWith(isLoading: true);

    try {
      final invoices = await _repository.search(
        invoiceNumber: invoiceNumber,
        sellerName: sellerName,
        orderId: orderId,
        minAmount: minAmount,
        maxAmount: maxAmount,
        startDate: startDate,
        endDate: endDate,
        hasLinkedOrder: hasLinkedOrder,
      );

      state = state.copyWith(
        invoices: invoices,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Get today's invoices
  Future<void> loadTodayInvoices() async {
    state = state.copyWith(isLoading: true);

    try {
      final invoices = await _repository.getTodayInvoices();
      state = state.copyWith(
        invoices: invoices,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Get this month's invoices
  Future<void> loadThisMonthInvoices() async {
    state = state.copyWith(isLoading: true);

    try {
      final invoices = await _repository.getThisMonthInvoices();
      state = state.copyWith(
        invoices: invoices,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Get invoices without linked orders
  Future<void> loadInvoicesWithoutOrders() async {
    state = state.copyWith(isLoading: true);

    try {
      final invoices = await _repository.getWithoutOrders();
      state = state.copyWith(
        invoices: invoices,
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
  Future<List<Invoice>> getAll() async {
    return await _repository.getAll();
  }

  Future<List<Invoice>> getAllForExport() async {
    return await _repository.getAll();
  }

  Future<List<Invoice>> getByDateRangeForExport(DateTime start, DateTime end) async {
    return await _repository.getByDateRange(start, end);
  }

  /// Get order IDs for an invoice
  Future<List<int>> getOrderIdsForInvoice(int invoiceId) async {
    return await _repository.getOrderIdsForInvoice(invoiceId);
  }

  /// Get order count for an invoice
  Future<int> getOrderCountForInvoice(int invoiceId) async {
    return await _repository.getOrderCountForInvoice(invoiceId);
  }

  /// Update order relations for an invoice
  Future<void> updateOrderRelations(int invoiceId, List<int> orderIds) async {
    await _repository.updateOrderRelations(invoiceId, orderIds);
  }

  /// Get seller names with count, ordered by count (highest first)
  Future<List<Map<String, dynamic>>> getSellerNamesWithCount() async {
    return await _repository.getSellerNamesWithCount();
  }
}

/// Provider for InvoiceRepository
final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  return InvoiceRepository();
});

/// Provider for InvoiceNotifier
final invoiceProvider = NotifierProvider<InvoiceNotifier, InvoiceState>(() {
  return InvoiceNotifier();
});

/// Provider for a specific invoice by ID
final invoiceByIdProvider = FutureProvider.family<Invoice?, int>((ref, id) async {
  final repository = ref.watch(invoiceRepositoryProvider);
  return await repository.getById(id);
});

/// Provider for invoices by order ID
final invoicesByOrderIdProvider = FutureProvider.family<List<Invoice>, int>((ref, orderId) async {
  final repository = ref.watch(invoiceRepositoryProvider);
  return await repository.getByOrderId(orderId);
});

/// Provider for invoice count by order ID
final invoiceCountByOrderIdProvider = FutureProvider.family<int, int>((ref, orderId) async {
  final repository = ref.watch(invoiceRepositoryProvider);
  return await repository.getCountByOrderId(orderId);
});

/// Provider for today's invoice count
final todayInvoiceCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(invoiceRepositoryProvider);
  final invoices = await repository.getTodayInvoices();
  return invoices.length;
});

/// Provider for total invoice amount
final totalInvoiceAmountProvider = FutureProvider<double>((ref) async {
  final repository = ref.watch(invoiceRepositoryProvider);
  return await repository.getTotalAmount();
});

/// Provider for invoice count
final invoiceCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(invoiceRepositoryProvider);
  return await repository.getCount();
});
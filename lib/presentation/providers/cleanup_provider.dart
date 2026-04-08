import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/order.dart';
import '../../data/models/invoice.dart';
import '../../data/services/cleanup_service.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/repositories/invoice_repository.dart';

/// Cleanup mode selection
enum CleanupMode {
  orders,
  invoices,
}

/// State for cleanup operations
class CleanupState {
  final CleanupMode mode;
  final DateTime? startDate;
  final DateTime? endDate;
  final Set<int> selectedIds;            // User directly selected IDs
  final Set<int> cascadeIds;             // Auto-selected via cascade
  final bool deleteRelatedItems;         // Delete invoices when orders, or vice versa
  final bool isLoading;
  final bool isDeleting;
  final String? errorMessage;
  final List<Order> availableOrders;
  final List<Invoice> availableInvoices;
  final Map<int, int> orderInvoiceCount; // orderId -> invoice count
  final Map<int, int> invoiceOrderCount; // invoiceId -> order count

  const CleanupState({
    this.mode = CleanupMode.orders,
    this.startDate,
    this.endDate,
    Set<int>? selectedIds,
    Set<int>? cascadeIds,
    this.deleteRelatedItems = false,
    this.isLoading = false,
    this.isDeleting = false,
    this.errorMessage,
    this.availableOrders = const [],
    this.availableInvoices = const [],
    Map<int, int>? orderInvoiceCount,
    Map<int, int>? invoiceOrderCount,
  })  : selectedIds = selectedIds ?? const {},
        cascadeIds = cascadeIds ?? const {},
        orderInvoiceCount = orderInvoiceCount ?? const {},
        invoiceOrderCount = invoiceOrderCount ?? const {};

  CleanupState copyWith({
    CleanupMode? mode,
    DateTime? startDate,
    DateTime? endDate,
    Set<int>? selectedIds,
    Set<int>? cascadeIds,
    bool? deleteRelatedItems,
    bool? isLoading,
    bool? isDeleting,
    String? errorMessage,
    List<Order>? availableOrders,
    List<Invoice>? availableInvoices,
    Map<int, int>? orderInvoiceCount,
    Map<int, int>? invoiceOrderCount,
    bool clearDateRange = false,
    bool clearError = false,
  }) {
    return CleanupState(
      mode: mode ?? this.mode,
      startDate: clearDateRange ? null : (startDate ?? this.startDate),
      endDate: clearDateRange ? null : (endDate ?? this.endDate),
      selectedIds: selectedIds ?? this.selectedIds,
      cascadeIds: cascadeIds ?? this.cascadeIds,
      deleteRelatedItems: deleteRelatedItems ?? this.deleteRelatedItems,
      isLoading: isLoading ?? this.isLoading,
      isDeleting: isDeleting ?? this.isDeleting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      availableOrders: availableOrders ?? this.availableOrders,
      availableInvoices: availableInvoices ?? this.availableInvoices,
      orderInvoiceCount: orderInvoiceCount ?? this.orderInvoiceCount,
      invoiceOrderCount: invoiceOrderCount ?? this.invoiceOrderCount,
    );
  }

  /// Get total selected count (including cascade)
  int get totalSelectedCount => selectedIds.length + cascadeIds.length;

  /// Check if an ID is selected (directly or cascade)
  bool isSelected(int id) => selectedIds.contains(id) || cascadeIds.contains(id);

  /// Check if an ID is cascade selected
  bool isCascadeSelected(int id) => cascadeIds.contains(id);

  /// Get all selected IDs (including cascade)
  Set<int> get allSelectedIds => {...selectedIds, ...cascadeIds};
}

/// Cleanup state notifier
class CleanupNotifier extends Notifier<CleanupState> {
  @override
  CleanupState build() {
    return const CleanupState();
  }

  CleanupService get _cleanupService => ref.read(cleanupServiceProvider);
  OrderRepository get _orderRepository => ref.read(orderRepositoryProvider);
  InvoiceRepository get _invoiceRepository => ref.read(invoiceRepositoryProvider);

  /// Set cleanup mode
  void setMode(CleanupMode mode) {
    state = state.copyWith(
      mode: mode,
      selectedIds: {},
      cascadeIds: {},
      clearDateRange: true,
      clearError: true,
    );
  }

  /// Set date range
  void setDateRange(DateTime? startDate, DateTime? endDate) {
    state = state.copyWith(
      startDate: startDate,
      endDate: endDate,
      clearError: true,
    );
    _loadAvailableItems();
  }

  /// Clear date range
  void clearDateRange() {
    state = state.copyWith(clearDateRange: true);
    _loadAvailableItems();
  }

  /// Toggle delete related items option
  Future<void> toggleDeleteRelatedItems() async {
    final newValue = !state.deleteRelatedItems;
    state = state.copyWith(deleteRelatedItems: newValue);
    await _recalculateCascade();
  }

  /// Load available items based on mode and date range
  Future<void> loadAvailableItems() async {
    return _loadAvailableItems();
  }

  Future<void> _loadAvailableItems() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      if (state.mode == CleanupMode.orders) {
        List<Order> orders;
        if (state.startDate != null && state.endDate != null) {
          orders = await _orderRepository.getByDateRange(
            state.startDate!,
            state.endDate!,
          );
        } else {
          orders = await _orderRepository.getAll();
        }

        // Build invoice count map
        final orderInvoiceCount = <int, int>{};
        for (final order in orders) {
          if (order.id != null) {
            final invoiceIds = await _orderRepository.getInvoiceIdsForOrder(order.id!);
            orderInvoiceCount[order.id!] = invoiceIds.length;
          }
        }

        state = state.copyWith(
          availableOrders: orders,
          orderInvoiceCount: orderInvoiceCount,
          isLoading: false,
          selectedIds: {},
          cascadeIds: {},
        );
      } else {
        List<Invoice> invoices;
        if (state.startDate != null && state.endDate != null) {
          invoices = await _invoiceRepository.getByDateRange(
            state.startDate!,
            state.endDate!,
          );
        } else {
          invoices = await _invoiceRepository.getAll();
        }

        // Build order count map
        final invoiceOrderCount = <int, int>{};
        for (final invoice in invoices) {
          if (invoice.id != null) {
            final orderIds = await _invoiceRepository.getOrderIdsForInvoice(invoice.id!);
            invoiceOrderCount[invoice.id!] = orderIds.length;
          }
        }

        state = state.copyWith(
          availableInvoices: invoices,
          invoiceOrderCount: invoiceOrderCount,
          isLoading: false,
          selectedIds: {},
          cascadeIds: {},
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Toggle selection for an item
  /// Returns cascade message if any items were cascade selected/unselected
  Future<String?> toggleSelection(int id) async {
    if (state.cascadeIds.contains(id)) {
      // Cascade selected item: unselect entire cascade chain
      return await _unselectCascadeChain(id);
    } else if (state.selectedIds.contains(id)) {
      // Directly selected item: check if cascade chain exists
      if (state.deleteRelatedItems) {
        return await _unselectCascadeChain(id);
      } else {
        state = state.copyWith(
          selectedIds: {...state.selectedIds.where((i) => i != id)},
        );
        return null;
      }
    } else {
      // Not selected: select it and cascade
      return await _selectWithCascade(id);
    }
  }

  /// Select an item with cascade
  Future<String?> _selectWithCascade(int id) async {
    state = state.copyWith(
      selectedIds: {...state.selectedIds, id},
    );

    if (!state.deleteRelatedItems) return null;

    // Calculate cascade IDs
    Set<int> cascadeIds = {};
    if (state.mode == CleanupMode.orders) {
      cascadeIds = await _cleanupService.calculateCascadeOrders(
        selectedOrderIds: state.selectedIds,
        deleteInvoices: true,
      );
    } else {
      cascadeIds = await _cleanupService.calculateCascadeInvoices(
        selectedInvoiceIds: state.selectedIds,
        deleteOrders: true,
      );
    }

    // Filter out already selected IDs
    final newCascadeIds = cascadeIds.where((i) => !state.selectedIds.contains(i)).toSet();

    // Add cascade items to available list if not already there
    await _addCascadeItemsToList(newCascadeIds);

    state = state.copyWith(cascadeIds: newCascadeIds);

    if (newCascadeIds.isNotEmpty) {
      return '有${newCascadeIds.length}条数据被一并勾选（关联了同一张发票）';
    }
    return null;
  }

  /// Add cascade items to the available list
  Future<void> _addCascadeItemsToList(Set<int> cascadeIds) async {
    if (cascadeIds.isEmpty) return;

    if (state.mode == CleanupMode.orders) {
      // Find cascade orders not in available list
      final availableIds = state.availableOrders.where((o) => o.id != null).map((o) => o.id!).toSet();
      final missingIds = cascadeIds.where((id) => !availableIds.contains(id));

      if (missingIds.isEmpty) return;

      // Fetch missing orders and add to list
      final List<Order> newOrders = [];
      final Map<int, int> newInvoiceCounts = {};

      for (final orderId in missingIds) {
        final order = await _cleanupService.getOrderById(orderId);
        if (order != null) {
          newOrders.add(order);
          final invoiceIds = await _cleanupService.getInvoiceIdsForOrder(orderId);
          newInvoiceCounts[orderId] = invoiceIds.length;
        }
      }

      state = state.copyWith(
        availableOrders: [...state.availableOrders, ...newOrders],
        orderInvoiceCount: {...state.orderInvoiceCount, ...newInvoiceCounts},
      );
    } else {
      // Find cascade invoices not in available list
      final availableIds = state.availableInvoices.where((i) => i.id != null).map((i) => i.id!).toSet();
      final missingIds = cascadeIds.where((id) => !availableIds.contains(id));

      if (missingIds.isEmpty) return;

      // Fetch missing invoices and add to list
      final List<Invoice> newInvoices = [];
      final Map<int, int> newOrderCounts = {};

      for (final invoiceId in missingIds) {
        final invoice = await _cleanupService.getInvoiceById(invoiceId);
        if (invoice != null) {
          newInvoices.add(invoice);
          final orderIds = await _cleanupService.getOrderIdsForInvoice(invoiceId);
          newOrderCounts[invoiceId] = orderIds.length;
        }
      }

      state = state.copyWith(
        availableInvoices: [...state.availableInvoices, ...newInvoices],
        invoiceOrderCount: {...state.invoiceOrderCount, ...newOrderCounts},
      );
    }
  }

  /// Unselect cascade chain
  Future<String?> _unselectCascadeChain(int id) async {
    Set<int> idsToUnselect = {id};
    int cascadeCount = 0;

    if (state.deleteRelatedItems) {
      // Find all items in the cascade chain
      if (state.mode == CleanupMode.orders) {
        final invoiceIds = await _cleanupService.getInvoiceIdsForOrder(id);
        for (final invoiceId in invoiceIds) {
          final orderIds = await _cleanupService.getOrderIdsForInvoice(invoiceId);
          idsToUnselect.addAll(orderIds);
        }
      } else {
        final orderIds = await _cleanupService.getOrderIdsForInvoice(id);
        for (final orderId in orderIds) {
          final invoiceIds = await _cleanupService.getInvoiceIdsForOrder(orderId);
          idsToUnselect.addAll(invoiceIds);
        }
      }

      cascadeCount = idsToUnselect.length - 1;
    }

    state = state.copyWith(
      selectedIds: state.selectedIds.where((i) => !idsToUnselect.contains(i)).toSet(),
      cascadeIds: state.cascadeIds.where((i) => !idsToUnselect.contains(i)).toSet(),
    );

    if (cascadeCount > 0) {
      return '有$cascadeCount条数据被一并取消勾选';
    }
    return null;
  }

  /// Recalculate cascade selection when deleteRelatedItems changes
  Future<void> _recalculateCascade() async {
    if (!state.deleteRelatedItems) {
      state = state.copyWith(cascadeIds: {});
      return;
    }

    Set<int> cascadeIds = {};
    if (state.mode == CleanupMode.orders && state.selectedIds.isNotEmpty) {
      cascadeIds = await _cleanupService.calculateCascadeOrders(
        selectedOrderIds: state.selectedIds,
        deleteInvoices: true,
      );
    } else if (state.mode == CleanupMode.invoices && state.selectedIds.isNotEmpty) {
      cascadeIds = await _cleanupService.calculateCascadeInvoices(
        selectedInvoiceIds: state.selectedIds,
        deleteOrders: true,
      );
    }

    final newCascadeIds = cascadeIds.where((i) => !state.selectedIds.contains(i)).toSet();
    state = state.copyWith(cascadeIds: newCascadeIds);
  }

  /// Select all items
  Future<String?> selectAll() async {
    if (state.mode == CleanupMode.orders) {
      final allIds = state.availableOrders
          .where((o) => o.id != null)
          .map((o) => o.id!)
          .toSet();
      state = state.copyWith(selectedIds: allIds, cascadeIds: {});
    } else {
      final allIds = state.availableInvoices
          .where((i) => i.id != null)
          .map((i) => i.id!)
          .toSet();
      state = state.copyWith(selectedIds: allIds, cascadeIds: {});
    }

    // Apply cascade if enabled
    if (state.deleteRelatedItems) {
      return await _recalculateCascadeAndGetMessage();
    }
    return null;
  }

  /// Invert selection
  Future<String?> invertSelection() async {
    if (state.mode == CleanupMode.orders) {
      final allIds = state.availableOrders
          .where((o) => o.id != null)
          .map((o) => o.id!)
          .toSet();
      final newSelectedIds = allIds.where((id) => !state.isSelected(id)).toSet();
      state = state.copyWith(selectedIds: newSelectedIds, cascadeIds: {});
    } else {
      final allIds = state.availableInvoices
          .where((i) => i.id != null)
          .map((i) => i.id!)
          .toSet();
      final newSelectedIds = allIds.where((id) => !state.isSelected(id)).toSet();
      state = state.copyWith(selectedIds: newSelectedIds, cascadeIds: {});
    }

    // Apply cascade if enabled
    if (state.deleteRelatedItems) {
      return await _recalculateCascadeAndGetMessage();
    }
    return null;
  }

  /// Recalculate cascade and return message
  Future<String?> _recalculateCascadeAndGetMessage() async {
    await _recalculateCascade();
    if (state.cascadeIds.isNotEmpty) {
      return '有${state.cascadeIds.length}条数据被一并勾选（关联了同一张发票）';
    }
    return null;
  }

  /// Execute cleanup
  Future<CleanupResult?> executeCleanup() async {
    if (state.totalSelectedCount == 0) return null;

    state = state.copyWith(isDeleting: true, clearError: true);

    try {
      CleanupResult result;
      if (state.mode == CleanupMode.orders) {
        result = await _cleanupService.deleteOrders(
          orderIds: state.allSelectedIds,
          deleteInvoices: state.deleteRelatedItems,
        );
      } else {
        result = await _cleanupService.deleteInvoices(
          invoiceIds: state.allSelectedIds,
          deleteOrders: state.deleteRelatedItems,
        );
      }

      // Refresh data
      await _loadAvailableItems();

      // Invalidate other providers
      ref.invalidate(orderCountProvider);
      ref.invalidate(invoiceCountProvider);

      state = state.copyWith(
        isDeleting: false,
        selectedIds: {},
        cascadeIds: {},
      );

      return result;
    } catch (e) {
      state = state.copyWith(
        isDeleting: false,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Get item relation count
  int getRelationCount(int id) {
    if (state.mode == CleanupMode.orders) {
      return state.orderInvoiceCount[id] ?? 0;
    } else {
      return state.invoiceOrderCount[id] ?? 0;
    }
  }

  /// Get the count of invoices that would be deleted when deleting selected orders
  /// Returns the actual count of unique invoices linked to all selected orders
  Future<int> getRelatedInvoiceCount() async {
    if (!state.deleteRelatedItems) return 0;

    final allOrderIds = state.allSelectedIds;
    final Set<int> invoiceIds = {};

    for (final orderId in allOrderIds) {
      final ids = await _cleanupService.getInvoiceIdsForOrder(orderId);
      invoiceIds.addAll(ids);
    }

    return invoiceIds.length;
  }

  /// Get the count of orders that would be deleted when deleting selected invoices
  /// Returns the actual count of unique orders linked to all selected invoices
  Future<int> getRelatedOrderCount() async {
    if (!state.deleteRelatedItems) return 0;

    final allInvoiceIds = state.allSelectedIds;
    final Set<int> orderIds = {};

    for (final invoiceId in allInvoiceIds) {
      final ids = await _cleanupService.getOrderIdsForInvoice(invoiceId);
      orderIds.addAll(ids);
    }

    return orderIds.length;
  }
}

/// Provider for CleanupService
final cleanupServiceProvider = Provider<CleanupService>((ref) {
  return CleanupService();
});

/// Provider for OrderRepository
final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository();
});

/// Provider for InvoiceRepository
final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  return InvoiceRepository();
});

/// Provider for order count
final orderCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(orderRepositoryProvider);
  return await repository.getCount();
});

/// Provider for invoice count
final invoiceCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(invoiceRepositoryProvider);
  return await repository.getCount();
});

/// Provider for CleanupNotifier
final cleanupProvider = NotifierProvider<CleanupNotifier, CleanupState>(() {
  return CleanupNotifier();
});
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/order.dart';
import '../../data/models/invoice.dart';
import '../../data/services/cleanup_service.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/repositories/invoice_repository.dart';
import 'invoice_provider.dart' as invoice_providers;
import 'ledger_data_revision_provider.dart';
import 'order_provider.dart' as order_providers;

/// Cleanup mode selection
enum CleanupMode { orders, invoices }

/// State for cleanup operations
class CleanupState {
  final CleanupMode mode;
  final DateTime? startDate;
  final DateTime? endDate;
  final Set<int> selectedIds; // User directly selected IDs
  final Set<int> cascadeIds; // Auto-selected via cascade
  final bool deleteRelatedItems; // Delete invoices when orders, or vice versa
  final bool isLoading;
  final bool isDeleting;
  final String? errorMessage;
  final String? refreshWarningMessage;
  final List<Order> availableOrders;
  final List<Invoice> availableInvoices;
  final Map<int, int> orderInvoiceCount; // orderId -> invoice count
  final Map<int, int> invoiceOrderCount; // invoiceId -> order count
  final Map<int, Order> cascadeOrders; // Includes hidden cascade orders
  final Map<int, Invoice> cascadeInvoices; // Includes hidden cascade invoices

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
    this.refreshWarningMessage,
    this.availableOrders = const [],
    this.availableInvoices = const [],
    Map<int, int>? orderInvoiceCount,
    Map<int, int>? invoiceOrderCount,
    Map<int, Order>? cascadeOrders,
    Map<int, Invoice>? cascadeInvoices,
  }) : selectedIds = selectedIds ?? const {},
       cascadeIds = cascadeIds ?? const {},
       orderInvoiceCount = orderInvoiceCount ?? const {},
       invoiceOrderCount = invoiceOrderCount ?? const {},
       cascadeOrders = cascadeOrders ?? const {},
       cascadeInvoices = cascadeInvoices ?? const {};

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
    String? refreshWarningMessage,
    List<Order>? availableOrders,
    List<Invoice>? availableInvoices,
    Map<int, int>? orderInvoiceCount,
    Map<int, int>? invoiceOrderCount,
    Map<int, Order>? cascadeOrders,
    Map<int, Invoice>? cascadeInvoices,
    bool clearDateRange = false,
    bool clearError = false,
    bool clearRefreshWarning = false,
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
      refreshWarningMessage: clearRefreshWarning
          ? null
          : (refreshWarningMessage ?? this.refreshWarningMessage),
      availableOrders: availableOrders ?? this.availableOrders,
      availableInvoices: availableInvoices ?? this.availableInvoices,
      orderInvoiceCount: orderInvoiceCount ?? this.orderInvoiceCount,
      invoiceOrderCount: invoiceOrderCount ?? this.invoiceOrderCount,
      cascadeOrders: cascadeOrders ?? this.cascadeOrders,
      cascadeInvoices: cascadeInvoices ?? this.cascadeInvoices,
    );
  }

  /// Get total selected count (including cascade)
  int get totalSelectedCount => allSelectedIds.length;

  /// Check if an ID is selected (directly or cascade)
  bool isSelected(int id) =>
      selectedIds.contains(id) || cascadeIds.contains(id);

  /// Check if an ID is cascade selected
  bool isCascadeSelected(int id) => cascadeIds.contains(id);

  /// Get all selected IDs (including cascade)
  Set<int> get allSelectedIds => {...selectedIds, ...cascadeIds};

  Set<int> get visibleIds {
    if (mode == CleanupMode.orders) {
      return availableOrders.map((item) => item.id).whereType<int>().toSet();
    }
    return availableInvoices.map((item) => item.id).whereType<int>().toSet();
  }

  /// IDs explicitly selected from the currently visible filter result.
  Set<int> get visibleSelectedIds => selectedIds.intersection(visibleIds);

  int get hiddenCascadeCount => cascadeIds.difference(visibleIds).length;

  /// Full amount of every item that will be deleted, including hidden cascades.
  double get selectedTotalAmount {
    if (mode == CleanupMode.orders) {
      final items = <int, Order>{
        for (final item in availableOrders)
          if (item.id != null) item.id!: item,
        ...cascadeOrders,
      };
      return allSelectedIds.fold<double>(
        0,
        (sum, id) => sum + (items[id]?.amount ?? 0),
      );
    }

    final items = <int, Invoice>{
      for (final item in availableInvoices)
        if (item.id != null) item.id!: item,
      ...cascadeInvoices,
    };
    return allSelectedIds.fold<double>(
      0,
      (sum, id) => sum + (items[id]?.totalAmount ?? 0),
    );
  }
}

/// Cleanup state notifier
class CleanupNotifier extends Notifier<CleanupState> {
  int _loadRequest = 0;
  int _cascadeRequest = 0;

  @override
  CleanupState build() {
    return const CleanupState();
  }

  CleanupService get _cleanupService => ref.read(cleanupServiceProvider);
  OrderRepository get _orderRepository => ref.read(orderRepositoryProvider);
  InvoiceRepository get _invoiceRepository =>
      ref.read(invoiceRepositoryProvider);

  /// Set cleanup mode
  void setMode(CleanupMode mode) {
    _loadRequest++;
    _cascadeRequest++;
    state = state.copyWith(
      mode: mode,
      selectedIds: {},
      cascadeIds: {},
      cascadeOrders: {},
      cascadeInvoices: {},
      deleteRelatedItems: false,
      isLoading: false,
      clearDateRange: true,
      clearError: true,
      clearRefreshWarning: true,
    );
  }

  /// Set date range
  Future<void> setDateRange(DateTime? startDate, DateTime? endDate) async {
    state = state.copyWith(
      startDate: startDate,
      endDate: endDate,
      selectedIds: {},
      cascadeIds: {},
      cascadeOrders: {},
      cascadeInvoices: {},
      clearError: true,
      clearRefreshWarning: true,
    );
    await _loadAvailableItems();
  }

  /// Clear date range
  Future<void> clearDateRange() async {
    state = state.copyWith(
      clearDateRange: true,
      selectedIds: {},
      cascadeIds: {},
      cascadeOrders: {},
      cascadeInvoices: {},
      clearError: true,
      clearRefreshWarning: true,
    );
    await _loadAvailableItems();
  }

  /// Toggle delete related items option
  Future<void> toggleDeleteRelatedItems() async {
    if (state.isLoading || state.isDeleting) return;
    final newValue = !state.deleteRelatedItems;
    state = state.copyWith(deleteRelatedItems: newValue, clearError: true);
    try {
      await _recalculateCascade();
    } catch (e) {
      state = state.copyWith(
        cascadeIds: {},
        cascadeOrders: {},
        cascadeInvoices: {},
        errorMessage: e.toString(),
      );
    }
  }

  /// Load available items based on mode and date range
  Future<void> loadAvailableItems() async {
    return _loadAvailableItems();
  }

  Future<void> _loadAvailableItems() async {
    final request = ++_loadRequest;
    _cascadeRequest++;
    final mode = state.mode;
    final startDate = state.startDate;
    final endDate = state.endDate;
    state = state.copyWith(
      isLoading: true,
      selectedIds: {},
      cascadeIds: {},
      cascadeOrders: {},
      cascadeInvoices: {},
      clearError: true,
      clearRefreshWarning: true,
    );

    try {
      if (mode == CleanupMode.orders) {
        List<Order> orders;
        if (startDate != null && endDate != null) {
          orders = await _orderRepository.getByDateRange(startDate, endDate);
        } else {
          orders = await _orderRepository.getAll();
        }

        // Build invoice count map
        final orderInvoiceCount = <int, int>{};
        for (final order in orders) {
          if (order.id != null) {
            final invoiceIds = await _orderRepository.getInvoiceIdsForOrder(
              order.id!,
            );
            orderInvoiceCount[order.id!] = invoiceIds.length;
          }
        }

        if (request != _loadRequest || state.mode != mode) return;

        state = state.copyWith(
          availableOrders: orders,
          orderInvoiceCount: orderInvoiceCount,
          isLoading: false,
          selectedIds: {},
          cascadeIds: {},
          cascadeOrders: {},
          cascadeInvoices: {},
        );
      } else {
        List<Invoice> invoices;
        if (startDate != null && endDate != null) {
          invoices = await _invoiceRepository.getByDateRange(
            startDate,
            endDate,
          );
        } else {
          invoices = await _invoiceRepository.getAll();
        }

        // Build order count map
        final invoiceOrderCount = <int, int>{};
        for (final invoice in invoices) {
          if (invoice.id != null) {
            final orderIds = await _invoiceRepository.getOrderIdsForInvoice(
              invoice.id!,
            );
            invoiceOrderCount[invoice.id!] = orderIds.length;
          }
        }

        if (request != _loadRequest || state.mode != mode) return;

        state = state.copyWith(
          availableInvoices: invoices,
          invoiceOrderCount: invoiceOrderCount,
          isLoading: false,
          selectedIds: {},
          cascadeIds: {},
          cascadeOrders: {},
          cascadeInvoices: {},
        );
      }
    } catch (e) {
      if (request != _loadRequest || state.mode != mode) return;
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Toggle selection for an item
  /// Returns cascade message if any items were cascade selected/unselected
  Future<String?> toggleSelection(int id) async {
    if (state.isLoading || state.isDeleting || !state.visibleIds.contains(id)) {
      return null;
    }

    try {
      state = state.copyWith(clearError: true);
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
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return null;
    }
  }

  /// Select an item with cascade
  Future<String?> _selectWithCascade(int id) async {
    state = state.copyWith(selectedIds: {...state.selectedIds, id});

    if (!state.deleteRelatedItems) return null;

    await _recalculateCascade();
    return _cascadeMessage();
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
          final orderIds = await _cleanupService.getOrderIdsForInvoice(
            invoiceId,
          );
          idsToUnselect.addAll(orderIds);
        }
      } else {
        final orderIds = await _cleanupService.getOrderIdsForInvoice(id);
        for (final orderId in orderIds) {
          final invoiceIds = await _cleanupService.getInvoiceIdsForOrder(
            orderId,
          );
          idsToUnselect.addAll(invoiceIds);
        }
      }

      cascadeCount = idsToUnselect.length - 1;
    }

    state = state.copyWith(
      selectedIds: state.selectedIds
          .where((i) => !idsToUnselect.contains(i))
          .toSet(),
      cascadeIds: state.cascadeIds
          .where((i) => !idsToUnselect.contains(i))
          .toSet(),
      cascadeOrders: Map.fromEntries(
        state.cascadeOrders.entries.where(
          (entry) => !idsToUnselect.contains(entry.key),
        ),
      ),
      cascadeInvoices: Map.fromEntries(
        state.cascadeInvoices.entries.where(
          (entry) => !idsToUnselect.contains(entry.key),
        ),
      ),
    );

    if (cascadeCount > 0) {
      return '有$cascadeCount条数据被一并取消勾选';
    }
    return null;
  }

  /// Recalculate cascade selection when deleteRelatedItems changes
  Future<void> _recalculateCascade() async {
    if (!state.deleteRelatedItems) {
      _cascadeRequest++;
      state = state.copyWith(
        cascadeIds: {},
        cascadeOrders: {},
        cascadeInvoices: {},
      );
      return;
    }

    final request = ++_cascadeRequest;
    final mode = state.mode;
    final selectedIds = Set<int>.of(state.visibleSelectedIds);
    final availableOrders = List<Order>.of(state.availableOrders);
    final availableInvoices = List<Invoice>.of(state.availableInvoices);

    Set<int> cascadeIds = {};
    if (mode == CleanupMode.orders && selectedIds.isNotEmpty) {
      cascadeIds = await _cleanupService.calculateCascadeOrders(
        selectedOrderIds: selectedIds,
        deleteInvoices: true,
      );
    } else if (mode == CleanupMode.invoices && selectedIds.isNotEmpty) {
      cascadeIds = await _cleanupService.calculateCascadeInvoices(
        selectedInvoiceIds: selectedIds,
        deleteOrders: true,
      );
    }

    final newCascadeIds = cascadeIds
        .where((i) => !selectedIds.contains(i))
        .toSet();
    final cascadeOrders = <int, Order>{};
    final cascadeInvoices = <int, Invoice>{};

    if (mode == CleanupMode.orders) {
      final visibleItems = <int, Order>{
        for (final item in availableOrders)
          if (item.id != null) item.id!: item,
      };
      for (final id in newCascadeIds) {
        final item = visibleItems[id] ?? await _cleanupService.getOrderById(id);
        if (item != null) cascadeOrders[id] = item;
      }
    } else {
      final visibleItems = <int, Invoice>{
        for (final item in availableInvoices)
          if (item.id != null) item.id!: item,
      };
      for (final id in newCascadeIds) {
        final item =
            visibleItems[id] ?? await _cleanupService.getInvoiceById(id);
        if (item != null) cascadeInvoices[id] = item;
      }
    }

    if (request != _cascadeRequest ||
        state.mode != mode ||
        !state.deleteRelatedItems ||
        !_sameIds(state.visibleSelectedIds, selectedIds)) {
      return;
    }

    state = state.copyWith(
      selectedIds: selectedIds,
      cascadeIds: newCascadeIds,
      cascadeOrders: cascadeOrders,
      cascadeInvoices: cascadeInvoices,
    );
  }

  bool _sameIds(Set<int> left, Set<int> right) =>
      left.length == right.length && left.containsAll(right);

  String? _cascadeMessage() {
    if (state.cascadeIds.isEmpty) return null;
    final hidden = state.hiddenCascadeCount;
    final hiddenMessage = hidden > 0 ? '，其中 $hidden 条在当前筛选范围外' : '';
    return '有 ${state.cascadeIds.length} 条数据被一并勾选$hiddenMessage';
  }

  /// Select all items
  Future<String?> selectAll() async {
    if (state.isLoading || state.isDeleting) return null;
    if (state.mode == CleanupMode.orders) {
      final allIds = state.availableOrders
          .where((o) => o.id != null)
          .map((o) => o.id!)
          .toSet();
      state = state.copyWith(
        selectedIds: allIds,
        cascadeIds: {},
        cascadeOrders: {},
        cascadeInvoices: {},
        clearError: true,
      );
    } else {
      final allIds = state.availableInvoices
          .where((i) => i.id != null)
          .map((i) => i.id!)
          .toSet();
      state = state.copyWith(
        selectedIds: allIds,
        cascadeIds: {},
        cascadeOrders: {},
        cascadeInvoices: {},
        clearError: true,
      );
    }

    // Apply cascade if enabled
    if (state.deleteRelatedItems) {
      return await _recalculateCascadeAndGetMessage();
    }
    return null;
  }

  /// Invert selection
  Future<String?> invertSelection() async {
    if (state.isLoading || state.isDeleting) return null;
    if (state.mode == CleanupMode.orders) {
      final allIds = state.availableOrders
          .where((o) => o.id != null)
          .map((o) => o.id!)
          .toSet();
      final newSelectedIds = allIds
          .where((id) => !state.isSelected(id))
          .toSet();
      state = state.copyWith(
        selectedIds: newSelectedIds,
        cascadeIds: {},
        cascadeOrders: {},
        cascadeInvoices: {},
        clearError: true,
      );
    } else {
      final allIds = state.availableInvoices
          .where((i) => i.id != null)
          .map((i) => i.id!)
          .toSet();
      final newSelectedIds = allIds
          .where((id) => !state.isSelected(id))
          .toSet();
      state = state.copyWith(
        selectedIds: newSelectedIds,
        cascadeIds: {},
        cascadeOrders: {},
        cascadeInvoices: {},
        clearError: true,
      );
    }

    // Apply cascade if enabled
    if (state.deleteRelatedItems) {
      return await _recalculateCascadeAndGetMessage();
    }
    return null;
  }

  /// Recalculate cascade and return message
  Future<String?> _recalculateCascadeAndGetMessage() async {
    try {
      await _recalculateCascade();
      return _cascadeMessage();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return null;
    }
  }

  /// Execute cleanup
  Future<CleanupResult?> executeCleanup() async {
    if (state.isLoading ||
        state.isDeleting ||
        state.errorMessage != null ||
        state.visibleSelectedIds.isEmpty) {
      return null;
    }

    // CleanupService calculates the disclosed one-hop cascade itself. Passing
    // the already-expanded IDs back as roots would calculate a second cascade
    // and could delete records that were never shown in the confirmation UI.
    final selectedIds = Set<int>.of(state.visibleSelectedIds);

    state = state.copyWith(
      isDeleting: true,
      clearError: true,
      clearRefreshWarning: true,
    );

    late final CleanupResult result;
    try {
      if (state.mode == CleanupMode.orders) {
        result = await _cleanupService.deleteOrders(
          orderIds: selectedIds,
          deleteInvoices: state.deleteRelatedItems,
        );
      } else {
        result = await _cleanupService.deleteInvoices(
          invoiceIds: selectedIds,
          deleteOrders: state.deleteRelatedItems,
        );
      }
    } catch (e) {
      state = state.copyWith(isDeleting: false, errorMessage: e.toString());
      return null;
    }

    // The destructive transaction already succeeded. From this point onward,
    // refresh failures must not turn the real deletion result into a failure.
    if (result.ordersDeleted > 0 || result.invoicesDeleted > 0) {
      ref.read(ledgerDataRevisionProvider.notifier).markChanged();
    }
    state = state.copyWith(
      selectedIds: {},
      cascadeIds: {},
      cascadeOrders: {},
      cascadeInvoices: {},
      clearError: true,
    );
    final refreshWarning = await _refreshAfterSuccessfulCleanup();
    state = state.copyWith(
      isDeleting: false,
      refreshWarningMessage: refreshWarning,
      clearRefreshWarning: refreshWarning == null,
      clearError: true,
    );
    return result;
  }

  /// Retry only the post-delete UI refresh. It never repeats deletion.
  Future<void> retryRefreshAfterCleanup() async {
    if (state.isLoading || state.isDeleting) return;
    state = state.copyWith(clearError: true, clearRefreshWarning: true);
    final refreshWarning = await _refreshAfterSuccessfulCleanup();
    state = state.copyWith(
      refreshWarningMessage: refreshWarning,
      clearRefreshWarning: refreshWarning == null,
      clearError: true,
    );
  }

  Future<String?> _refreshAfterSuccessfulCleanup() async {
    final issues = <String>[];

    // _loadAvailableItems reports its own error in state so ordinary loading
    // screens still work. Convert that error to a non-destructive warning here.
    await _loadAvailableItems();
    final cleanupListError = state.errorMessage;
    if (cleanupListError != null) {
      issues.add('清理列表刷新失败：$cleanupListError');
      state = state.copyWith(clearError: true);
    }

    try {
      await _refreshMainDataProviders();
    } catch (e) {
      issues.add('主列表刷新失败：$e');
    }

    // Counts should always be invalidated even when one list refresh failed.
    ref.invalidate(orderCountProvider);
    ref.invalidate(invoiceCountProvider);

    if (issues.isEmpty) return null;
    return '清理已完成，但数据刷新失败。请重试刷新。\n${issues.join('\n')}';
  }

  Future<void> _refreshMainDataProviders() async {
    final currentInvoiceFilter = ref
        .read(invoice_providers.invoiceProvider)
        .filterOrderId;

    await Future.wait([
      ref
          .read(order_providers.orderProvider.notifier)
          .loadOrders(refresh: true),
      ref
          .read(invoice_providers.invoiceProvider.notifier)
          .loadInvoices(refresh: true, filterOrderId: currentInvoiceFilter),
    ]);

    ref.invalidate(order_providers.orderCountProvider);
    ref.invalidate(order_providers.todayOrderCountProvider);
    ref.invalidate(order_providers.totalOrderAmountProvider);
    ref.invalidate(order_providers.orderByIdProvider);

    ref.invalidate(invoice_providers.invoiceCountProvider);
    ref.invalidate(invoice_providers.todayInvoiceCountProvider);
    ref.invalidate(invoice_providers.totalInvoiceAmountProvider);
    ref.invalidate(invoice_providers.invoiceByIdProvider);
    ref.invalidate(invoice_providers.invoicesByOrderIdProvider);
    ref.invalidate(invoice_providers.invoiceCountByOrderIdProvider);
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

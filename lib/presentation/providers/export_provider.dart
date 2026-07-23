import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../core/services/log_service.dart';
import '../../core/services/log_config.dart';
import 'invoice_provider.dart' as invoice_providers;
import 'order_provider.dart' as order_providers;

/// State for export operations
/// 导出操作状态
class ExportState {
  /// Date range filter start date
  /// 日期范围筛选开始日期
  final DateTime? startDate;

  /// Date range filter end date
  /// 日期范围筛选结束日期
  final DateTime? endDate;

  /// User directly selected order IDs
  /// 用户直接选中的订单ID集合
  final Set<int> selectedIds;

  /// Cascade selected order IDs (auto-selected via invoice relation)
  /// 联动选中的订单ID集合（通过发票关联自动选中）
  final Set<int> cascadeIds;

  /// Loading state
  /// 加载状态
  final bool isLoading;

  /// Available orders list
  /// 可用订单列表
  final List<Order> availableOrders;

  /// 当前可见记录及筛选范围外已选记录。
  final Map<int, Order> knownOrdersById;

  /// Order to invoice count mapping (orderId -> invoice count)
  /// 订单关联发票数量映射 (orderId -> 关联发票数量)
  final Map<int, int> orderInvoiceCount;

  /// Order to invoice IDs mapping (orderId -> invoice ID set)
  /// 订单关联发票ID集合映射 (orderId -> 关联发票ID集合)
  final Map<int, Set<int>> orderInvoices;

  /// Error message
  /// 错误消息
  final String? errorMessage;

  const ExportState({
    this.startDate,
    this.endDate,
    Set<int>? selectedIds,
    Set<int>? cascadeIds,
    this.isLoading = false,
    this.availableOrders = const [],
    Map<int, Order>? knownOrdersById,
    Map<int, int>? orderInvoiceCount,
    Map<int, Set<int>>? orderInvoices,
    this.errorMessage,
  }) : selectedIds = selectedIds ?? const {},
       cascadeIds = cascadeIds ?? const {},
       knownOrdersById = knownOrdersById ?? const {},
       orderInvoiceCount = orderInvoiceCount ?? const {},
       orderInvoices = orderInvoices ?? const {};

  /// Copy with method for state updates
  /// 状态更新方法
  ExportState copyWith({
    DateTime? startDate,
    DateTime? endDate,
    Set<int>? selectedIds,
    Set<int>? cascadeIds,
    bool? isLoading,
    List<Order>? availableOrders,
    Map<int, Order>? knownOrdersById,
    Map<int, int>? orderInvoiceCount,
    Map<int, Set<int>>? orderInvoices,
    String? errorMessage,
    bool clearDateRange = false,
    bool clearError = false,
  }) {
    return ExportState(
      startDate: clearDateRange ? null : (startDate ?? this.startDate),
      endDate: clearDateRange ? null : (endDate ?? this.endDate),
      selectedIds: selectedIds ?? this.selectedIds,
      cascadeIds: cascadeIds ?? this.cascadeIds,
      isLoading: isLoading ?? this.isLoading,
      availableOrders: availableOrders ?? this.availableOrders,
      knownOrdersById: knownOrdersById ?? this.knownOrdersById,
      orderInvoiceCount: orderInvoiceCount ?? this.orderInvoiceCount,
      orderInvoices: orderInvoices ?? this.orderInvoices,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  /// Get total selected count (including cascade)
  /// 获取总选中数量（包含联动选中）
  int get totalSelectedCount => allSelectedIds.length;

  bool get hasDateRange => startDate != null && endDate != null;

  int get selectableCount => availableOrders.where((order) {
    final id = order.id;
    return id != null && isSelectable(id);
  }).length;

  Set<int> get visibleOrderIds => {
    for (final order in availableOrders)
      if (order.id case final int id) id,
  };

  int get hiddenSelectedCount =>
      allSelectedIds.difference(visibleOrderIds).length;

  Set<int> get selectedInvoiceIds => {
    for (final orderId in allSelectedIds)
      ...(orderInvoices[orderId] ?? const <int>{}),
  };

  double get selectedTotal => knownOrdersById.values
      .where((order) => order.id != null && isSelected(order.id!))
      .fold(0, (sum, order) => sum + order.amount);

  /// Check if an order is selected (directly or cascade)
  /// 检查订单是否被选中（直接选中或联动选中）
  bool isSelected(int id) =>
      selectedIds.contains(id) || cascadeIds.contains(id);

  /// Check if an order is cascade selected
  /// 检查订单是否被联动选中
  bool isCascadeSelected(int id) => cascadeIds.contains(id);

  /// Check if an order is selectable (has linked invoices)
  /// 检查订单是否可被选择（至少关联一张发票）
  bool isSelectable(int id) => (orderInvoiceCount[id] ?? 0) > 0;

  /// Get all selected IDs (including cascade)
  /// 获取所有选中的ID集合（包含联动选中）
  Set<int> get allSelectedIds => {...selectedIds, ...cascadeIds};
}

/// Export state notifier
/// 导出状态管理器
class ExportNotifier extends Notifier<ExportState> {
  Future<void> _selectionTail = Future<void>.value();
  int _loadGeneration = 0;

  @override
  ExportState build() {
    return const ExportState();
  }

  OrderRepository get _orderRepository =>
      ref.read(order_providers.orderRepositoryProvider);
  InvoiceRepository get _invoiceRepository =>
      ref.read(invoice_providers.invoiceRepositoryProvider);

  /// Load available orders and their invoice relations
  /// 加载可用订单及其发票关联信息
  Future<void> loadAvailableOrders({bool clearSelection = false}) async {
    final generation = ++_loadGeneration;
    final directSelectionSnapshot = clearSelection
        ? const <int>{}
        : state.selectedIds;
    final cascadeSelectionSnapshot = clearSelection
        ? const <int>{}
        : state.cascadeIds;
    final selectionSnapshot = <int>{
      ...directSelectionSnapshot,
      ...cascadeSelectionSnapshot,
    };
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      List<Order> orders;
      if (state.startDate != null && state.endDate != null) {
        orders = await _orderRepository.getByDateRange(
          state.startDate!,
          state.endDate!,
        );
      } else {
        orders = await _orderRepository.getAll();
      }

      // Batch-load relations so a long reimbursement ledger does not issue one
      // database query per order.
      final selectedOrders = selectionSnapshot.isEmpty
          ? const <Order>[]
          : await _orderRepository.getByIds(
              selectionSnapshot.toList(growable: false),
            );
      final knownOrdersById = <int, Order>{
        for (final order in orders)
          if (order.id case final int id) id: order,
        for (final order in selectedOrders)
          if (order.id case final int id) id: order,
      };
      final knownOrderIds = knownOrdersById.keys.toList(growable: false);
      final loadedRelations = await _orderRepository.getInvoiceIdsForOrders(
        knownOrderIds,
      );
      final orderInvoices = <int, Set<int>>{
        for (final orderId in knownOrderIds)
          orderId: Set<int>.of(loadedRelations[orderId] ?? const <int>{}),
      };
      final orderInvoiceCount = <int, int>{
        for (final orderId in knownOrderIds)
          orderId: orderInvoices[orderId]!.length,
      };

      if (generation != _loadGeneration) return;
      final retainedIds = knownOrdersById.keys.toSet();
      state = state.copyWith(
        availableOrders: orders,
        knownOrdersById: knownOrdersById,
        orderInvoiceCount: orderInvoiceCount,
        orderInvoices: orderInvoices,
        isLoading: false,
        selectedIds: directSelectionSnapshot.intersection(retainedIds),
        cascadeIds: cascadeSelectionSnapshot.intersection(retainedIds),
      );
    } catch (e, stackTrace) {
      if (generation != _loadGeneration) return;
      logService.e(LogConfig.moduleDb, '加载订单失败', e, stackTrace);
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Set date range filter
  /// 设置日期范围筛选
  Future<void> setDateRange(DateTime? startDate, DateTime? endDate) async {
    state = state.copyWith(
      startDate: startDate,
      endDate: endDate,
      clearError: true,
    );
    await loadAvailableOrders();
  }

  /// Clear date range filter
  /// 清除日期范围筛选
  Future<void> clearDateRange() async {
    state = state.copyWith(clearDateRange: true);
    await loadAvailableOrders();
  }

  /// Toggle selection for an order
  /// Returns cascade message if any items were cascade selected/unselected
  /// 切换订单选中状态，返回联动勾选提示消息
  Future<String?> toggleSelection(int orderId) async {
    return _enqueueSelection(() => _toggleSelection(orderId));
  }

  Future<String?> _toggleSelection(int orderId) async {
    if (state.isLoading || !state.isSelectable(orderId)) return null;
    if (state.isSelected(orderId)) {
      return await _unselectCascadeChain(orderId);
    }
    return await _selectWithCascade(orderId);
  }

  /// Select an order with cascade
  /// 选中订单并联动勾选关联订单
  Future<String?> _selectWithCascade(int orderId) async {
    final selectedBefore = state.allSelectedIds;

    // Add to selected IDs
    // 添加到直接选中集合
    final newSelectedIds = {...state.selectedIds, orderId};

    // Calculate cascade IDs for all selected orders
    // 计算所有选中订单的联动ID
    final cascadeIds = await _calculateCascadeIds(newSelectedIds);

    // Filter out already selected IDs
    // 过滤掉已直接选中的ID
    final newCascadeIds = cascadeIds
        .where((id) => !newSelectedIds.contains(id))
        .toSet();

    // Add cascade orders to available list if not already there
    // 将联动订单添加到可用列表（如果尚未存在）
    await _cacheCascadeOrders(newCascadeIds);

    state = state.copyWith(
      selectedIds: newSelectedIds,
      cascadeIds: newCascadeIds,
    );

    return _cascadeDeltaMessage(
      selectedBefore: selectedBefore,
      selectedAfter: state.allSelectedIds,
      directlyChangedIds: <int>{orderId},
    );
  }

  /// 缓存筛选范围外的联动订单，但不把它们混入当前可见账页。
  Future<void> _cacheCascadeOrders(Set<int> cascadeIds) async {
    if (cascadeIds.isEmpty) return;

    final missingIds = cascadeIds.where(
      (id) => !state.knownOrdersById.containsKey(id),
    );

    if (missingIds.isEmpty) return;

    // Fetch the complete cascade in two batch reads. A date-filtered selection
    // can bring in orders outside the visible range, so those rows must carry
    // their relation metadata too.
    final missingIdList = missingIds.toList(growable: false);
    final newOrders = await _orderRepository.getByIds(missingIdList);
    final loadedRelations = await _orderRepository.getInvoiceIdsForOrders(
      missingIdList,
    );
    final newInvoices = <int, Set<int>>{
      for (final orderId in missingIdList)
        orderId: Set<int>.of(loadedRelations[orderId] ?? const <int>{}),
    };
    final newInvoiceCounts = <int, int>{
      for (final orderId in missingIdList)
        orderId: newInvoices[orderId]!.length,
    };

    state = state.copyWith(
      knownOrdersById: {
        ...state.knownOrdersById,
        for (final order in newOrders)
          if (order.id case final int id) id: order,
      },
      orderInvoiceCount: {...state.orderInvoiceCount, ...newInvoiceCounts},
      orderInvoices: {...state.orderInvoices, ...newInvoices},
    );
  }

  /// Unselect cascade chain for an order
  /// 取消订单的整个关联链
  Future<String?> _unselectCascadeChain(int orderId) async {
    final selectedBefore = state.allSelectedIds;

    // Get all IDs in the cascade chain
    // 获取关联链中的所有ID
    final idsToUnselect = await _getCascadeChainIds(orderId);

    // Remove all IDs from selected and cascade sets
    // 从选中集合和联动集合中移除所有ID
    state = state.copyWith(
      selectedIds: state.selectedIds
          .where((id) => !idsToUnselect.contains(id))
          .toSet(),
      cascadeIds: state.cascadeIds
          .where((id) => !idsToUnselect.contains(id))
          .toSet(),
    );

    return _cascadeDeltaMessage(
      selectedBefore: selectedBefore,
      selectedAfter: state.allSelectedIds,
      directlyChangedIds: <int>{orderId},
    );
  }

  /// Calculate cascade IDs for selected orders
  /// 计算选中订单的联动ID
  Future<Set<int>> _calculateCascadeIds(Set<int> selectedIds) async {
    if (selectedIds.isEmpty) return <int>{};

    final relations = await _relationsForOrders(selectedIds);
    final invoiceIds = <int>{
      for (final orderId in selectedIds)
        ...(relations[orderId] ?? const <int>{}),
    };
    if (invoiceIds.isEmpty) return <int>{};

    final ordersByInvoice = await _invoiceRepository.getOrderIdsForInvoices(
      invoiceIds.toList(growable: false),
    );
    return <int>{
      for (final invoiceId in invoiceIds)
        ...(ordersByInvoice[invoiceId] ?? const <int>{}),
    };
  }

  /// Get all IDs in the cascade chain for an order
  /// 获取订单关联链中的所有ID
  Future<Set<int>> _getCascadeChainIds(int orderId) async {
    final relations = await _relationsForOrders(<int>{orderId});
    final invoiceIds = relations[orderId] ?? const <int>{};
    if (invoiceIds.isEmpty) return <int>{orderId};

    final ordersByInvoice = await _invoiceRepository.getOrderIdsForInvoices(
      invoiceIds.toList(growable: false),
    );
    return <int>{
      orderId,
      for (final invoiceId in invoiceIds)
        ...(ordersByInvoice[invoiceId] ?? const <int>{}),
    };
  }

  Future<Map<int, Set<int>>> _relationsForOrders(Set<int> orderIds) async {
    final missingIds = orderIds
        .where((orderId) => !state.orderInvoices.containsKey(orderId))
        .toList(growable: false);
    final loaded = missingIds.isEmpty
        ? const <int, Set<int>>{}
        : await _orderRepository.getInvoiceIdsForOrders(missingIds);

    return <int, Set<int>>{
      for (final orderId in orderIds)
        orderId: Set<int>.of(
          state.orderInvoices[orderId] ?? loaded[orderId] ?? const <int>{},
        ),
    };
  }

  /// Select all selectable orders with cascade
  /// 全选所有可选订单并处理联动
  Future<String?> selectAll() async {
    return _enqueueSelection(_selectAll);
  }

  Future<String?> _selectAll() async {
    if (state.isLoading) return null;
    final selectedBefore = state.allSelectedIds;

    // Only select orders that have invoice relations (selectable orders)
    // 只选择有发票关联的订单（可选订单）
    final selectableIds = state.availableOrders
        .where((o) => o.id != null && state.isSelectable(o.id!))
        .map((o) => o.id!)
        .toSet();

    if (selectableIds.isEmpty) return null;

    // Calculate cascade IDs for all selectable orders
    // 计算所有可选订单的联动ID
    final newSelectedIds = <int>{...state.selectedIds, ...selectableIds};
    final cascadeIds = await _calculateCascadeIds(newSelectedIds);

    // Filter out already selected IDs (in this case, all selectable IDs)
    // 过滤掉已直接选中的ID
    final newCascadeIds = cascadeIds
        .where((id) => !newSelectedIds.contains(id))
        .toSet();

    await _cacheCascadeOrders(newCascadeIds);

    state = state.copyWith(
      selectedIds: newSelectedIds,
      cascadeIds: newCascadeIds,
    );

    return _cascadeDeltaMessage(
      selectedBefore: selectedBefore,
      selectedAfter: state.allSelectedIds,
      directlyChangedIds: selectableIds,
    );
  }

  /// Invert selection with cascade (only for selectable orders)
  /// 反选并处理联动（只处理可选订单）
  Future<String?> invertSelection() async {
    return _enqueueSelection(_invertSelection);
  }

  Future<String?> _invertSelection() async {
    if (state.isLoading) return null;
    final selectedBefore = state.allSelectedIds;

    // Only invert orders that have invoice relations (selectable orders)
    // 只反选有发票关联的订单（可选订单）
    final selectableIds = state.availableOrders
        .where((o) => o.id != null && state.isSelectable(o.id!))
        .map((o) => o.id!)
        .toSet();

    if (selectableIds.isEmpty) return null;

    final visibleSelectedIds = selectableIds.where(state.isSelected).toSet();
    final visibleUnselectedIds = selectableIds.difference(visibleSelectedIds);
    final relevantRelations = await _relationsForOrders(<int>{
      ...state.selectedIds,
      ...visibleSelectedIds,
    });
    final invoiceIdsToUnselect = <int>{
      for (final orderId in visibleSelectedIds)
        ...(relevantRelations[orderId] ?? const <int>{}),
    };
    final newSelectedIds = <int>{
      for (final orderId in state.selectedIds)
        if (!visibleSelectedIds.contains(orderId) &&
            (relevantRelations[orderId] ?? const <int>{})
                .intersection(invoiceIdsToUnselect)
                .isEmpty)
          orderId,
      ...visibleUnselectedIds,
    };

    // Calculate cascade IDs for new selection
    // 计算新选中的联动ID
    final cascadeIds = await _calculateCascadeIds(newSelectedIds);
    final newCascadeIds = cascadeIds
        .where((id) => !newSelectedIds.contains(id))
        .toSet();

    // Add cascade orders to available list if not already there
    // 将联动订单添加到可用列表
    await _cacheCascadeOrders(newCascadeIds);

    state = state.copyWith(
      selectedIds: newSelectedIds,
      cascadeIds: newCascadeIds,
    );

    return _cascadeDeltaMessage(
      selectedBefore: selectedBefore,
      selectedAfter: state.allSelectedIds,
      directlyChangedIds: selectableIds,
    );
  }

  String? _cascadeDeltaMessage({
    required Set<int> selectedBefore,
    required Set<int> selectedAfter,
    required Set<int> directlyChangedIds,
  }) {
    final cascadeSelected = selectedAfter
        .difference(selectedBefore)
        .difference(directlyChangedIds);
    final cascadeUnselected = selectedBefore
        .difference(selectedAfter)
        .difference(directlyChangedIds);

    if (cascadeSelected.isNotEmpty && cascadeUnselected.isNotEmpty) {
      return '同票联动：${cascadeSelected.length} 笔选中，'
          '${cascadeUnselected.length} 笔取消';
    }
    if (cascadeSelected.isNotEmpty) {
      return '另有 ${cascadeSelected.length} 笔同票订单一并选中';
    }
    if (cascadeUnselected.isNotEmpty) {
      return '另有 ${cascadeUnselected.length} 笔同票订单一并取消';
    }
    return null;
  }

  /// Get invoice IDs involved in selected orders
  /// 获取选中订单涉及的发票ID集合
  Future<Set<int>> getSelectedInvoiceIds() async {
    final invoiceIds = <int>{};

    for (final orderId in state.allSelectedIds) {
      // Get invoice IDs from cache or query
      // 从缓存或查询获取发票ID
      if (state.orderInvoices.containsKey(orderId)) {
        invoiceIds.addAll(state.orderInvoices[orderId]!);
      } else {
        final ids = await _orderRepository.getInvoiceIdsForOrder(orderId);
        invoiceIds.addAll(ids);
      }
    }

    return invoiceIds;
  }

  /// Calculate total amount of selected orders
  /// 计算选中订单的总金额
  double getSelectedTotalAmount() => state.selectedTotal;

  Future<void> clearSelection() {
    return _enqueueSelection(() async {
      state = state.copyWith(selectedIds: <int>{}, cascadeIds: <int>{});
    });
  }

  Future<T> _enqueueSelection<T>(Future<T> Function() operation) {
    final completer = Completer<T>();

    Future<void> runOperation() async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    }

    _selectionTail = _selectionTail.then<void>(
      (_) => runOperation(),
      onError: (Object _, StackTrace _) => runOperation(),
    );
    return completer.future;
  }

  /// Get count of invoices involved in selected orders
  /// 获取选中订单涉及的发票数量
  Future<int> getInvolvedInvoiceCount() async {
    final invoiceIds = await getSelectedInvoiceIds();
    return invoiceIds.length;
  }

  /// Clear error message
  /// 清除错误消息
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Get invoice count for an order
  /// 获取订单的发票关联数量
  int getInvoiceCount(int orderId) {
    return state.orderInvoiceCount[orderId] ?? 0;
  }

  /// Check if an order has invoice relations
  /// 检查订单是否有发票关联
  bool hasInvoiceRelation(int orderId) {
    return (state.orderInvoiceCount[orderId] ?? 0) > 0;
  }
}

/// Provider for ExportNotifier
/// ExportNotifier Provider
final exportProvider = NotifierProvider<ExportNotifier, ExportState>(() {
  return ExportNotifier();
});

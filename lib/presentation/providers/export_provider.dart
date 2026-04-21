import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/repositories/invoice_repository.dart';

/// Export mode selection
/// 导出模式选择
enum ExportMode {
  /// Export based on invoices
  /// 根据发票导出
  invoices,
  /// Export based on orders
  /// 根据订单导出
  orders,
}

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
    Map<int, int>? orderInvoiceCount,
    Map<int, Set<int>>? orderInvoices,
    this.errorMessage,
  })  : selectedIds = selectedIds ?? const {},
        cascadeIds = cascadeIds ?? const {},
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
      orderInvoiceCount: orderInvoiceCount ?? this.orderInvoiceCount,
      orderInvoices: orderInvoices ?? this.orderInvoices,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  /// Get total selected count (including cascade)
  /// 获取总选中数量（包含联动选中）
  int get totalSelectedCount => selectedIds.length + cascadeIds.length;

  /// Check if an order is selected (directly or cascade)
  /// 检查订单是否被选中（直接选中或联动选中）
  bool isSelected(int id) => selectedIds.contains(id) || cascadeIds.contains(id);

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
  @override
  ExportState build() {
    return const ExportState();
  }

  OrderRepository get _orderRepository => ref.read(orderRepositoryProvider);
  InvoiceRepository get _invoiceRepository => ref.read(invoiceRepositoryProvider);

  /// Load available orders and their invoice relations
  /// 加载可用订单及其发票关联信息
  Future<void> loadAvailableOrders() async {
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

      // Build invoice count and invoice ID maps
      // 构建发票数量和发票ID映射
      final orderInvoiceCount = <int, int>{};
      final orderInvoices = <int, Set<int>>{};

      for (final order in orders) {
        if (order.id != null) {
          final invoiceIds = await _orderRepository.getInvoiceIdsForOrder(order.id!);
          orderInvoiceCount[order.id!] = invoiceIds.length;
          orderInvoices[order.id!] = invoiceIds.toSet();
        }
      }

      state = state.copyWith(
        availableOrders: orders,
        orderInvoiceCount: orderInvoiceCount,
        orderInvoices: orderInvoices,
        isLoading: false,
        selectedIds: {},
        cascadeIds: {},
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Set date range filter
  /// 设置日期范围筛选
  void setDateRange(DateTime? startDate, DateTime? endDate) {
    state = state.copyWith(
      startDate: startDate,
      endDate: endDate,
      clearError: true,
    );
    loadAvailableOrders();
  }

  /// Clear date range filter
  /// 清除日期范围筛选
  void clearDateRange() {
    state = state.copyWith(clearDateRange: true);
    loadAvailableOrders();
  }

  /// Toggle selection for an order
  /// Returns cascade message if any items were cascade selected/unselected
  /// 切换订单选中状态，返回联动勾选提示消息
  Future<String?> toggleSelection(int orderId) async {
    if (state.cascadeIds.contains(orderId)) {
      // Cascade selected item: unselect entire cascade chain
      // 联动选中项：取消整个关联链
      return await _unselectCascadeChain(orderId);
    } else if (state.selectedIds.contains(orderId)) {
      // Directly selected item: unselect entire cascade chain
      // 直接选中项：取消整个关联链
      return await _unselectCascadeChain(orderId);
    } else {
      // Not selected: select it and cascade
      // 未选中：选中并联动
      return await _selectWithCascade(orderId);
    }
  }

  /// Select an order with cascade
  /// 选中订单并联动勾选关联订单
  Future<String?> _selectWithCascade(int orderId) async {
    // Add to selected IDs
    // 添加到直接选中集合
    final newSelectedIds = {...state.selectedIds, orderId};

    // Calculate cascade IDs for all selected orders
    // 计算所有选中订单的联动ID
    final cascadeIds = await _calculateCascadeIds(newSelectedIds);

    // Filter out already selected IDs
    // 过滤掉已直接选中的ID
    final newCascadeIds = cascadeIds.where((id) => !newSelectedIds.contains(id)).toSet();

    // Add cascade orders to available list if not already there
    // 将联动订单添加到可用列表（如果尚未存在）
    await _addCascadeOrdersToList(newCascadeIds);

    state = state.copyWith(
      selectedIds: newSelectedIds,
      cascadeIds: newCascadeIds,
    );

    if (newCascadeIds.isNotEmpty) {
      return '有${newCascadeIds.length}条订单被一并勾选（关联了同一张发票）';
    }
    return null;
  }

  /// Add cascade orders to the available list
  /// 将联动订单添加到可用列表
  Future<void> _addCascadeOrdersToList(Set<int> cascadeIds) async {
    if (cascadeIds.isEmpty) return;

    // Find cascade orders not in available list
    // 找出不在可用列表中的联动订单
    final availableIds = state.availableOrders
        .where((o) => o.id != null)
        .map((o) => o.id!)
        .toSet();
    final missingIds = cascadeIds.where((id) => !availableIds.contains(id));

    if (missingIds.isEmpty) return;

    // Fetch missing orders and add to list
    // 获取缺失的订单并添加到列表
    final List<Order> newOrders = [];
    final Map<int, int> newInvoiceCounts = {};
    final Map<int, Set<int>> newInvoices = {};

    for (final orderId in missingIds) {
      final order = await _orderRepository.getById(orderId);
      if (order != null && order.id != null) {
        newOrders.add(order);
        final invoiceIds = await _orderRepository.getInvoiceIdsForOrder(orderId);
        newInvoiceCounts[orderId] = invoiceIds.length;
        newInvoices[orderId] = invoiceIds.toSet();
      }
    }

    state = state.copyWith(
      availableOrders: [...state.availableOrders, ...newOrders],
      orderInvoiceCount: {...state.orderInvoiceCount, ...newInvoiceCounts},
      orderInvoices: {...state.orderInvoices, ...newInvoices},
    );
  }

  /// Unselect cascade chain for an order
  /// 取消订单的整个关联链
  Future<String?> _unselectCascadeChain(int orderId) async {
    // Get all IDs in the cascade chain
    // 获取关联链中的所有ID
    final idsToUnselect = await _getCascadeChainIds(orderId);

    // Calculate cascade count (excluding the target order itself)
    // 计算联动取消数量（不含目标订单本身）
    final cascadeCount = idsToUnselect.length - 1;

    // Remove all IDs from selected and cascade sets
    // 从选中集合和联动集合中移除所有ID
    state = state.copyWith(
      selectedIds: state.selectedIds.where((id) => !idsToUnselect.contains(id)).toSet(),
      cascadeIds: state.cascadeIds.where((id) => !idsToUnselect.contains(id)).toSet(),
    );

    if (cascadeCount > 0) {
      return '有$cascadeCount条订单被一并取消勾选';
    }
    return null;
  }

  /// Calculate cascade IDs for selected orders
  /// 计算选中订单的联动ID
  Future<Set<int>> _calculateCascadeIds(Set<int> selectedIds) async {
    final cascadeIds = <int>{};

    // For each selected order, find orders sharing the same invoices
    // 对每个选中的订单，找出共享同一发票的订单
    for (final orderId in selectedIds) {
      // Get invoice IDs for this order (from cache or query)
      // 获取此订单的发票ID（从缓存或查询）
      Set<int> invoiceIds;
      if (state.orderInvoices.containsKey(orderId)) {
        invoiceIds = state.orderInvoices[orderId]!;
      } else {
        final ids = await _orderRepository.getInvoiceIdsForOrder(orderId);
        invoiceIds = ids.toSet();
      }

      // For each invoice, get all linked orders
      // 对每个发票，获取所有关联订单
      for (final invoiceId in invoiceIds) {
        final linkedOrderIds = await _invoiceRepository.getOrderIdsForInvoice(invoiceId);
        cascadeIds.addAll(linkedOrderIds);
      }
    }

    return cascadeIds;
  }

  /// Get all IDs in the cascade chain for an order
  /// 获取订单关联链中的所有ID
  Future<Set<int>> _getCascadeChainIds(int orderId) async {
    final chainIds = <int>{orderId};

    // Get invoice IDs for this order
    // 获取此订单的发票ID
    Set<int> invoiceIds;
    if (state.orderInvoices.containsKey(orderId)) {
      invoiceIds = state.orderInvoices[orderId]!;
    } else {
      final ids = await _orderRepository.getInvoiceIdsForOrder(orderId);
      invoiceIds = ids.toSet();
    }

    // For each invoice, get all linked orders
    // 对每个发票，获取所有关联订单
    for (final invoiceId in invoiceIds) {
      final linkedOrderIds = await _invoiceRepository.getOrderIdsForInvoice(invoiceId);
      chainIds.addAll(linkedOrderIds);
    }

    return chainIds;
  }

  /// Select all selectable orders with cascade
  /// 全选所有可选订单并处理联动
  Future<String?> selectAll() async {
    // Only select orders that have invoice relations (selectable orders)
    // 只选择有发票关联的订单（可选订单）
    final selectableIds = state.availableOrders
        .where((o) => o.id != null && state.isSelectable(o.id!))
        .map((o) => o.id!)
        .toSet();

    if (selectableIds.isEmpty) return null;

    // Calculate cascade IDs for all selectable orders
    // 计算所有可选订单的联动ID
    final cascadeIds = await _calculateCascadeIds(selectableIds);

    // Filter out already selected IDs (in this case, all selectable IDs)
    // 过滤掉已直接选中的ID
    final newCascadeIds = cascadeIds.where((id) => !selectableIds.contains(id)).toSet();

    state = state.copyWith(
      selectedIds: selectableIds,
      cascadeIds: newCascadeIds,
    );

    if (newCascadeIds.isNotEmpty) {
      return '有${newCascadeIds.length}条订单被一并勾选（关联了同一张发票）';
    }
    return null;
  }

  /// Invert selection with cascade (only for selectable orders)
  /// 反选并处理联动（只处理可选订单）
  Future<String?> invertSelection() async {
    // Only invert orders that have invoice relations (selectable orders)
    // 只反选有发票关联的订单（可选订单）
    final selectableIds = state.availableOrders
        .where((o) => o.id != null && state.isSelectable(o.id!))
        .map((o) => o.id!)
        .toSet();

    if (selectableIds.isEmpty) return null;

    // Invert selection: select unselected, unselect selected
    // 反选：选中未选中的，取消已选中的
    final newSelectedIds = selectableIds.where((id) => !state.isSelected(id)).toSet();

    // Calculate cascade IDs for new selection
    // 计算新选中的联动ID
    final cascadeIds = await _calculateCascadeIds(newSelectedIds);
    final newCascadeIds = cascadeIds.where((id) => !newSelectedIds.contains(id)).toSet();

    // Add cascade orders to available list if not already there
    // 将联动订单添加到可用列表
    await _addCascadeOrdersToList(newCascadeIds);

    state = state.copyWith(
      selectedIds: newSelectedIds,
      cascadeIds: newCascadeIds,
    );

    if (newCascadeIds.isNotEmpty) {
      return '有${newCascadeIds.length}条订单被一并勾选（关联了同一张发票）';
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
  double getSelectedTotalAmount() {
    double total = 0.0;

    for (final order in state.availableOrders) {
      if (order.id != null && state.isSelected(order.id!)) {
        total += order.amount;
      }
    }

    return total;
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

/// Provider for OrderRepository
/// OrderRepository Provider
final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository();
});

/// Provider for InvoiceRepository
/// InvoiceRepository Provider
final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  return InvoiceRepository();
});

/// Provider for ExportNotifier
/// ExportNotifier Provider
final exportProvider = NotifierProvider<ExportNotifier, ExportState>(() {
  return ExportNotifier();
});
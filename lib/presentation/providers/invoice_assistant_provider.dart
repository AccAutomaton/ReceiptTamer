import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/data/models/uninvoiced_shop_summary.dart';
import 'package:receipt_tamer/data/repositories/order_repository.dart';
import 'package:receipt_tamer/presentation/providers/order_provider.dart';

const _unset = Object();

class InvoiceAssistantState {
  final List<UninvoicedShopSummary> summaries;
  final Map<String, List<Order>> ordersByShop;
  final Set<String> loadingShopKeys;
  final Set<int> selectedOrderIds;
  final bool isLoadingSummaries;
  final String? errorMessage;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? expandedShopKey;
  final String? selectedShopKey;
  final double selectedTotalAmount;

  const InvoiceAssistantState({
    this.summaries = const [],
    this.ordersByShop = const {},
    this.loadingShopKeys = const {},
    this.selectedOrderIds = const {},
    this.isLoadingSummaries = false,
    this.errorMessage,
    this.startDate,
    this.endDate,
    this.expandedShopKey,
    this.selectedShopKey,
    this.selectedTotalAmount = 0,
  });

  bool get hasSelection => selectedOrderIds.isNotEmpty;

  InvoiceAssistantState copyWith({
    List<UninvoicedShopSummary>? summaries,
    Map<String, List<Order>>? ordersByShop,
    Set<String>? loadingShopKeys,
    Set<int>? selectedOrderIds,
    bool? isLoadingSummaries,
    Object? errorMessage = _unset,
    Object? startDate = _unset,
    Object? endDate = _unset,
    Object? expandedShopKey = _unset,
    Object? selectedShopKey = _unset,
    double? selectedTotalAmount,
  }) {
    return InvoiceAssistantState(
      summaries: summaries ?? this.summaries,
      ordersByShop: ordersByShop ?? this.ordersByShop,
      loadingShopKeys: loadingShopKeys ?? this.loadingShopKeys,
      selectedOrderIds: selectedOrderIds ?? this.selectedOrderIds,
      isLoadingSummaries: isLoadingSummaries ?? this.isLoadingSummaries,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
      startDate: startDate == _unset ? this.startDate : startDate as DateTime?,
      endDate: endDate == _unset ? this.endDate : endDate as DateTime?,
      expandedShopKey: expandedShopKey == _unset
          ? this.expandedShopKey
          : expandedShopKey as String?,
      selectedShopKey: selectedShopKey == _unset
          ? this.selectedShopKey
          : selectedShopKey as String?,
      selectedTotalAmount: selectedTotalAmount ?? this.selectedTotalAmount,
    );
  }
}

class InvoiceAssistantNotifier extends Notifier<InvoiceAssistantState> {
  @override
  InvoiceAssistantState build() {
    return const InvoiceAssistantState();
  }

  OrderRepository get _repository => ref.watch(orderRepositoryProvider);

  Future<void> loadSummaries({DateTime? startDate, DateTime? endDate}) async {
    final effectiveStartDate = startDate ?? state.startDate;
    final effectiveEndDate = endDate ?? state.endDate;

    state = state.copyWith(
      isLoadingSummaries: true,
      errorMessage: null,
      startDate: effectiveStartDate,
      endDate: effectiveEndDate,
      expandedShopKey: null,
      ordersByShop: const {},
      selectedOrderIds: const {},
      selectedShopKey: null,
      selectedTotalAmount: 0,
    );

    try {
      final summaries = await _repository.getUninvoicedShopSummaries(
        startDate: effectiveStartDate,
        endDate: effectiveEndDate,
      );
      state = state.copyWith(summaries: summaries, isLoadingSummaries: false);
    } catch (e) {
      state = state.copyWith(
        isLoadingSummaries: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> setDateRange(DateTime startDate, DateTime endDate) {
    return loadSummaries(startDate: startDate, endDate: endDate);
  }

  Future<void> clearDateRange() async {
    state = state.copyWith(startDate: null, endDate: null);
    await loadSummaries(startDate: null, endDate: null);
  }

  Future<void> loadOrdersForShop(String shopKey) async {
    if (state.expandedShopKey == shopKey &&
        state.ordersByShop.containsKey(shopKey)) {
      state = state.copyWith(expandedShopKey: null);
      return;
    }

    state = state.copyWith(
      expandedShopKey: shopKey,
      loadingShopKeys: {...state.loadingShopKeys, shopKey},
      errorMessage: null,
    );

    try {
      final orders = await _repository.getUninvoicedOrdersForShop(
        shopKey,
        startDate: state.startDate,
        endDate: state.endDate,
      );
      final updatedOrdersByShop = {...state.ordersByShop, shopKey: orders};
      final updatedLoadingKeys = {...state.loadingShopKeys}..remove(shopKey);
      state = state.copyWith(
        ordersByShop: updatedOrdersByShop,
        loadingShopKeys: updatedLoadingKeys,
        expandedShopKey: shopKey,
      );
    } catch (e) {
      final updatedLoadingKeys = {...state.loadingShopKeys}..remove(shopKey);
      state = state.copyWith(
        loadingShopKeys: updatedLoadingKeys,
        errorMessage: e.toString(),
      );
    }
  }

  void toggleOrderSelection({required String shopKey, required Order order}) {
    final orderId = order.id;
    if (orderId == null) return;

    final selectedIds = state.selectedShopKey == shopKey
        ? {...state.selectedOrderIds}
        : <int>{};

    if (selectedIds.contains(orderId)) {
      selectedIds.remove(orderId);
    } else {
      selectedIds.add(orderId);
    }

    state = _selectionState(shopKey, selectedIds);
  }

  void selectAllForShop(String shopKey) {
    final orderIds =
        state.ordersByShop[shopKey]
            ?.map((order) => order.id)
            .whereType<int>()
            .toSet() ??
        <int>{};
    state = _selectionState(shopKey, orderIds);
  }

  void clearSelection() {
    state = state.copyWith(
      selectedOrderIds: const {},
      selectedShopKey: null,
      selectedTotalAmount: 0,
    );
  }

  InvoiceAssistantState _selectionState(String shopKey, Set<int> orderIds) {
    if (orderIds.isEmpty) {
      return state.copyWith(
        selectedOrderIds: const {},
        selectedShopKey: null,
        selectedTotalAmount: 0,
      );
    }

    final totalAmount = (state.ordersByShop[shopKey] ?? const <Order>[])
        .where((order) => order.id != null && orderIds.contains(order.id))
        .fold<double>(0, (sum, order) => sum + order.amount);

    return state.copyWith(
      selectedOrderIds: orderIds,
      selectedShopKey: shopKey,
      selectedTotalAmount: totalAmount,
    );
  }
}

final invoiceAssistantProvider =
    NotifierProvider<InvoiceAssistantNotifier, InvoiceAssistantState>(
      InvoiceAssistantNotifier.new,
    );

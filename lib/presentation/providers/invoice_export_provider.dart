import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/log_config.dart';
import '../../core/services/log_service.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/invoice.dart';
import '../../data/repositories/invoice_repository.dart';
import 'invoice_provider.dart' as invoice_providers;

/// 发票作为报销导出依据时的进程内选择状态。
class InvoiceExportState {
  const InvoiceExportState({
    this.startDate,
    this.endDate,
    this.selectedInvoiceIds = const <int>{},
    this.selectedOrderIds = const <int>{},
    this.availableInvoices = const <Invoice>[],
    this.orderIdsByInvoice = const <int, Set<int>>{},
    this.isLoading = false,
    this.isInitialized = false,
    this.errorMessage,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final Set<int> selectedInvoiceIds;
  final Set<int> selectedOrderIds;
  final List<Invoice> availableInvoices;
  final Map<int, Set<int>> orderIdsByInvoice;
  final bool isLoading;
  final bool isInitialized;
  final String? errorMessage;

  bool get hasDateRange => startDate != null && endDate != null;

  int get selectableCount => availableInvoices.where((invoice) {
    final id = invoice.id;
    return id != null && isSelectable(id);
  }).length;

  double get selectedTotal => availableInvoices
      .where((invoice) => selectedInvoiceIds.contains(invoice.id))
      .fold(0, (sum, invoice) => sum + invoice.totalAmount);

  bool isSelectable(int invoiceId) =>
      (orderIdsByInvoice[invoiceId]?.isNotEmpty ?? false);

  bool isSelected(int invoiceId) => selectedInvoiceIds.contains(invoiceId);

  int orderCountFor(int invoiceId) => orderIdsByInvoice[invoiceId]?.length ?? 0;

  InvoiceExportState copyWith({
    DateTime? startDate,
    DateTime? endDate,
    Set<int>? selectedInvoiceIds,
    Set<int>? selectedOrderIds,
    List<Invoice>? availableInvoices,
    Map<int, Set<int>>? orderIdsByInvoice,
    bool? isLoading,
    bool? isInitialized,
    String? errorMessage,
    bool clearDateRange = false,
    bool clearError = false,
  }) {
    return InvoiceExportState(
      startDate: clearDateRange ? null : (startDate ?? this.startDate),
      endDate: clearDateRange ? null : (endDate ?? this.endDate),
      selectedInvoiceIds: selectedInvoiceIds ?? this.selectedInvoiceIds,
      selectedOrderIds: selectedOrderIds ?? this.selectedOrderIds,
      availableInvoices: availableInvoices ?? this.availableInvoices,
      orderIdsByInvoice: orderIdsByInvoice ?? this.orderIdsByInvoice,
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class InvoiceExportNotifier extends Notifier<InvoiceExportState> {
  @override
  InvoiceExportState build() => const InvoiceExportState();

  InvoiceRepository get _repository =>
      ref.read(invoice_providers.invoiceRepositoryProvider);

  Future<void> loadAvailableInvoices() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final invoices = state.hasDateRange
          ? await _repository.getByDateRange(state.startDate!, state.endDate!)
          : await _repository.getAll();
      final sortedInvoices = invoices.toList()
        ..sort((left, right) {
          final leftDate = DateFormatter.resolveLedgerDate(
            businessDate: left.invoiceDate,
            createdAt: left.createdAt,
          );
          final rightDate = DateFormatter.resolveLedgerDate(
            businessDate: right.invoiceDate,
            createdAt: right.createdAt,
          );
          if (leftDate == null && rightDate == null) return 0;
          if (leftDate == null) return 1;
          if (rightDate == null) return -1;
          return rightDate.compareTo(leftDate);
        });
      final invoiceIds = sortedInvoices
          .map((invoice) => invoice.id)
          .whereType<int>()
          .toList(growable: false);
      final orderIdsByInvoice = await _repository.getOrderIdsForInvoices(
        invoiceIds,
      );

      state = state.copyWith(
        availableInvoices: sortedInvoices,
        orderIdsByInvoice: orderIdsByInvoice,
        selectedInvoiceIds: <int>{},
        selectedOrderIds: <int>{},
        isLoading: false,
        isInitialized: true,
        clearError: true,
      );
    } catch (error, stackTrace) {
      logService.e(LogConfig.moduleUi, '加载报销发票选择列表失败', error, stackTrace);
      state = state.copyWith(
        isLoading: false,
        isInitialized: true,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> setDateRange(DateTime startDate, DateTime endDate) async {
    state = state.copyWith(
      startDate: startDate,
      endDate: endDate,
      clearError: true,
    );
    await loadAvailableInvoices();
  }

  Future<void> clearDateRange() async {
    state = state.copyWith(clearDateRange: true, clearError: true);
    await loadAvailableInvoices();
  }

  void toggleSelection(int invoiceId) {
    if (!state.isSelectable(invoiceId)) return;

    final selected = Set<int>.of(state.selectedInvoiceIds);
    if (!selected.add(invoiceId)) selected.remove(invoiceId);
    _setSelection(selected);
  }

  void selectAll() {
    _setSelection({
      for (final invoice in state.availableInvoices)
        if (invoice.id case final int id when state.isSelectable(id)) id,
    });
  }

  void invertSelection() {
    _setSelection({
      for (final invoice in state.availableInvoices)
        if (invoice.id case final int id
            when state.isSelectable(id) && !state.isSelected(id))
          id,
    });
  }

  void selectHighestAmounts(int count) {
    final selectable =
        state.availableInvoices.where((invoice) {
          final id = invoice.id;
          return id != null && state.isSelectable(id);
        }).toList()..sort(
          (left, right) => right.totalAmount.compareTo(left.totalAmount),
        );
    _setSelection({for (final invoice in selectable.take(count)) invoice.id!});
  }

  void _setSelection(Set<int> selectedInvoiceIds) {
    final selectedOrderIds = <int>{};
    for (final invoiceId in selectedInvoiceIds) {
      selectedOrderIds.addAll(
        state.orderIdsByInvoice[invoiceId] ?? const <int>{},
      );
    }
    state = state.copyWith(
      selectedInvoiceIds: selectedInvoiceIds,
      selectedOrderIds: selectedOrderIds,
    );
  }
}

final invoiceExportProvider =
    NotifierProvider<InvoiceExportNotifier, InvoiceExportState>(
      InvoiceExportNotifier.new,
    );

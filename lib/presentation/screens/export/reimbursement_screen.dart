import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_design_tokens.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/invoice.dart';
import '../../../data/models/order.dart';
import '../../providers/export_provider.dart';
import '../../providers/invoice_export_provider.dart';
import '../../providers/ledger_data_revision_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_notice.dart';
import '../../widgets/common/date_range_picker.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/floating_overlay_layout.dart';
import '../../widgets/common/glass_navigation_bar.dart';
import '../../widgets/common/ledger_month_sheet.dart';
import 'saved_files_screen.dart';

enum _ReimbursementExportBasis { orders, invoices }

String _dateRangeFilterLabel(DateTime startDate, DateTime endDate) {
  final start = '${startDate.year}/${startDate.month}/${startDate.day}';
  final end = startDate.year == endDate.year
      ? '${endDate.month}/${endDate.day}'
      : '${endDate.year}/${endDate.month}/${endDate.day}';
  return '$start—$end';
}

extension on _ReimbursementExportBasis {
  String get label => switch (this) {
    _ReimbursementExportBasis.orders => '按订单导出',
    _ReimbursementExportBasis.invoices => '按发票导出',
  };

  String get subtitle => switch (this) {
    _ReimbursementExportBasis.orders => '同票订单一并选中',
    _ReimbursementExportBasis.invoices => '关联订单自动带入',
  };

  IconData get icon => switch (this) {
    _ReimbursementExportBasis.orders => Icons.receipt_long_outlined,
    _ReimbursementExportBasis.invoices => Icons.description_outlined,
  };
}

/// 报销材料选择页。
///
/// 报销范围只由用户在本页勾选的记录决定；日期仅是可选列表筛选条件，
/// 不会建立或保存固定分期。
class ReimbursementScreen extends ConsumerStatefulWidget {
  const ReimbursementScreen({super.key});

  @override
  ConsumerState<ReimbursementScreen> createState() =>
      _ReimbursementScreenState();
}

class _ReimbursementScreenState extends ConsumerState<ReimbursementScreen> {
  _ReimbursementExportBasis _basis = _ReimbursementExportBasis.orders;
  final Set<_ReimbursementExportBasis> _loadedBases = {};
  final Map<_ReimbursementExportBasis, Future<void>> _basisOperationTails = {};
  final Set<_ReimbursementExportBasis> _queuedAutomaticReloads = {};
  AppNoticeHandle? _cascadeNoticeHandle;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual<int>(ledgerDataRevisionProvider, (previous, next) {
      if (previous != null && previous != next) {
        _handleSourceDataChanged();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_ensureBasisLoaded(_ReimbursementExportBasis.orders));
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _queuedAutomaticReloads.clear();
    _cascadeNoticeHandle?.dismiss();
    super.dispose();
  }

  Future<void> _ensureBasisLoaded(_ReimbursementExportBasis basis) async {
    if (_isDisposed || _loadedBases.contains(basis)) return;
    _loadedBases.add(basis);
    await _enqueueBasisOperation(basis, () => _loadBasis(basis));
  }

  Future<void> _loadBasis(
    _ReimbursementExportBasis basis, {
    bool clearSelection = false,
  }) async {
    if (_isDisposed) return;

    switch (basis) {
      case _ReimbursementExportBasis.orders:
        await ref
            .read(exportProvider.notifier)
            .loadAvailableOrders(clearSelection: clearSelection);
      case _ReimbursementExportBasis.invoices:
        await ref
            .read(invoiceExportProvider.notifier)
            .loadAvailableInvoices(clearSelection: clearSelection);
    }
  }

  void _handleSourceDataChanged() {
    if (_isDisposed) return;

    for (final basis in _loadedBases.toList(growable: false)) {
      _queueAutomaticReload(basis);
    }
  }

  void _queueAutomaticReload(_ReimbursementExportBasis basis) {
    if (_isDisposed || !_queuedAutomaticReloads.add(basis)) return;

    final reload = _enqueueBasisOperation(basis, () async {
      _queuedAutomaticReloads.remove(basis);
      if (_isDisposed || !_loadedBases.contains(basis)) return;
      await _loadBasis(basis, clearSelection: true);
    });
    unawaited(reload.catchError((Object _, StackTrace _) {}));
  }

  Future<void> _enqueueBasisOperation(
    _ReimbursementExportBasis basis,
    Future<void> Function() operation,
  ) {
    if (_isDisposed) return Future<void>.value();

    final previous = _basisOperationTails[basis] ?? Future<void>.value();
    Future<void> runOperation() async {
      if (!_isDisposed) await operation();
    }

    final current = previous.then<void>(
      (_) => runOperation(),
      onError: (Object _, StackTrace _) => runOperation(),
    );
    _basisOperationTails[basis] = current;

    void clearTail() {
      if (identical(_basisOperationTails[basis], current)) {
        _basisOperationTails.remove(basis);
      }
    }

    unawaited(
      current.then<void>(
        (_) => clearTail(),
        onError: (Object _, StackTrace _) => clearTail(),
      ),
    );
    return current;
  }

  void _changeBasis(_ReimbursementExportBasis basis) {
    if (_basis == basis) return;
    setState(() => _basis = basis);
    unawaited(_ensureBasisLoaded(basis));
  }

  Future<void> _refresh() async {
    final basis = _basis;
    await _enqueueBasisOperation(basis, () => _loadBasis(basis));
  }

  Future<void> _chooseDateRange() async {
    final (startDate, endDate) = switch (_basis) {
      _ReimbursementExportBasis.orders => (
        ref.read(exportProvider).startDate,
        ref.read(exportProvider).endDate,
      ),
      _ReimbursementExportBasis.invoices => (
        ref.read(invoiceExportProvider).startDate,
        ref.read(invoiceExportProvider).endDate,
      ),
    };
    final result = await SyncfusionDateRangePicker.show(
      context,
      initialStartDate: startDate,
      initialEndDate: endDate,
    );
    if (result == null || !mounted) return;

    final basis = _basis;
    await _enqueueBasisOperation(basis, () async {
      switch (basis) {
        case _ReimbursementExportBasis.orders:
          await ref
              .read(exportProvider.notifier)
              .setDateRange(result.startDate, result.endDate);
        case _ReimbursementExportBasis.invoices:
          await ref
              .read(invoiceExportProvider.notifier)
              .setDateRange(result.startDate, result.endDate);
      }
    });
  }

  Future<void> _clearDateRange() async {
    final basis = _basis;
    await _enqueueBasisOperation(basis, () async {
      switch (basis) {
        case _ReimbursementExportBasis.orders:
          await ref.read(exportProvider.notifier).clearDateRange();
        case _ReimbursementExportBasis.invoices:
          await ref.read(invoiceExportProvider.notifier).clearDateRange();
      }
    });
  }

  Future<void> _toggleOrder(int orderId) =>
      _runOrderSelection((notifier) => notifier.toggleSelection(orderId));

  Future<void> _selectAllOrders() =>
      _runOrderSelection((notifier) => notifier.selectAll());

  Future<void> _invertOrders() =>
      _runOrderSelection((notifier) => notifier.invertSelection());

  Future<void> _runOrderSelection(
    Future<String?> Function(ExportNotifier notifier) operation,
  ) async {
    String? message;
    await _enqueueBasisOperation(_ReimbursementExportBasis.orders, () async {
      message = await operation(ref.read(exportProvider.notifier));
    });
    _showCascadeMessage(message);
  }

  Future<void> _toggleInvoice(int invoiceId) {
    return _enqueueBasisOperation(_ReimbursementExportBasis.invoices, () async {
      ref.read(invoiceExportProvider.notifier).toggleSelection(invoiceId);
    });
  }

  Future<void> _clearSelection() async {
    final basis = _basis;
    await _enqueueBasisOperation(basis, () async {
      switch (basis) {
        case _ReimbursementExportBasis.orders:
          await ref.read(exportProvider.notifier).clearSelection();
        case _ReimbursementExportBasis.invoices:
          ref.read(invoiceExportProvider.notifier).clearSelection();
      }
    });
    _showCascadeMessage(null);
  }

  void _showCascadeMessage(String? message) {
    if (!mounted) return;
    if (message == null) {
      _cascadeNoticeHandle?.dismiss();
      _cascadeNoticeHandle = null;
      return;
    }
    _cascadeNoticeHandle?.dismiss();
    _cascadeNoticeHandle = AppNotice.show(
      context,
      message,
      tone: AppNoticeTone.linkage,
      duration: AppNotice.linkageDuration,
      noticeKey: const ValueKey('reimbursement-cascade-notice'),
    );
  }

  void _continueToOptions() {
    final (invoiceIds, orderIds) = switch (_basis) {
      _ReimbursementExportBasis.orders => (
        ref.read(exportProvider).selectedInvoiceIds.toList()..sort(),
        ref.read(exportProvider).allSelectedIds.toList()..sort(),
      ),
      _ReimbursementExportBasis.invoices => (
        ref.read(invoiceExportProvider).selectedInvoiceIds.toList()..sort(),
        ref.read(invoiceExportProvider).selectedOrderIds.toList()..sort(),
      ),
    };
    if (invoiceIds.isEmpty || orderIds.isEmpty) return;

    context.pushNamed(
      'export_options',
      queryParameters: {
        'invoiceIds': invoiceIds.join(','),
        'orderIds': orderIds.join(','),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(exportProvider);
    final invoiceState = ref.watch(invoiceExportProvider);
    final textScale = AppTypography.accessibilityScaleOf(context);

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        titleSpacing: 0,
        toolbarHeight: textScale >= 1.6 ? 96 : 74,
        title: _ReimbursementTitleBar(basis: _basis, onChanged: _changeBasis),
      ),
      body: FloatingOverlayLayout(
        wrapTopInSurface: false,
        wrapBottomInSurface: false,
        topMargin: const EdgeInsets.fromLTRB(14, 6, 14, 0),
        bottomMargin: EdgeInsets.fromLTRB(
          14,
          0,
          14,
          _selectionBarBottomMargin(context),
        ),
        top: _SelectionControls(
          basis: _basis,
          orderState: orderState,
          invoiceState: invoiceState,
          onSelectAllOrders: _selectAllOrders,
          onInvertOrders: _invertOrders,
          onSelectAllInvoices: () =>
              ref.read(invoiceExportProvider.notifier).selectAll(),
          onInvertInvoices: () =>
              ref.read(invoiceExportProvider.notifier).invertSelection(),
          onChooseDate: _chooseDateRange,
          onClearDate: _clearDateRange,
          onClearSelection: _clearSelection,
          onOpenHistory: () =>
              showSavedFilesScreen(context, initialSubDir: 'materials'),
        ),
        bottom: _SelectionBar(
          basis: _basis,
          orderState: orderState,
          invoiceState: invoiceState,
          onContinue: _continueToOptions,
        ),
        bodyBuilder: (context, contentPadding) {
          return Padding(
            padding: EdgeInsets.only(
              top: contentPadding.top,
              bottom: contentPadding.bottom,
            ),
            child: AnimatedSwitcher(
              duration: AppMotion.adaptive(context, AppMotion.standard),
              child: _basis == _ReimbursementExportBasis.orders
                  ? _OrderSelectionLedger(
                      key: const ValueKey('reimbursement-order-ledger'),
                      state: orderState,
                      onRefresh: _refresh,
                      onToggle: _toggleOrder,
                    )
                  : _InvoiceSelectionLedger(
                      key: const ValueKey('reimbursement-invoice-ledger'),
                      state: invoiceState,
                      onRefresh: _refresh,
                      onToggle: _toggleInvoice,
                    ),
            ),
          );
        },
      ),
    );
  }

  double _selectionBarBottomMargin(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 360;
    final dockHeight = compact
        ? GlassNavigationBar.compactIslandHeight
        : GlassNavigationBar.islandHeight;
    final minimumBottomInset = compact ? 10.0 : 12.0;
    final safeBottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final missingMinimumInset = safeBottomInset < minimumBottomInset
        ? minimumBottomInset - safeBottomInset
        : 0.0;
    return dockHeight + GlassNavigationBar.contentFadeGap + missingMinimumInset;
  }
}

class _ReimbursementTitleBar extends StatelessWidget {
  const _ReimbursementTitleBar({required this.basis, required this.onChanged});

  final _ReimbursementExportBasis basis;
  final ValueChanged<_ReimbursementExportBasis> onChanged;

  Future<void> _showBasisPicker(BuildContext context) async {
    final view = View.of(context);
    final safeTop = view.padding.top / view.devicePixelRatio;
    final textScale = AppTypography.accessibilityScaleOf(context);
    final toolbarHeight = textScale >= 1.6 ? 96.0 : 74.0;
    final pickerTop = safeTop + (toolbarHeight - 56) / 2 + 56;
    final selected = await showGeneralDialog<_ReimbursementExportBasis>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭导出依据选择',
      barrierColor: Colors.transparent,
      transitionDuration: AppMotion.adaptive(context, AppMotion.fast),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Material(
          type: MaterialType.transparency,
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: pickerTop),
              child: _BasisPickerCard(current: basis),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.035),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 16,
            child: AppTypography.preserveOriginalSize(
              child: Text(
                '报销',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: AppPalette.textPrimaryFor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Center(
            child: Semantics(
              button: true,
              label: '${basis.label}，切换导出依据',
              child: Tooltip(
                message: '切换导出依据',
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadii.control),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: const ValueKey('reimbursement-export-basis'),
                    onTap: () => _showBasisPicker(context),
                    child: SizedBox(
                      width: 156,
                      height: 48,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              basis.label,
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                              softWrap: false,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: AppPalette.textPrimaryFor(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 19,
                            color: AppPalette.textPrimaryFor(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BasisPickerCard extends StatelessWidget {
  const _BasisPickerCard({required this.current});

  final _ReimbursementExportBasis current;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width - 48)
        .clamp(220.0, 252.0)
        .toDouble();

    return Material(
      color: AppEntityTokens.fillFor(context),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: BorderSide(color: AppEntityTokens.strongBorderFor(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        key: const ValueKey('reimbursement-basis-picker'),
        width: width,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (
                var index = 0;
                index < _ReimbursementExportBasis.values.length;
                index++
              ) ...[
                if (index > 0) const SizedBox(height: 2),
                _BasisMenuOption(
                  key: ValueKey(
                    'reimbursement-basis-${_ReimbursementExportBasis.values[index].name}',
                  ),
                  option: _ReimbursementExportBasis.values[index],
                  selected: _ReimbursementExportBasis.values[index] == current,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BasisMenuOption extends StatelessWidget {
  const _BasisMenuOption({
    super.key,
    required this.option,
    required this.selected,
  });

  final _ReimbursementExportBasis option;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = AppPalette.actionPrimaryFor(context);
    final foreground = selected ? primary : AppPalette.textPrimaryFor(context);

    return Material(
      color: selected
          ? AppPalette.actionContainerFor(context, alpha: 0.72)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.small),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(option),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(option.icon, size: 20, color: foreground),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        option.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: selected
                              ? primary.withValues(alpha: 0.78)
                              : AppPalette.textSecondaryFor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 20,
                  child: selected
                      ? Icon(Icons.check_rounded, size: 19, color: primary)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionControls extends StatelessWidget {
  const _SelectionControls({
    required this.basis,
    required this.orderState,
    required this.invoiceState,
    required this.onSelectAllOrders,
    required this.onInvertOrders,
    required this.onSelectAllInvoices,
    required this.onInvertInvoices,
    required this.onChooseDate,
    required this.onClearDate,
    required this.onClearSelection,
    required this.onOpenHistory,
  });

  final _ReimbursementExportBasis basis;
  final ExportState orderState;
  final InvoiceExportState invoiceState;
  final VoidCallback onSelectAllOrders;
  final VoidCallback onInvertOrders;
  final VoidCallback onSelectAllInvoices;
  final VoidCallback onInvertInvoices;
  final VoidCallback onChooseDate;
  final VoidCallback onClearDate;
  final VoidCallback onClearSelection;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOrderBasis = basis == _ReimbursementExportBasis.orders;
    final totalCount = isOrderBasis
        ? orderState.availableOrders.length
        : invoiceState.availableInvoices.length;
    final selectableCount = isOrderBasis
        ? orderState.selectableCount
        : invoiceState.selectableCount;
    final selectedCount = isOrderBasis
        ? orderState.totalSelectedCount
        : invoiceState.selectedInvoiceIds.length;
    final hiddenSelectedCount = isOrderBasis
        ? orderState.hiddenSelectedCount
        : invoiceState.hiddenSelectedCount;
    final hasDate = isOrderBasis
        ? orderState.hasDateRange
        : invoiceState.hasDateRange;
    final startDate = isOrderBasis
        ? orderState.startDate
        : invoiceState.startDate;
    final endDate = isOrderBasis ? orderState.endDate : invoiceState.endDate;
    final isLoading = isOrderBasis
        ? orderState.isLoading
        : invoiceState.isLoading;
    final allSelected =
        selectableCount > 0 &&
        (isOrderBasis
            ? orderState.availableOrders.every((order) {
                final id = order.id;
                return id == null ||
                    !orderState.isSelectable(id) ||
                    orderState.isSelected(id);
              })
            : invoiceState.availableInvoices.every((invoice) {
                final id = invoice.id;
                return id == null ||
                    !invoiceState.isSelectable(id) ||
                    invoiceState.isSelected(id);
              }));

    return IgnorePointer(
      ignoring: isLoading,
      child: Opacity(
        opacity: isLoading ? 0.62 : 1,
        child: AppCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: LedgerFilterStrip(
                      children: [
                        LedgerFilterChip(
                          label: '全选 $selectableCount',
                          icon: Icons.done_all_rounded,
                          selected: allSelected,
                          onPressed: isOrderBasis
                              ? onSelectAllOrders
                              : onSelectAllInvoices,
                        ),
                        LedgerFilterChip(
                          label: '反选',
                          icon: Icons.swap_horiz_rounded,
                          onPressed: isOrderBasis
                              ? onInvertOrders
                              : onInvertInvoices,
                        ),
                        LedgerFilterChip(
                          label: hasDate
                              ? _dateRangeFilterLabel(startDate!, endDate!)
                              : '日期',
                          icon: Icons.calendar_month_outlined,
                          selected: hasDate,
                          onPressed: onChooseDate,
                        ),
                        if (hasDate)
                          LedgerFilterChip(
                            key: const ValueKey(
                              'clear-reimbursement-date-filter',
                            ),
                            label: '清除日期',
                            icon: Icons.close_rounded,
                            onPressed: onClearDate,
                          ),
                        if (selectedCount > 0)
                          LedgerFilterChip(
                            key: const ValueKey(
                              'clear-reimbursement-selection',
                            ),
                            label: '清空选择',
                            icon: Icons.deselect_rounded,
                            onPressed: onClearSelection,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: onOpenHistory,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      foregroundColor: AppPalette.actionPrimaryFor(context),
                    ),
                    child: const Text('导出记录'),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isOrderBasis
                          ? '$totalCount 笔订单 · $selectableCount 笔可选'
                          : '$totalCount 张发票 · $selectableCount 张可选',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppPalette.textSecondaryFor(context),
                        fontFeatures: AppTypography.tabularFigures,
                      ),
                    ),
                  ),
                  if (hiddenSelectedCount == 0) ...[
                    const SizedBox(width: 10),
                    Text(
                      '已选 $selectedCount 笔',
                      key: const ValueKey('reimbursement-selection-summary'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppPalette.actionPrimaryFor(context),
                        fontWeight: FontWeight.w700,
                        fontFeatures: AppTypography.tabularFigures,
                      ),
                    ),
                  ],
                ],
              ),
              if (hiddenSelectedCount > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '已选 $selectedCount 笔，其中 $hiddenSelectedCount 笔不在当前筛选范围内',
                  key: const ValueKey('reimbursement-selection-summary'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppPalette.actionPrimaryFor(context),
                    fontWeight: FontWeight.w700,
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.basis,
    required this.orderState,
    required this.invoiceState,
    required this.onContinue,
  });

  final _ReimbursementExportBasis basis;
  final ExportState orderState;
  final InvoiceExportState invoiceState;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOrderBasis = basis == _ReimbursementExportBasis.orders;
    final selectedPrimaryCount = isOrderBasis
        ? orderState.totalSelectedCount
        : invoiceState.selectedInvoiceIds.length;
    final selectedRelatedCount = isOrderBasis
        ? orderState.selectedInvoiceIds.length
        : invoiceState.selectedOrderIds.length;
    final total = isOrderBasis
        ? orderState.selectedTotal
        : invoiceState.selectedTotal;
    final isLoading = isOrderBasis
        ? orderState.isLoading
        : invoiceState.isLoading;

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(14, 10, 11, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOrderBasis
                      ? '$selectedPrimaryCount 笔订单 · $selectedRelatedCount 张发票'
                      : '$selectedPrimaryCount 张发票 · $selectedRelatedCount 笔订单',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '合计 ${DateFormatter.formatAmount(total)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppPalette.textSecondaryFor(context),
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          AppButton(
            key: const ValueKey('reimbursement-export-next'),
            text: '下一步',
            width: 110,
            isDense: true,
            trailing: const Icon(Icons.arrow_forward_rounded, size: 18),
            onPressed:
                !isLoading &&
                    selectedPrimaryCount > 0 &&
                    selectedRelatedCount > 0
                ? onContinue
                : null,
          ),
        ],
      ),
    );
  }
}

class _OrderSelectionLedger extends StatelessWidget {
  const _OrderSelectionLedger({
    super.key,
    required this.state,
    required this.onRefresh,
    required this.onToggle,
  });

  final ExportState state;
  final Future<void> Function() onRefresh;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.availableOrders.isEmpty) {
      return _ScrollableStatus(
        onRefresh: onRefresh,
        child: const CircularProgressIndicator(),
      );
    }
    if (state.errorMessage != null && state.availableOrders.isEmpty) {
      return _ScrollableStatus(
        onRefresh: onRefresh,
        child: EmptyState(
          icon: Icons.error_outline_rounded,
          title: '订单加载失败',
          subtitle: '请稍后重试',
          actionLabel: '重试',
          actionIcon: Icons.refresh_rounded,
          onAction: onRefresh,
        ),
      );
    }
    if (state.availableOrders.isEmpty) {
      return _ScrollableStatus(
        onRefresh: onRefresh,
        child: const EmptyState(
          icon: Icons.receipt_long_outlined,
          title: '暂无订单',
          subtitle: '添加订单并关联发票后即可导出',
        ),
      );
    }

    final groups = _groupByMonth<Order>(
      state.availableOrders,
      (order) => DateFormatter.resolveLedgerDate(
        businessDate: order.orderDate,
        createdAt: order.createdAt,
      ),
    );

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        key: const PageStorageKey('reimbursement-order-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          for (final group in groups)
            LedgerMonthSheetSliver(
              key: ValueKey('reimbursement-order-month-${group.key}'),
              monthLabel: group.monthLabel,
              summary: '按订单日期',
              totalLabel: '本月',
              totalAmount: '${group.items.length} 笔',
              entries: [
                for (final order in group.items) _buildOrderRow(context, order),
              ],
            ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 8)),
        ],
      ),
    );
  }

  Widget _buildOrderRow(BuildContext context, Order order) {
    final id = order.id;
    if (id == null) return const SizedBox.shrink();
    final date = DateFormatter.resolveLedgerDate(
      businessDate: order.orderDate,
      createdAt: order.createdAt,
    );
    final mealTime = DateFormatter.mealTimeToDisplayName(
      DateFormatter.mealTimeFromString(order.mealTime),
    );
    final selectable = state.isSelectable(id);
    final enabled = selectable && !state.isLoading;
    final selected = state.isSelected(id);
    final cascade = state.isCascadeSelected(id);
    final orderNumber = order.orderNumber.trim();

    return Opacity(
      opacity: !selectable
          ? 0.52
          : state.isLoading
          ? 0.72
          : 1,
      child: LedgerEntryRow(
        key: ValueKey('reimbursement-order-$id'),
        leading: _SelectionIndicator(
          selected: selected,
          cascade: cascade,
          enabled: enabled,
        ),
        day: date?.day.toString().padLeft(2, '0') ?? '--',
        dateCaption: mealTime == '-' ? '—' : mealTime,
        title: order.shopName.trim().isEmpty ? '未命名店铺' : order.shopName.trim(),
        subtitle: orderNumber.isEmpty ? '无订单号' : '#$orderNumber',
        amount: DateFormatter.formatAmount(order.amount),
        relationLabel: cascade
            ? '同票带入'
            : selectable
            ? '已关联发票'
            : '未关联发票',
        relationTone: cascade
            ? LedgerRelationTone.action
            : selectable
            ? LedgerRelationTone.linked
            : LedgerRelationTone.neutral,
        selected: selected,
        onTap: enabled ? () => onToggle(id) : null,
      ),
    );
  }
}

class _InvoiceSelectionLedger extends StatelessWidget {
  const _InvoiceSelectionLedger({
    super.key,
    required this.state,
    required this.onRefresh,
    required this.onToggle,
  });

  final InvoiceExportState state;
  final Future<void> Function() onRefresh;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.availableInvoices.isEmpty) {
      return _ScrollableStatus(
        onRefresh: onRefresh,
        child: const CircularProgressIndicator(),
      );
    }
    if (state.errorMessage != null && state.availableInvoices.isEmpty) {
      return _ScrollableStatus(
        onRefresh: onRefresh,
        child: EmptyState(
          icon: Icons.error_outline_rounded,
          title: '发票加载失败',
          subtitle: '请稍后重试',
          actionLabel: '重试',
          actionIcon: Icons.refresh_rounded,
          onAction: onRefresh,
        ),
      );
    }
    if (state.availableInvoices.isEmpty) {
      return _ScrollableStatus(
        onRefresh: onRefresh,
        child: const EmptyState(
          icon: Icons.description_outlined,
          title: '暂无发票',
          subtitle: '添加发票并关联订单后即可导出',
        ),
      );
    }

    final groups = _groupByMonth<Invoice>(
      state.availableInvoices,
      (invoice) => DateFormatter.resolveLedgerDate(
        businessDate: invoice.invoiceDate,
        createdAt: invoice.createdAt,
      ),
    );

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        key: const PageStorageKey('reimbursement-invoice-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          for (final group in groups)
            LedgerMonthSheetSliver(
              key: ValueKey('reimbursement-invoice-month-${group.key}'),
              monthLabel: group.monthLabel,
              summary: '按开票日期',
              totalLabel: '本月',
              totalAmount: '${group.items.length} 张',
              entries: [
                for (final invoice in group.items) _buildInvoiceRow(invoice),
              ],
            ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 8)),
        ],
      ),
    );
  }

  Widget _buildInvoiceRow(Invoice invoice) {
    final id = invoice.id;
    if (id == null) return const SizedBox.shrink();
    final date = DateFormatter.resolveLedgerDate(
      businessDate: invoice.invoiceDate,
      createdAt: invoice.createdAt,
    );
    final orderCount = state.orderCountFor(id);
    final selectable = state.isSelectable(id);
    final enabled = selectable && !state.isLoading;
    final selected = state.isSelected(id);
    final invoiceNumber = invoice.invoiceNumber.trim();

    return Opacity(
      opacity: !selectable
          ? 0.52
          : state.isLoading
          ? 0.72
          : 1,
      child: LedgerEntryRow(
        key: ValueKey('reimbursement-invoice-$id'),
        leading: _SelectionIndicator(selected: selected, enabled: enabled),
        day: date?.day.toString().padLeft(2, '0') ?? '--',
        dateCaption: '日',
        title: invoice.sellerName.trim().isEmpty
            ? '未知商家'
            : invoice.sellerName.trim(),
        subtitle: invoiceNumber.isEmpty ? '无发票号' : invoiceNumber,
        amount: DateFormatter.formatAmount(invoice.totalAmount),
        relationLabel: selectable ? '关联 $orderCount 笔订单' : '未关联订单',
        relationTone: selectable
            ? LedgerRelationTone.linked
            : LedgerRelationTone.neutral,
        selected: selected,
        onTap: enabled ? () => onToggle(id) : null,
      ),
    );
  }
}

class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({
    required this.selected,
    required this.enabled,
    this.cascade = false,
  });

  final bool selected;
  final bool enabled;
  final bool cascade;

  @override
  Widget build(BuildContext context) {
    final selectedColor = cascade
        ? AppPalette.warningMuted
        : AppPalette.actionPrimaryFor(context);

    return AnimatedContainer(
      duration: AppMotion.adaptive(context, AppMotion.fast),
      width: 21,
      height: 21,
      decoration: BoxDecoration(
        color: selected ? selectedColor : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: selected
              ? selectedColor
              : AppEntityTokens.strongBorderFor(
                  context,
                ).withValues(alpha: enabled ? 1 : 0.55),
        ),
      ),
      child: selected
          ? Icon(
              cascade ? Icons.link_rounded : Icons.check_rounded,
              size: 15,
              color: Theme.of(context).colorScheme.onPrimary,
            )
          : null,
    );
  }
}

class _ScrollableStatus extends StatelessWidget {
  const _ScrollableStatus({required this.onRefresh, required this.child});

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: child),
          ),
        ],
      ),
    );
  }
}

class _ExportMonthGroup<T> {
  const _ExportMonthGroup({
    required this.key,
    required this.month,
    required this.items,
  });

  final String key;
  final DateTime? month;
  final List<T> items;

  String get monthLabel =>
      month == null ? '日期未知' : '${month!.year} 年 ${month!.month} 月';
}

List<_ExportMonthGroup<T>> _groupByMonth<T>(
  List<T> records,
  DateTime? Function(T record) dateOf,
) {
  final grouped = <String, List<T>>{};
  final monthByKey = <String, DateTime?>{};

  for (final record in records) {
    final date = dateOf(record);
    final key = date == null ? 'unknown' : '${date.year}-${date.month}';
    grouped.putIfAbsent(key, () => <T>[]).add(record);
    monthByKey[key] = date == null ? null : DateTime(date.year, date.month);
  }

  final groups = <_ExportMonthGroup<T>>[
    for (final entry in grouped.entries)
      _ExportMonthGroup<T>(
        key: entry.key,
        month: monthByKey[entry.key],
        items: entry.value.toList()
          ..sort((left, right) {
            final leftDate = dateOf(left);
            final rightDate = dateOf(right);
            if (leftDate == null && rightDate == null) return 0;
            if (leftDate == null) return 1;
            if (rightDate == null) return -1;
            return rightDate.compareTo(leftDate);
          }),
      ),
  ];

  groups.sort((left, right) {
    if (left.month == null && right.month == null) return 0;
    if (left.month == null) return 1;
    if (right.month == null) return -1;
    return right.month!.compareTo(left.month!);
  });
  return groups;
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/core/utils/date_formatter.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/presentation/providers/order_provider.dart';
import 'package:receipt_tamer/presentation/providers/invoice_provider.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_button.dart';
import 'package:receipt_tamer/presentation/widgets/common/empty_state.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_bottom_sheet.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_navigation_bar.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_search_dialog.dart';
import 'package:receipt_tamer/presentation/widgets/common/ledger_month_sheet.dart';
import 'package:receipt_tamer/presentation/widgets/common/scroll_edge_fog.dart';
import 'package:receipt_tamer/presentation/widgets/common/syncfusion_month_range_picker.dart';
import 'package:receipt_tamer/presentation/widgets/invoice/invoice_ledger_row.dart';
import 'package:receipt_tamer/presentation/widgets/invoice/invoice_month_group.dart';
import 'package:receipt_tamer/presentation/widgets/order/month_fast_scroll_bar.dart';

/// Invoices screen - displays list of all invoices grouped by month
class InvoicesScreen extends ConsumerStatefulWidget {
  final int? filterOrderId; // Optional: filter by order ID

  const InvoicesScreen({super.key, this.filterOrderId});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _monthAnchors = {};
  Order? _filterOrder;
  List<InvoiceMonthGroup> _monthGroups = [];
  Map<int, int> _invoiceOrderCounts = {}; // invoiceId -> order count
  InvoiceState? _invoiceOrderCountState;
  List<int> _invoiceOrderCountIds = const [];
  Future<Map<int, int>>? _invoiceOrderCountsFuture;
  _InvoiceLedgerFilter _activeFilter = _InvoiceLedgerFilter.all;
  MonthRangeResult? _selectedMonthRange;
  String? _activeSearchQuery;
  bool _isTodayFilter = false;
  int _knownTotalCount = 0;
  int _knownLinkedCount = 0;
  int _monthJumpRequest = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant InvoicesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filterOrderId != widget.filterOrderId) {
      _filterOrder = null;
      _monthGroups = [];
      _invoiceOrderCounts = {};
      _activeFilter = _InvoiceLedgerFilter.all;
      _selectedMonthRange = null;
      _activeSearchQuery = null;
      _isTodayFilter = false;
      _knownTotalCount = 0;
      _knownLinkedCount = 0;
      _resetInvoiceOrderCountsFuture();
      _init();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (widget.filterOrderId != null) {
      _filterOrder = await ref
          .read(orderProvider.notifier)
          .getOrderById(widget.filterOrderId!);
    }
    // Use Future.microtask to delay provider modification until after build
    Future.microtask(() {
      _loadInvoices();
    });
  }

  void _loadInvoices() {
    ref
        .read(invoiceProvider.notifier)
        .loadInvoices(filterOrderId: widget.filterOrderId);
  }

  void _resetInvoiceOrderCountsFuture() {
    _invoiceOrderCountState = null;
    _invoiceOrderCountIds = const [];
    _invoiceOrderCountsFuture = null;
  }

  Future<Map<int, int>> _orderCountsFutureFor(InvoiceState invoiceState) {
    final ids = invoiceState.invoices
        .map((invoice) => invoice.id)
        .whereType<int>()
        .toList(growable: false);

    if (!identical(_invoiceOrderCountState, invoiceState) ||
        !listEquals(_invoiceOrderCountIds, ids) ||
        _invoiceOrderCountsFuture == null) {
      _invoiceOrderCountState = invoiceState;
      _invoiceOrderCountIds = ids;
      _invoiceOrderCountsFuture = _loadInvoiceOrderCounts(
        invoiceState.invoices,
      );
    }

    return _invoiceOrderCountsFuture!;
  }

  void _handleAddInvoice() {
    if (widget.filterOrderId != null) {
      context.push('/invoices/new?orderId=${widget.filterOrderId}');
    } else {
      context.push('/invoices/new');
    }
  }

  void _handleInvoiceTap(int invoiceId) {
    context.push('/invoices/$invoiceId');
  }

  Future<void> _scrollToGroup(int index) async {
    if (index < 0 || index >= _monthGroups.length) return;
    final request = ++_monthJumpRequest;
    await revealMonthAnchor(
      controller: _scrollController,
      targetIndex: index,
      anchors: [
        for (final group in _monthGroups)
          _monthAnchors.putIfAbsent(group.key, GlobalKey.new),
      ],
      itemCounts: [for (final group in _monthGroups) group.count],
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 300),
      isCurrent: () => mounted && request == _monthJumpRequest,
    );
  }

  /// Group invoices by year and month (descending order)
  List<InvoiceMonthGroup> _groupInvoicesByMonth(List<Invoice> invoices) {
    final Map<String, List<Invoice>> grouped = {};

    for (final invoice in invoices) {
      final date = DateFormatter.resolveLedgerDate(
        businessDate: invoice.invoiceDate,
        createdAt: invoice.createdAt,
      );
      if (date == null) continue;

      final key = '${date.year}-${date.month}';
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(invoice);
    }

    // Convert to list of InvoiceMonthGroup and sort by date (descending)
    final groups = grouped.entries.map((entry) {
      final parts = entry.key.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);

      // Sort invoices within group by date (descending)
      final sortedInvoices = entry.value.toList()
        ..sort((a, b) {
          final dateA = DateFormatter.resolveLedgerDate(
            businessDate: a.invoiceDate,
            createdAt: a.createdAt,
          );
          final dateB = DateFormatter.resolveLedgerDate(
            businessDate: b.invoiceDate,
            createdAt: b.createdAt,
          );
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateB.compareTo(dateA);
        });

      // Build order counts map for this group
      final groupOrderCounts = <int, int>{};
      for (final invoice in sortedInvoices) {
        if (invoice.id != null) {
          groupOrderCounts[invoice.id!] = _invoiceOrderCounts[invoice.id!] ?? 0;
        }
      }

      return InvoiceMonthGroup(
        year: year,
        month: month,
        invoices: sortedInvoices,
        invoiceOrderCounts: groupOrderCounts,
      );
    }).toList();

    // Sort groups by date (descending - newest first)
    groups.sort((a, b) {
      if (a.year != b.year) return b.year.compareTo(a.year);
      return b.month.compareTo(a.month);
    });

    return groups;
  }

  /// Load order counts for all invoices
  Future<Map<int, int>> _loadInvoiceOrderCounts(List<Invoice> invoices) async {
    final invoiceIds = invoices
        .map((invoice) => invoice.id)
        .whereType<int>()
        .toList(growable: false);
    return await ref
        .read(invoiceProvider.notifier)
        .getOrderCountsForInvoices(invoiceIds);
  }

  @override
  Widget build(BuildContext context) {
    final invoiceState = ref.watch(invoiceProvider);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    if (invoiceState.invoices.isEmpty) {
      _monthGroups = [];
    }

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 16,
        toolbarHeight: textScale >= 1.6 ? 96 : 74,
        title: _buildPageTitle(
          context,
          _filterOrder != null ? '${_filterOrder!.shopName} 的发票' : '发票列表',
        ),
        elevation: 0,
        actions: [
          if (widget.filterOrderId == null) ...[
            AppIconButton(
              icon: Icons.search,
              onPressed: () => _showSearchDialog(context),
              tooltip: '搜索',
            ),
            const SizedBox(width: 8),
            AppIconButton(
              icon: Icons.filter_list,
              onPressed: () => _showFilterDialog(context),
              tooltip: '筛选',
            ),
            const SizedBox(width: 12),
          ],
        ],
      ),
      body: ScrollEdgeFog(
        topHeight: ledgerMonthFadeSafeTop,
        bottomHeight: 104,
        bottomInset: GlassNavigationBar.contentFadeInset(context),
        child: RefreshIndicator(
          onRefresh: _refreshCurrentView,
          child:
              invoiceState.isLoading &&
                  invoiceState.invoices.isEmpty &&
                  _activeFilter == _InvoiceLedgerFilter.all
              ? const Center(child: CircularProgressIndicator())
              : invoiceState.invoices.isEmpty &&
                    _activeFilter == _InvoiceLedgerFilter.all
              ? EmptyInvoices(onAdd: _handleAddInvoice)
              : invoiceState.invoices.isEmpty
              ? MonthFastScrollLayout(
                  items: const [],
                  onJumpToIndex: _scrollToGroup,
                  child: _buildGroupedList(),
                )
              : FutureBuilder<Map<int, int>>(
                  future: _orderCountsFutureFor(invoiceState),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      _invoiceOrderCounts = snapshot.data!;
                      if (_activeFilter == _InvoiceLedgerFilter.all &&
                          !invoiceState.isLoading) {
                        _knownTotalCount = invoiceState.invoices.length;
                        _knownLinkedCount = invoiceState.invoices.where((item) {
                          final id = item.id;
                          return id != null &&
                              (_invoiceOrderCounts[id] ?? 0) > 0;
                        }).length;
                      }
                    }
                    _monthGroups = _groupInvoicesByMonth(invoiceState.invoices);

                    return MonthFastScrollLayout(
                      items: _monthGroups
                          .map(
                            (g) =>
                                MonthScrollItem(year: g.year, month: g.month),
                          )
                          .toList(),
                      onJumpToIndex: _scrollToGroup,
                      listRightInset: _monthGroups.length > 1
                          ? monthFastScrollBarListRightInset
                          : 0,
                      child: _buildGroupedList(),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildPageTitle(BuildContext context, String title) {
    final theme = Theme.of(context);

    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.headlineMedium?.copyWith(
        color: AppPalette.textPrimaryFor(context),
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildGroupedList() {
    final validKeys = _monthGroups.map((group) => group.key).toSet();
    _monthAnchors.removeWhere((key, value) => !validKeys.contains(key));

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        if (widget.filterOrderId == null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
            sliver: SliverToBoxAdapter(child: _buildFilterStrip()),
          )
        else
          const SliverPadding(padding: EdgeInsets.only(top: 28)),
        ..._buildSliverGroups(),
        if (_monthGroups.isEmpty && widget.filterOrderId == null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.filter_alt_off,
              title: '无匹配发票',
              subtitle: '请调整筛选条件',
              actionLabel: '清除筛选',
              actionIcon: Icons.close,
              onAction: _clearFilter,
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 112)),
      ],
    );
  }

  List<Widget> _buildSliverGroups() {
    return _monthGroups.map((group) {
      final anchor = _monthAnchors.putIfAbsent(group.key, GlobalKey.new);

      return LedgerMonthSheetSliver(
        key: anchor,
        monthLabel: '${group.year} 年 ${group.month} 月',
        summary: '${group.count} 张',
        totalLabel: '合计',
        totalAmount: DateFormatter.formatAmount(group.totalAmount),
        entries: [
          for (final invoice in group.invoices)
            InvoiceLedgerRow(
              key: ValueKey('invoice-ledger-row-${invoice.id}'),
              invoice: invoice,
              orderCount: invoice.id == null
                  ? 0
                  : group.getOrderCount(invoice.id!),
              onTap: invoice.id != null && invoice.id! > 0
                  ? () => _handleInvoiceTap(invoice.id!)
                  : null,
            ),
        ],
      );
    }).toList();
  }

  Widget _buildFilterStrip() {
    final unlinkedCount = _knownTotalCount - _knownLinkedCount;

    return LedgerFilterStrip(
      key: ValueKey('invoice-filter-strip-${_activeFilter.name}'),
      children: [
        if (_activeFilter != _InvoiceLedgerFilter.all)
          LedgerFilterChip(
            label: '清除筛选',
            icon: Icons.close,
            onPressed: _clearFilter,
          ),
        LedgerFilterChip(
          label: '全部 $_knownTotalCount',
          selected: _activeFilter == _InvoiceLedgerFilter.all,
          onPressed: () => _applyRelationFilter(_InvoiceLedgerFilter.all),
        ),
        LedgerFilterChip(
          label: '未关联 $unlinkedCount',
          selected: _activeFilter == _InvoiceLedgerFilter.unlinked,
          onPressed: () => _activeFilter == _InvoiceLedgerFilter.unlinked
              ? _clearFilter()
              : _applyRelationFilter(_InvoiceLedgerFilter.unlinked),
        ),
        LedgerFilterChip(
          label: '已关联 $_knownLinkedCount',
          selected: _activeFilter == _InvoiceLedgerFilter.linked,
          onPressed: () => _activeFilter == _InvoiceLedgerFilter.linked
              ? _clearFilter()
              : _applyRelationFilter(_InvoiceLedgerFilter.linked),
        ),
        LedgerFilterChip(
          label: _monthFilterLabel(),
          icon: Icons.calendar_month,
          selected: _activeFilter == _InvoiceLedgerFilter.month,
          onPressed: () => _activeFilter == _InvoiceLedgerFilter.month
              ? _clearFilter()
              : _pickMonthRange(),
        ),
      ],
    );
  }

  String _monthFilterLabel() {
    final range = _selectedMonthRange;
    if (range == null) return '月份';

    final start = range.startDate;
    final end = range.endDate;
    final startMonth = start.month.toString().padLeft(2, '0');
    final endMonth = end.month.toString().padLeft(2, '0');
    if (start.year == end.year && start.month == end.month) {
      return '${start.year}.$startMonth';
    }
    if (start.year == end.year) {
      return '${start.year}.$startMonth–$endMonth';
    }
    return '${start.year}.$startMonth–${end.year}.$endMonth';
  }

  void _applyRelationFilter(_InvoiceLedgerFilter filter) {
    setState(() {
      _activeFilter = filter;
      _activeSearchQuery = null;
      _isTodayFilter = false;
      if (filter != _InvoiceLedgerFilter.month) {
        _selectedMonthRange = null;
      }
    });
    switch (filter) {
      case _InvoiceLedgerFilter.all:
        _loadInvoices();
        return;
      case _InvoiceLedgerFilter.unlinked:
        ref.read(invoiceProvider.notifier).loadInvoicesWithoutOrders();
        return;
      case _InvoiceLedgerFilter.linked:
        ref.read(invoiceProvider.notifier).searchInvoices(hasLinkedOrder: true);
        return;
      case _InvoiceLedgerFilter.month:
      case _InvoiceLedgerFilter.custom:
        return;
    }
  }

  Future<void> _pickMonthRange() async {
    final result = await SyncfusionMonthRangePicker.show(
      context,
      initialStartMonth: _selectedMonthRange?.startDate,
      initialEndMonth: _selectedMonthRange?.endDate,
    );
    if (result == null || !mounted) return;
    setState(() {
      _activeFilter = _InvoiceLedgerFilter.month;
      _selectedMonthRange = result;
      _activeSearchQuery = null;
      _isTodayFilter = false;
    });
    ref
        .read(invoiceProvider.notifier)
        .searchInvoices(startDate: result.startDate, endDate: result.endDate);
  }

  void _clearFilter() {
    _applyRelationFilter(_InvoiceLedgerFilter.all);
  }

  Future<void> _refreshCurrentView() async {
    final notifier = ref.read(invoiceProvider.notifier);
    switch (_activeFilter) {
      case _InvoiceLedgerFilter.all:
        await notifier.loadInvoices(
          filterOrderId: widget.filterOrderId,
          refresh: true,
        );
        return;
      case _InvoiceLedgerFilter.unlinked:
        await notifier.loadInvoicesWithoutOrders();
        return;
      case _InvoiceLedgerFilter.linked:
        await notifier.searchInvoices(hasLinkedOrder: true);
        return;
      case _InvoiceLedgerFilter.month:
        final range = _selectedMonthRange;
        if (range == null) {
          await notifier.loadThisMonthInvoices();
        } else {
          await notifier.searchInvoices(
            startDate: range.startDate,
            endDate: range.endDate,
          );
        }
        return;
      case _InvoiceLedgerFilter.custom:
        final query = _activeSearchQuery;
        if (query != null) {
          await notifier.searchInvoices(keyword: query);
        } else if (_isTodayFilter) {
          await notifier.loadTodayInvoices();
        } else {
          await notifier.loadInvoices(
            filterOrderId: widget.filterOrderId,
            refresh: true,
          );
        }
        return;
    }
  }

  void _showFilterDialog(BuildContext context) {
    showGlassBottomSheet<void>(
      context: context,
      builder: (context) => GlassBottomSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                ),
              ),
            ),
            Text('筛选发票', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('全部发票'),
              onTap: () {
                _applyRelationFilter(_InvoiceLedgerFilter.all);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.today),
              title: const Text('今日发票'),
              onTap: () {
                setState(() {
                  _activeFilter = _InvoiceLedgerFilter.custom;
                  _selectedMonthRange = null;
                  _activeSearchQuery = null;
                  _isTodayFilter = true;
                });
                ref.read(invoiceProvider.notifier).loadTodayInvoices();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('本月发票'),
              onTap: () {
                final now = DateTime.now();
                setState(() {
                  _activeFilter = _InvoiceLedgerFilter.month;
                  _selectedMonthRange = MonthRangeResult(
                    startDate: DateTime(now.year, now.month),
                    endDate: DateTime(now.year, now.month + 1, 0),
                  );
                  _activeSearchQuery = null;
                  _isTodayFilter = false;
                });
                ref.read(invoiceProvider.notifier).loadThisMonthInvoices();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.date_range),
              title: const Text('按月份范围'),
              onTap: () async {
                Navigator.pop(context);
                await _pickMonthRange();
              },
            ),
            ListTile(
              leading: const Icon(Icons.link_off),
              title: const Text('未关联订单'),
              onTap: () {
                _applyRelationFilter(_InvoiceLedgerFilter.unlinked);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('已关联订单'),
              onTap: () {
                _applyRelationFilter(_InvoiceLedgerFilter.linked);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSearchDialog(BuildContext context) async {
    final query = await showGlassSearchDialog(
      context: context,
      title: '搜索发票',
      hint: '输入销售方名称或发票号码',
    );

    if (query == null) return;

    if (query.isNotEmpty) {
      setState(() {
        _activeFilter = _InvoiceLedgerFilter.custom;
        _selectedMonthRange = null;
        _activeSearchQuery = query;
        _isTodayFilter = false;
      });
      ref.read(invoiceProvider.notifier).searchInvoices(keyword: query);
    } else {
      _applyRelationFilter(_InvoiceLedgerFilter.all);
    }
  }
}

enum _InvoiceLedgerFilter { all, unlinked, linked, month, custom }

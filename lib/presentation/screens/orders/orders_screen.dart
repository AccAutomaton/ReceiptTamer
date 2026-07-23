import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/core/utils/date_formatter.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/presentation/providers/order_provider.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_button.dart';
import 'package:receipt_tamer/presentation/widgets/common/empty_state.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_bottom_sheet.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_navigation_bar.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_search_dialog.dart';
import 'package:receipt_tamer/presentation/widgets/common/ledger_month_sheet.dart';
import 'package:receipt_tamer/presentation/widgets/common/scroll_edge_fog.dart';
import 'package:receipt_tamer/presentation/widgets/common/syncfusion_month_range_picker.dart';
import 'package:receipt_tamer/presentation/widgets/order/month_group.dart';
import 'package:receipt_tamer/presentation/widgets/order/month_fast_scroll_bar.dart';
import 'package:receipt_tamer/presentation/widgets/order/order_ledger_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Orders screen - displays list of all orders grouped by month
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _monthAnchors = {};
  List<MonthGroup> _monthGroups = [];
  _OrderLedgerFilter _activeFilter = _OrderLedgerFilter.all;
  MonthRangeResult? _selectedMonthRange;
  String? _activeSearchQuery;
  bool _isTodayFilter = false;
  int _knownTotalCount = 0;
  int _knownLinkedCount = 0;
  int _monthJumpRequest = 0;

  @override
  void initState() {
    super.initState();
    // Load orders when screen initializes
    Future.microtask(() {
      ref.read(orderProvider.notifier).loadOrders();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Group orders by year and month (descending order)
  List<MonthGroup> _groupOrdersByMonth(List<Order> orders) {
    final Map<String, List<Order>> grouped = {};

    for (final order in orders) {
      final date = DateFormatter.resolveLedgerDate(
        businessDate: order.orderDate,
        createdAt: order.createdAt,
      );
      if (date == null) continue;

      final key = '${date.year}-${date.month}';
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(order);
    }

    // Convert to list of MonthGroup and sort by date (descending)
    final groups = grouped.entries.map((entry) {
      final parts = entry.key.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);

      // Sort orders within group by date (descending)
      final sortedOrders = entry.value.toList()
        ..sort((a, b) {
          final dateA = DateFormatter.resolveLedgerDate(
            businessDate: a.orderDate,
            createdAt: a.createdAt,
          );
          final dateB = DateFormatter.resolveLedgerDate(
            businessDate: b.orderDate,
            createdAt: b.createdAt,
          );
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateB.compareTo(dateA);
        });

      return MonthGroup(year: year, month: month, orders: sortedOrders);
    }).toList();

    // Sort groups by date (descending - newest first)
    groups.sort((a, b) {
      if (a.year != b.year) return b.year.compareTo(a.year);
      return b.month.compareTo(a.month);
    });

    return groups;
  }

  void _handleAddOrder() {
    context.push('/orders/new');
  }

  void _handleOrderTap(int orderId) {
    context.push('/orders/$orderId');
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

  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(orderProvider);
    final textScale = AppTypography.accessibilityScaleOf(context);

    // Group orders by month
    _monthGroups = orderState.orders.isEmpty
        ? []
        : _groupOrdersByMonth(orderState.orders);
    if (_activeFilter == _OrderLedgerFilter.all && !orderState.isLoading) {
      _knownTotalCount = orderState.orders.length;
      _knownLinkedCount = orderState.orders
          .where((order) => order.hasInvoice)
          .length;
    }

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        forceMaterialTransparency: true,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: 16,
        toolbarHeight: textScale >= 1.6 ? 96 : 74,
        title: _buildPageTitle(context, '订单列表'),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
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
      ),
      body: _buildBody(orderState),
    );
  }

  Widget _buildBody(OrderState orderState) {
    final isInitialLoading =
        orderState.isLoading &&
        orderState.orders.isEmpty &&
        _activeFilter == _OrderLedgerFilter.all;
    final isUnfilteredEmpty =
        orderState.orders.isEmpty && _activeFilter == _OrderLedgerFilter.all;

    if (isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (isUnfilteredEmpty) {
      return EmptyOrders(onAdd: _handleAddOrder);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _buildFilterStrip(),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshCurrentView,
            child: ScrollEdgeFog(
              fadeTopToTransparent: true,
              topHeight: ledgerMonthFadeSafeTop,
              bottomHeight: 104,
              bottomInset: GlassNavigationBar.contentFadeInset(context),
              child: MonthFastScrollLayout(
                items: _monthGroups
                    .map((g) => MonthScrollItem(year: g.year, month: g.month))
                    .toList(),
                onJumpToIndex: _scrollToGroup,
                listRightInset: _monthGroups.length > 1
                    ? monthFastScrollBarListRightInset
                    : 0,
                child: LedgerViewportClip(child: _buildGroupedList()),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPageTitle(BuildContext context, String title) {
    final theme = Theme.of(context);

    return AppTypography.preserveOriginalSize(
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.headlineMedium?.copyWith(
          color: AppPalette.textPrimaryFor(context),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildGroupedList() {
    final validKeys = _monthGroups.map((group) => group.key).toSet();
    _monthAnchors.removeWhere((key, value) => !validKeys.contains(key));

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        ..._buildSliverGroups(),
        if (_monthGroups.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.filter_alt_off,
              title: '无匹配订单',
              subtitle: '请调整筛选条件',
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
        summary: '${group.count} 笔',
        totalLabel: '合计',
        totalAmount: DateFormatter.formatAmount(group.totalAmount),
        entries: [
          for (final order in group.orders)
            OrderLedgerRow(
              key: ValueKey('order-ledger-row-${order.id}'),
              order: order,
              onTap: order.id != null && order.id! > 0
                  ? () => _handleOrderTap(order.id!)
                  : null,
            ),
        ],
      );
    }).toList();
  }

  Widget _buildFilterStrip() {
    final unlinkedCount = _knownTotalCount - _knownLinkedCount;

    return LedgerFilterStrip(
      key: ValueKey('order-filter-strip-${_activeFilter.name}'),
      children: [
        LedgerFilterChip(
          label: '全部 $_knownTotalCount',
          selected: _activeFilter == _OrderLedgerFilter.all,
          onPressed: () => _applyRelationFilter(_OrderLedgerFilter.all),
        ),
        if (_isTodayFilter)
          LedgerFilterChip(
            key: const ValueKey('order-active-today-filter'),
            label: '今日',
            semanticLabel: '清除筛选：今日',
            icon: Icons.close,
            selected: true,
            onPressed: _clearFilter,
          ),
        if (_activeSearchQuery != null)
          LedgerFilterChip(
            key: const ValueKey('order-active-search-filter'),
            label: '搜索：${_activeSearchQuery!}',
            semanticLabel: '清除筛选：搜索 ${_activeSearchQuery!}',
            icon: Icons.close,
            selected: true,
            onPressed: _clearFilter,
          ),
        LedgerFilterChip(
          label: '未关联 $unlinkedCount',
          semanticLabel: _activeFilter == _OrderLedgerFilter.unlinked
              ? '清除筛选：未关联'
              : null,
          icon: Icons.link_off,
          selected: _activeFilter == _OrderLedgerFilter.unlinked,
          onPressed: () => _activeFilter == _OrderLedgerFilter.unlinked
              ? _clearFilter()
              : _applyRelationFilter(_OrderLedgerFilter.unlinked),
        ),
        LedgerFilterChip(
          label: '已关联 $_knownLinkedCount',
          semanticLabel: _activeFilter == _OrderLedgerFilter.linked
              ? '清除筛选：已关联'
              : null,
          selected: _activeFilter == _OrderLedgerFilter.linked,
          onPressed: () => _activeFilter == _OrderLedgerFilter.linked
              ? _clearFilter()
              : _applyRelationFilter(_OrderLedgerFilter.linked),
        ),
        LedgerFilterChip(
          label: _monthFilterLabel(),
          semanticLabel: _activeFilter == _OrderLedgerFilter.month
              ? '清除筛选：${_monthFilterLabel()}'
              : null,
          icon: _activeFilter == _OrderLedgerFilter.month
              ? Icons.close
              : Icons.calendar_month,
          selected: _activeFilter == _OrderLedgerFilter.month,
          onPressed: () => _activeFilter == _OrderLedgerFilter.month
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

  void _applyRelationFilter(_OrderLedgerFilter filter) {
    setState(() {
      _activeFilter = filter;
      _activeSearchQuery = null;
      _isTodayFilter = false;
      if (filter != _OrderLedgerFilter.month) {
        _selectedMonthRange = null;
      }
    });
    switch (filter) {
      case _OrderLedgerFilter.all:
        ref.read(orderProvider.notifier).loadOrders();
        return;
      case _OrderLedgerFilter.unlinked:
        ref.read(orderProvider.notifier).searchOrders(hasLinkedInvoice: false);
        return;
      case _OrderLedgerFilter.linked:
        ref.read(orderProvider.notifier).searchOrders(hasLinkedInvoice: true);
        return;
      case _OrderLedgerFilter.month:
      case _OrderLedgerFilter.custom:
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
      _activeFilter = _OrderLedgerFilter.month;
      _selectedMonthRange = result;
      _activeSearchQuery = null;
      _isTodayFilter = false;
    });
    ref
        .read(orderProvider.notifier)
        .searchOrders(startDate: result.startDate, endDate: result.endDate);
  }

  void _clearFilter() {
    _applyRelationFilter(_OrderLedgerFilter.all);
  }

  Future<void> _refreshCurrentView() async {
    final notifier = ref.read(orderProvider.notifier);
    switch (_activeFilter) {
      case _OrderLedgerFilter.all:
        await notifier.loadOrders(refresh: true);
        return;
      case _OrderLedgerFilter.unlinked:
        await notifier.searchOrders(hasLinkedInvoice: false);
        return;
      case _OrderLedgerFilter.linked:
        await notifier.searchOrders(hasLinkedInvoice: true);
        return;
      case _OrderLedgerFilter.month:
        final range = _selectedMonthRange;
        if (range == null) {
          await notifier.loadThisMonthOrders();
        } else {
          await notifier.searchOrders(
            startDate: range.startDate,
            endDate: range.endDate,
          );
        }
        return;
      case _OrderLedgerFilter.custom:
        final query = _activeSearchQuery;
        if (query != null) {
          await notifier.searchOrders(shopName: query, orderNumber: query);
        } else if (_isTodayFilter) {
          await notifier.loadTodayOrders();
        } else {
          await notifier.loadOrders(refresh: true);
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
            Text('筛选订单', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('全部订单'),
              onTap: () {
                _applyRelationFilter(_OrderLedgerFilter.all);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.today),
              title: const Text('今日订单'),
              onTap: () {
                setState(() {
                  _activeFilter = _OrderLedgerFilter.custom;
                  _selectedMonthRange = null;
                  _activeSearchQuery = null;
                  _isTodayFilter = true;
                });
                ref.read(orderProvider.notifier).loadTodayOrders();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('本月订单'),
              onTap: () {
                final now = DateTime.now();
                setState(() {
                  _activeFilter = _OrderLedgerFilter.month;
                  _selectedMonthRange = MonthRangeResult(
                    startDate: DateTime(now.year, now.month),
                    endDate: DateTime(now.year, now.month + 1, 0),
                  );
                  _activeSearchQuery = null;
                  _isTodayFilter = false;
                });
                ref.read(orderProvider.notifier).loadThisMonthOrders();
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
              title: const Text('未关联发票'),
              onTap: () {
                _applyRelationFilter(_OrderLedgerFilter.unlinked);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('已关联发票'),
              onTap: () {
                _applyRelationFilter(_OrderLedgerFilter.linked);
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
      title: '搜索订单',
      hint: '输入店铺名称或订单号',
    );

    if (query == null) return;

    if (query.isNotEmpty) {
      setState(() {
        _activeFilter = _OrderLedgerFilter.custom;
        _selectedMonthRange = null;
        _activeSearchQuery = query;
        _isTodayFilter = false;
      });
      ref
          .read(orderProvider.notifier)
          .searchOrders(shopName: query, orderNumber: query);
    } else {
      _applyRelationFilter(_OrderLedgerFilter.all);
    }
  }
}

enum _OrderLedgerFilter { all, unlinked, linked, month, custom }

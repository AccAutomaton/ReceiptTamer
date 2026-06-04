import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:receipt_tamer/core/constants/app_constants.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/presentation/providers/order_provider.dart';
import 'package:receipt_tamer/presentation/providers/invoice_provider.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_button.dart';
import 'package:receipt_tamer/presentation/widgets/common/empty_state.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_bottom_sheet.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_search_dialog.dart';
import 'package:receipt_tamer/presentation/widgets/common/syncfusion_month_range_picker.dart';
import 'package:receipt_tamer/presentation/widgets/invoice/invoice_card.dart';
import 'package:receipt_tamer/presentation/widgets/invoice/invoice_month_group.dart';
import 'package:receipt_tamer/presentation/widgets/invoice/invoice_month_section_header.dart';
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
  Order? _filterOrder;
  List<InvoiceMonthGroup> _monthGroups = [];
  Map<int, int> _invoiceOrderCounts = {}; // invoiceId -> order count
  InvoiceState? _invoiceOrderCountState;
  List<int> _invoiceOrderCountIds = const [];
  Future<Map<int, int>>? _invoiceOrderCountsFuture;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _init();
  }

  @override
  void didUpdateWidget(covariant InvoicesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filterOrderId != widget.filterOrderId) {
      _filterOrder = null;
      _monthGroups = [];
      _invoiceOrderCounts = {};
      _resetInvoiceOrderCountsFuture();
      _init();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter > 600) return;
    ref.read(invoiceProvider.notifier).loadMoreInvoices();
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

  void _scrollToGroup(int index) {
    if (!_scrollController.hasClients || _monthGroups.isEmpty) return;
    if (index < 0 || index >= _monthGroups.length) return;

    // Calculate approximate offset for the group
    const estimatedItemHeight = 80.0;
    const estimatedHeaderHeight = 64.0;
    double targetOffset = 0;

    for (int i = 0; i < index; i++) {
      final group = _monthGroups[i];
      targetOffset +=
          estimatedHeaderHeight + (group.count * estimatedItemHeight);
    }

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Group invoices by year and month (descending order)
  List<InvoiceMonthGroup> _groupInvoicesByMonth(List<Invoice> invoices) {
    final Map<String, List<Invoice>> grouped = {};

    for (final invoice in invoices) {
      // Use invoiceDate if available, otherwise fall back to createdAt
      final dateStr = invoice.invoiceDate ?? invoice.createdAt;
      DateTime? date;
      try {
        date = DateTime.parse(dateStr);
      } catch (_) {
        continue;
      }

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
          final dateA = a.invoiceDate ?? a.createdAt;
          final dateB = b.invoiceDate ?? b.createdAt;
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

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 16,
        title: _buildPageTitle(
          context,
          _filterOrder != null
              ? '${_filterOrder!.shopName} 的发票'
              : AppConstants.titleInvoices,
        ),
        elevation: 0,
        actions: [
          if (widget.filterOrderId == null) ...[
            AppIconButton(
              icon: Icons.filter_list,
              onPressed: () => _showFilterDialog(context),
              tooltip: '筛选',
            ),
            const SizedBox(width: 8),
            AppIconButton(
              icon: Icons.search,
              onPressed: () => _showSearchDialog(context),
              tooltip: '搜索',
            ),
            const SizedBox(width: 12),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref
              .read(invoiceProvider.notifier)
              .loadInvoices(filterOrderId: widget.filterOrderId, refresh: true);
        },
        child: invoiceState.isLoading && invoiceState.invoices.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : invoiceState.invoices.isEmpty
            ? EmptyInvoices(onAdd: _handleAddInvoice)
            : FutureBuilder<Map<int, int>>(
                future: _orderCountsFutureFor(invoiceState),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    _invoiceOrderCounts = snapshot.data!;
                    _monthGroups = _groupInvoicesByMonth(invoiceState.invoices);
                  }

                  return MonthFastScrollLayout(
                    items: _monthGroups
                        .map(
                          (g) => MonthScrollItem(year: g.year, month: g.month),
                        )
                        .toList(),
                    onJumpToIndex: _scrollToGroup,
                    child: _buildGroupedList(invoiceState),
                  );
                },
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
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildGroupedList(InvoiceState invoiceState) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        ..._buildSliverGroups(),
        if (invoiceState.isLoading && invoiceState.invoices.isNotEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 112)),
      ],
    );
  }

  List<Widget> _buildSliverGroups() {
    return _monthGroups.map((group) {
      return SliverMainAxisGroup(
        slivers: [
          // Pinned section header (sticky)
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyMonthHeaderDelegate(
              year: group.year,
              month: group.month,
              invoiceCount: group.count,
              totalAmount: group.totalAmount,
            ),
          ),
          // Invoice cards with padding
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final invoice = group.invoices[index];
                return InvoiceCard(
                  invoice: invoice,
                  orderCount: group.getOrderCount(invoice.id!),
                  onTap: () => _handleInvoiceTap(invoice.id!),
                );
              }, childCount: group.invoices.length),
            ),
          ),
        ],
      );
    }).toList();
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
                ref.read(invoiceProvider.notifier).loadInvoices();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.today),
              title: const Text('今日发票'),
              onTap: () {
                ref.read(invoiceProvider.notifier).loadTodayInvoices();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('本月发票'),
              onTap: () {
                ref.read(invoiceProvider.notifier).loadThisMonthInvoices();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.date_range),
              title: const Text('按月份范围'),
              onTap: () async {
                Navigator.pop(context);
                final result = await SyncfusionMonthRangePicker.show(context);
                if (result != null) {
                  ref
                      .read(invoiceProvider.notifier)
                      .searchInvoices(
                        startDate: result.startDate,
                        endDate: result.endDate,
                      );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.link_off),
              title: const Text('未关联订单'),
              onTap: () {
                ref.read(invoiceProvider.notifier).loadInvoicesWithoutOrders();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('已关联订单'),
              onTap: () {
                ref
                    .read(invoiceProvider.notifier)
                    .searchInvoices(hasLinkedOrder: true);
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
      hint: '输入销售方名称',
    );

    if (query == null) return;

    if (query.isNotEmpty) {
      ref.read(invoiceProvider.notifier).searchInvoices(sellerName: query);
    } else {
      // Empty search returns all invoices
      ref.read(invoiceProvider.notifier).loadInvoices();
    }
  }
}

/// Delegate for sticky month header
class _StickyMonthHeaderDelegate extends SliverPersistentHeaderDelegate {
  final int year;
  final int month;
  final int invoiceCount;
  final double totalAmount;

  _StickyMonthHeaderDelegate({
    required this.year,
    required this.month,
    required this.invoiceCount,
    required this.totalAmount,
  });

  @override
  double get minExtent => 64;

  @override
  double get maxExtent => 64;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: InvoiceMonthSectionHeader(
          year: year,
          month: month,
          invoiceCount: invoiceCount,
          totalAmount: totalAmount,
          isPinned: overlapsContent,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyMonthHeaderDelegate oldDelegate) {
    return year != oldDelegate.year ||
        month != oldDelegate.month ||
        invoiceCount != oldDelegate.invoiceCount ||
        totalAmount != oldDelegate.totalAmount;
  }
}

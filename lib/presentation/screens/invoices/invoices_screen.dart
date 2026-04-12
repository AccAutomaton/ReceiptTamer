import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:receipt_tamer/core/constants/app_constants.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/presentation/providers/order_provider.dart';
import 'package:receipt_tamer/presentation/providers/invoice_provider.dart';
import 'package:receipt_tamer/presentation/widgets/common/empty_state.dart';
import 'package:receipt_tamer/presentation/widgets/common/syncfusion_month_range_picker.dart';
import 'package:receipt_tamer/presentation/widgets/invoice/invoice_card.dart';
import 'package:receipt_tamer/presentation/widgets/invoice/invoice_month_group.dart';
import 'package:receipt_tamer/presentation/widgets/invoice/invoice_month_section_header.dart';
import 'package:receipt_tamer/presentation/widgets/order/month_fast_scroll_bar.dart';

/// Invoices screen - displays list of all invoices grouped by month
class InvoicesScreen extends ConsumerStatefulWidget {
  final int? filterOrderId; // Optional: filter by order ID

  const InvoicesScreen({
    super.key,
    this.filterOrderId,
  });

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  final ScrollController _scrollController = ScrollController();
  Order? _filterOrder;
  List<InvoiceMonthGroup> _monthGroups = [];
  Map<int, int> _invoiceOrderCounts = {}; // invoiceId -> order count

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (widget.filterOrderId != null) {
      _filterOrder = await ref.read(orderProvider.notifier).getOrderById(widget.filterOrderId!);
    }
    // Use Future.microtask to delay provider modification until after build
    Future.microtask(() {
      _loadInvoices();
    });
  }

  void _loadInvoices() {
    ref.read(invoiceProvider.notifier).loadInvoices(
          filterOrderId: widget.filterOrderId,
        );
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
    final invoiceOrderCounts = <int, int>{};

    for (final invoice in invoices) {
      if (invoice.id != null) {
        final orderIds = await ref.read(invoiceProvider.notifier).getOrderIdsForInvoice(invoice.id!);
        invoiceOrderCounts[invoice.id!] = orderIds.length;
      }
    }

    return invoiceOrderCounts;
  }

  @override
  Widget build(BuildContext context) {
    final invoiceState = ref.watch(invoiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _filterOrder != null
              ? '${_filterOrder!.shopName} 的发票'
              : AppConstants.titleInvoices,
        ),
        elevation: 0,
        actions: [
          if (widget.filterOrderId == null) ...[
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () {
                _showFilterDialog(context);
              },
              tooltip: '筛选',
            ),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                _showSearchDialog(context);
              },
              tooltip: '搜索',
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(invoiceProvider.notifier).loadInvoices(
                filterOrderId: widget.filterOrderId,
                refresh: true,
              );
        },
        child: invoiceState.isLoading && invoiceState.invoices.isEmpty
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : invoiceState.invoices.isEmpty
                ? EmptyInvoices(
                    onAdd: _handleAddInvoice,
                  )
                : FutureBuilder<Map<int, int>>(
                    future: _loadInvoiceOrderCounts(invoiceState.invoices),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        _invoiceOrderCounts = snapshot.data!;
                        _monthGroups = _groupInvoicesByMonth(invoiceState.invoices);
                      }

                      return Row(
                        children: [
                          // Main list takes remaining space
                          Expanded(
                            child: _buildGroupedList(),
                          ),
                          // Fast scroll bar on the right (non-overlapping)
                          if (_monthGroups.length > 1)
                            MonthFastScrollBar(
                              items: _monthGroups
                                  .map((g) => MonthScrollItem(year: g.year, month: g.month))
                                  .toList(),
                              onJumpToIndex: _scrollToGroup,
                            ),
                        ],
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildGroupedList() {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        ..._buildSliverGroups(),
        const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
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
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final invoice = group.invoices[index];
                  return InvoiceCard(
                    invoice: invoice,
                    orderCount: group.getOrderCount(invoice.id!),
                    onTap: () => _handleInvoiceTap(invoice.id!),
                  );
                },
                childCount: group.invoices.length,
              ),
            ),
          ),
        ],
      );
    }).toList();
  }

  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '筛选发票',
                style: Theme.of(context).textTheme.titleLarge,
              ),
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
                    ref.read(invoiceProvider.notifier).searchInvoices(
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
                  ref.read(invoiceProvider.notifier).searchInvoices(
                        hasLinkedOrder: true,
                      );
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    final searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('搜索发票'),
        content: TextField(
          controller: searchController,
          decoration: const InputDecoration(
            hintText: '输入销售方名称',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final query = searchController.text.trim();
              Navigator.pop(context);
              if (query.isNotEmpty) {
                ref.read(invoiceProvider.notifier).searchInvoices(
                      sellerName: query,
                    );
              } else {
                // Empty search returns all invoices
                ref.read(invoiceProvider.notifier).loadInvoices();
              }
            },
            child: const Text('搜索'),
          ),
        ],
      ),
    );
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
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
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
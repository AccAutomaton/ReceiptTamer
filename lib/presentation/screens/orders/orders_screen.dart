import 'package:receipt_tamer/core/constants/app_constants.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/presentation/providers/order_provider.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_button.dart';
import 'package:receipt_tamer/presentation/widgets/common/empty_state.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_bottom_sheet.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_search_dialog.dart';
import 'package:receipt_tamer/presentation/widgets/common/syncfusion_month_range_picker.dart';
import 'package:receipt_tamer/presentation/widgets/order/month_group.dart';
import 'package:receipt_tamer/presentation/widgets/order/month_section_header.dart';
import 'package:receipt_tamer/presentation/widgets/order/month_fast_scroll_bar.dart';
import 'package:receipt_tamer/presentation/widgets/order/order_card.dart';
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
  List<MonthGroup> _monthGroups = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Load orders when screen initializes
    Future.microtask(() {
      ref.read(orderProvider.notifier).loadOrders();
    });
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
    ref.read(orderProvider.notifier).loadMoreOrders();
  }

  /// Group orders by year and month (descending order)
  List<MonthGroup> _groupOrdersByMonth(List<Order> orders) {
    final Map<String, List<Order>> grouped = {};

    for (final order in orders) {
      // Use orderDate if available, otherwise fall back to createdAt
      final dateStr = order.orderDate ?? order.createdAt;
      DateTime? date;
      try {
        date = DateTime.parse(dateStr);
      } catch (_) {
        continue;
      }

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
          final dateA = a.orderDate ?? a.createdAt;
          final dateB = b.orderDate ?? b.createdAt;
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

  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(orderProvider);

    // Group orders by month
    _monthGroups = orderState.orders.isEmpty
        ? []
        : _groupOrdersByMonth(orderState.orders);

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 16,
        title: _buildPageTitle(context, AppConstants.titleOrders),
        elevation: 0,
        actions: [
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
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(orderProvider.notifier).loadOrders(refresh: true);
        },
        child: orderState.isLoading && orderState.orders.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : orderState.orders.isEmpty
            ? EmptyOrders(onAdd: _handleAddOrder)
            : MonthFastScrollLayout(
                items: _monthGroups
                    .map((g) => MonthScrollItem(year: g.year, month: g.month))
                    .toList(),
                onJumpToIndex: _scrollToGroup,
                child: _buildGroupedList(orderState),
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

  Widget _buildGroupedList(OrderState orderState) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        ..._buildSliverGroups(),
        if (orderState.isLoading && orderState.orders.isNotEmpty)
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
              orderCount: group.count,
              totalAmount: group.totalAmount,
            ),
          ),
          // Order cards with padding
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final order = group.orders[index];
                final orderId = order.id;
                return OrderCard(
                  order: order,
                  onTap: orderId != null && orderId > 0
                      ? () => _handleOrderTap(orderId)
                      : null,
                );
              }, childCount: group.orders.length),
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
            Text('筛选订单', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('全部订单'),
              onTap: () {
                ref.read(orderProvider.notifier).loadOrders();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.today),
              title: const Text('今日订单'),
              onTap: () {
                ref.read(orderProvider.notifier).loadTodayOrders();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('本月订单'),
              onTap: () {
                ref.read(orderProvider.notifier).loadThisMonthOrders();
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
                      .read(orderProvider.notifier)
                      .searchOrders(
                        startDate: result.startDate,
                        endDate: result.endDate,
                      );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.link_off),
              title: const Text('未关联发票'),
              onTap: () {
                ref
                    .read(orderProvider.notifier)
                    .searchOrders(hasLinkedInvoice: false);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('已关联发票'),
              onTap: () {
                ref
                    .read(orderProvider.notifier)
                    .searchOrders(hasLinkedInvoice: true);
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
      ref
          .read(orderProvider.notifier)
          .searchOrders(shopName: query, orderNumber: query);
    } else {
      // Empty search returns all orders
      ref.read(orderProvider.notifier).loadOrders();
    }
  }
}

/// Delegate for sticky month header
class _StickyMonthHeaderDelegate extends SliverPersistentHeaderDelegate {
  final int year;
  final int month;
  final int orderCount;
  final double totalAmount;

  _StickyMonthHeaderDelegate({
    required this.year,
    required this.month,
    required this.orderCount,
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
        child: MonthSectionHeader(
          year: year,
          month: month,
          orderCount: orderCount,
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
        orderCount != oldDelegate.orderCount ||
        totalAmount != oldDelegate.totalAmount;
  }
}

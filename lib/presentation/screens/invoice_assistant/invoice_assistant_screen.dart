import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/core/utils/date_formatter.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/data/models/uninvoiced_shop_summary.dart';
import 'package:receipt_tamer/presentation/providers/invoice_assistant_provider.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_button.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_notice.dart';
import 'package:receipt_tamer/presentation/widgets/common/date_range_picker.dart';
import 'package:receipt_tamer/presentation/widgets/common/empty_state.dart';
import 'package:receipt_tamer/presentation/widgets/common/floating_overlay_layout.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_page_scaffold.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_surface.dart';

class InvoiceAssistantScreen extends ConsumerStatefulWidget {
  const InvoiceAssistantScreen({super.key});

  @override
  ConsumerState<InvoiceAssistantScreen> createState() =>
      _InvoiceAssistantScreenState();
}

class _InvoiceAssistantScreenState
    extends ConsumerState<InvoiceAssistantScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      // 每次从首页进入都从“全部日期”开始，避免延续上次任务的筛选。
      await ref.read(invoiceAssistantProvider.notifier).clearDateRange();
    });
  }

  Future<void> _showDateRangePicker() async {
    final state = ref.read(invoiceAssistantProvider);
    final result = await SyncfusionDateRangePicker.show(
      context,
      initialStartDate: state.startDate,
      initialEndDate: state.endDate,
    );

    if (result != null) {
      await ref
          .read(invoiceAssistantProvider.notifier)
          .setDateRange(result.startDate, result.endDate);
    }
  }

  Future<void> _openInvoiceEditor() async {
    final state = ref.read(invoiceAssistantProvider);
    if (state.selectedOrderIds.isEmpty) {
      AppNotice.warning(context, '请选择订单', duration: const Duration(seconds: 4));
      return;
    }

    final uri = Uri(
      path: '/invoices/new',
      queryParameters: {'orderIds': state.selectedOrderIds.join(',')},
    );
    final saved = await context.push<bool>(uri.toString());

    if (saved == true && mounted) {
      ref.read(invoiceAssistantProvider.notifier).clearSelection();
      await ref.read(invoiceAssistantProvider.notifier).loadSummaries();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(invoiceAssistantProvider);

    return GlassPageScaffold(
      appBar: AppBar(title: const Text('待关联发票订单'), elevation: 0),
      body: FloatingOverlayLayout(
        top: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFilterSection(context, state),
            if (state.startDate != null || state.endDate != null)
              _buildDateFilterChip(context, state),
            if (state.errorMessage != null) _buildErrorBanner(context),
          ],
        ),
        bodyBuilder: (context, contentPadding) =>
            _buildShopList(context, state, contentPadding),
        bottom: _buildBottomBar(context, state),
      ),
    );
  }

  Widget _buildFilterSection(
    BuildContext context,
    InvoiceAssistantState state,
  ) {
    final theme = Theme.of(context);
    final totalOrders = state.summaries.fold<int>(
      0,
      (sum, summary) => sum + summary.orderCount,
    );
    final totalAmount = state.summaries.fold<double>(
      0,
      (sum, summary) => sum + summary.totalAmount,
    );

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppPalette.actionSoftFillFor(context),
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          child: Icon(
            Icons.storefront,
            color: AppPalette.actionPrimaryFor(context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${state.summaries.length} 家店铺 · $totalOrders 笔订单',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormatter.formatAmount(totalAmount),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppPalette.amountFor(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        IconButton.outlined(
          onPressed: state.isLoadingSummaries ? null : _showDateRangePicker,
          icon: const Icon(Icons.date_range),
          tooltip: '日期筛选',
        ),
      ],
    );
  }

  Widget _buildDateFilterChip(
    BuildContext context,
    InvoiceAssistantState state,
  ) {
    final startStr = state.startDate != null
        ? DateFormatter.formatDisplay(state.startDate!)
        : '';
    final endStr = state.endDate != null
        ? DateFormatter.formatDisplay(state.endDate!)
        : '';
    final dateRangeStr = startStr == endStr ? startStr : '$startStr - $endStr';

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Chip(
          label: Text(dateRangeStr),
          deleteIcon: const Icon(Icons.close, size: 16),
          onDeleted: () =>
              ref.read(invoiceAssistantProvider.notifier).clearDateRange(),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 8),
            const Expanded(child: Text('加载失败', maxLines: 2)),
          ],
        ),
      ),
    );
  }

  Widget _buildShopList(
    BuildContext context,
    InvoiceAssistantState state,
    EdgeInsets contentPadding,
  ) {
    if (state.isLoadingSummaries && state.summaries.isEmpty) {
      return Padding(
        padding: contentPadding,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (state.summaries.isEmpty) {
      return Padding(
        padding: contentPadding,
        child: EmptyState(icon: Icons.receipt_long, title: '暂无待关联发票订单'),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(invoiceAssistantProvider.notifier).loadSummaries(),
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          12,
          contentPadding.top + 8,
          12,
          contentPadding.bottom + 8,
        ),
        itemCount: state.summaries.length,
        itemBuilder: (context, index) {
          final summary = state.summaries[index];
          final isExpanded = state.expandedShopKey == summary.shopKey;
          return _ShopSummaryCard(
            summary: summary,
            isExpanded: isExpanded,
            isLoading: state.loadingShopKeys.contains(summary.shopKey),
            orders: state.ordersByShop[summary.shopKey] ?? const [],
            selectedOrderIds: state.selectedShopKey == summary.shopKey
                ? state.selectedOrderIds
                : const {},
            onTap: () => ref
                .read(invoiceAssistantProvider.notifier)
                .loadOrdersForShop(summary.shopKey),
            onSelectAll: () => ref
                .read(invoiceAssistantProvider.notifier)
                .selectAllForShop(summary.shopKey),
            onClearSelection: () =>
                ref.read(invoiceAssistantProvider.notifier).clearSelection(),
            onToggleOrder: (order) => ref
                .read(invoiceAssistantProvider.notifier)
                .toggleOrderSelection(shopKey: summary.shopKey, order: order),
            onOpenOrder: (order) {
              if (order.id != null && order.id! > 0) {
                context.push('/orders/${order.id}');
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, InvoiceAssistantState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.hasSelection
                    ? '已选 ${state.selectedOrderIds.length} 笔'
                    : '未选择',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                state.hasSelection
                    ? '合计 ${DateFormatter.formatAmount(state.selectedTotalAmount)}'
                    : '选择订单',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: state.hasSelection
                      ? AppPalette.amountFor(context)
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        AppButton(
          text: '关联发票',
          onPressed: state.hasSelection ? _openInvoiceEditor : null,
          icon: const Icon(Icons.add),
          width: 148,
        ),
      ],
    );
  }
}

class _ShopSummaryCard extends StatelessWidget {
  final UninvoicedShopSummary summary;
  final bool isExpanded;
  final bool isLoading;
  final List<Order> orders;
  final Set<int> selectedOrderIds;
  final VoidCallback onTap;
  final VoidCallback onSelectAll;
  final VoidCallback onClearSelection;
  final ValueChanged<Order> onToggleOrder;
  final ValueChanged<Order> onOpenOrder;

  const _ShopSummaryCard({
    required this.summary,
    required this.isExpanded,
    required this.isLoading,
    required this.orders,
    required this.selectedOrderIds,
    required this.onTap,
    required this.onSelectAll,
    required this.onClearSelection,
    required this.onToggleOrder,
    required this.onOpenOrder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GlassSurface(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      fillColor: AppPalette.cardFillFor(context),
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadii.card),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          summary.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${summary.orderCount} 笔待关联发票订单',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormatter.formatAmount(summary.totalAmount),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppPalette.amountFor(context),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(18),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: orders.isEmpty ? null : onSelectAll,
                      icon: const Icon(Icons.select_all, size: 18),
                      label: const Text('全选'),
                    ),
                    const SizedBox(width: 8),
                    if (selectedOrderIds.isNotEmpty)
                      TextButton.icon(
                        onPressed: onClearSelection,
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('清空'),
                      ),
                  ],
                ),
              ),
              ...orders.map(
                (order) => _AssistantOrderCard(
                  order: order,
                  isSelected:
                      order.id != null && selectedOrderIds.contains(order.id),
                  onToggle: () => onToggleOrder(order),
                  onOpen: () => onOpenOrder(order),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _AssistantOrderCard extends StatelessWidget {
  final Order order;
  final bool isSelected;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  const _AssistantOrderCard({
    required this.order,
    required this.isSelected,
    required this.onToggle,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final orderDate = order.orderDate != null && order.orderDate!.isNotEmpty
        ? DateTime.tryParse(order.orderDate!)
        : null;
    final mealTime = DateFormatter.mealTimeFromString(order.mealTime);
    final formattedDate = orderDate != null
        ? DateFormatter.formatDisplay(orderDate)
        : order.orderDate ?? '-';
    final formattedMealTime = DateFormatter.mealTimeToDisplayName(mealTime);

    return InkWell(
      onTap: onToggle,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppPalette.selectedFillFor(context)
              : AppGlassTokens.contentFillFor(context),
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: isSelected
                ? AppPalette.actionPrimaryFor(context)
                : colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Checkbox(value: isSelected, onChanged: (_) => onToggle()),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$formattedDate $formattedMealTime',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (order.orderNumber.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      order.orderNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              DateFormatter.formatAmount(order.amount),
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppPalette.amountFor(context),
                fontWeight: FontWeight.w800,
              ),
            ),
            IconButton(
              onPressed: onOpen,
              tooltip: '查看订单详情',
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}

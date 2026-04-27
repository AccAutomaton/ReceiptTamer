import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:receipt_tamer/core/utils/date_formatter.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/presentation/providers/export_provider.dart';
import 'package:receipt_tamer/presentation/widgets/common/date_range_picker.dart';

/// Order export screen for selecting orders to export
/// 支持级联选择（关联同一发票的订单会被一并选中）
class OrderExportScreen extends ConsumerStatefulWidget {
  const OrderExportScreen({super.key});

  @override
  ConsumerState<OrderExportScreen> createState() => _OrderExportScreenState();
}

class _OrderExportScreenState extends ConsumerState<OrderExportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(exportProvider.notifier).loadAvailableOrders();
    });
  }

  Future<void> _showDateRangePicker() async {
    final state = ref.read(exportProvider);
    final result = await SyncfusionDateRangePicker.show(
      context,
      initialStartDate: state.startDate,
      initialEndDate: state.endDate,
    );

    if (result != null) {
      ref.read(exportProvider.notifier).setDateRange(
            result.startDate,
            result.endDate,
          );
    }
  }

  Future<void> _toggleSelection(int orderId) async {
    final message = await ref.read(exportProvider.notifier).toggleSelection(orderId);
    if (message != null && mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _selectAll() async {
    final message = await ref.read(exportProvider.notifier).selectAll();
    if (message != null && mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _invertSelection() async {
    final message = await ref.read(exportProvider.notifier).invertSelection();
    if (message != null && mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _navigateToExportOptions() async {
    final state = ref.read(exportProvider);

    if (state.totalSelectedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择要导出的订单')),
      );
      return;
    }

    // Get invoice IDs involved in selected orders
    final invoiceIds = await ref.read(exportProvider.notifier).getSelectedInvoiceIds();
    final orderIds = state.allSelectedIds;

    if (!mounted) return;

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
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(exportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('选择要导出的订单'),
      ),
      body: Column(
        children: [
          // Options and filters
          _buildOptionsSection(state, colorScheme),

          // Statistics card
          _buildStatisticsCard(state, colorScheme),

          // Order list
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.availableOrders.isEmpty
                    ? _buildEmptyState(colorScheme)
                    : _buildOrderList(state, colorScheme),
          ),

          // Bottom action bar
          _buildBottomBar(state, colorScheme),
        ],
      ),
    );
  }

  Widget _buildOptionsSection(ExportState state, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hint text
          Text(
            '选择订单后，关联同一发票的订单将被一并选中',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),

          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              TextButton.icon(
                onPressed: state.availableOrders.isEmpty ? null : _selectAll,
                icon: const Icon(Icons.select_all, size: 18),
                label: const Text('全选'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: state.availableOrders.isEmpty ? null : _invertSelection,
                icon: const Icon(Icons.flip, size: 18),
                label: const Text('反选'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _showDateRangePicker,
                icon: const Icon(Icons.calendar_month, size: 18),
                label: Text(
                  state.startDate != null ? '修改日期' : '日期筛选',
                ),
              ),
            ],
          ),

          // Date range chip
          if (state.startDate != null && state.endDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Chip(
                    label: Text(
                      '${DateFormatter.formatDisplay(state.startDate!)} - ${DateFormatter.formatDisplay(state.endDate!)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      ref.read(exportProvider.notifier).clearDateRange();
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard(ExportState state, ColorScheme colorScheme) {
    final selectedCount = state.totalSelectedCount;
    final totalCount = state.availableOrders.length;
    final selectableCount = state.availableOrders
        .where((o) => o.id != null && state.isSelectable(o.id!))
        .length;
    final involvedInvoiceCount = state.selectedIds.fold<int>(0, (sum, id) {
      return sum + (state.orderInvoiceCount[id] ?? 0);
    });

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selectedCount > 0
            ? colorScheme.primaryContainer.withValues(alpha: 0.3)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: selectedCount > 0 ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '共 $totalCount 条订单，可选 $selectableCount 条，已选 $selectedCount 条',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (involvedInvoiceCount > 0)
                  Text(
                    '涉及发票 $involvedInvoiceCount 张',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无订单数据',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(ExportState state, ColorScheme colorScheme) {
    return ListView.builder(
      itemCount: state.availableOrders.length,
      itemBuilder: (context, index) {
        final order = state.availableOrders[index];
        if (order.id == null) return const SizedBox.shrink();

        final isSelected = state.isSelected(order.id!);
        final isCascade = state.isCascadeSelected(order.id!);
        final isSelectable = state.isSelectable(order.id!);
        final invoiceCount = state.orderInvoiceCount[order.id!] ?? 0;

        return _OrderExportCard(
          order: order,
          isSelected: isSelected,
          isCascadeSelected: isCascade,
          isSelectable: isSelectable,
          invoiceCount: invoiceCount,
          onTap: isSelectable ? () => _toggleSelection(order.id!) : null,
        );
      },
    );
  }

  Widget _buildBottomBar(ExportState state, ColorScheme colorScheme) {
    final selectedCount = state.totalSelectedCount;
    final totalAmount = ref.read(exportProvider.notifier).getSelectedTotalAmount();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '已选择 $selectedCount 条订单',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  '合计: ${DateFormatter.formatAmount(totalAmount)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: selectedCount > 0 ? _navigateToExportOptions : null,
              icon: const Icon(Icons.file_download),
              label: const Text('导出'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Order card widget for export screen
/// 四种状态：直接选中、联动选中、未选中、不可选(未关联发票)
class _OrderExportCard extends StatelessWidget {
  final Order order;
  final bool isSelected;
  final bool isCascadeSelected;
  final bool isSelectable;
  final int invoiceCount;
  final VoidCallback? onTap;

  const _OrderExportCard({
    required this.order,
    required this.isSelected,
    required this.isCascadeSelected,
    required this.isSelectable,
    required this.invoiceCount,
    required this.onTap,
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

    // Determine card appearance based on state
    Color? backgroundColor;
    Color borderColor;
    double borderWidth;

    if (!isSelectable) {
      // Unselectable: gray semi-transparent
      backgroundColor = colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
      borderColor = colorScheme.outlineVariant.withValues(alpha: 0.3);
      borderWidth = 1;
    } else if (isCascadeSelected) {
      // Cascade selected: orange/tertiary
      backgroundColor = colorScheme.tertiaryContainer.withValues(alpha: 0.3);
      borderColor = colorScheme.tertiary;
      borderWidth = 2;
    } else if (isSelected) {
      // Directly selected: blue/primary
      backgroundColor = colorScheme.primaryContainer.withValues(alpha: 0.3);
      borderColor = colorScheme.primary;
      borderWidth = 2;
    } else {
      // Unselected: white background
      backgroundColor = null;
      borderColor = colorScheme.outlineVariant.withValues(alpha: 0.3);
      borderWidth = 1;
    }

    return Opacity(
      opacity: isSelectable ? 1.0 : 0.6,
      child: InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: backgroundColor ?? colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: borderWidth,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Checkbox or indicator - wrapped to match Flutter Checkbox size (40x40)
              SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: _buildCheckbox(colorScheme, theme),
                ),
              ),
              const SizedBox(width: 8),

              // Order info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Shop name with cascade indicator
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.shopName.isEmpty ? '未命名店铺' : order.shopName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isSelectable ? null : colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Cascade label
                        if (isCascadeSelected)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.link,
                                  size: 12,
                                  color: colorScheme.onTertiaryContainer,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '联动',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onTertiaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Order date and meal time
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: isSelectable
                              ? colorScheme.onSurfaceVariant
                              : colorScheme.onSurface.withValues(alpha: 0.38),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$formattedDate $formattedMealTime',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isSelectable
                                ? colorScheme.onSurfaceVariant
                                : colorScheme.onSurface.withValues(alpha: 0.38),
                          ),
                        ),
                      ],
                    ),

                    // Invoice count badge
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          invoiceCount > 0 ? Icons.receipt_long : Icons.link_off,
                          size: 14,
                          color: invoiceCount > 0
                              ? colorScheme.primary
                              : colorScheme.error.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          invoiceCount > 0 ? '关联 $invoiceCount 张发票' : '未关联发票',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: invoiceCount > 0
                                ? colorScheme.primary
                                : colorScheme.error.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Amount
              Text(
                DateFormatter.formatAmount(order.amount),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isSelectable ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.5),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox(ColorScheme colorScheme, ThemeData theme) {
    const double checkboxSize = 18.0; // Flutter Checkbox native size
    const double iconSize = 12.0;

    if (!isSelectable) {
      // Unselectable: disabled checkbox with consistent style
      return Container(
        width: checkboxSize,
        height: checkboxSize,
        decoration: BoxDecoration(
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.38),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }

    if (isCascadeSelected) {
      // Cascade selected: orange checkbox with link icon
      return Container(
        width: checkboxSize,
        height: checkboxSize,
        decoration: BoxDecoration(
          color: colorScheme.tertiary,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Icon(
          Icons.link,
          size: iconSize,
          color: colorScheme.onTertiary,
        ),
      );
    }

    if (isSelected) {
      // Directly selected: blue checkbox with checkmark
      return Container(
        width: checkboxSize,
        height: checkboxSize,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Icon(
          Icons.check,
          size: iconSize,
          color: colorScheme.onPrimary,
        ),
      );
    }

    // Unselected: empty checkbox
    return Container(
      width: checkboxSize,
      height: checkboxSize,
      decoration: BoxDecoration(
        border: Border.all(
          color: colorScheme.outline,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
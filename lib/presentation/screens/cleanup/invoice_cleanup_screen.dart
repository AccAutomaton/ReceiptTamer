import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:receipt_tamer/core/utils/date_formatter.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/services/cleanup_service.dart';
import 'package:receipt_tamer/presentation/providers/cleanup_provider.dart';
import 'package:receipt_tamer/presentation/widgets/common/date_range_picker.dart';

/// Invoice cleanup screen for selecting and deleting invoices
class InvoiceCleanupScreen extends ConsumerStatefulWidget {
  const InvoiceCleanupScreen({super.key});

  @override
  ConsumerState<InvoiceCleanupScreen> createState() => _InvoiceCleanupScreenState();
}

class _InvoiceCleanupScreenState extends ConsumerState<InvoiceCleanupScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Switch to invoice mode and load data
      ref.read(cleanupProvider.notifier).setMode(CleanupMode.invoices);
      ref.read(cleanupProvider.notifier).loadAvailableItems();
    });
  }

  Future<void> _showDateRangePicker() async {
    final state = ref.read(cleanupProvider);
    final result = await SyncfusionDateRangePicker.show(
      context,
      initialStartDate: state.startDate,
      initialEndDate: state.endDate,
    );

    if (result != null) {
      ref.read(cleanupProvider.notifier).setDateRange(
            result.startDate,
            result.endDate,
          );
    }
  }

  Future<void> _toggleSelection(int invoiceId) async {
    final message = await ref.read(cleanupProvider.notifier).toggleSelection(invoiceId);
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
    final message = await ref.read(cleanupProvider.notifier).selectAll();
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
    final message = await ref.read(cleanupProvider.notifier).invertSelection();
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

  Future<void> _confirmDelete() async {
    final state = ref.read(cleanupProvider);

    // Build confirmation message
    final invoicesCount = state.totalSelectedCount;

    // Get actual order count from provider
    final ordersCount = await ref.read(cleanupProvider.notifier).getRelatedOrderCount();

    if (!mounted) return;

    final colorScheme = Theme.of(context).colorScheme;

    String message = '确定要删除 $invoicesCount 张发票吗？';
    if (state.deleteRelatedItems && ordersCount > 0) {
      message += '\n\n将同时删除 $ordersCount 条关联订单。';
    }
    message += '\n\n此操作不可撤销。';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Execute cleanup
    final result = await ref.read(cleanupProvider.notifier).executeCleanup();

    if (!mounted) return;

    if (result != null) {
      // Show result
      _showResultDialog(result);

      // Pop back to settings if no items left
      if (ref.read(cleanupProvider).availableInvoices.isEmpty) {
        context.pop();
      }
    }
  }

  void _showResultDialog(CleanupResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清理完成'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('已删除 ${result.invoicesDeleted} 张发票'),
            if (result.ordersDeleted > 0)
              Text('已删除 ${result.ordersDeleted} 条订单'),
            Text('已删除 ${result.filesDeleted} 个文件'),
            if (result.spaceFreedBytes > 0)
              Text('释放空间: ${_formatBytes(result.spaceFreedBytes)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(cleanupProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('选择要删除的发票'),
      ),
      body: Column(
        children: [
          // Options and filters
          _buildOptionsSection(state, colorScheme),

          // Statistics card
          _buildStatisticsCard(state, colorScheme),

          // Invoice list
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.availableInvoices.isEmpty
                    ? _buildEmptyState(colorScheme)
                    : _buildInvoiceList(state, colorScheme),
          ),

          // Bottom action bar
          _buildBottomBar(state, colorScheme),
        ],
      ),
    );
  }

  Widget _buildOptionsSection(CleanupState state, ColorScheme colorScheme) {
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
        children: [
          // Delete related orders toggle
          Row(
            children: [
              Checkbox(
                value: state.deleteRelatedItems,
                onChanged: (_) {
                  ref.read(cleanupProvider.notifier).toggleDeleteRelatedItems();
                },
              ),
              Expanded(
                child: InkWell(
                  onTap: () {
                    ref.read(cleanupProvider.notifier).toggleDeleteRelatedItems();
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('同时删除关联订单'),
                      Text(
                        '勾选后，关联同一订单的发票将自动选中',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              TextButton.icon(
                onPressed: state.availableInvoices.isEmpty ? null : _selectAll,
                icon: const Icon(Icons.select_all, size: 18),
                label: const Text('全选'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: state.availableInvoices.isEmpty ? null : _invertSelection,
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
                      ref.read(cleanupProvider.notifier).clearDateRange();
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard(CleanupState state, ColorScheme colorScheme) {
    final selectedCount = state.totalSelectedCount;
    final totalCount = state.availableInvoices.length;
    final orderCount = state.selectedIds.fold<int>(0, (sum, id) {
      return sum + (state.invoiceOrderCount[id] ?? 0);
    });

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selectedCount > 0
            ? colorScheme.errorContainer.withValues(alpha: 0.3)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: selectedCount > 0 ? colorScheme.error : colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '共 $totalCount 张发票，已选 $selectedCount 张',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (orderCount > 0)
                  Text(
                    '涉及关联订单 $orderCount 条',
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
            '暂无发票数据',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceList(CleanupState state, ColorScheme colorScheme) {
    return ListView.builder(
      itemCount: state.availableInvoices.length,
      itemBuilder: (context, index) {
        final invoice = state.availableInvoices[index];
        if (invoice.id == null) return const SizedBox.shrink();

        final isSelected = state.isSelected(invoice.id!);
        final isCascade = state.isCascadeSelected(invoice.id!);
        final orderCount = state.invoiceOrderCount[invoice.id!] ?? 0;

        return _InvoiceCleanupCard(
          invoice: invoice,
          isSelected: isSelected,
          isCascadeSelected: isCascade,
          orderCount: orderCount,
          onTap: () => _toggleSelection(invoice.id!),
        );
      },
    );
  }

  Widget _buildBottomBar(CleanupState state, ColorScheme colorScheme) {
    final selectedCount = state.totalSelectedCount;
    final totalAmount = state.availableInvoices
        .where((i) => i.id != null && state.isSelected(i.id!))
        .fold<double>(0, (sum, i) => sum + i.totalAmount);

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
                  '已选择 $selectedCount 张发票',
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
              onPressed: selectedCount > 0 && !state.isDeleting
                  ? _confirmDelete
                  : null,
              icon: state.isDeleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.delete),
              label: Text(state.isDeleting ? '删除中...' : '确认删除'),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Invoice card widget for cleanup screen
class _InvoiceCleanupCard extends StatelessWidget {
  final Invoice invoice;
  final bool isSelected;
  final bool isCascadeSelected;
  final int orderCount;
  final VoidCallback onTap;

  const _InvoiceCleanupCard({
    required this.invoice,
    required this.isSelected,
    required this.isCascadeSelected,
    required this.orderCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final invoiceDate = invoice.invoiceDate != null && invoice.invoiceDate!.isNotEmpty
        ? DateTime.tryParse(invoice.invoiceDate!)
        : null;
    final formattedDate = invoiceDate != null
        ? DateFormatter.formatDisplay(invoiceDate)
        : invoice.invoiceDate ?? '-';

    Color? backgroundColor;
    if (isCascadeSelected) {
      backgroundColor = colorScheme.tertiaryContainer.withValues(alpha: 0.3);
    } else if (isSelected) {
      backgroundColor = colorScheme.primaryContainer.withValues(alpha: 0.3);
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox or cascade indicator
            if (isCascadeSelected)
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                child: Icon(
                  Icons.link,
                  color: colorScheme.tertiary,
                  size: 20,
                ),
              )
            else
              Checkbox(
                value: isSelected,
                onChanged: (_) => onTap(),
              ),

            const SizedBox(width: 8),

            // Invoice info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Seller name with cascade indicator
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          invoice.sellerName.isEmpty ? '未命名店铺' : invoice.sellerName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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
                          child: Text(
                            '关联',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Invoice date
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formattedDate,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),

                  // Invoice number
                  if (invoice.invoiceNumber.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.numbers,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            invoice.invoiceNumber,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Order count badge
                  if (orderCount > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 14,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '关联 $orderCount 条订单',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Amount
            Text(
              DateFormatter.formatAmount(invoice.totalAmount),
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
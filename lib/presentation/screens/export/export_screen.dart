import 'package:receipt_tamer/core/constants/app_constants.dart';
import 'package:receipt_tamer/core/services/log_service.dart';
import 'package:receipt_tamer/core/services/log_config.dart';
import 'package:receipt_tamer/core/utils/date_formatter.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/presentation/providers/invoice_provider.dart';
import 'package:receipt_tamer/presentation/widgets/common/date_range_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Export screen - export reimbursement materials
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  Set<int> _selectedInvoiceIds = {};
  Set<int> _selectedOrderIds = {};
  Map<int, int> _invoiceOrderCounts = {}; // invoiceId -> order count

  List<Invoice> _availableInvoices = [];
  bool _isLoadingInvoices = false;

  @override
  void initState() {
    super.initState();
    // Default to no date filter
    // Load invoices after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInvoices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text(AppConstants.titleExport), elevation: 0),
      body: Column(
        children: [
          // Options and filters section
          _buildOptionsSection(theme, colorScheme),

          // Statistics card
          _buildStatisticsCard(theme, colorScheme),

          // Invoice list
          Expanded(
            child: _isLoadingInvoices
                ? const Center(child: CircularProgressIndicator())
                : _availableInvoices.isEmpty
                    ? _buildEmptyState(colorScheme)
                    : _buildInvoiceList(colorScheme),
          ),

          // Fixed export button at bottom
          _buildBottomBar(theme, colorScheme),
        ],
      ),
    );
  }

  Widget _buildOptionsSection(ThemeData theme, ColorScheme colorScheme) {
    final selectableInvoices = _availableInvoices
        .where((i) => i.id != null && (_invoiceOrderCounts[i.id] ?? 0) > 0)
        .toList();

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
            '选择发票后，关联订单将被自动选中',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 12),

          // Action buttons row
          Row(
            children: [
              TextButton.icon(
                onPressed: selectableInvoices.isEmpty ? null : _selectAll,
                icon: const Icon(Icons.select_all, size: 18),
                label: const Text('全选'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: selectableInvoices.isEmpty ? null : _invertSelection,
                icon: const Icon(Icons.flip, size: 18),
                label: const Text('反选'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _showDateRangePicker,
                icon: const Icon(Icons.calendar_month, size: 18),
                label: const Text('日期筛选'),
              ),
            ],
          ),

          // Date range chip
          if (_startDate != null && _endDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Chip(
                    label: Text(
                      '${DateFormatter.formatDisplay(_startDate!)} - ${DateFormatter.formatDisplay(_endDate!)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: _clearDateRange,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard(ThemeData theme, ColorScheme colorScheme) {
    final selectableInvoices = _availableInvoices
        .where((i) => i.id != null && (_invoiceOrderCounts[i.id] ?? 0) > 0)
        .toList();
    final selectableCount = selectableInvoices.length;
    final selectedCount = _selectedInvoiceIds.length;

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
                  '共 ${_availableInvoices.length} 张发票，可选 $selectableCount 张，已选 $selectedCount 张',
                  style: theme.textTheme.bodyMedium,
                ),
                if (_selectedOrderIds.isNotEmpty)
                  Text(
                    '关联订单 ${_selectedOrderIds.length} 条',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          // Quick filter button
          TextButton.icon(
            onPressed: selectableInvoices.isEmpty ? null : _showQuickFilterDialog,
            icon: const Icon(Icons.filter_list, size: 18),
            label: const Text('快速筛选'),
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
            '该日期范围内没有发票',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceList(ColorScheme colorScheme) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _availableInvoices.length,
      itemBuilder: (context, index) {
        final invoice = _availableInvoices[index];
        final isSelected = _selectedInvoiceIds.contains(invoice.id);
        final orderCount = _invoiceOrderCounts[invoice.id!] ?? 0;
        final isSelectable = orderCount > 0;

        return _InvoiceSelectorCard(
          invoice: invoice,
          orderCount: orderCount,
          isSelected: isSelected,
          isSelectable: isSelectable,
          onChanged: isSelectable
              ? (selected) {
                  _toggleInvoiceSelection(invoice, selected);
                }
              : null,
        );
      },
    );
  }

  Widget _buildBottomBar(ThemeData theme, ColorScheme colorScheme) {
    final selectedInvoices = _availableInvoices
        .where((i) => _selectedInvoiceIds.contains(i.id))
        .toList();
    final invoiceTotal = selectedInvoices.fold<double>(
      0,
      (sum, invoice) => sum + invoice.totalAmount,
    );

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
                  '已选择 ${_selectedInvoiceIds.length} 张发票',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  '合计: ${DateFormatter.formatAmount(invoiceTotal)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _selectedInvoiceIds.isEmpty ? null : _navigateToExportOptions,
              icon: const Icon(Icons.file_download),
              label: const Text('导出'),
            ),
          ],
        ),
      ),
    );
  }

  void _selectAll() {
    final selectableInvoices = _availableInvoices
        .where((i) => i.id != null && (_invoiceOrderCounts[i.id] ?? 0) > 0)
        .toList();

    setState(() {
      _selectedInvoiceIds = selectableInvoices.map((i) => i.id!).toSet();
      _updateSelectedOrders();
    });
  }

  void _invertSelection() {
    final selectableInvoices = _availableInvoices
        .where((i) => i.id != null && (_invoiceOrderCounts[i.id] ?? 0) > 0)
        .toList();

    setState(() {
      final newSelectedIds = <int>{};
      for (final invoice in selectableInvoices) {
        if (!_selectedInvoiceIds.contains(invoice.id)) {
          newSelectedIds.add(invoice.id!);
        }
      }
      _selectedInvoiceIds = newSelectedIds;
      _updateSelectedOrders();
    });
  }

  Future<void> _showDateRangePicker() async {
    final result = await SyncfusionDateRangePicker.show(
      context,
      initialStartDate: _startDate,
      initialEndDate: _endDate,
    );

    if (result != null) {
      setState(() {
        _startDate = result.startDate;
        _endDate = result.endDate;
      });
      _loadInvoicesIfReady();
    }
  }

  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _loadInvoices();
  }

  void _loadInvoicesIfReady() {
    if (_startDate != null && _endDate != null) {
      if (_startDate!.isAfter(_endDate!)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('开始日期不能晚于结束日期')));
        return;
      }
    }
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() {
      _isLoadingInvoices = true;
      _selectedInvoiceIds.clear();
      _selectedOrderIds.clear();
      _invoiceOrderCounts.clear();
    });

    try {
      // Load invoices - use all if no date filter, or by date range
      List<Invoice> invoices;
      if (_startDate != null && _endDate != null) {
        invoices = await ref
            .read(invoiceProvider.notifier)
            .getByDateRangeForExport(_startDate!, _endDate!);
      } else {
        invoices = await ref.read(invoiceProvider.notifier).getAllForExport();
      }

      // Load order counts for each invoice
      final orderCounts = <int, int>{};
      for (final invoice in invoices) {
        if (invoice.id != null) {
          final count = await ref
              .read(invoiceProvider.notifier)
              .getOrderCountForInvoice(invoice.id!);
          orderCounts[invoice.id!] = count;
        }
      }

      setState(() {
        // Sort by date descending
        invoices.sort((a, b) {
          final dateA = a.invoiceDate != null && a.invoiceDate!.isNotEmpty
              ? DateTime.tryParse(a.invoiceDate!) ?? DateTime(1970)
              : DateTime(1970);
          final dateB = b.invoiceDate != null && b.invoiceDate!.isNotEmpty
              ? DateTime.tryParse(b.invoiceDate!) ?? DateTime(1970)
              : DateTime(1970);
          return dateB.compareTo(dateA);
        });
        _availableInvoices = invoices;
        _invoiceOrderCounts = orderCounts;
        _isLoadingInvoices = false;
        // Don't auto-select, let user choose
      });

      // Update selected orders
      _updateSelectedOrders();
    } catch (e, stackTrace) {
      setState(() {
        _isLoadingInvoices = false;
      });
      if (mounted) {
        logService.e(LogConfig.moduleUi, '加载发票失败', e, stackTrace);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载发票失败: $e')));
      }
    }
  }

  void _toggleInvoiceSelection(Invoice invoice, bool selected) {
    setState(() {
      if (selected) {
        _selectedInvoiceIds.add(invoice.id!);
      } else {
        _selectedInvoiceIds.remove(invoice.id!);
      }
      _updateSelectedOrders();
    });
  }

  void _updateSelectedOrders() async {
    final orderIds = <int>{};
    for (final invoiceId in _selectedInvoiceIds) {
      final ids = await ref
          .read(invoiceProvider.notifier)
          .getOrderIdsForInvoice(invoiceId);
      orderIds.addAll(ids);
    }

    setState(() {
      _selectedOrderIds = orderIds;
    });
  }

  void _showQuickFilterDialog() {
    final selectableInvoices = _availableInvoices
        .where((i) => (_invoiceOrderCounts[i.id] ?? 0) > 0)
        .toList();

    if (selectableInvoices.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('没有可选的发票')));
      return;
    }

    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('快速筛选'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('选择金额最高的前N张发票', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(
              '可选发票数量: ${selectableInvoices.length}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '数量 N',
                hintText: '请输入数字',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final input = controller.text.trim();
              Navigator.pop(context);

              if (input.isEmpty) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('请输入数量')));
                return;
              }

              final n = int.tryParse(input);
              if (n == null || n <= 0) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('请输入有效的正整数')));
                return;
              }

              if (n > selectableInvoices.length) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('数量不能超过 ${selectableInvoices.length}'),
                  ),
                );
                return;
              }

              // Sort by amount descending and select top N
              final sortedInvoices = List<Invoice>.from(selectableInvoices)
                ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

              setState(() {
                _selectedInvoiceIds = sortedInvoices
                    .take(n)
                    .map((i) => i.id!)
                    .toSet();
                _updateSelectedOrders();
              });
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _navigateToExportOptions() {
    if (_selectedInvoiceIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请选择要导出的发票')));
      return;
    }

    context.pushNamed(
      'export_options',
      queryParameters: {
        'invoiceIds': _selectedInvoiceIds.join(','),
        'orderIds': _selectedOrderIds.join(','),
      },
    );
  }
}

/// Invoice selector card with checkbox
class _InvoiceSelectorCard extends StatelessWidget {
  final Invoice invoice;
  final int orderCount;
  final bool isSelected;
  final bool isSelectable;
  final ValueChanged<bool>? onChanged;

  const _InvoiceSelectorCard({
    required this.invoice,
    required this.orderCount,
    required this.isSelected,
    required this.isSelectable,
    required this.onChanged,
  });

  void _navigateToDetail(BuildContext context) {
    if (invoice.id != null) {
      context.pushNamed(
        'invoice_detail',
        pathParameters: {'id': invoice.id.toString()},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final invoiceDate =
        invoice.invoiceDate != null && invoice.invoiceDate!.isNotEmpty
        ? DateTime.tryParse(invoice.invoiceDate!)
        : null;
    final formattedDate = invoiceDate != null
        ? DateFormatter.formatDisplay(invoiceDate)
        : invoice.invoiceDate ?? '-';

    final disabledColor = colorScheme.onSurface.withValues(alpha: 0.38);

    return Opacity(
      opacity: isSelectable ? 1.0 : 0.5,
      child: GestureDetector(
        onDoubleTap: () => _navigateToDetail(context),
        child: InkWell(
          onTap: isSelectable ? () => onChanged?.call(!isSelected) : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                  : colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // Checkbox
                Checkbox(
                  value: isSelected,
                  onChanged: isSelectable
                      ? (v) => onChanged?.call(v ?? false)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              invoice.sellerName.isEmpty
                                  ? '未知商家'
                                  : invoice.sellerName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: isSelectable ? null : disabledColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            DateFormatter.formatAmount(invoice.totalAmount),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: isSelectable
                                  ? colorScheme.primary
                                  : disabledColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.event,
                            size: 12,
                            color: isSelectable
                                ? colorScheme.onSurfaceVariant
                                : disabledColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formattedDate,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isSelectable
                                  ? colorScheme.onSurfaceVariant
                                  : disabledColor,
                            ),
                          ),
                          if (orderCount > 0) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.link,
                              size: 12,
                              color: isSelectable
                                  ? colorScheme.onSurfaceVariant
                                  : disabledColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$orderCount条订单',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isSelectable
                                    ? colorScheme.onSurfaceVariant
                                    : disabledColor,
                              ),
                            ),
                          ] else ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.link_off,
                              size: 12,
                              color: colorScheme.error.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '未关联订单',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.error.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper widget to constrain max height while allowing content to scroll
class ConstrainedConstraints extends StatelessWidget {
  final double maxHeight;
  final Widget child;

  const ConstrainedConstraints({
    required this.maxHeight,
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: child,
    );
  }
}

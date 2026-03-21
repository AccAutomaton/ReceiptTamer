import 'package:receipt_tamer/core/constants/app_constants.dart';
import 'package:receipt_tamer/core/utils/date_formatter.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/presentation/providers/order_provider.dart';
import 'package:receipt_tamer/presentation/providers/invoice_provider.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_button.dart';
import 'package:receipt_tamer/presentation/widgets/common/empty_state.dart';
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
  double _orderTotalAmount = 0; // Total amount of selected orders

  List<Invoice> _availableInvoices = [];
  bool _isLoadingInvoices = false;

  @override
  void initState() {
    super.initState();
    // Default to current month range
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(
      now.year,
      now.month + 1,
      0,
    ); // Last day of current month
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
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Date range selection
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Start date
                        Text(
                          '开始日期',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _selectStartDate(context),
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text(
                              _startDate != null
                                  ? DateFormatter.formatDisplay(_startDate!)
                                  : '请选择',
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // End date
                        Text(
                          '截止日期',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _selectEndDate(context),
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text(
                              _endDate != null
                                  ? DateFormatter.formatDisplay(_endDate!)
                                  : '请选择',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Invoice selection section (always show since dates are initialized)
                _buildInvoiceSelectionCard(context),
                const SizedBox(height: 16),

                // Preview section (always show, displays zeros when nothing selected)
                _buildPreviewCard(context),
                const SizedBox(height: 24),
              ],
            ),
          ),
          // Fixed export button at bottom
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: AppButton(
                text: '导出报销材料',
                onPressed: _selectedInvoiceIds.isEmpty ? null : _navigateToExportOptions,
                isFullWidth: true,
                type: AppButtonType.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceSelectionCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectableInvoices = _availableInvoices
        .where((i) => i.id != null && (_invoiceOrderCounts[i.id] ?? 0) > 0)
        .toList();
    final selectableCount = selectableInvoices.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '发票选择',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Select all button
                TextButton(
                  onPressed: selectableCount == 0
                      ? null
                      : () {
                          setState(() {
                            // Select all selectable invoices
                            _selectedInvoiceIds = selectableInvoices
                                .map((i) => i.id!)
                                .toSet();
                            _updateSelectedOrders();
                          });
                        },
                  child: const Text('全选'),
                ),
                // Invert selection button
                TextButton(
                  onPressed: selectableCount == 0
                      ? null
                      : () {
                          setState(() {
                            // Invert selection: selected -> unselected, unselected -> selected
                            final newSelectedIds = <int>{};
                            for (final invoice in selectableInvoices) {
                              if (!_selectedInvoiceIds.contains(invoice.id)) {
                                newSelectedIds.add(invoice.id!);
                              }
                            }
                            _selectedInvoiceIds = newSelectedIds;
                            _updateSelectedOrders();
                          });
                        },
                  child: const Text('反选'),
                ),
                // Quick filter button
                TextButton.icon(
                  onPressed: selectableCount == 0
                      ? null
                      : _showQuickFilterDialog,
                  icon: const Icon(Icons.filter_list, size: 18),
                  label: const Text('快速筛选'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '共 ${_availableInvoices.length} 张发票，可选 $selectableCount 张，已选 ${_selectedInvoiceIds.length} 张',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '双击发票可查看详情',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.outline,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 12),

            // Invoice list
            if (_isLoadingInvoices)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_availableInvoices.isEmpty)
              const EmptyState(
                icon: Icons.description_outlined,
                title: '该日期范围内没有发票',
                isCompact: true,
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _availableInvoices.length,
                  itemBuilder: (context, index) {
                    final invoice = _availableInvoices[index];
                    final isSelected = _selectedInvoiceIds.contains(invoice.id);
                    final orderCount = _invoiceOrderCounts[invoice.id] ?? 0;
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
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard(BuildContext context) {
    final theme = Theme.of(context);

    // Calculate totals
    final selectedInvoices = _availableInvoices
        .where((i) => _selectedInvoiceIds.contains(i.id))
        .toList();
    final invoiceTotal = selectedInvoices.fold<double>(
      0,
      (sum, invoice) => sum + invoice.totalAmount,
    );

    final orderTotal = _selectedOrderIds.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '导出预览',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildPreviewItem(
                      context,
                      '发票',
                      '${selectedInvoices.length} 张',
                      DateFormatter.formatAmount(invoiceTotal),
                      Icons.description,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildPreviewItem(
                      context,
                      '关联订单',
                      '$orderTotal 条',
                      DateFormatter.formatAmount(_orderTotalAmount),
                      Icons.receipt_long,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewItem(
    BuildContext context,
    String label,
    String count,
    String amount,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      constraints: const BoxConstraints(
        minHeight: 76,
      ), // Minimum height for consistency
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            count,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          // Always show amount row for consistent height
          Text(
            amount.isNotEmpty ? amount : '-',
            style: theme.textTheme.bodySmall?.copyWith(
              color: amount.isNotEmpty
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
      _loadInvoicesIfReady();
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
      _loadInvoicesIfReady();
    }
  }

  void _loadInvoicesIfReady() {
    if (_startDate != null && _endDate != null) {
      if (_startDate!.isAfter(_endDate!)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('开始日期不能晚于结束日期')));
        return;
      }
      _loadInvoices();
    }
  }

  Future<void> _loadInvoices() async {
    if (_startDate == null || _endDate == null) return;

    setState(() {
      _isLoadingInvoices = true;
      _selectedInvoiceIds.clear();
      _selectedOrderIds.clear();
      _invoiceOrderCounts.clear();
    });

    try {
      final invoices = await ref
          .read(invoiceProvider.notifier)
          .getByDateRangeForExport(_startDate!, _endDate!);

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

      // Auto-select all selectable invoices (those with orders)
      final selectableIds = invoices
          .where((i) => i.id != null && (orderCounts[i.id] ?? 0) > 0)
          .map((i) => i.id!)
          .toSet();

      setState(() {
        _availableInvoices = invoices;
        _invoiceOrderCounts = orderCounts;
        _isLoadingInvoices = false;
        _selectedInvoiceIds = selectableIds;
      });

      // Update selected orders
      _updateSelectedOrders();
    } catch (e) {
      setState(() {
        _isLoadingInvoices = false;
      });
      if (mounted) {
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

    // Calculate total amount of selected orders
    double totalAmount = 0;
    for (final orderId in orderIds) {
      final order = await ref.read(orderProvider.notifier).getOrderById(orderId);
      if (order != null) {
        totalAmount += order.amount;
      }
    }

    setState(() {
      _selectedOrderIds = orderIds;
      _orderTotalAmount = totalAmount;
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            margin: const EdgeInsets.only(bottom: 8),
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

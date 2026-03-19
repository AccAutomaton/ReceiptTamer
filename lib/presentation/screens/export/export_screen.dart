import 'dart:io';

import 'package:catering_receipt_recorder/core/constants/app_constants.dart';
import 'package:catering_receipt_recorder/core/utils/date_formatter.dart';
import 'package:catering_receipt_recorder/data/models/invoice.dart';
import 'package:catering_receipt_recorder/data/models/order.dart';
import 'package:catering_receipt_recorder/data/services/pdf_export_service.dart';
import 'package:catering_receipt_recorder/presentation/providers/order_provider.dart';
import 'package:catering_receipt_recorder/presentation/providers/invoice_provider.dart';
import 'package:catering_receipt_recorder/presentation/widgets/common/app_button.dart';
import 'package:catering_receipt_recorder/presentation/widgets/common/empty_state.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' as share_plus;

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

  final TextEditingController _topAmountController = TextEditingController();

  bool _isExporting = false;

  @override
  void dispose() {
    _topAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.titleExport),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Date range selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '日期范围',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _selectStartDate(context),
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text(
                            _startDate != null
                                ? DateFormatter.formatDisplay(_startDate!)
                                : '开始日期',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _selectEndDate(context),
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text(
                            _endDate != null
                                ? DateFormatter.formatDisplay(_endDate!)
                                : '结束日期',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_startDate != null && _endDate != null)
                    Text(
                      '已选择: ${DateFormatter.formatDisplay(_startDate!)} - ${DateFormatter.formatDisplay(_endDate!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Invoice selection section
          if (_startDate != null && _endDate != null) ...[
            _buildInvoiceSelectionCard(context),
            const SizedBox(height: 16),
          ],

          // Preview section
          if (_selectedInvoiceIds.isNotEmpty) ...[
            _buildPreviewCard(context),
            const SizedBox(height: 24),
          ],

          // Export button
          AppButton(
            text: '导出报销材料',
            onPressed: _selectedInvoiceIds.isEmpty ? null : _handleExport,
            isLoading: _isExporting,
            isFullWidth: true,
            type: AppButtonType.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceSelectionCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '发票选择',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Quick selection row
                Row(
                  children: [
                    SizedBox(
                      width: 60,
                      height: 36,
                      child: TextField(
                        controller: _topAmountController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 8),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _selectTopInvoicesByAmount,
                      child: const Text('选前N张'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '共 ${_availableInvoices.length} 张发票，已选 ${_selectedInvoiceIds.length} 张',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
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
              ConstrainedConstraints(
                maxHeight: 400,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _availableInvoices.length,
                  itemBuilder: (context, index) {
                    final invoice = _availableInvoices[index];
                    final isSelected = _selectedInvoiceIds.contains(invoice.id);
                    final orderCount = _invoiceOrderCounts[invoice.id] ?? 0;

                    return _InvoiceSelectorCard(
                      invoice: invoice,
                      orderCount: orderCount,
                      isSelected: isSelected,
                      onChanged: (selected) {
                        _toggleInvoiceSelection(invoice, selected);
                      },
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
            Row(
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
                    '', // Could calculate order amount if needed
                    Icons.receipt_long,
                  ),
                ),
              ],
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 4),
          Text(
            count,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (amount.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              amount,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.primary,
              ),
            ),
          ],
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('开始日期不能晚于结束日期')),
        );
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

      setState(() {
        _availableInvoices = invoices;
        _invoiceOrderCounts = orderCounts;
        _isLoadingInvoices = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingInvoices = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载发票失败: $e')),
        );
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

  void _selectTopInvoicesByAmount() {
    final input = _topAmountController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入数量')),
      );
      return;
    }

    final n = int.tryParse(input);
    if (n == null || n <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的正整数')),
      );
      return;
    }

    if (n > _availableInvoices.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('数量不能超过 ${_availableInvoices.length}')),
      );
      return;
    }

    // Sort by amount descending and select top N
    final sortedInvoices = List<Invoice>.from(_availableInvoices)
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    setState(() {
      _selectedInvoiceIds = sortedInvoices.take(n).map((i) => i.id!).toSet();
      _updateSelectedOrders();
    });
  }

  Future<void> _handleExport() async {
    if (_selectedInvoiceIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择要导出的发票')),
      );
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      // Get selected invoices
      final selectedInvoices = _availableInvoices
          .where((i) => _selectedInvoiceIds.contains(i.id))
          .toList();

      // Get orders for selected invoices
      final orderIds = <int>{};
      for (final invoice in selectedInvoices) {
        if (invoice.id != null) {
          final ids = await ref
              .read(invoiceProvider.notifier)
              .getOrderIdsForInvoice(invoice.id!);
          orderIds.addAll(ids);
        }
      }

      final orders = <Order>[];
      for (final orderId in orderIds) {
        final order = await ref.read(orderProvider.notifier).getOrderById(orderId);
        if (order != null) {
          orders.add(order);
        }
      }

      // Export files
      await _exportFiles(orders, selectedInvoices);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _exportFiles(List<Order> orders, List<Invoice> invoices) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = _formatTimestamp(DateTime.now());
    final files = <share_plus.XFile>[];

    // Generate orders PDF
    final ordersPdfPath = '${directory.path}/订单列表_$timestamp.pdf';
    await PdfExportService.generateOrdersPdf(orders, ordersPdfPath);
    files.add(share_plus.XFile(ordersPdfPath));

    // Generate invoices PDF
    final invoicesPdfPath = '${directory.path}/发票列表_$timestamp.pdf';
    await PdfExportService.generateInvoicesPdf(invoices, invoicesPdfPath);
    files.add(share_plus.XFile(invoicesPdfPath));

    // Generate Excel for consumption details
    final excelPath = '${directory.path}/消费明细_$timestamp.xlsx';
    await _generateExcelFile(orders, invoices, excelPath);
    files.add(share_plus.XFile(excelPath));

    if (mounted) {
      _showExportSuccess(orders.length, invoices.length);

      // Share files
      await share_plus.SharePlus.instance.share(
        share_plus.ShareParams(
          files: files,
          text: '餐饮发票报销材料',
        ),
      );
    }
  }

  Future<void> _generateExcelFile(
    List<Order> orders,
    List<Invoice> invoices,
    String outputPath,
  ) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    // Create orders sheet
    final orderSheet = excel['订单明细'];
    orderSheet.appendRow([
      TextCellValue('店铺名称'),
      TextCellValue('实付款'),
      TextCellValue('日期'),
      TextCellValue('时段'),
      TextCellValue('订单号'),
      TextCellValue('录入时间'),
    ]);

    for (final order in orders) {
      orderSheet.appendRow([
        TextCellValue(order.shopName),
        DoubleCellValue(order.amount),
        TextCellValue(order.orderDate ?? ''),
        TextCellValue(DateFormatter.mealTimeToDisplayName(
            DateFormatter.mealTimeFromString(order.mealTime))),
        TextCellValue(order.orderNumber),
        TextCellValue(order.createdAt),
      ]);
    }

    // Create invoices sheet
    final invoiceSheet = excel['发票明细'];
    invoiceSheet.appendRow([
      TextCellValue('发票号码'),
      TextCellValue('开票日期'),
      TextCellValue('价税合计'),
      TextCellValue('销售方名称'),
      TextCellValue('关联订单数'),
      TextCellValue('录入时间'),
    ]);

    for (final invoice in invoices) {
      final orderCount = _invoiceOrderCounts[invoice.id] ?? 0;
      invoiceSheet.appendRow([
        TextCellValue(invoice.invoiceNumber),
        TextCellValue(invoice.invoiceDate ?? ''),
        DoubleCellValue(invoice.totalAmount),
        TextCellValue(invoice.sellerName),
        IntCellValue(orderCount),
        TextCellValue(invoice.createdAt),
      ]);
    }

    final bytes = excel.encode();
    if (bytes != null) {
      await File(outputPath).writeAsBytes(bytes);
    }
  }

  String _formatTimestamp(DateTime dt) {
    return '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}_${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showExportSuccess(int orderCount, int invoiceCount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导出成功'),
        content: Text(
          '已导出:\n'
          '- 订单列表 PDF\n'
          '- 发票列表 PDF\n'
          '- 消费明细 Excel\n\n'
          '包含 $invoiceCount 张发票和 $orderCount 条订单',
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
}

/// Invoice selector card with checkbox
class _InvoiceSelectorCard extends StatelessWidget {
  final Invoice invoice;
  final int orderCount;
  final bool isSelected;
  final ValueChanged<bool> onChanged;

  const _InvoiceSelectorCard({
    required this.invoice,
    required this.orderCount,
    required this.isSelected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final invoiceDate = invoice.invoiceDate != null &&
            invoice.invoiceDate!.isNotEmpty
        ? DateTime.tryParse(invoice.invoiceDate!)
        : null;
    final formattedDate = invoiceDate != null
        ? DateFormatter.formatDisplay(invoiceDate)
        : invoice.invoiceDate ?? '-';

    return InkWell(
      onTap: () => onChanged(!isSelected),
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
              onChanged: (v) => onChanged(v ?? false),
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
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        DateFormatter.formatAmount(invoice.totalAmount),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.primary,
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
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formattedDate,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (orderCount > 0) ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.link,
                          size: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$orderCount条订单',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
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
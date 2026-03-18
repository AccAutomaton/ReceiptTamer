import 'dart:io';

import 'package:catering_receipt_recorder/core/constants/app_constants.dart';
import 'package:catering_receipt_recorder/core/utils/date_formatter.dart';
import 'package:catering_receipt_recorder/data/models/invoice.dart';
import 'package:catering_receipt_recorder/data/models/order.dart';
import 'package:catering_receipt_recorder/presentation/providers/order_provider.dart';
import 'package:catering_receipt_recorder/presentation/providers/invoice_provider.dart';
import 'package:catering_receipt_recorder/presentation/widgets/common/app_button.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Export screen - export data to Excel/CSV format
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  ExportRange _selectedRange = ExportRange.all;
  ExportFormat _selectedFormat = ExportFormat.excel;
  DateTime? _startDate;
  DateTime? _endDate;

  bool _isExporting = false;

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
          // Export range selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '导出范围',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  RadioListTile<ExportRange>(
                    title: const Text('全部数据'),
                    subtitle: const Text('导出所有订单和发票'),
                    value: ExportRange.all,
                    groupValue: _selectedRange,
                    onChanged: (value) {
                      setState(() {
                        _selectedRange = value!;
                        _startDate = null;
                        _endDate = null;
                      });
                    },
                  ),
                  RadioListTile<ExportRange>(
                    title: const Text('按日期范围'),
                    subtitle: const Text('导出指定日期范围的数据'),
                    value: ExportRange.dateRange,
                    groupValue: _selectedRange,
                    onChanged: (value) {
                      setState(() {
                        _selectedRange = value!;
                      });
                    },
                  ),
                  if (_selectedRange == ExportRange.dateRange) ...[
                    const SizedBox(height: 8),
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
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Export format selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '导出格式',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  RadioListTile<ExportFormat>(
                    title: const Text('Excel (.xlsx)'),
                    subtitle: const Text('推荐格式，支持多工作表'),
                    value: ExportFormat.excel,
                    groupValue: _selectedFormat,
                    onChanged: (value) {
                      setState(() {
                        _selectedFormat = value!;
                      });
                    },
                  ),
                  RadioListTile<ExportFormat>(
                    title: const Text('CSV (.csv)'),
                    subtitle: const Text('通用格式，可用Excel打开'),
                    value: ExportFormat.csv,
                    groupValue: _selectedFormat,
                    onChanged: (value) {
                      setState(() {
                        _selectedFormat = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Preview section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '导出预览',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: _loadPreview,
                        child: const Text('刷新'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ExportPreview(
                    range: _selectedRange,
                    startDate: _startDate,
                    endDate: _endDate,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Export button
          AppButton(
            text: '导出',
            onPressed: _handleExport,
            isLoading: _isExporting,
            isFullWidth: true,
            type: AppButtonType.primary,
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
    }
  }

  void _loadPreview() {
    setState(() {
      // Force rebuild to refresh preview
    });
  }

  Future<void> _handleExport() async {
    if (_selectedRange == ExportRange.dateRange &&
        (_startDate == null || _endDate == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择开始和结束日期')),
      );
      return;
    }

    if (_startDate != null && _endDate != null && _startDate!.isAfter(_endDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('开始日期不能晚于结束日期')),
      );
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      // Get data to export
      final orders = await _getOrdersForExport();
      final invoices = await _getInvoicesForExport();

      if (orders.isEmpty && invoices.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('暂无数据可导出')),
          );
        }
        return;
      }

      // Export based on selected format
      if (_selectedFormat == ExportFormat.excel) {
        await _exportToExcel(orders, invoices);
      } else {
        await _exportToCsv(orders, invoices);
      }
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

  Future<List<Order>> _getOrdersForExport() async {
    if (_selectedRange == ExportRange.dateRange &&
        _startDate != null &&
        _endDate != null) {
      return await ref
          .read(orderProvider.notifier)
          .getByDateRangeForExport(_startDate!, _endDate!);
    }
    return await ref.read(orderProvider.notifier).getAllForExport();
  }

  Future<List<Invoice>> _getInvoicesForExport() async {
    if (_selectedRange == ExportRange.dateRange &&
        _startDate != null &&
        _endDate != null) {
      return await ref
          .read(invoiceProvider.notifier)
          .getByDateRangeForExport(_startDate!, _endDate!);
    }
    return await ref.read(invoiceProvider.notifier).getAllForExport();
  }

  Future<void> _exportToExcel(List<Order> orders, List<Invoice> invoices) async {
    try {
      final excel = Excel.createExcel();

      // 删除默认工作表
      excel.delete('Sheet1');

      // 创建订单工作表
      final orderSheet = excel['订单'];
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
          TextCellValue(DateFormatter.mealTimeToDisplayName(DateFormatter.mealTimeFromString(order.mealTime))),
          TextCellValue(order.orderNumber),
          TextCellValue(order.createdAt),
        ]);
      }

      // 创建发票工作表
      final invoiceSheet = excel['发票'];
      invoiceSheet.appendRow([
        TextCellValue('发票号码'),
        TextCellValue('开票日期'),
        TextCellValue('价税合计'),
        TextCellValue('销售方名称'),
        TextCellValue('录入时间'),
      ]);

      for (final invoice in invoices) {
        invoiceSheet.appendRow([
          TextCellValue(invoice.invoiceNumber),
          TextCellValue(invoice.invoiceDate ?? ''),
          DoubleCellValue(invoice.totalAmount),
          TextCellValue(invoice.sellerName),
          TextCellValue(invoice.createdAt),
        ]);
      }

      // 保存文件
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '餐饮发票导出_$timestamp.xlsx';
      final filePath = '${directory.path}/$fileName';

      final bytes = excel.encode();
      if (bytes != null) {
        final file = File(filePath);
        await file.writeAsBytes(bytes);

        if (mounted) {
          _showExportSuccess(orders.length, invoices.length);

          // 分享文件
          await Share.shareXFiles(
            [XFile(filePath)],
            text: '餐饮发票数据导出',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel导出失败: $e')),
        );
      }
    }
  }

  Future<void> _exportToCsv(List<Order> orders, List<Invoice> invoices) async {
    await _generateCsvExport(orders, invoices, '.csv');
    if (mounted) {
      _showExportSuccess(orders.length, invoices.length);
    }
  }

  Future<void> _generateCsvExport(
    List<Order> orders,
    List<Invoice> invoices,
    String extension,
  ) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Export orders
    final ordersFileName = '订单_$timestamp$extension';
    final ordersFilePath = '${directory.path}/$ordersFileName';
    final ordersContent = _generateOrdersCsv(orders);
    await File(ordersFilePath).writeAsString(ordersContent);

    // Export invoices
    final invoicesFileName = '发票_$timestamp$extension';
    final invoicesFilePath = '${directory.path}/$invoicesFileName';
    final invoicesContent = _generateInvoicesCsv(invoices);
    await File(invoicesFilePath).writeAsString(invoicesContent);

    // 分享文件
    if (mounted) {
      await Share.shareXFiles(
        [XFile(ordersFilePath), XFile(invoicesFilePath)],
        text: '餐饮发票数据导出',
      );
    }
  }

  String _generateOrdersCsv(List<Order> orders) {
    final buffer = StringBuffer();
    buffer.writeln('店铺名称,实付款,日期,时段,订单号,录入时间');

    for (final order in orders) {
      buffer.writeln(
        '${_escapeCsv(order.shopName)},'
        '${order.amount},'
        '${order.orderDate ?? ''},'
        '${DateFormatter.mealTimeToDisplayName(DateFormatter.mealTimeFromString(order.mealTime))},'
        '${_escapeCsv(order.orderNumber)},'
        '${order.createdAt}',
      );
    }

    return buffer.toString();
  }

  String _generateInvoicesCsv(List<Invoice> invoices) {
    final buffer = StringBuffer();
    buffer.writeln('发票号码,开票日期,价税合计,销售方名称,录入时间');

    for (final invoice in invoices) {
      buffer.writeln(
        '${_escapeCsv(invoice.invoiceNumber)},'
        '${invoice.invoiceDate ?? ''},'
        '${invoice.totalAmount},'
        '${_escapeCsv(invoice.sellerName)},'
        '${invoice.createdAt}',
      );
    }

    return buffer.toString();
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  void _showExportSuccess(int orderCount, int invoiceCount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导出成功'),
        content: Text(
          '已导出 $orderCount 条订单和 $invoiceCount 条发票',
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

enum ExportRange { all, dateRange }
enum ExportFormat { excel, csv }

/// Export preview widget
class _ExportPreview extends ConsumerWidget {
  final ExportRange range;
  final DateTime? startDate;
  final DateTime? endDate;

  const _ExportPreview({
    required this.range,
    this.startDate,
    this.endDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = range == ExportRange.dateRange &&
            startDate != null &&
            endDate != null
        ? ref.watch(
            FutureProvider<List<Order>>((ref) async {
              return await ref.read(orderProvider.notifier).getByDateRangeForExport(startDate!, endDate!);
            }),
          )
        : ref.watch(
            FutureProvider<List<Order>>((ref) async {
              return await ref.read(orderProvider.notifier).getAllForExport();
            }),
          );

    final invoicesAsync = range == ExportRange.dateRange &&
            startDate != null &&
            endDate != null
        ? ref.watch(
            FutureProvider<List<Invoice>>((ref) async {
              return await ref.read(invoiceProvider.notifier).getByDateRangeForExport(startDate!, endDate!);
            }),
          )
        : ref.watch(
            FutureProvider<List<Invoice>>((ref) async {
              return await ref.read(invoiceProvider.notifier).getAllForExport();
            }),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPreviewItem(
          context,
          '订单数量',
          ordersAsync.value?.length ?? 0,
          Icons.receipt_long,
        ),
        const SizedBox(height: 8),
        _buildPreviewItem(
          context,
          '发票数量',
          invoicesAsync.value?.length ?? 0,
          Icons.description,
        ),
      ],
    );
  }

  Widget _buildPreviewItem(
    BuildContext context,
    String label,
    int count,
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
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: 12),
          Text(
            label,
            style: theme.textTheme.bodyMedium,
          ),
          const Spacer(),
          Text(
            count.toString(),
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

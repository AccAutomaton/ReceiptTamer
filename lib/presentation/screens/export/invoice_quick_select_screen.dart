import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'package:receipt_tamer/core/services/log_service.dart';
import 'package:receipt_tamer/core/services/log_config.dart';
import 'package:receipt_tamer/core/utils/date_formatter.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/services/invoice_export_service.dart';
import 'package:receipt_tamer/data/services/file_service.dart';
import 'package:receipt_tamer/presentation/providers/invoice_provider.dart';
import 'package:receipt_tamer/presentation/providers/order_provider.dart';
import 'package:receipt_tamer/presentation/widgets/common/empty_state.dart';
import 'package:receipt_tamer/presentation/widgets/common/month_range_picker.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_button.dart';
import 'package:receipt_tamer/presentation/screens/export/saved_files_screen.dart';

/// Invoice quick select screen - for quick export of invoice PDF
/// User directly selects invoices instead of orders
class InvoiceQuickSelectScreen extends ConsumerStatefulWidget {
  const InvoiceQuickSelectScreen({super.key});

  @override
  ConsumerState<InvoiceQuickSelectScreen> createState() => _InvoiceQuickSelectScreenState();
}

class _InvoiceQuickSelectScreenState extends ConsumerState<InvoiceQuickSelectScreen> {
  Set<int> _selectedInvoiceIds = {};
  List<Invoice> _invoices = [];
  bool _isLoading = true;
  bool _isExporting = false;

  // Filter state
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchKeyword = '';
  final _searchController = TextEditingController();

  // Export options
  bool _showTimeLabel = true; // Show time label on invoices

  @override
  void initState() {
    super.initState();
    // Default to current month range
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
    _loadInvoices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);

    try {
      final invoices = await ref.read(invoiceProvider.notifier).getByDateRangeForExport(
            _startDate ?? DateTime(2000),
            _endDate ?? DateTime.now().add(const Duration(days: 365 * 10)),
          );

      // Apply keyword filter if any
      var filteredInvoices = invoices;
      if (_searchKeyword.isNotEmpty) {
        filteredInvoices = invoices.where((invoice) {
          final sellerName = invoice.sellerName.toLowerCase();
          final invoiceNumber = invoice.invoiceNumber.toLowerCase();
          final keyword = _searchKeyword.toLowerCase();
          return sellerName.contains(keyword) || invoiceNumber.contains(keyword);
        }).toList();
      }

      if (mounted) {
        setState(() {
          _invoices = filteredInvoices;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        setState(() => _isLoading = false);
        logService.e(LogConfig.moduleUi, '加载发票失败', e, stackTrace);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载发票失败: $e')),
        );
      }
    }
  }

  void _toggleSelection(int invoiceId) {
    setState(() {
      if (_selectedInvoiceIds.contains(invoiceId)) {
        _selectedInvoiceIds.remove(invoiceId);
      } else {
        _selectedInvoiceIds.add(invoiceId);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedInvoiceIds = _invoices.where((i) => i.id != null).map((i) => i.id!).toSet();
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedInvoiceIds.clear();
    });
  }

  void _showMonthRangePicker() async {
    final result = await MonthRangePicker.show(
      context,
      initialStartMonth: _startDate,
      initialEndMonth: _endDate,
    );

    if (result != null) {
      setState(() {
        _startDate = result.startDate;
        _endDate = result.endDate;
      });
      _loadInvoices();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _loadInvoices();
  }

  void _onSearchChanged(String value) {
    _searchKeyword = value;
    _loadInvoices();
  }

  Future<void> _confirmAndExport() async {
    if (_selectedInvoiceIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择发票')),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      // Get selected invoices
      final selectedInvoices = _invoices.where((i) => _selectedInvoiceIds.contains(i.id)).toList();

      // Prepare invoice export items
      final items = await InvoiceExportService.prepareInvoiceExportItems(
        invoices: selectedInvoices,
        getOrderIdsForInvoice: (invoiceId) =>
            ref.read(invoiceProvider.notifier).getOrderIdsForInvoice(invoiceId),
        getOrderById: (orderId) =>
            ref.read(orderProvider.notifier).getOrderById(orderId),
      );

      if (items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有可导出的发票')),
        );
        setState(() => _isExporting = false);
        return;
      }

      // Generate PDF to temp directory
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormatter.formatStorageWithTime(DateTime.now());
      final tempPath = '${tempDir.path}/发票_$timestamp.pdf';

      await InvoiceExportService.generateInvoicePdf(
        items: items,
        outputPath: tempPath,
        getFilePath: (path) => path,
        showTimeLabel: _showTimeLabel,
      );

      // Copy to download directory
      final now = DateTime.now();
      final dateDir = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final fileService = FileService();
      final savedPath = await fileService.copyToDownloadDirectory(
        tempPath,
        subDir: 'materials/$dateDir',
      );

      // Clean up temp file
      try {
        await File(tempPath).delete();
      } catch (_) {}

      logService.i(LogConfig.moduleFile, '发票PDF已保存: $savedPath');

      if (mounted) {
        setState(() => _isExporting = false);

        // Navigate to saved files screen to show exported file
        if (savedPath != null) {
          Navigator.pop(context);
          await showSavedFilesScreen(context, initialSubDir: 'materials/$dateDir');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('保存文件失败')),
          );
        }
      }
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleFile, '发票PDF导出失败', e, stackTrace);
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('发票导出'),
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'selectAll') {
                _selectAll();
              } else if (value == 'clearSelection') {
                _clearSelection();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'selectAll',
                child: Text('全选'),
              ),
              const PopupMenuItem(
                value: 'clearSelection',
                child: Text('清除选择'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filter section
          _buildFilterSection(context),

          // Date filter chip
          if (_startDate != null || _endDate != null)
            _buildDateFilterChip(context),

          // Invoice list
          Expanded(
            child: _buildInvoiceList(context),
          ),

          // Bottom confirm bar
          _buildBottomBar(context),
        ],
      ),
    );
  }

  Widget _buildFilterSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索销售方名称或发票号码',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchKeyword.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _searchKeyword = '';
                        _loadInvoices();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _loadInvoices(),
          ),

          const SizedBox(height: 12),

          // Options and date filter row
          Row(
            children: [
              // Time label toggle
              Expanded(
                child: Row(
                  children: [
                    Checkbox(
                      value: _showTimeLabel,
                      onChanged: (value) {
                        setState(() => _showTimeLabel = value ?? true);
                      },
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _showTimeLabel = !_showTimeLabel),
                        child: Text(
                          '显示订单时间标签',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Date filter button
              IconButton.outlined(
                onPressed: _showMonthRangePicker,
                icon: const Icon(Icons.date_range),
                tooltip: '日期筛选',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterChip(BuildContext context) {
    final startStr = _startDate != null ? DateFormatter.formatYearMonth(_startDate!) : '';
    final endStr = _endDate != null ? DateFormatter.formatYearMonth(_endDate!) : '';
    final dateRangeStr = startStr == endStr ? startStr : '$startStr - $endStr';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Chip(
            label: Text(dateRangeStr),
            deleteIcon: const Icon(Icons.close, size: 16),
            onDeleted: _clearDateFilter,
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceList(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_invoices.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long,
        title: _searchKeyword.isNotEmpty || _startDate != null
            ? '没有找到符合条件的发票'
            : '暂无发票',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _invoices.length,
      itemBuilder: (context, index) {
        final invoice = _invoices[index];
        final invoiceId = invoice.id;
        final isSelected = invoiceId != null && _selectedInvoiceIds.contains(invoiceId);

        return _InvoiceSelectCard(
          invoice: invoice,
          isSelected: isSelected,
          onTap: () => _showInvoiceDetail(invoice),
          onCheckChanged: invoiceId != null ? (_) => _toggleSelection(invoiceId) : null,
        );
      },
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Calculate total amount of selected invoices
    final totalAmount = _invoices
        .where((i) => _selectedInvoiceIds.contains(i.id))
        .fold<double>(0.0, (sum, i) => sum + i.totalAmount);

    final hasSelection = _selectedInvoiceIds.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
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
                  hasSelection ? '已选择 ${_selectedInvoiceIds.length} 张发票' : '未选择发票',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  hasSelection ? '合计: ${DateFormatter.formatAmount(totalAmount)}' : '请选择发票后导出',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: hasSelection ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const Spacer(),
            AppButton(
              text: '导出发票',
              onPressed: _isExporting ? null : _confirmAndExport,
              type: AppButtonType.primary,
              isLoading: _isExporting,
            ),
          ],
        ),
      ),
    );
  }

  void _showInvoiceDetail(Invoice invoice) {
    // Navigate to invoice detail screen
    if (invoice.id != null && invoice.id! > 0) {
      context.push('/invoices/${invoice.id}');
    }
  }
}

/// Invoice select card widget for displaying invoice info with checkbox
class _InvoiceSelectCard extends StatelessWidget {
  final Invoice invoice;
  final bool isSelected;
  final VoidCallback? onTap;
  final ValueChanged<bool?>? onCheckChanged;

  const _InvoiceSelectCard({
    required this.invoice,
    required this.isSelected,
    this.onTap,
    this.onCheckChanged,
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

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer.withValues(alpha: 0.3)
              : null,
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
            // Checkbox
            Checkbox(
              value: isSelected,
              onChanged: onCheckChanged,
            ),
            const SizedBox(width: 8),

            // Invoice info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Seller name
                  Text(
                    invoice.sellerName.isEmpty ? '未命名店铺' : invoice.sellerName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  if (invoice.invoiceNumber.isNotEmpty) ... [
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.receipt,
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
                ],
              ),
            ),

            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormatter.formatAmount(invoice.totalAmount),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
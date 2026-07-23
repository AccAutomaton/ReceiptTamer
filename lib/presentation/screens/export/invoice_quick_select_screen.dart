import 'package:flutter/material.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_alert_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'package:receipt_tamer/core/services/log_service.dart';
import 'package:receipt_tamer/core/services/log_config.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/core/utils/date_formatter.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/services/invoice_export_service.dart';
import 'package:receipt_tamer/data/services/file_service.dart';
import 'package:receipt_tamer/presentation/providers/invoice_provider.dart';
import 'package:receipt_tamer/presentation/providers/order_provider.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_notice.dart';
import 'package:receipt_tamer/presentation/widgets/common/empty_state.dart';
import 'package:receipt_tamer/presentation/widgets/common/date_range_picker.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_button.dart';
import 'package:receipt_tamer/presentation/widgets/common/floating_overlay_layout.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_page_scaffold.dart';
import 'package:receipt_tamer/presentation/screens/export/saved_files_screen.dart';
import 'package:receipt_tamer/presentation/utils/persistent_selection.dart';

/// Order relation filter enum for invoice export
/// 用于发票导出的订单关联筛选
enum OrderRelationFilter {
  all, // 全部
  withOrder, // 已关联订单
  withoutOrder, // 未关联订单
}

/// Invoice quick select screen - for quick export of invoice PDF
/// User directly selects invoices instead of orders
class InvoiceQuickSelectScreen extends ConsumerStatefulWidget {
  const InvoiceQuickSelectScreen({super.key});

  @override
  ConsumerState<InvoiceQuickSelectScreen> createState() =>
      _InvoiceQuickSelectScreenState();
}

class _InvoiceQuickSelectScreenState
    extends ConsumerState<InvoiceQuickSelectScreen> {
  final PersistentSelection<Invoice> _selection = PersistentSelection<Invoice>(
    (invoice) => invoice.id,
  );
  List<Invoice> _invoices = [];
  int _totalInvoiceCount = 0; // 全部筛选下的发票数量（用于已选计数分母）
  Map<int, int> _invoiceOrderCounts = {}; // invoiceId -> order count
  bool _isLoading = true;
  bool _isExporting = false;
  int _loadRequestId = 0;

  // Filter state
  OrderRelationFilter _orderRelationFilter = OrderRelationFilter.all;
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchKeyword = '';
  final _searchController = TextEditingController();

  // Export options
  bool _showTimeLabel = false; // Show time label on invoices (默认不标注)
  bool _addRemark = false; // 新增：是否添加备注
  String? _remarkContent; // 新增：备注内容

  @override
  void initState() {
    super.initState();
    // 独立发票导出默认查看全部发票；日期在这里仅是可选筛选。
    Future(() => _loadInvoices());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    final requestId = ++_loadRequestId;
    setState(() => _isLoading = true);

    try {
      // 快捷导出使用局部查询，避免覆盖主发票 Tab 的缓存列表。
      final repository = ref.read(invoiceRepositoryProvider);
      final relationFilter =
          _orderRelationFilter == OrderRelationFilter.withOrder
          ? true
          : _orderRelationFilter == OrderRelationFilter.withoutOrder
          ? false
          : null;
      final invoices = await repository.search(
        startDate: _startDate,
        endDate: _endDate,
        hasLinkedOrder: relationFilter,
      );

      // Apply keyword filter if any
      var filteredInvoices = invoices;
      if (_searchKeyword.isNotEmpty) {
        filteredInvoices = invoices.where((invoice) {
          final sellerName = invoice.sellerName.toLowerCase();
          final invoiceNumber = invoice.invoiceNumber.toLowerCase();
          final keyword = _searchKeyword.toLowerCase();
          return sellerName.contains(keyword) ||
              invoiceNumber.contains(keyword);
        }).toList();
      }

      // 获取全部筛选下的发票数量（用于已选计数分母）
      int totalCount;
      if (_orderRelationFilter == OrderRelationFilter.all &&
          _searchKeyword.isEmpty) {
        totalCount = filteredInvoices.length;
      } else {
        final allInvoices = await repository.search(
          startDate: _startDate,
          endDate: _endDate,
        );
        // 搜索关键词不影响分母（分母只考虑日期筛选）
        totalCount = allInvoices.length;
      }

      final invoiceIds = filteredInvoices
          .map((invoice) => invoice.id)
          .whereType<int>()
          .toList();
      final invoiceOrderCounts = await repository.getOrderCountsForInvoices(
        invoiceIds,
      );

      if (mounted && requestId == _loadRequestId) {
        setState(() {
          _invoices = filteredInvoices;
          _selection.refreshVisible(filteredInvoices);
          _invoiceOrderCounts = invoiceOrderCounts;
          _totalInvoiceCount = totalCount;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      if (mounted && requestId == _loadRequestId) {
        setState(() => _isLoading = false);
        logService.e(LogConfig.moduleUi, '加载发票失败', e, stackTrace);
        AppNotice.error(
          context,
          '加载发票失败: $e',
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  void _toggleSelection(Invoice invoice) {
    final invoiceId = invoice.id;
    if (invoiceId == null) return;
    setState(() {
      _selection.toggle(invoice);
    });
  }

  void _selectAll() {
    setState(() {
      _selection.selectVisible(_invoices);
    });
  }

  void _clearSelection() {
    setState(() {
      _selection.clear();
    });
  }

  void _invertSelection() {
    setState(() {
      _selection.invertVisible(_invoices);
    });
  }

  Future<List<Invoice>> _resolveSelectedInvoices() async {
    final repository = ref.read(invoiceRepositoryProvider);
    final resolved = <Invoice>[];
    for (final id in _selection.ids) {
      final invoice = await repository.getById(id);
      if (invoice != null) resolved.add(invoice);
    }
    return resolved;
  }

  void _showDateRangePicker() async {
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

  /// Show dialog for inputting invoice remark
  Future<void> _showRemarkDialog() async {
    final controller = TextEditingController(text: _remarkContent ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (context) => GlassAlertDialog(
        title: const Text('发票备注'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: '请输入备注内容',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          maxLength: 50,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // 取消不返回值
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (mounted) {
      setState(() {
        if (result != null && result.trim().isNotEmpty) {
          // 用户点击确定并输入了内容
          _addRemark = true;
          _remarkContent = result.trim();
        } else {
          // 用户点击取消或输入了空内容
          _addRemark = false;
          _remarkContent = null;
        }
      });
    }
  }

  Future<void> _confirmAndExport() async {
    if (_selection.isEmpty) {
      AppNotice.warning(
        context,
        '请先选择发票',
        duration: const Duration(seconds: 4),
      );
      return;
    }

    setState(() => _isExporting = true);
    String? tempPath;

    try {
      // Resolve by ID instead of intersecting with the currently visible
      // filter. Hidden selections remain part of the export.
      final selectedInvoices = await _resolveSelectedInvoices();
      if (selectedInvoices.length != _selection.length) {
        throw StateError('部分已选发票已不存在，请返回后重新选择');
      }

      // Prepare invoice export items
      final items = await InvoiceExportService.prepareInvoiceExportItems(
        invoices: selectedInvoices,
        getOrderIdsForInvoice: (invoiceId) =>
            ref.read(invoiceProvider.notifier).getOrderIdsForInvoice(invoiceId),
        getOrderById: (orderId) =>
            ref.read(orderProvider.notifier).getOrderById(orderId),
        remark: _addRemark ? _remarkContent : null,
      );

      final validation = await InvoiceExportService.validateAttachments(
        items: items,
        getFilePath: (path) => path,
      );
      if (validation.hasUnavailableItems) {
        throw InvoiceAttachmentUnavailableException(
          validation.unavailableItems.map((item) => item.invoice).toList(),
        );
      }

      if (!mounted) return;

      if (items.isEmpty) {
        AppNotice.warning(
          context,
          '没有可导出的发票',
          duration: const Duration(seconds: 4),
        );
        setState(() => _isExporting = false);
        return;
      }

      // Generate PDF to temp directory
      final now = DateTime.now();
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormatter.formatStorageWithTime(now);
      final workingPath = '${tempDir.path}/发票_$timestamp.pdf';
      tempPath = workingPath;

      await InvoiceExportService.generateInvoicePdf(
        items: items,
        outputPath: workingPath,
        getFilePath: (path) => path,
        showTimeLabel: _showTimeLabel,
        showRemark: _addRemark,
      );

      // Copy to download directory
      final dateDir =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final fileService = FileService();
      final savedPath = await fileService.copyToDownloadDirectory(
        workingPath,
        subDir: 'materials/$dateDir',
      );

      logService.i(LogConfig.moduleFile, '发票PDF已保存: $savedPath');

      if (mounted) {
        setState(() => _isExporting = false);

        // Navigate to saved files screen to show exported file
        if (savedPath != null) {
          final navigator = Navigator.of(context);
          final navigationContext = navigator.overlay!.context;
          navigator.pop();
          if (!navigationContext.mounted) return;
          await showSavedFilesScreen(
            navigationContext,
            initialSubDir: 'materials/$dateDir',
          );
        } else {
          AppNotice.error(
            context,
            '保存文件失败',
            duration: const Duration(seconds: 4),
          );
        }
      }
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleFile, '发票PDF导出失败', e, stackTrace);
      if (mounted) {
        setState(() => _isExporting = false);
        AppNotice.error(
          context,
          '导出失败: $e',
          duration: const Duration(seconds: 4),
        );
      }
    } finally {
      final workingPath = tempPath;
      if (workingPath != null) {
        try {
          final tempFile = File(workingPath);
          if (await tempFile.exists()) await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassPageScaffold(
      appBar: AppBar(title: const Text('发票导出'), elevation: 0),
      body: FloatingOverlayLayout(
        top: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFilterSection(context),
            if (_startDate != null || _endDate != null)
              _buildDateFilterChip(context),
            _buildSelectButtonsRow(context),
          ],
        ),
        bodyBuilder: (context, contentPadding) =>
            _buildInvoiceList(context, contentPadding),
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildExportOptions(context),
            const SizedBox(height: 12),
            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(BuildContext context) {
    return Column(
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            isDense: true,
          ),
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _loadInvoices(),
        ),

        const SizedBox(height: 12),

        // Filter chips row - 三段式筛选 + 日期筛选按钮
        Row(
          children: [
            // Order relation filter - 三段式筛选
            Expanded(
              child: SegmentedButton<OrderRelationFilter>(
                segments: const [
                  ButtonSegment(
                    value: OrderRelationFilter.all,
                    label: Text('全部'),
                  ),
                  ButtonSegment(
                    value: OrderRelationFilter.withOrder,
                    label: Text('已关联订单'),
                  ),
                  ButtonSegment(
                    value: OrderRelationFilter.withoutOrder,
                    label: Text('未关联订单'),
                  ),
                ],
                selected: {_orderRelationFilter},
                onSelectionChanged: (Set<OrderRelationFilter> selection) {
                  setState(() => _orderRelationFilter = selection.first);
                  _loadInvoices();
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStateProperty.all(
                    const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Date filter button
            IconButton.outlined(
              onPressed: _showDateRangePicker,
              icon: const Icon(Icons.date_range),
              tooltip: '日期筛选',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateFilterChip(BuildContext context) {
    final startStr = _startDate != null
        ? DateFormatter.formatDisplay(_startDate!)
        : '';
    final endStr = _endDate != null
        ? DateFormatter.formatDisplay(_endDate!)
        : '';
    final dateRangeStr = startStr == endStr ? startStr : '$startStr - $endStr';

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Chip(
          label: Text(dateRangeStr),
          deleteIcon: const Icon(Icons.close, size: 16),
          onDeleted: _clearDateFilter,
        ),
      ),
    );
  }

  Widget _buildSelectButtonsRow(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasSelection = _selection.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: _invoices.isEmpty ? null : _selectAll,
            icon: const Icon(Icons.select_all, size: 18),
            label: const Text('全选'),
          ),
          TextButton.icon(
            onPressed: _invoices.isEmpty ? null : _invertSelection,
            icon: const Icon(Icons.flip, size: 18),
            label: const Text('反选'),
          ),
          const Spacer(),
          GestureDetector(
            onTap: hasSelection ? _clearSelection : null,
            child: Text(
              hasSelection
                  ? '已选 ${_selection.length}/$_totalInvoiceCount ✕'
                  : '已选 ${_selection.length}/$_totalInvoiceCount',
              style: TextStyle(
                color: hasSelection
                    ? AppPalette.amountFor(context)
                    : colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建导出选项卡片
  Widget _buildExportOptions(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '导出选项',
          style: theme.textTheme.titleSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        _buildTimeLabelOptionRow(context),
        const SizedBox(height: 8),
        _buildRemarkOptionRow(context),
      ],
    );
  }

  /// 构建时间标注选项行
  Widget _buildTimeLabelOptionRow(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      button: true,
      checked: _showTimeLabel,
      label: '标注订单时间',
      onTap: () => setState(() => _showTimeLabel = !_showTimeLabel),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () => setState(() => _showTimeLabel = !_showTimeLabel),
          borderRadius: BorderRadius.circular(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _showTimeLabel
                      ? AppPalette.amountFor(context)
                      : Colors.transparent,
                  border: Border.all(
                    color: _showTimeLabel
                        ? AppPalette.amountFor(context)
                        : colorScheme.outline,
                    width: 2,
                  ),
                ),
                child: _showTimeLabel
                    ? Icon(Icons.check, size: 14, color: colorScheme.onPrimary)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                '标注订单时间',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建备注选项行
  Widget _buildRemarkOptionRow(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      button: true,
      checked: _addRemark,
      label: '添加发票备注',
      onTap: _showRemarkDialog,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: _showRemarkDialog,
          borderRadius: BorderRadius.circular(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _addRemark
                      ? AppPalette.actionPrimaryFor(context)
                      : Colors.transparent,
                  border: Border.all(
                    color: _addRemark
                        ? AppPalette.actionPrimaryFor(context)
                        : colorScheme.outline,
                    width: 2,
                  ),
                ),
                child: _addRemark
                    ? Icon(Icons.check, size: 14, color: colorScheme.onPrimary)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                '添加备注',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              if (_addRemark && _remarkContent != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppPalette.selectedFillFor(context),
                      borderRadius: BorderRadius.circular(AppRadii.control),
                    ),
                    child: Text(
                      _remarkContent!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceList(BuildContext context, EdgeInsets contentPadding) {
    if (_isLoading) {
      return Padding(
        padding: contentPadding,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_invoices.isEmpty) {
      return Padding(
        padding: contentPadding,
        child: EmptyState(
          icon: Icons.receipt_long,
          title:
              _searchKeyword.isNotEmpty ||
                  _startDate != null ||
                  _orderRelationFilter != OrderRelationFilter.all
              ? '没有找到符合条件的发票'
              : '暂无发票',
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        0,
        contentPadding.top + 8,
        0,
        contentPadding.bottom + 8,
      ),
      itemCount: _invoices.length,
      itemBuilder: (context, index) {
        final invoice = _invoices[index];
        final invoiceId = invoice.id;
        final isSelected =
            invoiceId != null && _selection.containsId(invoiceId);
        final orderCount = invoiceId != null
            ? _invoiceOrderCounts[invoiceId]
            : null;

        return _InvoiceSelectCard(
          invoice: invoice,
          isSelected: isSelected,
          orderCount: orderCount,
          onTap: invoiceId != null ? () => _toggleSelection(invoice) : null,
          onOpenDetails: () => _showInvoiceDetail(invoice),
        );
      },
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Calculate total amount of selected invoices
    final totalAmount = _selection.sum((invoice) => invoice.totalAmount);

    final hasSelection = _selection.isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasSelection ? '已选择 ${_selection.length} 张发票' : '未选择发票',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                hasSelection
                    ? '合计: ${DateFormatter.formatAmount(totalAmount)}'
                    : '请选择发票后导出',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: hasSelection
                      ? AppPalette.amountFor(context)
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        AppButton(
          text: '导出发票',
          onPressed: _isExporting ? null : _confirmAndExport,
          type: AppButtonType.primary,
          isLoading: _isExporting,
        ),
      ],
    );
  }

  void _showInvoiceDetail(Invoice invoice) {
    // Navigate to invoice detail screen
    if (invoice.id != null && invoice.id! > 0) {
      context.push('/invoices/${invoice.id}');
    }
  }
}

/// Invoice select card widget for displaying invoice info with selection support
/// 单击选择，并通过显式按钮查看详情。
class _InvoiceSelectCard extends StatelessWidget {
  final Invoice invoice;
  final bool isSelected;
  final int? orderCount;
  final VoidCallback? onTap;
  final VoidCallback? onOpenDetails;

  const _InvoiceSelectCard({
    required this.invoice,
    required this.isSelected,
    this.orderCount,
    this.onTap,
    this.onOpenDetails,
  });

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

    final hasLinkedOrders = orderCount != null && orderCount! > 0;

    return Semantics(
      label:
          '发票 ${invoice.sellerName.isEmpty ? '未命名店铺' : invoice.sellerName}，点按选择，使用详情按钮查看详情',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppPalette.selectedFillFor(context)
                : AppPalette.cardFillFor(context),
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(
              color: isSelected
                  ? AppPalette.actionPrimaryFor(context)
                  : colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox
              Checkbox(
                value: isSelected,
                onChanged: onTap != null ? (_) => onTap!() : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
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
                    if (invoice.invoiceNumber.isNotEmpty) ...[
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

                    // Order relation info
                    const SizedBox(height: 2),
                    if (hasLinkedOrders) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.link,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '已关联${orderCount!}条订单',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Icon(
                            Icons.link_off,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '未关联订单',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
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
                      color: AppPalette.amountFor(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: onOpenDetails,
                    tooltip: '查看发票详情',
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

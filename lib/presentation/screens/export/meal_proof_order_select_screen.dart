import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'package:receipt_tamer/core/services/log_service.dart';
import 'package:receipt_tamer/core/services/log_config.dart';
import 'package:receipt_tamer/core/utils/date_formatter.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/data/services/meal_proof_export_service.dart';
import 'package:receipt_tamer/data/services/file_service.dart';
import 'package:receipt_tamer/presentation/providers/order_provider.dart';
import 'package:receipt_tamer/presentation/providers/invoice_provider.dart';
import 'package:receipt_tamer/presentation/widgets/common/empty_state.dart';
import 'package:receipt_tamer/presentation/widgets/common/date_range_picker.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_button.dart';
import 'package:receipt_tamer/presentation/screens/export/saved_files_screen.dart';

/// Invoice relation filter enum for local use
enum InvoiceRelationFilter {
  all, // 全部
  withoutInvoice, // 未关联发票
  withInvoice, // 已关联发票
}

/// Meal proof order select screen - for quick export of meal proof PDF
/// User directly selects orders instead of invoices
class MealProofOrderSelectScreen extends ConsumerStatefulWidget {
  const MealProofOrderSelectScreen({super.key});

  @override
  ConsumerState<MealProofOrderSelectScreen> createState() => _MealProofOrderSelectScreenState();
}

class _MealProofOrderSelectScreenState extends ConsumerState<MealProofOrderSelectScreen> {
  Set<int> _selectedOrderIds = {};
  List<Order> _orders = [];
  int _totalOrderCount = 0; // 全部筛选下的订单数量（用于已选计数分母）
  bool _isLoading = true;
  bool _isExporting = false;

  // Filter state
  InvoiceRelationFilter _relationFilter = InvoiceRelationFilter.all;
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchKeyword = '';
  final _searchController = TextEditingController();

  // Remark state
  bool _addRemark = false;
  String? _remarkContent;

  @override
  void initState() {
    super.initState();
    // Default to current month range
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
    _loadOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);

    try {
      // 获取当前筛选后的订单
      final orders = await ref.read(orderProvider.notifier).searchOrdersWithInvoiceRelation(
            keyword: _searchKeyword.isNotEmpty ? _searchKeyword : null,
            startDate: _startDate,
            endDate: _endDate,
            hasInvoice: _relationFilter == InvoiceRelationFilter.withInvoice
                ? true
                : _relationFilter == InvoiceRelationFilter.withoutInvoice
                    ? false
                    : null,
          );

      // 获取全部筛选下的订单数量（用于已选计数分母）
      int totalCount;
      if (_relationFilter == InvoiceRelationFilter.all) {
        totalCount = orders.length;
      } else {
        final allOrders = await ref.read(orderProvider.notifier).searchOrdersWithInvoiceRelation(
              keyword: _searchKeyword.isNotEmpty ? _searchKeyword : null,
              startDate: _startDate,
              endDate: _endDate,
              hasInvoice: null, // 全部
            );
        totalCount = allOrders.length;
      }

      if (mounted) {
        setState(() {
          _orders = orders;
          _totalOrderCount = totalCount;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        setState(() => _isLoading = false);
        logService.e(LogConfig.moduleUi, '加载订单失败', e, stackTrace);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载订单失败: $e')),
        );
      }
    }
  }

  void _toggleSelection(int orderId) {
    setState(() {
      if (_selectedOrderIds.contains(orderId)) {
        _selectedOrderIds.remove(orderId);
      } else {
        _selectedOrderIds.add(orderId);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedOrderIds = _orders.where((o) => o.id != null).map((o) => o.id!).toSet();
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedOrderIds.clear();
    });
  }

  void _invertSelection() {
    setState(() {
      final allIds = _orders.where((o) => o.id != null).map((o) => o.id!).toSet();
      _selectedOrderIds = allIds.difference(_selectedOrderIds);
    });
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
      _loadOrders();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _loadOrders();
  }

  void _onSearchChanged(String value) {
    _searchKeyword = value;
    _loadOrders();
  }

  /// 显示备注输入对话框
  Future<void> _showRemarkDialog() async {
    final controller = TextEditingController(text: _remarkContent ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('用餐证明备注'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: '请输入备注内容',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
    if (_selectedOrderIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择订单')),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      // Get selected orders
      final selectedOrders = _orders.where((o) => _selectedOrderIds.contains(o.id)).toList();

      // Prepare meal proof items
      final items = await MealProofExportService.prepareMealProofItemsFromOrders(
        orders: selectedOrders,
        getInvoiceIdsForOrder: (orderId) =>
            ref.read(orderProvider.notifier).getInvoiceIdsForOrder(orderId),
        getInvoiceById: (invoiceId) =>
            ref.read(invoiceProvider.notifier).getInvoiceById(invoiceId),
      );

      if (!mounted) return;

      if (items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有可导出的用餐证明')),
        );
        setState(() => _isExporting = false);
        return;
      }

      // Generate PDF to temp directory
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormatter.formatStorageWithTime(DateTime.now());
      final tempPath = '${tempDir.path}/用餐证明_$timestamp.pdf';

      await MealProofExportService.generatePdf(
        items: items,
        outputPath: tempPath,
        getImagePath: (path) => path,
        remark: _addRemark ? _remarkContent : null, // 新增参数
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

      logService.i(LogConfig.moduleFile, '用餐证明PDF已保存: $savedPath');

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
      logService.e(LogConfig.moduleFile, '用餐证明PDF导出失败', e, stackTrace);
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
        title: const Text('用餐证明导出'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search and filter section
          _buildFilterSection(context),

          // Date filter chip
          if (_startDate != null || _endDate != null)
            _buildDateFilterChip(context),

          // Select buttons row
          _buildSelectButtonsRow(context),

          // Order list
          Expanded(
            child: _buildOrderList(context),
          ),

          // 导出选项卡片
          _buildExportOptions(context),

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
              hintText: '搜索店铺名称或订单号',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchKeyword.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _searchKeyword = '';
                        _loadOrders();
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
            onSubmitted: (_) => _loadOrders(),
          ),

          const SizedBox(height: 12),

          // Filter chips row
          Row(
            children: [
              // Invoice relation filter
              Expanded(
                child: SegmentedButton<InvoiceRelationFilter>(
                  segments: const [
                    ButtonSegment(
                      value: InvoiceRelationFilter.all,
                      label: Text('全部'),
                    ),
                    ButtonSegment(
                      value: InvoiceRelationFilter.withInvoice,
                      label: Text('有发票'),
                    ),
                    ButtonSegment(
                      value: InvoiceRelationFilter.withoutInvoice,
                      label: Text('无发票'),
                    ),
                  ],
                  selected: {_relationFilter},
                  onSelectionChanged: (Set<InvoiceRelationFilter> selection) {
                    setState(() => _relationFilter = selection.first);
                    _loadOrders();
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
      ),
    );
  }

  Widget _buildDateFilterChip(BuildContext context) {
    final startStr = _startDate != null ? DateFormatter.formatDisplay(_startDate!) : '';
    final endStr = _endDate != null ? DateFormatter.formatDisplay(_endDate!) : '';
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

  Widget _buildSelectButtonsRow(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasSelection = _selectedOrderIds.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: _orders.isEmpty ? null : _selectAll,
            icon: const Icon(Icons.select_all, size: 18),
            label: const Text('全选'),
          ),
          TextButton.icon(
            onPressed: _orders.isEmpty ? null : _invertSelection,
            icon: const Icon(Icons.flip, size: 18),
            label: const Text('反选'),
          ),
          const Spacer(),
          GestureDetector(
            onTap: hasSelection ? _clearSelection : null,
            child: Text(
              hasSelection
                  ? '已选 ${_selectedOrderIds.length}/$_totalOrderCount ✕'
                  : '已选 ${_selectedOrderIds.length}/$_totalOrderCount',
              style: TextStyle(
                color: hasSelection ? colorScheme.primary : colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_orders.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long,
        title: _searchKeyword.isNotEmpty ||
                _startDate != null ||
                _relationFilter != InvoiceRelationFilter.all
            ? '没有找到符合条件的订单'
            : '暂无订单',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _orders.length,
      itemBuilder: (context, index) {
        final order = _orders[index];
        final orderId = order.id;
        final isSelected = orderId != null && _selectedOrderIds.contains(orderId);

        return _MealProofOrderCard(
          order: order,
          isSelected: isSelected,
          onTap: orderId != null ? () => _toggleSelection(orderId) : null,
          onDoubleTap: () => _showOrderDetail(order),
        );
      },
    );
  }

  /// 构建导出选项卡片
  Widget _buildExportOptions(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
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
              _buildRemarkOptionRow(context),
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

    return InkWell(
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
              color: _addRemark ? colorScheme.primary : Colors.transparent,
              border: Border.all(
                color: _addRemark ? colorScheme.primary : colorScheme.outline,
                width: 2,
              ),
            ),
            child: _addRemark
                ? Icon(
                    Icons.check,
                    size: 14,
                    color: colorScheme.onPrimary,
                  )
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
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
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Calculate total amount of selected orders
    final totalAmount = _orders
        .where((o) => _selectedOrderIds.contains(o.id))
        .fold<double>(0.0, (sum, o) => sum + o.amount);

    final hasSelection = _selectedOrderIds.isNotEmpty;

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
                  hasSelection ? '已选择 ${_selectedOrderIds.length} 个订单' : '未选择订单',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  hasSelection ? '合计: ${DateFormatter.formatAmount(totalAmount)}' : '请选择订单后导出',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: hasSelection ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const Spacer(),
            AppButton(
              text: '导出用餐证明',
              onPressed: _isExporting ? null : _confirmAndExport,
              type: AppButtonType.primary,
              isLoading: _isExporting,
            ),
          ],
        ),
      ),
    );
  }

  void _showOrderDetail(Order order) {
    // Navigate to order detail screen
    if (order.id != null && order.id! > 0) {
      context.push('/orders/${order.id}');
    }
  }
}

/// Meal proof order card widget for displaying order info with selection support
/// 单击选择，双击查看详情
class _MealProofOrderCard extends StatelessWidget {
  final Order order;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;

  const _MealProofOrderCard({
    required this.order,
    required this.isSelected,
    this.onTap,
    this.onDoubleTap,
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

    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.all(12),
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

              // Order info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Shop name
                    Text(
                      order.shopName.isEmpty ? '未命名店铺' : order.shopName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Order date and meal time
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$formattedDate $formattedMealTime',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    if (order.orderNumber.isNotEmpty) ...[
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
                              order.orderNumber,
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
                    DateFormatter.formatAmount(order.amount),
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
      ),
    );
  }
}
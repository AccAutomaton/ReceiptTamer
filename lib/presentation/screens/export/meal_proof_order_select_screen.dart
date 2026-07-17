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
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/data/services/meal_proof_export_service.dart';
import 'package:receipt_tamer/data/services/file_service.dart';
import 'package:receipt_tamer/presentation/providers/order_provider.dart';
import 'package:receipt_tamer/presentation/providers/invoice_provider.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_notice.dart';
import 'package:receipt_tamer/presentation/widgets/common/empty_state.dart';
import 'package:receipt_tamer/presentation/widgets/common/date_range_picker.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_button.dart';
import 'package:receipt_tamer/presentation/widgets/common/floating_overlay_layout.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_page_scaffold.dart';
import 'package:receipt_tamer/presentation/screens/export/saved_files_screen.dart';
import 'package:receipt_tamer/presentation/utils/persistent_selection.dart';

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
  ConsumerState<MealProofOrderSelectScreen> createState() =>
      _MealProofOrderSelectScreenState();
}

class _MealProofOrderSelectScreenState
    extends ConsumerState<MealProofOrderSelectScreen> {
  final PersistentSelection<Order> _selection = PersistentSelection<Order>(
    (order) => order.id,
  );
  List<Order> _orders = [];
  int _totalOrderCount = 0; // 全部筛选下的订单数量（用于已选计数分母）
  bool _isLoading = true;
  bool _isExporting = false;
  int _loadRequestId = 0;

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
    // 独立用餐证明默认查看全部订单；日期在这里仅是可选筛选。
    _loadOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    final requestId = ++_loadRequestId;
    setState(() => _isLoading = true);

    try {
      // 获取当前筛选后的订单
      final orders = await ref
          .read(orderProvider.notifier)
          .searchOrdersWithInvoiceRelation(
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
        final allOrders = await ref
            .read(orderProvider.notifier)
            .searchOrdersWithInvoiceRelation(
              keyword: _searchKeyword.isNotEmpty ? _searchKeyword : null,
              startDate: _startDate,
              endDate: _endDate,
              hasInvoice: null, // 全部
            );
        totalCount = allOrders.length;
      }

      if (mounted && requestId == _loadRequestId) {
        setState(() {
          _orders = orders;
          _selection.refreshVisible(orders);
          _totalOrderCount = totalCount;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      if (mounted && requestId == _loadRequestId) {
        setState(() => _isLoading = false);
        logService.e(LogConfig.moduleUi, '加载订单失败', e, stackTrace);
        AppNotice.error(
          context,
          '加载订单失败: $e',
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  void _toggleSelection(Order order) {
    final orderId = order.id;
    if (orderId == null) return;
    setState(() {
      _selection.toggle(order);
    });
  }

  void _selectAll() {
    setState(() {
      _selection.selectVisible(_orders);
    });
  }

  void _clearSelection() {
    setState(() {
      _selection.clear();
    });
  }

  void _invertSelection() {
    setState(() {
      _selection.invertVisible(_orders);
    });
  }

  Future<List<Order>> _resolveSelectedOrders() async {
    final resolved = <Order>[];
    for (final id in _selection.ids) {
      final order = await ref.read(orderProvider.notifier).getOrderById(id);
      if (order != null) resolved.add(order);
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
      builder: (context) => GlassAlertDialog(
        title: const Text('用餐证明备注'),
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
        '请先选择订单',
        duration: const Duration(seconds: 4),
      );
      return;
    }

    setState(() => _isExporting = true);
    String? tempPath;

    try {
      // Resolve by ID so a filter cannot silently remove an already selected
      // order from the generated document.
      final selectedOrders = await _resolveSelectedOrders();
      if (selectedOrders.length != _selection.length) {
        throw StateError('部分已选订单已不存在，请返回后重新选择');
      }

      // Prepare meal proof items
      final items =
          await MealProofExportService.prepareMealProofItemsFromOrders(
            orders: selectedOrders,
            getInvoiceIdsForOrder: (orderId) =>
                ref.read(orderProvider.notifier).getInvoiceIdsForOrder(orderId),
            getInvoiceById: (invoiceId) =>
                ref.read(invoiceProvider.notifier).getInvoiceById(invoiceId),
            getOrderIdsForInvoice: (invoiceId) => ref
                .read(invoiceProvider.notifier)
                .getOrderIdsForInvoice(invoiceId),
            getOrderById: (orderId) =>
                ref.read(orderProvider.notifier).getOrderById(orderId),
          );

      if (!mounted) return;

      if (items.isEmpty) {
        AppNotice.warning(
          context,
          '没有可导出的用餐证明',
          duration: const Duration(seconds: 4),
        );
        setState(() => _isExporting = false);
        return;
      }

      // Generate PDF to temp directory
      final now = DateTime.now();
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormatter.formatStorageWithTime(now);
      final workingPath = '${tempDir.path}/用餐证明_$timestamp.pdf';
      tempPath = workingPath;

      await MealProofExportService.generatePdf(
        items: items,
        outputPath: workingPath,
        getImagePath: (path) => path,
        remark: _addRemark ? _remarkContent : null, // 新增参数
      );

      // Copy to download directory
      final dateDir =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final fileService = FileService();
      final savedPath = await fileService.copyToDownloadDirectory(
        workingPath,
        subDir: 'materials/$dateDir',
      );

      logService.i(LogConfig.moduleFile, '用餐证明PDF已保存: $savedPath');

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
      logService.e(LogConfig.moduleFile, '用餐证明PDF导出失败', e, stackTrace);
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
      appBar: AppBar(title: const Text('用餐证明导出'), elevation: 0),
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
            _buildOrderList(context, contentPadding),
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
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
                  ? '已选 ${_selection.length}/$_totalOrderCount ✕'
                  : '已选 ${_selection.length}/$_totalOrderCount',
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

  Widget _buildOrderList(BuildContext context, EdgeInsets contentPadding) {
    if (_isLoading) {
      return Padding(
        padding: contentPadding,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_orders.isEmpty) {
      return Padding(
        padding: contentPadding,
        child: EmptyState(
          icon: Icons.receipt_long,
          title:
              _searchKeyword.isNotEmpty ||
                  _startDate != null ||
                  _relationFilter != InvoiceRelationFilter.all
              ? '没有找到符合条件的订单'
              : '暂无订单',
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
      itemCount: _orders.length,
      itemBuilder: (context, index) {
        final order = _orders[index];
        final orderId = order.id;
        final isSelected = orderId != null && _selection.containsId(orderId);

        return _MealProofOrderCard(
          order: order,
          isSelected: isSelected,
          onTap: orderId != null ? () => _toggleSelection(order) : null,
          onDoubleTap: () => _showOrderDetail(order),
        );
      },
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
        _buildRemarkOptionRow(context),
      ],
    );
  }

  /// 构建备注选项行
  Widget _buildRemarkOptionRow(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      button: true,
      checked: _addRemark,
      label: '添加用餐证明备注',
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

  Widget _buildBottomBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Calculate total amount of selected orders
    final totalAmount = _selection.sum((order) => order.amount);

    final hasSelection = _selection.isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasSelection ? '已选择 ${_selection.length} 个订单' : '未选择订单',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                hasSelection
                    ? '合计: ${DateFormatter.formatAmount(totalAmount)}'
                    : '请选择订单后导出',
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
          text: '导出用餐证明',
          onPressed: _isExporting ? null : _confirmAndExport,
          type: AppButtonType.primary,
          isLoading: _isExporting,
        ),
      ],
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
                      color: AppPalette.amountFor(context),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:receipt_tamer/core/services/log_service.dart';
import 'package:receipt_tamer/core/services/log_config.dart';
import 'package:receipt_tamer/core/utils/date_formatter.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/presentation/providers/order_provider.dart';
import 'package:receipt_tamer/presentation/widgets/common/empty_state.dart';
import 'package:receipt_tamer/presentation/widgets/common/date_range_picker.dart';
import 'package:receipt_tamer/presentation/widgets/invoice/order_selector_card.dart';

/// Invoice relation filter enum
enum InvoiceRelationFilter {
  all, // 全部
  withoutInvoice, // 未关联发票
  withInvoice, // 已关联发票
}

/// Result returned from order selector
class OrderSelectorResult {
  final List<int> selectedOrderIds;

  OrderSelectorResult({required this.selectedOrderIds});
}

/// Order selector screen for selecting orders to link with an invoice
class OrderSelectorScreen extends ConsumerStatefulWidget {
  /// Currently selected order IDs
  final List<int> selectedOrderIds;

  /// Invoice ID being edited (to exclude its existing relations from "has invoice" filter)
  final int? excludeInvoiceId;

  const OrderSelectorScreen({
    super.key,
    this.selectedOrderIds = const [],
    this.excludeInvoiceId,
  });

  @override
  ConsumerState<OrderSelectorScreen> createState() => _OrderSelectorScreenState();
}

class _OrderSelectorScreenState extends ConsumerState<OrderSelectorScreen> {
  late List<int> _selectedOrderIds;
  List<Order> _orders = [];
  bool _isLoading = true;

  // Filter state
  InvoiceRelationFilter _relationFilter = InvoiceRelationFilter.withoutInvoice;
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchKeyword = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedOrderIds = List.from(widget.selectedOrderIds);
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
      final orders = await ref.read(orderProvider.notifier).searchOrdersWithInvoiceRelation(
            keyword: _searchKeyword.isNotEmpty ? _searchKeyword : null,
            startDate: _startDate,
            endDate: _endDate,
            hasInvoice: _relationFilter == InvoiceRelationFilter.withInvoice
                ? true
                : _relationFilter == InvoiceRelationFilter.withoutInvoice
                    ? false
                    : null,
            excludeInvoiceId: widget.excludeInvoiceId,
          );

      if (mounted) {
        setState(() {
          _orders = orders;
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

  void _confirmSelection() {
    Navigator.of(context).pop(OrderSelectorResult(
      selectedOrderIds: _selectedOrderIds,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('选择关联订单'),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _confirmSelection,
            child: Text(
              _selectedOrderIds.isNotEmpty ? '确认(${_selectedOrderIds.length})' : '确认',
              style: TextStyle(color: colorScheme.primary),
            ),
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

          // Order list
          Expanded(
            child: _buildOrderList(context),
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
                      value: InvoiceRelationFilter.withoutInvoice,
                      label: Text('未关联'),
                    ),
                    ButtonSegment(
                      value: InvoiceRelationFilter.withInvoice,
                      label: Text('已关联'),
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

        return OrderSelectorCard(
          order: order,
          isSelected: isSelected,
          onTap: () => _showOrderDetail(order),
          onCheckChanged: orderId != null ? (_) => _toggleSelection(orderId) : null,
        );
      },
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
                  hasSelection ? '合计: ${DateFormatter.formatAmount(totalAmount)}' : '将取消所有订单关联',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: hasSelection ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const Spacer(),
            FilledButton(
              onPressed: _confirmSelection,
              child: const Text('确认'),
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
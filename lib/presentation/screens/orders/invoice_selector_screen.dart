import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:receipt_tamer/core/services/log_service.dart';
import 'package:receipt_tamer/core/services/log_config.dart';
import 'package:receipt_tamer/core/utils/date_formatter.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/presentation/providers/invoice_provider.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_notice.dart';
import 'package:receipt_tamer/presentation/widgets/common/empty_state.dart';
import 'package:receipt_tamer/presentation/widgets/common/date_range_picker.dart';
import 'package:receipt_tamer/presentation/widgets/common/floating_overlay_layout.dart';
import 'package:receipt_tamer/presentation/widgets/order/invoice_selector_card.dart';

enum OrderRelationFilter {
  all, // 全部
  withoutOrder, // 未关联订单
  withOrder, // 已关联订单
}

/// Result returned from invoice selector
class InvoiceSelectorResult {
  final int? selectedInvoiceId;

  InvoiceSelectorResult({this.selectedInvoiceId});
}

/// Invoice data with order count
class InvoiceWithCount {
  final Invoice invoice;
  final int orderCount;

  InvoiceWithCount({required this.invoice, required this.orderCount});
}

/// Invoice selector screen for selecting an invoice to link with an order
class InvoiceSelectorScreen extends ConsumerStatefulWidget {
  /// Order ID that will be linked to the selected invoice
  final int orderId;

  const InvoiceSelectorScreen({super.key, required this.orderId});

  @override
  ConsumerState<InvoiceSelectorScreen> createState() =>
      _InvoiceSelectorScreenState();
}

class _InvoiceSelectorScreenState extends ConsumerState<InvoiceSelectorScreen> {
  List<InvoiceWithCount> _invoicesWithCount = [];
  bool _isLoading = true;

  // Filter state
  OrderRelationFilter _relationFilter = OrderRelationFilter.withoutOrder;
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchKeyword = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
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
      // Search invoices with filters
      final invoices = await ref
          .read(invoiceRepositoryProvider)
          .search(
            sellerName: _searchKeyword.isNotEmpty ? _searchKeyword : null,
            startDate: _startDate,
            endDate: _endDate,
            hasLinkedOrder: _relationFilter == OrderRelationFilter.withOrder
                ? true
                : _relationFilter == OrderRelationFilter.withoutOrder
                ? false
                : null,
          );

      // Get order count for each invoice
      final invoicesWithCount = <InvoiceWithCount>[];
      for (final invoice in invoices) {
        if (invoice.id != null) {
          final count = await ref
              .read(invoiceProvider.notifier)
              .getOrderCountForInvoice(invoice.id!);
          invoicesWithCount.add(
            InvoiceWithCount(invoice: invoice, orderCount: count),
          );
        }
      }

      if (mounted) {
        setState(() {
          _invoicesWithCount = invoicesWithCount;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        setState(() => _isLoading = false);
        logService.e(LogConfig.moduleUi, '加载发票失败', e, stackTrace);
        AppNotice.error(context, '加载发票失败: $e');
      }
    }
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

  Future<void> _selectInvoice(Invoice invoice) async {
    // Get current order IDs for this invoice
    final currentOrderIds = await ref
        .read(invoiceProvider.notifier)
        .getOrderIdsForInvoice(invoice.id!);

    // Add the new order ID if not already present
    if (!currentOrderIds.contains(widget.orderId)) {
      currentOrderIds.add(widget.orderId);
    }

    // Update the invoice's order relations
    await ref
        .read(invoiceProvider.notifier)
        .updateOrderRelations(invoice.id!, currentOrderIds);

    if (mounted) {
      Navigator.of(
        context,
      ).pop(InvoiceSelectorResult(selectedInvoiceId: invoice.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('选择发票'), elevation: 0),
      body: FloatingOverlayLayout(
        top: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFilterSection(context),
            if (_startDate != null || _endDate != null)
              _buildDateFilterChip(context),
          ],
        ),
        bodyBuilder: (context, contentPadding) =>
            _buildInvoiceList(context, contentPadding),
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
            hintText: '搜索销售方名称',
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

        // Filter chips row
        Row(
          children: [
            // Order relation filter
            Expanded(
              child: SegmentedButton<OrderRelationFilter>(
                segments: const [
                  ButtonSegment(
                    value: OrderRelationFilter.all,
                    label: Text('全部'),
                  ),
                  ButtonSegment(
                    value: OrderRelationFilter.withoutOrder,
                    label: Text('未关联'),
                  ),
                  ButtonSegment(
                    value: OrderRelationFilter.withOrder,
                    label: Text('已关联'),
                  ),
                ],
                selected: {_relationFilter},
                onSelectionChanged: (Set<OrderRelationFilter> selection) {
                  setState(() => _relationFilter = selection.first);
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

  Widget _buildInvoiceList(BuildContext context, EdgeInsets contentPadding) {
    if (_isLoading) {
      return Padding(
        padding: contentPadding,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_invoicesWithCount.isEmpty) {
      return Padding(
        padding: contentPadding,
        child: EmptyState(
          icon: Icons.description_outlined,
          title:
              _searchKeyword.isNotEmpty ||
                  _startDate != null ||
                  _relationFilter != OrderRelationFilter.all
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
      itemCount: _invoicesWithCount.length,
      itemBuilder: (context, index) {
        final item = _invoicesWithCount[index];
        return InvoiceSelectorCard(
          invoice: item.invoice,
          orderCount: item.orderCount,
          onTap: () => _selectInvoice(item.invoice),
        );
      },
    );
  }
}

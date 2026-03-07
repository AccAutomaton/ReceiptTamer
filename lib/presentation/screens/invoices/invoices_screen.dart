import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:catering_receipt_recorder/core/constants/app_constants.dart';
import 'package:catering_receipt_recorder/data/models/order.dart';
import 'package:catering_receipt_recorder/presentation/providers/order_provider.dart';
import 'package:catering_receipt_recorder/presentation/providers/invoice_provider.dart';
import 'package:catering_receipt_recorder/presentation/widgets/common/empty_state.dart';
import 'package:catering_receipt_recorder/presentation/widgets/invoice/invoice_card.dart';

/// Invoices screen - displays list of all invoices
class InvoicesScreen extends ConsumerStatefulWidget {
  final int? filterOrderId; // Optional: filter by order ID

  const InvoicesScreen({
    super.key,
    this.filterOrderId,
  });

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  Order? _filterOrder;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (widget.filterOrderId != null) {
      _filterOrder = await ref.read(orderProvider.notifier).getOrderById(widget.filterOrderId!);
    }
    _loadInvoices();
  }

  void _loadInvoices() {
    ref.read(invoiceProvider.notifier).loadInvoices(
          filterOrderId: widget.filterOrderId,
        );
  }

  void _handleAddInvoice() {
    if (widget.filterOrderId != null) {
      context.push('/invoices/new?orderId=${widget.filterOrderId}');
    } else {
      context.push('/invoices/new');
    }
  }

  void _handleInvoiceTap(int invoiceId) {
    context.push('/invoices/$invoiceId');
  }

  @override
  Widget build(BuildContext context) {
    final invoiceState = ref.watch(invoiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _filterOrder != null
              ? '${_filterOrder!.shopName} 的发票'
              : AppConstants.titleInvoices,
        ),
        elevation: 0,
        actions: [
          if (widget.filterOrderId == null) ...[
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () {
                _showFilterDialog(context);
              },
              tooltip: '筛选',
            ),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                _showSearchDialog(context);
              },
              tooltip: '搜索',
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(invoiceProvider.notifier).loadInvoices(
                filterOrderId: widget.filterOrderId,
                refresh: true,
              );
        },
        child: invoiceState.isLoading && invoiceState.invoices.isEmpty
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : invoiceState.invoices.isEmpty
                ? EmptyInvoices(
                    onAdd: _handleAddInvoice,
                  )
                : FutureBuilder<List<dynamic>>(
                    future: _loadOrderNames(),
                    builder: (context, snapshot) {
                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: invoiceState.invoices.length,
                        itemBuilder: (context, index) {
                          final invoice = invoiceState.invoices[index];
                          String? orderShopName;

                          if (snapshot.hasData) {
                            final orderMap = snapshot.data!;
                            final orderId = invoice.orderId;
                            orderShopName = orderId != null ? orderMap[orderId] : null;
                          }

                          return InvoiceCard(
                            invoice: invoice,
                            orderShopName: orderShopName,
                            onTap: () => _handleInvoiceTap(invoice.id!),
                          );
                        },
                      );
                    },
                  ),
      ),
    );
  }

  Future<List<dynamic>> _loadOrderNames() async {
    final invoices = ref.read(invoiceProvider).invoices;
    final orderIds = invoices.map((i) => i.orderId).where((id) => id != null && id > 0).toSet();

    final orderMap = <int, String>{};
    for (final orderId in orderIds) {
      if (orderId != null) {
        final order = await ref.read(orderProvider.notifier).getOrderById(orderId);
        if (order != null) {
          orderMap[orderId] = order.shopName;
        }
      }
    }

    return [orderMap];
  }

  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '筛选发票',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.list),
                title: const Text('全部发票'),
                onTap: () {
                  ref.read(invoiceProvider.notifier).loadInvoices();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.today),
                title: const Text('今日发票'),
                onTap: () {
                  ref.read(invoiceProvider.notifier).loadTodayInvoices();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month),
                title: const Text('本月发票'),
                onTap: () {
                  ref.read(invoiceProvider.notifier).loadThisMonthInvoices();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.link_off),
                title: const Text('未关联订单'),
                onTap: () {
                  ref.read(invoiceProvider.notifier).loadInvoicesWithoutOrders();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    final searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('搜索发票'),
        content: TextField(
          controller: searchController,
          decoration: const InputDecoration(
            hintText: '输入发票号码',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final query = searchController.text.trim();
              if (query.isNotEmpty) {
                ref.read(invoiceProvider.notifier).searchInvoices(
                      invoiceNumber: query,
                    );
              }
              Navigator.pop(context);
            },
            child: const Text('搜索'),
          ),
        ],
      ),
    );
  }
}

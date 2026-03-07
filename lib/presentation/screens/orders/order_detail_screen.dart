import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:catering_receipt_recorder/core/constants/app_constants.dart';
import 'package:catering_receipt_recorder/core/utils/date_formatter.dart';
import 'package:catering_receipt_recorder/data/models/order.dart';
import 'package:catering_receipt_recorder/presentation/providers/order_provider.dart';
import 'package:catering_receipt_recorder/presentation/providers/invoice_provider.dart';
import 'package:catering_receipt_recorder/presentation/widgets/order/order_image_preview.dart';

/// Order detail screen
class OrderDetailScreen extends ConsumerStatefulWidget {
  final int orderId;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
  });

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  Order? _order;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    final order = await ref.read(orderProvider.notifier).getOrderById(widget.orderId);
    if (mounted) {
      setState(() {
        _order = order;
      });
    }
  }

  Future<void> _handleEdit() async {
    final result = await context.push('/orders/${widget.orderId}/edit');
    if (result == true) {
      _loadOrder();
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppConstants.confirmDelete),
        content: const Text(AppConstants.confirmDeleteOrder),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppConstants.btnCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              AppConstants.btnDelete,
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref.read(orderProvider.notifier).deleteOrder(widget.orderId);
      if (mounted) {
        if (success) {
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppConstants.successDeleted)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppConstants.errorDeletingData)),
          );
        }
      }
    }
  }

  void _handleAddInvoice() {
    context.push('/invoices/new?orderId=${widget.orderId}');
  }

  void _handleViewInvoices() {
    context.push('/invoices?orderId=${widget.orderId}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(AppConstants.titleOrderDetail),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final order = _order!;
    final invoices = ref.watch(
      invoicesByOrderIdProvider(order.id!),
    );

    final orderDate = order.orderDate != null && order.orderDate!.isNotEmpty
        ? DateTime.tryParse(order.orderDate!)
        : null;
    final mealTime = DateFormatter.mealTimeFromString(order.mealTime);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.titleOrderDetail),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _handleEdit,
            tooltip: '编辑',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _handleDelete,
            tooltip: '删除',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image preview
            if (order.imagePath.isNotEmpty && File(order.imagePath).existsSync())
              OrderImagePreview(
                imagePath: order.imagePath,
                height: 250,
              ),

            // Order details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Amount card
                  _buildAmountCard(context, order, colorScheme),

                  const SizedBox(height: 16),

                  // Details card
                  _buildDetailsCard(context, order, orderDate, mealTime, colorScheme),

                  const SizedBox(height: 16),

                  // Invoices section
                  _buildInvoicesSection(context, order, invoices, colorScheme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountCard(BuildContext context, Order order, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withOpacity(0.1),
            colorScheme.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Text(
            '实付款',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormatter.formatAmount(order.amount),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(
    BuildContext context,
    Order order,
    DateTime? orderDate,
    MealTime? mealTime,
    ColorScheme colorScheme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '订单信息',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(
              '店铺名称',
              order.shopName.isEmpty ? '-' : order.shopName,
              Icons.store,
              colorScheme,
            ),
            const Divider(),
            _buildDetailRow(
              '订单号',
              order.orderNumber.isEmpty ? '-' : order.orderNumber,
              Icons.receipt,
              colorScheme,
            ),
            const Divider(),
            _buildDetailRow(
              '日期',
              orderDate != null
                  ? DateFormatter.formatDisplay(orderDate)
                  : '-',
              Icons.calendar_today,
              colorScheme,
            ),
            const Divider(),
            _buildDetailRow(
              '时段',
              DateFormatter.mealTimeToDisplayName(mealTime),
              Icons.access_time,
              colorScheme,
            ),
            const Divider(),
            _buildDetailRow(
              '录入时间',
              order.createdAt.isNotEmpty
                  ? DateFormatter.formatDisplayWithTime(
                      DateTime.tryParse(order.createdAt) ?? DateTime.now(),
                    )
                  : '-',
              Icons.edit_calendar,
              colorScheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoicesSection(
    BuildContext context,
    Order order,
    AsyncValue<List<dynamic>> invoices,
    ColorScheme colorScheme,
  ) {
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
                  '关联发票',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: _handleAddInvoice,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            invoices.when(
              data: (invoiceList) {
                if (invoiceList.isEmpty) {
                  return Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 48,
                          color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '暂无关联发票',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: invoiceList.length,
                  itemBuilder: (context, index) {
                    final invoice = invoiceList[index];
                    return ListTile(
                      leading: const Icon(Icons.description),
                      title: Text(invoice.invoiceNumber.isEmpty
                          ? '未填写发票号'
                          : invoice.invoiceNumber),
                      subtitle: Text(
                        DateFormatter.formatAmount(invoice.totalAmount),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        context.push('/invoices/${invoice.id}');
                      },
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stack) => Center(
                child: Text(
                  '加载失败: $error',
                  style: TextStyle(
                    color: colorScheme.error,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

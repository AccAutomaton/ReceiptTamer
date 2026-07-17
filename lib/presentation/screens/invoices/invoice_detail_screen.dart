import 'package:flutter/material.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_alert_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:receipt_tamer/core/constants/app_constants.dart';
import 'package:receipt_tamer/core/services/log_service.dart';
import 'package:receipt_tamer/core/services/log_config.dart';
import 'package:receipt_tamer/core/utils/date_formatter.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/presentation/providers/invoice_provider.dart';
import 'package:receipt_tamer/presentation/providers/order_provider.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_notice.dart';
import 'package:receipt_tamer/presentation/widgets/common/empty_state.dart';
import 'package:receipt_tamer/presentation/widgets/common/scroll_edge_fog.dart';
import 'package:receipt_tamer/presentation/widgets/invoice/invoice_image_preview.dart';

/// Invoice detail screen
class InvoiceDetailScreen extends ConsumerStatefulWidget {
  final int invoiceId;

  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  ConsumerState<InvoiceDetailScreen> createState() =>
      _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends ConsumerState<InvoiceDetailScreen> {
  Invoice? _invoice;
  List<Order> _relatedOrders = [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadInvoice();
  }

  Future<void> _loadInvoice() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final invoiceRepository = ref.read(invoiceRepositoryProvider);
      final orderRepository = ref.read(orderRepositoryProvider);
      final invoice = await invoiceRepository.getById(widget.invoiceId);
      if (invoice == null) {
        if (mounted) {
          setState(() {
            _invoice = null;
            _relatedOrders = [];
            _isLoading = false;
            _loadError = '发票不存在或已被删除';
          });
        }
        return;
      }

      final orderIds = await invoiceRepository.getOrderIdsForInvoice(
        widget.invoiceId,
      );
      final orders = orderIds.isEmpty
          ? const <Order>[]
          : await orderRepository.getByIds(orderIds);

      if (mounted) {
        setState(() {
          _invoice = invoice;
          _relatedOrders = orders;
          _isLoading = false;
          _loadError = null;
        });
      }
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleUi, '加载发票失败', e, stackTrace);
      if (mounted) {
        setState(() {
          _invoice = null;
          _relatedOrders = [];
          _isLoading = false;
          _loadError = '加载发票失败，请重试';
        });
      }
    }
  }

  Future<void> _handleEdit() async {
    final result = await context.push('/invoices/${widget.invoiceId}/edit');
    if (result == true) {
      _loadInvoice();
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => GlassAlertDialog(
        title: const Text(AppConstants.confirmDelete),
        content: const Text(AppConstants.confirmDeleteInvoice),
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
      final success = await ref
          .read(invoiceProvider.notifier)
          .deleteInvoice(widget.invoiceId);
      if (mounted) {
        if (success) {
          logService.i(LogConfig.moduleUi, '发票已删除: id=${widget.invoiceId}');
          AppNotice.success(context, AppConstants.successDeleted);
          context.pop();
        } else {
          AppNotice.error(context, AppConstants.errorDeletingData);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppConstants.titleInvoiceDetail)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_invoice == null) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppConstants.titleInvoiceDetail)),
        body: EmptyState(
          icon: Icons.description_outlined,
          title: _loadError ?? '发票不存在或已被删除',
          subtitle: '你可以重新加载，或返回发票列表刷新数据。',
          actionLabel: '重新加载',
          actionIcon: Icons.refresh,
          onAction: _loadInvoice,
        ),
      );
    }

    final invoice = _invoice!;

    final invoiceDate =
        invoice.invoiceDate != null && invoice.invoiceDate!.isNotEmpty
        ? DateTime.tryParse(invoice.invoiceDate!)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.titleInvoiceDetail),
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
      body: ScrollEdgeFog(
        showBottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image preview
              InvoiceImagePreview(imagePath: invoice.imagePath, height: 250),

              // Invoice details
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Amount card
                    _buildAmountCard(context, invoice, colorScheme),

                    const SizedBox(height: 16),

                    // Details card
                    _buildDetailsCard(
                      context,
                      invoice,
                      invoiceDate,
                      colorScheme,
                    ),

                    const SizedBox(height: 16),

                    // Related orders card
                    if (_relatedOrders.isNotEmpty) ...[
                      for (final order in _relatedOrders)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildOrderCard(context, order, colorScheme),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountCard(
    BuildContext context,
    Invoice invoice,
    ColorScheme colorScheme,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.secondaryContainer.withValues(alpha: 0.5),
            colorScheme.secondaryContainer.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.secondary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            AppConstants.labelTotalAmount,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormatter.formatAmount(invoice.totalAmount),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(
    BuildContext context,
    Invoice invoice,
    DateTime? invoiceDate,
    ColorScheme colorScheme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '发票信息',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(
              AppConstants.labelSellerName,
              invoice.sellerName.isEmpty ? '-' : invoice.sellerName,
              Icons.store,
              colorScheme,
            ),
            const Divider(),
            _buildDetailRow(
              AppConstants.labelInvoiceNumber,
              invoice.invoiceNumber.isEmpty ? '-' : invoice.invoiceNumber,
              Icons.description,
              colorScheme,
            ),
            const Divider(),
            _buildDetailRow(
              AppConstants.labelInvoiceDate,
              invoiceDate != null
                  ? DateFormatter.formatDisplay(invoiceDate)
                  : '-',
              Icons.event,
              colorScheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    Order order,
    ColorScheme colorScheme,
  ) {
    final orderDate = order.orderDate != null && order.orderDate!.isNotEmpty
        ? DateTime.tryParse(order.orderDate!)
        : null;
    final mealTime = DateFormatter.mealTimeFromString(order.mealTime);

    return Card(
      child: InkWell(
        onTap: () async {
          if (order.id != null && order.id! > 0) {
            await context.push('/orders/${order.id}');
            if (mounted) {
              await _loadInvoice();
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.receipt_long, size: 24, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '关联订单',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.shopName.isEmpty ? '未命名店铺' : order.shopName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (orderDate != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${DateFormatter.formatDisplay(orderDate)} ${DateFormatter.mealTimeToDisplayName(mealTime)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                DateFormatter.formatAmount(order.amount),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

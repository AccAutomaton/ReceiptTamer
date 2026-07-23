import 'package:flutter/material.dart';

import 'package:receipt_tamer/core/utils/date_formatter.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_alert_dialog.dart';

class InvoiceRelationTransferItem {
  const InvoiceRelationTransferItem({
    required this.order,
    required this.sourceInvoices,
  });

  final Order order;
  final List<Invoice> sourceInvoices;
}

String invoiceRelationLabel(Invoice invoice) {
  final number = invoice.invoiceNumber.trim();
  if (number.isNotEmpty) return '发票 $number';

  final seller = invoice.sellerName.trim();
  if (seller.isNotEmpty) return seller;

  return invoice.id == null ? '原发票' : '发票 #${invoice.id}';
}

Future<bool> showInvoiceRelationTransferDialog({
  required BuildContext context,
  required List<InvoiceRelationTransferItem> items,
  required String targetLabel,
}) async {
  if (items.isEmpty) return true;

  final totalAmount = items.fold<double>(
    0,
    (sum, item) => sum + item.order.amount,
  );
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => GlassAlertDialog(
      title: const Text('确认转移关联'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '这会把 ${items.length} 笔订单从原发票移到 $targetLabel，'
            '合计 ${DateFormatter.formatAmount(totalAmount)}。',
          ),
          const SizedBox(height: 16),
          for (final item in items) ...[
            _TransferLine(item: item, targetLabel: targetLabel),
            if (item != items.last) const Divider(height: 20),
          ],
          const SizedBox(height: 12),
          Text(
            '转移后，原发票将不再关联这些订单。',
            style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
              color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('保留原关联'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('确认转移'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

class _TransferLine extends StatelessWidget {
  const _TransferLine({required this.item, required this.targetLabel});

  final InvoiceRelationTransferItem item;
  final String targetLabel;

  @override
  Widget build(BuildContext context) {
    final sourceLabel = item.sourceInvoices.isEmpty
        ? '原发票'
        : item.sourceInvoices.map(invoiceRelationLabel).join('、');
    final orderLabel = item.order.shopName.trim().isEmpty
        ? '未命名订单'
        : item.order.shopName.trim();

    return Semantics(
      container: true,
      label:
          '$orderLabel，${DateFormatter.formatAmount(item.order.amount)}，'
          '从$sourceLabel转移到$targetLabel',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    orderLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(DateFormatter.formatAmount(item.order.amount)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$sourceLabel  →  $targetLabel',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

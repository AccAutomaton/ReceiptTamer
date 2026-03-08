import 'package:flutter/material.dart';

import 'package:catering_receipt_recorder/core/utils/date_formatter.dart';
import 'package:catering_receipt_recorder/data/models/invoice.dart';
import 'package:catering_receipt_recorder/presentation/widgets/common/app_card.dart';

/// Invoice card widget for displaying invoice information in the list
class InvoiceCard extends StatelessWidget {
  final Invoice invoice;
  final String? orderShopName; // Optional: related order shop name
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showThumbnail;
  final bool showOrderInfo;

  const InvoiceCard({
    super.key,
    required this.invoice,
    this.orderShopName,
    this.onTap,
    this.onLongPress,
    this.showThumbnail = false,
    this.showOrderInfo = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final invoiceDate = invoice.invoiceDate != null &&
            invoice.invoiceDate!.isNotEmpty
        ? DateTime.tryParse(invoice.invoiceDate!)
        : null;
    final formattedDate = invoiceDate != null
        ? DateFormatter.formatDisplay(invoiceDate)
        : invoice.invoiceDate ?? '-';

    final hasLinkedOrder = orderShopName != null && orderShopName!.isNotEmpty;

    return AppCard(
      onTap: onTap,
      onLongPress: onLongPress,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showThumbnail) ...[
            _buildThumbnail(context),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Invoice number
                Row(
                  children: [
                    Icon(
                      Icons.description,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        invoice.invoiceNumber.isEmpty
                            ? '未填写发票号'
                            : invoice.invoiceNumber,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Invoice date
                Row(
                  children: [
                    Icon(
                      Icons.event,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formattedDate,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),

                // Order info
                if (showOrderInfo) ...[
                  const SizedBox(height: 4),
                  if (hasLinkedOrder && orderShopName != null) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            orderShopName!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                          color: colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '未关联订单',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),

          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormatter.formatAmount(invoice.totalAmount),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (invoice.createdAt.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '录入: ${_formatDateShort(invoice.createdAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 60,
        height: 60,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.picture_as_pdf,
          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
        ),
      ),
    );
  }

  String _formatDateShort(String dateString) {
    final date = DateTime.tryParse(dateString);
    if (date == null) return '-';
    return '${date.month}/${date.day}';
  }
}

/// Compact invoice card widget for smaller spaces
class InvoiceCardCompact extends StatelessWidget {
  final Invoice invoice;
  final String? orderShopName;
  final VoidCallback? onTap;

  const InvoiceCardCompact({
    super.key,
    required this.invoice,
    this.orderShopName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final invoiceDate = invoice.invoiceDate != null &&
            invoice.invoiceDate!.isNotEmpty
        ? DateTime.tryParse(invoice.invoiceDate!)
        : null;
    final formattedDate = invoiceDate != null
        ? '${invoiceDate.month}/${invoiceDate.day}'
        : '';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    invoice.invoiceNumber.isEmpty
                        ? '未填写发票号'
                        : invoice.invoiceNumber,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (formattedDate.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      formattedDate,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              DateFormatter.formatAmount(invoice.totalAmount),
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

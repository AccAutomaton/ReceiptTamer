import 'package:flutter/material.dart';

import 'package:receipt_tamer/core/utils/date_formatter.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_card.dart';

/// Invoice card widget for displaying invoice information in the list
class InvoiceCard extends StatelessWidget {
  final Invoice invoice;
  final int? orderCount; // Number of linked orders
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showThumbnail;

  const InvoiceCard({
    super.key,
    required this.invoice,
    this.orderCount,
    this.onTap,
    this.onLongPress,
    this.showThumbnail = false,
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

    final hasLinkedOrders = orderCount != null && orderCount! > 0;

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
                // Seller name (title)
                Text(
                  invoice.sellerName.isEmpty ? '未知商家' : invoice.sellerName,
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
                const SizedBox(height: 4),
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
          Text(
            DateFormatter.formatAmount(invoice.totalAmount),
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
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
          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

/// Compact invoice card widget for smaller spaces
class InvoiceCardCompact extends StatelessWidget {
  final Invoice invoice;
  final int? orderCount;
  final VoidCallback? onTap;

  const InvoiceCardCompact({
    super.key,
    required this.invoice,
    this.orderCount,
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
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
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
                    invoice.sellerName.isEmpty ? '未知商家' : invoice.sellerName,
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
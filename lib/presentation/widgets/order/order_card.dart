import 'package:flutter/material.dart';

import 'package:catering_receipt_recorder/core/utils/date_formatter.dart';
import 'package:catering_receipt_recorder/data/models/order.dart';
import 'package:catering_receipt_recorder/core/constants/app_constants.dart';
import 'package:catering_receipt_recorder/presentation/widgets/common/app_card.dart';

/// Order card widget for displaying order information in the list
class OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showThumbnail;

  const OrderCard({
    super.key,
    required this.order,
    this.onTap,
    this.onLongPress,
    this.showThumbnail = false,
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

                // Order number
                if (order.orderNumber.isNotEmpty) ...[
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
                  const SizedBox(height: 4),
                ],

                // Order date and meal time
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '$formattedDate $formattedMealTime',
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
            ),
          ),

          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormatter.formatAmount(order.amount),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (order.createdAt.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '录入: ${_formatDateShort(order.createdAt)}',
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
          Icons.receipt_long,
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

/// Compact order card widget for smaller spaces
class OrderCardCompact extends StatelessWidget {
  final Order order;
  final VoidCallback? onTap;

  const OrderCardCompact({
    super.key,
    required this.order,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final orderDate = order.orderDate != null && order.orderDate!.isNotEmpty
        ? DateTime.tryParse(order.orderDate!)
        : null;
    final formattedDate = orderDate != null
        ? '${orderDate.month}/${orderDate.day}'
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
                    order.shopName.isEmpty ? '未命名店铺' : order.shopName,
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
              DateFormatter.formatAmount(order.amount),
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

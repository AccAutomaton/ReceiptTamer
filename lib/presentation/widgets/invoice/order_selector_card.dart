import 'package:flutter/material.dart';

import 'package:receipt_tamer/core/utils/date_formatter.dart';
import 'package:receipt_tamer/data/models/order.dart';

/// Order selector card widget for displaying order info with checkbox
/// Used in the OrderSelectorScreen for selecting orders to link with invoices
class OrderSelectorCard extends StatelessWidget {
  final Order order;
  final bool isSelected;
  final VoidCallback? onTap;
  final ValueChanged<bool?>? onCheckChanged;
  final bool showInvoiceStatus;

  const OrderSelectorCard({
    super.key,
    required this.order,
    required this.isSelected,
    this.onTap,
    this.onCheckChanged,
    this.showInvoiceStatus = true,
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

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer.withOpacity(0.3)
              : null,
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withOpacity(0.3),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox
            Checkbox(
              value: isSelected,
              onChanged: onCheckChanged,
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
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
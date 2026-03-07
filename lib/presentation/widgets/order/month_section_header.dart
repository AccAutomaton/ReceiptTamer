import 'package:flutter/material.dart';

/// Section header for month groups in order list
class MonthSectionHeader extends StatelessWidget {
  final int year;
  final int month;
  final int orderCount;
  final double totalAmount;
  final bool isPinned;

  const MonthSectionHeader({
    super.key,
    required this.year,
    required this.month,
    required this.orderCount,
    required this.totalAmount,
    this.isPinned = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isPinned
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.9)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: isPinned
            ? [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Left side: Year and Month
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '$year',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                '年',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$month',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                '月',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Right side: Order count and total amount
          Row(
            children: [
              _buildInfoItem(
                context,
                icon: Icons.receipt_long_outlined,
                label: '$orderCount笔',
              ),
              const SizedBox(width: 12),
              _buildInfoItem(
                context,
                icon: Icons.payments_outlined,
                label: '¥${totalAmount.toStringAsFixed(2)}',
                isHighlight: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    bool isHighlight = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: isHighlight ? colorScheme.primary : colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isHighlight ? FontWeight.w600 : FontWeight.normal,
            color: isHighlight ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
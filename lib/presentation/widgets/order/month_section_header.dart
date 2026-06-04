import 'package:flutter/material.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_surface.dart';

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

    return GlassSurface(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      fillColor: isPinned
          ? AppGlassTokens.sheetFillFor(context)
          : AppGlassTokens.panelFillFor(context),
      borderRadius: BorderRadius.circular(AppRadii.control),
      boxShadow: isPinned ? AppShadows.glass : null,
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
                  color: AppPalette.amountFor(context),
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
          color: isHighlight
              ? AppPalette.amountFor(context)
              : colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isHighlight ? FontWeight.w600 : FontWeight.normal,
            color: isHighlight
                ? AppPalette.amountFor(context)
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

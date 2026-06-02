import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_button.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_card.dart';
import 'package:receipt_tamer/presentation/widgets/common/liquid_glass_background.dart';

/// Export mode selection
/// 导出模式选择
enum ExportMode {
  /// Export based on invoices
  /// 根据发票导出
  invoices,

  /// Export based on orders
  /// 根据订单导出
  orders,
}

/// Export mode selection screen
/// 导出模式选择页面
class ExportModeScreen extends StatefulWidget {
  const ExportModeScreen({super.key});

  @override
  State<ExportModeScreen> createState() => _ExportModeScreenState();
}

class _ExportModeScreenState extends State<ExportModeScreen> {
  ExportMode _selectedMode = ExportMode.invoices;

  void _navigateToExportScreen() {
    // Navigate to appropriate export screen based on mode
    if (_selectedMode == ExportMode.invoices) {
      context.push('/export/invoices');
    } else {
      context.push('/export/orders');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppPalette.coldBackground,
      appBar: AppBar(title: const Text('导出报销材料')),
      body: LiquidGlassBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mode selection card
              _buildModeSelectionCard(colorScheme),

              const SizedBox(height: 32),

              // Next button
              AppButton(
                text: '下一步',
                onPressed: _navigateToExportScreen,
                icon: const Icon(Icons.arrow_forward),
                isFullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelectionCard(ColorScheme colorScheme) {
    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '导出方式',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            _buildModeOption(
              mode: ExportMode.invoices,
              icon: FontAwesomeIcons.fileInvoiceDollar,
              title: '根据发票导出',
              description: '选择发票，自动包含关联订单',
              colorScheme: colorScheme,
            ),

            const SizedBox(height: 12),

            _buildModeOption(
              mode: ExportMode.orders,
              icon: FontAwesomeIcons.receipt,
              title: '根据订单导出',
              description: '选择订单，联动勾选关联同一发票的所有订单',
              colorScheme: colorScheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeOption({
    required ExportMode mode,
    required IconData icon,
    required String title,
    required String description,
    required ColorScheme colorScheme,
  }) {
    final isSelected = _selectedMode == mode;

    return InkWell(
      onTap: () {
        setState(() => _selectedMode = mode);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppPalette.selectedFill : AppPalette.cardFill,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: isSelected
                ? AppPalette.actionPrimary
                : colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AppPalette.actionPrimary
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? AppPalette.actionPrimary
                      : colorScheme.outline.withValues(alpha: 0.55),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 8),

            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: FaIcon(icon, size: 20, color: AppPalette.actionPrimary),
            ),
            const SizedBox(width: 12),

            // Title and description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

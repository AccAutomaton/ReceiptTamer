import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../providers/export_provider.dart';

/// Export mode selection screen
/// 导出模式选择页面
class ExportModeScreen extends ConsumerStatefulWidget {
  const ExportModeScreen({super.key});

  @override
  ConsumerState<ExportModeScreen> createState() => _ExportModeScreenState();
}

class _ExportModeScreenState extends ConsumerState<ExportModeScreen> {
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
      appBar: AppBar(
        title: const Text('导出报销材料'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mode selection card
            _buildModeSelectionCard(colorScheme),

            const SizedBox(height: 32),

            // Next button
            FilledButton.icon(
              onPressed: _navigateToExportScreen,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('下一步'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelectionCard(ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '导出方式',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // Invoice export option
            _buildModeOption(
              mode: ExportMode.invoices,
              icon: FontAwesomeIcons.fileInvoiceDollar,
              title: '根据发票导出',
              description: '选择发票，自动包含关联订单',
              colorScheme: colorScheme,
            ),

            const SizedBox(height: 12),

            // Order export option
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
          color: isSelected
              ? colorScheme.primaryContainer.withValues(alpha: 0.3)
              : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            // Radio indicator
            Radio<ExportMode>(
              value: mode,
              groupValue: _selectedMode,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedMode = value);
                }
              },
            ),
            const SizedBox(width: 8),

            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: FaIcon(
                icon,
                size: 20,
                color: colorScheme.primary,
              ),
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
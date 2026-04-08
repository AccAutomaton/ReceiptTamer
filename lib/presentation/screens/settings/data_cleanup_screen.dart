import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../providers/cleanup_provider.dart';

/// Data cleanup mode selection screen
class DataCleanupScreen extends ConsumerStatefulWidget {
  const DataCleanupScreen({super.key});

  @override
  ConsumerState<DataCleanupScreen> createState() => _DataCleanupScreenState();
}

class _DataCleanupScreenState extends ConsumerState<DataCleanupScreen> {
  CleanupMode _selectedMode = CleanupMode.orders;

  @override
  void initState() {
    super.initState();
    // Initialize provider with default mode
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cleanupProvider.notifier).setMode(_selectedMode);
    });
  }

  void _navigateToCleanupScreen() {
    // Update provider with selected mode
    ref.read(cleanupProvider.notifier).setMode(_selectedMode);

    // Navigate to appropriate cleanup screen
    if (_selectedMode == CleanupMode.orders) {
      context.push('/settings/cleanup/orders');
    } else {
      context.push('/settings/cleanup/invoices');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('清理数据'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Warning banner
            _buildWarningBanner(colorScheme),
            const SizedBox(height: 24),

            // Cleanup mode selection
            _buildModeSelectionCard(colorScheme),

            const SizedBox(height: 32),

            // Next button
            FilledButton.icon(
              onPressed: _navigateToCleanupScreen,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('下一步'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningBanner(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.error.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: colorScheme.error,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '警告：数据删除后无法恢复，请谨慎操作',
              style: TextStyle(
                color: colorScheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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
              '清理方式',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // Order cleanup option
            _buildModeOption(
              mode: CleanupMode.orders,
              icon: FontAwesomeIcons.receipt,
              title: '根据订单清理',
              description: '选择订单删除，可选择是否同时删除关联发票',
              colorScheme: colorScheme,
            ),

            const SizedBox(height: 12),

            // Invoice cleanup option
            _buildModeOption(
              mode: CleanupMode.invoices,
              icon: FontAwesomeIcons.fileInvoiceDollar,
              title: '根据发票清理',
              description: '选择发票删除，可选择是否同时删除关联订单',
              colorScheme: colorScheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeOption({
    required CleanupMode mode,
    required IconData icon,
    required String title,
    required String description,
    required ColorScheme colorScheme,
  }) {
    final isSelected = _selectedMode == mode;

    return InkWell(
      onTap: () {
        setState(() => _selectedMode = mode);
        ref.read(cleanupProvider.notifier).setMode(mode);
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
            Radio<CleanupMode>(
              value: mode,
              groupValue: _selectedMode,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedMode = value);
                  ref.read(cleanupProvider.notifier).setMode(value);
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
import 'dart:typed_data';

import 'package:catering_receipt_recorder/presentation/widgets/common/app_button.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Export options screen - choose what to export
class ExportOptionsScreen extends ConsumerStatefulWidget {
  final List<int> invoiceIds;
  final List<int> orderIds;

  const ExportOptionsScreen({
    required this.invoiceIds,
    required this.orderIds,
    super.key,
  });

  @override
  ConsumerState<ExportOptionsScreen> createState() => _ExportOptionsScreenState();
}

class _ExportOptionsScreenState extends ConsumerState<ExportOptionsScreen> {
  // Export type selection
  bool _exportMealProof = true;
  bool _exportInvoice = true;
  bool _exportMealDetails = true;

  // Format selection for each type
  ExportFormat _mealProofFormat = ExportFormat.pdf;
  ExportFormat _invoiceFormat = ExportFormat.pdf;
  // Meal details only supports xlsx

  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('导出选项'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.description_outlined, color: colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '报销材料',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${widget.invoiceIds.length} 张发票 · ${widget.orderIds.length} 条订单',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Export options
                Text(
                  '选择导出内容',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),

                // Meal proof option
                _buildExportOptionCard(
                  title: '用餐证明',
                  subtitle: '订单截图汇总文档',
                  icon: Icons.restaurant_menu,
                  value: _exportMealProof,
                  format: _mealProofFormat,
                  showFormat: true,
                  onToggle: (v) => setState(() => _exportMealProof = v),
                  onFormatChange: (f) => setState(() => _mealProofFormat = f),
                ),

                const SizedBox(height: 12),

                // Invoice option
                _buildExportOptionCard(
                  title: '发票',
                  subtitle: '发票信息汇总文档',
                  icon: Icons.receipt_long,
                  value: _exportInvoice,
                  format: _invoiceFormat,
                  showFormat: true,
                  onToggle: (v) => setState(() => _exportInvoice = v),
                  onFormatChange: (f) => setState(() => _invoiceFormat = f),
                ),

                const SizedBox(height: 12),

                // Meal details option
                _buildExportOptionCard(
                  title: '用餐明细',
                  subtitle: '订单和发票明细表格',
                  icon: Icons.table_chart,
                  value: _exportMealDetails,
                  format: ExportFormat.xlsx,
                  showFormat: false,
                  onToggle: (v) => setState(() => _exportMealDetails = v),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),

          // Export button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: AppButton(
                text: '开始导出',
                onPressed: _canExport() ? _handleExport : null,
                isLoading: _isExporting,
                isFullWidth: true,
                type: AppButtonType.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canExport() {
    return _exportMealProof || _exportInvoice || _exportMealDetails;
  }

  Widget _buildExportOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    ExportFormat format = ExportFormat.pdf,
    bool showFormat = true,
    required ValueChanged<bool> onToggle,
    ValueChanged<ExportFormat>? onFormatChange,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Checkbox(
                  value: value,
                  onChanged: (v) => onToggle(v ?? false),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: value
                        ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: value ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (value && showFormat)
                  _buildFormatSelector(format, onFormatChange!),
                if (value && !showFormat)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'XLSX',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatSelector(
    ExportFormat currentFormat,
    ValueChanged<ExportFormat> onChanged,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFormatChip('PDF', ExportFormat.pdf, currentFormat, onChanged),
          const SizedBox(width: 4),
          _buildFormatChip('DOCX', ExportFormat.docx, currentFormat, onChanged),
        ],
      ),
    );
  }

  Widget _buildFormatChip(
    String label,
    ExportFormat format,
    ExportFormat currentFormat,
    ValueChanged<ExportFormat> onChanged,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = format == currentFormat;

    return GestureDetector(
      onTap: () => onChanged(format),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Future<void> _handleExport() async {
    setState(() {
      _isExporting = true;
    });

    try {
      final timestamp = _formatTimestamp(DateTime.now());
      int successCount = 0;

      // Export meal proof
      if (_exportMealProof) {
        final extension = _mealProofFormat == ExportFormat.pdf ? 'pdf' : 'docx';
        final path = await FilePicker.platform.saveFile(
          dialogTitle: '保存用餐证明',
          fileName: '用餐证明_$timestamp.$extension',
          type: FileType.custom,
          allowedExtensions: [extension],
          bytes: Uint8List(0),
        );
        if (path != null) {
          successCount++;
        }
      }

      // Export invoice
      if (_exportInvoice) {
        final extension = _invoiceFormat == ExportFormat.pdf ? 'pdf' : 'docx';
        final path = await FilePicker.platform.saveFile(
          dialogTitle: '保存发票',
          fileName: '发票_$timestamp.$extension',
          type: FileType.custom,
          allowedExtensions: [extension],
          bytes: Uint8List(0),
        );
        if (path != null) {
          successCount++;
        }
      }

      // Export meal details
      if (_exportMealDetails) {
        final path = await FilePicker.platform.saveFile(
          dialogTitle: '保存用餐明细',
          fileName: '用餐明细_$timestamp.xlsx',
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
          bytes: Uint8List(0),
        );
        if (path != null) {
          successCount++;
        }
      }

      if (mounted && successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功导出 $successCount 个文件')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  String _formatTimestamp(DateTime dt) {
    return '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}_${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}';
  }
}

/// Export format enum
enum ExportFormat {
  pdf,
  docx,
  xlsx,
}
import 'dart:io';

import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/services/file_service.dart';
import 'package:receipt_tamer/data/services/invoice_export_service.dart';
import 'package:receipt_tamer/data/services/meal_details_export_service.dart';
import 'package:receipt_tamer/data/services/meal_proof_export_service.dart';
import 'package:receipt_tamer/core/services/log_service.dart';
import 'package:receipt_tamer/core/services/log_config.dart';
import 'package:receipt_tamer/presentation/providers/invoice_provider.dart';
import 'package:receipt_tamer/presentation/providers/order_provider.dart';
import 'package:receipt_tamer/presentation/screens/export/saved_files_screen.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

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

  // Invoice export options
  bool _showInvoiceTimeLabel = true; // Show time labels on invoices

  // Meal details export options
  bool _skipEmptyDays = true; // Skip days without meal records

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
                  formatLabel: 'PDF',
                  onToggle: (v) => setState(() => _exportMealProof = v),
                ),

                const SizedBox(height: 12),

                // Invoice option
                _buildExportOptionCard(
                  title: '发票',
                  subtitle: '发票信息汇总文档',
                  icon: Icons.receipt_long,
                  value: _exportInvoice,
                  formatLabel: 'PDF',
                  onToggle: (v) => setState(() => _exportInvoice = v),
                ),

                const SizedBox(height: 12),

                // Meal details option
                _buildExportOptionCard(
                  title: '用餐明细',
                  subtitle: '订单和发票明细表格',
                  icon: Icons.table_chart,
                  value: _exportMealDetails,
                  formatLabel: 'XLSX',
                  onToggle: (v) => setState(() => _exportMealDetails = v),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),

          // Time label option for invoice export
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: InkWell(
              onTap: _exportInvoice
                  ? () => setState(() => _showInvoiceTimeLabel = !_showInvoiceTimeLabel)
                  : null,
              borderRadius: BorderRadius.circular(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // Circular checkbox
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _exportInvoice && _showInvoiceTimeLabel
                          ? colorScheme.primary
                          : Colors.transparent,
                      border: Border.all(
                        color: _exportInvoice
                            ? (_showInvoiceTimeLabel
                                ? colorScheme.primary
                                : colorScheme.outline)
                            : colorScheme.outline.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: _exportInvoice && _showInvoiceTimeLabel
                        ? Icon(
                            Icons.check,
                            size: 14,
                            color: colorScheme.onPrimary,
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '发票中标注订单时间',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _exportInvoice
                          ? colorScheme.onSurface
                          : colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Skip empty days option for meal details export
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: InkWell(
              onTap: _exportMealDetails
                  ? () => setState(() => _skipEmptyDays = !_skipEmptyDays)
                  : null,
              borderRadius: BorderRadius.circular(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // Circular checkbox
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _exportMealDetails && _skipEmptyDays
                          ? colorScheme.primary
                          : Colors.transparent,
                      border: Border.all(
                        color: _exportMealDetails
                            ? (_skipEmptyDays
                                ? colorScheme.primary
                                : colorScheme.outline)
                            : colorScheme.outline.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: _exportMealDetails && _skipEmptyDays
                        ? Icon(
                            Icons.check,
                            size: 14,
                            color: colorScheme.onPrimary,
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '用餐明细忽略无用餐记录的日期',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _exportMealDetails
                          ? colorScheme.onSurface
                          : colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Export button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
    String formatLabel = 'XLSX',
    required ValueChanged<bool> onToggle,
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
                if (value)
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
                        formatLabel,
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

  Future<void> _handleExport() async {
    setState(() {
      _isExporting = true;
    });

    logService.i(LogConfig.moduleUi, '开始导出报销材料');

    final fileService = FileService();

    try {
      final now = DateTime.now();
      final timestamp = _formatTimestamp(now);
      final dateDir = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final subDir = 'materials/$dateDir';

      int successCount = 0;
      List<String> errors = [];

      // Get selected invoices
      final invoices = await _getSelectedInvoices();

      // Export meal proof
      if (_exportMealProof && invoices.isNotEmpty) {
        String? tempPath;
        try {
          final fileName = '用餐证明_$timestamp.pdf';

          // Prepare meal proof items
          final items = await MealProofExportService.prepareMealProofItems(
            invoices: invoices,
            getOrderIdsForInvoice: (id) =>
                ref.read(invoiceProvider.notifier).getOrderIdsForInvoice(id),
            getOrderById: (id) =>
                ref.read(orderProvider.notifier).getOrderById(id),
          );

          if (items.isEmpty) {
            errors.add('用餐证明：没有可导出的订单');
          } else {
            // Generate to temp directory first
            final tempDir = await getTemporaryDirectory();
            tempPath = '${tempDir.path}/$fileName';

            await MealProofExportService.generatePdf(
              items: items,
              outputPath: tempPath,
              getImagePath: (p) => p, // Image path is already absolute
            );

            // Copy to Download/ReceiptTamer/materials/YYYYMMDD
            final savedPath = await fileService.copyToDownloadDirectory(
              tempPath,
              customFileName: fileName,
              subDir: subDir,
            );

            if (savedPath != null) {
              successCount++;
            } else {
              errors.add('用餐证明：保存到下载目录失败');
            }
          }
        } catch (e) {
          errors.add('用餐证明导出失败: $e');
        } finally {
          // Clean up temp file
          if (tempPath != null) {
            final tempFile = File(tempPath);
            if (await tempFile.exists()) {
              await tempFile.delete();
            }
          }
        }
      }

      // Export invoice
      if (_exportInvoice && invoices.isNotEmpty) {
        String? tempPath;
        try {
          final fileName = '发票_$timestamp.pdf';

          // Prepare invoice export items
          final items = await InvoiceExportService.prepareInvoiceExportItems(
            invoices: invoices,
            getOrderIdsForInvoice: (id) =>
                ref.read(invoiceProvider.notifier).getOrderIdsForInvoice(id),
            getOrderById: (id) =>
                ref.read(orderProvider.notifier).getOrderById(id),
          );

          if (items.isEmpty) {
            errors.add('发票：没有可导出的发票');
          } else {
            // Generate to temp directory first
            final tempDir = await getTemporaryDirectory();
            tempPath = '${tempDir.path}/$fileName';

            await InvoiceExportService.generateInvoicePdf(
              items: items,
              outputPath: tempPath,
              getFilePath: (p) => p, // File path is already absolute
              showTimeLabel: _showInvoiceTimeLabel,
            );

            // Copy to Download/ReceiptTamer/materials/YYYYMMDD
            final savedPath = await fileService.copyToDownloadDirectory(
              tempPath,
              customFileName: fileName,
              subDir: subDir,
            );

            if (savedPath != null) {
              successCount++;
            } else {
              errors.add('发票：保存到下载目录失败');
            }
          }
        } catch (e) {
          errors.add('发票导出失败: $e');
        } finally {
          // Clean up temp file
          if (tempPath != null) {
            final tempFile = File(tempPath);
            if (await tempFile.exists()) {
              await tempFile.delete();
            }
          }
        }
      }

      // Export meal details
      if (_exportMealDetails && invoices.isNotEmpty) {
        String? tempPath;
        try {
          final fileName = '用餐明细_$timestamp.xlsx';

          // Prepare daily meal details
          final items = await MealDetailsExportService.prepareDailyMealDetails(
            invoices: invoices,
            getOrderIdsForInvoice: (id) =>
                ref.read(invoiceProvider.notifier).getOrderIdsForInvoice(id),
            getOrderById: (id) =>
                ref.read(orderProvider.notifier).getOrderById(id),
            fillMissingDates: !_skipEmptyDays,
          );

          if (items.isEmpty) {
            errors.add('用餐明细：没有可导出的订单');
          } else {
            // Generate to temp directory first
            final tempDir = await getTemporaryDirectory();
            tempPath = '${tempDir.path}/$fileName';

            await MealDetailsExportService.generateExcel(
              items: items,
              outputPath: tempPath,
              skipEmptyDays: _skipEmptyDays,
            );

            // Copy to Download/ReceiptTamer/materials/YYYYMMDD
            final savedPath = await fileService.copyToDownloadDirectory(
              tempPath,
              customFileName: fileName,
              subDir: subDir,
            );

            if (savedPath != null) {
              successCount++;
            } else {
              errors.add('用餐明细：保存到下载目录失败');
            }
          }
        } catch (e) {
          errors.add('用餐明细导出失败: $e');
        } finally {
          // Clean up temp file
          if (tempPath != null) {
            final tempFile = File(tempPath);
            if (await tempFile.exists()) {
              await tempFile.delete();
            }
          }
        }
      }

      if (mounted) {
        if (successCount > 0) {
          logService.i(LogConfig.moduleUi, '报销材料导出成功');
          // Navigate to saved files screen to show exported files
          Navigator.pop(context);
          await showSavedFilesScreen(context, initialSubDir: subDir);
        }
        if (errors.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errors.join('\n')),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      if (mounted) {
        logService.e(LogConfig.moduleUi, '导出失败', e, stackTrace);
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

  /// Get selected invoices from invoice IDs
  Future<List<Invoice>> _getSelectedInvoices() async {
    final invoices = <Invoice>[];
    for (final id in widget.invoiceIds) {
      final invoice = await ref.read(invoiceProvider.notifier).getInvoiceById(id);
      if (invoice != null) {
        invoices.add(invoice);
      }
    }
    return invoices;
  }

  String _formatTimestamp(DateTime dt) {
    return '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}_${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}';
  }
}
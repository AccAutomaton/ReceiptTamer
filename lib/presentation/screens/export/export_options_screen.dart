import 'dart:io';

import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/data/services/file_service.dart';
import 'package:receipt_tamer/data/services/invoice_export_service.dart';
import 'package:receipt_tamer/data/services/meal_details_export_service.dart';
import 'package:receipt_tamer/data/services/meal_proof_export_service.dart';
import 'package:receipt_tamer/core/services/log_service.dart';
import 'package:receipt_tamer/core/services/log_config.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/presentation/providers/invoice_provider.dart';
import 'package:receipt_tamer/presentation/providers/order_provider.dart';
import 'package:receipt_tamer/presentation/providers/reimbursement_provider.dart';
import 'package:receipt_tamer/presentation/screens/export/export_completion_screen.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_button.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_card.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_notice.dart';
import 'package:receipt_tamer/presentation/widgets/common/floating_overlay_layout.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_alert_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Export options screen - choose what to export
class ExportOptionsScreen extends ConsumerStatefulWidget {
  final List<int> invoiceIds;
  final List<int> orderIds;

  const ExportOptionsScreen({
    this.invoiceIds = const [],
    this.orderIds = const [],
    super.key,
  });

  @override
  ConsumerState<ExportOptionsScreen> createState() =>
      _ExportOptionsScreenState();
}

class _ExportOptionsScreenState extends ConsumerState<ExportOptionsScreen> {
  // Export type selection
  bool _exportMealProof = true;
  bool _exportInvoice = true;
  bool _exportMealDetails = true;

  // Invoice export options
  bool _showInvoiceTimeLabel = false; // Show time labels on invoices
  bool _addInvoiceRemark = false; // Whether to add remark
  String? _invoiceRemarkContent; // Remark content

  // Meal proof export options
  bool _addMealProofRemark = false; // Whether to add remark
  String? _mealProofRemarkContent; // Remark content

  // Meal details export options
  bool _skipEmptyDays = true; // Skip days without meal records

  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final reimbursement = ref.watch(reimbursementProvider);
    final effectiveInvoiceIds = widget.invoiceIds.isNotEmpty
        ? widget.invoiceIds
        : reimbursement.invoiceIds.toList(growable: false);
    final effectiveOrderIds = widget.orderIds.isNotEmpty
        ? widget.orderIds
        : reimbursement.closureOrderIds.toList(growable: false);

    return PopScope(
      canPop: !_isExporting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isExporting) {
          AppNotice.info(context, '正在生成报销材料，完成后即可返回');
        }
      },
      child: GlassPageScaffold(
        appBar: AppBar(title: const Text('导出选项'), elevation: 0),
        body: AbsorbPointer(
          absorbing: _isExporting,
          child: FloatingOverlayLayout(
            bodyBuilder: (context, contentPadding) => ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                contentPadding.bottom + 16,
              ),
              children: [
                // Summary card
                AppCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.all(16),
                  child: Padding(
                    padding: EdgeInsets.zero,
                    child: Row(
                      children: [
                        Icon(
                          Icons.description_outlined,
                          color: colorScheme.primary,
                        ),
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
                                '${effectiveInvoiceIds.length} 张发票 · ${effectiveOrderIds.length} 笔订单',
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
              ],
            ),
            bottom: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Meal proof export options group (新增)
                _buildMealProofExportOptions(context),

                // Invoice export options group (only visible when invoice export is enabled)
                _buildInvoiceExportOptions(context),

                // Meal details export options group
                _buildMealDetailsExportOptions(context),

                // Export button
                AppButton(
                  text: _isExporting ? '正在生成报销材料' : '开始导出',
                  onPressed: _canExport() ? _handleExport : null,
                  isLoading: _isExporting,
                  isFullWidth: true,
                  type: AppButtonType.primary,
                ),
              ],
            ),
          ),
        ),
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

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(12),
      backgroundColor: value
          ? AppPalette.selectedFillFor(context)
          : AppPalette.cardFillFor(context),
      borderSide: BorderSide(
        color: value
            ? AppPalette.actionPrimaryFor(context)
            : colorScheme.outlineVariant.withValues(alpha: 0.44),
        width: value ? 1.4 : 1,
      ),
      child: Padding(
        padding: EdgeInsets.zero,
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
                        ? AppPalette.selectedFillFor(context)
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: value
                        ? AppPalette.actionPrimaryFor(context)
                        : colorScheme.onSurfaceVariant,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppPalette.actionPrimaryFor(context),
                        borderRadius: BorderRadius.circular(AppRadii.chip),
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

  /// Show dialog for inputting invoice remark
  Future<void> _showInvoiceRemarkDialog() async {
    final controller = TextEditingController(text: _invoiceRemarkContent ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (context) => GlassAlertDialog(
        title: const Text('发票备注'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: '请输入备注内容',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          maxLength: 50,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // 取消不返回值
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (mounted) {
      setState(() {
        if (result != null && result.trim().isNotEmpty) {
          // 用户点击确定并输入了内容
          _addInvoiceRemark = true;
          _invoiceRemarkContent = result.trim();
        } else {
          // 用户点击取消或输入了空内容
          _addInvoiceRemark = false;
          _invoiceRemarkContent = null;
        }
      });
    }
  }

  /// Show dialog for inputting meal proof remark
  Future<void> _showMealProofRemarkDialog() async {
    final controller = TextEditingController(
      text: _mealProofRemarkContent ?? '',
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => GlassAlertDialog(
        title: const Text('用餐证明备注'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: '请输入备注内容',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          maxLength: 50,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // 取消不返回值
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (mounted) {
      setState(() {
        if (result != null && result.trim().isNotEmpty) {
          // 用户点击确定并输入了内容
          _addMealProofRemark = true;
          _mealProofRemarkContent = result.trim();
        } else {
          // 用户点击取消或输入了空内容
          _addMealProofRemark = false;
          _mealProofRemarkContent = null;
        }
      });
    }
  }

  /// Build meal proof export options group
  Widget _buildMealProofExportOptions(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (!_exportMealProof) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '用餐证明导出选项',
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          _buildMealProofRemarkOptionRow(context),
        ],
      ),
    );
  }

  /// Build meal proof remark option row (with clickable remark content)
  Widget _buildMealProofRemarkOptionRow(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      button: true,
      checked: _addMealProofRemark,
      label: '添加用餐证明备注',
      onTap: _showMealProofRemarkDialog,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () {
            // 点击时弹出对话框，由对话框决定最终勾选状态
            _showMealProofRemarkDialog();
          },
          borderRadius: BorderRadius.circular(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _addMealProofRemark
                      ? colorScheme.primary
                      : Colors.transparent,
                  border: Border.all(
                    color: _addMealProofRemark
                        ? colorScheme.primary
                        : colorScheme.outline,
                    width: 2,
                  ),
                ),
                child: _addMealProofRemark
                    ? Icon(Icons.check, size: 14, color: colorScheme.onPrimary)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                '添加备注',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              if (_addMealProofRemark && _mealProofRemarkContent != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _mealProofRemarkContent!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Build invoice export options group
  Widget _buildInvoiceExportOptions(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (!_exportInvoice) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '发票导出选项',
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          _buildInvoiceOptionRow(
            context: context,
            label: '标注订单时间',
            value: _showInvoiceTimeLabel,
            onToggle: (v) => setState(() => _showInvoiceTimeLabel = v),
          ),
          const SizedBox(height: 8),
          _buildInvoiceRemarkOptionRow(context),
        ],
      ),
    );
  }

  /// Build meal details export options group
  Widget _buildMealDetailsExportOptions(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (!_exportMealDetails) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '用餐明细导出选项',
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          _buildInvoiceOptionRow(
            context: context,
            label: '忽略无用餐记录的日期',
            value: _skipEmptyDays,
            onToggle: (v) => setState(() => _skipEmptyDays = v),
          ),
        ],
      ),
    );
  }

  /// Build single invoice option row
  Widget _buildInvoiceOptionRow({
    required BuildContext context,
    required String label,
    required bool value,
    required ValueChanged<bool> onToggle,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      button: true,
      checked: value,
      label: label,
      onTap: () => onToggle(!value),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () => onToggle(!value),
          borderRadius: BorderRadius.circular(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value ? colorScheme.primary : Colors.transparent,
                  border: Border.all(
                    color: value ? colorScheme.primary : colorScheme.outline,
                    width: 2,
                  ),
                ),
                child: value
                    ? Icon(Icons.check, size: 14, color: colorScheme.onPrimary)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build invoice remark option row (with clickable remark content)
  Widget _buildInvoiceRemarkOptionRow(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      button: true,
      checked: _addInvoiceRemark,
      label: '添加发票备注',
      onTap: _showInvoiceRemarkDialog,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () {
            // 点击时弹出对话框，由对话框决定最终勾选状态
            _showInvoiceRemarkDialog();
          },
          borderRadius: BorderRadius.circular(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _addInvoiceRemark
                      ? colorScheme.primary
                      : Colors.transparent,
                  border: Border.all(
                    color: _addInvoiceRemark
                        ? colorScheme.primary
                        : colorScheme.outline,
                    width: 2,
                  ),
                ),
                child: _addInvoiceRemark
                    ? Icon(Icons.check, size: 14, color: colorScheme.onPrimary)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                '添加备注',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              if (_addInvoiceRemark && _invoiceRemarkContent != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _invoiceRemarkContent!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleExport() async {
    if (_isExporting) return;
    final reimbursement = ref.read(reimbursementProvider);
    final snapshot = _ExportRequestSnapshot(
      invoiceIds: List<int>.unmodifiable(
        widget.invoiceIds.isNotEmpty
            ? widget.invoiceIds
            : reimbursement.invoiceIds,
      ),
      orderIds: List<int>.unmodifiable(
        widget.orderIds.isNotEmpty
            ? widget.orderIds
            : reimbursement.closureOrderIds,
      ),
      exportMealProof: _exportMealProof,
      exportInvoice: _exportInvoice,
      exportMealDetails: _exportMealDetails,
      showInvoiceTimeLabel: _showInvoiceTimeLabel,
      invoiceRemark: _addInvoiceRemark ? _invoiceRemarkContent : null,
      mealProofRemark: _addMealProofRemark ? _mealProofRemarkContent : null,
      skipEmptyDays: _skipEmptyDays,
    );
    setState(() {
      _isExporting = true;
    });

    logService.i(LogConfig.moduleUi, '开始导出报销材料');

    final fileService = FileService();
    Directory? sessionDirectory;

    try {
      final now = DateTime.now();
      final timestamp = _formatTimestamp(now);
      final dateDir =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final subDir = 'materials/$dateDir';
      final tempRoot = await getTemporaryDirectory();
      sessionDirectory = await Directory(
        '${tempRoot.path}${Platform.pathSeparator}'
        'receipt_tamer_export_${now.microsecondsSinceEpoch}',
      ).create(recursive: true);
      final invoices = await _getSelectedInvoices(snapshot.invoiceIds);
      final results = <ExportMaterialResult>[];
      for (final type in ExportMaterialType.values) {
        if (!snapshot.isSelected(type)) {
          results.add(
            ExportMaterialResult(
              type: type,
              status: ExportMaterialStatus.notSelected,
              message: '本次没有选择生成',
            ),
          );
          continue;
        }
        results.add(
          await _exportMaterial(
            type: type,
            snapshot: snapshot,
            invoices: invoices,
            fileService: fileService,
            sessionDirectory: sessionDirectory,
            subDir: subDir,
            timestamp: timestamp,
          ),
        );
      }

      if (!mounted) {
        await sessionDirectory.delete(recursive: true);
        return;
      }
      setState(() => _isExporting = false);
      logService.i(
        LogConfig.moduleUi,
        '报销材料导出完成: '
        '${results.where((item) => item.isSuccess).length}/3 项成功',
      );
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ExportCompletionScreen(
            results: results,
            subDir: subDir,
            sessionDirectory: sessionDirectory!,
            fileService: fileService,
          ),
        ),
      );
    } catch (e, stackTrace) {
      if (sessionDirectory != null && await sessionDirectory.exists()) {
        await sessionDirectory.delete(recursive: true);
      }
      if (mounted) {
        logService.e(LogConfig.moduleUi, '导出失败', e, stackTrace);
        AppNotice.error(
          context,
          '导出失败，请重试',
          duration: const Duration(seconds: 4),
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

  Future<ExportMaterialResult> _exportMaterial({
    required ExportMaterialType type,
    required _ExportRequestSnapshot snapshot,
    required List<Invoice> invoices,
    required FileService fileService,
    required Directory sessionDirectory,
    required String subDir,
    required String timestamp,
  }) async {
    final fileName = switch (type) {
      ExportMaterialType.mealProof => '用餐证明_$timestamp.pdf',
      ExportMaterialType.invoice => '发票_$timestamp.pdf',
      ExportMaterialType.mealDetails => '用餐明细_$timestamp.xlsx',
    };
    final tempPath =
        '${sessionDirectory.path}${Platform.pathSeparator}$fileName';
    ExportMaterialResult failure(String message) => ExportMaterialResult(
      type: type,
      status: ExportMaterialStatus.failure,
      message: message,
      retry: () => _exportMaterial(
        type: type,
        snapshot: snapshot,
        invoices: invoices,
        fileService: fileService,
        sessionDirectory: sessionDirectory,
        subDir: subDir,
        timestamp: timestamp,
      ),
    );
    Future<List<int>> getOrderIdsForInvoice(int invoiceId) =>
        ref.read(invoiceProvider.notifier).getOrderIdsForInvoice(invoiceId);
    Future<Order?> getOrderById(int orderId) =>
        ref.read(orderProvider.notifier).getOrderById(orderId);

    try {
      if (invoices.isEmpty) {
        return failure('没有可导出的发票');
      }
      switch (type) {
        case ExportMaterialType.mealProof:
          final items = await MealProofExportService.prepareMealProofItems(
            invoices: invoices,
            getOrderIdsForInvoice: getOrderIdsForInvoice,
            getOrderById: getOrderById,
          );
          if (items.isEmpty) return failure('没有可导出的订单');
          await MealProofExportService.generatePdf(
            items: items,
            outputPath: tempPath,
            getImagePath: (value) => value,
            remark: snapshot.mealProofRemark,
          );
        case ExportMaterialType.invoice:
          final items = await InvoiceExportService.prepareInvoiceExportItems(
            invoices: invoices,
            getOrderIdsForInvoice: getOrderIdsForInvoice,
            getOrderById: getOrderById,
            remark: snapshot.invoiceRemark,
          );
          if (items.isEmpty) return failure('没有可导出的发票');
          await InvoiceExportService.generateInvoicePdf(
            items: items,
            outputPath: tempPath,
            getFilePath: (value) => value,
            showTimeLabel: snapshot.showInvoiceTimeLabel,
            showRemark: snapshot.invoiceRemark != null,
          );
        case ExportMaterialType.mealDetails:
          final items = await MealDetailsExportService.prepareDailyMealDetails(
            invoices: invoices,
            getOrderIdsForInvoice: getOrderIdsForInvoice,
            getOrderById: getOrderById,
            fillMissingDates: !snapshot.skipEmptyDays,
          );
          if (items.isEmpty) return failure('没有可导出的订单');
          await MealDetailsExportService.generateExcel(
            items: items,
            outputPath: tempPath,
            skipEmptyDays: snapshot.skipEmptyDays,
          );
      }
      final tempFile = File(tempPath);
      if (!await tempFile.exists() || await tempFile.length() == 0) {
        return failure('生成的文件为空，请重试');
      }
      final saved = await fileService.copyToDownloadDirectoryReference(
        tempPath,
        customFileName: fileName,
        subDir: subDir,
      );
      if (saved == null) return failure('保存到下载目录失败');
      return ExportMaterialResult(
        type: type,
        status: ExportMaterialStatus.success,
        file: saved,
        previewPath: tempPath,
        message: '已保存为 ${saved.name}',
      );
    } catch (error, stackTrace) {
      logService.e(
        LogConfig.moduleFile,
        '${type.name} 导出失败',
        error,
        stackTrace,
      );
      final message = switch (error) {
        MealProofAttachmentUnavailableException() => '$error',
        InvoiceAttachmentUnavailableException() => '$error',
        _ => '导出失败，请重试',
      };
      return failure(message);
    }
  }

  /// Get selected invoices from invoice IDs
  Future<List<Invoice>> _getSelectedInvoices(List<int> invoiceIds) async {
    final invoices = <Invoice>[];
    for (final id in invoiceIds) {
      final invoice = await ref
          .read(invoiceProvider.notifier)
          .getInvoiceById(id);
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

class _ExportRequestSnapshot {
  final List<int> invoiceIds;
  final List<int> orderIds;
  final bool exportMealProof;
  final bool exportInvoice;
  final bool exportMealDetails;
  final bool showInvoiceTimeLabel;
  final String? invoiceRemark;
  final String? mealProofRemark;
  final bool skipEmptyDays;

  const _ExportRequestSnapshot({
    required this.invoiceIds,
    required this.orderIds,
    required this.exportMealProof,
    required this.exportInvoice,
    required this.exportMealDetails,
    required this.showInvoiceTimeLabel,
    required this.invoiceRemark,
    required this.mealProofRemark,
    required this.skipEmptyDays,
  });

  bool isSelected(ExportMaterialType type) => switch (type) {
    ExportMaterialType.mealProof => exportMealProof,
    ExportMaterialType.invoice => exportInvoice,
    ExportMaterialType.mealDetails => exportMealDetails,
  };
}

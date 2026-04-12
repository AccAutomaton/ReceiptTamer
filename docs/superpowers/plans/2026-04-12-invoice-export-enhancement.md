# 发票导出增强实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为发票导出功能添加超过5个订单省略显示和发票备注选项。

**Architecture:** 修改 `InvoiceExportItem` 数据结构支持备注和省略显示，在两个导出入口（报销材料导出、首页直接导出）添加备注选项UI。

**Tech Stack:** Flutter, Dart, Syncfusion PDF

---

## 文件结构

| 文件 | 修改内容 |
|------|---------|
| `lib/data/services/invoice_export_service.dart` | 添加 remark 字段、truncatedTimeLabel getter、fullLabel getter，修改 generateInvoicePdf 参数 |
| `lib/presentation/screens/export/export_options_screen.dart` | 添加发票导出选项分组UI、备注输入对话框、状态变量 |
| `lib/presentation/screens/export/invoice_quick_select_screen.dart` | 添加备注选项、备注输入对话框、状态变量 |

---

### Task 1: 修改 InvoiceExportItem 数据结构

**Files:**
- Modify: `lib/data/services/invoice_export_service.dart`

- [ ] **Step 1: 添加 remark 字段到 InvoiceExportItem**

修改 `InvoiceExportItem` 类，添加 remark 字段：

```dart
/// Invoice export item for PDF generation
/// Represents a single invoice with its associated orders
class InvoiceExportItem {
  final Invoice invoice;
  final List<Order> orders;
  final String? remark; // 新增：发票备注

  const InvoiceExportItem({
    required this.invoice,
    required this.orders,
    this.remark,
  });
```

- [ ] **Step 2: 修改 timeLabel getter 为 truncatedTimeLabel，实现省略显示逻辑**

将原有的 `timeLabel` getter 重命名为 `truncatedTimeLabel`，实现超过5个订单的省略显示。首先在 `InvoiceExportItem` 类外部添加辅助类：

```dart
/// Meal entry helper class for time label generation
class _MealEntry {
  final String date;
  final String mealTime;
  _MealEntry({required this.date, required this.mealTime});
}
```

然后在 `InvoiceExportItem` 类中实现：

```dart
  /// Generate truncated time label for the invoice
  /// Format: "yyyy年MM月dd日早/中/晚餐"
  /// Same day meals are combined with "、" (e.g., "中、晚餐")
  /// Different days are separated with "|" (e.g., "早餐|午餐")
  /// When more than 5 orders, show first 5 then "...等共计x个订单"
  String get truncatedTimeLabel {
    if (orders.isEmpty) return '';

    // Collect all meal entries with date and meal time
    final mealEntries = <_MealEntry>[];
    for (final order in orders) {
      final date = order.orderDate ?? '';
      final mealTime = order.mealTime ?? '';
      if (date.isEmpty || mealTime.isEmpty) continue;
      mealEntries.add(_MealEntry(date: date, mealTime: mealTime));
    }

    if (mealEntries.isEmpty) return '';

    // Sort by date and meal time
    mealEntries.sort((a, b) {
      final dateCompare = a.date.compareTo(b.date);
      if (dateCompare != 0) return dateCompare;
      return _mealTimeOrder(a.mealTime).compareTo(_mealTimeOrder(b.mealTime));
    });

    // Determine truncation
    final totalCount = mealEntries.length;
    final displayCount = totalCount > 5 ? 5 : totalCount;
    final displayEntries = mealEntries.take(displayCount).toList();

    // Group by date
    final Map<String, List<String>> dateMealMap = {};
    for (final entry in displayEntries) {
      dateMealMap.putIfAbsent(entry.date, () => []);
      if (!dateMealMap[entry.date]!.contains(entry.mealTime)) {
        dateMealMap[entry.date]!.add(entry.mealTime);
      }
    }

    // Sort dates
    final sortedDates = dateMealMap.keys.toList()..sort();

    // Build label parts
    final parts = <String>[];
    for (final date in sortedDates) {
      final mealTimes = dateMealMap[date]!;
      mealTimes.sort((a, b) => _mealTimeOrder(a).compareTo(_mealTimeOrder(b)));
      
      final datePart = _formatDate(date);
      final mealPart = mealTimes.map(_mealTimeDisplayName).join('、');
      parts.add('$datePart$mealPart');
    }

    // Add truncation suffix if needed
    if (totalCount > 5) {
      parts.add('...等共计${totalCount}个订单');
    }

    return parts.join('|');
  }
```

- [ ] **Step 3: 添加 fullLabel getter 组合备注和时间标签**

添加新的 getter 来组合备注和时间标签：

```dart
  /// Generate full label combining remark and time label
  /// Format: "备注内容|时间标签" or "备注内容" or "时间标签"
  String get fullLabel {
    final parts = <String>[];
    
    // Add remark if present
    if (remark != null && remark!.isNotEmpty) {
      parts.add(remark!);
    }
    
    // Add truncated time label
    final timeLabel = truncatedTimeLabel;
    if (timeLabel.isNotEmpty) {
      parts.add(timeLabel);
    }
    
    return parts.join('|');
  }

  /// Original timeLabel getter for backward compatibility
  /// Now uses truncatedTimeLabel internally
  String get timeLabel => truncatedTimeLabel;
```

- [ ] **Step 4: 修改 prepareInvoiceExportItems 添加 remark 参数**

修改方法签名和实现：

```dart
  /// Prepare invoice export items from selected invoices and their orders
  static Future<List<InvoiceExportItem>> prepareInvoiceExportItems({
    required List<Invoice> invoices,
    required Future<List<int>> Function(int) getOrderIdsForInvoice,
    required Future<Order?> Function(int) getOrderById,
    String? remark, // 新增：统一备注
  }) async {
    final items = <InvoiceExportItem>[];

    // Sort invoices by invoice date (ascending)
    final sortedInvoices = List<Invoice>.from(invoices);
    sortedInvoices.sort((a, b) {
      final dateA = a.invoiceDate ?? '';
      final dateB = b.invoiceDate ?? '';
      return dateA.compareTo(dateB);
    });

    for (final invoice in sortedInvoices) {
      if (invoice.id == null) continue;

      final orderIds = await getOrderIdsForInvoice(invoice.id!);

      // Get all orders for this invoice
      final orders = <Order>[];
      for (final orderId in orderIds) {
        final order = await getOrderById(orderId);
        if (order != null) {
          orders.add(order);
        }
      }

      items.add(InvoiceExportItem(
        invoice: invoice,
        orders: orders,
        remark: remark, // 传递备注
      ));
    }

    return items;
  }
```

- [ ] **Step 5: 修改 generateInvoicePdf 使用 fullLabel**

修改 `_drawInvoice` 方法中的标签绘制逻辑：

```dart
  /// Draw a single invoice in the specified region
  static Future<void> _drawInvoice({
    required PdfGraphics graphics,
    required InvoiceExportItem item,
    required double x,
    required double y,
    required double width,
    required double height,
    required PdfFont labelFont,
    required String Function(String) getFilePath,
    required _LabelPosition labelPosition,
    required double labelMargin,
    bool showTimeLabel = true,
    bool showRemark = true, // 新增参数
  }) async {
    final imagePath = item.invoice.imagePath;
    if (imagePath.isEmpty) return;

    try {
      final resolvedPath = getFilePath(imagePath);
      final file = File(resolvedPath);
      if (!await file.exists()) return;

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;

      // Check if it's a PDF or image
      final isPdf = imagePath.toLowerCase().endsWith('.pdf');

      if (isPdf) {
        await _drawPdfInvoice(
          graphics: graphics,
          pdfBytes: bytes,
          x: x,
          y: y,
          width: width,
          height: height,
        );
      } else {
        await _drawImageInvoice(
          graphics: graphics,
          imageBytes: bytes,
          x: x,
          y: y,
          width: width,
          height: height,
        );
      }

      // Draw label if either remark or time label is enabled
      if (showRemark || showTimeLabel) {
        final label = item.fullLabel;
        _drawTimeLabel(
          graphics: graphics,
          label: label,
          font: labelFont,
          x: x,
          y: y,
          width: width,
          height: height,
          position: labelPosition,
          margin: labelMargin,
        );
      }
    } catch (e, stackTrace) {
      // Ignore errors for individual invoices
      logService.e(LogConfig.moduleFile, '绘制发票失败', e, stackTrace);
    }
  }
```

- [ ] **Step 6: 更新 generateInvoicePdf 方法签名**

添加 showRemark 参数：

```dart
  /// Generate invoice PDF document
  static Future<void> generateInvoicePdf({
    required List<InvoiceExportItem> items,
    required String outputPath,
    required String Function(String) getFilePath,
    bool showTimeLabel = true,
    bool showRemark = true, // 新增：是否显示备注
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('Items list cannot be empty');
    }

    final document = PdfDocument();
    document.pageSettings.size = PdfPageSize.a4;
    document.pageSettings.margins.all = 0;

    final labelFont = PdfCjkStandardFont(
      PdfCjkFontFamily.heiseiKakuGothicW5,
      9,
    );

    try {
      for (var i = 0; i < items.length; i += 2) {
        final item1 = items[i];
        final item2 = i + 1 < items.length ? items[i + 1] : null;

        final page = document.pages.add();
        final graphics = page.graphics;
        final pageSize = page.getClientSize();
        final pageWidth = pageSize.width;
        final pageHeight = pageSize.height;
        final halfHeight = pageHeight / 2;
        const labelMargin = 5.0;

        await _drawInvoice(
          graphics: graphics,
          item: item1,
          x: 0,
          y: 0,
          width: pageWidth,
          height: halfHeight,
          labelFont: labelFont,
          getFilePath: getFilePath,
          labelPosition: _LabelPosition.topLeft,
          labelMargin: labelMargin,
          showTimeLabel: showTimeLabel,
          showRemark: showRemark,
        );

        if (item2 != null) {
          await _drawInvoice(
            graphics: graphics,
            item: item2,
            x: 0,
            y: halfHeight,
            width: pageWidth,
            height: halfHeight,
            labelFont: labelFont,
            getFilePath: getFilePath,
            labelPosition: _LabelPosition.bottomLeft,
            labelMargin: labelMargin,
            showTimeLabel: showTimeLabel,
            showRemark: showRemark,
          );
        }
      }

      final bytes = document.saveSync();
      document.dispose();

      final file = File(outputPath);
      await file.writeAsBytes(bytes);
    } catch (e) {
      document.dispose();
      rethrow;
    }
  }
```

- [ ] **Step 7: 提交修改**

```bash
cd "E:/Projects/Flutter Project/ReceiptTamer"
git add lib/data/services/invoice_export_service.dart
git commit -m "feat(invoice-export): InvoiceExportItem 支持备注和省略显示

- 添加 remark 字段
- 实现 truncatedTimeLabel 超过5个订单省略显示
- 添加 fullLabel 组合备注和时间标签
- generateInvoicePdf 添加 showRemark 参数

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 2: 报销材料导出添加发票导出选项分组

**Files:**
- Modify: `lib/presentation/screens/export/export_options_screen.dart`

- [ ] **Step 1: 添加备注相关状态变量**

在 `_ExportOptionsScreenState` 类中添加：

```dart
class _ExportOptionsScreenState extends ConsumerState<ExportOptionsScreen> {
  // Export type selection
  bool _exportMealProof = true;
  bool _exportInvoice = true;
  bool _exportMealDetails = true;

  // Invoice export options
  bool _showInvoiceTimeLabel = true;
  bool _addInvoiceRemark = false; // 新增：是否添加备注
  String? _invoiceRemarkContent; // 新增：备注内容

  // Meal details export options
  bool _skipEmptyDays = true;

  bool _isExporting = false;

  // ... 其他代码
}
```

- [ ] **Step 2: 实现备注输入对话框**

添加 `_showInvoiceRemarkDialog` 方法：

```dart
  /// Show dialog for inputting invoice remark
  Future<void> _showInvoiceRemarkDialog() async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final controller = TextEditingController(text: _invoiceRemarkContent ?? '');
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('发票备注'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: '请输入备注内容',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          maxLength: 50,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    
    if (result != null && mounted) {
      setState(() {
        _invoiceRemarkContent = result.trim();
        if (_invoiceRemarkContent!.isEmpty) {
          _addInvoiceRemark = false;
          _invoiceRemarkContent = null;
        }
      });
    }
    
    controller.dispose();
  }
```

- [ ] **Step 3: 添加发票导出选项分组UI组件**

添加 `_buildInvoiceExportOptions` 方法：

```dart
  /// Build invoice export options group
  Widget _buildInvoiceExportOptions(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    if (!_exportInvoice) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '发票导出选项',
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Card(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Time label option
                  _buildInvoiceOptionRow(
                    context: context,
                    label: '发票中标注订单时间',
                    value: _showInvoiceTimeLabel,
                    onToggle: () => setState(() => _showInvoiceTimeLabel = !_showInvoiceTimeLabel),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Remark option
                  _buildInvoiceRemarkOptionRow(context),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  /// Build single invoice option row
  Widget _buildInvoiceOptionRow({
    required BuildContext context,
    required String label,
    required bool value,
    required VoidCallback onToggle,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(20),
      child: Row(
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
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Build remark option row with editable content
  Widget _buildInvoiceRemarkOptionRow(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Row(
      children: [
        // Checkbox
        InkWell(
          onTap: () {
            if (!_addInvoiceRemark) {
              _showInvoiceRemarkDialog();
            } else {
              setState(() {
                _addInvoiceRemark = false;
                _invoiceRemarkContent = null;
              });
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _addInvoiceRemark ? colorScheme.primary : Colors.transparent,
              border: Border.all(
                color: _addInvoiceRemark ? colorScheme.primary : colorScheme.outline,
                width: 2,
              ),
            ),
            child: _addInvoiceRemark
                ? Icon(Icons.check, size: 14, color: colorScheme.onPrimary)
                : null,
          ),
        ),
        const SizedBox(width: 8),
        // Label and remark content
        Expanded(
          child: GestureDetector(
            onTap: _addInvoiceRemark ? _showInvoiceRemarkDialog : null,
            child: Row(
              children: [
                Text(
                  '为发票添加备注',
                  style: theme.textTheme.bodyMedium,
                ),
                if (_invoiceRemarkContent != null && _invoiceRemarkContent!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: GestureDetector(
                      onTap: _showInvoiceRemarkDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _invoiceRemarkContent!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
```

- [ ] **Step 4: 修改 build 方法添加选项分组**

在 ListView 中替换原有的单个选项，添加分组：

```dart
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
                // Summary card (保持不变)
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

                // Export options (保持不变)
                Text(
                  '选择导出内容',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),

                _buildExportOptionCard(
                  title: '用餐证明',
                  subtitle: '订单截图汇总文档',
                  icon: Icons.restaurant_menu,
                  value: _exportMealProof,
                  formatLabel: 'PDF',
                  onToggle: (v) => setState(() => _exportMealProof = v),
                ),

                const SizedBox(height: 12),

                _buildExportOptionCard(
                  title: '发票',
                  subtitle: '发票信息汇总文档',
                  icon: Icons.receipt_long,
                  value: _exportInvoice,
                  formatLabel: 'PDF',
                  onToggle: (v) => setState(() => _exportInvoice = v),
                ),

                const SizedBox(height: 12),

                _buildExportOptionCard(
                  title: '用餐明细',
                  subtitle: '订单和发票明细表格',
                  icon: Icons.table_chart,
                  value: _exportMealDetails,
                  formatLabel: 'XLSX',
                  onToggle: (v) => setState(() => _exportMealDetails = v),
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),

          // 发票导出选项分组（新增，替换原有的单个选项）
          _buildInvoiceExportOptions(context),

          // Skip empty days option for meal details (保持不变)
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
                        ? Icon(Icons.check, size: 14, color: colorScheme.onPrimary)
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

          // Export button (保持不变)
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
```

- [ ] **Step 5: 修改 _handleExport 传递备注参数**

更新发票导出部分的代码：

```dart
      // Export invoice
      if (_exportInvoice && invoices.isNotEmpty) {
        String? tempPath;
        try {
          final fileName = '发票_$timestamp.pdf';

          // Prepare invoice export items with remark
          final items = await InvoiceExportService.prepareInvoiceExportItems(
            invoices: invoices,
            getOrderIdsForInvoice: (id) =>
                ref.read(invoiceProvider.notifier).getOrderIdsForInvoice(id),
            getOrderById: (id) =>
                ref.read(orderProvider.notifier).getOrderById(id),
            remark: _addInvoiceRemark ? _invoiceRemarkContent : null, // 传递备注
          );

          if (items.isEmpty) {
            errors.add('发票：没有可导出的发票');
          } else {
            final tempDir = await getTemporaryDirectory();
            tempPath = '${tempDir.path}/$fileName';

            await InvoiceExportService.generateInvoicePdf(
              items: items,
              outputPath: tempPath,
              getFilePath: (p) => p,
              showTimeLabel: _showInvoiceTimeLabel,
              showRemark: _addInvoiceRemark, // 传递是否显示备注
            );

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
          if (tempPath != null) {
            final tempFile = File(tempPath);
            if (await tempFile.exists()) {
              await tempFile.delete();
            }
          }
        }
      }
```

- [ ] **Step 6: 提交修改**

```bash
cd "E:/Projects/Flutter Project/ReceiptTamer"
git add lib/presentation/screens/export/export_options_screen.dart
git commit -m "feat(export-options): 发票导出添加备注选项分组

- 添加发票导出选项分组UI
- 实现备注输入对话框
- 勾选备注后显示备注内容，支持点击修改
- 导出时传递备注参数

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 3: 首页直接发票导出添加备注选项

**Files:**
- Modify: `lib/presentation/screens/export/invoice_quick_select_screen.dart`

- [ ] **Step 1: 添加备注相关状态变量**

在 `_InvoiceQuickSelectScreenState` 类中添加：

```dart
class _InvoiceQuickSelectScreenState extends ConsumerState<InvoiceQuickSelectScreen> {
  Set<int> _selectedInvoiceIds = {};
  List<Invoice> _invoices = [];
  bool _isLoading = true;
  bool _isExporting = false;

  // Filter state
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchKeyword = '';
  final _searchController = TextEditingController();

  // Export options
  bool _showTimeLabel = true;
  bool _addRemark = false; // 新增：是否添加备注
  String? _remarkContent; // 新增：备注内容

  // ... 其他代码
}
```

- [ ] **Step 2: 实现备注输入对话框**

添加 `_showRemarkDialog` 方法：

```dart
  /// Show dialog for inputting invoice remark
  Future<void> _showRemarkDialog() async {
    final controller = TextEditingController(text: _remarkContent ?? '');
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('发票备注'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: '请输入备注内容',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          maxLength: 50,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    
    if (result != null && mounted) {
      setState(() {
        _remarkContent = result.trim();
        if (_remarkContent!.isEmpty) {
          _addRemark = false;
          _remarkContent = null;
        }
      });
    }
    
    controller.dispose();
  }
```

- [ ] **Step 3: 修改筛选区域添加备注选项**

修改 `_buildFilterSection` 方法：

```dart
  Widget _buildFilterSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search field (保持不变)
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索销售方名称或发票号码',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchKeyword.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _searchKeyword = '';
                        _loadInvoices();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _loadInvoices(),
          ),

          const SizedBox(height: 12),

          // Options and date filter row
          Row(
            children: [
              // Time label toggle (保持不变)
              Expanded(
                child: Checkbox(
                  value: _showTimeLabel,
                  onChanged: (value) {
                    setState(() => _showTimeLabel = value ?? true);
                  },
                ),
              ),
              Expanded(
                flex: 3,
                child: GestureDetector(
                  onTap: () => setState(() => _showTimeLabel = !_showTimeLabel),
                  child: Text(
                    '显示订单时间标签',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),

              // Date filter button
              IconButton.outlined(
                onPressed: _showDateRangePicker,
                icon: const Icon(Icons.date_range),
                tooltip: '日期筛选',
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Remark option row (新增)
          Row(
            children: [
              Checkbox(
                value: _addRemark,
                onChanged: (value) {
                  if (value == true) {
                    _showRemarkDialog();
                  } else {
                    setState(() {
                      _addRemark = false;
                      _remarkContent = null;
                    });
                  }
                },
              ),
              Expanded(
                flex: 3,
                child: GestureDetector(
                  onTap: _addRemark ? _showRemarkDialog : null,
                  child: Row(
                    children: [
                      Text(
                        '为发票添加备注',
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (_remarkContent != null && _remarkContent!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: GestureDetector(
                            onTap: _showRemarkDialog,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _remarkContent!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 4: 修改 _confirmAndExport 传递备注参数**

更新导出逻辑：

```dart
  Future<void> _confirmAndExport() async {
    if (_selectedInvoiceIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择发票')),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      final selectedInvoices = _invoices.where((i) => _selectedInvoiceIds.contains(i.id)).toList();

      // Prepare invoice export items with remark
      final items = await InvoiceExportService.prepareInvoiceExportItems(
        invoices: selectedInvoices,
        getOrderIdsForInvoice: (invoiceId) =>
            ref.read(invoiceProvider.notifier).getOrderIdsForInvoice(invoiceId),
        getOrderById: (orderId) =>
            ref.read(orderProvider.notifier).getOrderById(orderId),
        remark: _addRemark ? _remarkContent : null, // 传递备注
      );

      if (items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有可导出的发票')),
        );
        setState(() => _isExporting = false);
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormatter.formatStorageWithTime(DateTime.now());
      final tempPath = '${tempDir.path}/发票_$timestamp.pdf';

      await InvoiceExportService.generateInvoicePdf(
        items: items,
        outputPath: tempPath,
        getFilePath: (path) => path,
        showTimeLabel: _showTimeLabel,
        showRemark: _addRemark, // 传递是否显示备注
      );

      final now = DateTime.now();
      final dateDir = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final fileService = FileService();
      final savedPath = await fileService.copyToDownloadDirectory(
        tempPath,
        subDir: 'materials/$dateDir',
      );

      try {
        await File(tempPath).delete();
      } catch (_) {}

      logService.i(LogConfig.moduleFile, '发票PDF已保存: $savedPath');

      if (mounted) {
        setState(() => _isExporting = false);

        if (savedPath != null) {
          Navigator.pop(context);
          await showSavedFilesScreen(context, initialSubDir: 'materials/$dateDir');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('保存文件失败')),
          );
        }
      }
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleFile, '发票PDF导出失败', e, stackTrace);
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }
```

- [ ] **Step 5: 提交修改**

```bash
cd "E:/Projects/Flutter Project/ReceiptTamer"
git add lib/presentation/screens/export/invoice_quick_select_screen.dart
git commit -m "feat(invoice-quick-select): 添加发票备注选项

- 筛选区域添加备注选项
- 实现备注输入对话框
- 导出时传递备注参数

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 4: 验证与测试

- [ ] **Step 1: 运行应用验证功能**

```bash
cd "E:/Projects/Flutter Project/ReceiptTamer"
flutter run
```

- [ ] **Step 2: 测试报销材料导出场景**

手动测试以下场景：
1. 勾选发票后，显示"发票导出选项"分组
2. 勾选"发票中标注订单时间"选项，导出后发票显示时间标签
3. 勾选"为发票添加备注"，弹出输入对话框
4. 输入备注后，显示备注内容，点击可修改
5. 取消勾选备注，清空备注内容
6. 两者都勾选，导出后显示"备注内容|时间标签"
7. 发票关联超过5个订单，显示省略格式

- [ ] **Step 3: 测试首页直接发票导出场景**

手动测试以下场景：
1. 进入发票导出页面，显示两个选项
2. 勾选备注，弹出输入对话框，输入后显示内容
3. 点击备注内容可修改
4. 导出时正确显示备注和时间标签

- [ ] **Step 4: 最终提交**

```bash
cd "E:/Projects/Flutter Project/ReceiptTamer"
git add -A
git commit -m "feat: 发票导出增强功能完成

- 超过5个订单按餐次省略显示
- 报销材料导出和首页直接导出都支持备注选项
- 分组UI和备注输入对话框

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Spec Coverage Check

| Spec 需求 | Task |
|----------|------|
| 超过5个订单省略显示 | Task 1 Step 2 |
| truncatedTimeLabel getter | Task 1 Step 2 |
| fullLabel getter 组合备注和时间 | Task 1 Step 3 |
| remark 字段 | Task 1 Step 1 |
| generateInvoicePdf showRemark 参数 | Task 1 Step 6 |
| 报销材料导出分组UI | Task 2 Step 3 |
| 备注输入对话框 | Task 2 Step 2 |
| 勾选备注显示内容 | Task 2 Step 3 |
| 点击备注可修改 | Task 2 Step 2, 3 |
| 首页直接导出备注选项 | Task 3 Step 1, 3 |
| 首页备注对话框 | Task 3 Step 2 |
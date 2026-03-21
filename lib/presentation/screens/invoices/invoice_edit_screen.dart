import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:receipt_tamer/core/constants/app_constants.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/models/ocr_result.dart';
import 'package:receipt_tamer/data/services/file_service.dart';
import 'package:receipt_tamer/data/services/image_service.dart';
import 'package:receipt_tamer/presentation/providers/invoice_provider.dart';
import 'package:receipt_tamer/presentation/providers/ocr_provider.dart';
import 'package:receipt_tamer/presentation/screens/invoices/order_selector_screen.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_button.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_text_field.dart';
import 'package:receipt_tamer/presentation/widgets/invoice/invoice_image_preview.dart';

/// Invoice edit/add screen
class InvoiceEditScreen extends ConsumerStatefulWidget {
  final int? invoiceId; // If null, creating new invoice
  final int? initialOrderId; // Optional initial order ID

  const InvoiceEditScreen({
    super.key,
    this.invoiceId,
    this.initialOrderId,
  });

  @override
  ConsumerState<InvoiceEditScreen> createState() =>
      _InvoiceEditScreenState();
}

class _InvoiceEditScreenState extends ConsumerState<InvoiceEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceNumberController = TextEditingController();
  final _amountController = TextEditingController();
  final _sellerNameController = TextEditingController();

  DateTime? _invoiceDate;
  List<int> _selectedOrderIds = [];
  String? _filePath;
  bool _isPdf = false;
  final ImageService _imageService = ImageService();
  final FileService _fileService = FileService();

  bool _isLoading = false;
  bool _hasOcrResult = false; // 是否有OCR识别结果
  List<Map<String, dynamic>> _sellerNameOptions = []; // 销售方名称选项列表（含次数）

  @override
  void initState() {
    super.initState();
    _loadSellerNames();
    if (widget.initialOrderId != null) {
      _selectedOrderIds = [widget.initialOrderId!];
    }
    if (widget.invoiceId != null) {
      _loadInvoice();
    }
  }

  Future<void> _loadSellerNames() async {
    final sellerNamesWithCount = await ref.read(invoiceProvider.notifier).getSellerNamesWithCount();
    if (mounted) {
      setState(() {
        _sellerNameOptions = sellerNamesWithCount;
      });
    }
  }

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _amountController.dispose();
    _sellerNameController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoice() async {
    final invoice =
        await ref.read(invoiceProvider.notifier).getInvoiceById(widget.invoiceId!);
    if (invoice != null && mounted) {
      // Load order relations
      final orderIds = await ref.read(invoiceProvider.notifier).getOrderIdsForInvoice(widget.invoiceId!);
      setState(() {
        _invoiceNumberController.text = invoice.invoiceNumber;
        _amountController.text = invoice.totalAmount.toStringAsFixed(2);
        _sellerNameController.text = invoice.sellerName;
        _filePath = invoice.imagePath;
        _isPdf = invoice.imagePath.toLowerCase().endsWith('.pdf');
        _selectedOrderIds = orderIds;
        if (invoice.invoiceDate != null && invoice.invoiceDate!.isNotEmpty) {
          _invoiceDate = DateTime.tryParse(invoice.invoiceDate!);
        }
      });
    }
  }

  Future<void> _pickFile() async {
    final result = await showModalBottomSheet<_FilePickResult>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text(AppConstants.btnTakePhoto),
              onTap: () => Navigator.pop(context, _FilePickResult(ImageSource.camera, false)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text(AppConstants.btnSelectFromGallery),
              onTap: () => Navigator.pop(context, _FilePickResult(ImageSource.gallery, false)),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text(AppConstants.btnSelectPDF),
              onTap: () => Navigator.pop(context, _FilePickResult(null, true)),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      if (result.isPdf) {
        // Pick PDF file
        final pickResult = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );
        if (pickResult != null && pickResult.files.single.path != null) {
          setState(() {
            _filePath = pickResult.files.single.path;
            _isPdf = true;
          });
        }
      } else if (result.imageSource != null) {
        // Pick image
        final imageFile = result.imageSource == ImageSource.camera
            ? await _imageService.pickImageFromCamera()
            : await _imageService.pickImageFromGallery();

        if (imageFile != null) {
          setState(() {
            _filePath = imageFile.path;
            _isPdf = false;
          });
        }
      }
    }
  }

  Future<void> _handleOCR() async {
    if (_filePath == null || _filePath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择图片或PDF')),
      );
      return;
    }

    // Show progress dialog (handles both image and PDF)
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _InvoiceOcrProgressDialog(
          filePath: _filePath!,
          isPdf: _isPdf,
          onResult: (ocrResult) {
            if (ocrResult?.success == true) {
              setState(() {
                _hasOcrResult = true;
                if (ocrResult?.invoiceNumber != null &&
                    ocrResult!.invoiceNumber!.isNotEmpty) {
                  _invoiceNumberController.text = ocrResult.invoiceNumber!;
                }
                if (ocrResult?.totalAmount != null && ocrResult!.totalAmount! > 0) {
                  _amountController.text = ocrResult.totalAmount!.toStringAsFixed(2);
                }
                if (ocrResult?.invoiceDate != null && ocrResult!.invoiceDate!.isNotEmpty) {
                  _invoiceDate = DateTime.tryParse(ocrResult.invoiceDate!);
                }
                if (ocrResult?.sellerName != null && ocrResult!.sellerName!.isNotEmpty) {
                  _sellerNameController.text = ocrResult.sellerName!;
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('OCR识别成功')),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(ocrResult?.errorMessage ?? 'OCR识别失败')),
              );
            }
          },
        ),
      );
    }
  }

  void _showOrderSelector() async {
    // Build the URL with query parameters
    final selectedIdsStr = _selectedOrderIds.join(',');
    final uri = Uri(
      path: '/orders/select',
      queryParameters: {
        if (selectedIdsStr.isNotEmpty) 'selectedIds': selectedIdsStr,
        if (widget.invoiceId != null) 'excludeInvoiceId': widget.invoiceId.toString(),
      },
    );

    final result = await context.push<OrderSelectorResult>(uri.toString());

    if (result != null) {
      setState(() {
        _selectedOrderIds = result.selectedOrderIds;
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_filePath == null || _filePath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择发票图片或PDF')),
      );
      return;
    }

    // Validate required fields that are not TextFormField
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的价税合计金额')),
      );
      return;
    }

    if (_invoiceDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择开票日期')),
      );
      return;
    }

    // Check if invoice number already exists
    final invoiceNumber = _invoiceNumberController.text.trim();
    if (invoiceNumber.isNotEmpty) {
      final existingInvoice = await ref
          .read(invoiceProvider.notifier)
          .checkInvoiceNumberExists(invoiceNumber, excludeId: widget.invoiceId);
      if (existingInvoice != null && mounted) {
        final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('发票号码已存在'),
            content: Text('发票号码 "$invoiceNumber" 已存在，是否继续保存？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('继续保存'),
              ),
            ],
          ),
        );
        if (shouldContinue != true) return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Save file to app directory if not already saved
      String savedPath;
      if (_isPdf) {
        savedPath = await _fileService.savePdf(File(_filePath!));
      } else {
        savedPath = await _imageService.saveImage(File(_filePath!));
      }

      final amount = double.tryParse(_amountController.text) ?? 0.0;

      final invoice = widget.invoiceId != null
          ? Invoice(
              id: widget.invoiceId,
              imagePath: savedPath,
              invoiceNumber: _invoiceNumberController.text.trim(),
              invoiceDate: _invoiceDate?.toIso8601String(),
              totalAmount: amount,
              sellerName: _sellerNameController.text.trim(),
              createdAt: '', // Will be preserved by repository
              updatedAt: DateTime.now().toIso8601String(),
            )
          : Invoice.create(
              imagePath: savedPath,
              invoiceNumber: _invoiceNumberController.text.trim(),
              invoiceDate: _invoiceDate?.toIso8601String(),
              totalAmount: amount,
              sellerName: _sellerNameController.text.trim(),
            );

      final success = widget.invoiceId != null
          ? await ref.read(invoiceProvider.notifier).updateInvoice(invoice, orderIds: _selectedOrderIds)
          : await ref.read(invoiceProvider.notifier).createInvoice(invoice, orderIds: _selectedOrderIds);

      if (mounted) {
        if (success) {
          context.pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppConstants.successSaved)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppConstants.errorSavingData)),
          );
        }
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getOrderSelectorSubtitle() {
    if (_selectedOrderIds.isEmpty) {
      return AppConstants.labelNoOrdersSelected;
    }
    return AppConstants.labelOrdersSelected.replaceAll('{}', _selectedOrderIds.length.toString());
  }

  void _showSellerNamePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '选择销售方',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            if (_sellerNameOptions.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.store,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '还没有开过发票的销售方',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _sellerNameOptions.length,
                  itemBuilder: (context, index) {
                    final item = _sellerNameOptions[index];
                    final sellerName = item['seller_name'] as String;
                    final count = item['count'] as int;
                    return ListTile(
                      title: Text(sellerName),
                      trailing: Text(
                        '开过 $count 次',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _sellerNameController.text = sellerName;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.invoiceId != null;
    final ocrState = ref.watch(ocrProvider);
    final isModelLoading = ocrState.isModelLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? AppConstants.titleInvoiceEdit : AppConstants.titleInvoiceAdd,
        ),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // File picker section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '发票文件',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    if (_filePath != null && _filePath!.isNotEmpty)
                      InvoiceImagePreview(
                        imagePath: _filePath!,
                        height: 200,
                      )
                    else
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outlineVariant
                                .withOpacity(0.5),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_photo_alternate,
                                size: 48,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withOpacity(0.5),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '点击下方按钮选择图片或PDF',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickFile,
                            icon: const Icon(Icons.attach_file),
                            label: const Text('选择文件'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (_isLoading || isModelLoading) ? null : _handleOCR,
                            icon: _isLoading || isModelLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.document_scanner),
                            label: Text(
                              _isLoading
                                  ? '识别中...'
                                  : isModelLoading
                                      ? '模型加载中...'
                                      : 'OCR识别',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Order selector (multi-select)
            Card(
              child: ListTile(
                leading: const Icon(Icons.receipt_long),
                title: const Text(AppConstants.labelRelatedOrders),
                subtitle: Text(
                  _getOrderSelectorSubtitle(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showOrderSelector,
              ),
            ),

            const SizedBox(height: 16),

            // OCR提示
            if (_hasOcrResult)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '由于设备性能限制，识别结果可能存在错误。\n请自行核对识别结果的准确性。',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Form fields
            AppDateField(
              label: AppConstants.labelInvoiceDate,
              initialValue: _invoiceDate,
              onChanged: (date) {
                setState(() {
                  _invoiceDate = date;
                });
              },
              required: true,
            ),

            const SizedBox(height: 16),

            AppAmountField(
              label: AppConstants.labelTotalAmount,
              hint: AppConstants.hintAmount,
              controller: _amountController,
              required: true,
            ),

            const SizedBox(height: 16),

            AppTextField(
              label: AppConstants.labelSellerName,
              hint: AppConstants.hintSellerName,
              controller: _sellerNameController,
              required: false,
              keyboardType: TextInputType.text,
              prefixIcon: const Icon(Icons.store),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_drop_down),
                onPressed: _showSellerNamePicker,
                tooltip: '从历史记录选择',
              ),
            ),

            const SizedBox(height: 16),

            AppTextField(
              label: AppConstants.labelInvoiceNumber,
              hint: AppConstants.hintInvoiceNumber,
              controller: _invoiceNumberController,
              required: false,
              keyboardType: TextInputType.text,
              prefixIcon: const Icon(Icons.description),
            ),

            const SizedBox(height: 24),

            // Save button
            AppButton(
              text: AppConstants.btnSave,
              onPressed: _handleSave,
              isLoading: _isLoading,
              isFullWidth: true,
              type: AppButtonType.primary,
            ),
          ],
        ),
      ),
    );
  }
}

/// File pick result helper class
class _FilePickResult {
  final ImageSource? imageSource;
  final bool isPdf;

  _FilePickResult(this.imageSource, this.isPdf);
}

/// Invoice OCR progress dialog widget
class _InvoiceOcrProgressDialog extends ConsumerStatefulWidget {
  final String filePath;
  final bool isPdf;
  final void Function(OcrResult?) onResult;

  const _InvoiceOcrProgressDialog({
    required this.filePath,
    required this.isPdf,
    required this.onResult,
  });

  @override
  ConsumerState<_InvoiceOcrProgressDialog> createState() => _InvoiceOcrProgressDialogState();
}

class _InvoiceOcrProgressDialogState extends ConsumerState<_InvoiceOcrProgressDialog> {
  bool _started = false;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    // Start OCR after the dialog is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startOcr();
    });
  }

  Future<void> _startOcr() async {
    if (_started) return;
    _started = true;

    final OcrResult? result;
    if (widget.isPdf) {
      // PDF file: use PDF recognition
      result = await ref.read(ocrProvider.notifier).recognizeInvoiceFromPdf(widget.filePath);
    } else {
      // Image file: use image recognition
      result = await ref.read(ocrProvider.notifier).recognizeInvoiceWithProgress(widget.filePath);
    }

    if (_cancelled) return;

    if (mounted) {
      Navigator.of(context).pop();
      widget.onResult(result);
    }
  }

  void _handleCancel() {
    _cancelled = true;
    ref.read(ocrProvider.notifier).cancelRecognition();
    Navigator.of(context).pop();
    widget.onResult(null);
  }

  @override
  Widget build(BuildContext context) {
    final ocrState = ref.watch(ocrProvider);

    // Get stage text
    String stageText;
    switch (ocrState.stage) {
      case OcrStage.ocrRecognizing:
        stageText = '正在识别文本...';
        break;
      case OcrStage.llmParsing:
        stageText = '正在解析文本...';
        break;
      default:
        stageText = '准备中...';
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress indicator
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: CircularProgressIndicator(
                      value: ocrState.progress,
                      strokeWidth: 6,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  Text(
                    '${(ocrState.progress * 100).toInt()}%',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Stage text
            Text(
              stageText,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Stage indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStageChip(
                  context,
                  'OCR识别',
                  ocrState.stage == OcrStage.ocrRecognizing,
                  ocrState.progress > 0.21 || ocrState.stage == OcrStage.llmParsing,
                ),
                Container(
                  width: 24,
                  height: 2,
                  color: ocrState.progress > 0.21
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
                _buildStageChip(
                  context,
                  'LLM解析',
                  ocrState.stage == OcrStage.llmParsing,
                  ocrState.progress >= 1.0,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _handleCancel,
          child: const Text('取消'),
        ),
      ],
    );
  }

  Widget _buildStageChip(BuildContext context, String label, bool isActive, bool isCompleted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? Theme.of(context).colorScheme.primaryContainer
            : isCompleted
                ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isActive
              ? Theme.of(context).colorScheme.onPrimaryContainer
              : Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
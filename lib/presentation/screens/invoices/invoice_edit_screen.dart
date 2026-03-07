import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:catering_receipt_recorder/core/constants/app_constants.dart';
import 'package:catering_receipt_recorder/core/utils/date_formatter.dart';
import 'package:catering_receipt_recorder/data/models/invoice.dart';
import 'package:catering_receipt_recorder/data/models/order.dart';
import 'package:catering_receipt_recorder/data/models/ocr_result.dart';
import 'package:catering_receipt_recorder/data/services/image_service.dart';
import 'package:catering_receipt_recorder/presentation/providers/invoice_provider.dart';
import 'package:catering_receipt_recorder/presentation/providers/order_provider.dart';
import 'package:catering_receipt_recorder/presentation/providers/ocr_provider.dart';
import 'package:catering_receipt_recorder/presentation/widgets/common/app_button.dart';
import 'package:catering_receipt_recorder/presentation/widgets/common/app_text_field.dart';
import 'package:catering_receipt_recorder/presentation/widgets/invoice/invoice_image_preview.dart';

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

  DateTime? _invoiceDate;
  int? _orderId;
  String? _imagePath;
  final ImageService _imageService = ImageService();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _orderId = widget.initialOrderId;
    if (widget.invoiceId != null) {
      _loadInvoice();
    }
  }

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoice() async {
    final invoice =
        await ref.read(invoiceProvider.notifier).getInvoiceById(widget.invoiceId!);
    if (invoice != null && mounted) {
      setState(() {
        _invoiceNumberController.text = invoice.invoiceNumber;
        _amountController.text = invoice.totalAmount.toStringAsFixed(2);
        _imagePath = invoice.imagePath;
        _orderId = invoice.orderId;
        if (invoice.invoiceDate != null && invoice.invoiceDate!.isNotEmpty) {
          _invoiceDate = DateTime.tryParse(invoice.invoiceDate!);
        }
      });
    }
  }

  Future<void> _pickImage() async {
    final result = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text(AppConstants.btnTakePhoto),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text(AppConstants.btnSelectFromGallery),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final imageFile = result == ImageSource.camera
          ? await _imageService.pickImageFromCamera()
          : await _imageService.pickImageFromGallery();

      if (imageFile != null) {
        setState(() {
          _imagePath = imageFile.path;
        });
      }
    }
  }

  Future<void> _handleOCR() async {
    if (_imagePath == null || _imagePath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择图片')),
      );
      return;
    }

    // Show progress dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _InvoiceOcrProgressDialog(
          imagePath: _imagePath!,
          onResult: (ocrResult) {
            if (ocrResult?.success == true) {
              setState(() {
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
    final orders = await ref.read(orderProvider.notifier).getAll();

    if (!mounted) return;

    final selected = await showDialog<Order>(
      context: context,
      builder: (context) => _OrderSelectorDialog(orders: orders),
    );

    if (selected != null) {
      setState(() {
        _orderId = selected.id;
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_imagePath == null || _imagePath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择发票图片')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Save image to app directory if not already saved
      final savedImagePath = await _imageService.saveImage(File(_imagePath!));

      final amount = double.tryParse(_amountController.text) ?? 0.0;

      final invoice = widget.invoiceId != null
          ? Invoice(
              id: widget.invoiceId,
              imagePath: savedImagePath,
              orderId: _orderId,
              invoiceNumber: _invoiceNumberController.text.trim(),
              invoiceDate: _invoiceDate?.toIso8601String(),
              totalAmount: amount,
              createdAt: '', // Will be preserved by repository
              updatedAt: DateTime.now().toIso8601String(),
            )
          : Invoice.create(
              imagePath: savedImagePath,
              orderId: _orderId,
              invoiceNumber: _invoiceNumberController.text.trim(),
              invoiceDate: _invoiceDate?.toIso8601String(),
              totalAmount: amount,
            );

      final success = widget.invoiceId != null
          ? await ref.read(invoiceProvider.notifier).updateInvoice(invoice)
          : await ref.read(invoiceProvider.notifier).createInvoice(invoice);

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

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.invoiceId != null;
    final order = _orderId != null
        ? ref.watch(orderByIdProvider(_orderId!)).value
        : null;
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
            // Image picker section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '发票图片',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    if (_imagePath != null && _imagePath!.isNotEmpty)
                      InvoiceImagePreview(
                        imagePath: _imagePath!,
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
                                '点击下方按钮选择图片',
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
                            onPressed: _pickImage,
                            icon: const Icon(Icons.image),
                            label: const Text('选择图片'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _handleOCR,
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

            // Order selector
            Card(
              child: ListTile(
                leading: const Icon(Icons.receipt_long),
                title: const Text(AppConstants.labelRelatedOrder),
                subtitle: order != null
                    ? Text(order.shopName.isEmpty ? '未命名店铺' : order.shopName)
                    : Text(
                        _orderId != null ? '加载中...' : AppConstants.labelNoOrder,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showOrderSelector,
              ),
            ),

            const SizedBox(height: 16),

            // Form fields
            AppTextField(
              label: AppConstants.labelInvoiceNumber,
              hint: AppConstants.hintInvoiceNumber,
              controller: _invoiceNumberController,
              required: false,
              keyboardType: TextInputType.text,
              prefixIcon: const Icon(Icons.description),
            ),

            const SizedBox(height: 16),

            AppAmountField(
              label: AppConstants.labelTotalAmount,
              hint: AppConstants.hintAmount,
              controller: _amountController,
              required: false,
            ),

            const SizedBox(height: 16),

            AppDateField(
              label: AppConstants.labelInvoiceDate,
              initialValue: _invoiceDate,
              onChanged: (date) {
                setState(() {
                  _invoiceDate = date;
                });
              },
              required: false,
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

/// Order selector dialog
class _OrderSelectorDialog extends StatelessWidget {
  final List<Order> orders;

  const _OrderSelectorDialog({required this.orders});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择关联订单'),
      content: SizedBox(
        width: double.maxFinite,
        child: orders.isEmpty
            ? const Center(
                child: Text('暂无订单'),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return ListTile(
                    leading: const Icon(Icons.receipt_long),
                    title: Text(order.shopName.isEmpty
                        ? '未命名店铺'
                        : order.shopName),
                    subtitle: Text(
                      DateFormatter.formatAmount(order.amount),
                    ),
                    onTap: () => Navigator.pop(context, order),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(AppConstants.btnCancel),
        ),
      ],
    );
  }
}

/// Invoice OCR progress dialog widget
class _InvoiceOcrProgressDialog extends ConsumerStatefulWidget {
  final String imagePath;
  final void Function(OcrResult?) onResult;

  const _InvoiceOcrProgressDialog({
    required this.imagePath,
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

    final result = await ref.read(ocrProvider.notifier).recognizeInvoiceWithProgress(widget.imagePath);

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

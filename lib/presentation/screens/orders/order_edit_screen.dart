import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:catering_receipt_recorder/core/constants/app_constants.dart';
import 'package:catering_receipt_recorder/core/utils/date_formatter.dart';
import 'package:catering_receipt_recorder/data/models/order.dart';
import 'package:catering_receipt_recorder/data/models/ocr_result.dart';
import 'package:catering_receipt_recorder/data/services/image_service.dart';
import 'package:catering_receipt_recorder/presentation/providers/order_provider.dart';
import 'package:catering_receipt_recorder/presentation/providers/ocr_provider.dart';
import 'package:catering_receipt_recorder/presentation/widgets/common/app_button.dart';
import 'package:catering_receipt_recorder/presentation/widgets/common/app_text_field.dart';
import 'package:catering_receipt_recorder/presentation/widgets/order/order_image_preview.dart';

/// Order edit/add screen
class OrderEditScreen extends ConsumerStatefulWidget {
  final int? orderId; // If null, creating new order
  final String? initialImagePath; // Optional initial image path

  const OrderEditScreen({
    super.key,
    this.orderId,
    this.initialImagePath,
  });

  @override
  ConsumerState<OrderEditScreen> createState() => _OrderEditScreenState();
}

class _OrderEditScreenState extends ConsumerState<OrderEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _orderNumberController = TextEditingController();

  DateTime? _orderDate;
  MealTime? _mealTime;
  String? _imagePath;
  final ImageService _imageService = ImageService();

  bool _isLoading = false;
  bool _hasOcrResult = false; // 是否有OCR识别结果

  @override
  void initState() {
    super.initState();
    _imagePath = widget.initialImagePath;
    if (widget.orderId != null) {
      _loadOrder();
    }
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _amountController.dispose();
    _orderNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadOrder() async {
    final order = await ref.read(orderProvider.notifier).getOrderById(widget.orderId!);
    if (order != null && mounted) {
      setState(() {
        _shopNameController.text = order.shopName;
        _amountController.text = order.amount.toStringAsFixed(2);
        _orderNumberController.text = order.orderNumber;
        _imagePath = order.imagePath;
        if (order.orderDate != null && order.orderDate!.isNotEmpty) {
          _orderDate = DateTime.tryParse(order.orderDate!);
        }
        _mealTime = DateFormatter.mealTimeFromString(order.mealTime);
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
        builder: (context) => _OcrProgressDialog(
          imagePath: _imagePath!,
          onResult: (ocrResult) {
            if (ocrResult?.success == true) {
              setState(() {
                _hasOcrResult = true;
                if (ocrResult?.shopName != null && ocrResult!.shopName!.isNotEmpty) {
                  _shopNameController.text = ocrResult.shopName!;
                }
                if (ocrResult?.amount != null && ocrResult!.amount! > 0) {
                  _amountController.text = ocrResult.amount!.toStringAsFixed(2);
                }
                if (ocrResult?.orderNumber != null && ocrResult!.orderNumber!.isNotEmpty) {
                  _orderNumberController.text = ocrResult.orderNumber!;
                }
                // Parse orderTime from OCR result into orderDate and mealTime
                if (ocrResult?.orderTime != null && ocrResult!.orderTime!.isNotEmpty) {
                  final (dateStr, mealTime) = DateFormatter.parseDateTimeToOrderDateAndMealTime(ocrResult.orderTime);
                  if (dateStr != null) {
                    _orderDate = DateTime.tryParse(dateStr);
                  }
                  _mealTime = mealTime;
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

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_imagePath == null || _imagePath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择订单图片')),
      );
      return;
    }

    // Validate required fields that are not TextFormField
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的实付金额')),
      );
      return;
    }

    if (_orderDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择订单日期')),
      );
      return;
    }

    if (_mealTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择用餐时段')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Save image to app directory if not already saved
      final savedImagePath = await _imageService.saveImage(File(_imagePath!));

      final orderDateStr = DateFormatter.formatStorage(_orderDate!);
      final mealTimeStr = _mealTime!.name;

      final order = widget.orderId != null
          ? Order(
              id: widget.orderId,
              imagePath: savedImagePath,
              shopName: _shopNameController.text.trim(),
              amount: amount,
              orderDate: orderDateStr,
              mealTime: mealTimeStr,
              orderNumber: _orderNumberController.text.trim(),
              createdAt: '', // Will be preserved by repository
              updatedAt: DateTime.now().toIso8601String(),
            )
          : Order.create(
              imagePath: savedImagePath,
              shopName: _shopNameController.text.trim(),
              amount: amount,
              orderDate: orderDateStr,
              mealTime: mealTimeStr,
              orderNumber: _orderNumberController.text.trim(),
            );

      final success = widget.orderId != null
          ? await ref.read(orderProvider.notifier).updateOrder(order)
          : await ref.read(orderProvider.notifier).createOrder(order);

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
    final isEditing = widget.orderId != null;
    final ocrState = ref.watch(ocrProvider);
    final isModelLoading = ocrState.isModelLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? AppConstants.titleOrderEdit : AppConstants.titleOrderAdd,
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
                      '订单图片',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_imagePath != null && _imagePath!.isNotEmpty)
                      OrderImagePreview(
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

            // Form fields - 按日期、时段、金额、店铺名称、订单号顺序排列
            AppDateField(
              label: AppConstants.labelOrderDate,
              initialValue: _orderDate,
              onChanged: (date) {
                setState(() {
                  _orderDate = date;
                });
              },
              required: true,
            ),

            const SizedBox(height: 16),

            AppSelectField<MealTime>(
              label: AppConstants.labelMealTime,
              value: _mealTime,
              options: MealTime.values,
              displayValue: (mealTime) => DateFormatter.mealTimeToDisplayName(mealTime),
              onChanged: (value) {
                setState(() {
                  _mealTime = value;
                });
              },
              required: true,
            ),

            const SizedBox(height: 16),

            AppAmountField(
              label: AppConstants.labelAmount,
              hint: AppConstants.hintAmount,
              controller: _amountController,
              required: true,
            ),

            const SizedBox(height: 16),

            AppTextField(
              label: AppConstants.labelShopName,
              hint: AppConstants.hintShopName,
              controller: _shopNameController,
              required: false,
              keyboardType: TextInputType.text,
              prefixIcon: const Icon(Icons.store),
            ),

            const SizedBox(height: 16),

            AppTextField(
              label: AppConstants.labelOrderNumber,
              hint: AppConstants.hintOrderNumber,
              controller: _orderNumberController,
              required: false,
              keyboardType: TextInputType.text,
              prefixIcon: const Icon(Icons.receipt),
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

/// OCR progress dialog widget
class _OcrProgressDialog extends ConsumerStatefulWidget {
  final String imagePath;
  final void Function(OcrResult?) onResult;

  const _OcrProgressDialog({
    required this.imagePath,
    required this.onResult,
  });

  @override
  ConsumerState<_OcrProgressDialog> createState() => _OcrProgressDialogState();
}

class _OcrProgressDialogState extends ConsumerState<_OcrProgressDialog> {
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

    final result = await ref.read(ocrProvider.notifier).recognizeOrderWithProgress(widget.imagePath);

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

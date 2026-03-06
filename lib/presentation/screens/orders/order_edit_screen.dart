import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:catering_receipt_recorder/core/constants/app_constants.dart';
import 'package:catering_receipt_recorder/core/utils/date_formatter.dart';
import 'package:catering_receipt_recorder/data/models/order.dart';
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

  DateTime? _orderTime;
  String? _imagePath;
  final ImageService _imageService = ImageService();

  bool _isLoading = false;

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
        if (order.orderTime != null && order.orderTime!.isNotEmpty) {
          _orderTime = DateTime.tryParse(order.orderTime!);
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

    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(ocrProvider.notifier).recognizeOrder(_imagePath!);
      final ocrResult = ref.read(ocrProvider).result;

      if (ocrResult?.success == true) {
        setState(() {
          if (ocrResult?.shopName != null && ocrResult!.shopName!.isNotEmpty) {
            _shopNameController.text = ocrResult!.shopName!;
          }
          if (ocrResult?.amount != null && ocrResult!.amount! > 0) {
            _amountController.text = ocrResult!.amount!.toStringAsFixed(2);
          }
          if (ocrResult?.orderNumber != null && ocrResult!.orderNumber!.isNotEmpty) {
            _orderNumberController.text = ocrResult!.orderNumber!;
          }
          if (ocrResult?.orderTime != null && ocrResult!.orderTime!.isNotEmpty) {
            _orderTime = DateTime.tryParse(ocrResult!.orderTime!);
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('OCR识别成功')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ocrResult?.errorMessage ?? 'OCR识别失败')),
          );
        }
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
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

    setState(() {
      _isLoading = true;
    });

    try {
      // Save image to app directory if not already saved
      final savedImagePath = await _imageService.saveImage(File(_imagePath!));

      final amount = double.tryParse(_amountController.text) ?? 0.0;

      final order = widget.orderId != null
          ? Order(
              id: widget.orderId,
              imagePath: savedImagePath,
              shopName: _shopNameController.text.trim(),
              amount: amount,
              orderTime: _orderTime?.toIso8601String(),
              orderNumber: _orderNumberController.text.trim(),
              createdAt: '', // Will be preserved by repository
              updatedAt: DateTime.now().toIso8601String(),
            )
          : Order.create(
              imagePath: savedImagePath,
              shopName: _shopNameController.text.trim(),
              amount: amount,
              orderTime: _orderTime?.toIso8601String(),
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

            // Form fields
            AppTextField(
              label: AppConstants.labelShopName,
              hint: AppConstants.hintShopName,
              controller: _shopNameController,
              required: false,
              keyboardType: TextInputType.text,
              prefixIcon: const Icon(Icons.store),
            ),

            const SizedBox(height: 16),

            AppAmountField(
              label: AppConstants.labelAmount,
              hint: AppConstants.hintAmount,
              controller: _amountController,
              required: false,
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

            const SizedBox(height: 16),

            AppDateField(
              label: AppConstants.labelOrderTime,
              initialValue: _orderTime,
              onChanged: (date) {
                setState(() {
                  _orderTime = date;
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

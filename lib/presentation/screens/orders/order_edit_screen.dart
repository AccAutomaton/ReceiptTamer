import 'dart:io';

import 'package:flutter/material.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_alert_dialog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:receipt_tamer/core/constants/app_constants.dart';
import 'package:receipt_tamer/core/services/log_service.dart';
import 'package:receipt_tamer/core/services/log_config.dart';
import 'package:receipt_tamer/core/utils/date_formatter.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/data/models/llm_backend.dart';
import 'package:receipt_tamer/data/models/ocr_result.dart';
import 'package:receipt_tamer/data/services/duplicate_detection_service.dart';
import 'package:receipt_tamer/data/services/llm_config_service.dart';
import 'package:receipt_tamer/data/services/file_service.dart';
import 'package:receipt_tamer/data/services/image_service.dart';
import 'package:receipt_tamer/data/services/share_handler_service.dart';
import 'package:receipt_tamer/presentation/providers/order_provider.dart';
import 'package:receipt_tamer/presentation/providers/ocr_provider.dart';
import 'package:receipt_tamer/presentation/providers/invoice_provider.dart';
import 'package:receipt_tamer/presentation/utils/ai_use_disclosure.dart';
import 'package:receipt_tamer/presentation/utils/share_import_actions.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_notice.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_button.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_text_field.dart';
import 'package:receipt_tamer/presentation/widgets/common/duplicate_warning_dialog.dart';
import 'package:receipt_tamer/presentation/widgets/common/scroll_edge_fog.dart';
import 'package:receipt_tamer/presentation/widgets/order/order_image_preview.dart';

/// Order edit/add screen
class OrderEditScreen extends ConsumerStatefulWidget {
  final int? orderId; // If null, creating new order
  final String? initialImagePath; // Optional initial image path
  final int remainingSharedCount; // Remaining shared files to process

  const OrderEditScreen({
    super.key,
    this.orderId,
    this.initialImagePath,
    this.remainingSharedCount = 0,
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
  final FileService _fileService = FileService();
  final DuplicateDetectionService _duplicateDetectionService =
      DuplicateDetectionService();

  Order? _loadedOrder;
  bool _isLoading = false;
  bool _saveInProgress = false;
  bool _hasOcrResult = false; // 是否有 OCR 识别结果
  List<Map<String, dynamic>> _shopNameOptions = []; // 店铺名称选项列表（含次数）

  @override
  void initState() {
    super.initState();
    _imagePath = widget.initialImagePath;
    _loadShopNames();
    if (widget.orderId != null) {
      _loadOrder();
    }
  }

  @override
  void didUpdateWidget(OrderEditScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当导航到新的订单时（例如继续添加下一个），重置所有状态
    if (oldWidget.initialImagePath != widget.initialImagePath ||
        oldWidget.orderId != widget.orderId) {
      _resetState();
    }
  }

  void _resetState() {
    // 清空输入框
    _shopNameController.clear();
    _amountController.clear();
    _orderNumberController.clear();

    // 重置状态
    setState(() {
      _loadedOrder = null;
      _orderDate = null;
      _mealTime = null;
      _imagePath = widget.initialImagePath;
      _hasOcrResult = false;
    });

    // 如果是编辑模式，加载数据
    if (widget.orderId != null) {
      _loadOrder();
    }
  }

  Future<void> _loadShopNames() async {
    final shopNamesWithCount = await ref
        .read(orderProvider.notifier)
        .getShopNamesWithCount();
    if (mounted) {
      setState(() {
        _shopNameOptions = shopNamesWithCount;
      });
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
    try {
      final order = await ref
          .read(orderProvider.notifier)
          .getOrderById(widget.orderId!);
      if (order != null && mounted) {
        setState(() {
          _loadedOrder = order;
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
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleUi, '加载订单失败', e, stackTrace);
    }
  }

  Future<void> _pickImage() async {
    ImageSource? source;
    try {
      source = await showGlassContentBottomSheet<ImageSource>(
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

      if (!mounted || source == null) return;
      final imageFile = source == ImageSource.camera
          ? await _imageService.pickImageFromCamera()
          : await _imageService.pickImageFromGallery();

      if (imageFile != null && mounted) {
        setState(() {
          _imagePath = imageFile.path;
        });
      }
    } on PlatformException catch (e, stackTrace) {
      logService.e(LogConfig.moduleUi, '选择订单图片失败', e, stackTrace);
      if (mounted) {
        final isCamera = source == ImageSource.camera;
        final isPermissionError =
            e.code.contains('denied') ||
            e.code.contains('restricted') ||
            e.code.contains('permission');
        AppNotice.error(
          context,
          isPermissionError
              ? isCamera
                    ? '无法访问相机，请在系统设置中允许相机权限'
                    : '无法访问相册，请在系统设置中允许照片权限'
              : '选择图片失败，请重试',
        );
      }
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleUi, '选择订单图片失败', e, stackTrace);
      if (mounted) {
        AppNotice.error(context, '选择图片失败，请重试');
      }
    }
  }

  Future<void> _handleOCR() async {
    if (_imagePath == null || _imagePath!.isEmpty) {
      AppNotice.warning(context, '请先选择图片');
      return;
    }

    logService.i(LogConfig.moduleUi, '开始订单 OCR 识别');

    final backendConfig = await _ensureAiBackendConfigured();
    if (backendConfig == null || !mounted) return;

    final uploadAllowed = await confirmCloudUploadIfNeeded(
      context,
      config: backendConfig,
      content: backendConfig.cloud.isMultimodal
          ? CloudUploadContent.orderImage
          : CloudUploadContent.orderText,
    );
    if (!uploadAllowed || !mounted) return;

    // Show progress dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: _OcrProgressDialog(
            imagePath: _imagePath!,
            onResult: (ocrResult) {
              if (ocrResult?.success == true) {
                setState(() {
                  _hasOcrResult = true;
                  if (ocrResult?.shopName != null &&
                      ocrResult!.shopName!.isNotEmpty) {
                    _shopNameController.text = ocrResult.shopName!;
                  }
                  if (ocrResult?.amount != null && ocrResult!.amount! > 0) {
                    _amountController.text = ocrResult.amount!.toStringAsFixed(
                      2,
                    );
                  }
                  if (ocrResult?.orderNumber != null &&
                      ocrResult!.orderNumber!.isNotEmpty) {
                    _orderNumberController.text = ocrResult.orderNumber!;
                  }
                  // Parse orderTime from OCR result into orderDate and mealTime
                  if (ocrResult?.orderTime != null &&
                      ocrResult!.orderTime!.isNotEmpty) {
                    final (
                      dateStr,
                      mealTime,
                    ) = DateFormatter.parseDateTimeToOrderDateAndMealTime(
                      ocrResult.orderTime,
                    );
                    if (dateStr != null) {
                      _orderDate = DateTime.tryParse(dateStr);
                    }
                    _mealTime = mealTime;
                  }
                });
                logService.i(LogConfig.moduleUi, '订单 OCR 识别成功');
                AppNotice.success(context, 'OCR 识别成功');
              } else {
                AppNotice.error(context, ocrResult?.errorMessage ?? 'OCR 识别失败');
              }
            },
          ),
        ),
      );
    }
  }

  Future<LlmBackendConfig?> _ensureAiBackendConfigured() async {
    final config = await LlmConfigService().load();
    if (config.backendType != LlmBackendType.unset) return config;
    if (!mounted) return null;

    final choice = await showAiAnalysisChoiceDialog(context);
    if (!mounted || choice == null) return null;
    if (choice == AiAnalysisChoice.manual) {
      if (mounted) {
        AppNotice.info(context, '已选择手工录入，可直接填写并保存');
      }
      return null;
    }

    await context.push('/settings/model-management');
    if (!mounted) return null;
    final updatedConfig = await LlmConfigService().load();
    return updatedConfig.backendType == LlmBackendType.unset
        ? null
        : updatedConfig;
  }

  void _showShopNamePicker() {
    showGlassContentBottomSheet(
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
                '选择店铺',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            if (_shopNameOptions.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.restaurant_menu,
                      size: 48,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '还没有吃过的店铺',
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
                  itemCount: _shopNameOptions.length,
                  itemBuilder: (context, index) {
                    final item = _shopNameOptions[index];
                    final shopName = item['shop_name'] as String;
                    final count = item['count'] as int;
                    return ListTile(
                      title: Text(shopName),
                      trailing: Text(
                        '吃过 $count 次',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _shopNameController.text = shopName;
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

  void _showContinueDialog() {
    final service = ShareHandlerService();
    final items = service.pendingSharedMedia
        ?.where((item) => item.isImage)
        .toList(growable: false);

    if (items == null || items.isEmpty) {
      context.go(service.hasPendingSharedMedia ? '/share' : '/');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => GlassAlertDialog(
        title: const Text('继续添加'),
        content: Text('还有 ${items.length} 个待处理的图片。\n\n是否继续添加下一个订单？'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final abandon = await confirmAbandonSharedImport(
                context,
                pendingCount:
                    service.pendingSharedMedia?.length ?? items.length,
              );
              if (!abandon || !mounted) return;
              service.clearPendingSharedMedia();
              context.go('/');
            },
            child: const Text('放弃全部'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.go('/');
            },
            child: const Text('稍后处理'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              // 获取下一个待处理的图片
              final nextItem = items.first;
              final remainingItems = items.skip(1).toList();

              // 导航到下一个订单编辑页面
              context.go(
                '/orders/new?sharedPath=${Uri.encodeComponent(nextItem.path)}&remainingCount=${remainingItems.length}',
              );
            },
            child: const Text('继续添加'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSave() async {
    if (_saveInProgress) return;
    _saveInProgress = true;
    try {
      if (!_formKey.currentState!.validate()) return;

      if (_imagePath == null || _imagePath!.isEmpty) {
        AppNotice.warning(context, '请选择订单图片');
        return;
      }

      final amount = double.tryParse(_amountController.text) ?? 0.0;
      if (amount <= 0) {
        AppNotice.warning(context, '请输入有效的实付金额');
        return;
      }

      if (_orderDate == null) {
        AppNotice.warning(context, '请选择订单日期');
        return;
      }

      if (_mealTime == null) {
        AppNotice.warning(context, '请选择用餐时段');
        return;
      }

      setState(() {
        _isLoading = true;
      });

      final duplicateReport = await _duplicateDetectionService.checkOrder(
        attachmentPath: _imagePath!,
        merchant: _shopNameController.text,
        orderNumber: _orderNumberController.text,
        orderDate: DateFormatter.formatStorage(_orderDate!),
        amount: amount,
        existingOrders: await ref.read(orderProvider.notifier).getAll(),
        existingInvoices: await ref.read(invoiceProvider.notifier).getAll(),
        excludeOrderId: widget.orderId,
      );
      if (!mounted) return;
      if (duplicateReport.hasMatches) {
        final shouldSave = await showDuplicateWarningDialog(
          context,
          report: duplicateReport,
          onOpenRecord: _openDuplicateRecord,
        );
        if (!shouldSave || !mounted) return;
      }

      final existingOrder = widget.orderId == null
          ? null
          : _loadedOrder ??
                await ref
                    .read(orderProvider.notifier)
                    .getOrderById(widget.orderId!);
      if (widget.orderId != null && existingOrder == null) {
        if (mounted) {
          AppNotice.error(context, '订单已不存在，请返回后刷新');
        }
        return;
      }

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
              createdAt: existingOrder!.createdAt,
              updatedAt: DateTime.now().toIso8601String(),
              hasInvoice: existingOrder.hasInvoice,
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
          logService.i(
            LogConfig.moduleUi,
            '订单保存成功: id=${widget.orderId ?? order.id}',
          );
          // Clean up temp file after successful save
          if (_imagePath != null) {
            _fileService.deleteTempFile(_imagePath!);
          }

          AppNotice.success(context, AppConstants.successSaved);

          // 判断是否从分享进入
          final isFromShare = widget.initialImagePath != null;

          if (isFromShare) {
            final shareService = ShareHandlerService();
            shareService.completePendingSharedMedia(widget.initialImagePath!);
            final hasMoreImages =
                shareService.pendingSharedMedia?.any((item) => item.isImage) ==
                true;
            if (hasMoreImages) {
              // 还有待处理的图片，显示继续对话框
              _showContinueDialog();
            } else if (shareService.hasPendingSharedMedia) {
              // 仍有 PDF 等非订单附件，回到类型选择页继续处理。
              context.go('/share');
            } else {
              // 已完成全部分享导入。
              context.go('/');
            }
          } else {
            // 不是从分享进入，正常返回上一级
            context.pop(true);
          }
        } else {
          AppNotice.error(context, AppConstants.errorSavingData);
        }
      }
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleUi, '保存订单失败', e, stackTrace);
      if (mounted) {
        AppNotice.error(context, AppConstants.errorSavingData);
      }
    } finally {
      _saveInProgress = false;
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openDuplicateRecord(DuplicateRecordSnapshot record) {
    final id = record.id;
    if (id == null) return;
    final route = record.type == DuplicateRecordType.order
        ? '/orders/$id'
        : '/invoices/$id';
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.orderId != null;
    final ocrState = ref.watch(ocrProvider);
    final isModelLoading = ocrState.isModelLoading;
    final isRecognizing = ocrState.isLoading;
    final isOcrButtonBusy = isRecognizing || isModelLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? AppConstants.titleOrderEdit : AppConstants.titleOrderAdd,
        ),
        elevation: 0,
      ),
      body: ScrollEdgeFog(
        showBottom: false,
        child: Form(
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
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      if (_imagePath != null && _imagePath!.isNotEmpty)
                        OrderImagePreview(imagePath: _imagePath!, height: 200)
                      else
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant
                                  .withValues(alpha: 0.5),
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
                                      .withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '点击下方按钮选择图片',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
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
                              onPressed: (_isLoading || isOcrButtonBusy)
                                  ? null
                                  : _handleOCR,
                              icon: isOcrButtonBusy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.document_scanner),
                              label: Text(
                                isRecognizing
                                    ? 'OCR 识别中...'
                                    : isModelLoading
                                    ? '模型加载中...'
                                    : AppConstants.btnOCR,
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
                          '识别结果可能存在错误，请自行核对识别结果的准确性。',
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
                displayValue: (mealTime) =>
                    DateFormatter.mealTimeToDisplayName(mealTime),
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
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_drop_down),
                  onPressed: _showShopNamePicker,
                  tooltip: '从历史记录选择',
                ),
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
      ),
    );
  }
}

/// OCR progress dialog widget
class _OcrProgressDialog extends ConsumerStatefulWidget {
  final String imagePath;
  final void Function(OcrResult?) onResult;

  const _OcrProgressDialog({required this.imagePath, required this.onResult});

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

    final result = await ref
        .read(ocrProvider.notifier)
        .recognizeOrderWithProgress(widget.imagePath);

    if (_cancelled) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    if (mounted) {
      Navigator.of(context).pop();
      widget.onResult(result);
    }
  }

  void _handleCancel() {
    if (_cancelled) return;
    setState(() {
      _cancelled = true;
    });
    ref.read(ocrProvider.notifier).cancelRecognition();
  }

  @override
  Widget build(BuildContext context) {
    final ocrState = ref.watch(ocrProvider);

    final stageText = _cancelled
        ? '正在安全结束识别...'
        : switch (ocrState.stage) {
            OcrStage.ocrRecognizing => '正在识别文本...',
            OcrStage.imageRecognizing => '正在理解图片...',
            OcrStage.llmParsing => '正在解析文本...',
            _ => '准备中...',
          };

    final isDirectVisionStage = ocrState.stage == OcrStage.imageRecognizing;

    return GlassAlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      value: _cancelled ? null : ocrState.progress,
                      strokeWidth: 6,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  if (_cancelled)
                    const Icon(Icons.hourglass_bottom)
                  else
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
            if (_cancelled) ...[
              const SizedBox(height: 8),
              Text(
                '结果不会写入表单；底层任务结束前将保持此窗口。'
                '已发出的云端请求仍可能产生费用。',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            // Stage indicator
            if (isDirectVisionStage)
              _buildStageChip(context, '图片理解', true, ocrState.progress >= 1.0)
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStageChip(
                    context,
                    'OCR 识别',
                    ocrState.stage == OcrStage.ocrRecognizing,
                    ocrState.progress > 0.21 ||
                        ocrState.stage == OcrStage.llmParsing,
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
          onPressed: _cancelled ? null : _handleCancel,
          child: Text(_cancelled ? '正在结束' : '取消识别'),
        ),
      ],
    );
  }

  Widget _buildStageChip(
    BuildContext context,
    String label,
    bool isActive,
    bool isCompleted,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? Theme.of(context).colorScheme.primaryContainer
            : isCompleted
            ? Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.5)
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

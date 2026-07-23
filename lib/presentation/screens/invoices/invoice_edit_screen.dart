import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_alert_dialog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:receipt_tamer/core/constants/app_constants.dart';
import 'package:receipt_tamer/core/services/log_service.dart';
import 'package:receipt_tamer/core/services/log_config.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/models/llm_backend.dart';
import 'package:receipt_tamer/data/models/ocr_result.dart';
import 'package:receipt_tamer/data/services/duplicate_detection_service.dart';
import 'package:receipt_tamer/data/services/file_service.dart';
import 'package:receipt_tamer/data/services/image_service.dart';
import 'package:receipt_tamer/data/services/llm_config_service.dart';
import 'package:receipt_tamer/data/services/share_handler_service.dart';
import 'package:receipt_tamer/presentation/providers/invoice_provider.dart';
import 'package:receipt_tamer/presentation/providers/ocr_provider.dart';
import 'package:receipt_tamer/presentation/providers/order_provider.dart';
import 'package:receipt_tamer/presentation/screens/invoices/order_selector_screen.dart';
import 'package:receipt_tamer/presentation/utils/ai_use_disclosure.dart';
import 'package:receipt_tamer/presentation/utils/share_import_actions.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_notice.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_button.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_text_field.dart';
import 'package:receipt_tamer/presentation/widgets/common/duplicate_warning_dialog.dart';
import 'package:receipt_tamer/presentation/widgets/common/scroll_edge_fog.dart';
import 'package:receipt_tamer/presentation/widgets/invoice/invoice_image_preview.dart';
import 'package:receipt_tamer/presentation/widgets/invoice/relation_transfer_dialog.dart';

/// Invoice edit/add screen
class InvoiceEditScreen extends ConsumerStatefulWidget {
  final int? invoiceId; // If null, creating new invoice
  final int? initialOrderId; // Optional initial order ID
  final List<int> initialOrderIds; // Optional initial order IDs
  final String? initialFilePath; // Optional initial file path (image or PDF)
  final int remainingSharedCount; // Remaining shared files to process

  const InvoiceEditScreen({
    super.key,
    this.invoiceId,
    this.initialOrderId,
    this.initialOrderIds = const [],
    this.initialFilePath,
    this.remainingSharedCount = 0,
  });

  List<int> get effectiveInitialOrderIds {
    final ids = <int>[];
    for (final orderId in initialOrderIds) {
      if (!ids.contains(orderId)) ids.add(orderId);
    }
    if (initialOrderId != null && !ids.contains(initialOrderId)) {
      ids.add(initialOrderId!);
    }
    return ids;
  }

  @override
  ConsumerState<InvoiceEditScreen> createState() => _InvoiceEditScreenState();
}

class _InvoiceEditScreenState extends ConsumerState<InvoiceEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceNumberController = TextEditingController();
  final _amountController = TextEditingController();
  final _sellerNameController = TextEditingController();

  DateTime? _invoiceDate;
  List<int> _selectedOrderIds = [];
  final Set<int> _approvedTransferOrderIds = {};
  String? _filePath;
  bool _isPdf = false;
  final ImageService _imageService = ImageService();
  final FileService _fileService = FileService();
  final DuplicateDetectionService _duplicateDetectionService =
      DuplicateDetectionService();

  Invoice? _loadedInvoice;
  bool _isLoading = false;
  bool _saveInProgress = false;
  bool _hasOcrResult = false; // 是否有 OCR 识别结果
  List<Map<String, dynamic>> _sellerNameOptions = []; // 销售方名称选项列表（含次数）

  @override
  void initState() {
    super.initState();
    _loadSellerNames();
    _selectedOrderIds = widget.effectiveInitialOrderIds;
    // Handle initial file path from share
    if (widget.initialFilePath != null) {
      _filePath = widget.initialFilePath;
      _isPdf = widget.initialFilePath!.toLowerCase().endsWith('.pdf');
    }
    if (widget.invoiceId != null) {
      _loadInvoice();
    }
  }

  @override
  void didUpdateWidget(InvoiceEditScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当导航到新的发票时（例如继续添加下一个），重置所有状态
    if (oldWidget.initialFilePath != widget.initialFilePath ||
        oldWidget.invoiceId != widget.invoiceId ||
        oldWidget.initialOrderId != widget.initialOrderId ||
        oldWidget.initialOrderIds.join(',') !=
            widget.initialOrderIds.join(',')) {
      _resetState();
    }
  }

  void _resetState() {
    // 清空输入框
    _invoiceNumberController.clear();
    _amountController.clear();
    _sellerNameController.clear();

    // 重置状态
    setState(() {
      _loadedInvoice = null;
      _invoiceDate = null;
      _selectedOrderIds = widget.effectiveInitialOrderIds;
      _approvedTransferOrderIds.clear();
      _filePath = widget.initialFilePath;
      _isPdf = widget.initialFilePath?.toLowerCase().endsWith('.pdf') ?? false;
      _hasOcrResult = false;
    });

    // 如果是编辑模式，加载数据
    if (widget.invoiceId != null) {
      _loadInvoice();
    }
  }

  Future<void> _loadSellerNames() async {
    final sellerNamesWithCount = await ref
        .read(invoiceProvider.notifier)
        .getSellerNamesWithCount();
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
    try {
      final invoice = await ref
          .read(invoiceProvider.notifier)
          .getInvoiceById(widget.invoiceId!);
      if (invoice != null && mounted) {
        // Load order relations
        final orderIds = await ref
            .read(invoiceProvider.notifier)
            .getOrderIdsForInvoice(widget.invoiceId!);
        setState(() {
          _loadedInvoice = invoice;
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
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleUi, '加载发票失败', e, stackTrace);
    }
  }

  Future<void> _pickFile() async {
    _FilePickResult? result;
    try {
      result = await showGlassContentBottomSheet<_FilePickResult>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text(AppConstants.btnTakePhoto),
                onTap: () => Navigator.pop(
                  context,
                  _FilePickResult(ImageSource.camera, false),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text(AppConstants.btnSelectFromGallery),
                onTap: () => Navigator.pop(
                  context,
                  _FilePickResult(ImageSource.gallery, false),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text(AppConstants.btnSelectPDF),
                onTap: () =>
                    Navigator.pop(context, _FilePickResult(null, true)),
              ),
            ],
          ),
        ),
      );

      if (!mounted || result == null) return;
      if (result.isPdf) {
        final pickResult = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );
        if (pickResult != null &&
            pickResult.files.single.path != null &&
            mounted) {
          setState(() {
            _filePath = pickResult.files.single.path;
            _isPdf = true;
          });
        }
      } else if (result.imageSource != null) {
        final imageFile = result.imageSource == ImageSource.camera
            ? await _imageService.pickImageFromCamera()
            : await _imageService.pickImageFromGallery();

        if (imageFile != null && mounted) {
          setState(() {
            _filePath = imageFile.path;
            _isPdf = false;
          });
        }
      }
    } on PlatformException catch (e, stackTrace) {
      logService.e(LogConfig.moduleUi, '选择发票附件失败', e, stackTrace);
      if (mounted) {
        final source = result?.imageSource;
        final isPermissionError =
            e.code.contains('denied') ||
            e.code.contains('restricted') ||
            e.code.contains('permission');
        AppNotice.error(
          context,
          isPermissionError && source == ImageSource.camera
              ? '无法访问相机，请在系统设置中允许相机权限'
              : isPermissionError && source == ImageSource.gallery
              ? '无法访问相册，请在系统设置中允许照片权限'
              : '选择附件失败，请重试',
        );
      }
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleUi, '选择发票附件失败', e, stackTrace);
      if (mounted) {
        AppNotice.error(context, '选择附件失败，请重试');
      }
    }
  }

  Future<void> _handleOCR() async {
    if (_filePath == null || _filePath!.isEmpty) {
      AppNotice.warning(context, '请先选择图片或PDF');
      return;
    }

    logService.i(LogConfig.moduleUi, '开始发票 OCR 识别');

    final backendConfig = await _ensureAiBackendConfigured();
    if (backendConfig == null || !mounted) return;

    final sendsImage = !_isPdf && backendConfig.cloud.isMultimodal;
    final uploadAllowed = await confirmCloudUploadIfNeeded(
      context,
      config: backendConfig,
      content: sendsImage
          ? CloudUploadContent.invoiceImage
          : CloudUploadContent.invoiceText,
    );
    if (!uploadAllowed || !mounted) return;

    // Show progress dialog (handles both image and PDF)
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: _InvoiceOcrProgressDialog(
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
                  if (ocrResult?.totalAmount != null &&
                      ocrResult!.totalAmount! > 0) {
                    _amountController.text = ocrResult.totalAmount!
                        .toStringAsFixed(2);
                  }
                  if (ocrResult?.invoiceDate != null &&
                      ocrResult!.invoiceDate!.isNotEmpty) {
                    _invoiceDate = DateTime.tryParse(ocrResult.invoiceDate!);
                  }
                  if (ocrResult?.sellerName != null &&
                      ocrResult!.sellerName!.isNotEmpty) {
                    _sellerNameController.text = ocrResult.sellerName!;
                  }
                });
                logService.i(LogConfig.moduleUi, '发票 OCR 识别成功');
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

  void _showOrderSelector() async {
    // Build the URL with query parameters
    final selectedIdsStr = _selectedOrderIds.join(',');
    final uri = Uri(
      path: '/orders/select',
      queryParameters: {
        if (selectedIdsStr.isNotEmpty) 'selectedIds': selectedIdsStr,
        if (widget.invoiceId != null)
          'excludeInvoiceId': widget.invoiceId.toString(),
      },
    );

    final result = await context.push<OrderSelectorResult>(uri.toString());

    if (result != null) {
      setState(() {
        _selectedOrderIds = result.selectedOrderIds;
        _approvedTransferOrderIds
          ..removeWhere((orderId) => !_selectedOrderIds.contains(orderId))
          ..addAll(result.approvedTransferOrderIds);
      });
    }
  }

  String get _relationTransferTargetLabel {
    final invoiceNumber = _invoiceNumberController.text.trim();
    if (invoiceNumber.isNotEmpty) return '发票 $invoiceNumber';

    final sellerName = _sellerNameController.text.trim();
    if (sellerName.isNotEmpty) return sellerName;

    return widget.invoiceId == null ? '本次新发票' : '当前发票';
  }

  Future<bool> _confirmPendingRelationTransfers() async {
    if (_selectedOrderIds.isEmpty) return true;

    final orderRepository = ref.read(orderRepositoryProvider);
    final invoiceIdsByOrder = await orderRepository.getInvoiceIdsForOrders(
      _selectedOrderIds,
    );
    final transferOrderIds = _selectedOrderIds
        .where((orderId) {
          if (_approvedTransferOrderIds.contains(orderId)) return false;
          return (invoiceIdsByOrder[orderId] ?? const <int>{}).any(
            (invoiceId) => invoiceId != widget.invoiceId,
          );
        })
        .toList(growable: false);
    if (transferOrderIds.isEmpty) return true;

    final orders = await orderRepository.getByIds(transferOrderIds);
    final ordersById = {
      for (final order in orders)
        if (order.id != null) order.id!: order,
    };
    final sourceInvoiceIds = transferOrderIds
        .expand((orderId) => invoiceIdsByOrder[orderId] ?? const <int>{})
        .where((invoiceId) => invoiceId != widget.invoiceId)
        .toSet();
    final invoiceRepository = ref.read(invoiceRepositoryProvider);
    final sourceInvoices = await Future.wait(
      sourceInvoiceIds.map(invoiceRepository.getById),
    );
    final sourceInvoicesById = {
      for (final invoice in sourceInvoices)
        if (invoice?.id != null) invoice!.id!: invoice,
    };
    final transferItems = [
      for (final orderId in transferOrderIds)
        if (ordersById[orderId] != null)
          InvoiceRelationTransferItem(
            order: ordersById[orderId]!,
            sourceInvoices: (invoiceIdsByOrder[orderId] ?? const <int>{})
                .where((invoiceId) => invoiceId != widget.invoiceId)
                .map((invoiceId) => sourceInvoicesById[invoiceId])
                .whereType<Invoice>()
                .toList(growable: false),
          ),
    ];
    if (transferItems.length != transferOrderIds.length) {
      if (mounted) {
        AppNotice.error(context, '部分订单已不存在，请重新选择关联订单');
      }
      return false;
    }
    if (!mounted) return false;

    final confirmed = await showInvoiceRelationTransferDialog(
      context: context,
      items: transferItems,
      targetLabel: _relationTransferTargetLabel,
    );
    if (confirmed) {
      _approvedTransferOrderIds.addAll(transferOrderIds);
    }
    return confirmed;
  }

  Future<void> _handleSave() async {
    if (_saveInProgress) return;
    _saveInProgress = true;
    try {
      if (!_formKey.currentState!.validate()) return;

      if (_filePath == null || _filePath!.isEmpty) {
        AppNotice.warning(context, '请选择发票图片或PDF');
        return;
      }

      final amount = double.tryParse(_amountController.text) ?? 0.0;
      if (amount <= 0) {
        AppNotice.warning(context, '请输入有效的价税合计金额');
        return;
      }

      if (_invoiceDate == null) {
        AppNotice.warning(context, '请选择开票日期');
        return;
      }

      setState(() {
        _isLoading = true;
      });

      final duplicateReport = await _duplicateDetectionService.checkInvoice(
        attachmentPath: _filePath!,
        sellerName: _sellerNameController.text,
        invoiceNumber: _invoiceNumberController.text,
        invoiceDate: _invoiceDate!.toIso8601String(),
        amount: amount,
        existingOrders: await ref.read(orderProvider.notifier).getAll(),
        existingInvoices: await ref.read(invoiceProvider.notifier).getAll(),
        excludeInvoiceId: widget.invoiceId,
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

      final existingInvoice = widget.invoiceId == null
          ? null
          : _loadedInvoice ??
                await ref
                    .read(invoiceProvider.notifier)
                    .getInvoiceById(widget.invoiceId!);
      if (widget.invoiceId != null && existingInvoice == null) {
        if (mounted) {
          AppNotice.error(context, '发票已不存在，请返回后刷新');
        }
        return;
      }

      if (!await _confirmPendingRelationTransfers()) return;
      if (!mounted) return;

      // Save file to app directory if not already saved
      String savedPath;
      if (_isPdf) {
        savedPath = await _fileService.savePdf(File(_filePath!));
      } else {
        savedPath = await _imageService.saveImage(File(_filePath!));
      }

      final invoice = widget.invoiceId != null
          ? Invoice(
              id: widget.invoiceId,
              imagePath: savedPath,
              invoiceNumber: _invoiceNumberController.text.trim(),
              invoiceDate: _invoiceDate?.toIso8601String(),
              totalAmount: amount,
              sellerName: _sellerNameController.text.trim(),
              createdAt: existingInvoice!.createdAt,
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
          ? await ref
                .read(invoiceProvider.notifier)
                .updateInvoice(invoice, orderIds: _selectedOrderIds)
          : await ref
                .read(invoiceProvider.notifier)
                .createInvoice(invoice, orderIds: _selectedOrderIds);

      if (mounted) {
        if (success) {
          logService.i(
            LogConfig.moduleUi,
            '发票保存成功: id=${widget.invoiceId ?? invoice.id}',
          );
          // Clean up temp file after successful save
          if (_filePath != null) {
            _fileService.deleteTempFile(_filePath!);
          }

          AppNotice.success(context, AppConstants.successSaved);

          // 判断是否从分享进入
          final isFromShare = widget.initialFilePath != null;

          if (isFromShare) {
            final shareService = ShareHandlerService();
            shareService.completePendingSharedMedia(widget.initialFilePath!);
            if (shareService.hasPendingSharedMedia) {
              // 还有待处理的文件，显示继续对话框
              _showContinueDialog();
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
      logService.e(LogConfig.moduleUi, '保存发票失败', e, stackTrace);
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

  String _getOrderSelectorSubtitle() {
    if (_selectedOrderIds.isEmpty) {
      return AppConstants.labelNoOrdersSelected;
    }
    return AppConstants.labelOrdersSelected.replaceAll(
      '{}',
      _selectedOrderIds.length.toString(),
    );
  }

  void _showSellerNamePicker() {
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
                '选择销售方',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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

  void _showContinueDialog() {
    final service = ShareHandlerService();
    final items = service.pendingSharedMedia;

    if (items == null || items.isEmpty) {
      context.go('/');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => GlassAlertDialog(
        title: const Text('继续添加'),
        content: Text('还有 ${items.length} 个待处理的文件。\n\n是否继续添加下一个发票？'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final abandon = await confirmAbandonSharedImport(
                context,
                pendingCount: items.length,
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
              // 获取下一个待处理的文件
              final nextItem = items.first;
              final remainingItems = items.skip(1).toList();

              // 导航到下一个发票编辑页面
              context.go(
                '/invoices/new?sharedPath=${Uri.encodeComponent(nextItem.path)}&remainingCount=${remainingItems.length}',
              );
            },
            child: const Text('继续添加'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.invoiceId != null;
    final ocrState = ref.watch(ocrProvider);
    final isModelLoading = ocrState.isModelLoading;
    final isRecognizing = ocrState.isLoading;
    final isOcrButtonBusy = isRecognizing || isModelLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing
              ? AppConstants.titleInvoiceEdit
              : AppConstants.titleInvoiceAdd,
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
              // File picker section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '发票文件',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      if (_filePath != null && _filePath!.isNotEmpty)
                        InvoiceImagePreview(imagePath: _filePath!, height: 200)
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
                                  '点击下方按钮选择图片或PDF',
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
                              onPressed: _pickFile,
                              icon: const Icon(Icons.attach_file),
                              label: const Text('选择文件'),
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
  ConsumerState<_InvoiceOcrProgressDialog> createState() =>
      _InvoiceOcrProgressDialogState();
}

class _InvoiceOcrProgressDialogState
    extends ConsumerState<_InvoiceOcrProgressDialog> {
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
      result = await ref
          .read(ocrProvider.notifier)
          .recognizeInvoiceFromPdf(widget.filePath);
    } else {
      // Image file: use image recognition
      result = await ref
          .read(ocrProvider.notifier)
          .recognizeInvoiceWithProgress(widget.filePath);
    }

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

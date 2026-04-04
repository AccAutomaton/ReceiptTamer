import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'package:receipt_tamer/core/services/log_service.dart';
import 'package:receipt_tamer/core/services/log_config.dart';
import 'package:receipt_tamer/data/services/share_handler_service.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_button.dart';

/// Share target type
enum ShareTargetType {
  order,
  invoice,
}

/// Result of share target selection
class ShareTargetResult {
  final ShareTargetType targetType;
  final List<SharedMediaItem> items;

  const ShareTargetResult({
    required this.targetType,
    required this.items,
  });
}

/// Screen for selecting where to import shared files
class ShareTargetScreen extends ConsumerWidget {
  final List<SharedMediaItem> sharedItems;

  const ShareTargetScreen({
    super.key,
    required this.sharedItems,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ShareHandlerService();
    final allImages = service.allImages(sharedItems);
    final allPdfs = service.allPdfs(sharedItems);
    final hasMixed = service.hasMixedTypes(sharedItems);

    return Scaffold(
      appBar: AppBar(
        title: const Text('导入分享内容'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // File preview section
            Expanded(
              child: _FilePreviewList(items: sharedItems),
            ),

            // Target selection section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '选择导入类型',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),

                  // Add as Order button (only if has images)
                  if (allImages || hasMixed)
                    AppButton(
                      text: allImages
                          ? '添加为订单 (${sharedItems.length} 个)'
                          : '添加为订单 (${service.filterByType(sharedItems, SharedMediaType.image).length} 个图片)',
                      onPressed: () {
                        final imageItems = service.filterByType(sharedItems, SharedMediaType.image);
                        if (imageItems.isNotEmpty) {
                          _navigateToOrderEdit(context, imageItems);
                        }
                      },
                      type: AppButtonType.primary,
                      isFullWidth: true,
                      icon: const Icon(Icons.receipt_long),
                    ),

                  if (allImages || hasMixed) const SizedBox(height: 12),

                  // Add as Invoice button
                  AppButton(
                    text: allPdfs
                        ? '添加为发票 (${sharedItems.length} 个)'
                        : hasMixed
                            ? '添加为发票 (${sharedItems.length} 个)'
                            : '添加为发票 (${sharedItems.length} 个)',
                    onPressed: () {
                      _navigateToInvoiceEdit(context, sharedItems);
                    },
                    type: allPdfs ? AppButtonType.primary : AppButtonType.secondary,
                    isFullWidth: true,
                    icon: const Icon(Icons.description),
                  ),

                  const SizedBox(height: 12),

                  // Cancel button
                  OutlinedButton(
                    onPressed: () {
                      service.clearPendingSharedMedia();
                      // 移到后台，让用户返回相册
                      SystemNavigator.pop();
                    },
                    child: const Text('取消'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToOrderEdit(BuildContext context, List<SharedMediaItem> items) {
    logService.i(LogConfig.moduleUi, '导航到订单编辑页面: ${items.length} 个图片');
    // Navigate to order edit with the first image
    // Pass remaining items as pending
    final firstItem = items.first;
    final remainingItems = items.skip(1).toList();

    // 保存剩余图片到 ShareHandlerService（用于后续处理）
    // 但设置一个临时标志防止 app.dart 自动导航
    final service = ShareHandlerService();
    service.sharedMediaNotifier.value = remainingItems.isNotEmpty ? remainingItems : null;

    // 使用 push 而不是 go，这样可以在编辑页面处理完后正确返回
    context.go(
      '/orders/new?sharedPath=${Uri.encodeComponent(firstItem.path)}&remainingCount=${remainingItems.length}',
    );
  }

  void _navigateToInvoiceEdit(BuildContext context, List<SharedMediaItem> items) {
    logService.i(LogConfig.moduleUi, '导航到发票编辑页面: ${items.length} 个文件');
    // Navigate to invoice edit with the first file
    // Pass remaining items as pending
    final firstItem = items.first;
    final remainingItems = items.skip(1).toList();

    // 保存剩余文件到 ShareHandlerService（用于后续处理）
    final service = ShareHandlerService();
    service.sharedMediaNotifier.value = remainingItems.isNotEmpty ? remainingItems : null;

    context.go(
      '/invoices/new?sharedPath=${Uri.encodeComponent(firstItem.path)}&remainingCount=${remainingItems.length}',
    );
  }
}

/// Widget for displaying a list of shared file previews
class _FilePreviewList extends StatelessWidget {
  final List<SharedMediaItem> items;

  const _FilePreviewList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text('没有可分享的文件'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _FilePreviewCard(item: item);
      },
    );
  }
}

/// Widget for displaying a single shared file preview
class _FilePreviewCard extends StatelessWidget {
  final SharedMediaItem item;

  const _FilePreviewCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isImage = item.isImage;
    final isPdf = item.isPdf;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Thumbnail or icon
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 80,
                height: 80,
                child: isImage
                    ? Image.file(
                        File(item.path),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.broken_image, size: 32),
                        ),
                      )
                    : Container(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(
                          isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file,
                          size: 32,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),

            // File info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getFileName(item.path),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isImage ? '图片' : (isPdf ? 'PDF文件' : '文件'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFileName(String path) {
    return path.split('/').last;
  }
}
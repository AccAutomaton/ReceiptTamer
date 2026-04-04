import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../core/services/log_service.dart';
import '../../core/services/log_config.dart';

/// Shared media item representing a single shared file
class SharedMediaItem {
  final String path;
  final SharedMediaType type;

  const SharedMediaItem({
    required this.path,
    required this.type,
  });

  bool get isImage => type == SharedMediaType.image;
  bool get isPdf => type == SharedMediaType.file && path.toLowerCase().endsWith('.pdf');
}

/// Service for handling shared content from other apps
class ShareHandlerService {
  static final ShareHandlerService _instance = ShareHandlerService._internal();
  factory ShareHandlerService() => _instance;
  ShareHandlerService._internal();

  /// Stream of shared media events
  final ValueNotifier<List<SharedMediaItem>?> sharedMediaNotifier = ValueNotifier(null);

  /// Initialize the share handler and listen for shared content
  Future<void> initialize() async {
    try {
      logService.i(LogConfig.moduleShare, '开始初始化...');

      // Listen for shared media while app is running
      ReceiveSharingIntent.instance.getMediaStream().listen(
        (sharedFiles) {
          logService.i(LogConfig.moduleShare, '从流中接收到 ${sharedFiles.length} 个文件');
          _processSharedMedia(sharedFiles);
        },
        onError: (error) {
          logService.e(LogConfig.moduleShare, '分享处理流错误', error);
        },
      );

      // 延迟获取初始媒体，给 Flutter Engine 更多时间准备
      await Future.delayed(const Duration(milliseconds: 500));

      // Check for shared media when app is launched from share
      final initialFiles = await ReceiveSharingIntent.instance.getInitialMedia();
      if (initialFiles.isNotEmpty) {
        logService.i(LogConfig.moduleShare, '发现 ${initialFiles.length} 个初始文件');
        _processSharedMedia(initialFiles);
      }

      logService.i(LogConfig.moduleShare, '初始化完成');
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleShare, '初始化分享处理器失败', e, stackTrace);
      rethrow;
    }
  }

  /// Process shared media and update the notifier
  void _processSharedMedia(List<SharedMediaFile> sharedFiles) {
    final items = <SharedMediaItem>[];

    for (final file in sharedFiles) {
      final path = file.path;
      if (path.isNotEmpty) {
        items.add(SharedMediaItem(
          path: path,
          type: file.type,
        ));
      }
    }

    if (items.isNotEmpty) {
      logService.i(LogConfig.moduleShare, '处理了 ${items.length} 个分享项');
      sharedMediaNotifier.value = items;
    } else {
      logService.w(LogConfig.moduleShare, '分享内容中没有有效项');
    }
  }

  /// Check if there are pending shared files
  bool get hasPendingSharedMedia => sharedMediaNotifier.value != null && sharedMediaNotifier.value!.isNotEmpty;

  /// Get pending shared media items
  List<SharedMediaItem>? get pendingSharedMedia => sharedMediaNotifier.value;

  /// Clear pending shared media
  void clearPendingSharedMedia() {
    sharedMediaNotifier.value = null;
  }

  /// Check if all shared items are images
  bool allImages(List<SharedMediaItem> items) {
    return items.every((item) => item.isImage);
  }

  /// Check if all shared items are PDFs
  bool allPdfs(List<SharedMediaItem> items) {
    return items.every((item) => item.isPdf);
  }

  /// Check if there's a mix of images and PDFs
  bool hasMixedTypes(List<SharedMediaItem> items) {
    final hasImage = items.any((item) => item.isImage);
    final hasPdf = items.any((item) => item.isPdf);
    return hasImage && hasPdf;
  }

  /// Filter items by type
  List<SharedMediaItem> filterByType(List<SharedMediaItem> items, SharedMediaType type) {
    return items.where((item) => item.type == type).toList();
  }

  /// Copy shared files to app directory for persistent access
  Future<List<String>> copySharedFilesToAppDir(
    List<SharedMediaItem> items,
    String appDir,
  ) async {
    logService.i(LogConfig.moduleShare, '开始复制分享文件到应用目录...');
    logService.diag(LogConfig.moduleShare, 'Items count', items.length);
    logService.diag(LogConfig.moduleShare, 'Target dir', appDir);

    final copiedPaths = <String>[];
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final sourceFile = File(item.path);

      if (await sourceFile.exists()) {
        final extension = _getExtension(item.path);
        final filename = 'shared_${timestamp}_$i$extension';
        final destPath = '$appDir/$filename';

        logService.d(LogConfig.moduleShare, '复制文件: ${item.path} -> $destPath');
        await sourceFile.copy(destPath);
        copiedPaths.add(destPath);
        logService.i(LogConfig.moduleShare, '文件已复制: $destPath');
      } else {
        logService.w(LogConfig.moduleShare, '源文件不存在: ${item.path}');
      }
    }

    logService.i(LogConfig.moduleShare, '复制完成，共 ${copiedPaths.length} 个文件');
    return copiedPaths;
  }

  /// Get file extension from path
  String _getExtension(String path) {
    final lastDot = path.lastIndexOf('.');
    if (lastDot != -1 && lastDot < path.length - 1) {
      return path.substring(lastDot);
    }
    return '';
  }

  /// Dispose resources
  void dispose() {
    sharedMediaNotifier.dispose();
  }
}
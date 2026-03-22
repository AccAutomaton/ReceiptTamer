import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

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
      debugPrint('ShareHandlerService: 开始初始化...');

      // Listen for shared media while app is running
      ReceiveSharingIntent.instance.getMediaStream().listen(
        (sharedFiles) {
          debugPrint('ShareHandlerService: Received ${sharedFiles.length} files from stream');
          _processSharedMedia(sharedFiles);
        },
        onError: (error) {
          debugPrint('Share handler stream error: $error');
        },
      );

      // 延迟获取初始媒体，给 Flutter Engine 更多时间准备
      await Future.delayed(const Duration(milliseconds: 500));

      // Check for shared media when app is launched from share
      final initialFiles = await ReceiveSharingIntent.instance.getInitialMedia();
      if (initialFiles.isNotEmpty) {
        debugPrint('ShareHandlerService: Found ${initialFiles.length} initial files');
        _processSharedMedia(initialFiles);
      }

      debugPrint('ShareHandlerService: 初始化完成');
    } catch (e) {
      debugPrint('Error initializing share handler: $e');
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
      debugPrint('Processed ${items.length} shared items');
      sharedMediaNotifier.value = items;
    } else {
      debugPrint('No valid items found in shared media');
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
    final copiedPaths = <String>[];
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final sourceFile = File(item.path);

      if (await sourceFile.exists()) {
        final extension = _getExtension(item.path);
        final filename = 'shared_${timestamp}_$i$extension';
        final destPath = '$appDir/$filename';

        await sourceFile.copy(destPath);
        copiedPaths.add(destPath);
      }
    }

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
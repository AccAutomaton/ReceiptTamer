import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:receipt_tamer/data/models/app_version.dart';
import 'package:receipt_tamer/data/services/update_preferences.dart';
import 'package:receipt_tamer/data/services/update_service.dart';

/// 更新弹窗组件
/// 封装更新弹窗显示和下载安装逻辑，供 main_shell 和 settings_screen 复用
class UpdateDialog {
  /// 显示更新弹窗
  ///
  /// [context] - 上下文
  /// [latestVersion] - 最新版本信息
  /// [updateService] - 更新服务（可选，默认创建新实例）
  /// [onApkDownloaded] - APK下载完成后的回调，用于记录路径以便安装后清理
  /// [onIgnore] - 点击"忽略此版本"后的回调（可选，默认自动记录忽略版本）
  /// [onLater] - 点击"稍后提醒"后的回调（可选，默认关闭弹窗）
  static Future<void> show(
    BuildContext context,
    AppVersion latestVersion, {
    UpdateService? updateService,
    void Function(String? apkPath)? onApkDownloaded,
    VoidCallback? onIgnore,
    VoidCallback? onLater,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.system_update, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(child: Text('发现新版本 ${latestVersion.version}')),
          ],
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (latestVersion.formattedFileSize != null)
                Text(
                  '安装包大小: ${latestVersion.formattedFileSize}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              const SizedBox(height: 12),
              if (latestVersion.changelog != null &&
                  latestVersion.changelog!.isNotEmpty) ...[
                const Text(
                  '更新内容:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: MarkdownBody(
                      data: latestVersion.changelog!,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(fontSize: 14),
                        h2: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        h3: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        listBullet: const TextStyle(fontSize: 14),
                        code: TextStyle(
                          fontSize: 12,
                          backgroundColor: Colors.grey[200],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  if (onIgnore != null) {
                    onIgnore();
                  } else {
                    await UpdatePreferences.setIgnoredVersion(latestVersion.version);
                  }
                },
                child: const Text('忽略此版本'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  onLater?.call();
                },
                child: const Text('稍后提醒'),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await UpdatePreferences.clearIgnoredVersion();
                  if (!context.mounted) return;
                  await startDownloadAndInstall(
                    context,
                    latestVersion,
                    updateService: updateService,
                    onApkDownloaded: onApkDownloaded,
                  );
                },
                child: const Text('立即更新'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 开始下载安装流程
  ///
  /// [context] - 上下文
  /// [version] - 版本信息
  /// [updateService] - 更新服务（可选，默认创建新实例）
  /// [onApkDownloaded] - APK下载完成后的回调，用于记录路径以便安装后清理
  static Future<void> startDownloadAndInstall(
    BuildContext context,
    AppVersion version, {
    UpdateService? updateService,
    void Function(String? apkPath)? onApkDownloaded,
  }) async {
    final service = updateService ?? UpdateService();
    final shouldDisposeService = updateService == null;  // 只 dispose 自己创建的实例

    if (version.downloadUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('下载地址不可用')),
      );
      if (shouldDisposeService) service.dispose();
      return;
    }

    // Check WiFi connection
    final isWifi = await service.isWifiConnection();
    if (!context.mounted) {
      if (shouldDisposeService) service.dispose();
      return;
    }
    if (!isWifi) {
      final shouldContinue = await _showMobileDataWarning(context, version);
      if (!context.mounted || !shouldContinue) {
        if (shouldDisposeService) service.dispose();
        return;
      }
    }

    // Start download with retry
    await _downloadWithRetry(
      context,
      service,
      version,
      onApkDownloaded: onApkDownloaded,
    );

    if (shouldDisposeService) service.dispose();
  }

  /// 显示移动数据警告弹窗
  static Future<bool> _showMobileDataWarning(
    BuildContext context,
    AppVersion version,
  ) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange[700]),
            const SizedBox(width: 8),
            const Text('网络提示'),
          ],
        ),
        content: Text(
          '当前未连接WiFi，继续下载将使用移动数据流量。\n'
          '安装包大小: ${version.formattedFileSize ?? "未知"}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('继续下载'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// 下载APK（支持重试）
  static Future<void> _downloadWithRetry(
    BuildContext context,
    UpdateService updateService,
    AppVersion version, {
    void Function(String? apkPath)? onApkDownloaded,
  }) async {
    DownloadProgress? progressInfo;
    bool downloadCancelled = false;
    bool shouldRetry = true;

    void Function(void Function())? dialogSetState;

    while (shouldRetry && context.mounted) {
      shouldRetry = false;
      downloadCancelled = false;
      progressInfo = null;

      // Check for existing partial download
      final existingSize = await updateService.getExistingDownloadSize(version.downloadUrl!);
      final hasPartialDownload = existingSize > 0;

      if (!context.mounted) return;

      // Show download progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            dialogSetState = setDialogState;
            return AlertDialog(
              title: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(hasPartialDownload ? '继续下载' : '正在下载'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: progressInfo?.progress ?? 0),
                  const SizedBox(height: 16),
                  Text(
                    '${((progressInfo?.progress ?? 0) * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (progressInfo != null) ...[
                    Text(
                      '${progressInfo!.formattedDownloaded} / ${progressInfo!.formattedTotal}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '下载速度: ${progressInfo!.formattedSpeed}/s',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    downloadCancelled = true;
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('取消'),
                ),
              ],
            );
          },
        ),
      );

      // Download APK with resume support
      final result = await updateService.downloadApkWithResume(
        version.downloadUrl!,
        onProgress: (p) {
          if (context.mounted && !downloadCancelled && dialogSetState != null) {
            dialogSetState!(() {
              progressInfo = p;
            });
          }
        },
      );

      if (!context.mounted) return;

      // Close progress dialog
      Navigator.of(context, rootNavigator: true).pop();

      if (result.success && result.filePath != null && !downloadCancelled) {
        // Notify callback about downloaded APK path
        onApkDownloaded?.call(result.filePath);

        // Request install permission
        final permissionResult = await Permission.requestInstallPackages.request();
        if (!permissionResult.isGranted && context.mounted) {
          await _showInstallPermissionDialog(context);
          return;
        }

        // Install APK
        final installed = await updateService.installApk(result.filePath!);
        if (!installed && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('安装失败，请重试')),
          );
        }
      } else if (!downloadCancelled && context.mounted) {
        // Show error dialog with retry option
        final retry = await _showDownloadErrorDialog(context, result.errorMessage);
        if (retry == true) {
          shouldRetry = true;
        }
      }
    }
  }

  /// 显示下载错误弹窗
  static Future<bool?> _showDownloadErrorDialog(
    BuildContext context,
    String? errorMessage,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[400]),
            const SizedBox(width: 8),
            const Text('下载失败'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(errorMessage ?? '未知错误'),
            const SizedBox(height: 12),
            Text(
              '已下载的部分将保留，重试时将从断点继续下载。',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  /// 显示安装权限引导弹窗
  static Future<void> _showInstallPermissionDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.settings, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Text('需要安装权限'),
          ],
        ),
        content: const Text(
          '为了安装应用更新，需要允许安装未知应用。请在设置中开启此权限后重试。',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('安装失败，请手动打开下载的文件')),
              );
            },
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }
}
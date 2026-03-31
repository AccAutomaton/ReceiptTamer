import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../../data/models/backup_metadata.dart';
import '../../../data/services/backup_service.dart';
import '../../../data/services/file_service.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/order_provider.dart';
import '../../screens/export/saved_files_screen.dart';
import '../common/app_button.dart';

/// Backup dialog for creating and restoring backups
class BackupDialog extends ConsumerStatefulWidget {
  const BackupDialog({super.key});

  @override
  ConsumerState<BackupDialog> createState() => _BackupDialogState();
}

class _BackupDialogState extends ConsumerState<BackupDialog> {
  final BackupService _backupService = BackupService();
  bool _isLoading = false;
  double _progress = 0.0;
  String _statusMessage = '';
  String _currentAppVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _currentAppVersion = packageInfo.version;
      });
    }
  }

  Future<void> _createBackup() async {
    final fileService = FileService();
    String? tempPath;

    try {
      setState(() {
        _isLoading = true;
        _progress = 0.0;
        _statusMessage = '正在创建备份...';
      });

      final now = DateTime.now();
      final dateDir = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final subDir = 'backup/$dateDir';

      // Create backup in temp directory first
      final tempDir = await getTemporaryDirectory();
      final fileName = 'ReceiptTamer_Backup_${now.toString().substring(0, 10)}.zip';
      tempPath = '${tempDir.path}/$fileName';

      final result = await _backupService.createBackup(
        tempPath,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _progress = progress;
            });
          }
        },
      );

      if (!mounted) return;

      if (!result.success) {
        setState(() => _isLoading = false);
        _showErrorDialog('备份失败', result.errorMessage ?? '未知错误');
        return;
      }

      // Copy to Download/ReceiptTamer/backup/YYYYMMDD
      setState(() {
        _statusMessage = '正在保存文件...';
      });

      final savedPath = await fileService.copyToDownloadDirectory(
        tempPath,
        customFileName: fileName,
        subDir: subDir,
      );

      if (mounted) {
        setState(() => _isLoading = false);

        if (savedPath != null) {
          // Navigate to saved files screen to show backup files
          Navigator.pop(context);
          await showSavedFilesScreen(context, initialSubDir: subDir);
        } else {
          _showErrorDialog('备份失败', '保存到下载目录失败');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorDialog('备份失败', e.toString());
      }
    } finally {
      // Clean up temp file
      if (tempPath != null) {
        final tempFile = File(tempPath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    }
  }

  Future<void> _restoreBackup() async {
    final fileService = FileService();

    try {
      // Let user choose backup file
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: '选择备份文件',
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.isEmpty) {
        // User cancelled - still clean cache
        await fileService.cleanTempFiles();
        return;
      }

      final zipPath = result.files.first.path;
      if (zipPath == null) {
        await fileService.cleanTempFiles();
        return;
      }

      // Validate backup
      setState(() {
        _isLoading = true;
        _statusMessage = '正在验证备份文件...';
      });

      final validation = await _backupService.validateBackup(zipPath);

      if (!mounted) {
        await fileService.cleanTempFiles();
        return;
      }

      if (!validation.isValid) {
        setState(() => _isLoading = false);
        _showErrorDialog('备份文件无效', validation.errorMessage ?? '未知错误');
        await fileService.cleanTempFiles();
        return;
      }

      if (!validation.canRestore) {
        setState(() => _isLoading = false);
        _showErrorDialog('无法还原', '备份文件的数据库版本高于当前应用版本，无法还原。\n请更新应用后再试。');
        await fileService.cleanTempFiles();
        return;
      }

      // Show version warning if needed
      if (validation.needsVersionWarning && validation.metadata != null) {
        final shouldContinue = await _showVersionWarningDialog(validation.metadata!);
        if (!shouldContinue) {
          setState(() => _isLoading = false);
          await fileService.cleanTempFiles();
          return;
        }
      }

      // Ask for restore mode
      final restoreMode = await _showRestoreModeDialog();
      if (restoreMode == null) {
        setState(() => _isLoading = false);
        await fileService.cleanTempFiles();
        return;
      }

      // Show confirmation
      final confirmed = await _showRestoreConfirmationDialog(restoreMode);
      if (!confirmed) {
        setState(() => _isLoading = false);
        await fileService.cleanTempFiles();
        return;
      }

      // Perform restore
      setState(() {
        _progress = 0.0;
        _statusMessage = '正在还原数据...';
      });

      final restoreResult = await _backupService.restoreBackup(
        zipPath,
        restoreMode,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _progress = progress;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (restoreResult.success) {
          // Refresh all providers to reflect restored data
          _refreshProviders();

          _showSnackBar('数据还原成功');
          Navigator.pop(context);
        } else {
          _showErrorDialog('还原失败', restoreResult.errorMessage ?? '未知错误');
        }
      }

      // Clean cache after restore (success or fail)
      await fileService.cleanTempFiles();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorDialog('还原失败', e.toString());
      }
      // Clean cache on error
      await fileService.cleanTempFiles();
    }
  }

  Future<bool> _showVersionWarningDialog(BackupMetadata metadata) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange),
                SizedBox(width: 8),
                Text('版本警告'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('备份文件版本信息：'),
                const SizedBox(height: 8),
                Text('备份应用版本: ${metadata.appVersion}'),
                Text('当前应用版本: $_currentAppVersion'),
                const Divider(),
                Text('备份数据库版本: ${metadata.databaseVersion}'),
                Text('当前数据库版本: ${BackupService().databaseVersion}'),
                const SizedBox(height: 16),
                Text(
                  '版本差异可能导致数据不兼容，建议先创建当前数据备份再继续还原。是否继续？',
                  style: TextStyle(color: Colors.orange[700]),
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
                child: const Text('继续还原'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<RestoreMode?> _showRestoreModeDialog() async {
    return await showDialog<RestoreMode>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('选择还原模式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_sweep),
              title: const Text('覆盖还原'),
              subtitle: const Text('清除所有现有数据后还原备份'),
              onTap: () => Navigator.pop(context, RestoreMode.overwrite),
            ),
            ListTile(
              leading: const Icon(Icons.merge),
              title: const Text('增量还原'),
              subtitle: const Text('保留现有数据，与备份数据合并'),
              onTap: () => Navigator.pop(context, RestoreMode.incremental),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showRestoreConfirmationDialog(RestoreMode mode) async {
    final message = mode == RestoreMode.overwrite
        ? '覆盖还原将清除所有现有数据！\n确定要继续吗？'
        : '增量还原将合并备份数据与现有数据。\n确定要继续吗？';

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('确认还原'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确认'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Refresh all providers after restore
  void _refreshProviders() {
    // Refresh order providers
    ref.read(orderProvider.notifier).loadOrders(refresh: true);
    ref.invalidate(orderCountProvider);
    ref.invalidate(todayOrderCountProvider);
    ref.invalidate(totalOrderAmountProvider);

    // Refresh invoice providers
    ref.read(invoiceProvider.notifier).loadInvoices(refresh: true);
    ref.invalidate(invoiceCountProvider);
    ref.invalidate(todayInvoiceCountProvider);
    ref.invalidate(totalInvoiceAmountProvider);
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[400]),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('备份与还原'),
      content: _isLoading
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(_statusMessage),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 8),
                Text('${(_progress * 100).toStringAsFixed(0)}%'),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '当前版本: $_currentAppVersion',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                AppButton(
                  text: '创建备份',
                  icon: const Icon(Icons.backup),
                  onPressed: _createBackup,
                  isFullWidth: true,
                ),
                const SizedBox(height: 12),
                AppButton(
                  text: '还原备份',
                  icon: const Icon(Icons.restore),
                  onPressed: _restoreBackup,
                  type: AppButtonType.outlined,
                  isFullWidth: true,
                ),
                const SizedBox(height: 16),
                Text(
                  '备份包含：订单数据、发票数据、图片、PDF文件',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
      actions: _isLoading
          ? null
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ],
    );
  }
}

/// Show backup dialog
Future<void> showBackupDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (context) => const BackupDialog(),
  );
}
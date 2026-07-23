import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:receipt_tamer/core/services/log_config.dart';
import 'package:receipt_tamer/core/services/log_service.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/data/services/file_service.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_button.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_card.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_notice.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_page_scaffold.dart';

enum ExportMaterialType { mealProof, invoice, mealDetails }

enum ExportMaterialStatus { success, failure, notSelected }

typedef ExportMaterialRetry = Future<ExportMaterialResult> Function();

class ExportMaterialResult {
  final ExportMaterialType type;
  final ExportMaterialStatus status;
  final DownloadedFileReference? file;
  final String? previewPath;
  final String? message;
  final ExportMaterialRetry? retry;

  const ExportMaterialResult({
    required this.type,
    required this.status,
    this.file,
    this.previewPath,
    this.message,
    this.retry,
  });

  String get title => switch (type) {
    ExportMaterialType.mealProof => '用餐证明',
    ExportMaterialType.invoice => '发票',
    ExportMaterialType.mealDetails => '用餐明细',
  };

  String get format => switch (type) {
    ExportMaterialType.mealProof || ExportMaterialType.invoice => 'PDF',
    ExportMaterialType.mealDetails => 'XLSX',
  };

  bool get isSuccess =>
      status == ExportMaterialStatus.success &&
      file != null &&
      previewPath != null;
}

typedef ExportZipBuilder =
    Future<DownloadedFileReference?> Function(
      List<ExportMaterialResult> results,
    );

class ExportCompletionScreen extends StatefulWidget {
  final List<ExportMaterialResult> results;
  final String subDir;
  final Directory sessionDirectory;
  final FileService? fileService;
  final ExportZipBuilder? zipBuilder;

  const ExportCompletionScreen({
    required this.results,
    required this.subDir,
    required this.sessionDirectory,
    this.fileService,
    this.zipBuilder,
    super.key,
  });

  @override
  State<ExportCompletionScreen> createState() => _ExportCompletionScreenState();
}

class _ExportCompletionScreenState extends State<ExportCompletionScreen> {
  late final FileService _fileService;
  late List<ExportMaterialResult> _results;
  final Set<ExportMaterialType> _retrying = {};
  bool _isSharingAll = false;
  bool _isCreatingZip = false;

  @override
  void initState() {
    super.initState();
    _fileService = widget.fileService ?? FileService();
    _results = List<ExportMaterialResult>.of(widget.results);
  }

  @override
  void dispose() {
    unawaited(_deleteSessionDirectory());
    super.dispose();
  }

  Future<void> _deleteSessionDirectory() async {
    try {
      if (await widget.sessionDirectory.exists()) {
        await widget.sessionDirectory.delete(recursive: true);
      }
    } catch (error, stackTrace) {
      logService.w(LogConfig.moduleFile, '清理导出会话临时目录失败: $error\n$stackTrace');
    }
  }

  List<ExportMaterialResult> get _successfulResults =>
      _results.where((result) => result.isSuccess).toList(growable: false);

  Future<void> _retry(ExportMaterialResult result) async {
    final retry = result.retry;
    if (retry == null || _retrying.contains(result.type)) return;
    setState(() => _retrying.add(result.type));
    try {
      final updated = await retry();
      if (!mounted) return;
      setState(() {
        final index = _results.indexWhere((item) => item.type == result.type);
        if (index != -1) _results[index] = updated;
      });
      if (updated.isSuccess) {
        AppNotice.success(context, '${updated.title}已重新生成');
      } else {
        AppNotice.error(context, updated.message ?? '${updated.title}重试失败');
      }
    } finally {
      if (mounted) {
        setState(() => _retrying.remove(result.type));
      }
    }
  }

  Future<void> _open(ExportMaterialResult result) async {
    final file = result.file;
    if (file == null || !await _fileService.openDownloadedFile(file)) {
      if (mounted) AppNotice.error(context, '无法打开${result.title}');
    }
  }

  Future<void> _preview(ExportMaterialResult result) async {
    final localPath = result.previewPath;
    if (localPath == null ||
        !await File(localPath).exists() ||
        !await _fileService.openFile(localPath)) {
      if (mounted) AppNotice.error(context, '无法预览${result.title}');
    }
  }

  Future<void> _share(ExportMaterialResult result) async {
    final file = result.file;
    if (file == null) return;
    final shared = await _fileService.shareFile(
      file.uri,
      file.name,
      _fileService.getMimeType(file.name),
    );
    if (!shared && mounted) AppNotice.error(context, '分享${result.title}失败');
  }

  Future<void> _shareAll() async {
    final successfulResults = _successfulResults;
    if (_isSharingAll || successfulResults.isEmpty) return;
    setState(() => _isSharingAll = true);
    try {
      final shared = await _fileService.shareFiles(
        successfulResults.map((result) => result.file!).toList(growable: false),
      );
      if (!shared && mounted) AppNotice.error(context, '分享全部失败');
    } finally {
      if (mounted) setState(() => _isSharingAll = false);
    }
  }

  Future<void> _shareZip() async {
    final successfulResults = _successfulResults;
    if (_isCreatingZip || successfulResults.isEmpty) return;
    setState(() => _isCreatingZip = true);
    try {
      final zipFile = await (widget.zipBuilder ?? _buildZip)(successfulResults);
      if (!mounted) return;
      if (zipFile == null) {
        AppNotice.error(context, 'ZIP 打包失败');
        return;
      }
      final shared = await _fileService.shareFile(
        zipFile.uri,
        zipFile.name,
        'application/zip',
      );
      if (!shared && mounted) AppNotice.error(context, 'ZIP 分享失败');
    } catch (error, stackTrace) {
      logService.e(LogConfig.moduleFile, 'ZIP 打包失败', error, stackTrace);
      if (mounted) AppNotice.error(context, 'ZIP 打包失败');
    } finally {
      if (mounted) setState(() => _isCreatingZip = false);
    }
  }

  Future<DownloadedFileReference?> _buildZip(
    List<ExportMaterialResult> results,
  ) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final zipName = '报销材料_$timestamp.zip';
    final zipPath = path.join(widget.sessionDirectory.path, zipName);
    final encoder = ZipFileEncoder();
    encoder.create(zipPath);
    try {
      for (final result in results) {
        final source = File(result.previewPath!);
        if (!await source.exists() || await source.length() == 0) {
          throw FileSystemException('待打包文件不可用', source.path);
        }
        await encoder.addFile(source);
      }
    } finally {
      await encoder.close();
    }
    final zip = File(zipPath);
    if (!await zip.exists() || await zip.length() == 0) return null;
    return _fileService.copyToDownloadDirectoryReference(
      zip.path,
      customFileName: zipName,
      subDir: widget.subDir,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final successCount = _successfulResults.length;
    final failureCount = _results
        .where((result) => result.status == ExportMaterialStatus.failure)
        .length;
    final hasFailures = failureCount > 0;

    return PopScope(
      key: const ValueKey('export-completion-pop-scope'),
      canPop: !_isCreatingZip,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isCreatingZip) {
          AppNotice.info(context, '正在打包 ZIP，完成后即可返回');
        }
      },
      child: GlassPageScaffold(
        appBar: AppBar(title: const Text('导出完成')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            AppCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    hasFailures ? Icons.rule_folder_outlined : Icons.task_alt,
                    color: hasFailures
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasFailures ? '部分材料需要处理' : '材料已经归档',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$successCount 项成功'
                          '${hasFailures ? ' · $failureCount 项失败' : ''}'
                          ' · 已保存到下载目录',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '三项材料',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            ..._results.map(
              (result) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MaterialResultCard(
                  result: result,
                  retrying: _retrying.contains(result.type),
                  onRetry: () => _retry(result),
                  onOpen: () => _open(result),
                  onPreview: () => _preview(result),
                  onShare: () => _share(result),
                ),
              ),
            ),
            const SizedBox(height: 8),
            AppButton(
              text: '分享全部成功项',
              icon: const Icon(Icons.share_outlined, size: 19),
              isFullWidth: true,
              isLoading: _isSharingAll,
              onPressed: successCount == 0 ? null : _shareAll,
            ),
            const SizedBox(height: 10),
            AppButton(
              text: '打包 ZIP 后分享',
              icon: const Icon(Icons.folder_zip_outlined, size: 19),
              type: AppButtonType.outlined,
              isFullWidth: true,
              isLoading: _isCreatingZip,
              onPressed: successCount == 0 ? null : _shareZip,
            ),
            const SizedBox(height: 8),
            Text(
              'ZIP 仅在你主动选择时创建，不影响上方已导出的单个文件。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialResultCard extends StatelessWidget {
  final ExportMaterialResult result;
  final bool retrying;
  final VoidCallback onRetry;
  final VoidCallback onOpen;
  final VoidCallback onPreview;
  final VoidCallback onShare;

  const _MaterialResultCard({
    required this.result,
    required this.retrying,
    required this.onRetry,
    required this.onOpen,
    required this.onPreview,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isSuccess = result.status == ExportMaterialStatus.success;
    final isFailure = result.status == ExportMaterialStatus.failure;
    final (icon, color, label) = switch (result.status) {
      ExportMaterialStatus.success => (
        Icons.check_circle_outline,
        colors.primary,
        '已导出',
      ),
      ExportMaterialStatus.failure => (
        Icons.error_outline,
        colors.error,
        '导出失败',
      ),
      ExportMaterialStatus.notSelected => (
        Icons.remove_circle_outline,
        colors.onSurfaceVariant,
        '未选择',
      ),
    };

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(14),
      backgroundColor: isFailure
          ? colors.errorContainer.withValues(alpha: 0.24)
          : AppPalette.cardFillFor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                result.format,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (result.message case final message?) ...[
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isFailure ? colors.error : colors.onSurfaceVariant,
              ),
            ),
          ],
          if (isSuccess) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new, size: 17),
                  label: const Text('打开'),
                ),
                TextButton.icon(
                  onPressed: onPreview,
                  icon: const Icon(Icons.visibility_outlined, size: 17),
                  label: const Text('预览'),
                ),
                TextButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.share_outlined, size: 17),
                  label: const Text('分享'),
                ),
              ],
            ),
          ],
          if (isFailure) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: retrying ? null : onRetry,
                icon: retrying
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: Text(retrying ? '正在重试' : '重试'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

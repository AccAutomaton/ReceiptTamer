import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// Invoice image/PDF preview widget
class InvoiceImagePreview extends StatelessWidget {
  final String imagePath;
  final double? height;
  final double? width;
  final bool interactive;
  final VoidCallback? onTap;
  final Widget? placeholder;

  const InvoiceImagePreview({
    super.key,
    required this.imagePath,
    this.height,
    this.width,
    this.interactive = true,
    this.onTap,
    this.placeholder,
  });

  bool get isPdf => imagePath.toLowerCase().endsWith('.pdf');

  @override
  Widget build(BuildContext context) {
    if (isPdf) {
      return _buildPdfPreview(context);
    }
    return _buildImagePreview(context);
  }

  Widget _buildPdfPreview(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final file = File(imagePath);
    if (!file.existsSync()) {
      return _buildPlaceholder(
        context,
        Icons.broken_image,
        '文件不存在',
      );
    }

    return InkWell(
      onTap: onTap ??
          () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => FullScreenPdfPreview(
                  filePath: imagePath,
                ),
              ),
            );
          },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: height ?? 200,
        width: width,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.picture_as_pdf,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'PDF 文档',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '点击查看',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (interactive)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'PDF',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final file = File(imagePath);
    if (!file.existsSync()) {
      return _buildPlaceholder(
        context,
        Icons.broken_image,
        '图片不存在',
      );
    }

    final image = Image.file(
      file,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return _buildPlaceholder(
          context,
          Icons.error_outline,
          '加载失败',
          isError: true,
        );
      },
    );

    return GestureDetector(
      onTap: onTap ??
          () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => FullScreenImagePreview(
                  imagePath: imagePath,
                ),
              ),
            );
          },
      child: Container(
        height: height ?? 200,
        width: width,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: interactive
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: image,
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '双指缩放',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : image,
        ),
      ),
    );
  }

  Widget _buildPlaceholder(
    BuildContext context,
    IconData icon,
    String message, {
    bool isError = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: height ?? 200,
      width: width,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: isError ? colorScheme.error : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isError ? colorScheme.error : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full screen image preview
class FullScreenImagePreview extends StatelessWidget {
  final String imagePath;

  const FullScreenImagePreview({
    super.key,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    final file = File(imagePath);
    if (!file.existsSync()) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: Text(
            '图片不存在',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              try {
                await Share.shareXFiles(
                  [XFile(imagePath)],
                  text: '分享图片',
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('分享失败: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          Navigator.of(context).pop();
        },
        child: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 5.0,
            child: Image.file(
              file,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

/// Full screen PDF preview with SfPdfViewer
class FullScreenPdfPreview extends StatelessWidget {
  final String filePath;

  const FullScreenPdfPreview({
    super.key,
    required this.filePath,
  });

  @override
  Widget build(BuildContext context) {
    final file = File(filePath);
    if (!file.existsSync()) {
      return Scaffold(
        backgroundColor: Colors.grey[200],
        appBar: AppBar(
          title: const Text('PDF 预览'),
        ),
        body: const Center(
          child: Text('PDF文件不存在'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF 预览'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              try {
                await Share.shareXFiles(
                  [XFile(filePath)],
                  text: '分享PDF文档',
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('分享失败: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: SfPdfViewer.file(file),
    );
  }
}
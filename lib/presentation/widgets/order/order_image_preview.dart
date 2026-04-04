import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Order image preview widget with zoom and pan support
class OrderImagePreview extends StatefulWidget {
  final String imagePath;
  final double? height;
  final double? width;
  final bool interactive;
  final VoidCallback? onTap;
  final Widget? placeholder;

  const OrderImagePreview({
    super.key,
    required this.imagePath,
    this.height,
    this.width,
    this.interactive = true,
    this.onTap,
    this.placeholder,
  });

  @override
  State<OrderImagePreview> createState() => _OrderImagePreviewState();
}

class _OrderImagePreviewState extends State<OrderImagePreview> {
  final TransformationController _transformationController =
      TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final file = File(widget.imagePath);
    if (!file.existsSync()) {
      return Container(
        height: widget.height ?? 200,
        width: widget.width,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.broken_image,
                size: 48,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 8),
              Text(
                '图片不存在',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final image = Image.file(
      file,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          height: widget.height ?? 200,
          width: widget.width,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: colorScheme.error,
                ),
                const SizedBox(height: 8),
                Text(
                  '加载失败',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!widget.interactive) {
      return GestureDetector(
        onTap: widget.onTap ??
            () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => FullScreenImagePreview(
                    imagePath: widget.imagePath,
                  ),
                ),
              );
            },
        child: Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: image,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: widget.onTap ??
          () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => FullScreenImagePreview(
                  imagePath: widget.imagePath,
                ),
              ),
            );
          },
      child: Container(
        height: widget.height ?? 200,
        width: widget.width,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                transformationController: _transformationController,
                minScale: 0.5,
                maxScale: 4.0,
                child: image,
              ),
              // Zoom hint
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.zoom_in,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '双指缩放',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
                await SharePlus.instance.share(ShareParams(
                  files: [XFile(imagePath)],
                  subject: '分享订单图片',
                ));
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
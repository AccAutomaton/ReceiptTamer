import 'dart:math';
import 'package:flutter/material.dart';

/// Storage type definition
enum StorageType {
  images('图片', Colors.blue),
  pdfs('PDF', Colors.red),
  data('数据', Colors.green),
  model('模型', Colors.purple),
  cache('缓存', Colors.orange);

  final String label;
  final Color color;

  const StorageType(this.label, this.color);
}

/// Storage ring chart widget
/// Displays storage usage as a donut chart with total size in the center
/// Uses non-linear scaling to ensure small values are visible
class StorageRingChart extends StatelessWidget {
  final Map<String, int> storageData;
  final double size;
  final double strokeWidth;
  final double spacing;
  /// Minimum sweep angle for non-zero values (in radians)
  /// Ensures small values are visible even with large values present
  static const double _minSweepAngle = 0.15; // ~8.6 degrees

  const StorageRingChart({
    super.key,
    required this.storageData,
    this.size = 200,
    this.strokeWidth = 20,
    this.spacing = 2,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Calculate total
    final total = storageData.values.fold(0, (sum, value) => sum + value);

    // Build segments list
    final segments = _buildSegments();

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingChartPainter(
          segments: segments,
          strokeWidth: strokeWidth,
          spacing: spacing,
          backgroundColor: colorScheme.surfaceContainerHighest,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatSize(total),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '总计',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_ChartSegment> _buildSegments() {
    final segments = <_ChartSegment>[];

    // Count non-zero values
    final nonZeroCount = storageData.values.where((v) => v > 0).length;
    if (nonZeroCount == 0) return segments;

    final total = storageData.values.fold(0, (sum, value) => sum + value);
    if (total == 0) return segments;

    // Calculate total reserved angle for minimum sweeps
    final totalMinAngle = nonZeroCount * _minSweepAngle;
    // Remaining angle to distribute proportionally
    final remainingAngle = (2 * pi) - totalMinAngle;
    // Total value to distribute proportionally
    final totalValue = total;

    for (final type in StorageType.values) {
      final value = storageData[type.name] ?? 0;
      if (value > 0) {
        // Non-linear scaling: minimum angle + proportional angle
        final proportionalAngle = (value / totalValue) * remainingAngle;
        final sweepAngle = _minSweepAngle + proportionalAngle;

        segments.add(_ChartSegment(
          value: value,
          displayAngle: sweepAngle,
          color: type.color,
          label: type.label,
        ));
      }
    }

    return segments;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}

/// Chart segment data
class _ChartSegment {
  final int value;
  final double displayAngle;
  final Color color;
  final String label;

  _ChartSegment({
    required this.value,
    required this.displayAngle,
    required this.color,
    required this.label,
  });
}

/// Custom painter for ring chart
class _RingChartPainter extends CustomPainter {
  final List<_ChartSegment> segments;
  final double strokeWidth;
  final double spacing;
  final Color backgroundColor;

  _RingChartPainter({
    required this.segments,
    required this.strokeWidth,
    required this.spacing,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Draw background ring
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    canvas.drawCircle(center, radius, bgPaint);

    if (segments.isEmpty) return;

    // Draw segments using pre-calculated display angles
    final rect = Rect.fromCircle(center: center, radius: radius);
    double startAngle = -pi / 2; // Start from top

    for (final segment in segments) {
      final sweepAngle = segment.displayAngle;

      // Account for spacing between segments
      final adjustedSweep = sweepAngle - (spacing / radius);

      if (adjustedSweep > 0) {
        // Draw the arc with flat ends
        final paint = Paint()
          ..color = segment.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt;

        canvas.drawArc(
          rect,
          startAngle,
          adjustedSweep,
          false,
          paint,
        );
      }

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _RingChartPainter oldDelegate) {
    return segments != oldDelegate.segments ||
        strokeWidth != oldDelegate.strokeWidth ||
        spacing != oldDelegate.spacing ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}

/// Storage legend widget
class StorageLegend extends StatelessWidget {
  final Map<String, int> storageData;

  const StorageLegend({
    super.key,
    required this.storageData,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: StorageType.values.map((type) {
        final value = storageData[type.name] ?? 0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _LegendItem(
            color: type.color,
            label: type.label,
            value: _formatSize(value),
          ),
        );
      }).toList(),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: $value',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
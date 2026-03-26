import 'package:flutter/material.dart';

/// Custom receipt icon that adapts to theme
class ReceiptIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const ReceiptIcon({
    super.key,
    this.size = 48,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = color ?? colorScheme.primary;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ReceiptIconPainter(iconColor),
      ),
    );
  }
}

class _ReceiptIconPainter extends CustomPainter {
  final Color color;

  _ReceiptIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final scale = size.width / 512;
    final strokeWidth = 24 * scale;
    paint.strokeWidth = strokeWidth;

    final path = Path();

    // Receipt body with zigzag bottom (updated proportions)
    path.moveTo(136 * scale, 88 * scale);
    path.lineTo(376 * scale, 88 * scale);
    path.lineTo(376 * scale, 420 * scale);
    path.lineTo(336 * scale, 398 * scale);
    path.lineTo(304 * scale, 420 * scale);
    path.lineTo(272 * scale, 398 * scale);
    path.lineTo(240 * scale, 420 * scale);
    path.lineTo(208 * scale, 398 * scale);
    path.lineTo(176 * scale, 420 * scale);
    path.lineTo(136 * scale, 398 * scale);
    path.close();

    canvas.drawPath(path, paint);

    // Top decorative line
    paint.strokeWidth = 18 * scale;
    canvas.drawLine(
      Offset(172 * scale, 170 * scale),
      Offset(302 * scale, 170 * scale),
      paint,
    );

    // Text lines (lighter opacity)
    final lightPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 12 * scale;

    canvas.drawLine(
      Offset(172 * scale, 212 * scale),
      Offset(278 * scale, 212 * scale),
      lightPaint,
    );
    canvas.drawLine(
      Offset(172 * scale, 244 * scale),
      Offset(252 * scale, 244 * scale),
      lightPaint,
    );
    canvas.drawLine(
      Offset(172 * scale, 276 * scale),
      Offset(226 * scale, 276 * scale),
      lightPaint,
    );

    // Total amount line (emphasized)
    paint.strokeWidth = 15 * scale;
    canvas.drawLine(
      Offset(172 * scale, 320 * scale),
      Offset(302 * scale, 320 * scale),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ReceiptIconPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}
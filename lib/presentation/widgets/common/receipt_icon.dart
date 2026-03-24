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
    final strokeWidth = 16 * scale;
    paint.strokeWidth = strokeWidth;

    final path = Path();

    // Receipt body with zigzag bottom
    path.moveTo(160 * scale, 100 * scale);
    path.lineTo(352 * scale, 100 * scale);
    path.lineTo(352 * scale, 380 * scale);
    path.lineTo(320 * scale, 360 * scale);
    path.lineTo(288 * scale, 380 * scale);
    path.lineTo(256 * scale, 360 * scale);
    path.lineTo(224 * scale, 380 * scale);
    path.lineTo(192 * scale, 360 * scale);
    path.lineTo(160 * scale, 380 * scale);
    path.close();

    canvas.drawPath(path, paint);

    // Top decorative line
    paint.strokeWidth = 12 * scale;
    canvas.drawLine(
      Offset(200 * scale, 160 * scale),
      Offset(312 * scale, 160 * scale),
      paint,
    );

    // Text lines (lighter opacity)
    paint.strokeWidth = 8 * scale;
    final lightPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(200 * scale, 210 * scale),
      Offset(300 * scale, 210 * scale),
      lightPaint,
    );
    canvas.drawLine(
      Offset(200 * scale, 245 * scale),
      Offset(280 * scale, 245 * scale),
      lightPaint,
    );
    canvas.drawLine(
      Offset(200 * scale, 280 * scale),
      Offset(260 * scale, 280 * scale),
      lightPaint,
    );

    // Total amount line (emphasized)
    paint.strokeWidth = 10 * scale;
    canvas.drawLine(
      Offset(200 * scale, 330 * scale),
      Offset(312 * scale, 330 * scale),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ReceiptIconPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}
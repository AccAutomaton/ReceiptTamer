import 'package:flutter/material.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';

class LiquidGlassEdge extends StatelessWidget {
  const LiquidGlassEdge({
    super.key,
    required this.borderRadius,
    required this.child,
  });

  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: LiquidGlassEdgePainter(
        borderRadius: borderRadius,
        isDark: Theme.of(context).brightness == Brightness.dark,
      ),
      child: child,
    );
  }
}

class LiquidGlassEdgePainter extends CustomPainter {
  const LiquidGlassEdgePainter({
    required this.borderRadius,
    required this.isDark,
  });

  final BorderRadius borderRadius;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final rect = Offset.zero & size;
    final radius = borderRadius.resolve(TextDirection.ltr).topLeft;
    final outerRadius = Radius.circular(
      (radius.x + 1.8).clamp(0, size.shortestSide / 2),
    );
    final outerRRect = RRect.fromRectAndRadius(rect.inflate(1.8), outerRadius);

    final softWhite = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..color = Colors.white.withValues(alpha: isDark ? 0.06 : 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.5);
    canvas.drawRRect(outerRRect, softWhite);

    final refraction = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: isDark ? 0.08 : 0.28),
          Colors.white.withValues(alpha: isDark ? 0.02 : 0.07),
          AppPalette.primaryMuted.withValues(alpha: isDark ? 0.04 : 0.09),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0, 0.38, 0.74, 1],
      ).createShader(rect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4);
    canvas.drawRRect(outerRRect.deflate(0.4), refraction);
  }

  @override
  bool shouldRepaint(LiquidGlassEdgePainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.isDark != isDark;
  }
}

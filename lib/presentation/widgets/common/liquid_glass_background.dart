import 'package:flutter/material.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';

class LiquidGlassBackground extends StatelessWidget {
  const LiquidGlassBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF101820), Color(0xFF17232B)]
              : const [
                  AppPalette.coldBackground,
                  Color(0xFFEFF5F7),
                  Color(0xFFF8FAFA),
                ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _LiquidGlassBackgroundPainter(isDark: isDark),
              ),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _LiquidGlassBackgroundPainter extends CustomPainter {
  const _LiquidGlassBackgroundPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    _drawMist(canvas, rect, Alignment.topRight, isDark ? 0.06 : 0.18);
    _drawMist(canvas, rect, Alignment.bottomLeft, isDark ? 0.04 : 0.12);

    final veilPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: isDark ? 0.00 : 0.16),
          Colors.white.withValues(alpha: 0),
          AppPalette.coldBackground.withValues(alpha: isDark ? 0.00 : 0.36),
        ],
        stops: const [0, 0.46, 1],
      ).createShader(rect);
    canvas.drawRect(rect, veilPaint);
  }

  void _drawMist(Canvas canvas, Rect rect, Alignment center, double opacity) {
    final paint = Paint()
      ..shader = RadialGradient(
        center: center,
        radius: 0.88,
        colors: [
          AppPalette.mistBlue.withValues(alpha: opacity),
          Colors.white.withValues(alpha: opacity * 0.55),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0, 0.46, 1],
      ).createShader(rect);

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_LiquidGlassBackgroundPainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}

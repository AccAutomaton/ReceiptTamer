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
          Positioned.fill(child: _LiquidGlassBackdrop(isDark: isDark)),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _LiquidGlassBackdrop extends StatelessWidget {
  const _LiquidGlassBackdrop({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topRight,
                radius: 0.88,
                colors: [
                  AppPalette.mistBlue.withValues(alpha: isDark ? 0.06 : 0.18),
                  Colors.white.withValues(alpha: isDark ? 0.03 : 0.10),
                  Colors.white.withValues(alpha: 0),
                ],
                stops: const [0, 0.46, 1],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.bottomLeft,
                radius: 0.88,
                colors: [
                  AppPalette.mistBlue.withValues(alpha: isDark ? 0.04 : 0.12),
                  Colors.white.withValues(alpha: isDark ? 0.02 : 0.07),
                  Colors.white.withValues(alpha: 0),
                ],
                stops: const [0, 0.46, 1],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: isDark ? 0.00 : 0.16),
                  Colors.white.withValues(alpha: 0),
                  AppPalette.coldBackground.withValues(
                    alpha: isDark ? 0.00 : 0.36,
                  ),
                ],
                stops: const [0, 0.46, 1],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

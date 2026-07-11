import 'package:flutter/material.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';

class LiquidGlassBackground extends StatelessWidget {
  const LiquidGlassBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              colors.primary.withValues(alpha: isDark ? 0.035 : 0.045),
              colors.surface,
            ),
            colors.surface,
            Color.alphaBlend(
              colors.surfaceContainerHigh.withValues(
                alpha: isDark ? 0.16 : 0.34,
              ),
              colors.surface,
            ),
          ],
        ),
      ),
      child: BackdropGroup(
        child: Stack(
          children: [
            Positioned.fill(child: _LiquidGlassBackdrop(isDark: isDark)),
            Positioned.fill(child: child),
          ],
        ),
      ),
    );
  }
}

class _LiquidGlassBackdrop extends StatelessWidget {
  const _LiquidGlassBackdrop({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topRight,
                radius: 0.88,
                colors: [
                  colors.primary.withValues(alpha: isDark ? 0.055 : 0.075),
                  colors.primaryContainer.withValues(
                    alpha: isDark ? 0.025 : 0.07,
                  ),
                  colors.primaryContainer.withValues(alpha: 0),
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
                  AppPalette.skyAccent.withValues(alpha: isDark ? 0.045 : 0.12),
                  colors.surfaceContainerLow.withValues(
                    alpha: isDark ? 0.02 : 0.08,
                  ),
                  colors.surfaceContainerLow.withValues(alpha: 0),
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
                  Colors.white.withValues(alpha: isDark ? 0.00 : 0.10),
                  Colors.white.withValues(alpha: 0),
                  colors.surfaceContainerHigh.withValues(
                    alpha: isDark ? 0.00 : 0.18,
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

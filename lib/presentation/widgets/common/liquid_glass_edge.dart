import 'package:flutter/material.dart';

class LiquidGlassEdge extends StatelessWidget {
  const LiquidGlassEdge({
    super.key,
    required this.borderRadius,
    required this.child,
    this.edgeIntensity = 1,
  }) : assert(
         edgeIntensity >= 0 && edgeIntensity <= 1,
         'edgeIntensity must be between 0 and 1.',
       );

  final BorderRadius borderRadius;
  final double edgeIntensity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    final softGlow = (isDark ? Colors.black : colors.primary).withValues(
      alpha: (isDark ? 0.12 : 0.035) * edgeIntensity,
    );
    final edgeColor = Color.alphaBlend(
      Colors.white.withValues(alpha: isDark ? 0.06 : 0.42),
      colors.outlineVariant,
    );

    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                boxShadow: [
                  BoxShadow(
                    color: softGlow,
                    blurRadius: 8 * edgeIntensity,
                    spreadRadius: -2 * edgeIntensity,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                border: Border.all(
                  color: edgeColor.withValues(alpha: edgeIntensity),
                  width: 0.8,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(
                      alpha: (isDark ? 0.035 : 0.12) * edgeIntensity,
                    ),
                    Colors.white.withValues(
                      alpha: (isDark ? 0.01 : 0.025) * edgeIntensity,
                    ),
                    Colors.white.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

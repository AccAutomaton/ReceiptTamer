import 'package:flutter/material.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';

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
    final softGlow = Colors.white.withValues(
      alpha: (isDark ? 0.04 : 0.14) * edgeIntensity,
    );
    final edgeTint = AppPalette.primaryMuted.withValues(
      alpha: (isDark ? 0.05 : 0.10) * edgeIntensity,
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
                    blurRadius: 10 * edgeIntensity,
                    spreadRadius: edgeIntensity,
                    offset: const Offset(0, -1),
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
                  color: Colors.white.withValues(
                    alpha: (isDark ? 0.07 : 0.24) * edgeIntensity,
                  ),
                  width: 0.8,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(
                      alpha: (isDark ? 0.08 : 0.30) * edgeIntensity,
                    ),
                    Colors.white.withValues(
                      alpha: (isDark ? 0.02 : 0.06) * edgeIntensity,
                    ),
                    edgeTint,
                    Colors.white.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.42, 0.78, 1],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

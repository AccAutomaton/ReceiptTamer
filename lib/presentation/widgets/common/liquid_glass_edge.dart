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
    final colors = Theme.of(context).colorScheme;

    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: edgeIntensity),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/presentation/widgets/common/liquid_glass_edge.dart';

enum GlassSurfacePreset { panel, sheet, dialog }

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
    this.margin,
    this.fillColor,
    this.borderColor,
    this.blurSigma = AppGlassTokens.blurSigma,
    this.boxShadow,
    this.showHighlights = true,
    this.preset = GlassSurfacePreset.panel,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? fillColor;
  final Color? borderColor;
  final double blurSigma;
  final List<BoxShadow>? boxShadow;
  final bool showHighlights;
  final GlassSurfacePreset preset;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius =
        borderRadius ?? BorderRadius.circular(AppRadii.glassLarge);
    final effectiveFill = fillColor ?? AppGlassTokens.panelFillFor(context);
    final content = Padding(padding: padding ?? EdgeInsets.zero, child: child);

    final fallback = _GlassSurfaceFallback(
      borderRadius: effectiveRadius,
      fillColor: effectiveFill,
      borderColor: borderColor,
      blurSigma: blurSigma,
      boxShadow: boxShadow,
      showHighlights: showHighlights,
      child: content,
    );

    return Padding(padding: margin ?? EdgeInsets.zero, child: fallback);
  }
}

class _GlassSurfaceFallback extends StatelessWidget {
  const _GlassSurfaceFallback({
    required this.borderRadius,
    required this.fillColor,
    required this.child,
    this.borderColor,
    this.blurSigma = AppGlassTokens.blurSigma,
    this.boxShadow,
    this.showHighlights = true,
  });

  final BorderRadius borderRadius;
  final Color fillColor;
  final Color? borderColor;
  final double blurSigma;
  final List<BoxShadow>? boxShadow;
  final bool showHighlights;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final explicitBorder = borderColor == null
        ? null
        : Border.all(
            color: borderColor!.withValues(alpha: isDark ? 0.08 : 0.14),
            width: 0.5,
          );

    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: boxShadow ?? AppShadows.glass,
      ),
      child: LiquidGlassEdge(
        borderRadius: borderRadius,
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: fillColor,
                      borderRadius: borderRadius,
                      border: explicitBorder,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          fillColor,
                          Color.alphaBlend(
                            AppGlassTokens.refractionTint,
                            fillColor,
                          ),
                          fillColor,
                        ],
                        stops: const [0, 0.58, 1],
                      ),
                    ),
                  ),
                ),
                if (showHighlights)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: borderRadius,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(
                              alpha: isDark ? 0.08 : 0.34,
                            ),
                            Colors.white.withValues(
                              alpha: isDark ? 0.01 : 0.05,
                            ),
                            AppPalette.frostLine.withValues(
                              alpha: isDark ? 0.02 : 0.08,
                            ),
                          ],
                          stops: const [0, 0.48, 1],
                        ),
                      ),
                    ),
                  ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

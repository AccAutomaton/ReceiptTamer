import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';

enum GlassSurfacePreset { panel, floating, navigation, sheet, dialog }

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
    this.edgeIntensity = 1,
    this.preset = GlassSurfacePreset.panel,
  }) : assert(
         edgeIntensity >= 0 && edgeIntensity <= 1,
         'edgeIntensity must be between 0 and 1.',
       );

  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? fillColor;
  final Color? borderColor;
  final double blurSigma;
  final List<BoxShadow>? boxShadow;
  final bool showHighlights;
  final double edgeIntensity;
  final GlassSurfacePreset preset;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius =
        borderRadius ?? BorderRadius.circular(AppRadii.glassLarge);
    final requestedFill =
        fillColor ??
        switch (preset) {
          GlassSurfacePreset.panel => AppEntityTokens.fillFor(context),
          GlassSurfacePreset.floating ||
          GlassSurfacePreset.navigation => AppGlassTokens.panelFillFor(context),
          GlassSurfacePreset.sheet ||
          GlassSurfacePreset.dialog => AppGlassTokens.sheetFillFor(context),
        };
    // Frozen ce04b3c content widgets can still pass legacy translucent fills
    // to the panel preset. Pre-composite those colors onto entity paper so
    // ordinary rows stay fully opaque without changing business widgets.
    final effectiveFill =
        preset == GlassSurfacePreset.panel && requestedFill.a < 1
        ? Color.alphaBlend(requestedFill, AppEntityTokens.fillFor(context))
        : requestedFill;
    final content = Padding(padding: padding ?? EdgeInsets.zero, child: child);

    final fallback = _GlassSurfaceFallback(
      borderRadius: effectiveRadius,
      fillColor: effectiveFill,
      borderColor: borderColor,
      blurSigma: blurSigma,
      preset: preset,
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
    this.preset = GlassSurfacePreset.panel,
  });

  final BorderRadius borderRadius;
  final Color fillColor;
  final Color? borderColor;
  final double blurSigma;
  final GlassSurfacePreset preset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFloating = preset != GlassSurfacePreset.panel;
    final effectiveBorder =
        borderColor ??
        (isFloating
            ? (isDark ? AppGlassTokens.darkBorder : AppGlassTokens.lightBorder)
            : AppEntityTokens.borderFor(context));
    final surfaceBody = DecoratedBox(
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: borderRadius,
        border: Border.all(color: effectiveBorder),
      ),
      child: child,
    );
    final effectiveBlurSigma = blurSigma.clamp(0.0, 12.0).toDouble();
    final clippedBody = !isFloating || effectiveBlurSigma <= 0
        ? surfaceBody
        : BackdropFilter.grouped(
            filter: ImageFilter.blur(
              sigmaX: effectiveBlurSigma,
              sigmaY: effectiveBlurSigma,
            ),
            child: surfaceBody,
          );

    return ClipRRect(borderRadius: borderRadius, child: clippedBody);
  }
}

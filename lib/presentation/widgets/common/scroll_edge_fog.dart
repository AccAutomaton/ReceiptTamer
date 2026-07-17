import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Paints quiet paper-colored fades over the edges of a scrolling viewport.
///
/// The default mode paints linear gradients above [child] in a [Stack] and
/// lets every pointer event pass through. Transparent page shells can opt into
/// [fadeTopToTransparent], which applies one viewport-sized alpha mask at the
/// top so the real background shows through instead of introducing a solid
/// color band. Insets in the default mode remain opaque protected zones.
class ScrollEdgeFog extends StatelessWidget {
  const ScrollEdgeFog({
    super.key,
    required this.child,
    this.showTop = true,
    this.showBottom = true,
    this.topHeight = 28,
    this.bottomHeight = 56,
    this.topInset = 0,
    this.bottomInset = 0,
    this.fogColor,
    this.fadeTopToTransparent = false,
  }) : assert(topHeight >= 0 && topHeight < double.infinity),
       assert(bottomHeight >= 0 && bottomHeight < double.infinity),
       assert(topInset >= 0 && topInset < double.infinity),
       assert(bottomInset >= 0 && bottomInset < double.infinity);

  static const topFogKey = ValueKey<String>('scroll-edge-fog-top');
  static const bottomFogKey = ValueKey<String>('scroll-edge-fog-bottom');
  static const topGuardKey = ValueKey<String>('scroll-edge-fog-top-guard');
  static const topTransparencyMaskKey = ValueKey<String>(
    'scroll-edge-fog-top-transparency-mask',
  );
  static const bottomGuardKey = ValueKey<String>(
    'scroll-edge-fog-bottom-guard',
  );

  final Widget child;
  final bool showTop;
  final bool showBottom;
  final double topHeight;
  final double bottomHeight;
  final double topInset;
  final double bottomInset;

  /// Reveals the real page background by fading the scrolling content itself
  /// at the top edge instead of painting an opaque paper-colored gradient.
  ///
  /// This is intended for transparent page shells where a solid fog color
  /// would create a visible horizontal band. Keep refresh or other overlay
  /// controls outside this widget so only scrolling content is faded. The
  /// bottom fog remains unchanged.
  final bool fadeTopToTransparent;

  /// The solid color at the outer edge of each fade.
  ///
  /// Defaults to the current scaffold background so callers only need to set
  /// this when their scroll viewport uses a different paper color.
  final Color? fogColor;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = fogColor ?? Theme.of(context).scaffoldBackgroundColor;
    final useTransparentTopFade =
        showTop && fadeTopToTransparent && topHeight > 0;
    final content = useTransparentTopFade
        ? ShaderMask(
            key: topTransparencyMaskKey,
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) {
              final start = Offset(bounds.left, bounds.top + topInset);
              final end = Offset(
                bounds.left,
                bounds.top + topInset + topHeight,
              );

              return ui.Gradient.linear(
                start,
                end,
                const [Color(0x00000000), Color(0x2E000000), Color(0xFF000000)],
                const [0, 0.38, 1],
                TileMode.clamp,
              );
            },
            child: child,
          )
        : child;

    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.hardEdge,
      children: [
        content,
        if (showTop && !useTransparentTopFade && topInset > 0)
          Positioned(
            key: topGuardKey,
            top: 0,
            left: 0,
            right: 0,
            height: topInset,
            child: _FogGuard(color: resolvedColor),
          ),
        if (showTop && !useTransparentTopFade)
          Positioned(
            key: topFogKey,
            top: topInset,
            left: 0,
            right: 0,
            height: topHeight,
            child: _FogLayer(color: resolvedColor, edge: Alignment.topCenter),
          ),
        if (showBottom && bottomInset > 0)
          Positioned(
            key: bottomGuardKey,
            bottom: 0,
            left: 0,
            right: 0,
            height: bottomInset,
            child: _FogGuard(color: resolvedColor),
          ),
        if (showBottom)
          Positioned(
            key: bottomFogKey,
            bottom: bottomInset,
            left: 0,
            right: 0,
            height: bottomHeight,
            child: _FogLayer(
              color: resolvedColor,
              edge: Alignment.bottomCenter,
            ),
          ),
      ],
    );
  }
}

class _FogGuard extends StatelessWidget {
  const _FogGuard({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(child: ColoredBox(color: color)),
    );
  }
}

class _FogLayer extends StatelessWidget {
  const _FogLayer({required this.color, required this.edge});

  final Color color;
  final Alignment edge;

  @override
  Widget build(BuildContext context) {
    final transparent = color.withValues(alpha: 0);
    final softened = color.withValues(alpha: color.a * 0.82);

    return IgnorePointer(
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: edge,
              end: edge == Alignment.topCenter
                  ? Alignment.bottomCenter
                  : Alignment.topCenter,
              colors: [color, softened, transparent],
              stops: const [0, 0.38, 1],
            ),
          ),
        ),
      ),
    );
  }
}

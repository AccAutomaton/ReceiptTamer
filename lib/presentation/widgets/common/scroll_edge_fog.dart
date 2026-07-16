import 'package:flutter/material.dart';

/// Paints quiet paper-colored fades over the edges of a scrolling viewport.
///
/// [ScrollEdgeFog] deliberately does not own or mask the scrollable. The fog
/// sits above [child] in a [Stack], lets every pointer event pass through, and
/// uses only linear gradients. This keeps long ledgers inexpensive while still
/// letting fixed controls feel visually separate from the content beneath.
/// Insets are opaque protected zones: scrolling content fades out before a
/// fixed control instead of remaining visible behind it.
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
  }) : assert(topHeight >= 0 && topHeight < double.infinity),
       assert(bottomHeight >= 0 && bottomHeight < double.infinity),
       assert(topInset >= 0 && topInset < double.infinity),
       assert(bottomInset >= 0 && bottomInset < double.infinity);

  static const topFogKey = ValueKey<String>('scroll-edge-fog-top');
  static const bottomFogKey = ValueKey<String>('scroll-edge-fog-bottom');
  static const topGuardKey = ValueKey<String>('scroll-edge-fog-top-guard');
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

  /// The solid color at the outer edge of each fade.
  ///
  /// Defaults to the current scaffold background so callers only need to set
  /// this when their scroll viewport uses a different paper color.
  final Color? fogColor;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = fogColor ?? Theme.of(context).scaffoldBackgroundColor;

    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.hardEdge,
      children: [
        child,
        if (showTop && topInset > 0)
          Positioned(
            key: topGuardKey,
            top: 0,
            left: 0,
            right: 0,
            height: topInset,
            child: _FogGuard(color: resolvedColor),
          ),
        if (showTop)
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

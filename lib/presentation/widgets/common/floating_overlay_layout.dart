import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_surface.dart';

typedef FloatingOverlayBodyBuilder =
    Widget Function(BuildContext context, EdgeInsets contentPadding);

class FloatingOverlayLayout extends StatefulWidget {
  const FloatingOverlayLayout({
    super.key,
    required this.bodyBuilder,
    this.top,
    this.bottom,
    this.topMargin = const EdgeInsets.fromLTRB(12, 8, 12, 0),
    this.bottomMargin = const EdgeInsets.fromLTRB(12, 0, 12, 12),
    this.overlayPadding = const EdgeInsets.all(12),
    this.topSpacing = 8,
    this.bottomSpacing = 8,
  });

  final FloatingOverlayBodyBuilder bodyBuilder;
  final Widget? top;
  final Widget? bottom;
  final EdgeInsetsGeometry topMargin;
  final EdgeInsetsGeometry bottomMargin;
  final EdgeInsetsGeometry overlayPadding;
  final double topSpacing;
  final double bottomSpacing;

  @override
  State<FloatingOverlayLayout> createState() => _FloatingOverlayLayoutState();
}

class _FloatingOverlayLayoutState extends State<FloatingOverlayLayout> {
  double _topHeight = 0;
  double _bottomHeight = 0;

  void _setTopSize(Size size) {
    if ((size.height - _topHeight).abs() < 0.5) return;
    setState(() => _topHeight = size.height);
  }

  void _setBottomSize(Size size) {
    if ((size.height - _bottomHeight).abs() < 0.5) return;
    setState(() => _bottomHeight = size.height);
  }

  @override
  Widget build(BuildContext context) {
    final contentPadding = EdgeInsets.only(
      top: widget.top == null ? 0 : _topHeight + widget.topSpacing,
      bottom: widget.bottom == null ? 0 : _bottomHeight + widget.bottomSpacing,
    );

    return Stack(
      children: [
        Positioned.fill(child: widget.bodyBuilder(context, contentPadding)),
        if (widget.top != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _MeasureSize(
              onChange: _setTopSize,
              child: _buildOverlaySurface(
                context: context,
                margin: widget.topMargin,
                child: widget.top!,
              ),
            ),
          ),
        if (widget.bottom != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _MeasureSize(
              onChange: _setBottomSize,
              child: _buildOverlaySurface(
                context: context,
                margin: _bottomMarginFor(context),
                child: widget.bottom!,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOverlaySurface({
    required BuildContext context,
    required EdgeInsetsGeometry margin,
    required Widget child,
  }) {
    return GlassSurface(
      margin: margin,
      padding: widget.overlayPadding,
      fillColor: AppGlassTokens.panelFillFor(context),
      borderRadius: BorderRadius.circular(AppRadii.card),
      boxShadow: AppShadows.glass,
      child: child,
    );
  }

  EdgeInsetsGeometry _bottomMarginFor(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    if (bottomInset == 0) return widget.bottomMargin;

    final textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final margin = widget.bottomMargin.resolve(textDirection);
    return margin.copyWith(bottom: margin.bottom + bottomInset);
  }
}

class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({required this.onChange, required super.child});

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderMeasureSize(onChange);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderMeasureSize renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize(this.onChange);

  ValueChanged<Size> onChange;
  Size? _oldSize;

  @override
  void performLayout() {
    super.performLayout();

    final newSize = child?.size ?? Size.zero;
    if (_oldSize == newSize) return;
    _oldSize = newSize;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) {
        onChange(newSize);
      }
    });
  }
}

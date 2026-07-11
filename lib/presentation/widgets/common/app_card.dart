import 'package:flutter/material.dart';

import 'package:receipt_tamer/core/theme/app_design_tokens.dart';

/// Opaque filing surface with a restrained highlight, ridge and press depth.
class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;
  final List<BoxShadow>? boxShadow;
  final BorderSide? borderSide;
  final BorderRadius? borderRadius;
  final bool semanticContainer;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.onLongPress,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.boxShadow,
    this.borderSide,
    this.borderRadius,
    this.semanticContainer = true,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isInteractive = widget.onTap != null || widget.onLongPress != null;
    final entityFill = AppEntityTokens.fillFor(context);
    final requestedBackgroundColor = widget.backgroundColor ?? entityFill;
    final effectiveBackgroundColor = requestedBackgroundColor.a < 1
        ? Color.alphaBlend(requestedBackgroundColor, entityFill)
        : requestedBackgroundColor;
    final effectivePadding =
        widget.padding ??
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    final effectiveMargin =
        widget.margin ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 6);
    final effectiveBorderRadius =
        widget.borderRadius ?? BorderRadius.circular(AppRadii.card);
    final effectiveBorderSide =
        widget.borderSide ??
        BorderSide(color: AppEntityTokens.borderFor(context));
    final effectiveShadows =
        widget.boxShadow ??
        (widget.elevation == null
            ? AppEntityTokens.shadowFor(context)
            : widget.elevation! > 0
            ? [
                BoxShadow(
                  color: Theme.of(context).colorScheme.shadow.withValues(
                    alpha: AppPalette.isDark(context) ? 0.46 : 0.14,
                  ),
                  blurRadius: widget.elevation! * 3.2,
                  spreadRadius: -widget.elevation!,
                  offset: Offset(0, widget.elevation!),
                ),
              ]
            : null);

    Widget content = Padding(padding: effectivePadding, child: widget.child);
    if (widget.foregroundColor != null) {
      content = IconTheme.merge(
        data: IconThemeData(color: widget.foregroundColor),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: widget.foregroundColor),
          child: content,
        ),
      );
    }

    final card = _AppCardChrome(
      borderRadius: effectiveBorderRadius,
      backgroundColor: effectiveBackgroundColor,
      borderSide: effectiveBorderSide,
      shadows: effectiveShadows,
      highlightColor: AppEntityTokens.highlightFor(context),
      ridgeColor: AppEntityTokens.ridgeFor(context),
      child: content,
    );

    Widget interactiveCard = _withInk(card, effectiveBorderRadius);
    if (isInteractive) {
      final duration = AppMotion.adaptive(context, AppMotion.fast);
      final pressedVisual = _isPressed && !AppMotion.reduceMotion(context);
      interactiveCard = AnimatedSlide(
        duration: duration,
        curve: AppMotion.curve,
        offset: pressedVisual ? const Offset(0, 0.018) : Offset.zero,
        child: AnimatedScale(
          duration: duration,
          curve: AppMotion.curve,
          scale: pressedVisual ? 0.985 : 1,
          child: interactiveCard,
        ),
      );
    }

    return Padding(padding: effectiveMargin, child: interactiveCard);
  }

  Widget _withInk(Widget child, BorderRadius borderRadius) {
    if (widget.onTap == null && widget.onLongPress == null) return child;

    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            borderRadius: borderRadius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              onLongPress: widget.onLongPress,
              onHighlightChanged: (value) {
                if (!mounted || _isPressed == value) return;
                setState(() => _isPressed = value);
              },
              borderRadius: borderRadius,
            ),
          ),
        ),
      ],
    );
  }
}

class _AppCardChrome extends StatelessWidget {
  const _AppCardChrome({
    required this.borderRadius,
    required this.backgroundColor,
    required this.borderSide,
    required this.shadows,
    required this.highlightColor,
    required this.ridgeColor,
    required this.child,
  });

  final BorderRadius borderRadius;
  final Color backgroundColor;
  final BorderSide borderSide;
  final List<BoxShadow>? shadows;
  final Color highlightColor;
  final Color ridgeColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: backgroundColor,
      borderRadius: borderRadius,
      border: borderSide == BorderSide.none
          ? null
          : Border.fromBorderSide(borderSide),
      boxShadow: shadows,
    );

    return Stack(
      fit: StackFit.passthrough,
      children: [
        DecoratedBox(decoration: decoration, child: child),
        Positioned(
          top: 1,
          left: borderRadius.topLeft.x,
          right: borderRadius.topRight.x,
          height: 1,
          child: IgnorePointer(child: ColoredBox(color: highlightColor)),
        ),
        Positioned(
          right: borderRadius.bottomRight.x * 0.72,
          bottom: 0,
          left: borderRadius.bottomLeft.x * 0.72,
          height: 2,
          child: IgnorePointer(child: ColoredBox(color: ridgeColor)),
        ),
      ],
    );
  }
}

/// App Card with a header
class AppCardWithHeader extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? leading;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const AppCardWithHeader({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.leading,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final effectiveForegroundColor = foregroundColor ?? colorScheme.onSurface;

    return AppCard(
      margin: margin,
      padding: EdgeInsets.zero,
      onTap: onTap,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                AppPalette.actionSoftFillFor(context, alpha: 0.3),
                AppEntityTokens.fillFor(context),
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadii.card),
                topRight: Radius.circular(AppRadii.card),
              ),
            ),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 8)],
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: effectiveForegroundColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (actions != null) ...actions!,
              ],
            ),
          ),
          // Content
          Padding(padding: padding ?? const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

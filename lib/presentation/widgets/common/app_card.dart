import 'package:flutter/material.dart';

import 'package:receipt_tamer/core/theme/app_design_tokens.dart';

/// Opaque flat filing surface with a uniform outline.
class AppCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final entityFill = AppEntityTokens.fillFor(context);
    final requestedBackgroundColor = backgroundColor ?? entityFill;
    final effectiveBackgroundColor = requestedBackgroundColor.a < 1
        ? Color.alphaBlend(requestedBackgroundColor, entityFill)
        : requestedBackgroundColor;
    final effectivePadding =
        padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    final effectiveMargin =
        margin ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 6);
    final effectiveBorderRadius =
        borderRadius ?? BorderRadius.circular(AppRadii.card);
    final effectiveBorderSide =
        borderSide ?? BorderSide(color: AppEntityTokens.borderFor(context));

    Widget content = Padding(padding: effectivePadding, child: child);
    if (foregroundColor != null) {
      content = IconTheme.merge(
        data: IconThemeData(color: foregroundColor),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: foregroundColor),
          child: content,
        ),
      );
    }

    final card = _AppCardChrome(
      borderRadius: effectiveBorderRadius,
      backgroundColor: effectiveBackgroundColor,
      borderSide: effectiveBorderSide,
      child: content,
    );

    return Semantics(
      container: semanticContainer,
      child: Padding(
        padding: effectiveMargin,
        child: _withInk(card, effectiveBorderRadius),
      ),
    );
  }

  Widget _withInk(Widget child, BorderRadius borderRadius) {
    if (onTap == null && onLongPress == null) return child;

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
              onTap: onTap,
              onLongPress: onLongPress,
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
    required this.child,
  });

  final BorderRadius borderRadius;
  final Color backgroundColor;
  final BorderSide borderSide;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        border: borderSide == BorderSide.none
            ? null
            : Border.fromBorderSide(borderSide),
      ),
      child: child,
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

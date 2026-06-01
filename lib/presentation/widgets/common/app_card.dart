import 'package:flutter/material.dart';

import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/presentation/widgets/common/liquid_glass_edge.dart';

/// App Card - Material 3 style card widget with consistent styling
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;
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
    this.borderSide,
    this.borderRadius,
    this.semanticContainer = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor =
        backgroundColor ?? AppGlassTokens.contentFill;
    final effectivePadding =
        padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    final effectiveMargin =
        margin ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 6);
    final effectiveBorderRadius =
        borderRadius ?? BorderRadius.circular(AppRadii.card);
    final effectiveBorderSide = borderSide ?? BorderSide.none;
    final effectiveShadows = elevation == null
        ? AppShadows.card
        : elevation! > 0
        ? [
            BoxShadow(
              color: AppPalette.shadowMuted,
              blurRadius: elevation! * 2.8,
              offset: Offset(0, elevation!),
            ),
          ]
        : null;

    final content = Padding(padding: effectivePadding, child: child);

    final card = _AppCardChrome(
      borderRadius: effectiveBorderRadius,
      backgroundColor: effectiveBackgroundColor,
      borderSide: effectiveBorderSide,
      shadows: effectiveShadows,
      child: content,
    );

    return Padding(
      padding: effectiveMargin,
      child: _withInk(card, effectiveBorderRadius),
    );
  }

  Widget _withInk(Widget child, BorderRadius borderRadius) {
    if (onTap == null && onLongPress == null) return child;

    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: borderRadius,
        child: child,
      ),
    );
  }
}

class _AppCardChrome extends StatelessWidget {
  const _AppCardChrome({
    required this.borderRadius,
    required this.backgroundColor,
    required this.borderSide,
    required this.shadows,
    required this.child,
  });

  final BorderRadius borderRadius;
  final Color backgroundColor;
  final BorderSide borderSide;
  final List<BoxShadow>? shadows;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: backgroundColor,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          backgroundColor,
          Color.alphaBlend(AppGlassTokens.refractionTint, backgroundColor),
          backgroundColor.withValues(alpha: backgroundColor.a * 0.92),
        ],
        stops: const [0, 0.62, 1],
      ),
      borderRadius: borderRadius,
      border: borderSide == BorderSide.none
          ? null
          : Border.fromBorderSide(borderSide),
      boxShadow: shadows,
    );

    final content = DecoratedBox(decoration: decoration, child: child);
    return LiquidGlassEdge(borderRadius: borderRadius, child: content);
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
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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

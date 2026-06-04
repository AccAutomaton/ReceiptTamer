import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_surface.dart';

class GlassAlertDialog extends StatelessWidget {
  const GlassAlertDialog({
    super.key,
    this.title,
    this.titlePadding,
    this.content,
    this.contentPadding,
    this.actions,
    this.actionsPadding,
    this.insetPadding,
    this.shape,
    this.scrollable = false,
  });

  final Widget? title;
  final EdgeInsetsGeometry? titlePadding;
  final Widget? content;
  final EdgeInsetsGeometry? contentPadding;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? actionsPadding;
  final EdgeInsets? insetPadding;
  final ShapeBorder? shape;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderRadius =
        _borderRadiusFromShape() ?? BorderRadius.circular(AppRadii.glassLarge);
    final body = _buildBody(theme, colorScheme);

    return SizedBox.expand(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Center(
          child: Dialog(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            insetPadding:
                insetPadding ?? const EdgeInsets.symmetric(horizontal: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: GlassSurface(
                borderRadius: borderRadius,
                fillColor: AppGlassTokens.sheetFillFor(context),
                boxShadow: AppShadows.glass,
                child: body,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme colorScheme) {
    final children = <Widget>[];

    if (title != null) {
      children.add(
        Padding(
          padding: titlePadding ?? const EdgeInsets.fromLTRB(24, 22, 24, 0),
          child: DefaultTextStyle.merge(
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
            child: title!,
          ),
        ),
      );
    }

    if (content != null) {
      final contentWidget = DefaultTextStyle.merge(
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
        ),
        child: content!,
      );

      children.add(
        Padding(
          padding: contentPadding ?? const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: scrollable
              ? SingleChildScrollView(child: contentWidget)
              : contentWidget,
        ),
      );
    }

    if (actions != null && actions!.isNotEmpty) {
      children.add(
        Padding(
          padding: actionsPadding ?? const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: OverflowBar(
            alignment: MainAxisAlignment.end,
            spacing: 8,
            overflowSpacing: 8,
            children: actions!,
          ),
        ),
      );
    }

    return Column(mainAxisSize: MainAxisSize.min, children: children);
  }

  BorderRadius? _borderRadiusFromShape() {
    final dialogShape = shape;
    if (dialogShape is RoundedRectangleBorder) {
      final radius = dialogShape.borderRadius;
      if (radius is BorderRadius) return radius;
    }
    return null;
  }
}

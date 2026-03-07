import 'package:flutter/material.dart';

/// App Button - Unified button styles for the application
enum AppButtonType {
  primary,
  secondary,
  tertiary,
  outlined,
  text,
}

/// App Button widget
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final AppButtonType type;
  final Widget? icon;
  final Widget? trailing;
  final bool isFullWidth;
  final bool isLoading;
  final bool isDense;
  final double? width;
  final double? height;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final BorderSide? borderSide;
  final double borderRadius;
  final VoidCallback? onPressedWhileLoading;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.onLongPress,
    this.type = AppButtonType.primary,
    this.icon,
    this.trailing,
    this.isFullWidth = false,
    this.isLoading = false,
    this.isDense = false,
    this.width,
    this.height,
    this.backgroundColor,
    this.foregroundColor,
    this.borderSide,
    this.borderRadius = 8,
    this.onPressedWhileLoading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveDisabled = isLoading || onPressed == null;

    Widget button;
    final child = _buildChild(context);

    switch (type) {
      case AppButtonType.primary:
        button = ElevatedButton(
          onPressed: effectiveDisabled && onPressedWhileLoading == null
              ? null
              : isLoading ? onPressedWhileLoading : onPressed,
          onLongPress: onLongPress,
          style: _primaryStyle(context, colorScheme),
          child: child,
        );
        break;

      case AppButtonType.secondary:
        button = ElevatedButton(
          onPressed: effectiveDisabled && onPressedWhileLoading == null
              ? null
              : isLoading ? onPressedWhileLoading : onPressed,
          onLongPress: onLongPress,
          style: _secondaryStyle(context, colorScheme),
          child: child,
        );
        break;

      case AppButtonType.tertiary:
        button = ElevatedButton(
          onPressed: effectiveDisabled && onPressedWhileLoading == null
              ? null
              : isLoading ? onPressedWhileLoading : onPressed,
          onLongPress: onLongPress,
          style: _tertiaryStyle(context, colorScheme),
          child: child,
        );
        break;

      case AppButtonType.outlined:
        button = OutlinedButton(
          onPressed: effectiveDisabled && onPressedWhileLoading == null
              ? null
              : isLoading ? onPressedWhileLoading : onPressed,
          onLongPress: onLongPress,
          style: _outlinedStyle(context, colorScheme),
          child: child,
        );
        break;

      case AppButtonType.text:
        button = TextButton(
          onPressed: effectiveDisabled && onPressedWhileLoading == null
              ? null
              : isLoading ? onPressedWhileLoading : onPressed,
          onLongPress: onLongPress,
          style: _textStyle(context, colorScheme),
          child: child,
        );
        break;
    }

    if (isFullWidth || width != null) {
      return SizedBox(
        width: width ?? double.infinity,
        child: button,
      );
    }

    return button;
  }

  Widget _buildChild(BuildContext context) {
    if (isLoading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: isDense ? 16 : 20,
            height: isDense ? 16 : 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                foregroundColor ??
                    Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(text),
        ],
      );
    }

    if (icon != null || trailing != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            icon!,
            const SizedBox(width: 8),
          ],
          Flexible(child: Text(text)),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      );
    }

    return Text(text);
  }

  ButtonStyle _primaryStyle(BuildContext context, ColorScheme colorScheme) {
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor ?? colorScheme.primary,
      foregroundColor: foregroundColor ?? colorScheme.onPrimary,
      padding: EdgeInsets.symmetric(
        horizontal: isDense ? 16 : 24,
        vertical: isDense ? 8 : 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      minimumSize: Size(width ?? 0, height ?? 44),
    );
  }

  ButtonStyle _secondaryStyle(BuildContext context, ColorScheme colorScheme) {
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor ?? colorScheme.secondaryContainer,
      foregroundColor: foregroundColor ?? colorScheme.onSecondaryContainer,
      padding: EdgeInsets.symmetric(
        horizontal: isDense ? 16 : 24,
        vertical: isDense ? 8 : 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      minimumSize: Size(width ?? 0, height ?? 44),
    );
  }

  ButtonStyle _tertiaryStyle(BuildContext context, ColorScheme colorScheme) {
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor ?? colorScheme.tertiaryContainer,
      foregroundColor: foregroundColor ?? colorScheme.onTertiaryContainer,
      padding: EdgeInsets.symmetric(
        horizontal: isDense ? 16 : 24,
        vertical: isDense ? 8 : 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      minimumSize: Size(width ?? 0, height ?? 44),
    );
  }

  ButtonStyle _outlinedStyle(BuildContext context, ColorScheme colorScheme) {
    return OutlinedButton.styleFrom(
      foregroundColor: foregroundColor ?? colorScheme.primary,
      side: borderSide ??
          BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.5),
            width: 1,
          ),
      padding: EdgeInsets.symmetric(
        horizontal: isDense ? 16 : 24,
        vertical: isDense ? 8 : 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      minimumSize: Size(width ?? 0, height ?? 44),
    );
  }

  ButtonStyle _textStyle(BuildContext context, ColorScheme colorScheme) {
    return TextButton.styleFrom(
      foregroundColor: foregroundColor ?? colorScheme.primary,
      padding: EdgeInsets.symmetric(
        horizontal: isDense ? 12 : 16,
        vertical: isDense ? 6 : 10,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      minimumSize: Size(width ?? 0, height ?? 36),
    );
  }
}

/// Icon button variant
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final String? tooltip;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double size;
  final double borderRadius;

  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.onLongPress,
    this.tooltip,
    this.isLoading = false,
    this.backgroundColor,
    this.foregroundColor,
    this.size = 40,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveDisabled = isLoading || onPressed == null;

    return IconButton(
      onPressed: effectiveDisabled ? null : onPressed,
      onLongPress: onLongPress,
      tooltip: tooltip,
      icon: isLoading
          ? SizedBox(
              width: size * 0.5,
              height: size * 0.5,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  foregroundColor ?? colorScheme.onSurface,
                ),
              ),
            )
          : Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: backgroundColor ?? colorScheme.surfaceContainerHighest,
        foregroundColor: foregroundColor ?? colorScheme.onSurface,
        minimumSize: Size(size, size),
        maximumSize: Size(size, size),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

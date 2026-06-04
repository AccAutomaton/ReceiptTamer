import 'package:flutter/material.dart';

class AppPalette {
  const AppPalette._();

  static const coldBackground = Color(0xFFF6F9FA);
  static const mistBlue = Color(0xFFDFE9ED);
  static const primaryMuted = Color(0xFF78939D);
  static const amountMuted = Color(0xFF486A74);
  static const actionPrimary = Color(0xFF0C8293);
  static const actionSecondary = Color(0xFF287D8A);
  static const actionTertiary = Color(0xFF337A86);
  static const actionOutline = Color(0xFF37A6B6);
  static const actionContainer = Color(0xFFDDF4F7);
  static const actionSoftFill = Color(0xFFE5F7FA);
  static const textPrimary = Color(0xFF19232B);
  static const textSecondary = Color(0xFF697781);
  static const outlineMuted = Color(0xFFCAD7DD);
  static const cardFill = Color(0xF7FFFFFF);
  static const elevatedFill = Color(0xFFEAF2F5);
  static const selectedFill = actionContainer;
  static const successMuted = Color(0xFF6F8E7A);
  static const warningMuted = Color(0xFF9A8667);
  static const errorMuted = Color(0xFFA76F72);
  static const shadowMuted = Color(0x2419232B);
  static const shadowDeep = Color(0x3019232B);
  static const frostHighlight = Color(0xBFFFFFFF);
  static const frostLine = Color(0x66B9C9D0);
  static const darkSurface = Color(0xFF131B22);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color textPrimaryFor(BuildContext context) =>
      isDark(context) ? Theme.of(context).colorScheme.onSurface : textPrimary;

  static Color textSecondaryFor(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.onSurfaceVariant
      : textSecondary;

  static Color amountFor(BuildContext context) =>
      isDark(context) ? Theme.of(context).colorScheme.primary : amountMuted;

  static Color actionPrimaryFor(BuildContext context) =>
      isDark(context) ? Theme.of(context).colorScheme.primary : actionPrimary;

  static Color actionSecondaryFor(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.secondary
      : actionSecondary;

  static Color actionOutlineFor(BuildContext context, {double alpha = 1}) =>
      (isDark(context) ? Theme.of(context).colorScheme.primary : actionOutline)
          .withValues(alpha: alpha);

  static Color actionContainerFor(BuildContext context, {double alpha = 1}) =>
      (isDark(context)
              ? Theme.of(context).colorScheme.primaryContainer
              : actionContainer)
          .withValues(alpha: alpha);

  static Color actionSoftFillFor(BuildContext context, {double alpha = 1}) =>
      (isDark(context)
              ? Theme.of(context).colorScheme.secondaryContainer
              : actionSoftFill)
          .withValues(alpha: alpha);

  static Color selectedFillFor(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.7)
      : selectedFill;

  static Color cardFillFor(BuildContext context) => isDark(context)
      ? Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.36)
      : cardFill;

  static Color elevatedFillFor(BuildContext context, {double alpha = 1}) =>
      (isDark(context)
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : elevatedFill)
          .withValues(alpha: alpha);
}

class AppRadii {
  const AppRadii._();

  static const card = 22.0;
  static const control = 18.0;
  static const chip = 999.0;
  static const glassLarge = 28.0;
  static const nav = 999.0;
  static const sheet = 30.0;
}

class AppGlassTokens {
  const AppGlassTokens._();

  static const blurSigma = 22.0;
  static const lightFill = Color(0xAAFFFFFF);
  static const darkFill = Color(0x9E232F39);
  static const lightBorder = Color(0xD8FFFFFF);
  static const darkBorder = Color(0x1FFFFFFF);
  static const sheetFill = Color(0xF4FFFFFF);
  static const contentFill = Color(0xF7FFFFFF);
  static const refractionTint = Color(0x2B8BA5AE);
  static const innerHairline = Color(0x8FFFFFFF);
  static const navHeight = 62.0;
  static const navCenterSlotWidth = 74.0;
  static const navCenterButtonSize = 68.0;

  static Color panelFillFor(BuildContext context) =>
      AppPalette.isDark(context) ? darkFill : lightFill;

  static Color contentFillFor(BuildContext context) =>
      AppPalette.isDark(context) ? darkFill : contentFill;

  static Color sheetFillFor(BuildContext context) =>
      AppPalette.isDark(context) ? darkFill : sheetFill;
}

class AppShadows {
  const AppShadows._();

  static const card = [
    BoxShadow(
      color: AppPalette.shadowMuted,
      blurRadius: 22,
      offset: Offset(0, 10),
    ),
  ];

  static const glass = [
    BoxShadow(
      color: AppPalette.shadowDeep,
      blurRadius: 34,
      spreadRadius: -8,
      offset: Offset(0, 18),
    ),
    BoxShadow(color: Color(0x52FFFFFF), blurRadius: 1, offset: Offset(0, -1)),
  ];
}

import 'package:flutter/material.dart';

/// Rendering cost and semantic role of a surface.
///
/// Kept for compatibility with design-system widgets; the original screens do
/// not need to know which concrete paint treatment a surface uses.
enum AppSurfaceStyle { ledger, raised, glass, danger }

/// Shared visual tokens for the flat "morning-mist ledger" direction.
///
/// The names from the ce04b3c theme remain intact so the original screens and
/// widgets can adopt the new appearance without structural changes.
class AppPalette {
  const AppPalette._();

  // Morning mist, filing paper and binding ink.
  static const morningMist = Color(0xFFEEF5F2);
  static const raisedWhite = Color(0xFFFCFEFD);
  static const mistLayer = Color(0xFFE6F2EE);
  static const freshInk = Color(0xFF193335);
  static const freshGraphite = Color(0xFF52686A);
  static const deepTeal = Color(0xFF2B716C);
  static const mintAccent = Color(0xFF70B9AE);
  static const mintSoft = Color(0xFFE3F2EE);
  static const skyAccent = Color(0xFF7AB7D2);
  static const skySoft = Color(0xFFE5F2F7);
  static const coralAccent = Color(0xFFA4473F);
  static const coralSoft = Color(0xFFFBEEEA);
  static const sunAccent = Color(0xFFF4C76C);

  // ce04b3c public palette names.
  static const coldBackground = morningMist;
  static const mistBlue = mistLayer;
  static const primaryMuted = mintAccent;
  static const amountMuted = deepTeal;
  static const actionPrimary = deepTeal;
  static const actionSecondary = Color(0xFF3D7471);
  static const actionTertiary = Color(0xFF4F91AD);
  static const actionOutline = mintAccent;
  static const actionContainer = mintSoft;
  static const actionSoftFill = Color(0xFFF1F8F6);
  static const textPrimary = freshInk;
  static const textSecondary = freshGraphite;
  static const outlineMuted = Color(0xFFD7E4DF);
  static const cardFill = raisedWhite;
  static const elevatedFill = mistLayer;
  static const selectedFill = actionContainer;
  static const successMuted = Color(0xFF27765F);
  static const warningMuted = Color(0xFF896225);
  static const errorMuted = coralAccent;
  // Compatibility shadow/highlight names stay available, but flat surfaces do
  // not paint them.
  static const shadowMuted = Colors.transparent;
  static const shadowDeep = Colors.transparent;
  static const frostHighlight = Colors.transparent;
  static const frostLine = Color(0x66BFD2CC);
  static const darkSurface = Color(0xFF0F191A);

  // Compatibility aliases retained for widgets created during the previous
  // visual-system work. They intentionally point at the fresh palette.
  static const receiptWhite = coldBackground;
  static const copyPaper = mistBlue;
  static const inkBlack = textPrimary;
  static const graphite = textSecondary;
  static const financeTeal = actionPrimary;
  static const sealRed = errorMuted;

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color textPrimaryFor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color textSecondaryFor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

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
      ? Theme.of(context).colorScheme.primaryContainer
      : selectedFill;

  static Color cardFillFor(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.surfaceContainerLow
      : cardFill;

  static Color elevatedFillFor(BuildContext context, {double alpha = 1}) =>
      (isDark(context)
              ? Theme.of(context).colorScheme.surfaceContainerHigh
              : elevatedFill)
          .withValues(alpha: alpha);
}

/// Typeface roles for the paper-ledger interface.
///
/// Tinos shapes Latin text and tabular numbers while Noto Serif SC supplies
/// the Chinese glyphs. Keeping the same pairing for titles, body copy, labels
/// and utility text gives the archive a single, deliberate typographic voice.
class AppTypography {
  const AppTypography._();

  static const primaryFamily = 'Tinos';
  static const serifFallback = <String>['NotoSerifSC'];

  static const displayFamily = primaryFamily;
  static const bodyFamily = primaryFamily;
  static const labelFamily = primaryFamily;
  static const numberFamily = primaryFamily;
  static const utilityFamily = primaryFamily;

  static const tabularFigures = <FontFeature>[FontFeature.tabularFigures()];

  static TextTheme textTheme(Brightness brightness) {
    final primary = brightness == Brightness.dark
        ? const Color(0xFFEFF7F4)
        : AppPalette.textPrimary;
    final secondary = brightness == Brightness.dark
        ? const Color(0xFFB3C3BF)
        : AppPalette.textSecondary;

    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: serifFallback,
        fontSize: 44,
        height: 1.12,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.8,
        color: primary,
      ),
      displayMedium: TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: serifFallback,
        fontSize: 38,
        height: 1.15,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.68,
        color: primary,
      ),
      displaySmall: TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: serifFallback,
        fontSize: 32,
        height: 1.18,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.56,
        color: primary,
      ),
      headlineLarge: TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: serifFallback,
        fontSize: 30,
        height: 1.2,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.45,
        color: primary,
      ),
      headlineMedium: TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: serifFallback,
        fontSize: 26,
        height: 1.22,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.3,
        color: primary,
      ),
      headlineSmall: TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: serifFallback,
        fontSize: 22,
        height: 1.25,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.18,
        color: primary,
      ),
      titleLarge: TextStyle(
        fontFamily: displayFamily,
        fontFamilyFallback: serifFallback,
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.1,
        color: primary,
      ),
      titleMedium: TextStyle(
        fontFamily: bodyFamily,
        fontFamilyFallback: serifFallback,
        fontSize: 16,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleSmall: TextStyle(
        fontFamily: labelFamily,
        fontFamilyFallback: serifFallback,
        fontSize: 14,
        height: 1.35,
        fontWeight: FontWeight.w500,
        color: primary,
      ),
      bodyLarge: TextStyle(
        fontFamily: bodyFamily,
        fontFamilyFallback: serifFallback,
        fontSize: 16,
        height: 1.55,
        fontWeight: FontWeight.w400,
        color: primary,
      ),
      bodyMedium: TextStyle(
        fontFamily: bodyFamily,
        fontFamilyFallback: serifFallback,
        fontSize: 14,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: primary,
      ),
      bodySmall: TextStyle(
        fontFamily: bodyFamily,
        fontFamilyFallback: serifFallback,
        fontSize: 12,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: secondary,
      ),
      labelLarge: TextStyle(
        fontFamily: labelFamily,
        fontFamilyFallback: serifFallback,
        fontSize: 14,
        height: 1.25,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: primary,
      ),
      labelMedium: TextStyle(
        fontFamily: labelFamily,
        fontFamilyFallback: serifFallback,
        fontSize: 12,
        height: 1.25,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: secondary,
      ),
      labelSmall: TextStyle(
        fontFamily: labelFamily,
        fontFamilyFallback: serifFallback,
        fontSize: 10,
        height: 1.25,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
        color: secondary,
      ),
    );
  }

  static TextStyle amount(
    BuildContext context, {
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: numberFamily,
      fontFamilyFallback: serifFallback,
      fontSize: fontSize,
      height: 1.1,
      fontWeight: fontWeight,
      fontFeatures: tabularFigures,
      color: color ?? AppPalette.amountFor(context),
    );
  }

  static TextStyle utility(
    BuildContext context, {
    double fontSize = 11,
    Color? color,
  }) => TextStyle(
    fontFamily: utilityFamily,
    fontFamilyFallback: serifFallback,
    fontSize: fontSize,
    height: 1.25,
    fontFeatures: tabularFigures,
    letterSpacing: 0.24,
    color: color ?? AppPalette.textSecondaryFor(context),
  );
}

class AppSpacing {
  const AppSpacing._();

  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const page = 16.0;
  static const minTouchTarget = 48.0;
}

class AppMotion {
  const AppMotion._();

  static const fast = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 190);
  static const emphasized = Duration(milliseconds: 220);
  static const curve = Curves.easeOutCubic;

  static bool reduceMotion(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  static Duration adaptive(BuildContext context, Duration duration) =>
      reduceMotion(context) ? Duration.zero : duration;
}

class AppRadii {
  const AppRadii._();

  static const small = 10.0;
  static const control = 14.0;
  static const card = 16.0;
  static const large = 18.0;

  // ce04b3c public names and compatibility aliases.
  static const chip = 999.0;
  static const glassLarge = 18.0;
  static const nav = 26.0;
  static const sheet = 28.0;
}

/// Opaque content surfaces. These tokens never require a backdrop filter.
class AppEntityTokens {
  const AppEntityTokens._();

  static const lightFill = AppPalette.raisedWhite;
  static const lightSubtleFill = AppPalette.mistLayer;
  static const lightBorder = Color(0xFFD7E4DF);
  static const lightStrongBorder = Color(0xFFBFD2CC);
  static const lightRidge = Colors.transparent;
  static const lightHighlight = Colors.transparent;

  static const darkFill = Color(0xFF172526);
  static const darkSubtleFill = Color(0xFF203836);
  static const darkBorder = Color(0xFF2B3F3E);
  static const darkStrongBorder = Color(0xFF3D5552);
  static const darkRidge = Colors.transparent;
  static const darkHighlight = Colors.transparent;

  static const lightShadow = <BoxShadow>[];
  static const darkShadow = <BoxShadow>[];
  static const lightControlShadow = <BoxShadow>[];
  static const darkControlShadow = <BoxShadow>[];

  static Color fillFor(BuildContext context) =>
      AppPalette.isDark(context) ? darkFill : lightFill;

  static Color subtleFillFor(BuildContext context) =>
      AppPalette.isDark(context) ? darkSubtleFill : lightSubtleFill;

  static Color borderFor(BuildContext context) =>
      AppPalette.isDark(context) ? darkBorder : lightBorder;

  static Color strongBorderFor(BuildContext context) =>
      AppPalette.isDark(context) ? darkStrongBorder : lightStrongBorder;

  static Color ridgeFor(BuildContext context) =>
      AppPalette.isDark(context) ? darkRidge : lightRidge;

  static Color highlightFor(BuildContext context) =>
      AppPalette.isDark(context) ? darkHighlight : lightHighlight;

  static List<BoxShadow> shadowFor(BuildContext context) =>
      AppPalette.isDark(context) ? darkShadow : lightShadow;

  static List<BoxShadow> controlShadowFor(BuildContext context) =>
      AppPalette.isDark(context) ? darkControlShadow : lightControlShadow;
}

/// Compatibility shape for widgets that still use the former relief API.
///
/// It now paints only [RoundedRectangleBorder]'s uniform outline. The former
/// highlight and ridge values remain as inert fields so feature widgets can be
/// migrated independently without changing their public API.
class AppReliefRoundedRectangleBorder extends RoundedRectangleBorder {
  const AppReliefRoundedRectangleBorder({
    required Color highlightColor,
    required Color ridgeColor,
    double ridgeWidth = 0,
    super.side,
    super.borderRadius,
  }) : highlightColor = Colors.transparent,
       ridgeColor = Colors.transparent,
       ridgeWidth = 0;

  final Color highlightColor;
  final Color ridgeColor;
  final double ridgeWidth;

  @override
  AppReliefRoundedRectangleBorder copyWith({
    BorderSide? side,
    BorderRadiusGeometry? borderRadius,
  }) => AppReliefRoundedRectangleBorder(
    highlightColor: highlightColor,
    ridgeColor: ridgeColor,
    ridgeWidth: ridgeWidth,
    side: side ?? this.side,
    borderRadius: borderRadius ?? this.borderRadius,
  );

  @override
  AppReliefRoundedRectangleBorder scale(double t) =>
      AppReliefRoundedRectangleBorder(
        highlightColor: highlightColor.withValues(alpha: highlightColor.a * t),
        ridgeColor: ridgeColor.withValues(alpha: ridgeColor.a * t),
        ridgeWidth: ridgeWidth * t,
        side: side.scale(t),
        borderRadius: borderRadius * t,
      );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is RoundedRectangleBorder) {
      final fromHighlight = a is AppReliefRoundedRectangleBorder
          ? a.highlightColor
          : Colors.transparent;
      final fromRidge = a is AppReliefRoundedRectangleBorder
          ? a.ridgeColor
          : Colors.transparent;
      final fromRidgeWidth = a is AppReliefRoundedRectangleBorder
          ? a.ridgeWidth
          : 0.0;
      return AppReliefRoundedRectangleBorder(
        highlightColor: Color.lerp(fromHighlight, highlightColor, t)!,
        ridgeColor: Color.lerp(fromRidge, ridgeColor, t)!,
        ridgeWidth: fromRidgeWidth + (ridgeWidth - fromRidgeWidth) * t,
        side: BorderSide.lerp(a.side, side, t),
        borderRadius: BorderRadiusGeometry.lerp(
          a.borderRadius,
          borderRadius,
          t,
        )!,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is RoundedRectangleBorder) {
      final toHighlight = b is AppReliefRoundedRectangleBorder
          ? b.highlightColor
          : Colors.transparent;
      final toRidge = b is AppReliefRoundedRectangleBorder
          ? b.ridgeColor
          : Colors.transparent;
      final toRidgeWidth = b is AppReliefRoundedRectangleBorder
          ? b.ridgeWidth
          : 0.0;
      return AppReliefRoundedRectangleBorder(
        highlightColor: Color.lerp(highlightColor, toHighlight, t)!,
        ridgeColor: Color.lerp(ridgeColor, toRidge, t)!,
        ridgeWidth: ridgeWidth + (toRidgeWidth - ridgeWidth) * t,
        side: BorderSide.lerp(side, b.side, t),
        borderRadius: BorderRadiusGeometry.lerp(
          borderRadius,
          b.borderRadius,
          t,
        )!,
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppReliefRoundedRectangleBorder &&
          other.side == side &&
          other.borderRadius == borderRadius &&
          other.highlightColor == highlightColor &&
          other.ridgeColor == ridgeColor &&
          other.ridgeWidth == ridgeWidth;

  @override
  int get hashCode =>
      Object.hash(side, borderRadius, highlightColor, ridgeColor, ridgeWidth);
}

/// Compatibility input outline for widgets that still use the former relief
/// API. It now paints only [OutlineInputBorder]'s uniform outline.
class AppReliefInputBorder extends OutlineInputBorder {
  const AppReliefInputBorder({
    required Color highlightColor,
    required Color ridgeColor,
    double ridgeWidth = 0,
    super.borderSide,
    super.borderRadius,
    super.gapPadding,
  }) : highlightColor = Colors.transparent,
       ridgeColor = Colors.transparent,
       ridgeWidth = 0;

  final Color highlightColor;
  final Color ridgeColor;
  final double ridgeWidth;

  @override
  AppReliefInputBorder copyWith({
    BorderSide? borderSide,
    BorderRadius? borderRadius,
    double? gapPadding,
  }) => AppReliefInputBorder(
    highlightColor: highlightColor,
    ridgeColor: ridgeColor,
    ridgeWidth: ridgeWidth,
    borderSide: borderSide ?? this.borderSide,
    borderRadius: borderRadius ?? this.borderRadius,
    gapPadding: gapPadding ?? this.gapPadding,
  );

  @override
  AppReliefInputBorder scale(double t) => AppReliefInputBorder(
    highlightColor: highlightColor.withValues(alpha: highlightColor.a * t),
    ridgeColor: ridgeColor.withValues(alpha: ridgeColor.a * t),
    ridgeWidth: ridgeWidth * t,
    borderSide: borderSide.scale(t),
    borderRadius: borderRadius * t,
    gapPadding: gapPadding * t,
  );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is OutlineInputBorder) {
      final fromHighlight = a is AppReliefInputBorder
          ? a.highlightColor
          : Colors.transparent;
      final fromRidge = a is AppReliefInputBorder
          ? a.ridgeColor
          : Colors.transparent;
      final fromRidgeWidth = a is AppReliefInputBorder ? a.ridgeWidth : 0.0;
      return AppReliefInputBorder(
        highlightColor: Color.lerp(fromHighlight, highlightColor, t)!,
        ridgeColor: Color.lerp(fromRidge, ridgeColor, t)!,
        ridgeWidth: fromRidgeWidth + (ridgeWidth - fromRidgeWidth) * t,
        borderSide: BorderSide.lerp(a.borderSide, borderSide, t),
        borderRadius: BorderRadius.lerp(a.borderRadius, borderRadius, t)!,
        gapPadding: a.gapPadding + (gapPadding - a.gapPadding) * t,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is OutlineInputBorder) {
      final toHighlight = b is AppReliefInputBorder
          ? b.highlightColor
          : Colors.transparent;
      final toRidge = b is AppReliefInputBorder
          ? b.ridgeColor
          : Colors.transparent;
      final toRidgeWidth = b is AppReliefInputBorder ? b.ridgeWidth : 0.0;
      return AppReliefInputBorder(
        highlightColor: Color.lerp(highlightColor, toHighlight, t)!,
        ridgeColor: Color.lerp(ridgeColor, toRidge, t)!,
        ridgeWidth: ridgeWidth + (toRidgeWidth - ridgeWidth) * t,
        borderSide: BorderSide.lerp(borderSide, b.borderSide, t),
        borderRadius: BorderRadius.lerp(borderRadius, b.borderRadius, t)!,
        gapPadding: gapPadding + (b.gapPadding - gapPadding) * t,
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0,
    double gapPercentage = 0,
    TextDirection? textDirection,
  }) {
    super.paint(
      canvas,
      rect,
      gapStart: gapStart,
      gapExtent: gapExtent,
      gapPercentage: gapPercentage,
      textDirection: textDirection,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppReliefInputBorder &&
          other.borderSide == borderSide &&
          other.borderRadius == borderRadius &&
          other.gapPadding == gapPadding &&
          other.highlightColor == highlightColor &&
          other.ridgeColor == ridgeColor &&
          other.ridgeWidth == ridgeWidth;

  @override
  int get hashCode => Object.hash(
    borderSide,
    borderRadius,
    gapPadding,
    highlightColor,
    ridgeColor,
    ridgeWidth,
  );
}

class AppGlassTokens {
  const AppGlassTokens._();

  static const blurSigma = 12.0;
  // Floating controls stay legible: 92% in light mode, 94% in dark mode.
  static const lightFill = Color(0xEBFCFEFD);
  static const darkFill = Color(0xF0172526);
  static const lightModalFill = Color(0xF0FCFEFD);
  static const darkModalFill = Color(0xF0172526);
  static const lightBorder = Color(0x332B716C);
  static const darkBorder = Color(0x388FD3C9);
  static const sheetFill = lightModalFill;
  static const contentFill = AppEntityTokens.lightFill;
  static const refractionTint = Color(0x1470B9AE);
  static const innerHairline = Colors.transparent;
  static const navHeight = 72.0;
  static const navCenterSlotWidth = 68.0;
  static const navCenterButtonSize = 58.0;

  static Color panelFillFor(BuildContext context) =>
      AppPalette.isDark(context) ? darkFill : lightFill;

  static Color contentFillFor(BuildContext context) =>
      AppEntityTokens.fillFor(context);

  static Color sheetFillFor(BuildContext context) =>
      AppPalette.isDark(context) ? darkModalFill : lightModalFill;
}

class AppShadows {
  const AppShadows._();

  static const card = AppEntityTokens.lightShadow;
  static const glass = <BoxShadow>[];
}

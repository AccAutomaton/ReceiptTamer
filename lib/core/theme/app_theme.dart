import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_design_tokens.dart';
import 'app_system_ui.dart';

/// Material 3 configuration for the flat "morning-mist ledger" direction.
///
/// The public constants and theme getters match the ce04b3c contract. Feature
/// screens therefore keep their original structure, copy and behavior while
/// inheriting the new palette and typography.
class AppTheme {
  const AppTheme._();

  // Primary colors.
  static const Color primaryColor = AppPalette.actionPrimary;
  static const Color onPrimaryColor = Color(0xFFFFFFFF);
  static const Color primaryContainerColor = AppPalette.actionContainer;
  static const Color onPrimaryContainerColor = Color(0xFF183E3B);

  // Secondary colors.
  static const Color secondaryColor = AppPalette.actionSecondary;
  static const Color onSecondaryColor = Color(0xFFFFFFFF);
  static const Color secondaryContainerColor = AppPalette.skySoft;
  static const Color onSecondaryContainerColor = Color(0xFF244A59);

  // Tertiary colors.
  static const Color tertiaryColor = AppPalette.warningMuted;
  static const Color onTertiaryColor = Color(0xFFFFFFFF);
  static const Color tertiaryContainerColor = Color(0xFFFFF1C7);
  static const Color onTertiaryContainerColor = Color(0xFF3F2F08);

  // Error colors use a deeper coral for readable text and controls.
  static const Color errorColor = AppPalette.errorMuted;
  static const Color errorContainerColor = AppPalette.coralSoft;

  // Surface colors.
  static const Color surfaceColor = AppPalette.coldBackground;
  static const Color onSurfaceColor = AppPalette.textPrimary;
  static const Color surfaceContainerHighestColor = AppPalette.mistBlue;
  static const Color onSurfaceVariantColor = AppPalette.textSecondary;

  // Outline colors.
  static const Color outlineColor = Color(0xFF728985);
  static const Color outlineVariantColor = AppPalette.outlineMuted;

  // Inverse colors.
  static const Color inverseSurfaceColor = AppPalette.darkSurface;
  static const Color inversePrimaryColor = Color(0xFF8FD3C9);

  static const _lightScheme = ColorScheme.light(
    primary: primaryColor,
    onPrimary: onPrimaryColor,
    primaryContainer: primaryContainerColor,
    onPrimaryContainer: onPrimaryContainerColor,
    secondary: secondaryColor,
    onSecondary: onSecondaryColor,
    secondaryContainer: secondaryContainerColor,
    onSecondaryContainer: onSecondaryContainerColor,
    tertiary: tertiaryColor,
    onTertiary: onTertiaryColor,
    tertiaryContainer: tertiaryContainerColor,
    onTertiaryContainer: onTertiaryContainerColor,
    error: errorColor,
    onError: Colors.white,
    errorContainer: errorContainerColor,
    onErrorContainer: Color(0xFF612218),
    surface: surfaceColor,
    onSurface: onSurfaceColor,
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: AppEntityTokens.lightFill,
    surfaceContainer: Color(0xFFF1F8F6),
    surfaceContainerHigh: AppEntityTokens.lightSubtleFill,
    surfaceContainerHighest: surfaceContainerHighestColor,
    onSurfaceVariant: onSurfaceVariantColor,
    outline: outlineColor,
    outlineVariant: outlineVariantColor,
    inverseSurface: inverseSurfaceColor,
    onInverseSurface: Color(0xFFEFF7F4),
    inversePrimary: inversePrimaryColor,
    shadow: Colors.transparent,
    scrim: Color(0xFF132324),
  );

  static const _darkScheme = ColorScheme.dark(
    primary: Color(0xFF8FD3C9),
    onPrimary: Color(0xFF0D3534),
    primaryContainer: Color(0xFF203B38),
    onPrimaryContainer: Color(0xFFC7F1EA),
    secondary: Color(0xFF91CBE2),
    onSecondary: Color(0xFF12333F),
    secondaryContainer: Color(0xFF203740),
    onSecondaryContainer: Color(0xFFC7E9F4),
    tertiary: Color(0xFFE3BD72),
    onTertiary: Color(0xFF3E2E08),
    tertiaryContainer: Color(0xFF443817),
    onTertiaryContainer: Color(0xFFFBE3A9),
    error: Color(0xFFFF9B88),
    onError: Color(0xFF5B1510),
    errorContainer: Color(0xFF482D2B),
    onErrorContainer: Color(0xFFFFDAD3),
    surface: Color(0xFF0F191A),
    onSurface: Color(0xFFEFF7F4),
    surfaceContainerLowest: Color(0xFF0B1213),
    surfaceContainerLow: AppEntityTokens.darkFill,
    surfaceContainer: Color(0xFF1B2D2D),
    surfaceContainerHigh: AppEntityTokens.darkSubtleFill,
    surfaceContainerHighest: Color(0xFF263D3B),
    onSurfaceVariant: Color(0xFFB3C3BF),
    outline: Color(0xFF7D9691),
    outlineVariant: AppEntityTokens.darkBorder,
    inverseSurface: Color(0xFFEFF7F4),
    onInverseSurface: Color(0xFF233238),
    inversePrimary: Color(0xFF245F61),
    shadow: Colors.transparent,
    scrim: Color(0xFF000000),
  );

  /// Light theme.
  static ThemeData get lightTheme => _build(
    scheme: _lightScheme,
    overlayStyle: AppSystemUi.overlayStyleFor(Brightness.light),
  );

  /// Dark theme.
  static ThemeData get darkTheme => _build(
    scheme: _darkScheme,
    overlayStyle: AppSystemUi.overlayStyleFor(Brightness.dark),
  );

  static ThemeData _build({
    required ColorScheme scheme,
    required SystemUiOverlayStyle overlayStyle,
  }) {
    final isDark = scheme.brightness == Brightness.dark;
    final textTheme = AppTypography.textTheme(scheme.brightness);
    final raisedSurface = isDark
        ? AppEntityTokens.darkFill
        : AppEntityTokens.lightFill;
    final quietSurface = isDark
        ? scheme.surfaceContainer
        : AppPalette.actionSoftFill;
    final lineColor = isDark
        ? AppEntityTokens.darkBorder
        : AppEntityTokens.lightBorder;
    final strongLineColor = isDark
        ? AppEntityTokens.darkStrongBorder
        : AppEntityTokens.lightStrongBorder;
    final actionOutline = isDark
        ? scheme.primary.withValues(alpha: 0.48)
        : AppPalette.actionOutline.withValues(alpha: 0.72);
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.control),
    );
    final flatControlShape = WidgetStatePropertyAll<OutlinedBorder?>(
      controlShape,
    );
    const flatElevation = WidgetStatePropertyAll<double?>(0);
    const transparentShadow = WidgetStatePropertyAll<Color?>(
      Colors.transparent,
    );
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.control),
      borderSide: BorderSide(color: strongLineColor),
    );
    final focusedFieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.control),
      borderSide: BorderSide(color: scheme.primary),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      fontFamily: AppTypography.bodyFamily,
      fontFamilyFallback: AppTypography.serifFallback,
      textTheme: textTheme,
      primaryTextTheme: textTheme.apply(
        bodyColor: scheme.onPrimary,
        displayColor: scheme.onPrimary,
      ),
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        // App bars and scroll-edge fogs share one paper color so the body can
        // fade in without producing a horizontal seam below the title bar.
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle: overlayStyle,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        color: raisedSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: lineColor),
        ),
      ),
      dividerTheme: DividerThemeData(color: lineColor, thickness: 1, space: 1),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style:
            ElevatedButton.styleFrom(
              minimumSize: const Size(48, 48),
              backgroundColor: quietSurface,
              foregroundColor: scheme.primary,
              disabledBackgroundColor: scheme.surfaceContainerHigh,
              disabledForegroundColor: scheme.onSurfaceVariant.withValues(
                alpha: 0.62,
              ),
              elevation: 0,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: controlShape,
              side: BorderSide(color: actionOutline),
              textStyle: textTheme.labelLarge,
              animationDuration: AppMotion.standard,
            ).copyWith(
              elevation: flatElevation,
              shadowColor: transparentShadow,
              shape: flatControlShape,
            ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              disabledBackgroundColor: scheme.surfaceContainerHigh,
              disabledForegroundColor: scheme.onSurfaceVariant.withValues(
                alpha: 0.62,
              ),
              elevation: 0,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: controlShape,
              side: BorderSide(
                color: isDark
                    ? scheme.primary.withValues(alpha: 0.52)
                    : const Color(0xFF1E5955),
              ),
              textStyle: textTheme.labelLarge,
              animationDuration: AppMotion.standard,
            ).copyWith(
              elevation: flatElevation,
              shadowColor: transparentShadow,
              shape: flatControlShape,
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              backgroundColor: raisedSurface,
              foregroundColor: scheme.primary,
              elevation: 0,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: controlShape,
              side: BorderSide(color: actionOutline),
              textStyle: textTheme.labelLarge,
              animationDuration: AppMotion.standard,
            ).copyWith(
              elevation: flatElevation,
              shadowColor: transparentShadow,
              shape: flatControlShape,
            ),
      ),
      textButtonTheme: TextButtonThemeData(
        style:
            TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: scheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: controlShape,
              textStyle: textTheme.labelLarge,
              animationDuration: AppMotion.standard,
            ).copyWith(
              elevation: flatElevation,
              shadowColor: transparentShadow,
              shape: flatControlShape,
            ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: Colors.transparent,
          foregroundColor: scheme.primary,
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: scheme.onSurfaceVariant.withValues(
            alpha: 0.62,
          ),
          shape: controlShape,
          side: BorderSide.none,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: raisedSurface,
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: focusedFieldBorder,
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide(color: scheme.error),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide(color: lineColor),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.small / 2),
        ),
        side: BorderSide(color: scheme.outline),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.surfaceContainerHigh;
          }
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return raisedSurface;
        }),
        checkColor: WidgetStatePropertyAll(scheme.onPrimary),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurfaceVariant.withValues(alpha: 0.5);
          }
          return scheme.primary;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurfaceVariant.withValues(alpha: 0.55);
          }
          if (states.contains(WidgetState.selected)) return scheme.onPrimary;
          return scheme.onSurfaceVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.surfaceContainerHigh;
          }
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return quietSurface;
        }),
        trackOutlineColor: WidgetStatePropertyAll(lineColor),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          shape: WidgetStatePropertyAll(controlShape),
          side: WidgetStatePropertyAll(BorderSide(color: lineColor)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.primaryContainer
                : raisedSurface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: raisedSurface,
        selectedColor: scheme.primaryContainer,
        disabledColor: scheme.surfaceContainerHigh,
        labelStyle: textTheme.labelMedium,
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.primary,
        ),
        checkmarkColor: scheme.primary,
        side: BorderSide(color: lineColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.chip),
        ),
      ),
      listTileTheme: ListTileThemeData(
        minTileHeight: 56,
        iconColor: scheme.primary,
        textColor: scheme.onSurface,
        selectedColor: scheme.primary,
        selectedTileColor: scheme.primaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        disabledElevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        backgroundColor: raisedSurface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: AppGlassTokens.navHeight,
        elevation: 0,
        backgroundColor: raisedSurface,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        elevation: 0,
        modalElevation: 0,
        backgroundColor: raisedSurface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: scheme.scrim.withValues(alpha: 0.34),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: raisedSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.glassLarge),
          side: BorderSide(color: lineColor),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: isDark ? scheme.primaryContainer : scheme.primary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: isDark ? scheme.onPrimaryContainer : scheme.onPrimary,
        ),
        actionTextColor: isDark ? scheme.primary : AppPalette.mintSoft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHigh,
        circularTrackColor: scheme.surfaceContainerHigh,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.22),
        selectionHandleColor: scheme.primary,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: raisedSurface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: scheme.primaryContainer,
        headerForegroundColor: scheme.onPrimaryContainer,
        dividerColor: lineColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.glassLarge),
          side: BorderSide(color: lineColor),
        ),
        dayShape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
          ),
        ),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return Colors.transparent;
        }),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.onPrimary;
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurfaceVariant.withValues(alpha: 0.4);
          }
          return scheme.onSurface;
        }),
        todayForegroundColor: WidgetStatePropertyAll(scheme.primary),
        todayBorder: BorderSide(color: scheme.primary),
        rangePickerElevation: 0,
        rangePickerShadowColor: Colors.transparent,
        rangePickerSurfaceTintColor: Colors.transparent,
      ),
    );
  }
}

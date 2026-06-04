import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_design_tokens.dart';

/// App theme configuration using Material Design 3
class AppTheme {
  // Primary colors
  static const Color primaryColor = AppPalette.actionPrimary;
  static const Color onPrimaryColor = Color(0xFFFFFFFF);
  static const Color primaryContainerColor = AppPalette.actionContainer;
  static const Color onPrimaryContainerColor = AppPalette.textPrimary;

  // Secondary colors
  static const Color secondaryColor = AppPalette.actionSecondary;
  static const Color onSecondaryColor = Color(0xFFFFFFFF);
  static const Color secondaryContainerColor = AppPalette.actionContainer;
  static const Color onSecondaryContainerColor = AppPalette.actionPrimary;

  // Tertiary colors
  static const Color tertiaryColor = AppPalette.actionTertiary;
  static const Color onTertiaryColor = Color(0xFFFFFFFF);
  static const Color tertiaryContainerColor = AppPalette.actionSoftFill;
  static const Color onTertiaryContainerColor = AppPalette.actionPrimary;

  // Error colors
  static const Color errorColor = Color(0xFFBA1A1A);
  static const Color errorContainerColor = Color(0xFFFFDAD6);

  // Surface colors
  static const Color surfaceColor = AppPalette.coldBackground;
  static const Color onSurfaceColor = AppPalette.textPrimary;
  static const Color surfaceContainerHighestColor = AppPalette.mistBlue;
  static const Color onSurfaceVariantColor = AppPalette.textSecondary;

  // Outline colors
  static const Color outlineColor = Color(0xFF8A9AA3);
  static const Color outlineVariantColor = AppPalette.outlineMuted;

  // Inverse colors
  static const Color inverseSurfaceColor = AppPalette.darkSurface;
  static const Color inversePrimaryColor = Color(0xFFAFC8D0);

  /// Light theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
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
        errorContainer: errorContainerColor,
        surface: surfaceColor,
        onSurface: onSurfaceColor,
        surfaceContainerHighest: surfaceContainerHighestColor,
        onSurfaceVariant: onSurfaceVariantColor,
        outline: outlineColor,
        outlineVariant: outlineVariantColor,
        inverseSurface: inverseSurfaceColor,
        inversePrimary: inversePrimaryColor,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppPalette.cardFill,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(
            color: outlineVariantColor.withValues(alpha: 0.7),
            width: 1,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.actionSoftFill,
          foregroundColor: primaryColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          side: BorderSide(
            color: AppPalette.actionOutline.withValues(alpha: 0.44),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: onPrimaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppPalette.actionSoftFill.withValues(alpha: 0.58),
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          side: const BorderSide(color: AppPalette.actionOutline, width: 1.3),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          backgroundColor: AppPalette.actionSoftFill.withValues(alpha: 0.78),
          foregroundColor: primaryColor,
          side: BorderSide(
            color: AppPalette.actionOutline.withValues(alpha: 0.42),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        checkColor: WidgetStateProperty.all(onPrimaryColor),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return null;
          if (states.contains(WidgetState.selected)) return primaryColor;
          return AppPalette.actionSoftFill;
        }),
        side: const BorderSide(color: AppPalette.actionOutline, width: 1.3),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return null;
          return primaryColor;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return null;
          if (states.contains(WidgetState.selected)) return onPrimaryColor;
          return AppPalette.actionPrimary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return null;
          if (states.contains(WidgetState.selected)) return primaryColor;
          return AppPalette.actionSoftFill;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return null;
          return AppPalette.actionOutline;
        }),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppPalette.actionContainer;
            }
            return AppPalette.actionSoftFill.withValues(alpha: 0.58);
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return null;
            return primaryColor;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return null;
            return const BorderSide(
              color: AppPalette.actionOutline,
              width: 1.2,
            );
          }),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppPalette.actionSoftFill.withValues(alpha: 0.52),
        selectedColor: AppPalette.actionContainer,
        checkmarkColor: primaryColor,
        side: BorderSide(
          color: AppPalette.actionOutline.withValues(alpha: 0.46),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.chip),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: primaryColor,
        selectedColor: primaryColor,
        selectedTileColor: primaryContainerColor,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.cardFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide(color: outlineColor.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide(color: outlineColor.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: primaryColor, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: onPrimaryColor,
        elevation: 4,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  /// Dark theme
  static ThemeData get darkTheme {
    const darkPrimary = Color(0xFF6BEAFF);
    const darkOnPrimary = Color(0xFF00363D);
    const darkPrimaryContainer = Color(0xFF0B3F49);
    const darkActionSoftFill = Color(0xFF123F47);
    const darkActionOutline = Color(0xFF60D6E7);

    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: darkPrimary,
        onPrimary: darkOnPrimary,
        primaryContainer: darkPrimaryContainer,
        onPrimaryContainer: Color(0xFF97F0FF),
        secondary: Color(0xFF8AE6F3),
        onSecondary: Color(0xFF1C3438),
        secondaryContainer: darkActionSoftFill,
        onSecondaryContainer: Color(0xFFCCE7EC),
        tertiary: Color(0xFFB5EEF6),
        onTertiary: Color(0xFF152C5E),
        tertiaryContainer: Color(0xFF183E49),
        onTertiaryContainer: Color(0xFFCED9FF),
        error: Color(0xFFFFB4AB),
        errorContainer: Color(0xFF93000A),
        surface: Color(0xFF191C1D),
        onSurface: Color(0xFFE1E3E3),
        surfaceContainerHighest: Color(0xFF3F484A),
        onSurfaceVariant: Color(0xFFBEC8C9),
        outline: Color(0xFF899294),
        outlineVariant: Color(0xFF3F484A),
        inverseSurface: Color(0xFFE1E3E3),
        inversePrimary: Color(0xFF006874),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(
            color: const Color(0xFF3F484A).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkActionSoftFill,
          foregroundColor: darkPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          side: BorderSide(color: darkActionOutline.withValues(alpha: 0.52)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: darkPrimary,
          foregroundColor: darkOnPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: darkActionSoftFill.withValues(alpha: 0.72),
          foregroundColor: darkPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          side: const BorderSide(color: darkActionOutline, width: 1.3),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: darkPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          backgroundColor: darkActionSoftFill.withValues(alpha: 0.72),
          foregroundColor: darkPrimary,
          side: BorderSide(color: darkActionOutline.withValues(alpha: 0.46)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        checkColor: WidgetStateProperty.all(darkOnPrimary),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return null;
          if (states.contains(WidgetState.selected)) return darkPrimary;
          return darkActionSoftFill;
        }),
        side: const BorderSide(color: darkActionOutline, width: 1.3),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return null;
          return darkPrimary;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return null;
          if (states.contains(WidgetState.selected)) return darkOnPrimary;
          return darkPrimary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return null;
          if (states.contains(WidgetState.selected)) return darkPrimary;
          return darkActionSoftFill;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return null;
          return darkActionOutline;
        }),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return darkPrimaryContainer;
            }
            return darkActionSoftFill.withValues(alpha: 0.72);
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return null;
            return darkPrimary;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return null;
            return const BorderSide(color: darkActionOutline, width: 1.2);
          }),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkActionSoftFill.withValues(alpha: 0.62),
        selectedColor: darkPrimaryContainer,
        checkmarkColor: darkPrimary,
        side: BorderSide(color: darkActionOutline.withValues(alpha: 0.48)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.chip),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: darkPrimary,
        selectedColor: darkPrimary,
        selectedTileColor: darkPrimaryContainer,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF3F484A).withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide(
            color: const Color(0xFF899294).withValues(alpha: 0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide(
            color: const Color(0xFF899294).withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: darkPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: Color(0xFFFFB4AB)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: Color(0xFFFFB4AB), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: darkPrimary,
        foregroundColor: darkOnPrimary,
        elevation: 4,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

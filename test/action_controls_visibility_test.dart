import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/core/theme/app_theme.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_button.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_navigation_bar.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_surface.dart';

void main() {
  test('light theme keeps action colors while flattening every control', () {
    final theme = AppTheme.lightTheme;
    final colorScheme = theme.colorScheme;

    expect(colorScheme.primary, AppPalette.actionPrimary);
    expect(colorScheme.secondary, AppPalette.actionSecondary);
    expect(colorScheme.tertiary, AppPalette.warningMuted);
    expect(colorScheme.shadow, Colors.transparent);

    final filledBackground = theme.filledButtonTheme.style?.backgroundColor
        ?.resolve(<WidgetState>{});
    expect(filledBackground, AppPalette.actionPrimary);

    final outlinedSide = theme.outlinedButtonTheme.style?.side?.resolve(
      <WidgetState>{},
    );
    expect(
      outlinedSide?.color,
      AppPalette.actionOutline.withValues(alpha: 0.72),
    );
    expect(outlinedSide?.width, 1);

    expect(theme.cardTheme.elevation, 0);
    expect(theme.cardTheme.shadowColor, Colors.transparent);
    expect(theme.cardTheme.shape, isA<RoundedRectangleBorder>());
    expect(
      theme.cardTheme.shape,
      isNot(isA<AppReliefRoundedRectangleBorder>()),
    );

    final buttonStyles = [
      theme.elevatedButtonTheme.style!,
      theme.filledButtonTheme.style!,
      theme.outlinedButtonTheme.style!,
      theme.textButtonTheme.style!,
    ];
    const states = <Set<WidgetState>>[
      <WidgetState>{},
      <WidgetState>{WidgetState.hovered},
      <WidgetState>{WidgetState.focused},
      <WidgetState>{WidgetState.pressed},
      <WidgetState>{WidgetState.disabled},
    ];
    for (final style in buttonStyles) {
      final idleShape = style.shape?.resolve(const <WidgetState>{});
      expect(idleShape, isA<RoundedRectangleBorder>());
      expect(idleShape, isNot(isA<AppReliefRoundedRectangleBorder>()));
      for (final state in states) {
        expect(style.elevation?.resolve(state), 0);
        expect(style.shadowColor?.resolve(state), Colors.transparent);
        expect(style.shape?.resolve(state), idleShape);
      }
    }

    expect(AppEntityTokens.lightShadow, isEmpty);
    expect(AppEntityTokens.lightControlShadow, isEmpty);
    expect(AppEntityTokens.lightHighlight, Colors.transparent);
    expect(AppEntityTokens.lightRidge, Colors.transparent);

    final inputTheme = theme.inputDecorationTheme;
    expect(inputTheme.enabledBorder, isA<OutlineInputBorder>());
    expect(inputTheme.enabledBorder, isNot(isA<AppReliefInputBorder>()));
    expect(
      (inputTheme.enabledBorder! as OutlineInputBorder).borderSide.width,
      1,
    );
    expect(
      (inputTheme.focusedBorder! as OutlineInputBorder).borderSide,
      BorderSide(color: colorScheme.primary),
    );

    final fabTheme = theme.floatingActionButtonTheme;
    expect(fabTheme.elevation, 0);
    expect(fabTheme.focusElevation, 0);
    expect(fabTheme.hoverElevation, 0);
    expect(fabTheme.highlightElevation, 0);
    expect(fabTheme.disabledElevation, 0);

    final datePickerTheme = theme.datePickerTheme;
    expect(datePickerTheme.elevation, 0);
    expect(datePickerTheme.shadowColor, Colors.transparent);
    expect(datePickerTheme.rangePickerElevation, 0);
    expect(datePickerTheme.rangePickerShadowColor, Colors.transparent);
  });

  test('light and dark themes share the zero-elevation surface contract', () {
    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      expect(theme.colorScheme.shadow, Colors.transparent);
      expect(theme.cardTheme.elevation, 0);
      expect(theme.cardTheme.shadowColor, Colors.transparent);
      expect(theme.dialogTheme.elevation, 0);
      expect(theme.bottomSheetTheme.elevation, 0);
      expect(theme.bottomSheetTheme.modalElevation, 0);
      expect(theme.snackBarTheme.elevation, 0);
      expect(theme.navigationBarTheme.elevation, 0);

      for (final style in [
        theme.elevatedButtonTheme.style!,
        theme.filledButtonTheme.style!,
        theme.outlinedButtonTheme.style!,
        theme.textButtonTheme.style!,
      ]) {
        for (final state in WidgetState.values) {
          expect(style.elevation?.resolve({state}), 0);
          expect(style.shadowColor?.resolve({state}), Colors.transparent);
        }
      }
    }

    expect(AppEntityTokens.darkShadow, isEmpty);
    expect(AppEntityTokens.darkControlShadow, isEmpty);
    expect(AppEntityTokens.darkHighlight, Colors.transparent);
    expect(AppEntityTokens.darkRidge, Colors.transparent);
    expect(AppShadows.glass, isEmpty);
  });

  testWidgets('custom app controls default to visible enabled action colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Column(
            children: [
              AppButton(
                text: 'secondary',
                type: AppButtonType.secondary,
                onPressed: () {},
              ),
              AppIconButton(icon: Icons.search, onPressed: () {}),
              GlassNavigationBar(
                selectedIndex: 0,
                items: const [
                  GlassNavItem(
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home,
                    label: 'home',
                  ),
                  GlassNavItem(
                    icon: Icons.receipt_long_outlined,
                    selectedIcon: Icons.receipt_long,
                    label: 'orders',
                  ),
                  GlassNavItem(
                    icon: Icons.description_outlined,
                    selectedIcon: Icons.description,
                    label: 'invoices',
                  ),
                  GlassNavItem(
                    icon: Icons.inventory_2_outlined,
                    selectedIcon: Icons.inventory_2,
                    label: 'reimbursement',
                  ),
                ],
                onDestinationSelected: (_) {},
                onIntakePressed: () {},
              ),
            ],
          ),
        ),
      ),
    );

    final secondaryButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'secondary'),
    );
    final secondaryStyle = secondaryButton.style!;
    expect(
      secondaryStyle.backgroundColor!.resolve(<WidgetState>{}),
      AppEntityTokens.lightFill,
    );
    expect(
      secondaryStyle.foregroundColor!.resolve(<WidgetState>{}),
      AppTheme.lightTheme.colorScheme.primary,
    );

    final iconButton = tester.widget<IconButton>(find.byType(IconButton));
    final iconStyle = iconButton.style!;
    expect(
      iconStyle.backgroundColor!.resolve(<WidgetState>{}),
      Colors.transparent,
    );
    expect(
      iconStyle.foregroundColor!.resolve(<WidgetState>{}),
      AppPalette.actionPrimary,
    );

    final intakeFinder = find.byKey(const ValueKey('glass_nav_intake_action'));
    final intakeMaterial = tester.widget<Material>(
      find.descendant(of: intakeFinder, matching: find.byType(Material)).first,
    );
    expect(intakeMaterial.color, AppPalette.actionPrimary);
    expect(intakeMaterial.shape, isA<RoundedRectangleBorder>());
    expect(
      find.descendant(of: intakeFinder, matching: find.byType(GlassSurface)),
      findsNothing,
    );
  });
}

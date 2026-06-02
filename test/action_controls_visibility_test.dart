import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/core/theme/app_theme.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_button.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_navigation_bar.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_surface.dart';

void main() {
  test('light theme uses brighter action colors for enabled controls', () {
    final theme = AppTheme.lightTheme;
    final colorScheme = theme.colorScheme;

    expect(colorScheme.primary, const Color(0xFF0C8293));
    expect(colorScheme.secondary, const Color(0xFF287D8A));
    expect(colorScheme.tertiary, const Color(0xFF337A86));

    final filledBackground = theme.filledButtonTheme.style?.backgroundColor
        ?.resolve(<WidgetState>{});
    expect(filledBackground, const Color(0xFF0C8293));

    final outlinedSide = theme.outlinedButtonTheme.style?.side?.resolve(
      <WidgetState>{},
    );
    expect(outlinedSide?.color, const Color(0xFF37A6B6));
    expect(outlinedSide?.width, 1.3);
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
                    icon: Icons.settings_outlined,
                    selectedIcon: Icons.settings,
                    label: 'settings',
                  ),
                ],
                onDestinationSelected: (_) {},
                onCenterPressed: () {},
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
      const Color(0xFFDDF4F7),
    );
    expect(
      secondaryStyle.foregroundColor!.resolve(<WidgetState>{}),
      const Color(0xFF0C8293),
    );

    final iconButton = tester.widget<IconButton>(find.byType(IconButton));
    final iconStyle = iconButton.style!;
    expect(
      iconStyle.backgroundColor!.resolve(<WidgetState>{}),
      const Color(0xFFE5F7FA),
    );
    expect(
      iconStyle.foregroundColor!.resolve(<WidgetState>{}),
      const Color(0xFF0C8293),
    );

    final centerSurface = tester.widget<GlassSurface>(
      find
          .descendant(
            of: find.byKey(const ValueKey('glass_nav_center_action')),
            matching: find.byType(GlassSurface),
          )
          .first,
    );
    expect(centerSurface.fillColor, const Color(0xFF0C8293));
  });
}

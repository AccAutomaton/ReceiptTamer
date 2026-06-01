import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_navigation_bar.dart';

void main() {
  const items = [
    GlassNavItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: '首页',
    ),
    GlassNavItem(
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      label: '订单',
    ),
    GlassNavItem(
      icon: Icons.description_outlined,
      selectedIcon: Icons.description,
      label: '发票',
    ),
    GlassNavItem(
      icon: Icons.info_outline,
      selectedIcon: Icons.info,
      label: '关于',
    ),
  ];

  testWidgets('GlassNavigationBar renders labels and oversized center action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: GlassNavigationBar(
              selectedIndex: 0,
              items: items,
              onDestinationSelected: (_) {},
              onCenterPressed: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('首页'), findsOneWidget);
    expect(find.text('订单'), findsOneWidget);
    expect(find.text('发票'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);

    final centerBox = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('glass_nav_center_action')),
    );
    expect(centerBox.size.width, AppGlassTokens.navCenterButtonSize);
    expect(centerBox.size.height, AppGlassTokens.navCenterButtonSize);
  });

  testWidgets('GlassNavigationBar reports destination and center taps', (
    tester,
  ) async {
    int? selected;
    var centerPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: GlassNavigationBar(
              selectedIndex: 0,
              items: items,
              onDestinationSelected: (index) => selected = index,
              onCenterPressed: () => centerPressed = true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('订单'));
    expect(selected, 1);

    await tester.tap(find.byKey(const ValueKey('glass_nav_center_action')));
    expect(centerPressed, isTrue);
  });
}

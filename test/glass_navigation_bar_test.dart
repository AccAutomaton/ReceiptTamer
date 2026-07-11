import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_navigation_bar.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_surface.dart';

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

  testWidgets('GlassNavigationBar renders labels and in-island center action', (
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
    expect(centerBox.size.width, GlassNavigationBar.centerActionSize);
    expect(centerBox.size.height, GlassNavigationBar.centerActionSize);

    final island = tester.widget<GlassSurface>(
      find.byKey(const ValueKey('glass_nav_island')),
    );
    expect(island.fillColor?.a, closeTo(0.92, 0.002));
    expect(island.blurSigma, lessThanOrEqualTo(12));
    expect(island.preset, GlassSurfacePreset.navigation);

    final centerSurface = tester.widget<GlassSurface>(
      find
          .descendant(
            of: find.byKey(const ValueKey('glass_nav_center_action')),
            matching: find.byType(GlassSurface),
          )
          .first,
    );
    expect(centerSurface.blurSigma, 0);
    expect(centerSurface.preset, GlassSurfacePreset.panel);
  });

  testWidgets('GlassNavigationBar follows regular and compact island insets', (
    tester,
  ) async {
    Future<void> pumpAt(Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
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
      await tester.pump();
    }

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpAt(const Size(412, 915));
    var rect = tester.getRect(find.byKey(const ValueKey('glass_nav_island')));
    var centerRect = tester.getRect(
      find.byKey(const ValueKey('glass_nav_center_action')),
    );
    expect(rect.left, 14);
    expect(412 - rect.right, 14);
    expect(915 - rect.bottom, 12);
    expect(rect.height, GlassNavigationBar.islandHeight);
    expect(centerRect.size, const Size.square(54));
    expect(centerRect.center.dx, 206);
    expect(centerRect.center.dy, closeTo(rect.center.dy, 0.5));
    expect(centerRect.top, greaterThanOrEqualTo(rect.top));
    expect(centerRect.bottom, lessThanOrEqualTo(rect.bottom));

    await pumpAt(const Size(360, 800));
    rect = tester.getRect(find.byKey(const ValueKey('glass_nav_island')));
    centerRect = tester.getRect(
      find.byKey(const ValueKey('glass_nav_center_action')),
    );
    expect(rect.left, 12);
    expect(360 - rect.right, 12);
    expect(800 - rect.bottom, 10);
    expect(rect.height, GlassNavigationBar.compactIslandHeight);
    expect(centerRect.size, const Size.square(51));
    expect(centerRect.center.dx, 180);
    expect(centerRect.center.dy, closeTo(rect.center.dy, 0.5));
    expect(centerRect.top, greaterThanOrEqualTo(rect.top));
    expect(centerRect.bottom, lessThanOrEqualTo(rect.bottom));
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

import 'dart:ui' show SemanticsAction;

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
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
      label: '报销',
    ),
  ];

  testWidgets('GlassNavigationBar renders four destinations and side intake', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: GlassNavigationBar(
              selectedIndex: 0,
              items: items,
              onDestinationSelected: (_) {},
              onIntakePressed: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('首页'), findsOneWidget);
    expect(find.text('订单'), findsOneWidget);
    expect(find.text('发票'), findsOneWidget);
    expect(find.text('报销'), findsOneWidget);
    expect(find.text('新增'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(find.byKey(const ValueKey('glass_nav_center_action')), findsNothing);

    final intakeFinder = find.byKey(const ValueKey('glass_nav_intake_action'));
    final intakeBox = tester.renderObject<RenderBox>(intakeFinder);
    expect(intakeBox.size.width, GlassNavigationBar.intakeActionSize);
    expect(intakeBox.size.height, GlassNavigationBar.intakeActionSize);

    final intakeSemantics = tester.getSemantics(intakeFinder);
    final intakeSemanticsData = intakeSemantics.getSemanticsData();
    expect(
      intakeSemantics.label.split('\n').where((label) => label.isNotEmpty),
      everyElement('新增'),
    );
    expect(intakeSemanticsData.flagsCollection.isButton, isTrue);
    expect(intakeSemanticsData.hasAction(SemanticsAction.tap), isTrue);

    final island = tester.widget<GlassSurface>(
      find.byKey(const ValueKey('glass_nav_island')),
    );
    expect(island.fillColor?.a, closeTo(0.92, 0.002));
    expect(island.blurSigma, lessThanOrEqualTo(12));
    expect(island.preset, GlassSurfacePreset.navigation);
    expect(island.boxShadow, isNull);

    expect(
      find.descendant(of: intakeFinder, matching: find.byType(GlassSurface)),
      findsNothing,
    );
    expect(
      find.descendant(of: intakeFinder, matching: find.byType(AnimatedSlide)),
      findsNothing,
    );
    expect(
      find.descendant(of: intakeFinder, matching: find.byType(AnimatedScale)),
      findsNothing,
    );

    final intakeMaterial = tester.widget<Material>(
      find.descendant(of: intakeFinder, matching: find.byType(Material)).first,
    );
    expect(intakeMaterial.elevation, 0);
    expect(intakeMaterial.shadowColor, Colors.transparent);

    semantics.dispose();
  });

  testWidgets('GlassNavigationBar keeps side dock geometry at both widths', (
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
                onIntakePressed: () {},
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
    var intakeRect = tester.getRect(
      find.byKey(const ValueKey('glass_nav_intake_action')),
    );
    expect(rect.left, 14);
    expect(915 - rect.bottom, 12);
    expect(rect.height, GlassNavigationBar.islandHeight);
    expect(intakeRect.size, const Size.square(72));
    expect(intakeRect.left - rect.right, GlassNavigationBar.dockGap);
    expect(412 - intakeRect.right, 14);
    expect(intakeRect.top, rect.top);
    expect(intakeRect.bottom, rect.bottom);
    expect(
      GlassNavigationBar.contentFadeInset(
        tester.element(find.byType(GlassNavigationBar)),
      ),
      92,
    );

    await pumpAt(const Size(360, 800));
    rect = tester.getRect(find.byKey(const ValueKey('glass_nav_island')));
    intakeRect = tester.getRect(
      find.byKey(const ValueKey('glass_nav_intake_action')),
    );
    expect(rect.left, 12);
    expect(800 - rect.bottom, 10);
    expect(rect.height, GlassNavigationBar.compactIslandHeight);
    expect(intakeRect.size, const Size.square(68));
    expect(intakeRect.left - rect.right, GlassNavigationBar.dockGap);
    expect(360 - intakeRect.right, 12);
    expect(intakeRect.top, rect.top);
    expect(intakeRect.bottom, rect.bottom);
    expect(
      GlassNavigationBar.contentFadeInset(
        tester.element(find.byType(GlassNavigationBar)),
      ),
      86,
    );
  });

  testWidgets('GlassNavigationBar clears the gesture navigation inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(412, 915),
            padding: EdgeInsets.only(bottom: 34),
            viewPadding: EdgeInsets.only(bottom: 34),
          ),
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: GlassNavigationBar(
                selectedIndex: 0,
                items: items,
                onDestinationSelected: (_) {},
                onIntakePressed: () {},
              ),
            ),
          ),
        ),
      ),
    );

    final islandRect = tester.getRect(
      find.byKey(const ValueKey('glass_nav_island')),
    );
    expect(915 - islandRect.bottom, 34);
    expect(
      GlassNavigationBar.contentFadeInset(
        tester.element(find.byType(GlassNavigationBar)),
      ),
      114,
    );
  });

  testWidgets('GlassNavigationBar reports destination and intake taps', (
    tester,
  ) async {
    int? selected;
    var intakePressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: GlassNavigationBar(
              selectedIndex: 0,
              items: items,
              onDestinationSelected: (index) => selected = index,
              onIntakePressed: () => intakePressed = true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('订单'));
    expect(selected, 1);

    await tester.tap(find.text('报销'));
    expect(selected, 3);

    await tester.tap(find.byKey(const ValueKey('glass_nav_intake_action')));
    expect(intakePressed, isTrue);
  });
}

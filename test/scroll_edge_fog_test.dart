import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/core/theme/app_theme.dart';
import 'package:receipt_tamer/presentation/widgets/common/scroll_edge_fog.dart';

void main() {
  test('标题栏与雾边默认使用同一页面纸色', () {
    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      expect(theme.appBarTheme.backgroundColor, theme.scaffoldBackgroundColor);
    }
  });

  testWidgets('上下雾边按配置尺寸覆盖滚动视口', (tester) async {
    const fogColor = Color(0xFFEDF4F1);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            height: 320,
            child: ScrollEdgeFog(
              topHeight: 24,
              bottomHeight: 52,
              fogColor: fogColor,
              child: ColoredBox(color: Colors.white),
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(ScrollEdgeFog.topFogKey)).height, 24);
    expect(tester.getSize(find.byKey(ScrollEdgeFog.bottomFogKey)).height, 52);

    final topGradient = _gradientFor(tester, ScrollEdgeFog.topFogKey);
    final bottomGradient = _gradientFor(tester, ScrollEdgeFog.bottomFogKey);
    expect(topGradient.begin, Alignment.topCenter);
    expect(topGradient.end, Alignment.bottomCenter);
    expect(bottomGradient.begin, Alignment.bottomCenter);
    expect(bottomGradient.end, Alignment.topCenter);
    expect(topGradient.colors.first, fogColor);
    expect(bottomGradient.colors.first, fogColor);
    expect(topGradient.colors.last.a, 0);
    expect(bottomGradient.colors.last.a, 0);
  });

  testWidgets('可分别关闭雾边并默认继承页面纸色', (tester) async {
    const pageColor = Color(0xFF102526);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(scaffoldBackgroundColor: pageColor),
        home: const Scaffold(
          body: SizedBox(
            width: 200,
            height: 240,
            child: ScrollEdgeFog(
              showBottom: false,
              child: ColoredBox(color: Colors.white),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(ScrollEdgeFog.topFogKey), findsOneWidget);
    expect(find.byKey(ScrollEdgeFog.bottomFogKey), findsNothing);
    expect(
      _gradientFor(tester, ScrollEdgeFog.topFogKey).colors.first,
      pageColor,
    );
  });

  testWidgets('雾边不拦截顶部或底部的滚动内容交互', (tester) async {
    var tapCount = 0;
    const contentKey = ValueKey<String>('interactive-scroll-content');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              height: 240,
              child: ScrollEdgeFog(
                topHeight: 72,
                bottomHeight: 72,
                child: GestureDetector(
                  key: contentKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: () => tapCount++,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final contentRect = tester.getRect(find.byKey(contentKey));
    await tester.tapAt(contentRect.topCenter + const Offset(0, 12));
    await tester.tapAt(contentRect.bottomCenter - const Offset(0, 12));
    await tester.pump();

    expect(tapCount, 2);
    expect(
      find.descendant(
        of: find.byType(ScrollEdgeFog),
        matching: find.byType(IgnorePointer),
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('顶部透明渐隐只遮罩内容且保留底部雾边', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            height: 320,
            child: ScrollEdgeFog(
              fadeTopToTransparent: true,
              topHeight: 28,
              topInset: 12,
              bottomHeight: 52,
              child: ColoredBox(color: Colors.white),
            ),
          ),
        ),
      ),
    );

    final maskFinder = find.byKey(ScrollEdgeFog.topTransparencyMaskKey);
    expect(maskFinder, findsOneWidget);
    expect(tester.widget<ShaderMask>(maskFinder).blendMode, BlendMode.dstIn);
    expect(find.byKey(ScrollEdgeFog.topFogKey), findsNothing);
    expect(find.byKey(ScrollEdgeFog.topGuardKey), findsNothing);
    expect(find.byKey(ScrollEdgeFog.bottomFogKey), findsOneWidget);
    expect(tester.getSize(find.byKey(ScrollEdgeFog.bottomFogKey)).height, 52);
  });

  testWidgets('默认实色雾边不引入实时模糊或 ShaderMask', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ScrollEdgeFog(child: SingleChildScrollView(child: Text('账页'))),
        ),
      ),
    );

    final fog = find.byType(ScrollEdgeFog);
    expect(
      find.descendant(of: fog, matching: find.byType(BackdropFilter)),
      findsNothing,
    );
    expect(
      find.descendant(of: fog, matching: find.byType(ShaderMask)),
      findsNothing,
    );
  });

  testWidgets('固定控件占位使用纸色遮挡且雾边贴合其上沿', (tester) async {
    const fogColor = Color(0xFFEDF4F1);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            height: 320,
            child: ScrollEdgeFog(
              topHeight: 24,
              bottomHeight: 52,
              topInset: 40,
              bottomInset: 88,
              fogColor: fogColor,
              child: ColoredBox(color: Colors.white),
            ),
          ),
        ),
      ),
    );

    final viewport = tester.getRect(find.byType(ScrollEdgeFog));
    final topGuard = tester.getRect(find.byKey(ScrollEdgeFog.topGuardKey));
    final topFog = tester.getRect(find.byKey(ScrollEdgeFog.topFogKey));
    final bottomGuard = tester.getRect(
      find.byKey(ScrollEdgeFog.bottomGuardKey),
    );
    final bottomFog = tester.getRect(find.byKey(ScrollEdgeFog.bottomFogKey));

    expect(topGuard.top, viewport.top);
    expect(topGuard.height, 40);
    expect(topFog.top, topGuard.bottom);
    expect(bottomGuard.bottom, viewport.bottom);
    expect(bottomGuard.height, 88);
    expect(bottomFog.bottom, bottomGuard.top);
    expect(
      tester
          .widget<ColoredBox>(
            find.descendant(
              of: find.byKey(ScrollEdgeFog.bottomGuardKey),
              matching: find.byType(ColoredBox),
            ),
          )
          .color,
      fogColor,
    );
  });
}

LinearGradient _gradientFor(WidgetTester tester, Key fogKey) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byKey(fogKey),
      matching: find.byType(DecoratedBox),
    ),
  );
  return (box.decoration as BoxDecoration).gradient! as LinearGradient;
}

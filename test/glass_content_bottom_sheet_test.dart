import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/core/theme/app_theme.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_alert_dialog.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_bottom_sheet.dart'
    show GlassBottomSheet;
import 'package:receipt_tamer/presentation/widgets/common/glass_surface.dart';

void main() {
  testWidgets('content sheet uses one local blur and preserves its result', (
    tester,
  ) async {
    _setViewport(tester, const Size(412, 915));
    late Future<String?> result;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                key: const ValueKey('open_sheet'),
                onPressed: () {
                  result = showGlassContentBottomSheet<String>(
                    context: context,
                    builder: (sheetContext) => SizedBox(
                      height: 120,
                      child: Center(
                        child: TextButton(
                          key: const ValueKey('return_result'),
                          onPressed: () =>
                              Navigator.of(sheetContext).pop('已选择'),
                          child: const Text('选择'),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open_sheet')));
    await tester.pumpAndSettle();

    expect(find.byType(GlassBottomSheet), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);

    final surface = tester.widget<GlassSurface>(
      find.descendant(
        of: find.byType(GlassBottomSheet),
        matching: find.byType(GlassSurface),
      ),
    );
    expect(surface.preset, GlassSurfacePreset.sheet);
    expect(surface.fillColor?.a, closeTo(0.94, 0.002));
    expect(surface.blurSigma, 10);

    final blurRect = tester.getRect(find.byType(BackdropFilter));
    expect(blurRect.width, lessThan(412));
    expect(blurRect.height, lessThan(915));

    final routeSheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(routeSheet.backgroundColor, Colors.transparent);

    await tester.tap(find.byKey(const ValueKey('return_result')));
    await tester.pumpAndSettle();
    expect(await result, '已选择');
  });

  testWidgets(
    'content sheet keeps nearest-navigator and barrier-dismiss defaults',
    (tester) async {
      final rootObserver = _CountingNavigatorObserver();
      final nestedObserver = _CountingNavigatorObserver();
      late Future<String?> result;

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [rootObserver],
          home: Navigator(
            observers: [nestedObserver],
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    key: const ValueKey('open_nested_sheet'),
                    onPressed: () {
                      result = showGlassContentBottomSheet<String>(
                        context: context,
                        builder: (_) => const SizedBox(
                          height: 100,
                          child: Center(child: Text('最近的 Navigator')),
                        ),
                      );
                    },
                    child: const Text('打开'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rootPushesBefore = rootObserver.pushes;
      final nestedPushesBefore = nestedObserver.pushes;
      final nestedPopsBefore = nestedObserver.pops;

      await tester.tap(find.byKey(const ValueKey('open_nested_sheet')));
      await tester.pumpAndSettle();

      expect(rootObserver.pushes, rootPushesBefore);
      expect(nestedObserver.pushes, nestedPushesBefore + 1);

      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      expect(nestedObserver.pops, nestedPopsBefore + 1);
      expect(await result, isNull);
      expect(find.byType(GlassBottomSheet), findsNothing);
    },
  );

  testWidgets('content sheet forwards shape and scroll-controlled layout', (
    tester,
  ) async {
    _setViewport(tester, const Size(412, 800));
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                key: const ValueKey('open_tall_sheet'),
                onPressed: () {
                  showGlassContentBottomSheet<void>(
                    context: context,
                    shape: shape,
                    isScrollControlled: true,
                    builder: (_) => const SizedBox(
                      height: 650,
                      child: Center(child: Text('完整高度内容')),
                    ),
                  );
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open_tall_sheet')));
    await tester.pumpAndSettle();

    final surface = tester.widget<GlassSurface>(
      find.descendant(
        of: find.byType(GlassBottomSheet),
        matching: find.byType(GlassSurface),
      ),
    );
    expect(
      surface.borderRadius,
      const BorderRadius.all(Radius.circular(16)),
      reason: '悬浮 Sheet 四角都应闭合，不能在底部留出方形透明缺口。',
    );
    expect(
      tester.getSize(find.byType(BackdropFilter)).height,
      greaterThan(600),
    );
    expect(tester.widget<BottomSheet>(find.byType(BottomSheet)).shape, shape);
  });
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

class _CountingNavigatorObserver extends NavigatorObserver {
  int pushes = 0;
  int pops = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pops++;
  }
}

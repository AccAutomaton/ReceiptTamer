import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/core/theme/app_system_ui.dart';
import 'package:receipt_tamer/core/theme/app_theme.dart';
import 'package:receipt_tamer/presentation/widgets/invoice/invoice_image_preview.dart'
    as invoice_preview;
import 'package:receipt_tamer/presentation/widgets/order/order_image_preview.dart'
    as order_preview;

void main() {
  test('系统栏样式保持透明并随页面明暗提供可见图标', () {
    final light = AppSystemUi.overlayStyleFor(Brightness.light);
    final dark = AppSystemUi.overlayStyleFor(Brightness.dark);

    for (final style in [light, dark]) {
      expect(style.statusBarColor, Colors.transparent);
      expect(style.systemNavigationBarColor, Colors.transparent);
      expect(style.systemNavigationBarDividerColor, Colors.transparent);
      expect(style.systemStatusBarContrastEnforced, isFalse);
      expect(style.systemNavigationBarContrastEnforced, isFalse);
    }

    expect(light.statusBarIconBrightness, Brightness.dark);
    expect(light.systemNavigationBarIconBrightness, Brightness.dark);
    expect(dark.statusBarIconBrightness, Brightness.light);
    expect(dark.systemNavigationBarIconBrightness, Brightness.light);
    expect(AppTheme.lightTheme.appBarTheme.systemOverlayStyle, light);
    expect(AppTheme.darkTheme.appBarTheme.systemOverlayStyle, dark);
  });

  testWidgets('启动配置显式启用 edge-to-edge 并关闭系统栏遮罩', (tester) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await AppSystemUi.configureForStartup(Brightness.light);
    await tester.pump();

    final modeCall = calls.singleWhere(
      (call) => call.method == 'SystemChrome.setEnabledSystemUIMode',
    );
    expect(modeCall.arguments, 'SystemUiMode.edgeToEdge');

    final styleCall = calls.singleWhere(
      (call) => call.method == 'SystemChrome.setSystemUIOverlayStyle',
    );
    final arguments = styleCall.arguments as Map<dynamic, dynamic>;
    expect(
      arguments['systemNavigationBarColor'],
      Colors.transparent.toARGB32(),
    );
    expect(
      arguments['systemNavigationBarDividerColor'],
      Colors.transparent.toARGB32(),
    );
    expect(arguments['systemStatusBarContrastEnforced'], isFalse);
    expect(arguments['systemNavigationBarContrastEnforced'], isFalse);
  });

  testWidgets('黑底图片预览始终使用浅色系统图标', (tester) async {
    Future<void> verify(Widget preview) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: preview),
      );

      final expected = AppSystemUi.overlayStyleFor(Brightness.dark);
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      final systemUiRegion = tester
          .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byKey(const ValueKey('full_screen_image_system_ui')),
          );
      expect(appBar.systemOverlayStyle, expected);
      expect(systemUiRegion.value, expected);
    }

    await verify(
      const order_preview.FullScreenImagePreview(
        imagePath: '__missing_order_preview__.png',
      ),
    );
    await verify(
      const invoice_preview.FullScreenImagePreview(
        imagePath: '__missing_invoice_preview__.png',
      ),
    );
  });
}

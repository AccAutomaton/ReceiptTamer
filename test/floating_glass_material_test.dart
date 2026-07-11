import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_alert_dialog.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_bottom_sheet.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_surface.dart';

void main() {
  testWidgets('bottom sheet keeps blur local and uses a high-opacity fill', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: GlassBottomSheet(child: Text('新增订单'))),
      ),
    );

    final surface = tester.widget<GlassSurface>(
      find.descendant(
        of: find.byType(GlassBottomSheet),
        matching: find.byType(GlassSurface),
      ),
    );
    expect(surface.fillColor?.a, closeTo(0.94, 0.002));
    expect(surface.blurSigma, 10);
    expect(surface.preset, GlassSurfacePreset.sheet);
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('dialog blurs only its own high-opacity surface', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GlassAlertDialog(title: Text('删除订单'), content: Text('此操作不可撤销')),
        ),
      ),
    );

    final surface = tester.widget<GlassSurface>(
      find.descendant(
        of: find.byType(GlassAlertDialog),
        matching: find.byType(GlassSurface),
      ),
    );
    expect(surface.fillColor?.a, closeTo(0.94, 0.002));
    expect(surface.blurSigma, 12);
    expect(surface.preset, GlassSurfacePreset.dialog);

    final blur = find.byType(BackdropFilter);
    expect(blur, findsOneWidget);
    final blurSize = tester.getSize(blur);
    expect(blurSize.width, lessThan(412));
    expect(blurSize.height, lessThan(915));
  });
}

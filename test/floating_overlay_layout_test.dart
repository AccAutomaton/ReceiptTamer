import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/presentation/widgets/common/floating_overlay_layout.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_surface.dart';
import 'package:receipt_tamer/presentation/widgets/common/scroll_edge_fog.dart';

void main() {
  testWidgets('wraps floating overlays and reserves measured space', (
    tester,
  ) async {
    EdgeInsets? latestPadding;

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(viewPadding: const EdgeInsets.only(bottom: 24)),
            child: child!,
          );
        },
        home: Scaffold(
          body: FloatingOverlayLayout(
            topSpacing: 12,
            bottomSpacing: 16,
            top: const SizedBox(height: 50, child: Text('top')),
            bottom: const SizedBox(height: 80, child: Text('bottom')),
            bodyBuilder: (context, contentPadding) {
              latestPadding = contentPadding;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(GlassSurface), findsNWidgets(2));
    expect(find.byType(SafeArea), findsNothing);
    expect(latestPadding?.top, 94);
    expect(latestPadding?.bottom, 156);
    expect(
      tester.getSize(find.byKey(ScrollEdgeFog.topGuardKey)).height,
      latestPadding?.top,
    );
    expect(
      tester.getSize(find.byKey(ScrollEdgeFog.bottomGuardKey)).height,
      latestPadding?.bottom,
    );

    for (final surface in tester.widgetList<GlassSurface>(
      find.byType(GlassSurface),
    )) {
      expect(surface.fillColor?.a, closeTo(0.92, 0.002));
      expect(surface.blurSigma, 10);
      expect(surface.preset, GlassSurfacePreset.floating);
    }
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/presentation/widgets/common/floating_overlay_layout.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_surface.dart';

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
  });
}

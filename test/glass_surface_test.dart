import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_surface.dart';

void main() {
  testWidgets('GlassSurface renders child with blur and rounded clipping', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: GlassSurface(
              borderRadius: BorderRadius.all(Radius.circular(24)),
              child: Text('玻璃内容'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('玻璃内容'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(ClipRRect), findsOneWidget);

    final clip = tester.widget<ClipRRect>(find.byType(ClipRRect).first);
    expect(clip.borderRadius, BorderRadius.circular(24));

    final filter = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
    expect(filter.filter, isA<ImageFilter>());
  });

  testWidgets('GlassSurface uses cold muted defaults', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GlassSurface(child: SizedBox(width: 20, height: 20)),
        ),
      ),
    );

    final decorations = find
        .descendant(
          of: find.byType(GlassSurface),
          matching: find.byType(DecoratedBox),
        )
        .evaluate()
        .map((element) => (element.widget as DecoratedBox).decoration)
        .whereType<BoxDecoration>();
    final decoration = decorations.firstWhere(
      (decoration) => decoration.color == AppGlassTokens.lightFill,
    );

    expect(decoration.color, AppGlassTokens.lightFill);
    expect(decoration.borderRadius, BorderRadius.circular(AppRadii.glassLarge));
    expect(decoration.border, isNull);
    expect(decoration.gradient, isNotNull);
  });
}

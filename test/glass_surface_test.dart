import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_surface.dart';

void main() {
  test(
    'surface tokens separate opaque content from legible floating fills',
    () {
      expect(AppGlassTokens.contentFill.a, 1);
      for (final fill in [
        AppGlassTokens.lightFill,
        AppGlassTokens.darkFill,
        AppGlassTokens.lightModalFill,
        AppGlassTokens.darkModalFill,
      ]) {
        expect(fill.a, inInclusiveRange(0.90, 0.95));
      }
      expect(AppGlassTokens.blurSigma, lessThanOrEqualTo(12));
    },
  );

  testWidgets('panel surface renders without blur and keeps rounded clipping', (
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
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(ClipRRect), findsOneWidget);

    final clip = tester.widget<ClipRRect>(find.byType(ClipRRect).first);
    expect(clip.borderRadius, BorderRadius.circular(24));
  });

  testWidgets('panel surface uses an opaque flat entity default', (
    tester,
  ) async {
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
      (decoration) => decoration.color == AppEntityTokens.lightFill,
    );

    expect(decoration.color, AppEntityTokens.lightFill);
    expect(decoration.color!.a, 1);
    expect(decoration.borderRadius, BorderRadius.circular(AppRadii.glassLarge));
    expect(decoration.border, isNotNull);
    expect(decoration.gradient, isNull);
    expect(decoration.boxShadow, isNull);
    expect(
      find.descendant(
        of: find.byType(GlassSurface),
        matching: find.byType(ColoredBox),
      ),
      findsNothing,
    );
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('panel pre-composites legacy translucent content fills', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GlassSurface(
            fillColor: AppGlassTokens.lightFill,
            child: Text('月份栏'),
          ),
        ),
      ),
    );

    final opaqueFill = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(GlassSurface),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((widget) => widget.decoration)
        .whereType<BoxDecoration>()
        .map((decoration) => decoration.color)
        .whereType<Color>()
        .firstWhere((color) => color.a == 1);
    expect(opaqueFill.a, 1);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('floating and modal roles keep one bounded blur layer', (
    tester,
  ) async {
    Future<void> pumpPreset(GlassSurfacePreset preset) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassSurface(
              preset: preset,
              blurSigma: 30,
              child: const Text('浮层'),
            ),
          ),
        ),
      );
    }

    void expectClampedSurface(Color fillColor) {
      final backdropFilterFinder = find.byType(BackdropFilter);
      expect(backdropFilterFinder, findsOneWidget);
      final backdropFilter = tester.widget<BackdropFilter>(
        backdropFilterFinder,
      );
      expect(
        backdropFilter.filter,
        ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      );
      final decoration = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(GlassSurface),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((widget) => widget.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((value) => value.color == fillColor);
      expect(decoration.color!.a, inInclusiveRange(0.90, 0.95));
      expect(decoration.boxShadow, isNull);
    }

    await pumpPreset(GlassSurfacePreset.floating);
    expectClampedSurface(AppGlassTokens.lightFill);

    await pumpPreset(GlassSurfacePreset.sheet);
    expectClampedSurface(AppGlassTokens.lightModalFill);
  });
}

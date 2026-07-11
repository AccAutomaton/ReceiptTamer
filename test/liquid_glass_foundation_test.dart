import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_button.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_card.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_surface.dart';
import 'package:receipt_tamer/presentation/widgets/common/liquid_glass_background.dart';

void main() {
  testWidgets('AppCard uses an opaque morning-mist relief surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppCard(child: Text('内容卡片'))),
      ),
    );

    final decorations = find
        .descendant(
          of: find.byType(AppCard),
          matching: find.byType(DecoratedBox),
        )
        .evaluate()
        .map((element) => element.widget)
        .whereType<DecoratedBox>()
        .map((widget) => widget.decoration)
        .whereType<BoxDecoration>();
    final decoration = decorations.firstWhere(
      (decoration) => decoration.color == AppGlassTokens.contentFill,
    );

    expect(decoration.color, AppGlassTokens.contentFill);
    expect(decoration.color!.a, 1);
    expect(decoration.gradient, isNull);
    expect(decoration.borderRadius, BorderRadius.circular(AppRadii.card));
    expect(decoration.border, isNotNull);
    expect(decoration.boxShadow, isNotEmpty);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('interactive AppCard removes press motion when requested', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: AppCard(onTap: () {}, child: const Text('可点击卡片')),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('可点击卡片')),
    );
    await tester.pump();
    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.duration, Duration.zero);
    expect(scale.scale, 1);
    await gesture.up();
  });

  testWidgets('AppIconButton uses one legible floating blur surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppIconButton(icon: Icons.search, onPressed: () {}),
        ),
      ),
    );

    final iconButton = tester.widget<IconButton>(find.byType(IconButton));
    final style = iconButton.style!;
    final background = style.backgroundColor!.resolve(<WidgetState>{});
    final shape =
        style.shape!.resolve(<WidgetState>{})! as RoundedRectangleBorder;

    expect(background, Colors.transparent);
    expect(style.minimumSize!.resolve(<WidgetState>{}), const Size(44, 44));
    expect(shape.borderRadius, BorderRadius.circular(AppRadii.control));
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(
      tester
          .widget<GlassSurface>(
            find.descendant(
              of: find.byType(AppIconButton),
              matching: find.byType(GlassSurface),
            ),
          )
          .preset,
      GlassSurfacePreset.floating,
    );

    final floatingDecoration = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(AppIconButton),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((widget) => widget.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((value) => value.color == AppGlassTokens.lightFill);
    expect(floatingDecoration.color!.a, inInclusiveRange(0.90, 0.95));
    expect(AppGlassTokens.blurSigma, lessThanOrEqualTo(12));
  });

  testWidgets('AppButton stays opaque and disables press motion on request', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: AppButton(text: '保存', onPressed: () {}),
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsNothing);
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration,
      Duration.zero,
    );
    expect(
      tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).duration,
      Duration.zero,
    );
  });

  testWidgets('LiquidGlassBackground paints a non-flat morning backdrop', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LiquidGlassBackground(child: Text('晨雾背景'))),
      ),
    );

    expect(find.text('晨雾背景'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(LiquidGlassBackground),
        matching: find.byType(DecoratedBox),
      ),
      findsWidgets,
    );
  });
}

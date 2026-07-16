import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_button.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_card.dart';
import 'package:receipt_tamer/presentation/widgets/common/liquid_glass_background.dart';

void main() {
  testWidgets('AppCard uses an opaque flat surface with one outline', (
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
    expect(decoration.boxShadow, isNull);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('interactive AppCard keeps flat geometry while pressed', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppCard(onTap: () => tapped = true, child: const Text('可点击卡片')),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('可点击卡片')),
    );
    await tester.pump();
    expect(find.byType(AnimatedScale), findsNothing);
    expect(find.byType(AnimatedSlide), findsNothing);
    await gesture.up();
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('AppIconButton uses flat transparent chrome', (tester) async {
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
    expect(
      style.backgroundColor!.resolve(<WidgetState>{WidgetState.disabled}),
      Colors.transparent,
    );
    expect(style.side!.resolve(<WidgetState>{}), BorderSide.none);
    expect(style.minimumSize!.resolve(<WidgetState>{}), const Size(44, 44));
    expect(shape.borderRadius, BorderRadius.circular(AppRadii.control));
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('AppButton stays opaque with zero elevation in every state', (
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
    expect(find.byType(AnimatedScale), findsNothing);
    expect(find.byType(AnimatedSlide), findsNothing);

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    for (final states in <Set<WidgetState>>[
      <WidgetState>{},
      <WidgetState>{WidgetState.pressed},
      <WidgetState>{WidgetState.hovered},
      <WidgetState>{WidgetState.focused},
    ]) {
      expect(button.style!.elevation!.resolve(states), 0);
      expect(button.style!.shadowColor!.resolve(states), Colors.transparent);
    }
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

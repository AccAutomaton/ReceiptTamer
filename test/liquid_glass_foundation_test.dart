import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_button.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_card.dart';
import 'package:receipt_tamer/presentation/widgets/common/liquid_glass_background.dart';

void main() {
  testWidgets('AppCard uses a readable cold liquid card surface', (
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
      (decoration) => decoration.color == const Color(0xF7FFFFFF),
    );

    expect(decoration.color, const Color(0xF7FFFFFF));
    expect(decoration.gradient, isNotNull);
    expect(decoration.borderRadius, BorderRadius.circular(22));
    expect(decoration.border, isNull);
  });

  testWidgets('AppIconButton uses visible action capsule defaults', (
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

    expect(background, AppPalette.actionSoftFill);
    expect(style.minimumSize!.resolve(<WidgetState>{}), const Size(44, 44));
    expect(shape.borderRadius, BorderRadius.circular(18));
  });

  testWidgets('LiquidGlassBackground paints a non-flat cold backdrop', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LiquidGlassBackground(child: Text('鍐烽浘鑳屾櫙'))),
      ),
    );

    expect(find.text('鍐烽浘鑳屾櫙'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(LiquidGlassBackground),
        matching: find.byType(DecoratedBox),
      ),
      findsWidgets,
    );
  });
}

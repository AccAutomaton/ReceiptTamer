import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/core/theme/app_theme.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_text_field.dart';

void main() {
  testWidgets('AppTextField suffix IconButton uses plain field styling', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: AppTextField(
            controller: TextEditingController(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.arrow_drop_down),
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    final iconContext = tester.element(find.byIcon(Icons.arrow_drop_down));
    final style = IconButtonTheme.of(iconContext).style!;
    final colorScheme = AppTheme.lightTheme.colorScheme;

    expect(style.backgroundColor!.resolve(<WidgetState>{}), Colors.transparent);
    expect(
      style.foregroundColor!.resolve(<WidgetState>{}),
      colorScheme.onSurfaceVariant,
    );
    expect(style.side!.resolve(<WidgetState>{}), BorderSide.none);
  });

  testWidgets('AppTextField uses an opaque flat field without blur', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: AppTextField(hint: '字段提示')),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration!.fillColor, AppEntityTokens.lightFill);
    expect(field.decoration!.fillColor!.a, 1);
    final border = field.decoration!.enabledBorder;
    expect(border, isA<AppReliefInputBorder>());
    final flatBorder = border! as AppReliefInputBorder;
    expect(flatBorder.borderSide.width, 1);
    expect(flatBorder.highlightColor, Colors.transparent);
    expect(flatBorder.ridgeColor, Colors.transparent);
    expect(flatBorder.ridgeWidth, 0);
    expect(find.byType(BackdropFilter), findsNothing);
  });
}

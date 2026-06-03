import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/core/theme/app_theme.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_text_field.dart';

void main() {
  testWidgets(
    'AppSelectField uses an opaque rounded relief decorator without blur',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 240,
                child: AppSelectField<String>(
                  value: 'breakfast',
                  options: const ['breakfast', 'lunch'],
                  displayValue: (value) => value,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      final inputDecorator = tester.widget<InputDecorator>(
        find.byType(InputDecorator),
      );

      expect(inputDecorator.decoration.fillColor, AppEntityTokens.lightFill);
      expect(inputDecorator.decoration.fillColor?.a, 1);
      expect(
        inputDecorator.decoration.border,
        isA<AppReliefInputBorder>()
            .having(
              (border) => border.borderRadius,
              'borderRadius',
              BorderRadius.circular(AppRadii.control),
            )
            .having(
              (border) => border.borderSide,
              'borderSide',
              const BorderSide(color: AppEntityTokens.lightStrongBorder),
            ),
      );
      expect(find.byType(BackdropFilter), findsNothing);
    },
  );

  testWidgets('AppSelectField opens menu with control border radius', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              child: AppSelectField<String>(
                value: 'breakfast',
                options: const ['breakfast', 'lunch'],
                displayValue: (value) => value,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ClipRRect &&
            widget.borderRadius == BorderRadius.circular(AppRadii.control) &&
            widget.clipBehavior == Clip.antiAlias,
      ),
      findsOneWidget,
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/core/theme/app_theme.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_text_field.dart';

void main() {
  testWidgets('AppSelectField uses an opaque flat outline without blur', (
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

    final inputDecorator = tester.widget<InputDecorator>(
      find.byType(InputDecorator),
    );
    final dropdown = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );

    expect(inputDecorator.decoration.fillColor, AppEntityTokens.lightFill);
    expect(inputDecorator.decoration.fillColor?.a, 1);
    expect(dropdown.elevation, 0);
    final border = inputDecorator.decoration.border;
    expect(border, isA<AppReliefInputBorder>());
    final flatBorder = border! as AppReliefInputBorder;
    expect(flatBorder.borderRadius, BorderRadius.circular(AppRadii.control));
    expect(
      flatBorder.borderSide,
      const BorderSide(color: AppEntityTokens.lightStrongBorder),
    );
    expect(flatBorder.highlightColor, Colors.transparent);
    expect(flatBorder.ridgeColor, Colors.transparent);
    expect(flatBorder.ridgeWidth, 0);
    expect(find.byType(BackdropFilter), findsNothing);
  });

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

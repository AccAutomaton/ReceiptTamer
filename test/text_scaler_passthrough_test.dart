import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_text_field.dart';
import 'package:receipt_tamer/presentation/widgets/order/month_fast_scroll_bar.dart';

void main() {
  testWidgets('compound required labels inherit the active UI text scaler', (
    tester,
  ) async {
    final activeScaler = AppTypography.enlargeUiText(
      const TextScaler.linear(1.5),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: activeScaler),
          child: Scaffold(
            body: ListView(
              children: [
                const AppTextField(label: '必填文本', required: true),
                AppSelectField<String>(
                  label: '必填选项',
                  required: true,
                  options: const ['选项'],
                  displayValue: (value) => value,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final compoundLabels = tester
        .widgetList<RichText>(find.byType(RichText))
        .where(
          (richText) =>
              const {'必填文本 *', '必填选项 *'}.contains(richText.text.toPlainText()),
        )
        .toList();

    expect(compoundLabels, hasLength(2));
    for (final label in compoundLabels) {
      expect(label.textScaler, same(activeScaler));
      expect(label.textScaler.scale(14), 22.5);
    }
  });

  testWidgets(
    'month rail paints and repaints with the app step and accessibility scale',
    (tester) async {
      final recordingScaler = _RecordingTextScaler();

      await tester.pumpWidget(_railApp(textScaler: recordingScaler));
      await tester.pumpAndSettle();
      final basePainter = _railPainter(tester);
      expect(recordingScaler.scaledFontSizes, containsAll(<double>[7, 8, 10]));
      expect((basePainter as dynamic).textScaler, same(recordingScaler));

      final steppedScaler = AppTypography.enlargeUiText(TextScaler.noScaling);
      await tester.pumpWidget(_railApp(textScaler: steppedScaler));
      await tester.pumpAndSettle();
      final steppedPainter = _railPainter(tester);

      expect(steppedPainter.shouldRepaint(basePainter), isTrue);
      expect((steppedPainter as dynamic).textScaler, same(steppedScaler));
      expect(steppedScaler.scale(8), 9);

      final accessibleScaler = AppTypography.enlargeUiText(
        const TextScaler.linear(2),
      );
      await tester.pumpWidget(_railApp(textScaler: accessibleScaler));
      await tester.pumpAndSettle();
      final accessiblePainter = _railPainter(tester);

      expect(accessiblePainter.shouldRepaint(steppedPainter), isTrue);
      expect((accessiblePainter as dynamic).textScaler, same(accessibleScaler));
      expect(accessibleScaler.scale(8), 18);
    },
  );
}

Widget _railApp({required TextScaler textScaler}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: textScaler),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: 32,
            height: 280,
            child: MonthFastScrollBar(
              items: const [
                MonthScrollItem(year: 2025, month: 12),
                MonthScrollItem(year: 2026, month: 1),
                MonthScrollItem(year: 2026, month: 2),
              ],
              onJumpToIndex: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
}

CustomPainter _railPainter(WidgetTester tester) {
  final customPaint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(MonthFastScrollBar),
      matching: find.byType(CustomPaint),
    ),
  );
  return customPaint.painter!;
}

class _RecordingTextScaler extends TextScaler {
  final scaledFontSizes = <double>[];

  @override
  double scale(double fontSize) {
    scaledFontSizes.add(fontSize);
    return fontSize;
  }

  @override
  double get textScaleFactor => 1;
}

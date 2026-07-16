import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/core/theme/app_theme.dart';

void main() {
  test('Tinos 四种字形在 Flutter 字体清单中保持注册', () {
    final pubspec = File(
      'pubspec.yaml',
    ).readAsStringSync().replaceAll('\r\n', '\n');

    expect(pubspec, contains('- family: Tinos'));
    for (final asset in [
      'assets/fonts/Tinos-Regular.ttf',
      'assets/fonts/Tinos-Italic.ttf',
      'assets/fonts/Tinos-Bold.ttf',
      'assets/fonts/Tinos-BoldItalic.ttf',
    ]) {
      expect(pubspec, contains('- asset: $asset'));
    }
    expect(
      pubspec,
      contains(
        'Tinos-Italic.ttf\n          weight: 400\n          style: italic',
      ),
    );
    expect(
      pubspec,
      contains(
        'Tinos-BoldItalic.ttf\n          weight: 700\n          style: italic',
      ),
    );
  });

  test('全部 Material 文字角色使用同一衬线字体链', () {
    for (final brightness in Brightness.values) {
      final theme = AppTypography.textTheme(brightness);
      for (final style in _styles(theme)) {
        expect(style.fontFamily, AppTypography.primaryFamily);
        expect(style.fontFamilyFallback, AppTypography.serifFallback);
      }
    }

    expect(
      AppTypography.textTheme(Brightness.light).displayLarge!.letterSpacing,
      greaterThan(-1),
    );
    expect(
      AppTypography.textTheme(Brightness.light).labelSmall!.letterSpacing,
      greaterThan(0),
    );
  });

  test('浅暗主题均把衬线字体链传给 Material 默认样式', () {
    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      for (final style in _styles(theme.textTheme)) {
        expect(style.fontFamily, AppTypography.primaryFamily);
        expect(style.fontFamilyFallback, AppTypography.serifFallback);
      }
    }
  });

  testWidgets('金额和工具文字也使用 Tinos 与中文衬线回退', (tester) async {
    late TextStyle amountStyle;
    late TextStyle utilityStyle;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) {
            amountStyle = AppTypography.amount(context);
            utilityStyle = AppTypography.utility(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    for (final style in [amountStyle, utilityStyle]) {
      expect(style.fontFamily, AppTypography.primaryFamily);
      expect(style.fontFamilyFallback, AppTypography.serifFallback);
      expect(style.fontFeatures, AppTypography.tabularFigures);
    }
  });
}

List<TextStyle> _styles(TextTheme theme) => [
  theme.displayLarge!,
  theme.displayMedium!,
  theme.displaySmall!,
  theme.headlineLarge!,
  theme.headlineMedium!,
  theme.headlineSmall!,
  theme.titleLarge!,
  theme.titleMedium!,
  theme.titleSmall!,
  theme.bodyLarge!,
  theme.bodyMedium!,
  theme.bodySmall!,
  theme.labelLarge!,
  theme.labelMedium!,
  theme.labelSmall!,
];

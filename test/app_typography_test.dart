import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/core/theme/app_theme.dart';
import 'package:receipt_tamer/presentation/widgets/common/ledger_month_sheet.dart';

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

  testWidgets('真实 AppBar 在大一号正文下保留标题原字号与限幅', (tester) async {
    late double enlargedBodySize;
    late double originalTitleSize;
    late double reportedAccessibilityScale;
    late double clampedAccessibilityScale;

    for (final platformScale in [1.3, 2.0]) {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(platformScale),
              ),
              child: Builder(
                builder: (context) => AppTypography.applyUiTextSize(
                  context: context,
                  child: child!,
                ),
              ),
            );
          },
          home: Scaffold(
            appBar: AppBar(
              title: AppTypography.preserveOriginalSize(
                child: Builder(
                  builder: (context) {
                    originalTitleSize = MediaQuery.textScalerOf(
                      context,
                    ).scale(26);
                    clampedAccessibilityScale =
                        AppTypography.accessibilityScaleOf(context);
                    return const Text('页面标题');
                  },
                ),
              ),
            ),
            body: Builder(
              builder: (context) {
                enlargedBodySize = MediaQuery.textScalerOf(context).scale(14);
                reportedAccessibilityScale = AppTypography.accessibilityScaleOf(
                  context,
                );
                return const Text('正文');
              },
            ),
          ),
        ),
      );

      expect(enlargedBodySize, closeTo(15 * platformScale, 0.001));
      expect(
        originalTitleSize,
        closeTo(26 * platformScale.clamp(0, 1.34), 0.001),
      );
      expect(reportedAccessibilityScale, closeTo(platformScale, 0.001));
      expect(clampedAccessibilityScale, closeTo(platformScale, 0.001));
    }
  });

  test('重复组合字号增量不会二次放大', () {
    final enlarged = AppTypography.enlargeUiText(TextScaler.noScaling);

    expect(enlarged.scale(14), 15);
    expect(identical(AppTypography.enlargeUiText(enlarged), enlarged), isTrue);
  });

  testWidgets('默认大一号不会把月份栏高度比例误判为两倍', (tester) async {
    late double headerExtent;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => AppTypography.applyUiTextSize(
            context: context,
            child: Builder(
              builder: (context) {
                headerExtent = ledgerMonthHeaderExtent(
                  context,
                  sheetWidth: 380,
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );

    expect(headerExtent, inInclusiveRange(101, 120));
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

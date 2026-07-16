import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/core/theme/app_theme.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_button.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_text_field.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_navigation_bar.dart';
import 'package:receipt_tamer/presentation/widgets/common/muted_status_chip.dart';

void main() {
  test('浅暗色小字语义色对比度不低于 4.5:1', () {
    for (final scheme in [
      AppTheme.lightTheme.colorScheme,
      AppTheme.darkTheme.colorScheme,
    ]) {
      expect(
        _contrast(scheme.onSurfaceVariant, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(scheme.onSurfaceVariant, scheme.surfaceContainerLow),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(scheme.primary, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(scheme.error, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  test('触控、圆角与动效 token 符合验收边界', () {
    expect(AppSpacing.minTouchTarget, 48);
    expect({AppRadii.small, AppRadii.control, AppRadii.large}, {10, 14, 18});
    expect(AppMotion.fast.inMilliseconds, inInclusiveRange(160, 220));
    expect(AppMotion.standard.inMilliseconds, inInclusiveRange(160, 220));
    expect(AppMotion.emphasized.inMilliseconds, inInclusiveRange(160, 220));
  });

  testWidgets('输入提示使用不透明高对比石墨色', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: TextField(decoration: InputDecoration(hintText: '提示')),
        ),
      ),
    );

    final decoration = Theme.of(
      tester.element(find.byType(TextField)),
    ).inputDecorationTheme;
    expect(decoration.hintStyle?.color, AppPalette.textSecondary);
    expect(decoration.hintStyle?.color?.a, 1);
  });

  testWidgets('实际输入与选择组件的提示文字在浅暗色均满足 4.5:1', (tester) async {
    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: theme.brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          home: Scaffold(
            body: Column(
              children: [
                const AppTextField(hint: '文本提示'),
                AppSelectField<String>(
                  hint: '选择提示',
                  options: const ['选项'],
                  displayValue: (value) => value,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      final textHintColor = textField.decoration!.hintStyle!.color!;
      final textFieldBackground = theme.brightness == Brightness.dark
          ? theme.colorScheme.surfaceContainerLow
          : AppPalette.raisedWhite;
      expect(textHintColor.a, 1);
      expect(
        _contrast(textHintColor, textFieldBackground),
        greaterThanOrEqualTo(4.5),
      );

      final selectHint = tester.widget<Text>(find.text('选择提示'));
      final selectHintColor = selectHint.style!.color!;
      expect(selectHintColor.a, 1);
      expect(
        _contrast(
          selectHintColor,
          theme.brightness == Brightness.dark
              ? AppEntityTokens.darkFill
              : AppEntityTokens.lightFill,
        ),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  testWidgets('导航小字保持高对比并遵循减少动态效果', (tester) async {
    Future<void> pumpNavigation({
      required ThemeData theme,
      required bool disableAnimations,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: theme.brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: disableAnimations),
            child: Scaffold(
              body: GlassNavigationBar(
                selectedIndex: 0,
                items: const [
                  GlassNavItem(
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home,
                    label: '首页',
                  ),
                  GlassNavItem(
                    icon: Icons.receipt_long_outlined,
                    selectedIcon: Icons.receipt_long,
                    label: '订单',
                  ),
                  GlassNavItem(
                    icon: Icons.description_outlined,
                    selectedIcon: Icons.description,
                    label: '发票',
                  ),
                  GlassNavItem(
                    icon: Icons.inventory_2_outlined,
                    selectedIcon: Icons.inventory_2,
                    label: '报销',
                  ),
                ],
                onDestinationSelected: (_) {},
                onIntakePressed: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      await pumpNavigation(theme: theme, disableAnimations: false);
      final label = tester.widget<Text>(find.text('订单'));
      final panelFill = theme.brightness == Brightness.dark
          ? AppGlassTokens.darkFill
          : AppGlassTokens.lightFill;
      final effectivePanel = Color.alphaBlend(
        panelFill,
        theme.colorScheme.surface,
      );
      expect(
        _contrast(label.style!.color!, effectivePanel),
        greaterThanOrEqualTo(4.5),
      );

      final animatedFinder = find.ancestor(
        of: find.text('订单'),
        matching: find.byType(AnimatedContainer),
      );
      expect(
        tester.widget<AnimatedContainer>(animatedFinder).duration,
        const Duration(milliseconds: 180),
      );

      await pumpNavigation(theme: theme, disableAnimations: true);
      expect(
        tester.widget<AnimatedContainer>(animatedFinder).duration,
        Duration.zero,
      );
    }
  });

  testWidgets('状态标签按实际底色校正为 4.5:1', (tester) async {
    const tones = [
      AppPalette.successMuted,
      AppPalette.warningMuted,
      AppPalette.errorMuted,
    ];

    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      for (final tone in tones) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: theme.brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
            home: Scaffold(
              body: Builder(
                builder: (context) => ColoredBox(
                  color: AppGlassTokens.contentFillFor(context),
                  child: MutedStatusChip(
                    label: '关系状态',
                    color: tone,
                    icon: Icons.link,
                    compact: true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final foreground = tester.widget<Text>(find.text('关系状态')).style!.color!;
        final base = theme.brightness == Brightness.dark
            ? theme.colorScheme.surfaceContainerLow
            : AppPalette.raisedWhite;
        final effectiveBackground = Color.alphaBlend(
          tone.withValues(alpha: 0.13),
          base,
        );
        expect(
          _contrast(foreground, effectiveBackground),
          greaterThanOrEqualTo(4.5),
        );
      }
    }
  });

  testWidgets('AppIconButton 保持 44dp 外观并提供至少 48dp 命中区', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: AppIconButton(
              icon: Icons.refresh,
              tooltip: '刷新',
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    final finder = find.byType(IconButton);
    final widget = tester.widget<IconButton>(finder);
    expect(widget.style!.minimumSize!.resolve({}), const Size(44, 44));
    expect(widget.style!.maximumSize!.resolve({}), const Size(44, 44));
    expect(tester.getSize(finder).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(finder).height, greaterThanOrEqualTo(48));

    final semanticsNode = tester.getSemantics(finder);
    expect(semanticsNode.rect.width, greaterThanOrEqualTo(48));
    expect(semanticsNode.rect.height, greaterThanOrEqualTo(48));
    semantics.dispose();
  });
}

double _contrast(Color foreground, Color background) {
  final lighter = math.max(
    foreground.computeLuminance(),
    background.computeLuminance(),
  );
  final darker = math.min(
    foreground.computeLuminance(),
    background.computeLuminance(),
  );
  return (lighter + 0.05) / (darker + 0.05);
}

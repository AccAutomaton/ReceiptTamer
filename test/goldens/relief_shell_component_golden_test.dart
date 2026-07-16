import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_button.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_navigation_bar.dart';
import 'package:receipt_tamer/presentation/widgets/common/ledger_month_sheet.dart';
import 'package:receipt_tamer/presentation/widgets/common/liquid_glass_background.dart';

import 'harness/ledger_golden_harness.dart';

const _variants = <LedgerGoldenVariant>[
  LedgerGoldenVariant(
    id: 'android_regular',
    size: Size(412, 915),
    brightness: Brightness.light,
    textScale: 1,
  ),
  LedgerGoldenVariant(
    id: 'android_regular',
    size: Size(412, 915),
    brightness: Brightness.dark,
    textScale: 1,
  ),
  LedgerGoldenVariant(
    id: 'android_compact',
    size: Size(360, 800),
    brightness: Brightness.light,
    textScale: 1,
  ),
  LedgerGoldenVariant(
    id: 'android_compact',
    size: Size(360, 800),
    brightness: Brightness.dark,
    textScale: 1,
  ),
];

void main() {
  setUpAll(loadLedgerGoldenFonts);

  for (final variant in _variants) {
    testWidgets('relief shell ${variant.fileStem}', (tester) async {
      addTearDown(tester.resetLedgerGoldenView);
      await tester.pumpLedgerGolden(
        variant: variant,
        child: const _ReliefShellFixture(),
      );
      await tester.settleLedgerGolden();

      expect(tester.takeException(), isNull);
      expect(find.byType(AppIconButton), findsNWidgets(2));
      expect(find.byType(LedgerMonthSheet), findsOneWidget);
      expect(find.byType(LedgerEntryRow), findsNWidgets(3));
      expect(find.byKey(const ValueKey('glass_nav_island')), findsOneWidget);

      final intakeSize = tester.getSize(
        find.byKey(const ValueKey('glass_nav_intake_action')),
      );
      final expectedIntakeSize = variant.size.width <= 360 ? 68.0 : 72.0;
      expect(intakeSize, Size.square(expectedIntakeSize));

      await expectLater(
        find.byKey(ledgerGoldenBoundaryKey),
        matchesGoldenFile('baselines/relief-shell-${variant.fileStem}.png'),
      );
    });
  }
}

class _ReliefShellFixture extends StatelessWidget {
  const _ReliefShellFixture();

  static const _navigationItems = <GlassNavItem>[
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
  ];

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 360;

    return LiquidGlassBackground(
      child: Stack(
        children: [
          Positioned.fill(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                centerTitle: false,
                titleSpacing: compact ? 12 : 16,
                title: Text(
                  '订单',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                actions: [
                  AppIconButton(
                    icon: Icons.filter_list,
                    size: 48,
                    tooltip: '筛选',
                    onPressed: _noop,
                  ),
                  const SizedBox(width: 6),
                  AppIconButton(
                    icon: Icons.search,
                    size: 48,
                    tooltip: '搜索',
                    onPressed: _noop,
                  ),
                  SizedBox(width: compact ? 10 : 12),
                ],
              ),
              body: ListView(
                padding: EdgeInsets.fromLTRB(
                  compact ? 12 : 14,
                  10,
                  compact ? 12 : 14,
                  124,
                ),
                children: const [
                  LedgerMonthSheet(
                    monthLabel: '2026 年 7 月',
                    summary: '3 笔',
                    totalLabel: '合计',
                    totalAmount: '¥106.50',
                    entries: [
                      LedgerEntryRow(
                        day: '10',
                        dateCaption: '午餐',
                        title: '南风小馆',
                        subtitle: '#RT-0710',
                        amount: '¥36.00',
                        relationLabel: '已关联发票',
                        relationTone: LedgerRelationTone.linked,
                      ),
                      LedgerEntryRow(
                        day: '08',
                        dateCaption: '晚餐',
                        title: '青禾餐厅',
                        subtitle: '#RT-0708',
                        amount: '¥28.50',
                        relationLabel: '未关联发票',
                      ),
                      LedgerEntryRow(
                        day: '03',
                        dateCaption: '午餐',
                        title: '云栖食堂',
                        subtitle: '#RT-0703',
                        amount: '¥42.00',
                        relationLabel: '已关联发票',
                        relationTone: LedgerRelationTone.linked,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            left: 0,
            child: GlassNavigationBar(
              selectedIndex: 1,
              items: _navigationItems,
              onDestinationSelected: _noopIndex,
              onIntakePressed: _noop,
            ),
          ),
        ],
      ),
    );
  }

  static void _noop() {}

  static void _noopIndex(int _) {}
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_button.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_card.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_navigation_bar.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_surface.dart';
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
      expect(find.byType(AppCard), findsNWidgets(3));
      expect(
        find.byKey(const ValueKey('fixture_month_surface')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('glass_nav_island')), findsOneWidget);

      final centerSize = tester.getSize(
        find.byKey(const ValueKey('glass_nav_center_action')),
      );
      final expectedCenterSize = variant.size.width <= 360 ? 51.0 : 54.0;
      expect(centerSize, Size.square(expectedCenterSize));

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
      icon: Icons.info_outline,
      selectedIcon: Icons.info,
      label: '关于',
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
                  _MonthSurface(),
                  SizedBox(height: 9),
                  _FixtureOrderCard(
                    icon: Icons.ramen_dining_outlined,
                    shop: '南风小馆',
                    date: '2026年07月10日 · 午餐',
                    amount: '¥36.00',
                    relation: '已关联发票',
                  ),
                  SizedBox(height: 9),
                  _FixtureOrderCard(
                    icon: Icons.local_cafe_outlined,
                    shop: '青禾餐厅',
                    date: '2026年07月08日 · 晚餐',
                    amount: '¥28.50',
                    relation: '未关联发票',
                  ),
                  SizedBox(height: 9),
                  _FixtureOrderCard(
                    icon: Icons.lunch_dining_outlined,
                    shop: '云栖食堂',
                    date: '2026年07月03日 · 午餐',
                    amount: '¥42.00',
                    relation: '已关联发票',
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
              onCenterPressed: _noop,
            ),
          ),
        ],
      ),
    );
  }

  static void _noop() {}

  static void _noopIndex(int _) {}
}

class _MonthSurface extends StatelessWidget {
  const _MonthSurface();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassSurface(
      key: const ValueKey('fixture_month_surface'),
      preset: GlassSurfacePreset.panel,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      edgeIntensity: 0.72,
      child: Row(
        children: [
          Text(
            '2026年7月',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            '3 笔  ·  ¥106.50',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppPalette.textSecondaryFor(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _FixtureOrderCard extends StatelessWidget {
  const _FixtureOrderCard({
    required this.icon,
    required this.shop,
    required this.date,
    required this.amount,
    required this.relation,
  });

  final IconData icon;
  final String shop;
  final String date;
  final String amount;
  final String relation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final linked = relation == '已关联发票';

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppEntityTokens.subtleFillFor(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppEntityTokens.borderFor(context)),
            ),
            child: Icon(
              icon,
              color: AppPalette.actionPrimaryFor(context),
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shop,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 7),
                Text(
                  relation,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: linked
                        ? AppPalette.actionPrimaryFor(context)
                        : AppPalette.textSecondaryFor(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(amount, style: AppTypography.amount(context, fontSize: 19)),
        ],
      ),
    );
  }
}

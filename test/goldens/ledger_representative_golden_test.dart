import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/presentation/providers/invoice_provider.dart'
    show invoiceRepositoryProvider;
import 'package:receipt_tamer/presentation/providers/order_provider.dart'
    show orderRepositoryProvider;
import 'package:receipt_tamer/presentation/screens/home/home_screen.dart';
import 'package:receipt_tamer/presentation/widgets/common/liquid_glass_background.dart';

import 'fixtures/ledger_visual_fixtures.dart';
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
    brightness: Brightness.light,
    textScale: 1.3,
  ),
  LedgerGoldenVariant(
    id: 'android_regular',
    size: Size(412, 915),
    brightness: Brightness.light,
    textScale: 2,
  ),
  LedgerGoldenVariant(
    id: 'android_regular',
    size: Size(412, 915),
    brightness: Brightness.dark,
    textScale: 1,
  ),
  LedgerGoldenVariant(
    id: 'android_regular',
    size: Size(412, 915),
    brightness: Brightness.dark,
    textScale: 1.3,
  ),
  LedgerGoldenVariant(
    id: 'android_regular',
    size: Size(412, 915),
    brightness: Brightness.dark,
    textScale: 2,
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
    brightness: Brightness.light,
    textScale: 1.3,
  ),
  LedgerGoldenVariant(
    id: 'android_compact',
    size: Size(360, 800),
    brightness: Brightness.light,
    textScale: 2,
  ),
  LedgerGoldenVariant(
    id: 'android_compact',
    size: Size(360, 800),
    brightness: Brightness.dark,
    textScale: 1,
  ),
  LedgerGoldenVariant(
    id: 'android_compact',
    size: Size(360, 800),
    brightness: Brightness.dark,
    textScale: 1.3,
  ),
  LedgerGoldenVariant(
    id: 'android_compact',
    size: Size(360, 800),
    brightness: Brightness.dark,
    textScale: 2,
  ),
];

void main() {
  setUpAll(loadLedgerGoldenFonts);

  for (final variant in _variants) {
    testWidgets('home ${variant.fileStem}', (tester) async {
      addTearDown(tester.resetLedgerGoldenView);
      await tester.pumpLedgerGolden(
        variant: variant,
        child: ProviderScope(
          overrides: [
            orderRepositoryProvider.overrideWithValue(
              LedgerFixtureOrderRepository(),
            ),
            invoiceRepositoryProvider.overrideWithValue(
              LedgerFixtureInvoiceRepository(),
            ),
          ],
          child: LiquidGlassBackground(child: const HomeScreen()),
        ),
      );
      await tester.settleLedgerGolden();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(ledgerGoldenBoundaryKey),
        matchesGoldenFile('baselines/home-${variant.fileStem}.png'),
      );
    });
  }
}

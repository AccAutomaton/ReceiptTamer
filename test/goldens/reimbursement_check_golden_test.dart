import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/presentation/providers/reimbursement_provider.dart';
import 'package:receipt_tamer/presentation/screens/export/reimbursement_check_screen.dart';

import 'harness/ledger_golden_harness.dart';

void main() {
  setUpAll(loadLedgerGoldenFonts);

  for (final variant in LedgerGoldenVariants.representative) {
    testWidgets('reimbursement check ${variant.fileStem}', (tester) async {
      addTearDown(tester.resetLedgerGoldenView);
      await tester.pumpLedgerGolden(
        variant: variant,
        child: ProviderScope(
          overrides: [
            reimbursementProvider.overrideWith(
              () => _GoldenReimbursementNotifier(_state),
            ),
          ],
          child: const ReimbursementCheckScreen(),
        ),
      );
      await tester.settleLedgerGolden();

      expect(tester.takeException(), isNull);
      expect(find.text('检查关联'), findsOneWidget);
      expect(find.text('包含范围外关联订单'), findsOneWidget);

      await expectLater(
        find.byKey(ledgerGoldenBoundaryKey),
        matchesGoldenFile(
          'baselines/reimbursement-check-${variant.fileStem}.png',
        ),
      );
    });
  }
}

final _rangeOrders = <Order>[
  const Order(
    id: 101,
    shopName: '南风小馆',
    amount: 36,
    orderDate: '2026-07-10',
    mealTime: 'lunch',
    createdAt: '2026-07-10T12:30:00+08:00',
  ),
  const Order(
    id: 102,
    shopName: '青禾餐厅',
    amount: 28.5,
    orderDate: '2026-07-08',
    mealTime: 'dinner',
    createdAt: '2026-07-08T19:00:00+08:00',
  ),
  const Order(
    id: 103,
    shopName: '云栖食堂',
    amount: 42,
    orderDate: '2026-07-07',
    mealTime: 'lunch',
    createdAt: '2026-07-07T13:00:00+08:00',
  ),
];

const _outsideOrder = Order(
  id: 104,
  shopName: '南风小馆',
  amount: 22,
  orderDate: '2026-07-06',
  mealTime: 'dinner',
  createdAt: '2026-07-06T19:00:00+08:00',
);

final _state = ReimbursementState(
  startDate: DateTime(2026, 7, 7),
  endDate: DateTime(2026, 7, 11),
  rangeOrders: _rangeOrders,
  invoiceIds: const {201, 202},
  outOfRangeOrderIds: const {104},
  closureOrderIds: const {101, 102, 103, 104},
  closureOrders: [..._rangeOrders, _outsideOrder],
);

class _GoldenReimbursementNotifier extends ReimbursementNotifier {
  _GoldenReimbursementNotifier(this.initialState);

  final ReimbursementState initialState;

  @override
  ReimbursementState build() => initialState;
}

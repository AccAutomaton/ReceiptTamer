import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Monotonic signal for committed order, invoice, and relation mutations.
///
/// Read-only loads must never update this value. Consumers can watch it to
/// refresh derived ledger projections after a write completes.
class LedgerDataRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void markChanged() {
    state++;
  }
}

final ledgerDataRevisionProvider =
    NotifierProvider<LedgerDataRevisionNotifier, int>(
      LedgerDataRevisionNotifier.new,
    );

import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/presentation/utils/persistent_selection.dart';

void main() {
  test('filter changes preserve hidden selections and their totals', () {
    final selection = PersistentSelection<_Record>((record) => record.id);
    const firstPage = [_Record(1, 10), _Record(2, 20)];
    const filteredPage = [_Record(3, 30)];

    selection.selectVisible(firstPage);
    selection.selectVisible(filteredPage);

    expect(selection.ids, {1, 2, 3});
    expect(selection.sum((record) => record.amount), 60);

    selection.invertVisible(filteredPage);

    expect(selection.ids, {1, 2});
    expect(selection.sum((record) => record.amount), 30);
  });

  test('visible refresh updates cached selected record values', () {
    final selection = PersistentSelection<_Record>((record) => record.id);
    selection.toggle(const _Record(1, 10));

    selection.refreshVisible(const [_Record(1, 42), _Record(2, 99)]);

    expect(selection.ids, {1});
    expect(selection.sum((record) => record.amount), 42);
  });
}

class _Record {
  const _Record(this.id, this.amount);

  final int id;
  final double amount;
}

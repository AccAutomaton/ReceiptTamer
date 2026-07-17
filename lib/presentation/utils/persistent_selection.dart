/// Keeps selected records available while the visible list is replaced by a
/// search or filter result.
class PersistentSelection<T> {
  PersistentSelection(this._idOf);

  final int? Function(T item) _idOf;
  final Map<int, T> _itemsById = <int, T>{};

  Set<int> get ids => Set<int>.unmodifiable(_itemsById.keys);
  int get length => _itemsById.length;
  bool get isEmpty => _itemsById.isEmpty;
  bool get isNotEmpty => _itemsById.isNotEmpty;

  bool containsId(int? id) => id != null && _itemsById.containsKey(id);

  void toggle(T item) {
    final id = _idOf(item);
    if (id == null) return;
    if (_itemsById.containsKey(id)) {
      _itemsById.remove(id);
    } else {
      _itemsById[id] = item;
    }
  }

  /// Add every visible item without discarding selections hidden by filters.
  void selectVisible(Iterable<T> items) {
    for (final item in items) {
      final id = _idOf(item);
      if (id != null) _itemsById[id] = item;
    }
  }

  /// Toggle every visible item without changing hidden selections.
  void invertVisible(Iterable<T> items) {
    for (final item in items) {
      final id = _idOf(item);
      if (id == null) continue;
      if (_itemsById.containsKey(id)) {
        _itemsById.remove(id);
      } else {
        _itemsById[id] = item;
      }
    }
  }

  /// Refresh cached copies for selected records that are visible again.
  void refreshVisible(Iterable<T> items) {
    for (final item in items) {
      final id = _idOf(item);
      if (id != null && _itemsById.containsKey(id)) {
        _itemsById[id] = item;
      }
    }
  }

  double sum(double Function(T item) valueOf) =>
      _itemsById.values.fold<double>(0, (total, item) => total + valueOf(item));

  void clear() => _itemsById.clear();
}

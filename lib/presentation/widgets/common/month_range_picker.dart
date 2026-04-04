import 'package:flutter/material.dart';

/// Result of month range selection
class MonthRangeResult {
  final DateTime startDate;
  final DateTime endDate;

  MonthRangeResult({required this.startDate, required this.endDate});
}

/// Month range picker bottom sheet
class MonthRangePicker extends StatefulWidget {
  final DateTime? initialStartMonth;
  final DateTime? initialEndMonth;

  const MonthRangePicker({
    super.key,
    this.initialStartMonth,
    this.initialEndMonth,
  });

  /// Show month range picker as bottom sheet
  static Future<MonthRangeResult?> show(
    BuildContext context, {
    DateTime? initialStartMonth,
    DateTime? initialEndMonth,
  }) async {
    return await showModalBottomSheet<MonthRangeResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => MonthRangePicker(
        initialStartMonth: initialStartMonth,
        initialEndMonth: initialEndMonth,
      ),
    );
  }

  @override
  State<MonthRangePicker> createState() => _MonthRangePickerState();
}

class _MonthRangePickerState extends State<MonthRangePicker> {
  late int _startYear;
  late int _startMonth;
  late int _endYear;
  late int _endMonth;

  final int _minYear = 2020;
  final int _maxYear = DateTime.now().year + 1;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();

    if (widget.initialStartMonth != null) {
      _startYear = widget.initialStartMonth!.year;
      _startMonth = widget.initialStartMonth!.month;
    } else {
      _startYear = now.year;
      _startMonth = now.month;
    }

    if (widget.initialEndMonth != null) {
      _endYear = widget.initialEndMonth!.year;
      _endMonth = widget.initialEndMonth!.month;
    } else {
      _endYear = now.year;
      _endMonth = now.month;
    }
  }

  /// Check if start month is after end month
  bool get _isInvalidRange {
    if (_startYear > _endYear) return true;
    if (_startYear == _endYear && _startMonth > _endMonth) return true;
    return false;
  }

  void _confirm() {
    if (_isInvalidRange) return;

    final start = DateTime(_startYear, _startMonth, 1);
    final end = DateTime(_endYear, _endMonth + 1, 0); // Last day of end month

    Navigator.pop<MonthRangeResult>(
      context,
      MonthRangeResult(startDate: start, endDate: end),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '选择月份范围',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            _buildMonthSelector(
              title: '开始月份',
              year: _startYear,
              month: _startMonth,
              onYearChanged: (year) => setState(() => _startYear = year),
              onMonthChanged: (month) => setState(() => _startMonth = month),
            ),
            const SizedBox(height: 16),
            _buildMonthSelector(
              title: '结束月份',
              year: _endYear,
              month: _endMonth,
              onYearChanged: (year) => setState(() => _endYear = year),
              onMonthChanged: (month) => setState(() => _endMonth = month),
            ),
            if (_isInvalidRange)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '开始月份不能晚于结束月份',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isInvalidRange ? null : _confirm,
                  child: const Text('确定'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector({
    required String title,
    required int year,
    required int month,
    required ValueChanged<int> onYearChanged,
    required ValueChanged<int> onMonthChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Year dropdown
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<int>(
                initialValue: year,
                decoration: const InputDecoration(
                  labelText: '年份',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: List.generate(
                  _maxYear - _minYear + 1,
                  (index) => _minYear + index,
                )
                    .map((y) => DropdownMenuItem(
                          value: y,
                          child: Text('$y 年'),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) onYearChanged(value);
                },
              ),
            ),
            const SizedBox(width: 16),
            // Month grid
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<int>(
                initialValue: month,
                decoration: const InputDecoration(
                  labelText: '月份',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: List.generate(12, (index) => index + 1)
                    .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text('$m 月'),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) onMonthChanged(value);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
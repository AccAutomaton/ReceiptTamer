import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

/// Result of date range selection
class DateRangeResult {
  final DateTime startDate;
  final DateTime endDate;

  DateRangeResult({required this.startDate, required this.endDate});
}

/// Date range picker dialog using Syncfusion
class SyncfusionDateRangePicker extends StatefulWidget {
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  const SyncfusionDateRangePicker({
    super.key,
    this.initialStartDate,
    this.initialEndDate,
  });

  /// Show date range picker as dialog
  static Future<DateRangeResult?> show(
    BuildContext context, {
    DateTime? initialStartDate,
    DateTime? initialEndDate,
  }) async {
    return await showDialog<DateRangeResult>(
      context: context,
      builder: (context) => SyncfusionDateRangePicker(
        initialStartDate: initialStartDate,
        initialEndDate: initialEndDate,
      ),
    );
  }

  @override
  State<SyncfusionDateRangePicker> createState() => _SyncfusionDateRangePickerState();
}

class _SyncfusionDateRangePickerState extends State<SyncfusionDateRangePicker> {
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
  }

  void _onSelectionChanged(DateRangePickerSelectionChangedArgs args) {
    if (args.value is PickerDateRange) {
      final range = args.value as PickerDateRange;
      setState(() {
        _startDate = range.startDate;
        _endDate = range.endDate;
      });
    }
  }

  void _confirm() {
    if (_startDate == null || _endDate == null) return;

    Navigator.pop<DateRangeResult>(
      context,
      DateRangeResult(startDate: _startDate!, endDate: _endDate!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('选择日期范围'),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      content: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: colorScheme,
        ),
        child: Container(
          width: 320,
          height: 350,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SfDateRangePicker(
            view: DateRangePickerView.month,
            selectionMode: DateRangePickerSelectionMode.range,
            initialSelectedRange: _startDate != null && _endDate != null
                ? PickerDateRange(_startDate!, _endDate!)
                : null,
            minDate: DateTime(2020),
            maxDate: DateTime.now(),
            onSelectionChanged: _onSelectionChanged,
            backgroundColor: colorScheme.surface,
            headerStyle: DateRangePickerHeaderStyle(
              backgroundColor: colorScheme.surface,
              textStyle: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            monthViewSettings: DateRangePickerMonthViewSettings(
              firstDayOfWeek: 1, // Monday
              dayFormat: 'EEE',
              viewHeaderStyle: DateRangePickerViewHeaderStyle(
                backgroundColor: colorScheme.surface,
                textStyle: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
            selectionTextStyle: TextStyle(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w600,
            ),
            rangeTextStyle: TextStyle(
              color: colorScheme.onPrimaryContainer,
            ),
            startRangeSelectionColor: colorScheme.primary,
            endRangeSelectionColor: colorScheme.primary,
            rangeSelectionColor: colorScheme.primaryContainer.withValues(alpha: 0.5),
            todayHighlightColor: colorScheme.primary,
            monthCellStyle: DateRangePickerMonthCellStyle(
              textStyle: TextStyle(
                color: colorScheme.onSurface,
              ),
              todayTextStyle: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
              disabledDatesTextStyle: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _startDate != null && _endDate != null ? _confirm : null,
          child: const Text('确定'),
        ),
      ],
    );
  }
}
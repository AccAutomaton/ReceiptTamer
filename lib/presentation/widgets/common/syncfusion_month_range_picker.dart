import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

/// 月份范围选择结果
class MonthRangeResult {
  final DateTime startDate;  // 开始月份第一天
  final DateTime endDate;    // 结束月份最后一天

  MonthRangeResult({required this.startDate, required this.endDate});
}

/// 月份范围选择器对话框
class SyncfusionMonthRangePicker extends StatefulWidget {
  final DateTime? initialStartMonth;
  final DateTime? initialEndMonth;

  const SyncfusionMonthRangePicker({
    super.key,
    this.initialStartMonth,
    this.initialEndMonth,
  });

  /// 显示月份范围选择对话框
  static Future<MonthRangeResult?> show(
    BuildContext context, {
    DateTime? initialStartMonth,
    DateTime? initialEndMonth,
  }) async {
    return await showDialog<MonthRangeResult>(
      context: context,
      builder: (context) => SyncfusionMonthRangePicker(
        initialStartMonth: initialStartMonth,
        initialEndMonth: initialEndMonth,
      ),
    );
  }

  @override
  State<SyncfusionMonthRangePicker> createState() => _SyncfusionMonthRangePickerState();
}

class _SyncfusionMonthRangePickerState extends State<SyncfusionMonthRangePicker> {
  DateTime? _startMonth;
  DateTime? _endMonth;

  @override
  void initState() {
    super.initState();
    _startMonth = widget.initialStartMonth;
    _endMonth = widget.initialEndMonth;
  }

  /// 检查月份范围是否有效
  bool get _isValidRange {
    if (_startMonth == null || _endMonth == null) return false;
    if (_startMonth!.year > _endMonth!.year) return false;
    if (_startMonth!.year == _endMonth!.year && _startMonth!.month > _endMonth!.month) return false;
    return true;
  }

  /// 格式化月份显示
  String _formatMonth(DateTime? date) {
    if (date == null) return '未选择';
    return '${date.year}年${date.month}月';
  }

  /// 打开单月份选择对话框
  Future<void> _showMonthPicker(bool isStart) async {
    final result = await showDialog<DateTime>(
      context: context,
      builder: (context) => _MonthPickerDialog(
        initialMonth: isStart ? _startMonth : _endMonth,
      ),
    );

    if (result != null) {
      setState(() {
        if (isStart) {
          _startMonth = result;
        } else {
          _endMonth = result;
        }
      });
    }
  }

  /// 确认选择
  void _confirm() {
    if (!_isValidRange) return;

    // 开始月份为第一天
    final start = DateTime(_startMonth!.year, _startMonth!.month, 1);
    // 结束月份为最后一天
    final end = DateTime(_endMonth!.year, _endMonth!.month + 1, 0);

    Navigator.pop<MonthRangeResult>(
      context,
      MonthRangeResult(startDate: start, endDate: end),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('选择月份范围'),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 开始月份选择区域
          _buildMonthSelector(
            title: '开始月份',
            month: _startMonth,
            onTap: () => _showMonthPicker(true),
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 16),
          // 结束月份选择区域
          _buildMonthSelector(
            title: '结束月份',
            month: _endMonth,
            onTap: () => _showMonthPicker(false),
            colorScheme: colorScheme,
          ),
          // 错误提示
          if (_startMonth != null && _endMonth != null && !_isValidRange)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '开始月份不能晚于结束月份',
                style: TextStyle(
                  color: colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _isValidRange ? _confirm : null,
          child: const Text('确定'),
        ),
      ],
    );
  }

  Widget _buildMonthSelector({
    required String title,
    required DateTime? month,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: month != null
                    ? colorScheme.primary
                    : colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatMonth(month),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: month != null ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                  ),
                ),
                Icon(
                  Icons.calendar_month,
                  color: colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 单月份选择对话框（年份视图）
class _MonthPickerDialog extends StatefulWidget {
  final DateTime? initialMonth;

  const _MonthPickerDialog({this.initialMonth});

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('选择月份'),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      content: Theme(
        data: Theme.of(context).copyWith(colorScheme: colorScheme),
        child: Container(
          width: 320,
          height: 350,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SfDateRangePicker(
            view: DateRangePickerView.year,
            selectionMode: DateRangePickerSelectionMode.single,
            initialSelectedDate: widget.initialMonth ?? DateTime.now(),
            minDate: DateTime(2020),
            maxDate: DateTime.now().add(const Duration(days: 365)),
            onSelectionChanged: (args) {
              if (args.value is DateTime) {
                final selected = args.value as DateTime;
                // 返回月份第一天
                Navigator.pop(context, DateTime(selected.year, selected.month, 1));
              }
            },
            backgroundColor: colorScheme.surface,
            headerStyle: DateRangePickerHeaderStyle(
              backgroundColor: colorScheme.surface,
              textStyle: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            yearCellStyle: DateRangePickerYearCellStyle(
              textStyle: TextStyle(color: colorScheme.onSurface),
              todayTextStyle: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
              disabledDatesTextStyle: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
            selectionTextStyle: TextStyle(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w600,
            ),
            selectionColor: colorScheme.primary,
            todayHighlightColor: colorScheme.primary,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../data/services/duplicate_detection_service.dart';
import 'glass_alert_dialog.dart';

Future<bool> showDuplicateWarningDialog(
  BuildContext context, {
  required DuplicateCheckReport report,
  required ValueChanged<DuplicateRecordSnapshot> onOpenRecord,
}) async {
  final shouldSave = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      void openRecord(DuplicateRecordSnapshot record) {
        Navigator.pop(dialogContext, false);
        onOpenRecord(record);
      }

      return GlassAlertDialog(
        title: Text(report.hasStrongWarning ? '发现相同附件' : '发现可能重复的记录'),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.58,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CandidateSummary(record: report.candidate),
                if (report.identicalAttachments.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _DuplicateRuleSection(
                    title: '附件内容完全相同',
                    description: '文件哈希一致，强烈建议先查看已有记录，避免重复导入。',
                    matches: report.identicalAttachments,
                    isStrong: true,
                    onOpenRecord: openRecord,
                  ),
                ],
                if (report.sameReferences.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _DuplicateRuleSection(
                    title: '${report.candidate.typeLabel}编号相同',
                    description: '请对比本次内容与已有记录后再决定是否保存。',
                    matches: report.sameReferences,
                    onOpenRecord: openRecord,
                  ),
                ],
                if (report.suspectedFields.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _DuplicateRuleSection(
                    title: '疑似重复',
                    description: '商家、日期和金额相同；这可能是不同记录，仅作提醒。',
                    matches: report.suspectedFields,
                    onOpenRecord: openRecord,
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('仍然保存'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('返回核对'),
          ),
        ],
      );
    },
  );

  return shouldSave == true;
}

class _CandidateSummary extends StatelessWidget {
  const _CandidateSummary({required this.record});

  final DuplicateRecordSnapshot record;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '本次${record.typeLabel}',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(_recordDescription(record)),
        ],
      ),
    );
  }
}

class _DuplicateRuleSection extends StatelessWidget {
  const _DuplicateRuleSection({
    required this.title,
    required this.description,
    required this.matches,
    required this.onOpenRecord,
    this.isStrong = false,
  });

  final String title;
  final String description;
  final List<DuplicateMatch> matches;
  final ValueChanged<DuplicateRecordSnapshot> onOpenRecord;
  final bool isStrong;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = isStrong ? colorScheme.error : colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isStrong ? Icons.warning_amber_rounded : Icons.compare_arrows,
              size: 18,
              color: accent,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          description,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        for (final match in matches)
          _ExistingRecordTile(
            record: match.record,
            onOpen: match.record.id == null
                ? null
                : () => onOpenRecord(match.record),
          ),
      ],
    );
  }
}

class _ExistingRecordTile extends StatelessWidget {
  const _ExistingRecordTile({required this.record, required this.onOpen});

  final DuplicateRecordSnapshot record;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final description = _recordDescription(record);

    return Semantics(
      button: onOpen != null,
      label: '已有${record.typeLabel}，$description',
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text('已有${record.typeLabel} #${record.id ?? '-'}'),
        subtitle: Text(description),
        trailing: onOpen == null
            ? null
            : IconButton(
                onPressed: onOpen,
                tooltip: '查看已有${record.typeLabel}',
                icon: const Icon(Icons.open_in_new),
              ),
      ),
    );
  }
}

String _recordDescription(DuplicateRecordSnapshot record) {
  final fields = <String>[
    if (record.merchant.isNotEmpty) record.merchant,
    if (record.referenceNumber.isNotEmpty) '编号 ${record.referenceNumber}',
    if (record.date != null && record.date!.trim().isNotEmpty)
      _displayDate(record.date!),
    DateFormatter.formatAmount(record.amount),
  ];
  return fields.join(' · ');
}

String _displayDate(String value) {
  final date = DateTime.tryParse(value);
  return date == null ? value : DateFormatter.formatDisplay(date);
}

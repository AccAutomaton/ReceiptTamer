import 'package:flutter/material.dart';

import '../widgets/common/glass_alert_dialog.dart';

/// Requires an explicit second decision before discarding a pending share
/// import queue.
Future<bool> confirmAbandonSharedImport(
  BuildContext context, {
  required int pendingCount,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => GlassAlertDialog(
      title: const Text('放弃全部待处理文件？'),
      content: Text('将移除剩余 $pendingCount 个待处理文件。已保存的订单或发票不会受到影响。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('继续保留'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('放弃全部'),
        ),
      ],
    ),
  );

  return confirmed == true;
}

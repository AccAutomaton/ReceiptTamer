import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_design_tokens.dart';
import '../../../core/utils/date_formatter.dart';
import '../../providers/reimbursement_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/glass_page_scaffold.dart';
import '../../widgets/common/scroll_edge_fog.dart';

/// 完整报销的关联检查步骤。
class ReimbursementCheckScreen extends ConsumerWidget {
  const ReimbursementCheckScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reimbursementProvider);
    final notifier = ref.read(reimbursementProvider.notifier);

    return GlassPageScaffold(
      appBar: AppBar(
        title: const Text('检查关联'),
        actions: [
          if (state.hasRange)
            IconButton(
              onPressed: state.isLoading ? null : notifier.refresh,
              tooltip: '重新检查',
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: ScrollEdgeFog(
              showTop: true,
              showBottom: true,
              bottomInset: 88,
              child: _CheckContent(state: state, notifier: notifier),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            left: 12,
            child: SafeArea(
              top: false,
              child: AppCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(8),
                child: AppButton(
                  key: const ValueKey('continue_reimbursement_build'),
                  text: _buttonLabel(state),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  isFullWidth: true,
                  isLoading: state.isLoading,
                  onPressed: state.canContinue
                      ? () => context.push('/export/options')
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _buttonLabel(ReimbursementState state) {
    if (state.isLoading) return '正在检查';
    if (!state.hasRange) return '未选择日期范围';
    if (state.rangeOrders.isEmpty) return '范围内没有订单';
    if (state.unlinkedOrders.isNotEmpty) {
      return '${state.unlinkedOrders.length} 笔订单未关联';
    }
    if (state.outOfRangeOrderIds.isNotEmpty && !state.closureAccepted) {
      return '确认范围外订单';
    }
    return '下一步';
  }
}

class _CheckContent extends StatelessWidget {
  const _CheckContent({required this.state, required this.notifier});

  final ReimbursementState state;
  final ReimbursementNotifier notifier;

  @override
  Widget build(BuildContext context) {
    if (!state.hasRange) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.date_range_outlined, size: 52),
              const SizedBox(height: 14),
              Text('未选择日期范围', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              AppButton(text: '返回选择范围', onPressed: () => context.go('/export')),
            ],
          ),
        ),
      );
    }

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final rangeAmount = state.rangeOrders.fold<double>(
      0,
      (total, order) => total + order.amount,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 116),
      children: [
        AppCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '日期范围',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${DateFormatter.formatInput(state.startDate!)} — ${DateFormatter.formatInput(state.endDate!)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${state.rangeOrders.length} 笔订单 · ${state.invoiceIds.length} 张发票',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                DateFormatter.formatAmount(rangeAmount),
                style: AppTypography.amount(context, fontSize: 21),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '检查结果',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 9),
        if (state.errorMessage != null)
          _IssuePaper(
            icon: Icons.error_outline,
            title: '加载失败',
            tone: theme.colorScheme.error,
          )
        else if (state.rangeOrders.isEmpty)
          const _IssuePaper(
            icon: Icons.inbox_outlined,
            title: '范围内没有订单',
            detail: '请重新选择日期范围。',
          )
        else ...[
          _IssuePaper(
            icon: state.unlinkedOrders.isEmpty
                ? Icons.check_circle_outline
                : Icons.link_off,
            title: state.unlinkedOrders.isEmpty
                ? '订单均已关联'
                : '${state.unlinkedOrders.length} 笔订单未关联发票',
            detail: state.unlinkedOrders.isEmpty
                ? '可继续检查范围外订单。'
                : '请先关联发票。用餐证明可单独导出。',
            tone: state.unlinkedOrders.isEmpty
                ? theme.colorScheme.primary
                : theme.colorScheme.error,
          ),
          if (state.unlinkedOrders.isNotEmpty) ...[
            const SizedBox(height: 8),
            AppCard(
              margin: EdgeInsets.zero,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (
                    var index = 0;
                    index < state.unlinkedOrders.take(5).length;
                    index++
                  ) ...[
                    ListTile(
                      title: Text(
                        state.unlinkedOrders[index].shopName.isEmpty
                            ? '未知商家'
                            : state.unlinkedOrders[index].shopName,
                      ),
                      subtitle: Text(
                        state.unlinkedOrders[index].orderDate ?? '未填写日期',
                      ),
                      trailing: Text(
                        DateFormatter.formatAmount(
                          state.unlinkedOrders[index].amount,
                        ),
                      ),
                      onTap: state.unlinkedOrders[index].id == null
                          ? null
                          : () => context.push(
                              '/orders/${state.unlinkedOrders[index].id}',
                            ),
                    ),
                    if (index != state.unlinkedOrders.take(5).length - 1)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: AppButton(
                      text: '开票助手',
                      type: AppButtonType.secondary,
                      isFullWidth: true,
                      onPressed: () => context.push('/invoice-assistant'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (state.outOfRangeOrderIds.isEmpty)
            _IssuePaper(
              icon: Icons.done_all,
              title: '无范围外订单',
              detail: '无需追加订单。',
              tone: theme.colorScheme.primary,
            )
          else
            AppCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '范围外关联订单 ${state.outOfRangeOrderIds.length} 笔',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '为保持发票关联完整，导出时将一并包含。日期范围不变。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: state.closureAccepted,
                    onChanged: (value) =>
                        notifier.setClosureAccepted(value ?? false),
                    title: const Text('包含范围外关联订单'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
        ],
        if (_footerHint != null) ...[
          const SizedBox(height: 14),
          Text(
            _footerHint!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }

  String? get _footerHint {
    if (state.errorMessage != null || state.rangeOrders.isEmpty) return null;
    if (state.unlinkedOrders.isNotEmpty) {
      return '关联发票后，请重新检查。';
    }
    if (state.outOfRangeOrderIds.isNotEmpty && !state.closureAccepted) {
      return '请确认是否包含范围外订单。';
    }
    if (state.canContinue) {
      return '默认导出用餐证明、发票和用餐明细。';
    }
    return null;
  }
}

class _IssuePaper extends StatelessWidget {
  const _IssuePaper({
    required this.icon,
    required this.title,
    this.detail,
    this.tone,
  });

  final IconData icon;
  final String title;
  final String? detail;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedTone = tone ?? theme.colorScheme.onSurfaceVariant;
    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: resolvedTone),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (detail != null && detail!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    detail!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

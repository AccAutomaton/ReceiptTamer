import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_design_tokens.dart';
import '../../../core/utils/date_formatter.dart';
import '../../providers/home_overview_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/glass_navigation_bar.dart';
import '../../widgets/common/scroll_edge_fog.dart';

/// The app's filing desk: a task directory followed by recent orders.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _regularBottomClearance = 120.0;
  static const _compactBottomClearance = 112.0;

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(homeOverviewProvider);
    await ref.read(homeOverviewProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(homeOverviewProvider);
    final textScale = AppTypography.accessibilityScaleOf(context);
    final toolbarHeight = (72 + (textScale - 1).clamp(0, 1) * 24).toDouble();

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        toolbarHeight: toolbarHeight,
        centerTitle: false,
        titleSpacing: 16,
        title: const _HomeTitle(),
        actions: [
          AppIconButton(
            key: const ValueKey('home-settings-action'),
            icon: Icons.settings_outlined,
            tooltip: '设置',
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ScrollEdgeFog(
        topHeight: textScale >= 1.7 ? 42 : 34,
        bottomHeight: textScale >= 1.7 ? 68 : 58,
        bottomInset: GlassNavigationBar.contentFadeInset(context),
        child: overview.when(
          skipLoadingOnRefresh: true,
          data: (data) =>
              _HomeScroll(overview: data, onRefresh: () => _refresh(ref)),
          loading: () => const _HomeLoading(),
          error: (error, stackTrace) =>
              _HomeError(onRetry: () => ref.invalidate(homeOverviewProvider)),
        ),
      ),
    );
  }
}

class _HomeTitle extends StatelessWidget {
  const _HomeTitle();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTypography.preserveOriginalSize(
          child: Text(
            '首页',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: AppPalette.textPrimaryFor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeScroll extends StatelessWidget {
  const _HomeScroll({required this.overview, required this.onRefresh});

  final HomeOverview overview;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 380;
    final bottomClearance = compact
        ? HomeScreen._compactBottomClearance
        : HomeScreen._regularBottomClearance;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        key: const ValueKey('home-scroll-view'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              compact ? 12 : 16,
              14,
              compact ? 12 : 16,
              bottomClearance + MediaQuery.paddingOf(context).bottom,
            ),
            sliver: SliverList.list(
              children: [
                if (overview.orderCount == 0 && overview.invoiceCount == 0) ...[
                  const _FirstUseChecklist(),
                  const SizedBox(height: 14),
                ],
                _FilingDirectory(overview: overview),
                const SizedBox(height: 14),
                _RecentOrders(items: overview.recentOrders),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FirstUseChecklist extends StatelessWidget {
  const _FirstUseChecklist();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final divider = AppEntityTokens.borderFor(context);
    final fill = AppEntityTokens.fillFor(context);

    return _PaperSurface(
      key: const ValueKey('home-first-use-checklist'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                theme.colorScheme.primary.withValues(alpha: 0.07),
                fill,
              ),
              border: Border(bottom: BorderSide(color: divider)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '第一次使用，从这三步开始',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '识别功能是可选项，手工录入也能完成全部流程。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _FirstUseStep(
            index: 1,
            title: '导入一笔订单',
            description: '选择订单截图，识别后核对或直接手工填写',
            onTap: () => context.push('/orders/new'),
          ),
          Divider(height: 1, color: divider),
          _FirstUseStep(
            index: 2,
            title: '选择识别方式',
            description: '比较手工、本地和云端的速度、隐私与成本',
            onTap: () => context.push('/settings/model-management'),
          ),
          Divider(height: 1, color: divider),
          _FirstUseStep(
            index: 3,
            title: '关联发票并导出',
            description: '把订单关联到发票，再生成报销材料',
            onTap: () => context.push('/invoice-assistant'),
          ),
        ],
      ),
    );
  }
}

class _FirstUseStep extends StatelessWidget {
  const _FirstUseStep({
    required this.index,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final int index;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: '第 $index 步，$title，$description',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$index',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: theme.colorScheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilingDirectory extends StatelessWidget {
  const _FilingDirectory({required this.overview});

  final HomeOverview overview;

  @override
  Widget build(BuildContext context) {
    final border = AppEntityTokens.strongBorderFor(context);
    final divider = AppEntityTokens.borderFor(context);
    final fill = AppEntityTokens.fillFor(context);

    return _PaperSurface(
      key: const ValueKey('home-directory-card'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 28,
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                fill,
              ),
              border: Border(bottom: BorderSide(color: divider)),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  _BindingHole(),
                  SizedBox(width: 38),
                  _BindingHole(),
                  SizedBox(width: 38),
                  _BindingHole(),
                ],
              ),
            ),
          ),
          IntrinsicHeight(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: _DirectoryStat(
                      key: const ValueKey('home-order-stat-column'),
                      value: overview.orderCount,
                      label: '订单总数',
                    ),
                  ),
                  VerticalDivider(width: 1, thickness: 1, color: divider),
                  Expanded(
                    child: _DirectoryStat(
                      key: const ValueKey('home-invoice-stat-column'),
                      value: overview.invoiceCount,
                      label: '发票总数',
                    ),
                  ),
                  VerticalDivider(width: 1, thickness: 1, color: divider),
                  Expanded(
                    child: _DirectoryStat(
                      key: const ValueKey('home-uninvoiced-stat-column'),
                      value: overview.uninvoicedOrderCount,
                      label: '未关联订单',
                      emphasized: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, color: divider),
          _DirectoryTask(
            key: const ValueKey('home-invoice-assistant-action'),
            shopCount: overview.uninvoicedShopCount,
            orderCount: overview.uninvoicedOrderCount,
            onTap: () => context.push('/invoice-assistant'),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
                fill,
              ),
              border: Border(top: BorderSide(color: divider)),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _DirectoryTool(
                      key: const ValueKey('home-meal-proof-action'),
                      icon: Icons.restaurant_menu,
                      title: '用餐证明导出',
                      description: '选择订单生成 PDF',
                      onTap: () => context.push('/export/meal-proof'),
                    ),
                  ),
                  VerticalDivider(width: 1, thickness: 1, color: border),
                  Expanded(
                    child: _DirectoryTool(
                      key: const ValueKey('home-invoice-export-action'),
                      icon: Icons.description_outlined,
                      title: '发票导出',
                      description: '选择发票生成 PDF',
                      onTap: () => context.push('/export/invoice'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BindingHole extends StatelessWidget {
  const _BindingHole();

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppEntityTokens.fillFor(context),
        border: Border.all(color: accent, width: 1.4),
      ),
    );
  }
}

class _DirectoryStat extends StatelessWidget {
  const _DirectoryStat({
    super.key,
    required this.value,
    required this.label,
    this.emphasized = false,
  });

  final int value;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = emphasized
        ? theme.colorScheme.primary
        : AppPalette.textPrimaryFor(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectoryTask extends StatelessWidget {
  const _DirectoryTask({
    super.key,
    required this.shopCount,
    required this.orderCount,
    required this.onTap,
  });

  final int shopCount;
  final int orderCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final divider = AppEntityTokens.borderFor(context);
    final fill = AppEntityTokens.fillFor(context);

    return Semantics(
      button: true,
      label: '待关联订单，$shopCount 家店铺，$orderCount 笔订单',
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color.alphaBlend(accent.withValues(alpha: 0.025), fill),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 104),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Center(
                      key: const ValueKey('home-assistant-icon-column'),
                      child: Container(
                        key: const ValueKey('home-assistant-icon-seal'),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Color.alphaBlend(
                            accent.withValues(alpha: 0.11),
                            fill,
                          ),
                          borderRadius: BorderRadius.circular(AppRadii.control),
                        ),
                        child: Icon(
                          Icons.receipt_long_outlined,
                          size: 25,
                          color: accent,
                        ),
                      ),
                    ),
                  ),
                  _AssistantPerforation(color: divider),
                  Expanded(
                    child: Padding(
                      key: const ValueKey('home-assistant-copy-column'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 13,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '待关联订单',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppPalette.textPrimaryFor(context),
                            ),
                          ),
                          const SizedBox(height: 5),
                          _AssistantMetric(value: shopCount, label: '家店铺'),
                          const SizedBox(height: 1),
                          _AssistantMetric(value: orderCount, label: '笔订单'),
                        ],
                      ),
                    ),
                  ),
                  _AssistantPerforation(color: divider),
                  Expanded(
                    child: Center(
                      key: const ValueKey('home-assistant-action-column'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 11,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '查看未关联订单',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              key: const ValueKey('home-assistant-action-mark'),
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Color.alphaBlend(
                                  accent.withValues(alpha: 0.10),
                                  fill,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantMetric extends StatelessWidget {
  const _AssistantMetric({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text.rich(
      TextSpan(
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        children: [
          TextSpan(
            text: '$value',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
          TextSpan(text: ' $label'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _AssistantPerforation extends StatelessWidget {
  const _AssistantPerforation({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1,
      child: Center(
        child: SizedBox(
          height: 30,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              4,
              (index) => Container(width: 1, height: 4, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

class _DirectoryTool extends StatelessWidget {
  const _DirectoryTool({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textScale = AppTypography.accessibilityScaleOf(context);
    final compact = MediaQuery.sizeOf(context).width < 380;
    final horizontalPadding = compact ? 12.0 : 16.0;

    return Semantics(
      button: true,
      label: '$title，$description',
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 76),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 10,
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppPalette.textPrimaryFor(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (textScale < 1.7) ...[
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward,
                  size: 15,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentOrders extends StatelessWidget {
  const _RecentOrders({required this.items});

  final List<RecentOrderItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final divider = AppEntityTokens.borderFor(context);
    final fill = AppEntityTokens.fillFor(context);

    return _PaperSurface(
      key: const ValueKey('home-recent-orders-sheet'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 54),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                theme.colorScheme.secondary.withValues(alpha: 0.06),
                fill,
              ),
              border: Border(bottom: BorderSide(color: divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '最近订单',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  key: const ValueKey('home-recent-orders-more'),
                  onPressed: () => context.go('/orders'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    '查看更多',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (items.isEmpty)
            const _EmptyOrders()
          else
            for (var index = 0; index < items.length; index++) ...[
              if (index > 0) Divider(height: 1, thickness: 1, color: divider),
              _RecentOrderRow(item: items[index]),
            ],
        ],
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 150),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 34,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 10),
              Text('暂无订单', style: theme.textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentOrderRow extends StatelessWidget {
  const _RecentOrderRow({required this.item});

  final RecentOrderItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textScale = AppTypography.accessibilityScaleOf(context);
    final stacked = textScale >= 1.7;
    final route = '/orders/${item.id}';

    final mainCopy = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.title,
          maxLines: stacked ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelLarge?.copyWith(
            color: AppPalette.textPrimaryFor(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          _metadata(item),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    final endCopy = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          DateFormatter.formatAmount(item.amount),
          maxLines: 1,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
            fontFeatures: AppTypography.tabularFigures,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          _relationLabel(item),
          maxLines: 1,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    return Semantics(
      button: item.id != null,
      label: '订单，${item.title}，${_relationLabel(item)}',
      child: InkWell(
        key: ValueKey('recent-order-${item.id ?? 'unknown'}'),
        onTap: item.id == null ? null : () => context.push(route),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: stacked ? 96 : 64),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ArchiveDate(date: item.collectedAt),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    child: stacked
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              mainCopy,
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: endCopy,
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: mainCopy),
                              const SizedBox(width: 8),
                              endCopy,
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _metadata(RecentOrderItem item) {
    final parts = <String>['订单'];
    final mealTime = DateFormatter.mealTimeToDisplayName(
      DateFormatter.mealTimeFromString(item.mealTime),
    );
    if (mealTime != '-') parts.add(mealTime);
    if (item.referenceNumber.isNotEmpty) {
      final tailLength = item.referenceNumber.length.clamp(0, 5);
      parts.add(
        '#${item.referenceNumber.substring(item.referenceNumber.length - tailLength)}',
      );
    }
    return parts.join(' · ');
  }

  static String _relationLabel(RecentOrderItem item) {
    if (!item.hasInvoice) {
      return '未关联发票';
    }
    return '已关联发票';
  }
}

class _ArchiveDate extends StatelessWidget {
  const _ArchiveDate({required this.date});

  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 52,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: AppEntityTokens.borderFor(context)),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            date?.day.toString().padLeft(2, '0') ?? '--',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            date == null ? '未知' : '${date!.month}月',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaperSurface extends StatelessWidget {
  const _PaperSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(AppRadii.large));

    return Material(
      color: AppEntityTokens.fillFor(context),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: AppEntityTokens.strongBorderFor(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _HomeLoading extends StatelessWidget {
  const _HomeLoading();

  @override
  Widget build(BuildContext context) {
    return const CustomScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 38,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text('加载失败', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重试'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

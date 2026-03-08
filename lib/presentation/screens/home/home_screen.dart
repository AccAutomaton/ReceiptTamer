import 'package:catering_receipt_recorder/core/constants/app_constants.dart';
import 'package:catering_receipt_recorder/core/utils/date_formatter.dart';
import 'package:catering_receipt_recorder/presentation/providers/order_provider.dart';
import 'package:catering_receipt_recorder/presentation/providers/invoice_provider.dart';
import 'package:catering_receipt_recorder/presentation/providers/ocr_provider.dart';
import 'package:catering_receipt_recorder/presentation/widgets/common/app_button.dart';
import 'package:catering_receipt_recorder/presentation/widgets/common/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Home screen - main dashboard with statistics overview
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Preload OCR provider to start model initialization at app startup
    ref.watch(ocrProvider);

    final orderCountAsync = ref.watch(orderCountProvider);
    final invoiceCountAsync = ref.watch(invoiceCountProvider);
    final totalOrderAmountAsync = ref.watch(totalOrderAmountProvider);
    final totalInvoiceAmountAsync = ref.watch(totalInvoiceAmountProvider);
    final todayOrderCountAsync = ref.watch(todayOrderCountProvider);

    final orderState = ref.watch(orderProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            backgroundColor: colorScheme.primaryContainer,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                AppConstants.titleHome,
                style: TextStyle(color: Colors.black),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primaryContainer,
                      colorScheme.secondaryContainer,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Statistics cards
                  _buildStatisticsCards(
                    context,
                    orderCountAsync,
                    invoiceCountAsync,
                    totalOrderAmountAsync,
                    totalInvoiceAmountAsync,
                    todayOrderCountAsync,
                  ),

                  const SizedBox(height: 24),

                  // Quick access
                  Text(
                    '快捷功能',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildQuickAccessGrid(context, colorScheme),

                  const SizedBox(height: 24),

                  // Recent orders
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '最近订单',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/orders'),
                        child: const Text('查看全部'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildRecentOrders(context, orderState),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCards(
    BuildContext context,
    AsyncValue<int> orderCount,
    AsyncValue<int> invoiceCount,
    AsyncValue<double> totalOrderAmount,
    AsyncValue<double> totalInvoiceAmount,
    AsyncValue<int> todayOrderCount,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: '订单总数',
                value: orderCount.value?.toString() ?? '-',
                icon: Icons.receipt_long,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: '发票总数',
                value: invoiceCount.value?.toString() ?? '-',
                icon: Icons.description,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: '订单总金额',
                value: totalOrderAmount.value != null
                    ? DateFormatter.formatAmount(totalOrderAmount.value!)
                    : '-',
                icon: Icons.account_balance_wallet,
                color: Theme.of(context).colorScheme.tertiary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: '今日订单',
                value: todayOrderCount.value?.toString() ?? '-',
                icon: Icons.today,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAccessGrid(BuildContext context, ColorScheme colorScheme) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.5,
      children: [
        _QuickAccessButton(
          icon: Icons.file_download_outlined,
          label: '数据导出',
          color: colorScheme.primary,
          onTap: () => context.push('/export'),
        ),
        _QuickAccessButton(
          icon: Icons.search,
          label: '搜索订单',
          color: colorScheme.secondary,
          onTap: () => context.push('/orders'),
        ),
      ],
    );
  }

  Widget _buildRecentOrders(BuildContext context, dynamic orderState) {
    final orders = orderState.orders;
    final isLoading = orderState.isLoading;

    if (isLoading && orders.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (orders.isEmpty) {
      return AppCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 48,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.3),
              ),
              const SizedBox(height: 8),
              Text(
                '暂无订单',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              AppButton(
                text: '添加订单',
                onPressed: () => context.push('/orders/new'),
                type: AppButtonType.primary,
              ),
            ],
          ),
        ),
      );
    }

    final recentOrders = orders.take(3).toList();

    return Column(
      children: recentOrders.map((order) {
        final orderDate = order.orderDate != null && order.orderDate!.isNotEmpty
            ? DateTime.tryParse(order.orderDate!)
            : null;

        return AppCard(
          onTap: () {
            if (order.id != null && order.id! > 0) {
              context.push('/orders/${order.id}');
            }
          },
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.receipt_long,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      order.shopName.isEmpty ? '未命名店铺' : order.shopName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (orderDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          DateFormatter.formatDisplay(orderDate),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                DateFormatter.formatAmount(order.amount),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        );
      }).cast<Widget>().toList(),
    );
  }
}

/// Stat card widget
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick access button widget
class _QuickAccessButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAccessButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:receipt_tamer/core/constants/app_constants.dart';
import 'package:receipt_tamer/core/services/log_service.dart';
import 'package:receipt_tamer/core/services/log_config.dart';
import 'package:receipt_tamer/core/utils/date_formatter.dart';
import 'package:receipt_tamer/presentation/providers/order_provider.dart';
import 'package:receipt_tamer/presentation/providers/invoice_provider.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_button.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_card.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Home screen - main dashboard with statistics overview
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final EasyRefreshController _refreshController = EasyRefreshController(
    controlFinishRefresh: true,
  );

  bool _initialized = false;
  bool _dataLoaded = false;

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  /// 刷新所有数据
  Future<void> _refreshData() async {
    await Future.wait([
      ref.refresh(orderCountProvider.future),
      ref.refresh(invoiceCountProvider.future),
    ]);
    await ref.read(orderProvider.notifier).loadOrders();
    if (mounted) {
      setState(() {
        _dataLoaded = true;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 确保数据只加载一次
    if (!_initialized) {
      _initialized = true;
      // 首帧后加载数据，确保 UI 已经构建完成
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshData();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 数据未加载完成时显示加载界面
    if (!_dataLoaded) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(AppConstants.titleHome),
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final orderCountAsync = ref.watch(orderCountProvider);
    final invoiceCountAsync = ref.watch(invoiceCountProvider);
    final orderState = ref.watch(orderProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.titleHome),
        elevation: 0,
      ),
      body: EasyRefresh(
        controller: _refreshController,
        onRefresh: () async {
          try {
            await _refreshData();
            _refreshController.finishRefresh(IndicatorResult.success);
          } catch (e, stackTrace) {
            _refreshController.finishRefresh(IndicatorResult.fail);
            logService.e(LogConfig.moduleUi, '刷新数据失败', e, stackTrace);
          }
        },
        header: ClassicHeader(
          dragText: '下拉刷新',
          armedText: '松手刷新',
          readyText: '正在刷新...',
          processingText: '正在刷新...',
          processedText: '刷新完成',
          noMoreText: '',
          showMessage: false,
          iconDimension: 20,
          iconTheme: IconThemeData(color: colorScheme.primary),
          textStyle: TextStyle(
            color: colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Statistics cards
              Text(
                '数据概览',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildStatisticsCards(context, orderCountAsync, invoiceCountAsync),

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
    );
  }

  Widget _buildStatisticsCards(
    BuildContext context,
    AsyncValue<int> orderCount,
    AsyncValue<int> invoiceCount,
  ) {
    return Row(
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
    );
  }

  Widget _buildQuickAccessGrid(BuildContext context, ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: _QuickAccessButton(
            icon: Icons.file_download_outlined,
            label: '报销材料导出',
            color: colorScheme.primary,
            onTap: () => context.push('/export'),
          ),
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
      return SizedBox(
        width: double.infinity,
        child: AppCard(
          margin: EdgeInsets.zero,
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
        ),
      );
    }

    final recentOrders = orders.take(5).toList();

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
      margin: EdgeInsets.zero,
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
    return AppCard(
      margin: EdgeInsets.zero,
      onTap: onTap,
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
    );
  }
}
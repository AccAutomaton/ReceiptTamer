import 'package:receipt_tamer/core/constants/app_constants.dart';
import 'package:receipt_tamer/core/services/log_service.dart';
import 'package:receipt_tamer/core/services/log_config.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/core/utils/date_formatter.dart';
import 'package:receipt_tamer/presentation/providers/order_provider.dart';
import 'package:receipt_tamer/presentation/providers/invoice_provider.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_button.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_card.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_surface.dart';
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
        backgroundColor: Colors.transparent,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final orderCountAsync = ref.watch(orderCountProvider);
    final invoiceCountAsync = ref.watch(invoiceCountProvider);
    final orderState = ref.watch(orderProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
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
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 112),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SafeArea(bottom: false, child: _buildPageHeader(context)),
              const SizedBox(height: 18),
              _buildHeroSummary(
                context,
                orderCountAsync,
                invoiceCountAsync,
                orderState,
              ),

              const SizedBox(height: 18),
              _buildStatisticsCards(
                context,
                orderCountAsync,
                invoiceCountAsync,
              ),

              const SizedBox(height: 22),

              Text(
                '快捷功能',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppPalette.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _buildQuickAccessGrid(context),

              const SizedBox(height: 22),

              // Recent orders
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '最近订单',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppPalette.textPrimary,
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

  Widget _buildPageHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            AppConstants.titleHome,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: AppPalette.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        AppIconButton(
          icon: Icons.search,
          tooltip: '搜索订单',
          onPressed: () => context.push('/orders'),
        ),
      ],
    );
  }

  Widget _buildHeroSummary(
    BuildContext context,
    AsyncValue<int> orderCount,
    AsyncValue<int> invoiceCount,
    dynamic orderState,
  ) {
    final theme = Theme.of(context);
    final orders = orderState.orders as List<dynamic>;
    final linkedCount = orders
        .where((order) => order.hasInvoice == true)
        .length;
    final totalAmount = orders.fold<double>(
      0,
      (sum, order) => sum + (order.amount as double),
    );
    final totalOrders = orderCount.value ?? orders.length;
    final linkedRatio = totalOrders == 0 ? 0.0 : linkedCount / totalOrders;

    return GlassSurface(
      padding: const EdgeInsets.all(18),
      fillColor: AppGlassTokens.sheetFill,
      boxShadow: AppShadows.glass,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppPalette.selectedFill,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: AppPalette.amountMuted,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '报销材料概览',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppPalette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${invoiceCount.value ?? 0} 张发票 · $linkedCount 条已关联订单',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppPalette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                DateFormatter.formatAmount(totalAmount),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: AppPalette.amountMuted,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.chip),
            child: LinearProgressIndicator(
              value: linkedRatio.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppPalette.mistBlue,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppPalette.primaryMuted,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            totalOrders == 0
                ? '还没有订单数据'
                : '订单关联进度 ${(linkedRatio * 100).round()}%',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppPalette.textSecondary,
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
  ) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: '订单总数',
            value: orderCount.value?.toString() ?? '-',
            icon: Icons.receipt_long,
            color: AppPalette.amountMuted,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            title: '发票总数',
            value: invoiceCount.value?.toString() ?? '-',
            icon: Icons.description,
            color: AppPalette.primaryMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAccessGrid(BuildContext context) {
    return Column(
      children: [
        // 第一行：用餐证明导出 + 发票导出
        Row(
          children: [
            Expanded(
              child: _QuickAccessButton(
                icon: Icons.restaurant_menu,
                label: '用餐证明导出',
                color: AppPalette.amountMuted,
                onTap: () => context.push('/export/meal-proof'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickAccessButton(
                icon: Icons.receipt_long,
                label: '发票导出',
                color: AppPalette.primaryMuted,
                onTap: () => context.push('/export/invoice'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 第二行：报销材料导出
        Row(
          children: [
            Expanded(
              child: _QuickAccessButton(
                icon: Icons.file_download_outlined,
                label: '报销材料导出',
                color: AppPalette.amountMuted,
                centerContent: true,
                onTap: () => context.push('/export'),
              ),
            ),
          ],
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
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
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
      children: recentOrders
          .map((order) {
            final orderDate =
                order.orderDate != null && order.orderDate!.isNotEmpty
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
                      color: AppPalette.elevatedFill,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.receipt_long,
                      color: AppPalette.amountMuted,
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
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (orderDate != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              DateFormatter.formatDisplay(orderDate),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    DateFormatter.formatAmount(order.amount),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppPalette.amountMuted,
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
          })
          .cast<Widget>()
          .toList(),
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
              borderRadius: BorderRadius.circular(16),
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
                    color: AppPalette.amountMuted,
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
  final bool centerContent;

  const _QuickAccessButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.centerContent = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconChip = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: color),
    );
    final labelText = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: centerContent ? Alignment.center : Alignment.centerLeft,
      child: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: AppPalette.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        maxLines: 1,
      ),
    );

    return AppCard(
      padding: const EdgeInsets.all(16),
      margin: EdgeInsets.zero,
      onTap: onTap,
      child: Row(
        mainAxisAlignment: centerContent
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        mainAxisSize: centerContent ? MainAxisSize.min : MainAxisSize.max,
        children: [
          iconChip,
          const SizedBox(width: 12),
          if (centerContent) labelText else Expanded(child: labelText),
        ],
      ),
    );
  }
}

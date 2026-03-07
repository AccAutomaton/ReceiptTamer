import 'package:catering_receipt_recorder/core/constants/app_constants.dart';
import 'package:catering_receipt_recorder/presentation/providers/order_provider.dart';
import 'package:catering_receipt_recorder/presentation/widgets/common/empty_state.dart';
import 'package:catering_receipt_recorder/presentation/widgets/order/order_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Orders screen - displays list of all orders
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  @override
  void initState() {
    super.initState();
    // Load orders when screen initializes
    Future.microtask(() {
      ref.read(orderProvider.notifier).loadOrders();
    });
  }

  void _handleAddOrder() {
    context.push('/orders/new');
  }

  void _handleOrderTap(int orderId) {
    context.push('/orders/$orderId');
  }

  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(orderProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.titleOrders),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              _showFilterDialog(context);
            },
            tooltip: '筛选',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              _showSearchDialog(context);
            },
            tooltip: '搜索',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(orderProvider.notifier).loadOrders(refresh: true);
        },
        child: orderState.isLoading && orderState.orders.isEmpty
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : orderState.orders.isEmpty
                ? EmptyOrders(
                    onAdd: _handleAddOrder,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: orderState.orders.length,
                    itemBuilder: (context, index) {
                      final order = orderState.orders[index];
                      return OrderCard(
                        order: order,
                        onTap: () => _handleOrderTap(order.id!),
                      );
                    },
                  ),
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '筛选订单',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.list),
                title: const Text('全部订单'),
                onTap: () {
                  ref.read(orderProvider.notifier).loadOrders();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.today),
                title: const Text('今日订单'),
                onTap: () {
                  ref.read(orderProvider.notifier).loadTodayOrders();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month),
                title: const Text('本月订单'),
                onTap: () {
                  ref.read(orderProvider.notifier).loadThisMonthOrders();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    final searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('搜索订单'),
        content: TextField(
          controller: searchController,
          decoration: const InputDecoration(
            hintText: '输入店铺名称或订单号',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final query = searchController.text.trim();
              if (query.isNotEmpty) {
                ref.read(orderProvider.notifier).searchOrders(
                      shopName: query,
                      orderNumber: query,
                    );
              }
              Navigator.pop(context);
            },
            child: const Text('搜索'),
          ),
        ],
      ),
    );
  }
}

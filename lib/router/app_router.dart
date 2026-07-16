import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/orders/orders_screen.dart';
import '../presentation/screens/orders/order_detail_screen.dart';
import '../presentation/screens/orders/order_edit_screen.dart';
import '../presentation/screens/orders/invoice_selector_screen.dart';
import '../presentation/screens/invoices/invoices_screen.dart';
import '../presentation/screens/invoices/invoice_detail_screen.dart';
import '../presentation/screens/invoices/invoice_edit_screen.dart';
import '../presentation/screens/invoices/order_selector_screen.dart';
import '../presentation/screens/export/export_screen.dart';
import '../presentation/screens/export/export_options_screen.dart';
import '../presentation/screens/export/order_export_screen.dart';
import '../presentation/screens/export/meal_proof_order_select_screen.dart';
import '../presentation/screens/export/invoice_quick_select_screen.dart';
import '../presentation/screens/export/reimbursement_screen.dart';
import '../presentation/screens/export/reimbursement_check_screen.dart';
import '../presentation/screens/invoice_assistant/invoice_assistant_screen.dart';
import '../presentation/screens/settings/settings_screen.dart';
import '../presentation/screens/settings/data_cleanup_screen.dart';
import '../presentation/screens/settings/info_screen.dart';
import '../presentation/screens/settings/model_management_screen.dart';
import '../presentation/screens/settings/release_history_screen.dart';
import '../presentation/screens/settings/storage_management_screen.dart';
import '../presentation/screens/cleanup/order_cleanup_screen.dart';
import '../presentation/screens/cleanup/invoice_cleanup_screen.dart';
import '../presentation/screens/share/share_target_screen.dart';
import '../presentation/widgets/main_shell.dart';
import '../data/services/share_handler_service.dart';
import '../core/services/log_service.dart';
import '../core/services/log_config.dart';

/// Provider for the app router
final routerProvider = Provider<GoRouter>((ref) {
  logService.d(LogConfig.moduleApp, 'Router 初始化');
  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: '/',
    routes: [
      // Main shell with cached bottom navigation branches.
      StatefulShellRoute(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        navigatorContainerBuilder: (context, navigationShell, children) {
          return _AnimatedBranchContainer(
            currentIndex: navigationShell.currentIndex,
            children: children,
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: 'home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/orders',
                name: 'orders',
                builder: (context, state) => const OrdersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/invoices',
                name: 'invoices',
                builder: (context, state) {
                  final orderId = state.uri.queryParameters['orderId'] != null
                      ? int.tryParse(state.uri.queryParameters['orderId']!)
                      : null;
                  return InvoicesScreen(filterOrderId: orderId);
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/export',
                name: 'export',
                builder: (context, state) => const ReimbursementScreen(),
              ),
            ],
          ),
        ],
      ),
      // Routes outside the shell (no bottom nav)
      GoRoute(
        path: '/orders/new',
        name: 'order_new',
        builder: (context, state) {
          final sharedPath = state.uri.queryParameters['sharedPath'];
          final remainingCount =
              state.uri.queryParameters['remainingCount'] != null
              ? int.tryParse(state.uri.queryParameters['remainingCount']!)
              : null;
          // 安全解码路径
          String? decodedPath;
          if (sharedPath != null) {
            try {
              decodedPath = Uri.decodeComponent(sharedPath);
            } catch (e) {
              decodedPath = sharedPath; // 解码失败则使用原始值
            }
          }
          return OrderEditScreen(
            initialImagePath: decodedPath,
            remainingSharedCount: remainingCount ?? 0,
          );
        },
      ),
      // Order selector screen must be before /orders/:id to avoid matching "select" as an ID
      GoRoute(
        path: '/orders/select',
        name: 'order_selector',
        builder: (context, state) {
          // Parse selected order IDs from query parameters
          final selectedIdsStr = state.uri.queryParameters['selectedIds'];
          final excludeInvoiceId =
              state.uri.queryParameters['excludeInvoiceId'] != null
              ? int.tryParse(state.uri.queryParameters['excludeInvoiceId']!)
              : null;

          List<int> selectedIds = [];
          if (selectedIdsStr != null && selectedIdsStr.isNotEmpty) {
            selectedIds = selectedIdsStr
                .split(',')
                .map((id) => int.tryParse(id))
                .whereType<int>()
                .toList();
          }

          return OrderSelectorScreen(
            selectedOrderIds: selectedIds,
            excludeInvoiceId: excludeInvoiceId,
          );
        },
      ),
      // Invoice selector for orders
      GoRoute(
        path: '/invoices/select',
        name: 'invoice_selector',
        builder: (context, state) {
          final orderId = state.uri.queryParameters['orderId'] != null
              ? int.tryParse(state.uri.queryParameters['orderId']!)
              : null;
          if (orderId == null) {
            return const _ErrorScreen(message: 'Invalid order ID');
          }
          return InvoiceSelectorScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/orders/:id',
        name: 'order_detail',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) {
            return const _ErrorScreen(message: 'Invalid order ID');
          }
          return OrderDetailScreen(orderId: id);
        },
      ),
      GoRoute(
        path: '/orders/:id/edit',
        name: 'order_edit',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) {
            return const _ErrorScreen(message: 'Invalid order ID');
          }
          return OrderEditScreen(orderId: id);
        },
      ),
      GoRoute(
        path: '/invoices/new',
        name: 'invoice_new',
        builder: (context, state) {
          final orderId = state.uri.queryParameters['orderId'] != null
              ? int.tryParse(state.uri.queryParameters['orderId']!)
              : null;
          final orderIdsStr = state.uri.queryParameters['orderIds'] ?? '';
          final orderIds = orderIdsStr.isEmpty
              ? <int>[]
              : orderIdsStr
                    .split(',')
                    .map((id) => int.tryParse(id))
                    .whereType<int>()
                    .toList();
          final sharedPath = state.uri.queryParameters['sharedPath'];
          final remainingCount =
              state.uri.queryParameters['remainingCount'] != null
              ? int.tryParse(state.uri.queryParameters['remainingCount']!)
              : null;
          // 安全解码路径
          String? decodedPath;
          if (sharedPath != null) {
            try {
              decodedPath = Uri.decodeComponent(sharedPath);
            } catch (e) {
              decodedPath = sharedPath; // 解码失败则使用原始值
            }
          }
          return InvoiceEditScreen(
            initialOrderId: orderId,
            initialOrderIds: orderIds,
            initialFilePath: decodedPath,
            remainingSharedCount: remainingCount ?? 0,
          );
        },
      ),
      GoRoute(
        path: '/invoices/:id',
        name: 'invoice_detail',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) {
            return const _ErrorScreen(message: 'Invalid invoice ID');
          }
          return InvoiceDetailScreen(invoiceId: id);
        },
      ),
      GoRoute(
        path: '/invoices/:id/edit',
        name: 'invoice_edit',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) {
            return const _ErrorScreen(message: 'Invalid invoice ID');
          }
          return InvoiceEditScreen(invoiceId: id);
        },
      ),
      GoRoute(
        path: '/export/check',
        name: 'reimbursement_check',
        builder: (context, state) => const ReimbursementCheckScreen(),
      ),
      GoRoute(
        path: '/export/invoices',
        name: 'export_invoices',
        builder: (context, state) => const ExportScreen(),
      ),
      GoRoute(
        path: '/export/orders',
        name: 'export_orders',
        builder: (context, state) => const OrderExportScreen(),
      ),
      GoRoute(
        path: '/export/options',
        name: 'export_options',
        builder: (context, state) {
          final invoiceIdsStr = state.uri.queryParameters['invoiceIds'] ?? '';
          final orderIdsStr = state.uri.queryParameters['orderIds'] ?? '';

          final invoiceIds = invoiceIdsStr.isEmpty
              ? <int>[]
              : invoiceIdsStr
                    .split(',')
                    .map((id) => int.tryParse(id))
                    .whereType<int>()
                    .toList();
          final orderIds = orderIdsStr.isEmpty
              ? <int>[]
              : orderIdsStr
                    .split(',')
                    .map((id) => int.tryParse(id))
                    .whereType<int>()
                    .toList();

          return ExportOptionsScreen(
            invoiceIds: invoiceIds,
            orderIds: orderIds,
          );
        },
      ),
      // Meal proof quick export route
      GoRoute(
        path: '/export/meal-proof',
        name: 'meal_proof_export',
        builder: (context, state) => const MealProofOrderSelectScreen(),
      ),
      // Invoice quick export route
      GoRoute(
        path: '/export/invoice',
        name: 'invoice_export',
        builder: (context, state) => const InvoiceQuickSelectScreen(),
      ),
      GoRoute(
        path: '/invoice-assistant',
        name: 'invoice_assistant',
        builder: (context, state) => const InvoiceAssistantScreen(),
      ),
      // 设置移出主导航，但保留全部原有能力。
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      // Data cleanup routes
      GoRoute(
        path: '/settings/model-management',
        name: 'model_management',
        builder: (context, state) => const ModelManagementScreen(),
      ),
      GoRoute(
        path: '/settings/storage',
        name: 'storage_management',
        builder: (context, state) => const StorageManagementScreen(),
      ),
      GoRoute(
        path: '/settings/privacy',
        name: 'privacy_policy',
        builder: (context, state) => const InfoScreen(
          title: '隐私政策',
          markdownAssetPath: 'assets/docs/privacy_policy.md',
        ),
      ),
      GoRoute(
        path: '/settings/open-source',
        name: 'open_source_info',
        builder: (context, state) => const InfoScreen(
          title: '开源信息',
          markdownAssetPath: 'assets/docs/open_source.md',
        ),
      ),
      GoRoute(
        path: '/settings/release-history',
        name: 'release_history',
        builder: (context, state) => const ReleaseHistoryScreen(),
      ),
      GoRoute(
        path: '/settings/cleanup',
        name: 'data_cleanup',
        builder: (context, state) => const DataCleanupScreen(),
      ),
      GoRoute(
        path: '/settings/cleanup/orders',
        name: 'order_cleanup',
        builder: (context, state) => const OrderCleanupScreen(),
      ),
      GoRoute(
        path: '/settings/cleanup/invoices',
        name: 'invoice_cleanup',
        builder: (context, state) => const InvoiceCleanupScreen(),
      ),
      // Share target screen
      GoRoute(
        path: '/share',
        name: 'share_target',
        builder: (context, state) {
          final service = ShareHandlerService();
          final items = service.pendingSharedMedia ?? [];
          return ShareTargetScreen(sharedItems: items);
        },
      ),
    ],
    errorBuilder: (context, state) {
      final error = state.error ?? StateError('页面未找到');
      logService.e(
        LogConfig.moduleApp,
        '路由错误: $error',
        error,
        StackTrace.current,
      );
      return _ErrorScreen(message: state.error?.toString() ?? '页面未找到');
    },
  );
});

/// Error screen for navigation errors
class _ErrorScreen extends StatelessWidget {
  final String message;

  const _ErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('返回首页'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedBranchContainer extends StatefulWidget {
  const _AnimatedBranchContainer({
    required this.currentIndex,
    required this.children,
  });

  static const _duration = Duration(milliseconds: 320);

  final int currentIndex;
  final List<Widget> children;

  @override
  State<_AnimatedBranchContainer> createState() =>
      _AnimatedBranchContainerState();
}

class _AnimatedBranchContainerState extends State<_AnimatedBranchContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  var _slideDirection = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _AnimatedBranchContainer._duration,
      value: 1,
    );
    _updateAnimations();
  }

  @override
  void didUpdateWidget(_AnimatedBranchContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex == oldWidget.currentIndex) {
      return;
    }

    _slideDirection = widget.currentIndex > oldWidget.currentIndex ? 1 : -1;
    _updateAnimations();
    _controller
      ..stop()
      ..value = 0
      ..forward();
  }

  void _updateAnimations() {
    _fadeAnimation = _controller.drive(
      Tween<double>(
        begin: 0.88,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
    );
    _slideAnimation = _controller.drive(
      Tween<Offset>(
        begin: Offset(_slideDirection * 0.12, 0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.currentIndex,
      children: [
        for (var index = 0; index < widget.children.length; index++)
          _AnimatedBranch(
            index: index,
            currentIndex: widget.currentIndex,
            fadeAnimation: _fadeAnimation,
            slideAnimation: _slideAnimation,
            child: widget.children[index],
          ),
      ],
    );
  }
}

class _AnimatedBranch extends StatelessWidget {
  const _AnimatedBranch({
    required this.index,
    required this.currentIndex,
    required this.fadeAnimation,
    required this.slideAnimation,
    required this.child,
  });

  final int index;
  final int currentIndex;
  final Animation<double> fadeAnimation;
  final Animation<Offset> slideAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final active = index == currentIndex;

    return Offstage(
      offstage: !active,
      child: TickerMode(
        enabled: active,
        child: FadeTransition(
          opacity: fadeAnimation,
          child: SlideTransition(position: slideAnimation, child: child),
        ),
      ),
    );
  }
}

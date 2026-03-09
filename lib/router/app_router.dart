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
import '../presentation/screens/settings/settings_screen.dart';
import '../presentation/widgets/main_shell.dart';

/// Provider for the app router
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: '/',
    routes: [
      // Main shell with bottom navigation
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/orders',
            name: 'orders',
            builder: (context, state) => const OrdersScreen(),
          ),
          GoRoute(
            path: '/invoices',
            name: 'invoices',
            builder: (context, state) {
              final orderId = state.uri.queryParameters['orderId'] != null
                  ? int.tryParse(state.uri.queryParameters['orderId']!)
                  : null;
              return InvoicesScreen(
                filterOrderId: orderId,
              );
            },
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
      // Routes outside the shell (no bottom nav)
      GoRoute(
        path: '/orders/new',
        name: 'order_new',
        builder: (context, state) => const OrderEditScreen(),
      ),
      // Order selector screen must be before /orders/:id to avoid matching "select" as an ID
      GoRoute(
        path: '/orders/select',
        name: 'order_selector',
        builder: (context, state) {
          // Parse selected order IDs from query parameters
          final selectedIdsStr = state.uri.queryParameters['selectedIds'];
          final excludeInvoiceId = state.uri.queryParameters['excludeInvoiceId'] != null
              ? int.tryParse(state.uri.queryParameters['excludeInvoiceId']!)
              : null;

          List<int> selectedIds = [];
          if (selectedIdsStr != null && selectedIdsStr.isNotEmpty) {
            selectedIds = selectedIdsStr.split(',').map((id) => int.tryParse(id)).whereType<int>().toList();
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
          return InvoiceEditScreen(
            initialOrderId: orderId,
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
        path: '/export',
        name: 'export',
        builder: (context, state) => const ExportScreen(),
      ),
    ],
    errorBuilder: (context, state) => _ErrorScreen(
      message: state.error?.toString() ?? 'Page not found',
    ),
  );
});

/// Error screen for navigation errors
class _ErrorScreen extends StatelessWidget {
  final String message;

  const _ErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
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
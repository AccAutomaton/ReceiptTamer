import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Shell widget that provides bottom navigation bar
class MainShell extends ConsumerStatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;
  bool _initialized = false;

  // Navigation destinations (excluding the center FAB)
  static const _destinations = [
    _NavDestination(
      path: '/',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: '首页',
    ),
    _NavDestination(
      path: '/orders',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      label: '订单',
    ),
    _NavDestination(
      path: '/invoices',
      icon: Icons.description_outlined,
      selectedIcon: Icons.description,
      label: '发票',
    ),
    _NavDestination(
      path: '/settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: '设置',
    ),
  ];

  void _onDestinationSelected(int index) {
    // _currentIndex stores UI index directly (for NavigationBar.selectedIndex)
    // UI: [0:首页, 1:订单, 2:占位符, 3:发票, 4:设置]
    // _destinations: [0:首页, 1:订单, 2:发票, 3:设置]
    final destIndex = index < 2 ? index : index - 1;
    setState(() => _currentIndex = index);
    context.go(_destinations[destIndex].path);
  }

  void _onAddPressed() {
    context.push('/orders/new');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Use SchedulerBinding to defer state update to after build
    _updateCurrentIndex();
  }

  void _updateCurrentIndex() {
    try {
      final state = GoRouterState.of(context);
      final location = state.matchedLocation;
      final destIndex = _destinations.indexWhere((d) => d.path == location);
      if (destIndex != -1) {
        // Map destination index back to UI index (add 1 for items after placeholder)
        // _destinations: [0:首页, 1:订单, 2:发票, 3:设置]
        // UI: [0:首页, 1:订单, 2:占位符, 3:发票, 4:设置]
        final uiIndex = destIndex < 2 ? destIndex : destIndex + 1;
        if (uiIndex != _currentIndex) {
          // Use WidgetsBinding to defer setState to after the current build frame
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _currentIndex = uiIndex);
            }
          });
        }
        _initialized = true;
      }
    } catch (e) {
      // Ignore errors during route state access
      // This can happen during initial build before router is fully initialized
      debugPrint('Error updating current index: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Stack(
      children: [
        Scaffold(
          body: widget.child,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onDestinationSelected,
            destinations: [
              // 首页
              NavigationDestination(
                icon: Icon(_destinations[0].icon),
                selectedIcon: Icon(_destinations[0].selectedIcon),
                label: _destinations[0].label,
              ),
              // 订单
              NavigationDestination(
                icon: Icon(_destinations[1].icon),
                selectedIcon: Icon(_destinations[1].selectedIcon),
                label: _destinations[1].label,
              ),
              // 中间的加号占位
              NavigationDestination(
                icon: const SizedBox.shrink(),
                label: '',
                enabled: false,
              ),
              // 发票
              NavigationDestination(
                icon: Icon(_destinations[2].icon),
                selectedIcon: Icon(_destinations[2].selectedIcon),
                label: _destinations[2].label,
              ),
              // 设置
              NavigationDestination(
                icon: Icon(_destinations[3].icon),
                selectedIcon: Icon(_destinations[3].selectedIcon),
                label: _destinations[3].label,
              ),
            ],
          ),
        ),
        // FAB positioned outside Scaffold to prevent animation on rebuild
        Positioned(
          bottom: 35,
          left: 0,
          right: 0,
          child: Center(
            child: FloatingActionButton(
              key: const ValueKey('main_fab'),
              heroTag: null,
              onPressed: _onAddPressed,
              elevation: 8,
              highlightElevation: 12,
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              shape: const CircleBorder(),
              child: const Icon(Icons.add, size: 32),
            ),
          ),
        ),
      ],
    );
  }
}

class _NavDestination {
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavDestination({
    required this.path,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
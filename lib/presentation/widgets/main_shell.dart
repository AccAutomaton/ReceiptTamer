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
    setState(() => _currentIndex = index);
    context.go(_destinations[index].path);
  }

  void _onAddPressed() {
    context.push('/orders/new');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateCurrentIndex();
  }

  void _updateCurrentIndex() {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _destinations.indexWhere((d) => d.path == location);
    if (index != -1 && index != _currentIndex) {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
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
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddPressed,
        elevation: 8,
        highlightElevation: 12,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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
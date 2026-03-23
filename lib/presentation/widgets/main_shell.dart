import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:receipt_tamer/data/models/app_version.dart';
import 'package:receipt_tamer/data/services/update_preferences.dart';
import 'package:receipt_tamer/data/services/update_service.dart';

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
  DateTime? _lastPressedTime;
  bool _updateChecked = false;

  final UpdateService _updateService = UpdateService();

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
      icon: Icons.info_outline,
      selectedIcon: Icons.info,
      label: '关于',
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.receipt_long,
                color: colorScheme.primary,
              ),
              title: const Text('添加订单'),
              subtitle: const Text('通过订单截图导入'),
              onTap: () {
                Navigator.pop(context);
                context.push('/orders/new');
              },
            ),
            ListTile(
              leading: Icon(
                Icons.description,
                color: colorScheme.primary,
              ),
              title: const Text('添加发票'),
              subtitle: const Text('通过图片或PDF导入'),
              onTap: () {
                Navigator.pop(context);
                context.push('/invoices/new');
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 处理返回键：在主页面时将应用移到后台
  Future<bool> _handleBackPress() async {
    final now = DateTime.now();
    // 检查是否在主Tab页面（首页、订单、发票、设置）
    final state = GoRouterState.of(context);
    final location = state.matchedLocation;
    final isMainTab = _destinations.any((d) => d.path == location);

    if (!isMainTab) {
      // 不在主Tab页面，允许正常返回
      return true;
    }

    // 双击返回键退出提示
    if (_lastPressedTime == null ||
        now.difference(_lastPressedTime!) > const Duration(seconds: 2)) {
      _lastPressedTime = now;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('再次返回回到桌面'),
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }

    // 将应用移到后台
    SystemNavigator.pop();
    return false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Use SchedulerBinding to defer state update to after build
    _updateCurrentIndex();
    // Auto check for updates once
    _autoCheckForUpdates();
  }

  /// Auto check for updates silently (once per 12 hours)
  Future<void> _autoCheckForUpdates() async {
    if (_updateChecked) return;
    _updateChecked = true;

    try {
      // Check if enough time has passed
      final shouldCheck = await UpdatePreferences.shouldCheckForUpdate();
      if (!shouldCheck) return;

      // Check for updates
      final response = await _updateService.checkForUpdates();

      // Update last check time
      await UpdatePreferences.setLastCheckTime(DateTime.now());

      if (!mounted) return;

      // If update available and not ignored, show dialog
      if (response.result == UpdateCheckResult.available &&
          response.latestVersion != null) {
        final isIgnored = await UpdatePreferences.isVersionIgnored(
          response.latestVersion!.version,
        );
        if (!isIgnored && mounted) {
          _showAutoUpdateDialog(response.latestVersion!);
        }
      }
      // All other cases (no update, error, rate limited) are silent
    } catch (e) {
      // Silently ignore any errors during auto update check
      // User will not be notified of any errors
    }
  }

  /// Show auto update dialog with ignore options
  void _showAutoUpdateDialog(AppVersion latestVersion) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.system_update, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(child: Text('发现新版本 ${latestVersion.version}')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (latestVersion.formattedFileSize != null)
                Text(
                  '安装包大小: ${latestVersion.formattedFileSize}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              const SizedBox(height: 12),
              if (latestVersion.changelog != null &&
                  latestVersion.changelog!.isNotEmpty) ...[
                const Text(
                  '更新内容:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Text(
                      latestVersion.changelog!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await UpdatePreferences.setIgnoredVersion(latestVersion.version);
            },
            child: const Text('忽略此版本'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后提醒'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/settings');
            },
            child: const Text('立即更新'),
          ),
        ],
        actionsAlignment: MainAxisAlignment.end,
      ),
    );
  }

  @override
  void dispose() {
    _updateService.dispose();
    super.dispose();
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handleBackPress();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Stack(
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
                // 关于
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
      ),
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
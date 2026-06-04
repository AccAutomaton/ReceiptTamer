import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:receipt_tamer/data/services/update_preferences.dart';
import 'package:receipt_tamer/data/services/update_service.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_bottom_sheet.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_navigation_bar.dart';
import 'package:receipt_tamer/presentation/widgets/common/liquid_glass_background.dart';
import 'package:receipt_tamer/presentation/widgets/common/update_dialog.dart';

/// Shell widget that provides bottom navigation bar
class MainShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  DateTime? _lastPressedTime;
  bool _updateChecked = false;

  final UpdateService _updateService = UpdateService();

  /// Path of the downloaded APK file (for cleanup after install)
  String? _downloadedApkPath;

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
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  void _onAddPressed() {
    showGlassBottomSheet<void>(
      context: context,
      builder: (context) => GlassBottomSheet(
        key: const ValueKey('glass_add_sheet'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            GlassActionTile(
              icon: Icons.receipt_long,
              title: '添加订单',
              subtitle: '通过订单截图导入',
              onTap: () {
                Navigator.pop(context);
                context.push('/orders/new');
              },
            ),
            const SizedBox(height: 6),
            GlassActionTile(
              icon: Icons.description,
              title: '添加发票',
              subtitle: '通过图片或PDF导入',
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Clean up APK file after returning from installation
      _cleanupApkAfterInstall();
    }
  }

  /// Clean up downloaded APK file after installation
  Future<void> _cleanupApkAfterInstall() async {
    final apkPath = _downloadedApkPath;
    _downloadedApkPath = null; // 先清空避免重复清理
    if (apkPath != null) {
      await _updateService.deleteApk(apkPath);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
          UpdateDialog.show(
            context,
            response.latestVersion!,
            updateService: _updateService,
            onApkDownloaded: (apkPath) {
              _downloadedApkPath = apkPath;
            },
          );
        }
      }
      // All other cases (no update, error, rate limited) are silent
    } catch (e) {
      // Silently ignore any errors during auto update check
      // User will not be notified of any errors
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = widget.navigationShell.currentIndex;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handleBackPress();
        if (shouldPop && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pop();
            }
          });
        }
      },
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: LiquidGlassBackground(child: widget.navigationShell),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: GlassNavigationBar(
                selectedIndex: selectedIndex,
                items: [
                  for (final destination in _destinations)
                    GlassNavItem(
                      icon: destination.icon,
                      selectedIcon: destination.selectedIcon,
                      label: destination.label,
                    ),
                ],
                onDestinationSelected: _onDestinationSelected,
                onCenterPressed: _onAddPressed,
              ),
            ),
          ],
        ),
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

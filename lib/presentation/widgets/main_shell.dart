import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:receipt_tamer/data/services/update_preferences.dart';
import 'package:receipt_tamer/data/services/update_service.dart';
import 'package:receipt_tamer/data/services/share_handler_service.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_notice.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_bottom_sheet.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_navigation_bar.dart';
import 'package:receipt_tamer/presentation/widgets/common/liquid_glass_background.dart';
import 'package:receipt_tamer/presentation/widgets/common/update_dialog.dart';

enum MainShellBackDecision { showPrompt, exit }

/// Keeps Android BACK handling deterministic and independently testable.
@visibleForTesting
class MainShellBackExitGuard {
  MainShellBackExitGuard({this.window = const Duration(seconds: 2)});

  final Duration window;
  DateTime? _lastPressedAt;

  MainShellBackDecision register(DateTime now) {
    final lastPressedAt = _lastPressedAt;
    if (lastPressedAt == null ||
        now.isBefore(lastPressedAt) ||
        now.difference(lastPressedAt) > window) {
      _lastPressedAt = now;
      return MainShellBackDecision.showPrompt;
    }

    _lastPressedAt = null;
    return MainShellBackDecision.exit;
  }

  void reset() => _lastPressedAt = null;
}

/// Shell widget that provides bottom navigation bar
class MainShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  final MainShellBackExitGuard _backExitGuard = MainShellBackExitGuard();
  bool _updateChecked = false;

  final UpdateService _updateService = UpdateService();

  /// Path of the downloaded APK file (for cleanup after install)
  String? _downloadedApkPath;

  // 四个连续的业务目的地；新增入口独立放在右侧。
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
      path: '/export',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
      label: '报销',
    ),
  ];

  void _onDestinationSelected(int index) {
    _backExitGuard.reset();
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  void _onAddPressed() {
    final shareHandler = ShareHandlerService();
    final pendingItems = shareHandler.pendingSharedMedia ?? const [];
    final pendingImages = pendingItems.where((item) => item.isImage).length;
    final pendingPdfs = pendingItems.where((item) => item.isPdf).length;

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
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '新增',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (pendingItems.isNotEmpty) ...[
              GlassActionTile(
                key: const ValueKey('resume_shared_media'),
                icon: Icons.move_to_inbox_outlined,
                title: '待处理文件',
                subtitle: '图片 $pendingImages · PDF $pendingPdfs',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/share');
                },
              ),
              const SizedBox(height: 6),
            ],
            GlassActionTile(
              icon: Icons.receipt_long,
              title: '添加订单',
              subtitle: '导入订单截图',
              onTap: () {
                Navigator.pop(context);
                context.push('/orders/new');
              },
            ),
            const SizedBox(height: 6),
            GlassActionTile(
              icon: Icons.description,
              title: '添加发票',
              subtitle: '导入图片或 PDF',
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

  /// The shell owns only the four root tabs. Routes above it pop normally;
  /// every BACK attempt that reaches the shell therefore follows this guard.
  void _handleBackPress() {
    switch (_backExitGuard.register(DateTime.now())) {
      case MainShellBackDecision.showPrompt:
        AppNotice.info(
          context,
          '再次返回回到桌面',
          duration: const Duration(seconds: 2),
        );
        return;
      case MainShellBackDecision.exit:
        SystemNavigator.pop();
        return;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Clean up an installer APK left by a process-replacing app update.
    _updateService.cleanupPendingApk();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _backExitGuard.reset();
    }
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
      await _updateService.cleanupPendingApk();
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
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
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
                onIntakePressed: _onAddPressed,
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

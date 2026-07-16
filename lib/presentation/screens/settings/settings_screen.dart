import 'package:receipt_tamer/core/constants/app_constants.dart';
import 'package:receipt_tamer/core/services/log_service.dart';
import 'package:receipt_tamer/core/services/log_config.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/data/services/update_preferences.dart';
import 'package:receipt_tamer/data/services/update_service.dart';
import 'package:receipt_tamer/presentation/screens/export/saved_files_screen.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_card.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_surface.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_page_scaffold.dart';
import 'package:receipt_tamer/presentation/widgets/common/receipt_icon.dart';
import 'package:receipt_tamer/presentation/widgets/common/scroll_edge_fog.dart';
import 'package:receipt_tamer/presentation/widgets/common/update_dialog.dart';
import 'package:receipt_tamer/presentation/widgets/settings/backup_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// 设置页面
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  final UpdateService _updateService = UpdateService();
  bool _isCheckingUpdate = false;
  String _currentVersion = '';

  /// Path of the downloaded APK file (for cleanup after install)
  String? _downloadedApkPath;

  /// Logo tap tracking for log export
  int _logoTapCount = 0;
  DateTime? _lastLogoTapTime;
  bool _isExportingLogs = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCurrentVersion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateService.dispose();
    super.dispose();
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

  /// Handle logo tap for log export (tap 10 times within 500ms each)
  void _handleLogoTap() {
    final now = DateTime.now();

    // Reset if too long since last tap
    if (_lastLogoTapTime != null &&
        now.difference(_lastLogoTapTime!).inMilliseconds >
            LogConfig.tapTimeoutMs) {
      _logoTapCount = 0;
    }

    _lastLogoTapTime = now;
    _logoTapCount++;

    if (_logoTapCount >= LogConfig.tapCountToTrigger) {
      _logoTapCount = 0;
      _exportLogs();
    }
  }

  /// Export logs to Download directory
  Future<void> _exportLogs() async {
    if (_isExportingLogs) return;

    setState(() => _isExportingLogs = true);

    try {
      logService.i(LogConfig.moduleUi, '用户触发导出日志');

      final exportedPath = await logService.exportLogs();

      if (!mounted) return;

      if (exportedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('日志已导出：$exportedPath'),
            action: SnackBarAction(
              label: '查看',
              onPressed: () {
                // Open saved files screen in logs directory
                showSavedFilesScreen(
                  context,
                  initialSubDir: LogConfig.logDirName,
                );
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('日志导出失败')));
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingLogs = false);
      }
    }
  }

  Future<void> _loadCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _currentVersion = packageInfo.version;
      });
    }
  }

  Future<void> _checkUpdate() async {
    if (_isCheckingUpdate) return;

    setState(() => _isCheckingUpdate = true);

    try {
      final response = await _updateService.checkForUpdates();

      // Update last check time
      await UpdatePreferences.setLastCheckTime(DateTime.now());

      if (!mounted) return;

      if (response.result == UpdateCheckResult.available &&
          response.latestVersion != null) {
        // Clear ignored version when manually checking
        await UpdatePreferences.clearIgnoredVersion();
        if (!mounted) return;
        UpdateDialog.show(
          context,
          response.latestVersion!,
          updateService: _updateService,
          onApkDownloaded: (apkPath) {
            _downloadedApkPath = apkPath;
          },
        );
      } else if (response.result == UpdateCheckResult.notAvailable) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已是最新版本')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_updateFailureMessage(response.errorMessage))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  String _updateFailureMessage(String? errorMessage) {
    if (errorMessage == 'RATE_LIMITED') {
      return 'GitHub 请求受限，请前往项目页面查看最新版本';
    }

    final normalized = errorMessage?.toLowerCase() ?? '';
    final isNetworkFailure = const [
      'socketexception',
      'clientexception',
      'failed host lookup',
      'connection refused',
      'connection reset',
      'network is unreachable',
      'timed out',
      'timeout',
    ].any(normalized.contains);

    if (isNetworkFailure) {
      return '网络连接失败，请检查网络后重试';
    }
    if (normalized.startsWith('server returned')) {
      return 'GitHub 服务暂时不可用，请稍后重试';
    }
    return '检查更新失败，请稍后重试';
  }

  void _navigateToInfo(BuildContext context, String type) {
    switch (type) {
      case 'privacy':
        context.push('/settings/privacy');
        break;
      case 'opensource':
        context.push('/settings/open-source');
        break;
      default:
        return;
    }
  }

  Future<void> _launchGitHubUrl(BuildContext context) async {
    final uri = Uri.parse('https://github.com/AccAutomaton/ReceiptTamer');
    try {
      // 先尝试用外部应用（如 GitHub App）打开
      if (await canLaunchUrl(uri)) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        // 如果外部应用打开失败，回退到浏览器
        if (!launched) {
          await launchUrl(uri, mode: LaunchMode.platformDefault);
        }
      } else {
        // 无法用外部应用打开，直接用浏览器
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('打开链接失败，请重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GlassPageScaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          '设置',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: AppPalette.textPrimaryFor(context),
            fontWeight: FontWeight.w800,
          ),
        ),
        elevation: 0,
      ),
      body: ScrollEdgeFog(
        showTop: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // 应用信息头部
            _buildAppHeader(context, theme),

            _buildSection(context, '模型与数据', [
              _buildListTile(
                context,
                icon: Icons.tune_outlined,
                title: '模型管理',
                subtitle: '本地与外部模型',
                onTap: () => context.push('/settings/model-management'),
              ),
              _buildListTile(
                context,
                icon: Icons.storage_outlined,
                title: '存储管理',
                subtitle: '存储占用、缓存与数据',
                onTap: () => context.push('/settings/storage'),
              ),
              _buildListTile(
                context,
                icon: Icons.backup_outlined,
                title: '备份与还原',
                subtitle: '备份或恢复应用数据',
                onTap: () => showBackupDialog(context),
              ),
              _buildListTile(
                context,
                icon: Icons.cleaning_services_outlined,
                title: '数据清理',
                subtitle: '清理订单或发票',
                onTap: () => context.push('/settings/cleanup'),
              ),
            ]),

            const SizedBox(height: 14),

            _buildSection(context, '应用信息', [
              _buildListTile(
                context,
                icon: Icons.privacy_tip_outlined,
                title: '隐私政策',
                onTap: () => _navigateToInfo(context, 'privacy'),
              ),
              _buildListTile(
                context,
                icon: Icons.code_outlined,
                title: '开源信息',
                onTap: () => _navigateToInfo(context, 'opensource'),
              ),
              _buildListTile(
                context,
                icon: Icons.history_outlined,
                title: '更新历史',
                onTap: () => context.push('/settings/release-history'),
              ),
            ]),

            const SizedBox(height: 32),

            // 底部版权信息
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  Text(
                    'Copyright 2026 acautomaton.com. All rights reserved.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Powered By Codex With GPT-5.5',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  // GitHub 链接按钮
                  InkWell(
                    onTap: () => _launchGitHubUrl(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            FontAwesomeIcons.github,
                            size: 20,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'GitHub',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppHeader(BuildContext context, ThemeData theme) {
    return GlassSurface(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      fillColor: AppGlassTokens.sheetFillFor(context),
      borderRadius: BorderRadius.circular(AppRadii.glassLarge),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 应用图标（连点10次导出日志）
          GestureDetector(onTap: _handleLogoTap, child: ReceiptIcon(size: 96)),
          // 应用名称
          Text(
            AppConstants.appName,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppPalette.textPrimaryFor(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          // 版本号
          Text(
            '版本 ${_currentVersion.isNotEmpty ? _currentVersion : '...'}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppPalette.textSecondaryFor(context),
            ),
          ),
          // 检查更新按钮
          TextButton.icon(
            onPressed: _isCheckingUpdate ? null : _checkUpdate,
            icon: _isCheckingUpdate
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 18),
            label: Text(_isCheckingUpdate ? '检查中…' : '检查更新'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    final theme = Theme.of(context);

    return AppCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppPalette.selectedFillFor(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          icon,
          color: AppPalette.actionPrimaryFor(context),
          size: 21,
        ),
      ),
      title: Text(title),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
      trailing:
          trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
    );
  }
}

import 'package:catering_receipt_recorder/core/constants/app_constants.dart';
import 'package:catering_receipt_recorder/data/models/app_version.dart';
import 'package:catering_receipt_recorder/data/services/file_service.dart';
import 'package:catering_receipt_recorder/data/services/llm_service.dart';
import 'package:catering_receipt_recorder/data/services/update_service.dart';
import 'package:catering_receipt_recorder/presentation/providers/ocr_provider.dart';
import 'package:catering_receipt_recorder/presentation/screens/settings/info_screen.dart';
import 'package:catering_receipt_recorder/presentation/widgets/common/app_button.dart';
import 'package:catering_receipt_recorder/presentation/widgets/common/storage_ring_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// About screen
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final FileService _fileService = FileService();
  final UpdateService _updateService = UpdateService();
  Map<String, int> _storageUsage = {};
  bool _isLoading = true;
  bool _isCheckingUpdate = false;
  LlmService? _llmService;
  String _currentVersion = '';

  @override
  void initState() {
    super.initState();
    _loadStorageUsage();
    _initLlmService();
    _loadCurrentVersion();
  }

  Future<void> _loadCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _currentVersion = packageInfo.version;
      });
    }
  }

  Future<void> _initLlmService() async {
    // Get LLM service from OCR provider
    final ocrState = ref.read(ocrProvider);
    _llmService = ocrState.llmService;
    setState(() {});
  }

  Future<void> _loadStorageUsage() async {
    setState(() => _isLoading = true);

    try {
      final usage = await _fileService.getStorageUsage();
      setState(() {
        _storageUsage = usage;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清理'),
        content: const Text('确定要清理缓存文件吗？这不会删除您的订单和发票数据。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final deletedCount = await _fileService.cleanTempFiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已清理 $deletedCount 个临时文件')),
        );
        _loadStorageUsage();
      }
    }
  }

  Future<void> _checkUpdate() async {
    if (_isCheckingUpdate) return;

    setState(() => _isCheckingUpdate = true);

    try {
      final response = await _updateService.checkForUpdates();

      if (!mounted) return;

      if (response.result == UpdateCheckResult.available &&
          response.latestVersion != null) {
        _showUpdateDialog(response.latestVersion!);
      } else if (response.result == UpdateCheckResult.notAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前已是最新版本')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('检查更新失败: ${response.errorMessage ?? "未知错误"}'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  void _showUpdateDialog(AppVersion latestVersion) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.system_update, color: Colors.blue),
            const SizedBox(width: 8),
            Text('发现新版本 ${latestVersion.version}'),
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
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后提醒'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _downloadAndInstall(latestVersion);
            },
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAndInstall(AppVersion version) async {
    if (version.downloadUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('下载地址不可用')),
      );
      return;
    }

    double progress = 0;
    bool downloadCancelled = false;

    // Show download progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('正在下载'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 16),
              Text('${(progress * 100).toStringAsFixed(1)}%'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                downloadCancelled = true;
                Navigator.pop(context);
              },
              child: const Text('取消'),
            ),
          ],
        ),
      ),
    );

    // Download APK
    final filePath = await _updateService.downloadApk(
      version.downloadUrl!,
      onProgress: (p) {
        if (mounted && !downloadCancelled) {
          setState(() => progress = p);
        }
      },
    );

    if (!mounted) return;

    // Close progress dialog if still open
    if (filePath != null && !downloadCancelled) {
      Navigator.of(context, rootNavigator: true).pop();

      // Install APK
      final installed = await _updateService.installApk(filePath);
      if (!installed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('安装失败，请手动打开下载的文件')),
        );
      }
    } else if (mounted && !downloadCancelled) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('下载失败，请稍后重试')),
      );
    }
  }

  void _navigateToInfo(BuildContext context, String type) {
    String title;
    String content;

    switch (type) {
      case 'privacy':
        title = '隐私政策';
        content = _privacyPolicyContent;
        break;
      case 'opensource':
        title = '开源信息';
        content = _openSourceContent;
        break;
      default:
        return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InfoScreen(title: title, content: content),
      ),
    );
  }

  static const String _privacyPolicyContent = '''
餐饮发票报销助手 隐私政策

更新日期：2026年3月

感谢您使用餐饮发票报销助手（以下简称"本应用"）。我们非常重视您的隐私保护，本隐私政策旨在向您说明我们如何收集、使用和保护您的信息。

一、信息收集

本应用是一款本地化应用，所有数据均存储在您的设备本地，不会上传至任何服务器。我们收集的信息包括：

1. 订单信息：店铺名称、实付款、下单时间、订单号
2. 发票信息：发票号码、开票日期、价税合计金额
3. 图片文件：订单截图、发票图片/PDF

以上信息均由您主动输入或通过OCR识别功能获取，存储在您设备的本地数据库中。

二、信息使用

您的信息仅用于：
1. 记录和管理您的餐饮发票报销单据
2. 导出订单和发票数据为Excel文件
3. 通过本地OCR识别提取订单和发票信息

三、信息存储与安全

1. 所有数据存储在您的设备本地数据库中
2. 我们不会将您的任何数据上传至云端服务器
3. 您可以随时删除本应用，所有数据将随之删除

四、OCR与AI功能

本应用的OCR识别和AI推理功能完全在您的设备本地运行：
1. OCR引擎：RapidOcrAndroidOnnx，基于ONNX Runtime
2. AI推理：MNN框架，运行Qwen3.5-0.8B模型

所有识别过程均在本地完成，不会将您的图片或数据发送到任何服务器。

五、第三方服务

本应用不集成任何第三方分析、广告或推送服务。

六、权限说明

本应用需要以下权限：
1. 存储权限：用于读取和保存图片、PDF文件
2. 相机权限：用于拍摄订单截图（可选）

七、联系我们

如您对本隐私政策有任何疑问，请通过以下方式联系我们：
acautomaton@icloud.com

八、隐私政策更新

我们可能会不时更新本隐私政策。更新后的政策将在本应用中发布，请定期查阅。
''';

  static const String _openSourceContent = '''
餐饮发票报销助手 开源许可证

本应用使用了以下开源软件包和库：

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Flutter SDK
Copyright 2014 The Flutter Authors. All rights reserved.
Licensed under the BSD 3-Clause License

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

cupertino_icons
Copyright 2014 The Flutter Authors. All rights reserved.
Licensed under the BSD 3-Clause License

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

flutter_riverpod
Copyright 2020 Remi Rousselet
Licensed under the MIT License

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

sqflite
Copyright 2014 Tekartik
Licensed under the BSD 2-Clause License

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

sqflite_common_ffi
Copyright 2020 Tekartik
Licensed under the BSD 2-Clause License

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

image_picker
Copyright 2013 The Flutter Authors
Licensed under the BSD 3-Clause License

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

file_picker
Copyright 2018 Miguel Henvu
Licensed under the MIT License

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

syncfusion_flutter_pdf
syncfusion_flutter_pdfviewer
Copyright 2001-2024 Syncfusion Inc.
Licensed under the Syncfusion Commercial License

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

go_router
Copyright 2014 The Flutter Authors. All rights reserved.
Licensed under the BSD 3-Clause License

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

freezed_annotation
freezed
Copyright 2019 Remi Rousselet
Licensed under the MIT License

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

json_annotation
json_serializable
Copyright 2017, the Dart project authors.
Licensed under the BSD 3-Clause License

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

intl
Copyright 2013, the Dart project authors.
Licensed under the BSD 3-Clause License

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

uuid
Copyright 2018 Yulian Kuncheff
Licensed under the MIT License

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

path_provider
Copyright 2013 The Flutter Authors
Licensed under the BSD 3-Clause License

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

share_plus
Copyright 2019 The Flutter Authors
Licensed under the BSD 3-Clause License

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

excel
Copyright 2019 Kawaljeet Singh
Licensed under the BSD 3-Clause License

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

image
Copyright 2013-2022, Brendan Duncan.
Licensed under the MIT License

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RapidOcrAndroidOnnx
Copyright 2022 RapidAI
Licensed under the Apache License 2.0

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

MNN (Mobile Neural Network)
Copyright 2018 Alibaba Group
Licensed under the Apache License 2.0

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Qwen3.5-0.8B
Copyright 2024 Alibaba Group
Licensed under the Apache License 2.0

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

感谢以上开源项目的贡献者！
''';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ocrState = ref.watch(ocrProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('关于'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 应用信息头部
          _buildAppHeader(context, theme, colorScheme),

          // AI引擎状态
          _buildAiEngineSection(context, theme, colorScheme, ocrState),

          const SizedBox(height: 16),

          // 存储信息
          _buildSection(
            context,
            '存储管理',
            [
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                // Ring chart with legend on the right
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      StorageRingChart(
                        storageData: _storageUsage,
                        size: 160,
                        strokeWidth: 16,
                      ),
                      const SizedBox(width: 24),
                      StorageLegend(storageData: _storageUsage),
                    ],
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.all(16),
                child: AppButton(
                  text: '清理缓存',
                  onPressed: _clearCache,
                  type: AppButtonType.outlined,
                  isFullWidth: true,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 隐私政策与开源信息
          _buildSection(
            context,
            '',
            [
              _buildListTile(
                context,
                icon: Icons.privacy_tip_outlined,
                title: '隐私政策',
                subtitle: '数据仅存储在本地设备',
                onTap: () => _navigateToInfo(context, 'privacy'),
              ),
              _buildListTile(
                context,
                icon: Icons.code_outlined,
                title: '开源信息',
                subtitle: '查看开源许可证',
                onTap: () => _navigateToInfo(context, 'opensource'),
              ),
            ],
          ),

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
                  'Powered By Claude Code With GLM-5.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppHeader(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 应用图标
          Icon(
            Icons.receipt_long,
            size: 48,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 16),
          // 应用名称
          Text(
            AppConstants.appName,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          // 版本号
          Text(
            '版本 ${_currentVersion.isNotEmpty ? _currentVersion : '...'}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
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
            label: Text(_isCheckingUpdate ? '检查中...' : '检查更新'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiEngineSection(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    dynamic ocrState,
  ) {
    final isOcrAvailable = ocrState.isModelAvailable;
    final isLlmAvailable = _llmService?.isInitialized == true;
    final isLlmLoading = _llmService?.isLoading == true;
    final isArchNotSupported = _llmService?.archNotSupported == true;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  ' AI 引擎',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '均在您的设备上运行',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Paddle OCR
          ListTile(
            leading: Icon(Icons.document_scanner, color: colorScheme.primary),
            title: const Text('Paddle OCR'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isOcrAvailable) ...[
                  GestureDetector(
                    onTap: () => _showUnavailableInfo(context, 'ocr', false),
                    child: Icon(
                      Icons.help_outline,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                _buildStatusBadge(
                  isOcrAvailable ? '可用' : '不可用',
                  isOcrAvailable ? Colors.green : Colors.orange,
                ),
              ],
            ),
          ),
          // Qwen 3.5
          ListTile(
            leading: Icon(Icons.psychology, color: colorScheme.primary),
            title: const Text('Qwen 3.5'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isLlmAvailable && !isLlmLoading) ...[
                  GestureDetector(
                    onTap: () => _showUnavailableInfo(context, 'llm', isArchNotSupported),
                    child: Icon(
                      Icons.help_outline,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                _buildStatusBadge(
                  isLlmAvailable ? '可用' : '不可用',
                  isLlmAvailable ? Colors.green : Colors.orange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showUnavailableInfo(BuildContext context, String type, bool isArchNotSupported) {
    String title;
    String message;

    if (type == 'ocr') {
      title = 'Paddle OCR 不可用';
      message = 'Paddle OCR 模型加载失败，请尝试重启 APP。';
    } else {
      title = 'Qwen 3.5 不可用';
      if (isArchNotSupported) {
        message = 'Qwen 3.5 仅支持 arm64-v8a 架构设备。';
      } else {
        message = 'Qwen 3.5 模型加载失败，请尝试重启 APP。';
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    final theme = Theme.of(context);

    return Card(
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
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      leading: Icon(icon, color: colorScheme.primary),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
    );
  }
}
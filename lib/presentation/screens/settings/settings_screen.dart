import 'package:catering_receipt_recorder/core/constants/app_constants.dart';
import 'package:catering_receipt_recorder/data/services/file_service.dart';
import 'package:catering_receipt_recorder/data/services/llm_service.dart';
import 'package:catering_receipt_recorder/presentation/providers/ocr_provider.dart';
import 'package:catering_receipt_recorder/presentation/widgets/common/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// About screen
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final FileService _fileService = FileService();
  Map<String, int> _storageUsage = {};
  bool _isLoading = true;
  LlmService? _llmService;

  @override
  void initState() {
    super.initState();
    _loadStorageUsage();
    _initLlmService();
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

  void _checkUpdate() {
    // TODO: 实现检查更新逻辑
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('当前已是最新版本')),
    );
  }

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
                _buildListTile(
                  context,
                  icon: Icons.image,
                  title: '图片存储',
                  subtitle: _formatSize(_storageUsage['images'] ?? 0),
                ),
                _buildListTile(
                  context,
                  icon: Icons.picture_as_pdf,
                  title: 'PDF存储',
                  subtitle: _formatSize(_storageUsage['pdfs'] ?? 0),
                ),
                _buildListTile(
                  context,
                  icon: Icons.folder,
                  title: '总存储',
                  subtitle: _formatSize(_storageUsage['total'] ?? 0),
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

          // 隐私政策
          _buildSection(
            context,
            '',
            [
              _buildListTile(
                context,
                icon: Icons.privacy_tip_outlined,
                title: '隐私政策',
                subtitle: '数据仅存储在本地设备',
              ),
            ],
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
            '版本 1.0.0',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          // 检查更新按钮
          TextButton.icon(
            onPressed: _checkUpdate,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('检查更新'),
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

  String _formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}

import 'package:catering_receipt_recorder/core/constants/app_constants.dart';
import 'package:catering_receipt_recorder/data/services/file_service.dart';
import 'package:catering_receipt_recorder/data/services/llm_service.dart';
import 'package:catering_receipt_recorder/presentation/providers/ocr_provider.dart';
import 'package:catering_receipt_recorder/presentation/widgets/common/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Settings screen
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ocrState = ref.watch(ocrProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 应用信息
          _buildSection(
            context,
            '应用信息',
            [
              _buildListTile(
                context,
                icon: Icons.info_outline,
                title: '应用名称',
                subtitle: AppConstants.appName,
              ),
              _buildListTile(
                context,
                icon: Icons.verified,
                title: '版本',
                subtitle: '1.0.0',
              ),
            ],
          ),

          const SizedBox(height: 16),

          // OCR模型状态
          _buildSection(
            context,
            'OCR识别',
            [
              _buildListTile(
                context,
                icon: Icons.document_scanner,
                title: 'PaddleOCR 模型',
                subtitle: ocrState.isModelAvailable
                    ? '已加载'
                    : '未加载',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ocrState.isModelAvailable
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    ocrState.isModelAvailable ? '可用' : '不可用',
                    style: TextStyle(
                      color: ocrState.isModelAvailable ? Colors.green : Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  ocrState.isModelAvailable
                      ? 'PaddleOCR模型已加载，可以进行文字识别'
                      : '请将PaddleOCR模型文件放入 assets/models/ 目录',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Divider(indent: 16, endIndent: 16),
              _buildListTile(
                context,
                icon: Icons.psychology,
                title: 'LLM 结构化模型',
                subtitle: _llmService?.isInitialized == true
                    ? '${_llmService!.modelName} (${_llmService!.modelSizeFormatted})'
                    : _llmService?.isLoading == true
                        ? '加载中...'
                        : '未加载',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _llmService?.isInitialized == true
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _llmService?.isInitialized == true ? '可用' : '不可用',
                    style: TextStyle(
                      color: _llmService?.isInitialized == true ? Colors.green : Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  _llmService?.isInitialized == true
                      ? 'LLM模型已加载，可进行智能结构化提取'
                      : '请将Qwen GGUF模型文件放入应用存储目录',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),

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

          // 关于
          _buildSection(
            context,
            '关于',
            [
              _buildListTile(
                context,
                icon: Icons.description_outlined,
                title: '使用说明',
                subtitle: '如何使用本应用',
                onTap: () => _showUsageDialog(context),
              ),
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

  void _showUsageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('使用说明'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('1. 添加订单', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('从首页点击"添加订单"，选择外卖订单截图，使用OCR识别或手动填写信息。'),
              SizedBox(height: 12),
              Text('2. 添加发票', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('从发票页面点击添加，选择发票图片或PDF，关联对应订单。'),
              SizedBox(height: 12),
              Text('3. 数据导出', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('在导出页面选择导出范围和格式，导出Excel或CSV文件。'),
              SizedBox(height: 12),
              Text('4. OCR识别', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('需要将OCR模型文件放入 assets/models/ 目录才能使用OCR功能。'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}
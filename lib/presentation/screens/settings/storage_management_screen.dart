import 'package:flutter/material.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_alert_dialog.dart';
import 'package:go_router/go_router.dart';

import '../../../data/services/file_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/scroll_edge_fog.dart';
import '../../widgets/common/storage_ring_chart.dart';

class StorageManagementScreen extends StatefulWidget {
  const StorageManagementScreen({super.key});

  @override
  State<StorageManagementScreen> createState() =>
      _StorageManagementScreenState();
}

class _StorageManagementScreenState extends State<StorageManagementScreen> {
  final FileService _fileService = FileService();
  Map<String, int> _storageUsage = {};
  bool _isLoading = true;
  bool _isClearingCache = false;

  @override
  void initState() {
    super.initState();
    _loadStorageUsage();
  }

  Future<void> _loadStorageUsage() async {
    setState(() => _isLoading = true);
    try {
      final usage = await _fileService.getStorageUsage();
      if (!mounted) return;
      setState(() {
        _storageUsage = usage;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => GlassAlertDialog(
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

    if (confirmed != true) return;
    setState(() => _isClearingCache = true);
    try {
      final deletedCount = await _fileService.cleanTempFiles();
      await _loadStorageUsage();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已清理 $deletedCount 个临时文件')));
    } finally {
      if (mounted) setState(() => _isClearingCache = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('存储管理')),
      body: ScrollEdgeFog(
        showBottom: false,
        child: RefreshIndicator(
          onRefresh: _loadStorageUsage,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '存储占用',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 320;
                            final chartSize = compact ? 128.0 : 160.0;
                            final chartStrokeWidth = compact ? 14.0 : 16.0;
                            final gap = compact ? 12.0 : 24.0;
                            final chart = StorageRingChart(
                              storageData: _storageUsage,
                              size: chartSize,
                              strokeWidth: chartStrokeWidth,
                            );
                            final legend = StorageLegend(
                              storageData: _storageUsage,
                            );
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                chart,
                                SizedBox(width: gap),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: legend,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              text: '清理数据',
                              onPressed: () =>
                                  context.push('/settings/cleanup'),
                              type: AppButtonType.outlined,
                              foregroundColor: theme.colorScheme.error,
                              borderSide: BorderSide(
                                color: theme.colorScheme.error.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: AppButton(
                              text: _isClearingCache ? '清理中...' : '清理缓存',
                              onPressed: _isClearingCache ? null : _clearCache,
                              type: AppButtonType.outlined,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

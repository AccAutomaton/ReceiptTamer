import 'package:flutter/material.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_alert_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/llm_backend.dart';
import '../../../data/services/file_service.dart';
import '../../../data/services/llm_config_service.dart';
import '../../../data/services/model_asset_service.dart';
import '../../../data/services/openai_compatible_backend.dart';
import '../../providers/ocr_provider.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/scroll_edge_fog.dart';

enum _ModelInstallChoice { importZip, downloadHfMirror, downloadHuggingFace }

class ModelManagementScreen extends ConsumerStatefulWidget {
  const ModelManagementScreen({super.key});

  @override
  ConsumerState<ModelManagementScreen> createState() =>
      _ModelManagementScreenState();
}

class _ModelManagementScreenState extends ConsumerState<ModelManagementScreen> {
  final FileService _fileService = FileService();
  final LlmConfigService _llmConfigService = LlmConfigService();
  final TextEditingController _endpointController = TextEditingController();
  final TextEditingController _cloudModelController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _extraBodyController = TextEditingController();

  late final ModelAssetService _modelAssetService;
  LlmBackendConfig _llmConfig = const LlmBackendConfig();
  ModelAssetStatus? _modelStatus;
  OpenAiModelProvider _selectedProvider = OpenAiModelProvider.xiaomiMimo;
  Map<OpenAiModelProvider, OpenAiCompatibleConfig> _providerConfigs = {};
  List<String> _presetModelOptions = const [];
  String? _presetModelLoadError;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isModelActionRunning = false;
  bool _isLoadingPresetModels = false;

  @override
  void initState() {
    super.initState();
    _modelAssetService = ModelAssetService(
      disposeBeforeDelete: () async {
        await ref.read(ocrServiceProvider).llmService?.dispose();
      },
    );
    _loadState();
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _cloudModelController.dispose();
    _apiKeyController.dispose();
    _extraBodyController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    setState(() => _isLoading = true);
    try {
      final config = await _llmConfigService.load();
      final status = await _modelAssetService.getStatus();
      final normalizedConfig = _normalizeBackendConfig(config, status);
      final provider = _providerForCloudConfig(normalizedConfig.cloud);
      final providerConfigs = _providerConfigsFromConfig(normalizedConfig);
      var cloudConfig = providerConfigs[provider]!;
      if (provider != normalizedConfig.cloud.provider &&
          _hasCloudConfigValues(normalizedConfig.cloud)) {
        cloudConfig = _cloudConfigForProvider(
          normalizedConfig.cloud,
          provider,
          clearModelName: false,
        );
        providerConfigs[provider] = cloudConfig;
      }
      if (normalizedConfig.backendType != config.backendType) {
        await _llmConfigService.save(normalizedConfig);
      }
      if (!mounted) return;
      setState(() {
        _llmConfig = normalizedConfig.copyWith(
          cloud: cloudConfig,
          cloudConfigs: providerConfigs,
        );
        _providerConfigs = providerConfigs;
        _modelStatus = status;
        _selectedProvider = provider;
        _setCloudControllers(cloudConfig);
        _isLoading = false;
      });
      if (provider.usesPreset && cloudConfig.apiKey.trim().isNotEmpty) {
        await _loadPresetModels(showMessage: false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<OpenAiModelProvider, OpenAiCompatibleConfig> _providerConfigsFromConfig(
    LlmBackendConfig config,
  ) {
    return {
      for (final provider in OpenAiModelProvider.values)
        provider: config.cloudConfigForProvider(provider),
    };
  }

  bool _hasCloudConfigValues(OpenAiCompatibleConfig config) {
    return config.endpoint.trim().isNotEmpty ||
        config.modelName.trim().isNotEmpty ||
        config.apiKey.trim().isNotEmpty ||
        config.extraParamsJson.trim().isNotEmpty ||
        config.isMultimodal;
  }

  void _setCloudControllers(OpenAiCompatibleConfig config) {
    _endpointController.text = config.endpoint;
    _cloudModelController.text = config.modelName;
    _apiKeyController.text = config.apiKey;
    _extraBodyController.text = config.extraParamsJson;
  }

  OpenAiModelProvider _providerForCloudConfig(OpenAiCompatibleConfig config) {
    if (config.provider != OpenAiModelProvider.custom) {
      return config.provider;
    }
    final endpoint = config.endpoint.trim().replaceAll(RegExp(r'/+$'), '');
    for (final provider in OpenAiModelProvider.values) {
      if (!provider.usesPreset) continue;
      if (endpoint ==
          provider.presetEndpoint.trim().replaceAll(RegExp(r'/+$'), '')) {
        return provider;
      }
    }
    return OpenAiModelProvider.custom;
  }

  OpenAiCompatibleConfig _cloudConfigForProvider(
    OpenAiCompatibleConfig current,
    OpenAiModelProvider provider, {
    required bool clearModelName,
  }) {
    final modelName = clearModelName ? '' : current.modelName;
    if (!provider.usesPreset) {
      return current.copyWith(
        provider: provider,
        endpoint: clearModelName ? '' : current.endpoint,
        modelName: modelName,
        extraParamsJson: clearModelName ? '' : current.extraParamsJson,
      );
    }
    return current.copyWith(
      provider: provider,
      endpoint: provider.presetEndpoint,
      modelName: modelName,
      extraParamsJson: provider.disabledThinkingExtraBodyJson,
    );
  }

  LlmBackendConfig _normalizeBackendConfig(
    LlmBackendConfig config,
    ModelAssetStatus status,
  ) {
    if (config.backendType == LlmBackendType.localMnn && !status.installed) {
      return config.copyWith(backendType: LlmBackendType.unset);
    }
    if (config.backendType == LlmBackendType.openAiCompatible &&
        !config.cloud.isConfigured) {
      return config.copyWith(backendType: LlmBackendType.unset);
    }
    return config;
  }

  Future<void> _saveConfig(
    LlmBackendConfig config, {
    bool showMessage = true,
  }) async {
    setState(() => _isSaving = true);
    try {
      await _llmConfigService.save(config);
      if (!mounted) return;
      setState(() {
        _llmConfig = config;
        _providerConfigs = _providerConfigsFromConfig(config);
      });
      if (showMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('模型设置已保存')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _toggleBackend(LlmBackendType backendType, bool enabled) async {
    if (enabled) {
      if (backendType == LlmBackendType.localMnn && !_canEnableLocalModel()) {
        return;
      }
      if (backendType == LlmBackendType.openAiCompatible &&
          !_canEnableExternalModel()) {
        return;
      }
    }

    final previousType = _llmConfig.backendType;
    final nextType = enabled
        ? backendType
        : _llmConfig.backendType == backendType
        ? LlmBackendType.unset
        : _llmConfig.backendType;
    final nextConfig = backendType == LlmBackendType.openAiCompatible
        ? _configWithCurrentProvider()
        : _llmConfig;
    await _saveConfig(
      nextConfig.copyWith(backendType: nextType),
      showMessage: false,
    );
    await _syncLocalModelLifecycle(previousType, nextType);
  }

  Future<void> _syncLocalModelLifecycle(
    LlmBackendType previousType,
    LlmBackendType nextType,
  ) async {
    final llmService = ref.read(ocrServiceProvider).llmService;
    if (nextType == LlmBackendType.localMnn) {
      await llmService?.preloadIfConfiguredLocalModel();
      return;
    }
    if (previousType == LlmBackendType.localMnn) {
      await llmService?.dispose();
    }
  }

  Future<void> _saveExternalModel() async {
    final cloudConfig = _currentCloudConfig;
    final backendType =
        _llmConfig.backendType == LlmBackendType.openAiCompatible &&
            !cloudConfig.isConfigured
        ? LlmBackendType.unset
        : _llmConfig.backendType;
    await _saveConfig(
      _configWithCurrentProvider(
        cloudConfig,
      ).copyWith(backendType: backendType),
    );
  }

  Future<void> _toggleCloudMultimodal(bool value) async {
    if (value && _selectedProvider == OpenAiModelProvider.deepSeek) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => GlassAlertDialog(
          title: const Text('Deepseek 多模态提示'),
          content: const Text('Deepseek 目前不支持多模态，继续开启可能导致问题。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('继续开启'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    await _saveConfig(
      _configWithCurrentProvider(
        _currentCloudConfig.copyWith(isMultimodal: value),
      ),
      showMessage: false,
    );
  }

  OpenAiCompatibleConfig get _currentCloudConfig {
    final provider = _selectedProvider;
    final base =
        _providerConfigs[provider] ??
        OpenAiCompatibleConfig.forProvider(provider);
    return base.copyWith(
      provider: provider,
      endpoint: provider.usesPreset
          ? provider.presetEndpoint
          : _endpointController.text.trim(),
      modelName: _cloudModelController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      extraParamsJson: provider.usesPreset
          ? provider.disabledThinkingExtraBodyJson
          : _extraBodyController.text.trim(),
    );
  }

  LlmBackendConfig _configWithCurrentProvider([
    OpenAiCompatibleConfig? cloudConfig,
  ]) {
    final cloud = cloudConfig ?? _currentCloudConfig;
    final configs = Map<OpenAiModelProvider, OpenAiCompatibleConfig>.from(
      _providerConfigs,
    );
    configs[cloud.provider] = cloud;
    return _llmConfig.copyWith(cloud: cloud, cloudConfigs: configs);
  }

  bool _canEnableLocalModel() {
    final status = _modelStatus;
    if (status?.installed != true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先安装本地模型')));
      return false;
    }
    return true;
  }

  bool _canEnableExternalModel() {
    if (!_currentCloudConfig.isConfigured) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先填写模型端点和模型名称')));
      return false;
    }
    return true;
  }

  Future<void> _changeProvider(OpenAiModelProvider provider) async {
    final currentCloud = _currentCloudConfig;
    final providerConfigs =
        Map<OpenAiModelProvider, OpenAiCompatibleConfig>.from(_providerConfigs);
    providerConfigs[_selectedProvider] = currentCloud;
    final nextCloud =
        providerConfigs[provider] ??
        OpenAiCompatibleConfig.forProvider(provider);

    setState(() {
      _selectedProvider = provider;
      _providerConfigs = providerConfigs;
      _llmConfig = _llmConfig.copyWith(
        cloud: nextCloud,
        cloudConfigs: providerConfigs,
      );
      _presetModelOptions = const [];
      _presetModelLoadError = null;
      _setCloudControllers(nextCloud);
    });
    if (provider.usesPreset && nextCloud.apiKey.trim().isNotEmpty) {
      await _loadPresetModels(showMessage: false);
    }
  }

  void _updateCurrentProviderConfig() {
    final cloudConfig = _currentCloudConfig;
    final providerConfigs =
        Map<OpenAiModelProvider, OpenAiCompatibleConfig>.from(_providerConfigs);
    providerConfigs[_selectedProvider] = cloudConfig;
    setState(() {
      _providerConfigs = providerConfigs;
      _llmConfig = _llmConfig.copyWith(
        cloud: cloudConfig,
        cloudConfigs: providerConfigs,
      );
      _presetModelLoadError = null;
    });
  }

  Future<void> _loadPresetModels({bool showMessage = true}) async {
    if (!_selectedProvider.usesPreset) return;
    if (_apiKeyController.text.trim().isEmpty) {
      if (mounted) setState(() => _presetModelLoadError = null);
      return;
    }

    setState(() {
      _isLoadingPresetModels = true;
      _presetModelLoadError = null;
    });
    try {
      final models = await OpenAiCompatibleBackend(
        config: _currentCloudConfig,
      ).listModels();
      if (!mounted) return;
      setState(() {
        _presetModelOptions = models;
        if (!_presetModelOptions.contains(_cloudModelController.text.trim())) {
          _cloudModelController.text = models.first;
        }
      });
      if (showMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('模型列表已更新')));
      }
    } catch (e) {
      if (!mounted) return;
      final message = e is OpenAiCompatibleException
          ? e.message
          : '模型列表获取失败: $e';
      setState(() {
        _presetModelLoadError = message;
      });
      if (showMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_presetModelLoadError!)));
      }
    } finally {
      if (mounted) setState(() => _isLoadingPresetModels = false);
    }
  }

  bool get _canLoadPresetModels =>
      _selectedProvider.usesPreset &&
      _apiKeyController.text.trim().isNotEmpty &&
      !_isLoadingPresetModels;

  String? get _presetModelHelperText {
    if (!_selectedProvider.usesPreset) return null;
    if (_apiKeyController.text.trim().isEmpty) {
      return '填写 API key 后才可获取模型列表';
    }
    return _presetModelLoadError;
  }

  Future<void> _showInstallOptions() async {
    final choice = await showDialog<_ModelInstallChoice>(
      context: context,
      builder: (context) => GlassAlertDialog(
        title: const Text('安装本地模型'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInstallOptionButton(
              icon: Icons.folder_zip_outlined,
              label: '从 ZIP 安装',
              choice: _ModelInstallChoice.importZip,
            ),
            const SizedBox(height: 8),
            _buildInstallOptionButton(
              icon: Icons.download,
              label: '在线下载',
              choice: _ModelInstallChoice.downloadHfMirror,
            ),
            const SizedBox(height: 8),
            _buildInstallOptionButton(
              icon: Icons.cloud_download_outlined,
              label: '在线下载（huggingface.co）',
              choice: _ModelInstallChoice.downloadHuggingFace,
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;

    switch (choice) {
      case _ModelInstallChoice.importZip:
        await _importModelZip();
        break;
      case _ModelInstallChoice.downloadHfMirror:
        await _showModelDownloadDialog(
          repositoryUrl: ModelAssetService.hfMirrorRepositoryUrl,
          sourceLabel: 'hf-mirror.com',
        );
        break;
      case _ModelInstallChoice.downloadHuggingFace:
        await _showModelDownloadDialog(
          repositoryUrl: ModelAssetService.huggingFaceRepositoryUrl,
          sourceLabel: 'huggingface.co',
        );
        break;
    }
  }

  Widget _buildInstallOptionButton({
    required IconData icon,
    required String label,
    required _ModelInstallChoice choice,
  }) {
    final effectiveLabel = switch (choice) {
      _ModelInstallChoice.downloadHfMirror => '在线下载（hf-mirror.com）',
      _ModelInstallChoice.downloadHuggingFace => '在线下载（huggingface.co）',
      _ => label,
    };
    return OutlinedButton.icon(
      onPressed: () => Navigator.pop(context, choice),
      icon: Icon(icon),
      label: Text(effectiveLabel),
    );
  }

  Future<void> _showModelDownloadDialog({
    required Uri repositoryUrl,
    required String sourceLabel,
  }) async {
    setState(() => _isModelActionRunning = true);
    final existingSize = await _modelAssetService.getExistingDownloadSize();
    ModelDownloadProgress? progressInfo;
    void Function(void Function())? dialogSetState;
    var dialogShown = false;
    var cancelRequested = false;

    if (mounted) {
      dialogShown = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            dialogSetState = setDialogState;
            final resumed = progressInfo?.wasResumed ?? existingSize > 0;
            final progress = progressInfo?.progress;
            final currentFileText = progressInfo == null
                ? '下载源：$sourceLabel'
                : '下载源：$sourceLabel\n正在下载第 ${progressInfo!.fileIndex} / ${progressInfo!.fileCount} 个模型文件：${progressInfo!.fileName}';
            return GlassAlertDialog(
              title: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(resumed ? '继续下载模型' : '正在下载模型')),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 16),
                  Text(
                    currentFileText,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    progress == null
                        ? '准备下载...'
                        : '${(progress * 100).clamp(0, 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (progressInfo != null) ...[
                    Text(
                      '${_fileService.formatFileSize(progressInfo!.downloadedBytes)} / '
                      '${_fileService.formatFileSize(progressInfo!.totalBytes)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '下载速度: ${_fileService.formatFileSize(progressInfo!.speedBytesPerSecond)}/s',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ] else if (existingSize > 0)
                    Text(
                      '已保留部分下载: ${_fileService.formatFileSize(existingSize)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: cancelRequested
                      ? null
                      : () {
                          setDialogState(() => cancelRequested = true);
                        },
                  child: Text(cancelRequested ? '正在取消...' : '取消'),
                ),
              ],
            );
          },
        ),
      );
    }

    try {
      await _modelAssetService.downloadDefaultModel(
        resume: true,
        repositoryUrl: repositoryUrl,
        shouldCancel: () => cancelRequested,
        onProgress: (progress) {
          if (!mounted || dialogSetState == null) return;
          dialogSetState!(() => progressInfo = progress);
        },
      );
      if (!mounted) return;
      if (dialogShown) Navigator.of(context, rootNavigator: true).pop();
      await _loadState();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('本地模型已安装')));
    } on ModelDownloadCancelledException {
      if (!mounted) return;
      if (dialogShown) Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('下载已取消，已下载部分会保留')));
    } catch (e) {
      if (!mounted) return;
      if (dialogShown) Navigator.of(context, rootNavigator: true).pop();
      final retry = await showDialog<bool>(
        context: context,
        builder: (context) => GlassAlertDialog(
          title: const Text('下载失败'),
          content: Text('模型下载失败: $e\n\n已下载的部分会保留，重试时将从断点继续。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('重试'),
            ),
          ],
        ),
      );
      if (retry == true && mounted) {
        await _showModelDownloadDialog(
          repositoryUrl: repositoryUrl,
          sourceLabel: sourceLabel,
        );
      }
    } finally {
      if (mounted) setState(() => _isModelActionRunning = false);
    }
  }

  Future<void> _importModelZip() async {
    setState(() => _isModelActionRunning = true);
    try {
      await _modelAssetService.importZip();
      await _loadState();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('本地模型已安装')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('模型安装失败: $e')));
    } finally {
      if (mounted) setState(() => _isModelActionRunning = false);
    }
  }

  Future<void> _deleteDownloadedModel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => GlassAlertDialog(
        title: const Text('删除本地模型'),
        content: const Text('将删除已下载或导入的本地 MNN 模型，不会删除订单和发票数据。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isModelActionRunning = true);
    try {
      await _modelAssetService.deleteDownloadedModel();
      if (_llmConfig.backendType == LlmBackendType.localMnn) {
        await _saveConfig(
          _llmConfig.copyWith(backendType: LlmBackendType.unset),
          showMessage: false,
        );
      }
      await _loadState();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('本地模型已删除')));
    } finally {
      if (mounted) setState(() => _isModelActionRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('模型管理')),
      body: ScrollEdgeFog(
        showBottom: false,
        child: RefreshIndicator(
          onRefresh: _loadState,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildLocalModelCard(),
              const SizedBox(height: 16),
              _buildExternalModelCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocalModelCard() {
    final status = _modelStatus;
    final installed = status?.installed == true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(
              icon: Icons.memory,
              title: '本地模型',
              enabled: _llmConfig.backendType == LlmBackendType.localMnn,
              onEnabledChanged: _isSaving
                  ? null
                  : (value) => _toggleBackend(LlmBackendType.localMnn, value),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  _buildStatusBadge(status),
                const SizedBox(width: 10),
                Expanded(child: Text(_statusDescription(status))),
              ],
            ),
            const SizedBox(height: 14),
            _buildInfoRow('模型名称', _llmConfig.local.modelName),
            const SizedBox(height: 8),
            _buildInfoRow('安装状态', _statusLabel(status)),
            const SizedBox(height: 8),
            _buildInfoRow(
              '占用空间',
              (status?.sizeBytes ?? 0) > 0
                  ? _fileService.formatFileSize(status!.sizeBytes)
                  : '0 B',
            ),
            const SizedBox(height: 16),
            if (!installed)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isModelActionRunning ? null : _showInstallOptions,
                  icon: _isModelActionRunning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.install_mobile),
                  label: const Text('安装'),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isModelActionRunning
                          ? null
                          : _showInstallOptions,
                      icon: const Icon(Icons.download),
                      label: const Text('重新安装'),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isModelActionRunning
                          ? null
                          : _deleteDownloadedModel,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('删除'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExternalModelCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(
              icon: Icons.cloud_outlined,
              title: '外部模型',
              enabled:
                  _llmConfig.backendType == LlmBackendType.openAiCompatible,
              onEnabledChanged: _isSaving
                  ? null
                  : (value) =>
                        _toggleBackend(LlmBackendType.openAiCompatible, value),
            ),
            const SizedBox(height: 16),
            AppSelectField<OpenAiModelProvider>(
              key: ValueKey('provider-${_selectedProvider.name}'),
              label: '模型提供商',
              value: _selectedProvider,
              options: OpenAiModelProvider.values,
              displayValue: (provider) => provider.displayName,
              onChanged: _isSaving
                  ? null
                  : (provider) {
                      if (provider != null) _changeProvider(provider);
                    },
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _endpointController,
              label: '模型端点',
              hint: _selectedProvider.usesPreset
                  ? _selectedProvider.presetEndpoint
                  : 'https://openai.example.com/v1',
              prefixIcon: const Icon(Icons.link),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.none,
              enabled: !_selectedProvider.usesPreset,
            ),
            const SizedBox(height: 12),
            _buildCloudModelField(),
            const SizedBox(height: 12),
            AppTextField(
              controller: _apiKeyController,
              label: 'API key',
              hint: 'sk-example',
              obscureText: true,
              prefixIcon: const Icon(Icons.key),
              keyboardType: TextInputType.visiblePassword,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.none,
              autocorrect: false,
              enableSuggestions: false,
              manualPasteContextMenu: true,
              onChanged: (_) => _updateCurrentProviderConfig(),
              onSubmitted: (_) => _loadPresetModels(),
            ),
            if (_selectedProvider.usesPreset) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _canLoadPresetModels
                      ? () => _loadPresetModels()
                      : null,
                  icon: _isLoadingPresetModels
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: const Text('获取模型列表'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            AppTextField(
              controller: _extraBodyController,
              label: 'extra_body',
              hint: _selectedProvider.usesPreset
                  ? _selectedProvider.disabledThinkingExtraBodyJson
                  : 'e.g. {"thinking":{"type":"disabled"}}',
              helperText: _selectedProvider.usesPreset
                  ? null
                  : '如您不明白该参数的作用，请不要填写',
              prefixIcon: const Icon(Icons.data_object),
              textCapitalization: TextCapitalization.none,
              enabled: !_selectedProvider.usesPreset,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _llmConfig.cloud.isMultimodal,
              onChanged: _isSaving ? null : _toggleCloudMultimodal,
              title: const Text('多模态模型'),
              subtitle: const Text('开启后，将直接使用外部模型处理图片'),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _saveExternalModel,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloudModelField() {
    if (!_selectedProvider.usesPreset) {
      return AppTextField(
        controller: _cloudModelController,
        label: '模型名称',
        hint: 'model/name',
        prefixIcon: const Icon(Icons.smart_toy_outlined),
        textInputAction: TextInputAction.next,
        textCapitalization: TextCapitalization.none,
      );
    }

    final selectedModel = _cloudModelController.text.trim();
    final options = <String>[
      if (selectedModel.isNotEmpty &&
          !(_presetModelOptions.contains(selectedModel)))
        selectedModel,
      ..._presetModelOptions,
    ];

    return AppSelectField<String>(
      key: ValueKey(
        'preset-model-${_selectedProvider.name}-$selectedModel-${options.join('|')}',
      ),
      label: '模型名称',
      hint: _isLoadingPresetModels ? '正在获取模型列表...' : '请先获取模型列表',
      value: options.contains(selectedModel) ? selectedModel : null,
      options: options,
      displayValue: (model) => model,
      helperText: _selectedProvider.usesPreset ? _presetModelHelperText : null,
      enabled: options.isNotEmpty && !_isLoadingPresetModels,
      onChanged: (model) {
        if (model == null) return;
        setState(() {
          _cloudModelController.text = model;
          final cloudConfig = _currentCloudConfig;
          final providerConfigs =
              Map<OpenAiModelProvider, OpenAiCompatibleConfig>.from(
                _providerConfigs,
              );
          providerConfigs[_selectedProvider] = cloudConfig;
          _providerConfigs = providerConfigs;
          _llmConfig = _llmConfig.copyWith(
            cloud: cloudConfig,
            cloudConfigs: providerConfigs,
          );
        });
      },
    );
  }

  Widget _buildCardHeader({
    required IconData icon,
    required String title,
    required bool enabled,
    required ValueChanged<bool>? onEnabledChanged,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, color: colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Switch.adaptive(value: enabled, onChanged: onEnabledChanged),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Text(value, style: theme.textTheme.bodySmall)),
      ],
    );
  }

  Widget _buildStatusBadge(ModelAssetStatus? status) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = _statusLabel(status);
    final color = switch (status?.state) {
      ModelAssetState.installed => Colors.green,
      ModelAssetState.invalid => colorScheme.error,
      ModelAssetState.downloading => colorScheme.primary,
      _ => colorScheme.onSurfaceVariant,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _statusLabel(ModelAssetStatus? status) {
    return switch (status?.state) {
      ModelAssetState.installed => '已安装',
      ModelAssetState.invalid => '需修复',
      ModelAssetState.downloading => '下载中',
      _ => '未安装',
    };
  }

  String _statusDescription(ModelAssetStatus? status) {
    if (_isLoading) return '正在检查本地模型状态...';
    if (status == null) return '无法读取本地模型状态。';
    return switch (status.state) {
      ModelAssetState.installed => '模型文件完整，可用于本地 AI 分析。',
      ModelAssetState.invalid => status.errorMessage ?? '模型文件不完整，请重新安装。',
      ModelAssetState.downloading => '模型正在下载中。',
      ModelAssetState.missing => '尚未安装本地模型，可在线下载或导入本地 ZIP。',
    };
  }
}

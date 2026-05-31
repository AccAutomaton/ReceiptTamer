import 'package:flutter/services.dart';

import '../../core/services/log_config.dart';
import '../../core/services/log_service.dart';
import '../models/llm_backend.dart';
import '../models/ocr_result.dart';
import '../models/ocr_text_block.dart';
import 'llm_config_service.dart';
import 'llm_prompt_service.dart';
import 'model_asset_service.dart';
import 'openai_compatible_backend.dart';

/// Routes structured extraction to either local MNN or an OpenAI-compatible
/// cloud model, based on the user's settings.
class LlmService {
  static const MethodChannel _channel = MethodChannel(
    'com.acautomaton.receipt.tamer/llm',
  );

  static const String _modelPath = ModelAssetService.modelDirName;
  static const Duration _statusPollInterval = Duration(milliseconds: 500);
  static const int _staleNativeLoadMaxPolls = 240;

  final LlmConfigService _configService;

  bool _isInitialized = false;
  bool _isLoading = false;
  bool _isModelLoading = false;
  bool _archNotSupported = false;
  String? _loadError;
  int _modelSizeBytes = 0;
  int _loadGeneration = 0;
  int? _wantedLoadGeneration;

  LlmService({LlmConfigService? configService})
    : _configService = configService ?? LlmConfigService();

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  bool get isModelLoading => _isModelLoading;
  bool get archNotSupported => _archNotSupported;
  String? get loadError => _loadError;
  String get modelName => 'Qwen3.5-0.8B-MNN-Text-Only';
  int get modelSizeBytes => _modelSizeBytes;

  String get modelSizeFormatted {
    if (_modelSizeBytes == 0) return '未安装';
    if (_modelSizeBytes < 1024) return '$_modelSizeBytes B';
    if (_modelSizeBytes < 1024 * 1024) {
      return '${(_modelSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(_modelSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<bool> preloadIfConfiguredLocalModel() async {
    final config = await _configService.load();
    if (config.backendType != LlmBackendType.localMnn) {
      return false;
    }
    logService.i(LogConfig.moduleLlm, '检测到本地模型配置，启动预加载');
    return initialize();
  }

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    if (_isLoading) return true;

    final generation = ++_loadGeneration;
    _wantedLoadGeneration = generation;
    _isLoading = true;
    _isModelLoading = true;
    _archNotSupported = false;
    _loadError = null;
    _initializeInBackground(generation);
    return true;
  }

  void _initializeInBackground(int generation) {
    Future(() async {
      try {
        logService.i(LogConfig.moduleLlm, '正在初始化本地 MNN LLM...');
        final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
          'initialize',
          {'modelPath': _modelPath},
        );
        if (!_isCurrentLoad(generation)) {
          await _disposeStaleNativeLoad();
          return;
        }
        _applyStatus(Map<String, dynamic>.from(result ?? {}));

        if (_archNotSupported || _loadError != null) {
          _isLoading = false;
          _isModelLoading = false;
          return;
        }
        if (_isModelLoading) {
          await _pollForLoadingComplete(generation);
        }
      } catch (e, stackTrace) {
        if (!_isCurrentLoad(generation)) {
          await _disposeStaleNativeLoad();
          return;
        }
        logService.e(LogConfig.moduleLlm, '本地 LLM 初始化失败', e, stackTrace);
        _loadError = e.toString();
        _isLoading = false;
        _isModelLoading = false;
      }
    });
  }

  bool _isCurrentLoad(int generation) =>
      generation == _loadGeneration && _wantedLoadGeneration == generation;

  Future<void> _pollForLoadingComplete(int generation) async {
    while (true) {
      await Future.delayed(_statusPollInterval);
      if (!_isCurrentLoad(generation)) {
        await _disposeStaleNativeLoad();
        return;
      }
      final status = await _readNativeStatus(apply: false);
      if (!_isCurrentLoad(generation)) {
        await _disposeStaleNativeLoad();
        return;
      }
      _applyStatus(status);
      if (_isInitialized || _archNotSupported || _loadError != null) break;
      if (status['isLoading'] != true) break;
    }
    if (!_isCurrentLoad(generation)) {
      await _disposeStaleNativeLoad();
      return;
    }
    _isLoading = false;
    _isModelLoading = false;
  }

  Future<void> _disposeStaleNativeLoad() async {
    logService.i(LogConfig.moduleLlm, '本地 LLM 加载已取消，准备释放 Native 资源');
    for (var i = 0; i < _staleNativeLoadMaxPolls; i++) {
      final status = await _readNativeStatus(apply: false);
      if (status['isLoading'] != true) break;
      await Future.delayed(_statusPollInterval);
    }
    if (_wantedLoadGeneration == null) {
      await _disposeNativeLlm();
    }
  }

  Future<bool> waitForInitialization({
    Duration timeout = const Duration(seconds: 120),
  }) async {
    if (_isInitialized) return true;
    if (_archNotSupported) return false;

    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final status = await getStatus();
      if (status['isInitialized'] == true) return true;
      if (status['archNotSupported'] == true || status['error'] != null) {
        return false;
      }
      if (status['isLoading'] != true) break;
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return _isInitialized;
  }

  Future<Map<String, dynamic>> getStatus() async {
    return _readNativeStatus();
  }

  Future<Map<String, dynamic>> _readNativeStatus({bool apply = true}) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getStatus',
      );
      final status = Map<String, dynamic>.from(result ?? {});
      if (apply) _applyStatus(status);
      return status;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleLlm, '获取 LLM 状态失败', e, stackTrace);
      return {};
    }
  }

  Future<OcrResult> extractStructuredData(
    OcrRawResult ocrResult,
    OcrType type,
  ) async {
    if (!ocrResult.success) {
      return OcrResult.failure(
        errorMessage: ocrResult.errorMessage ?? 'OCR 识别失败',
        type: type,
      );
    }
    return extractStructuredDataFromText(ocrResult.fullText, type);
  }

  Future<OcrResult> extractStructuredDataFromText(
    String text,
    OcrType type,
  ) async {
    final config = await _configService.load();
    if (!config.isConfigured) {
      return OcrResult.failure(errorMessage: '请先在设置中选择 AI 分析方式', type: type);
    }

    final prompt = LlmPromptBuilder.buildTextPrompt(type, text);
    try {
      final completion = switch (config.backendType) {
        LlmBackendType.localMnn => await _completeLocal(prompt),
        LlmBackendType.openAiCompatible => await OpenAiCompatibleBackend(
          config: config.cloud,
        ).complete(LlmRequest.text(prompt: prompt, type: type)),
        LlmBackendType.unset => throw StateError('LLM backend is unset'),
      };
      return LlmResultParser.parse(completion.text, type);
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleLlm, 'LLM 提取失败', e, stackTrace);
      return OcrResult.failure(errorMessage: 'LLM 提取失败: $e', type: type);
    }
  }

  Future<OcrResult> extractStructuredDataFromImage({
    required Uint8List imageBytes,
    required String mimeType,
    required OcrType type,
  }) async {
    final config = await _configService.load();
    if (config.backendType != LlmBackendType.openAiCompatible ||
        !config.cloud.isConfigured ||
        !config.cloud.isMultimodal) {
      return OcrResult.failure(errorMessage: '当前 AI 模型未启用图片直传', type: type);
    }

    try {
      final completion = await OpenAiCompatibleBackend(config: config.cloud)
          .complete(
            LlmRequest.image(
              prompt: LlmPromptBuilder.buildImagePrompt(type),
              imageBytes: imageBytes,
              mimeType: mimeType,
              type: type,
            ),
          );
      return LlmResultParser.parse(completion.text, type);
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleLlm, '多模态云端提取失败', e, stackTrace);
      return OcrResult.failure(errorMessage: '云端图片识别失败: $e', type: type);
    }
  }

  Future<LlmCompletion> _completeLocal(String prompt) async {
    if (!_isInitialized) {
      await initialize();
      final loaded = await waitForInitialization();
      if (!loaded) {
        throw StateError(_loadError ?? '本地模型未加载');
      }
    }

    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'generate',
      {'prompt': prompt, 'maxTokens': 256, 'temperature': 0.0, 'topP': 1.0},
    );
    final map = Map<String, dynamic>.from(result ?? {});
    if (map['success'] != true) {
      throw StateError(map['error'] as String? ?? '本地模型生成失败');
    }
    return LlmCompletion(text: map['result'] as String? ?? '');
  }

  void _applyStatus(Map<String, dynamic> status) {
    _isInitialized = status['isInitialized'] ?? _isInitialized;
    _isModelLoading = status['isLoading'] ?? false;
    _archNotSupported = status['archNotSupported'] ?? false;
    _loadError = status['error'] as String?;
    _modelSizeBytes =
        (status['modelSizeBytes'] as num?)?.toInt() ?? _modelSizeBytes;
  }

  Future<void> dispose() async {
    logService.i(LogConfig.moduleLlm, '释放 LLM 服务资源...');
    _loadGeneration++;
    _wantedLoadGeneration = null;
    await _disposeNativeLlm();
    _isInitialized = false;
    _isModelLoading = false;
    _isLoading = false;
    _archNotSupported = false;
    _loadError = null;
  }

  Future<void> _disposeNativeLlm() async {
    try {
      await _channel.invokeMethod('disposeLlm');
    } catch (e) {
      logService.w(LogConfig.moduleLlm, '释放 Native LLM 资源时出错: $e');
    }
  }

  Map<String, dynamic> getModelInfo() {
    return {
      'isInitialized': _isInitialized,
      'isLoading': _isLoading,
      'isModelLoading': _isModelLoading,
      'archNotSupported': _archNotSupported,
      'loadError': _loadError,
      'modelName': modelName,
      'modelSize': modelSizeFormatted,
      'modelSizeBytes': _modelSizeBytes,
      'modelPath': _modelPath,
      'enabled': true,
    };
  }
}

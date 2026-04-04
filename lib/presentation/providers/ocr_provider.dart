import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/log_service.dart';
import '../../core/services/log_config.dart';
import '../../data/models/ocr_result.dart';
import '../../data/models/ocr_text_block.dart';
import '../../data/services/llm_service.dart';
import '../../data/services/ocr_service.dart';
import '../../data/services/pdf_service.dart';

/// OCR processing stage
enum OcrStage {
  idle,
  ocrRecognizing,  // OCR text recognition phase
  llmParsing,      // LLM structured extraction phase
}

/// OCR state
class OcrState {
  final OcrResult? result;
  final bool isLoading;
  final bool isInitialized;
  final bool isModelAvailable;
  final bool isModelLoading;
  final bool archNotSupported;
  final String? errorMessage;
  final LlmService? llmService;
  final OcrStage stage;
  final double progress;

  const OcrState({
    this.result,
    this.isLoading = false,
    this.isInitialized = false,
    this.isModelAvailable = false,
    this.isModelLoading = false,
    this.archNotSupported = false,
    this.errorMessage,
    this.llmService,
    this.stage = OcrStage.idle,
    this.progress = 0.0,
  });

  OcrState copyWith({
    OcrResult? result,
    bool? isLoading,
    bool? isInitialized,
    bool? isModelAvailable,
    bool? isModelLoading,
    bool? archNotSupported,
    String? errorMessage,
    LlmService? llmService,
    OcrStage? stage,
    double? progress,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return OcrState(
      result: clearResult ? null : (result ?? this.result),
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
      isModelAvailable: isModelAvailable ?? this.isModelAvailable,
      isModelLoading: isModelLoading ?? this.isModelLoading,
      archNotSupported: archNotSupported ?? this.archNotSupported,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      llmService: llmService ?? this.llmService,
      stage: stage ?? this.stage,
      progress: progress ?? this.progress,
    );
  }
}

/// OCR state notifier (Riverpod 3.x Notifier)
class OcrNotifier extends Notifier<OcrState> {
  // Progress animation settings
  static const int _ocrDurationMs = 4000; // 4 seconds for OCR phase
  static const int _llmDurationMs = 15000; // 15 seconds for LLM phase
  static const int _progressUpdateIntervalMs = 100; // Update every 100ms

  // OCR phase: 0% to 21% (4/19 ≈ 21%)
  // LLM phase: 21% to 100%
  static const double _ocrEndProgress = 0.21;

  Timer? _progressTimer;

  @override
  OcrState build() {
    // 不在build()中自动初始化，避免阻塞UI
    // OCR会在用户需要识别时按需初始化
    ref.onDispose(() {
      _progressTimer?.cancel();
    });
    return const OcrState();
  }

  OcrService get _service => ref.watch(ocrServiceProvider);

  /// Start progress animation for a given stage
  void _startProgressAnimation(OcrStage stage, Duration totalDuration) {
    _progressTimer?.cancel();

    final startTime = DateTime.now();
    final startProgress = stage == OcrStage.ocrRecognizing ? 0.0 : _ocrEndProgress;
    final endProgress = stage == OcrStage.ocrRecognizing ? _ocrEndProgress : 1.0;

    _progressTimer = Timer.periodic(
      const Duration(milliseconds: _progressUpdateIntervalMs),
      (timer) {
        final elapsed = DateTime.now().difference(startTime);
        final progress = elapsed.inMilliseconds / totalDuration.inMilliseconds;

        if (progress >= 1.0) {
          // Cap at end progress but don't complete yet
          state = state.copyWith(
            stage: stage,
            progress: endProgress,
          );
          timer.cancel();
        } else {
          final currentProgress = startProgress + (endProgress - startProgress) * progress;
          state = state.copyWith(
            stage: stage,
            progress: currentProgress,
          );
        }
      },
    );
  }

  /// Stop progress animation
  void _stopProgressAnimation() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  /// Cancel ongoing recognition
  void cancelRecognition() {
    logService.i(LogConfig.moduleOcr, '取消识别');
    _stopProgressAnimation();
    state = state.copyWith(
      isLoading: false,
      stage: OcrStage.idle,
      progress: 0.0,
      clearResult: true,
    );
  }

  /// Initialize the OCR service (async, non-blocking)
  Future<void> initialize() async {
    state = state.copyWith(isModelLoading: true);

    // 启动后台初始化（不等待）
    _service.initialize();

    // 轮询检查初始化状态
    _watchInitializationStatus();
  }

  /// 轮询检查初始化状态，完成后更新 state
  void _watchInitializationStatus() {
    Future(() async {
      try {
        logService.d(LogConfig.moduleOcr, '开始监听初始化状态...');

        // 等待 OCR 服务初始化完成
        while (_service.isModelLoading && !_service.isModelAvailable) {
          logService.d(LogConfig.moduleOcr, '等待中... isModelLoading=${_service.isModelLoading}, isModelAvailable=${_service.isModelAvailable}');
          await Future.delayed(const Duration(milliseconds: 200));
        }

        logService.i(LogConfig.moduleOcr, 'OCR初始化完成，更新状态: isModelAvailable=${_service.isModelAvailable}, isModelLoading=${_service.isModelLoading}');

        // 更新状态
        state = state.copyWith(
          isInitialized: _service.isModelAvailable,
          isModelAvailable: _service.isModelAvailable,
          isModelLoading: _service.isModelLoading || (_service.llmService?.isModelLoading ?? false),
          archNotSupported: _service.archNotSupported,
          llmService: _service.llmService,
        );

        logService.d(LogConfig.moduleOcr, '状态已更新: state.isModelLoading=${state.isModelLoading}, state.isModelAvailable=${state.isModelAvailable}');

        // 如果 LLM 还在加载，继续监听
        if (_service.llmService?.isModelLoading == true) {
          logService.d(LogConfig.moduleOcr, 'LLM仍在加载，启动监听...');
          _watchModelLoading();
        }
      } catch (e) {
        logService.e(LogConfig.moduleOcr, '监听初始化状态出错', e);
        state = state.copyWith(
          isInitialized: false,
          isModelAvailable: false,
          isModelLoading: false,
          errorMessage: '初始化 OCR 失败: ${e.toString()}',
        );
      }
    });
  }

  /// Watch model loading status and update state when done
  /// 使用轮询方式检查状态，避免阻塞主线程
  void _watchModelLoading() {
    Future(() async {
      try {
        final llmService = _service.llmService;
        if (llmService == null) {
          logService.w(LogConfig.moduleOcr, 'LLM服务为空，跳过监听');
          state = state.copyWith(isModelLoading: false);
          return;
        }

        logService.d(LogConfig.moduleOcr, '开始监听LLM加载状态...');

        // 轮询检查模型加载状态，每200ms检查一次
        while (llmService.isModelLoading) {
          await Future.delayed(const Duration(milliseconds: 200));
          logService.d(LogConfig.moduleOcr, 'LLM加载中... isModelLoading=${llmService.isModelLoading}, isInitialized=${llmService.isInitialized}');
          if (!llmService.isModelLoading) break;
        }

        logService.i(LogConfig.moduleOcr, 'LLM加载完成，更新状态: isInitialized=${llmService.isInitialized}');

        // 更新状态
        state = state.copyWith(
          isModelLoading: false,
          isModelAvailable: _service.isModelAvailable && llmService.isInitialized,
          archNotSupported: llmService.archNotSupported,
        );

        logService.d(LogConfig.moduleOcr, '最终状态: isModelLoading=${state.isModelLoading}, isModelAvailable=${state.isModelAvailable}');
      } catch (e) {
        logService.e(LogConfig.moduleOcr, '监听LLM加载出错', e);
        state = state.copyWith(
          isModelLoading: false,
          errorMessage: '模型加载失败: ${e.toString()}',
        );
      }
    });
  }

  /// Wait for model initialization to complete
  /// Returns true if model is available
  Future<bool> waitForModel() async {
    return _service.waitForInitialization();
  }

  /// 轮询等待模型加载完成（不阻塞主线程）
  Future<bool> _pollWaitForModel() async {
    // 等待 OCR 服务初始化
    while (_service.isModelLoading) {
      await Future.delayed(const Duration(milliseconds: 200));
    }

    // 等待 LLM 初始化
    final llmService = _service.llmService;
    if (llmService != null) {
      while (llmService.isModelLoading) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    return _service.isModelAvailable;
  }

  /// Recognize text from an order image path with progress
  Future<OcrResult?> recognizeOrderWithProgress(String imagePath) async {
    final totalStopwatch = Stopwatch()..start();
    logService.i(LogConfig.moduleOcr, '========== OCR Pipeline 开始 (Order) ==========');
    logService.diag(LogConfig.moduleOcr, 'ImagePath', imagePath);

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      clearResult: true,
      stage: OcrStage.idle,
      progress: 0.0,
    );

    try {
      // 确保OCR服务已初始化
      if (!_service.isModelAvailable) {
        logService.i(LogConfig.moduleOcr, 'OCR模型未初始化，开始初始化...');
        await _service.initialize();
        // 更新状态
        state = state.copyWith(
          isInitialized: _service.isModelAvailable,
          isModelAvailable: _service.isModelAvailable,
          isModelLoading: _service.isModelLoading,
          archNotSupported: _service.archNotSupported,
          llmService: _service.llmService,
        );
      }

      // Wait for model if loading (使用轮询，不阻塞主线程)
      await _pollWaitForModel();

      final llmService = _service.llmService;

      // Check architecture support
      if (llmService?.archNotSupported == true) {
        state = state.copyWith(
          isLoading: false,
          stage: OcrStage.idle,
          errorMessage: 'OCR功能仅支持 arm64-v8a 架构设备',
        );
        return OcrResult.failure(
          errorMessage: 'OCR功能仅支持 arm64-v8a 架构设备',
          type: OcrType.order,
        );
      }

      if (!_service.isModelAvailable) {
        state = state.copyWith(
          isLoading: false,
          stage: OcrStage.idle,
          errorMessage: 'OCR模型未加载',
        );
        return OcrResult.failure(
          errorMessage: 'OCR模型未加载',
          type: OcrType.order,
        );
      }

      // Read image bytes
      final file = File(imagePath);
      if (!await file.exists()) {
        logService.w(LogConfig.moduleOcr, '图片文件不存在: $imagePath');
        state = state.copyWith(
          isLoading: false,
          stage: OcrStage.idle,
          errorMessage: '图片文件不存在',
        );
        return OcrResult.failure(
          errorMessage: '图片文件不存在',
          type: OcrType.order,
        );
      }
      final bytes = await file.readAsBytes();
      logService.diag(LogConfig.moduleOcr, 'Image size', '${bytes.length} bytes');

      // Phase 1: OCR recognition
      logService.d(LogConfig.moduleOcr, 'Phase 1: OCR 识别...');
      _startProgressAnimation(OcrStage.ocrRecognizing, const Duration(milliseconds: _ocrDurationMs));

      final ocrStopwatch = Stopwatch()..start();
      final rawResult = await _service.recognizeRaw(bytes);
      ocrStopwatch.stop();
      logService.diag(LogConfig.moduleOcr, 'OCR recognition time', '${ocrStopwatch.elapsedMilliseconds}ms');
      logService.diag(LogConfig.moduleOcr, 'OCR text blocks', rawResult.textBlocks.length);

      _stopProgressAnimation();

      if (!rawResult.success) {
        logService.w(LogConfig.moduleOcr, 'OCR 识别失败: ${rawResult.errorMessage}');
        state = state.copyWith(
          isLoading: false,
          stage: OcrStage.idle,
          errorMessage: rawResult.errorMessage ?? 'OCR识别失败',
        );
        return OcrResult.failure(
          errorMessage: rawResult.errorMessage ?? 'OCR识别失败',
          type: OcrType.order,
        );
      }

      // Phase 2: LLM parsing
      if (llmService != null && llmService.isInitialized) {
        logService.d(LogConfig.moduleOcr, 'Phase 2: LLM 结构化提取...');
        _startProgressAnimation(OcrStage.llmParsing, const Duration(milliseconds: _llmDurationMs));

        final llmStopwatch = Stopwatch()..start();
        final llmResult = await llmService.extractStructuredData(rawResult, OcrType.order);
        llmStopwatch.stop();
        logService.diag(LogConfig.moduleOcr, 'LLM extraction time', '${llmStopwatch.elapsedMilliseconds}ms');

        _stopProgressAnimation();

        totalStopwatch.stop();
        logService.diag(LogConfig.moduleOcr, 'Total pipeline time', '${totalStopwatch.elapsedMilliseconds}ms');
        logService.i(LogConfig.moduleOcr, '========== OCR Pipeline 完成 (Order) ==========');

        state = state.copyWith(
          result: llmResult,
          isLoading: false,
          stage: OcrStage.idle,
          progress: 1.0,
        );
        return llmResult;
      } else {
        // LLM not available
        logService.w(LogConfig.moduleOcr, 'LLM 未初始化');
        state = state.copyWith(
          isLoading: false,
          stage: OcrStage.idle,
          errorMessage: 'LLM未初始化，无法进行结构化提取',
        );
        return OcrResult.failure(
          errorMessage: 'LLM未初始化，无法进行结构化提取',
          type: OcrType.order,
        );
      }
    } catch (e, stackTrace) {
      _stopProgressAnimation();
      logService.e(LogConfig.moduleOcr, 'OCR Pipeline 异常', e, stackTrace);
      state = state.copyWith(
        isLoading: false,
        stage: OcrStage.idle,
        errorMessage: 'OCR识别失败: ${e.toString()}',
      );
      return OcrResult.failure(
        errorMessage: 'OCR识别失败: ${e.toString()}',
        type: OcrType.order,
      );
    }
  }

  /// Recognize text from an order image path (without progress)
  Future<void> recognizeOrder(String imagePath) async {
    await recognizeOrderWithProgress(imagePath);
  }

  /// Recognize text from an invoice image path with progress
  Future<OcrResult?> recognizeInvoiceWithProgress(String imagePath) async {
    final totalStopwatch = Stopwatch()..start();
    logService.i(LogConfig.moduleOcr, '========== OCR Pipeline 开始 (Invoice) ==========');
    logService.diag(LogConfig.moduleOcr, 'ImagePath', imagePath);

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      clearResult: true,
      stage: OcrStage.idle,
      progress: 0.0,
    );

    try {
      // 确保OCR服务已初始化
      if (!_service.isModelAvailable) {
        logService.i(LogConfig.moduleOcr, 'OCR模型未初始化，开始初始化...');
        await _service.initialize();
        // 更新状态
        state = state.copyWith(
          isInitialized: _service.isModelAvailable,
          isModelAvailable: _service.isModelAvailable,
          isModelLoading: _service.isModelLoading,
          archNotSupported: _service.archNotSupported,
          llmService: _service.llmService,
        );
      }

      // Wait for model if loading (使用轮询，不阻塞主线程)
      await _pollWaitForModel();

      final llmService = _service.llmService;

      // Check architecture support
      if (llmService?.archNotSupported == true) {
        state = state.copyWith(
          isLoading: false,
          stage: OcrStage.idle,
          errorMessage: 'OCR功能仅支持 arm64-v8a 架构设备',
        );
        return OcrResult.failure(
          errorMessage: 'OCR功能仅支持 arm64-v8a 架构设备',
          type: OcrType.invoice,
        );
      }

      if (!_service.isModelAvailable) {
        state = state.copyWith(
          isLoading: false,
          stage: OcrStage.idle,
          errorMessage: 'OCR模型未加载',
        );
        return OcrResult.failure(
          errorMessage: 'OCR模型未加载',
          type: OcrType.invoice,
        );
      }

      // Read image bytes
      final file = File(imagePath);
      if (!await file.exists()) {
        logService.w(LogConfig.moduleOcr, '图片文件不存在: $imagePath');
        state = state.copyWith(
          isLoading: false,
          stage: OcrStage.idle,
          errorMessage: '图片文件不存在',
        );
        return OcrResult.failure(
          errorMessage: '图片文件不存在',
          type: OcrType.invoice,
        );
      }
      final bytes = await file.readAsBytes();
      logService.diag(LogConfig.moduleOcr, 'Image size', '${bytes.length} bytes');

      // Phase 1: OCR recognition
      logService.d(LogConfig.moduleOcr, 'Phase 1: OCR 识别...');
      _startProgressAnimation(OcrStage.ocrRecognizing, const Duration(milliseconds: _ocrDurationMs));

      final ocrStopwatch = Stopwatch()..start();
      final rawResult = await _service.recognizeRaw(bytes);
      ocrStopwatch.stop();
      logService.diag(LogConfig.moduleOcr, 'OCR recognition time', '${ocrStopwatch.elapsedMilliseconds}ms');
      logService.diag(LogConfig.moduleOcr, 'OCR text blocks', rawResult.textBlocks.length);

      _stopProgressAnimation();

      if (!rawResult.success) {
        logService.w(LogConfig.moduleOcr, 'OCR 识别失败: ${rawResult.errorMessage}');
        state = state.copyWith(
          isLoading: false,
          stage: OcrStage.idle,
          errorMessage: rawResult.errorMessage ?? 'OCR识别失败',
        );
        return OcrResult.failure(
          errorMessage: rawResult.errorMessage ?? 'OCR识别失败',
          type: OcrType.invoice,
        );
      }

      // Phase 2: LLM parsing
      if (llmService != null && llmService.isInitialized) {
        logService.d(LogConfig.moduleOcr, 'Phase 2: LLM 结构化提取...');
        _startProgressAnimation(OcrStage.llmParsing, const Duration(milliseconds: _llmDurationMs));

        final llmStopwatch = Stopwatch()..start();
        final llmResult = await llmService.extractStructuredData(rawResult, OcrType.invoice);
        llmStopwatch.stop();
        logService.diag(LogConfig.moduleOcr, 'LLM extraction time', '${llmStopwatch.elapsedMilliseconds}ms');

        _stopProgressAnimation();

        totalStopwatch.stop();
        logService.diag(LogConfig.moduleOcr, 'Total pipeline time', '${totalStopwatch.elapsedMilliseconds}ms');
        logService.i(LogConfig.moduleOcr, '========== OCR Pipeline 完成 (Invoice) ==========');

        state = state.copyWith(
          result: llmResult,
          isLoading: false,
          stage: OcrStage.idle,
          progress: 1.0,
        );
        return llmResult;
      } else {
        // LLM not available
        logService.w(LogConfig.moduleOcr, 'LLM 未初始化');
        state = state.copyWith(
          isLoading: false,
          stage: OcrStage.idle,
          errorMessage: 'LLM未初始化，无法进行结构化提取',
        );
        return OcrResult.failure(
          errorMessage: 'LLM未初始化，无法进行结构化提取',
          type: OcrType.invoice,
        );
      }
    } catch (e, stackTrace) {
      _stopProgressAnimation();
      logService.e(LogConfig.moduleOcr, 'OCR Pipeline 异常', e, stackTrace);
      state = state.copyWith(
        isLoading: false,
        stage: OcrStage.idle,
        errorMessage: 'OCR识别失败: ${e.toString()}',
      );
      return OcrResult.failure(
        errorMessage: 'OCR识别失败: ${e.toString()}',
        type: OcrType.invoice,
      );
    }
  }

  /// Recognize text from an invoice image path (without progress)
  Future<void> recognizeInvoice(String imagePath) async {
    await recognizeInvoiceWithProgress(imagePath);
  }

  /// Recognize invoice from PDF file with progress
  /// For text-based PDF: extract text and call LLM directly
  /// For image-based PDF: not supported (syncfusion_flutter_pdf doesn't support image extraction)
  Future<OcrResult?> recognizeInvoiceFromPdf(String pdfPath) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      clearResult: true,
      stage: OcrStage.idle,
      progress: 0.0,
    );

    try {
      // 确保OCR服务已初始化
      if (!_service.isModelAvailable) {
        logService.i(LogConfig.moduleOcr, 'OCR模型未初始化，开始初始化...');
        await _service.initialize();
        // 更新状态
        state = state.copyWith(
          isInitialized: _service.isModelAvailable,
          isModelAvailable: _service.isModelAvailable,
          isModelLoading: _service.isModelLoading,
          archNotSupported: _service.archNotSupported,
          llmService: _service.llmService,
        );
      }

      // Wait for model if loading (使用轮询，不阻塞主线程)
      await _pollWaitForModel();

      final llmService = _service.llmService;

      // Check architecture support
      if (llmService?.archNotSupported == true) {
        state = state.copyWith(
          isLoading: false,
          stage: OcrStage.idle,
          errorMessage: 'OCR功能仅支持 arm64-v8a 架构设备',
        );
        return OcrResult.failure(
          errorMessage: 'OCR功能仅支持 arm64-v8a 架构设备',
          type: OcrType.invoice,
        );
      }

      if (llmService == null || !llmService.isInitialized) {
        state = state.copyWith(
          isLoading: false,
          stage: OcrStage.idle,
          errorMessage: 'LLM未初始化',
        );
        return OcrResult.failure(
          errorMessage: 'LLM未初始化',
          type: OcrType.invoice,
        );
      }

      // Check if file exists
      final file = File(pdfPath);
      if (!await file.exists()) {
        state = state.copyWith(
          isLoading: false,
          stage: OcrStage.idle,
          errorMessage: 'PDF文件不存在',
        );
        return OcrResult.failure(
          errorMessage: 'PDF文件不存在',
          type: OcrType.invoice,
        );
      }

      // Phase 1: Extract text from PDF (skip OCR for text-based PDF)
      _startProgressAnimation(OcrStage.ocrRecognizing, const Duration(milliseconds: _ocrDurationMs));

      final pdfService = PdfService();
      final isTextBased = await pdfService.isTextBasedPdf(pdfPath, minTextLength: 20);

      OcrRawResult rawResult;

      if (isTextBased) {
        // Text-based PDF: extract text directly
        logService.d(LogConfig.moduleOcr, '检测到文本型 PDF，直接提取文本');
        final text = await pdfService.extractTextFromPdf(pdfPath);
        // Create a simple text block from the extracted text
        // Use dummy bounding box and confidence since we don't have position info
        rawResult = OcrRawResult(
          success: true,
          textBlocks: [
            OcrTextBlock(
              text: text,
              boundingBox: [
                OcrPoint(x: 0, y: 0),
                OcrPoint(x: 100, y: 0),
                OcrPoint(x: 100, y: 100),
                OcrPoint(x: 0, y: 100),
              ],
              confidence: 1.0,
            ),
          ],
        );
      } else {
        // Image-based PDF: not supported
        _stopProgressAnimation();
        state = state.copyWith(
          isLoading: false,
          stage: OcrStage.idle,
          errorMessage: '图片型PDF暂不支持OCR识别，请上传图片或文本型PDF',
        );
        return OcrResult.failure(
          errorMessage: '图片型PDF暂不支持OCR识别，请上传图片或文本型PDF',
          type: OcrType.invoice,
        );
      }

      _stopProgressAnimation();

      if (!rawResult.success || rawResult.fullText.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          stage: OcrStage.idle,
          errorMessage: 'PDF文本提取失败',
        );
        return OcrResult.failure(
          errorMessage: 'PDF文本提取失败',
          type: OcrType.invoice,
        );
      }

      logService.d(LogConfig.moduleOcr, 'PDF 提取文本: ${rawResult.fullText.substring(0, rawResult.fullText.length > 200 ? 200 : rawResult.fullText.length)}');

      // Phase 2: LLM parsing
      _startProgressAnimation(OcrStage.llmParsing, const Duration(milliseconds: _llmDurationMs));

      final llmResult = await llmService.extractStructuredData(rawResult, OcrType.invoice);

      _stopProgressAnimation();

      state = state.copyWith(
        result: llmResult,
        isLoading: false,
        stage: OcrStage.idle,
        progress: 1.0,
      );
      return llmResult;
    } catch (e) {
      _stopProgressAnimation();
      logService.e(LogConfig.moduleOcr, 'PDF 识别错误', e);
      state = state.copyWith(
        isLoading: false,
        stage: OcrStage.idle,
        errorMessage: 'PDF识别失败: ${e.toString()}',
      );
      return OcrResult.failure(
        errorMessage: 'PDF识别失败: ${e.toString()}',
        type: OcrType.invoice,
      );
    }
  }

  /// Recognize text from image bytes
  Future<void> recognizeFromBytes(Uint8List imageBytes, OcrType type) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final result = await _service.recognizeFromBytes(imageBytes, type);
      state = state.copyWith(
        result: result,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'OCR 识别失败: ${e.toString()}',
      );
    }
  }

  /// Recognize text from an image file
  Future<void> recognizeFromFile(File imageFile, OcrType type) async {
    if (!await imageFile.exists()) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '图片文件不存在',
      );
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final bytes = await imageFile.readAsBytes();
      await recognizeFromBytes(bytes, type);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '读取图片失败: ${e.toString()}',
      );
    }
  }

  /// Clear the OCR result
  void clearResult() {
    state = state.copyWith(
      result: null,
      errorMessage: null,
      stage: OcrStage.idle,
      progress: 0.0,
    );
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

/// Provider for OcrService
final ocrServiceProvider = Provider<OcrService>((ref) {
  return OcrService();
});

/// Provider for OcrNotifier
final ocrProvider = NotifierProvider<OcrNotifier, OcrState>(() {
  return OcrNotifier();
});

/// Provider for checking if OCR is available
final ocrAvailableProvider = Provider<bool>((ref) {
  final state = ref.watch(ocrProvider);
  return state.isInitialized && state.isModelAvailable;
});

/// Provider for checking if OCR model is loading
final ocrModelLoadingProvider = Provider<bool>((ref) {
  final state = ref.watch(ocrProvider);
  return state.isModelLoading;
});

/// Provider for OCR model info
final ocrModelInfoProvider = Provider<Map<String, dynamic>>((ref) {
  final service = ref.watch(ocrServiceProvider);
  return service.getModelInfo();
});
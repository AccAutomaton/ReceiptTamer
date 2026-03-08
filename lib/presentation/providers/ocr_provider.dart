import 'dart:async';
import 'dart:io';

import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    // Initialize OCR in background without blocking
    Future.microtask(() => initialize());
    ref.onDispose(() {
      _progressTimer?.cancel();
    });
    return const OcrState(isModelLoading: true);
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

    try {
      // Start initialization (non-blocking)
      await _service.initialize();

      // Update state with initial status
      state = state.copyWith(
        isInitialized: _service.isModelAvailable,
        isModelAvailable: _service.isModelAvailable,
        isModelLoading: _service.isModelLoading,
        archNotSupported: _service.archNotSupported,
        llmService: _service.llmService,
      );

      // If LLM is still loading in background, wait for it
      if (_service.isModelLoading) {
        // Start a background watcher for model loading
        _watchModelLoading();
      }
    } catch (e) {
      state = state.copyWith(
        isInitialized: false,
        isModelAvailable: false,
        isModelLoading: false,
        errorMessage: 'Failed to initialize OCR: ${e.toString()}',
      );
    }
  }

  /// Watch model loading status and update state when done
  void _watchModelLoading() {
    Future(() async {
      try {
        final llmService = _service.llmService;
        if (llmService != null && llmService.isModelLoading) {
          // Wait for LLM to finish loading
          await llmService.waitForInitialization();

          // Update state when loading is complete
          state = state.copyWith(
            isModelLoading: false,
            isModelAvailable: _service.isModelAvailable && llmService.isInitialized,
            archNotSupported: llmService.archNotSupported,
          );
        }
      } catch (e) {
        debugPrint('Error watching model loading: $e');
        // Update state to reflect error
        state = state.copyWith(
          isModelLoading: false,
          errorMessage: 'Model loading failed: ${e.toString()}',
        );
      }
    });
  }

  /// Wait for model initialization to complete
  /// Returns true if model is available
  Future<bool> waitForModel() async {
    return _service.waitForInitialization();
  }

  /// Recognize text from an order image path with progress
  Future<OcrResult?> recognizeOrderWithProgress(String imagePath) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      clearResult: true,
      stage: OcrStage.idle,
      progress: 0.0,
    );

    try {
      // Wait for model if loading
      if (_service.isModelLoading) {
        await _service.waitForInitialization();
      }

      final llmService = _service.llmService;
      if (llmService?.isModelLoading == true) {
        await llmService!.waitForInitialization();
      }

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

      // Phase 1: OCR recognition
      _startProgressAnimation(OcrStage.ocrRecognizing, const Duration(milliseconds: _ocrDurationMs));

      final rawResult = await _service.recognizeRaw(bytes);

      _stopProgressAnimation();

      if (!rawResult.success) {
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
        _startProgressAnimation(OcrStage.llmParsing, const Duration(milliseconds: _llmDurationMs));

        final llmResult = await llmService.extractStructuredData(rawResult, OcrType.order);

        _stopProgressAnimation();

        state = state.copyWith(
          result: llmResult,
          isLoading: false,
          stage: OcrStage.idle,
          progress: 1.0,
        );
        return llmResult;
      } else {
        // LLM not available
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
    } catch (e) {
      _stopProgressAnimation();
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
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      clearResult: true,
      stage: OcrStage.idle,
      progress: 0.0,
    );

    try {
      // Wait for model if loading
      if (_service.isModelLoading) {
        await _service.waitForInitialization();
      }

      final llmService = _service.llmService;
      if (llmService?.isModelLoading == true) {
        await llmService!.waitForInitialization();
      }

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

      // Phase 1: OCR recognition
      _startProgressAnimation(OcrStage.ocrRecognizing, const Duration(milliseconds: _ocrDurationMs));

      final rawResult = await _service.recognizeRaw(bytes);

      _stopProgressAnimation();

      if (!rawResult.success) {
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
      } else {
        // LLM not available
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
    } catch (e) {
      _stopProgressAnimation();
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
      // Wait for model if loading
      if (_service.isModelLoading) {
        await _service.waitForInitialization();
      }

      final llmService = _service.llmService;
      if (llmService?.isModelLoading == true) {
        await llmService!.waitForInitialization();
      }

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
        debugPrint('Detected text-based PDF, extracting text directly');
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

      debugPrint('PDF extracted text: ${rawResult.fullText.substring(0, rawResult.fullText.length > 200 ? 200 : rawResult.fullText.length)}');

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
      debugPrint('PDF recognition error: $e');
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
        errorMessage: 'OCR recognition failed: ${e.toString()}',
      );
    }
  }

  /// Recognize text from an image file
  Future<void> recognizeFromFile(File imageFile, OcrType type) async {
    if (!await imageFile.exists()) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Image file not found',
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
        errorMessage: 'Failed to read image: ${e.toString()}',
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
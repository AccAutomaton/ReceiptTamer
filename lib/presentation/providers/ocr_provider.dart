import 'dart:io';

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/ocr_result.dart';
import '../../data/services/llm_service.dart';
import '../../data/services/ocr_service.dart';

/// OCR state
class OcrState {
  final OcrResult? result;
  final bool isLoading;
  final bool isInitialized;
  final bool isModelAvailable;
  final bool isModelLoading;
  final String? errorMessage;
  final LlmService? llmService;

  const OcrState({
    this.result,
    this.isLoading = false,
    this.isInitialized = false,
    this.isModelAvailable = false,
    this.isModelLoading = false,
    this.errorMessage,
    this.llmService,
  });

  OcrState copyWith({
    OcrResult? result,
    bool? isLoading,
    bool? isInitialized,
    bool? isModelAvailable,
    bool? isModelLoading,
    String? errorMessage,
    LlmService? llmService,
  }) {
    return OcrState(
      result: result ?? this.result,
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
      isModelAvailable: isModelAvailable ?? this.isModelAvailable,
      isModelLoading: isModelLoading ?? this.isModelLoading,
      errorMessage: errorMessage,
      llmService: llmService ?? this.llmService,
    );
  }
}

/// OCR state notifier (Riverpod 3.x Notifier)
class OcrNotifier extends Notifier<OcrState> {
  @override
  OcrState build() {
    // Initialize OCR when the provider is first created
    Future.microtask(() => initialize());
    return const OcrState(isModelLoading: true);
  }

  OcrService get _service => ref.watch(ocrServiceProvider);

  /// Initialize the OCR service
  Future<void> initialize() async {
    state = state.copyWith(isModelLoading: true);

    try {
      final success = await _service.initialize();

      state = state.copyWith(
        isInitialized: success,
        isModelAvailable: _service.isModelAvailable,
        isModelLoading: false,
        llmService: _service.llmService,
      );
    } catch (e) {
      state = state.copyWith(
        isInitialized: false,
        isModelAvailable: false,
        isModelLoading: false,
        errorMessage: 'Failed to initialize OCR: ${e.toString()}',
      );
    }
  }

  /// Wait for model initialization to complete
  /// Returns true if model is available
  Future<bool> waitForModel() async {
    return _service.waitForInitialization();
  }

  /// Recognize text from an order image path
  Future<void> recognizeOrder(String imagePath) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final result = await _service.recognizeOrder(imagePath);
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

  /// Recognize text from an invoice image path
  Future<void> recognizeInvoice(String imagePath) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final result = await _service.recognizeInvoice(imagePath);
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
    state = state.copyWith(result: null, errorMessage: null);
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
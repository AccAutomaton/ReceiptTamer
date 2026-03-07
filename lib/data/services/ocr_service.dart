import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/ocr_result.dart';
import '../models/ocr_text_block.dart';
import 'llm_service.dart';

/// OCR service for text recognition using Paddle-Lite (RapidOcrAndroidOnnx)
///
/// 流程：OCR识别 → LLM结构化提取
class OcrService {
  static const MethodChannel _channel = MethodChannel('com.example.catering_receipt_recorder/ocr');

  bool _isInitialized = false;
  bool _isModelAvailable = false;
  bool _isLoading = false;
  Completer<bool>? _initCompleter;
  LlmService? _llmService;

  /// 深度转换 Map 类型（递归处理嵌套结构）
  /// 用于解决 Platform Channel 返回的 _Map<Object?, Object?> 类型转换问题
  static Map<String, dynamic> _deepConvertMap(Map<dynamic, dynamic> map) {
    return map.map((key, value) => MapEntry(
      key.toString(),
      _deepConvertValue(value),
    ));
  }

  /// 递归转换值类型
  static dynamic _deepConvertValue(dynamic value) {
    if (value is Map) {
      return _deepConvertMap(Map<dynamic, dynamic>.from(value));
    } else if (value is List) {
      return value.map((e) => _deepConvertValue(e)).toList();
    }
    return value;
  }

  /// Initialize the OCR service (async, non-blocking)
  /// Starts background initialization and returns immediately
  Future<bool> initialize() async {
    if (_isInitialized && _isModelAvailable) return true;

    // If already initializing, wait for the existing initialization
    if (_isLoading && _initCompleter != null) {
      debugPrint('等待现有的OCR初始化完成...');
      return _initCompleter!.future;
    }

    _isLoading = true;
    _initCompleter = Completer<bool>();

    try {
      // Initialize LLM service first (async, non-blocking)
      _llmService = LlmService();
      await _llmService!.initialize();
      debugPrint('LLM初始化已启动 (后台加载中)');

      // Initialize native OCR engine
      final result = await _channel.invokeMethod<bool>('initialize');

      _isInitialized = true;
      _isModelAvailable = result ?? false;

      debugPrint('Paddle-Lite OCR初始化: ${_isModelAvailable ? "成功" : "失败"}');

      _initCompleter!.complete(_isModelAvailable);
      _isLoading = false;
      return _isModelAvailable;
    } on PlatformException catch (e) {
      debugPrint('OCR初始化失败: ${e.message}');
      _isInitialized = true;
      _isModelAvailable = false;
      _initCompleter!.complete(false);
      _isLoading = false;
      return false;
    } catch (e) {
      debugPrint('OCR初始化异常: $e');
      _isInitialized = true;
      _isModelAvailable = false;
      _initCompleter!.complete(false);
      _isLoading = false;
      return false;
    }
  }

  /// Wait for initialization to complete if currently loading
  /// Returns true if model is available after waiting
  Future<bool> waitForInitialization() async {
    if (_isInitialized && _isModelAvailable) return true;
    if (_isLoading && _initCompleter != null) {
      return _initCompleter!.future;
    }
    // Not initialized and not loading, try to initialize
    return initialize();
  }

  /// Check if the OCR model is available
  bool get isModelAvailable => _isInitialized && _isModelAvailable;

  /// Check if LLM is available for structured extraction
  bool get isLlmAvailable => _llmService?.isInitialized ?? false;

  /// Check if model is currently loading
  bool get isModelLoading => _isLoading || (_llmService?.isModelLoading ?? false);

  /// Check if architecture is not supported
  bool get archNotSupported => _llmService?.archNotSupported ?? false;

  /// Get LLM service instance
  LlmService? get llmService => _llmService;

  /// Recognize text from an order image
  Future<OcrResult> recognizeOrder(String imagePath) async {
    // Wait for initialization if still loading
    if (_isLoading) {
      debugPrint('等待OCR模型加载完成...');
      await waitForInitialization();
    }

    // Wait for LLM if it's loading
    if (_llmService?.isModelLoading == true) {
      debugPrint('等待LLM模型加载完成...');
      await _llmService!.waitForInitialization();
    }

    // Check architecture support
    if (_llmService?.archNotSupported == true) {
      return OcrResult.failure(
        errorMessage: 'OCR功能仅支持 arm64-v8a 架构设备',
        type: OcrType.order,
      );
    }

    if (!_isModelAvailable) {
      return OcrResult.failure(
        errorMessage: 'OCR模型未加载',
        type: OcrType.order,
      );
    }

    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        return OcrResult.failure(
          errorMessage: '图片文件不存在',
          type: OcrType.order,
        );
      }

      final bytes = await file.readAsBytes();
      return await _recognizeFromBytes(bytes, OcrType.order);
    } catch (e) {
      return OcrResult.failure(
        errorMessage: 'OCR识别失败: ${e.toString()}',
        type: OcrType.order,
      );
    }
  }

  /// Recognize text from an invoice image
  Future<OcrResult> recognizeInvoice(String imagePath) async {
    // Wait for initialization if still loading
    if (_isLoading) {
      debugPrint('等待OCR模型加载完成...');
      await waitForInitialization();
    }

    // Wait for LLM if it's loading
    if (_llmService?.isModelLoading == true) {
      debugPrint('等待LLM模型加载完成...');
      await _llmService!.waitForInitialization();
    }

    // Check architecture support
    if (_llmService?.archNotSupported == true) {
      return OcrResult.failure(
        errorMessage: 'OCR功能仅支持 arm64-v8a 架构设备',
        type: OcrType.invoice,
      );
    }

    if (!_isModelAvailable) {
      return OcrResult.failure(
        errorMessage: 'OCR模型未加载',
        type: OcrType.invoice,
      );
    }

    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        return OcrResult.failure(
          errorMessage: '图片文件不存在',
          type: OcrType.invoice,
        );
      }

      final bytes = await file.readAsBytes();
      return await _recognizeFromBytes(bytes, OcrType.invoice);
    } catch (e) {
      return OcrResult.failure(
        errorMessage: 'OCR识别失败: ${e.toString()}',
        type: OcrType.invoice,
      );
    }
  }

  /// Recognize text from image bytes
  Future<OcrResult> recognizeFromBytes(Uint8List imageBytes, OcrType type) async {
    // Wait for initialization if still loading
    if (_isLoading) {
      debugPrint('等待OCR模型加载完成...');
      await waitForInitialization();
    }

    // Wait for LLM if it's loading
    if (_llmService?.isModelLoading == true) {
      debugPrint('等待LLM模型加载完成...');
      await _llmService!.waitForInitialization();
    }

    // Check architecture support
    if (_llmService?.archNotSupported == true) {
      return OcrResult.failure(
        errorMessage: 'OCR功能仅支持 arm64-v8a 架构设备',
        type: type,
      );
    }

    if (!_isModelAvailable) {
      return OcrResult.failure(
        errorMessage: 'OCR模型未加载',
        type: type,
      );
    }

    return await _recognizeFromBytes(imageBytes, type);
  }

  /// Get raw OCR result (text blocks with positions)
  Future<OcrRawResult> recognizeRaw(Uint8List imageBytes) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'recognizeRaw',
        {'imageBytes': imageBytes},
      );

      if (result != null && result['success'] == true) {
        final textBlocks = (result['textBlocks'] as List<dynamic>?)
                ?.map((block) => OcrTextBlock.fromJson(
                    _deepConvertMap(Map<dynamic, dynamic>.from(block as Map))))
                .toList() ??
            [];

        return OcrRawResultFactory.success(
          textBlocks: textBlocks,
          processingTimeMs: result['processingTimeMs'] as int?,
        );
      } else {
        return OcrRawResultFactory.failure(
          errorMessage: result?['error'] as String? ?? 'OCR识别失败',
        );
      }
    } on PlatformException catch (e) {
      debugPrint('Platform Channel调用失败: ${e.message}');
      return OcrRawResultFactory.failure(
        errorMessage: 'OCR调用失败: ${e.message}',
      );
    } catch (e) {
      return OcrRawResultFactory.failure(
        errorMessage: 'OCR识别异常: $e',
      );
    }
  }

  /// 执行OCR识别并使用LLM提取结构化数据
  Future<OcrResult> _recognizeFromBytes(Uint8List bytes, OcrType type) async {
    final totalStopwatch = Stopwatch()..start();

    debugPrint('========== OCR Pipeline Start ==========');
    debugPrint('[DIAG] Type: ${type == OcrType.order ? "Order" : "Invoice"}');
    debugPrint('[DIAG] Image size: ${bytes.length} bytes');

    try {
      // Step 1: Get raw OCR result
      debugPrint('[DIAG] Step 1: Running OCR recognition...');
      final ocrStopwatch = Stopwatch()..start();
      final rawResult = await recognizeRaw(bytes);
      ocrStopwatch.stop();
      debugPrint('[DIAG] OCR recognition time: ${ocrStopwatch.elapsedMilliseconds}ms');
      debugPrint('[DIAG] OCR text blocks: ${rawResult.textBlocks.length}');
      debugPrint('[DIAG] OCR full text length: ${rawResult.fullText.length}');

      if (!rawResult.success) {
        debugPrint('[DIAG] OCR recognition failed: ${rawResult.errorMessage}');
        return OcrResult.failure(
          errorMessage: rawResult.errorMessage ?? 'OCR识别失败',
          type: type,
        );
      }

      // Step 2: Use LLM for structured extraction
      if (_llmService != null && _llmService!.isInitialized) {
        debugPrint('[DIAG] Step 2: Running LLM extraction...');
        final llmStopwatch = Stopwatch()..start();
        final llmResult = await _llmService!.extractStructuredData(rawResult, type);
        llmStopwatch.stop();

        totalStopwatch.stop();
        debugPrint('[DIAG] LLM extraction time: ${llmStopwatch.elapsedMilliseconds}ms');
        debugPrint('[DIAG] Total pipeline time: ${totalStopwatch.elapsedMilliseconds}ms');

        if (llmResult.success) {
          debugPrint('[DIAG] Pipeline completed successfully');
          return llmResult;
        }
        debugPrint('[DIAG] LLM extraction failed: ${llmResult.errorMessage}');
      } else {
        debugPrint('[DIAG] LLM service not available (initialized: ${_llmService?.isInitialized})');
      }

      // LLM未初始化或提取失败
      return OcrResult.failure(
        errorMessage: _llmService?.isInitialized == true
            ? 'LLM提取失败，请检查模型是否正确加载'
            : 'LLM未初始化，无法进行结构化提取',
        type: type,
      );

    } on PlatformException catch (e) {
      debugPrint('[DIAG] Platform Exception: ${e.message}');
      return OcrResult.failure(
        errorMessage: 'OCR调用失败: ${e.message}',
        type: type,
      );
    } catch (e, stackTrace) {
      debugPrint('[DIAG] Exception: $e');
      debugPrint('[DIAG] Stack trace: $stackTrace');
      return OcrResult.failure(
        errorMessage: 'OCR识别异常: $e',
        type: type,
      );
    }
  }

  /// Release resources
  Future<void> dispose() async {
    try {
      await _channel.invokeMethod('dispose');
    } catch (e) {
      // Ignore errors during dispose
    }

    await _llmService?.dispose();
    _llmService = null;
    _isInitialized = false;
    _isModelAvailable = false;
  }

  /// Get model information
  Map<String, dynamic> getModelInfo() {
    return {
      'isInitialized': _isInitialized,
      'isModelAvailable': _isModelAvailable,
      'isModelLoading': isModelLoading,
      'supportedFormats': ['jpg', 'jpeg', 'png'],
      'engine': 'Paddle-Lite (RapidOcrAndroidOnnx)',
      'llmAvailable': isLlmAvailable,
      'archNotSupported': archNotSupported,
      'llmInfo': _llmService?.getModelInfo(),
    };
  }
}
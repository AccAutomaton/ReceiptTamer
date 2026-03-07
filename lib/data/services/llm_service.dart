import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/ocr_text_block.dart';
import '../models/ocr_result.dart';

/// LLM service for structured data extraction using Qwen3.5-0.8B MNN
///
/// 使用端侧 Qwen3.5-0.8B MNN 模型进行结构化数据提取
/// 模型文件: assets/models/qwen3.5-0.8b.mnn/
class LlmService {
  static const MethodChannel _channel = MethodChannel('com.example.catering_receipt_recorder/llm');

  bool _isInitialized = false;
  bool _isLoading = false;
  bool _isModelLoading = false;
  bool _archNotSupported = false;
  String? _loadError;
  final int _modelSizeBytes = 0;

  // 模型路径 (Flutter assets 中的路径 - MNN模型目录)
  static const String _modelPath = 'assets/models/qwen3.5-0.8b.mnn';

  /// Check if LLM is initialized and ready
  bool get isInitialized => _isInitialized;

  /// Check if model is currently loading
  bool get isLoading => _isLoading;

  /// Check if model is loading in background
  bool get isModelLoading => _isModelLoading;

  /// Check if architecture is not supported
  bool get archNotSupported => _archNotSupported;

  /// Get load error message
  String? get loadError => _loadError;

  /// Get model name
  String get modelName => 'Qwen3.5-0.8B-MNN';

  /// Get model size in bytes
  int get modelSizeBytes => _modelSizeBytes;

  /// Get model size formatted as string
  String get modelSizeFormatted {
    if (_modelSizeBytes == 0) return '未加载';
    if (_modelSizeBytes < 1024) return '$_modelSizeBytes B';
    if (_modelSizeBytes < 1024 * 1024) return '${(_modelSizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(_modelSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Initialize the LLM service (async, non-blocking)
  /// Returns true if initialization started successfully
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    if (_isLoading) return true;

    _isLoading = true;
    _isModelLoading = true;

    try {
      debugPrint('正在初始化LLM服务...');

      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('initialize', {
        'modelPath': _modelPath,
      });

      // Parse result
      _isModelLoading = result?['isLoading'] ?? false;
      _archNotSupported = result?['archNotSupported'] ?? false;
      _loadError = result?['error'] as String?;
      _isInitialized = result?['isInitialized'] ?? false;

      if (_archNotSupported) {
        debugPrint('LLM不支持当前架构: $_loadError');
        _isLoading = false;
        return false;
      }

      // If still loading in background, we don't wait
      if (_isModelLoading) {
        debugPrint('LLM模型正在后台加载...');
      }

      return true;
    } on PlatformException catch (e) {
      debugPrint('LLM初始化失败: ${e.message}');
      _loadError = e.message;
      _isLoading = false;
      _isModelLoading = false;
      return false;
    } catch (e) {
      debugPrint('LLM初始化异常: $e');
      _loadError = e.toString();
      _isLoading = false;
      _isModelLoading = false;
      return false;
    }
  }

  /// Wait for model initialization to complete
  /// Returns true if model is initialized successfully
  Future<bool> waitForInitialization({Duration timeout = const Duration(seconds: 120)}) async {
    if (_isInitialized) return true;
    if (_archNotSupported) return false;

    try {
      final result = await _channel.invokeMethod<bool>('waitForLoaded', {
        'timeoutMs': timeout.inMilliseconds,
      });

      _isInitialized = result ?? false;
      _isLoading = false;
      _isModelLoading = false;

      return _isInitialized;
    } catch (e) {
      debugPrint('等待LLM初始化失败: $e');
      _isLoading = false;
      _isModelLoading = false;
      return false;
    }
  }

  /// Get current status from native side
  Future<Map<String, dynamic>> getStatus() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getStatus');
      if (result != null) {
        _isInitialized = result['isInitialized'] ?? false;
        _isModelLoading = result['isLoading'] ?? false;
        _archNotSupported = result['archNotSupported'] ?? false;
        _loadError = result['error'] as String?;
      }
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      debugPrint('获取LLM状态失败: $e');
      return {};
    }
  }

  /// Extract structured data from OCR text
  Future<OcrResult> extractStructuredData(
    OcrRawResult ocrResult,
    OcrType type,
  ) async {
    if (!_isInitialized) {
      return OcrResult.failure(
        errorMessage: 'LLM模型未初始化',
        type: type,
      );
    }

    if (!ocrResult.success) {
      return OcrResult.failure(
        errorMessage: ocrResult.errorMessage ?? 'OCR识别失败',
        type: type,
      );
    }

    final totalStopwatch = Stopwatch()..start();

    try {
      final ocrText = ocrResult.fullText;
      debugPrint('========== LLM Service: Extract Structured Data ==========');
      debugPrint('[DIAG] Type: ${type == OcrType.order ? "Order" : "Invoice"}');
      debugPrint('[DIAG] OCR text length: ${ocrText.length} chars');
      debugPrint('[DIAG] OCR text: ${ocrText.substring(0, ocrText.length > 300 ? 300 : ocrText.length)}${ocrText.length > 300 ? "..." : ""}');

      String? jsonResult;

      final extractStopwatch = Stopwatch()..start();
      if (type == OcrType.order) {
        jsonResult = await _extractOrderInfo(ocrText);
      } else {
        jsonResult = await _extractInvoiceInfo(ocrText);
      }
      extractStopwatch.stop();

      debugPrint('[DIAG] Native extraction time: ${extractStopwatch.elapsedMilliseconds}ms');

      if (jsonResult == null) {
        debugPrint('[DIAG] Extraction returned null');
        return OcrResult.failure(
          errorMessage: 'LLM提取失败',
          type: type,
        );
      }

      debugPrint('[DIAG] LLM raw result: $jsonResult');

      // Parse JSON result
      final parseStopwatch = Stopwatch()..start();
      final result = _parseLlmResult(jsonResult, type);
      parseStopwatch.stop();

      totalStopwatch.stop();
      debugPrint('[DIAG] JSON parsing time: ${parseStopwatch.elapsedMilliseconds}ms');
      debugPrint('[DIAG] Total LLM service time: ${totalStopwatch.elapsedMilliseconds}ms');

      return result;

    } catch (e, stackTrace) {
      debugPrint('LLM提取异常: $e');
      debugPrint('Stack trace: $stackTrace');
      return OcrResult.failure(
        errorMessage: 'LLM提取异常: $e',
        type: type,
      );
    }
  }

  /// Extract order info using LLM
  Future<String?> _extractOrderInfo(String ocrText) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'extractOrder',
        {'ocrText': ocrText},
      );

      if (result != null && result['success'] == true) {
        return result['result'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('提取订单信息失败: $e');
      return null;
    }
  }

  /// Extract invoice info using LLM
  Future<String?> _extractInvoiceInfo(String ocrText) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'extractInvoice',
        {'ocrText': ocrText},
      );

      if (result != null && result['success'] == true) {
        return result['result'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('提取发票信息失败: $e');
      return null;
    }
  }

  /// Parse LLM JSON result into OcrResult
  OcrResult _parseLlmResult(String jsonStr, OcrType type) {
    try {
      final json = Map<String, dynamic>.from(jsonDecode(jsonStr) as Map);

      if (type == OcrType.order) {
        return OcrResult.orderSuccess(
          shopName: json['shopName'] as String? ?? '',
          amount: _parseAmount(json['amount']),
          orderTime: json['orderTime'] as String?,
          orderNumber: _cleanOrderNumber(json['orderNumber'] as String? ?? ''),
        );
      } else {
        return OcrResult.invoiceSuccess(
          invoiceNumber: _cleanOrderNumber(json['invoiceNumber'] as String? ?? ''),
          invoiceDate: json['invoiceDate'] as String? ?? '',
          totalAmount: _parseAmount(json['totalAmount']),
        );
      }
    } catch (e) {
      debugPrint('解析LLM结果失败: $e');
      return OcrResult.failure(
        errorMessage: '解析LLM结果失败: $e',
        type: type,
      );
    }
  }

  /// Clean order/invoice number: remove all non-alphanumeric characters
  String _cleanOrderNumber(String value) {
    if (value.isEmpty) return '';
    // Keep only letters and digits
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
  }

  /// Parse amount value from LLM result (handles both String and num)
  double _parseAmount(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      // Remove any non-numeric characters except decimal point and minus
      final cleaned = value.replaceAll(RegExp(r'[^\d.\-]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  /// Release resources
  Future<void> dispose() async {
    try {
      await _channel.invokeMethod('disposeLlm');
    } catch (e) {
      // Ignore errors during dispose
    }
    _isInitialized = false;
  }

  /// Get model information
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
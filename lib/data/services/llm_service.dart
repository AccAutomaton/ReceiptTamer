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
  int _modelSizeBytes = 0;

  // 模型路径 (Flutter assets 中的路径 - MNN模型目录)
  static const String _modelPath = 'assets/models/qwen3.5-0.8b.mnn';

  /// Check if LLM is initialized and ready
  bool get isInitialized => _isInitialized;

  /// Check if model is currently loading
  bool get isLoading => _isLoading;

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

  /// Initialize the LLM service
  /// Returns true if initialization was successful
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    if (_isLoading) return false;

    _isLoading = true;

    try {
      debugPrint('正在初始化LLM服务...');

      final result = await _channel.invokeMethod<bool>('initialize', {
        'modelPath': _modelPath,
      });

      _isInitialized = result ?? false;
      _isLoading = false;

      if (_isInitialized) {
        debugPrint('LLM服务初始化成功 (Qwen3.5-0.8B-MNN)');
      } else {
        debugPrint('LLM服务初始化失败');
      }

      return _isInitialized;
    } on PlatformException catch (e) {
      debugPrint('LLM初始化失败: ${e.message}');
      _isLoading = false;
      return false;
    } catch (e) {
      debugPrint('LLM初始化异常: $e');
      _isLoading = false;
      return false;
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
          amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
          orderTime: json['orderTime'] as String?,
          orderNumber: json['orderNumber'] as String? ?? '',
        );
      } else {
        return OcrResult.invoiceSuccess(
          invoiceNumber: json['invoiceNumber'] as String? ?? '',
          invoiceDate: json['invoiceDate'] as String? ?? '',
          totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
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
      'modelName': modelName,
      'modelSize': modelSizeFormatted,
      'modelSizeBytes': _modelSizeBytes,
      'modelPath': _modelPath,
      'enabled': true,
    };
  }
}
import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/ocr_text_block.dart';
import '../models/ocr_result.dart';
import '../../core/services/log_service.dart';
import '../../core/services/log_config.dart';

/// LLM service for structured data extraction using Qwen3.5-0.8B MNN
///
/// 使用端侧 Qwen3.5-0.8B MNN 模型进行结构化数据提取
/// 模型文件: assets/models/qwen3.5-0.8b.mnn/
class LlmService {
  static const MethodChannel _channel = MethodChannel('com.acautomaton.receipt.tamer/llm');

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
  /// 不会阻塞主线程，立即返回，模型在后台加载
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    if (_isLoading) return true;

    _isLoading = true;
    _isModelLoading = true;

    // 在后台执行初始化，不阻塞主线程
    _initializeInBackground();

    return true;
  }

  /// 后台初始化，不阻塞主线程
  void _initializeInBackground() {
    Future(() async {
      try {
        logService.i(LogConfig.moduleLlm, '正在初始化LLM服务...');

        final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('initialize', {
          'modelPath': _modelPath,
        });

        // Parse result
        _isModelLoading = result?['isLoading'] ?? false;
        _archNotSupported = result?['archNotSupported'] ?? false;
        _loadError = result?['error'] as String?;
        _isInitialized = result?['isInitialized'] ?? false;

        if (_archNotSupported) {
          logService.w(LogConfig.moduleLlm, 'LLM不支持当前架构: $_loadError');
          _isLoading = false;
          return;
        }

        // If still loading in background, poll for completion
        if (_isModelLoading) {
          logService.i(LogConfig.moduleLlm, 'LLM模型正在后台加载...');
          await _pollForLoadingComplete();
        }
      } on PlatformException catch (e, stackTrace) {
        logService.e(LogConfig.moduleLlm, 'LLM初始化失败', e, stackTrace);
        _loadError = e.message;
        _isLoading = false;
        _isModelLoading = false;
      } catch (e, stackTrace) {
        logService.e(LogConfig.moduleLlm, 'LLM初始化异常', e, stackTrace);
        _loadError = e.toString();
        _isLoading = false;
        _isModelLoading = false;
      }
    });
  }

  /// 轮询等待模型加载完成
  Future<void> _pollForLoadingComplete() async {
    logService.d(LogConfig.moduleLlm, '开始轮询加载状态...');
    while (_isModelLoading) {
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        final status = await getStatus();
        _isModelLoading = status['isLoading'] ?? false;
        _isInitialized = status['isInitialized'] ?? false;
        _archNotSupported = status['archNotSupported'] ?? false;
        _loadError = status['error'] as String?;

        logService.d(LogConfig.moduleLlm, '轮询状态: isLoading=$_isModelLoading, isInitialized=$_isInitialized');

        if (_isInitialized) {
          logService.i(LogConfig.moduleLlm, '模型加载完成!');
          _isLoading = false;
          break;
        }
        if (_loadError != null || _archNotSupported) {
          logService.w(LogConfig.moduleLlm, '模型加载失败: $_loadError');
          _isLoading = false;
          break;
        }
      } catch (e, stackTrace) {
        logService.e(LogConfig.moduleLlm, '轮询状态失败', e, stackTrace);
      }
    }
    _isLoading = false;
    _isModelLoading = false;
    logService.i(LogConfig.moduleLlm, '轮询结束: isInitialized=$_isInitialized');
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
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleLlm, '等待LLM初始化失败', e, stackTrace);
      _isLoading = false;
      _isModelLoading = false;
      return false;
    }
  }

  /// Get current status from native side
  Future<Map<String, dynamic>> getStatus() async {
    logService.d(LogConfig.moduleLlm, '获取 LLM 状态...');
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getStatus');
      if (result != null) {
        _isInitialized = result['isInitialized'] ?? false;
        _isModelLoading = result['isLoading'] ?? false;
        _archNotSupported = result['archNotSupported'] ?? false;
        _loadError = result['error'] as String?;
      }
      logService.d(LogConfig.moduleLlm, 'LLM 状态: isInitialized=$_isInitialized, isModelLoading=$_isModelLoading, archNotSupported=$_archNotSupported');
      return Map<String, dynamic>.from(result ?? {});
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleLlm, '获取LLM状态失败', e, stackTrace);
      return {};
    }
  }

  /// Extract structured data from OCR text
  Future<OcrResult> extractStructuredData(
    OcrRawResult ocrResult,
    OcrType type,
  ) async {
    logService.d(LogConfig.moduleLlm, 'extractStructuredData: type=${type == OcrType.order ? "Order" : "Invoice"}');
    if (!_isInitialized) {
      logService.w(LogConfig.moduleLlm, 'LLM 模型未初始化');
      return OcrResult.failure(
        errorMessage: 'LLM模型未初始化',
        type: type,
      );
    }

    if (!ocrResult.success) {
      logService.w(LogConfig.moduleLlm, 'OCR 结果无效: ${ocrResult.errorMessage}');
      return OcrResult.failure(
        errorMessage: ocrResult.errorMessage ?? 'OCR识别失败',
        type: type,
      );
    }

    final totalStopwatch = Stopwatch()..start();

    try {
      final ocrText = ocrResult.fullText;
      logService.i(LogConfig.moduleLlm, '========== LLM 结构化提取 ==========');
      logService.diag(LogConfig.moduleLlm, 'Type', type == OcrType.order ? "Order" : "Invoice");
      logService.diag(LogConfig.moduleLlm, 'OCR text length', '${ocrText.length} chars');
      logService.d(LogConfig.moduleLlm, 'OCR text: ${ocrText.substring(0, ocrText.length > 300 ? 300 : ocrText.length)}${ocrText.length > 300 ? "..." : ""}');

      String? jsonResult;

      final extractStopwatch = Stopwatch()..start();
      if (type == OcrType.order) {
        jsonResult = await _extractOrderInfo(ocrText);
      } else {
        jsonResult = await _extractInvoiceInfo(ocrText);
      }
      extractStopwatch.stop();

      logService.diag(LogConfig.moduleLlm, 'Native extraction time', '${extractStopwatch.elapsedMilliseconds}ms');

      if (jsonResult == null) {
        logService.w(LogConfig.moduleLlm, '提取结果为空');
        return OcrResult.failure(
          errorMessage: 'LLM提取失败',
          type: type,
        );
      }

      logService.d(LogConfig.moduleLlm, 'LLM raw result: $jsonResult');

      // Parse JSON result
      final parseStopwatch = Stopwatch()..start();
      final result = _parseLlmResult(jsonResult, type);
      parseStopwatch.stop();

      totalStopwatch.stop();
      logService.diag(LogConfig.moduleLlm, 'JSON parsing time', '${parseStopwatch.elapsedMilliseconds}ms');
      logService.diag(LogConfig.moduleLlm, 'Total LLM service time', '${totalStopwatch.elapsedMilliseconds}ms');

      return result;

    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleLlm, 'LLM提取异常', e, stackTrace);
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
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleLlm, '提取订单信息失败', e, stackTrace);
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
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleLlm, '提取发票信息失败', e, stackTrace);
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
          sellerName: json['sellerName'] as String? ?? '',
        );
      }
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleLlm, '解析LLM结果失败', e, stackTrace);
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
    logService.i(LogConfig.moduleLlm, 'LLM 服务释放资源...');
    try {
      await _channel.invokeMethod('disposeLlm');
      logService.i(LogConfig.moduleLlm, 'Native LLM 资源已释放');
    } catch (e) {
      logService.w(LogConfig.moduleLlm, '释放 Native LLM 资源时出错: $e');
    }
    _isInitialized = false;
    logService.i(LogConfig.moduleLlm, 'LLM 服务资源释放完成');
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
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/services/log_config.dart';
import '../../core/services/log_service.dart';
import '../models/llm_backend.dart';

class OpenAiCompatibleException implements Exception {
  const OpenAiCompatibleException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OpenAiCompatibleBackend implements LlmBackend {
  static const Set<String> _protectedExtraKeys = {
    'model',
    'messages',
    'stream',
  };

  final OpenAiCompatibleConfig config;
  final http.Client _client;
  final ServiceLogSink _logSink;

  OpenAiCompatibleBackend({
    required this.config,
    http.Client? client,
    ServiceLogSink? logSink,
  }) : _client = client ?? http.Client(),
       _logSink = logSink ?? defaultServiceLogSink;

  static Uri chatCompletionsUri(String endpoint) {
    final trimmed = endpoint.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.endsWith('/chat/completions')) {
      return Uri.parse(trimmed);
    }
    if (trimmed.endsWith('/v1')) {
      return Uri.parse('$trimmed/chat/completions');
    }
    return Uri.parse('$trimmed/v1/chat/completions');
  }

  static Uri modelsUri(String endpoint) {
    final trimmed = endpoint.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.endsWith('/models')) {
      return Uri.parse(trimmed);
    }
    if (trimmed.endsWith('/chat/completions')) {
      final base = trimmed.substring(
        0,
        trimmed.length - '/chat/completions'.length,
      );
      return Uri.parse('$base/models');
    }
    if (trimmed.endsWith('/v1')) {
      return Uri.parse('$trimmed/models');
    }
    return Uri.parse('$trimmed/v1/models');
  }

  Map<String, dynamic> buildRequestBody(LlmRequest request) {
    final body = <String, dynamic>{
      'model': config.modelName.trim(),
      'messages': [
        {'role': 'user', 'content': _buildUserContent(request)},
      ],
    };

    for (final entry in config.extraParams.entries) {
      if (!_protectedExtraKeys.contains(entry.key)) {
        body[entry.key] = entry.value;
      }
    }
    return body;
  }

  dynamic _buildUserContent(LlmRequest request) {
    if (!config.isMultimodal || !request.hasImage) {
      return request.prompt;
    }

    final dataUrl =
        'data:${request.mimeType};base64,${base64Encode(request.imageBytes!)}';
    return [
      {'type': 'text', 'text': request.prompt},
      {
        'type': 'image_url',
        'image_url': {'url': dataUrl},
      },
    ];
  }

  Future<List<String>> listModels() async {
    final uri = modelsUri(config.endpoint);
    final stopwatch = Stopwatch()..start();
    final headers = <String, String>{
      'accept': 'application/json',
      if (config.apiKey.trim().isNotEmpty)
        'authorization': 'Bearer ${config.apiKey.trim()}',
    };

    try {
      _logI('开始获取云端模型列表: 主机=${uri.host}');
      final response = await _client.get(uri, headers: headers);
      _logI(
        '云端模型列表请求完成: 主机=${uri.host}, HTTP ${response.statusCode}, '
        '耗时=${stopwatch.elapsedMilliseconds}ms',
      );

      if (response.statusCode == 401) {
        throw const OpenAiCompatibleException('API Key 错误');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw OpenAiCompatibleException(
          '模型列表请求失败: HTTP ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['data'] is! List) {
        throw const FormatException('模型列表响应格式无效');
      }

      final modelIds = (decoded['data'] as List)
          .whereType<Map>()
          .map((model) => model['id'])
          .whereType<String>()
          .where((id) => id.trim().isNotEmpty)
          .toList(growable: false);
      if (modelIds.isEmpty) {
        throw const FormatException('模型列表为空');
      }
      _logI('云端模型列表解析完成: 主机=${uri.host}, modelCount=${modelIds.length}');
      return modelIds;
    } catch (e, stackTrace) {
      _logE(
        '云端模型列表请求异常: 主机=${uri.host}, '
        '耗时=${stopwatch.elapsedMilliseconds}ms',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<LlmBackendStatus> getStatus() async {
    return LlmBackendStatus(isAvailable: config.isConfigured);
  }

  @override
  Future<LlmCompletion> complete(LlmRequest request) async {
    final uri = chatCompletionsUri(config.endpoint);
    final stopwatch = Stopwatch()..start();
    final isMultimodalRequest = config.isMultimodal && request.hasImage;
    final headers = <String, String>{
      'content-type': 'application/json',
      if (config.apiKey.trim().isNotEmpty)
        'authorization': 'Bearer ${config.apiKey.trim()}',
    };

    try {
      _logI(
        '云端模型请求开始: 主机=${uri.host}, 模型=${config.modelName.trim()}, '
        '多模态=$isMultimodalRequest',
      );
      final response = await _client.post(
        uri,
        headers: headers,
        body: jsonEncode(buildRequestBody(request)),
      );
      _logI(
        '云端模型请求完成: 主机=${uri.host}, 模型=${config.modelName.trim()}, '
        '多模态=$isMultimodalRequest, HTTP ${response.statusCode}, '
        '耗时=${stopwatch.elapsedMilliseconds}ms',
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw OpenAiCompatibleException(_safeHttpFailureMessage(response));
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const FormatException('云端模型响应不是 JSON 对象');
      }
      final json = decoded.map((key, value) => MapEntry(key.toString(), value));
      final choices = json['choices'];
      final text = _extractContent(choices);
      return LlmCompletion(text: text);
    } catch (e, stackTrace) {
      _logE(
        '云端模型请求异常: 主机=${uri.host}, 模型=${config.modelName.trim()}, '
        '多模态=$isMultimodalRequest, 耗时=${stopwatch.elapsedMilliseconds}ms',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  String _extractContent(dynamic choices) {
    if (choices is! List || choices.isEmpty) {
      throw const FormatException('云端模型响应缺少 choices');
    }
    final first = choices.first;
    if (first is! Map) {
      throw const FormatException('云端模型 choice 不是对象');
    }
    final message = first['message'];
    if (message is Map) {
      final content = message['content'];
      if (content is String) return content;
      if (content is List) {
        return content
            .whereType<Map>()
            .map((part) => part['text'])
            .whereType<String>()
            .join();
      }
    }
    final text = first['text'];
    if (text is String) return text;
    throw const FormatException('云端模型响应缺少文本内容');
  }

  String _safeHttpFailureMessage(http.Response response) {
    final code = _safeProviderErrorCode(response.body);
    final codeSuffix = code == null ? '' : ' ($code)';
    return '云端模型请求失败: HTTP ${response.statusCode}$codeSuffix';
  }

  String? _safeProviderErrorCode(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      Object? code;
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map) {
          code = error['code'] ?? error['type'];
        } else {
          code = decoded['code'] ?? decoded['type'];
        }
      }
      if (code is String && RegExp(r'^[A-Za-z0-9_.:-]{1,80}$').hasMatch(code)) {
        return code;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  void _logI(String message) {
    _logSink('I', LogConfig.moduleLlm, message);
  }

  void _logE(String message, Object error, StackTrace stackTrace) {
    _logSink('E', LogConfig.moduleLlm, message, error, stackTrace);
  }
}

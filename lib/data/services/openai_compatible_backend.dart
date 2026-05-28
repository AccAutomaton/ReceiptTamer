import 'dart:convert';

import 'package:http/http.dart' as http;

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

  OpenAiCompatibleBackend({required this.config, http.Client? client})
    : _client = client ?? http.Client();

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
    final headers = <String, String>{
      'accept': 'application/json',
      if (config.apiKey.trim().isNotEmpty)
        'authorization': 'Bearer ${config.apiKey.trim()}',
    };

    final response = await _client.get(
      modelsUri(config.endpoint),
      headers: headers,
    );

    if (response.statusCode == 401) {
      throw const OpenAiCompatibleException('API Key 错误');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OpenAiCompatibleException('模型列表请求失败: HTTP ${response.statusCode}');
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
    return modelIds;
  }

  @override
  Future<LlmBackendStatus> getStatus() async {
    return LlmBackendStatus(isAvailable: config.isConfigured);
  }

  @override
  Future<LlmCompletion> complete(LlmRequest request) async {
    final headers = <String, String>{
      'content-type': 'application/json',
      if (config.apiKey.trim().isNotEmpty)
        'authorization': 'Bearer ${config.apiKey.trim()}',
    };

    final response = await _client.post(
      chatCompletionsUri(config.endpoint),
      headers: headers,
      body: jsonEncode(buildRequestBody(request)),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OpenAiCompatibleException(_safeHttpFailureMessage(response));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Cloud model response is not a JSON object');
    }
    final json = decoded.map((key, value) => MapEntry(key.toString(), value));
    final choices = json['choices'];
    final text = _extractContent(choices);
    return LlmCompletion(text: text);
  }

  String _extractContent(dynamic choices) {
    if (choices is! List || choices.isEmpty) {
      throw const FormatException('Cloud model response has no choices');
    }
    final first = choices.first;
    if (first is! Map) {
      throw const FormatException('Cloud model choice is not an object');
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
    throw const FormatException('Cloud model response has no text content');
  }

  String _safeHttpFailureMessage(http.Response response) {
    final code = _safeProviderErrorCode(response.body);
    final codeSuffix = code == null ? '' : ' ($code)';
    return 'Cloud model request failed: HTTP ${response.statusCode}$codeSuffix';
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
}

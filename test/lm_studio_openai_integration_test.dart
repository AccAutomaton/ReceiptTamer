import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:receipt_tamer/data/models/llm_backend.dart';
import 'package:receipt_tamer/data/services/openai_compatible_backend.dart';

void main() {
  const enabledEnv = 'LM_STUDIO_OPENAI_TEST';
  const endpointEnv = 'LM_STUDIO_ENDPOINT';
  const modelEnv = 'LM_STUDIO_MODEL';

  final enabled = Platform.environment[enabledEnv] == '1';
  final endpoint =
      Platform.environment[endpointEnv] ?? 'http://localhost:1234/v1';

  final skipReason = enabled
      ? false
      : 'Set $enabledEnv=1 to run against a local LM Studio endpoint.';

  test(
    'LM Studio multimodal mode accepts direct image content',
    () async {
      final modelName =
          Platform.environment[modelEnv] ?? await _firstModelId(endpoint);
      final backend = OpenAiCompatibleBackend(
        config: OpenAiCompatibleConfig(
          endpoint: endpoint,
          modelName: modelName,
          isMultimodal: true,
          extraParamsJson: '{"temperature":0,"max_tokens":32}',
        ),
      );

      final completion = await backend
          .complete(
            LlmRequest.image(
              prompt:
                  'Look at this tiny image and reply with one short word for its dominant color.',
              imageBytes: base64Decode(_redPixelPngBase64),
              mimeType: 'image/png',
            ),
          )
          .timeout(const Duration(seconds: 60));

      expect(completion.text.trim(), isNotEmpty);
    },
    skip: skipReason,
    timeout: const Timeout(Duration(seconds: 75)),
  );

  test(
    'LM Studio text-only setting sends OCR text instead of image content',
    () async {
      final modelName =
          Platform.environment[modelEnv] ?? await _firstModelId(endpoint);
      final backend = OpenAiCompatibleBackend(
        config: OpenAiCompatibleConfig(
          endpoint: endpoint,
          modelName: modelName,
          isMultimodal: false,
          extraParamsJson: '{"temperature":0,"max_tokens":64}',
        ),
      );

      final completion = await backend
          .complete(
            const LlmRequest.text(
              prompt:
                  'Assume this text came from OCR. Return compact JSON only: 商家: 测试餐厅; 金额: 12.30; 日期: 2026-05-24.',
            ),
          )
          .timeout(const Duration(seconds: 60));

      expect(completion.text.trim(), isNotEmpty);
    },
    skip: skipReason,
    timeout: const Timeout(Duration(seconds: 75)),
  );
}

const _redPixelPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAACHSURBVHhe7dAhAQAADITA719681QAcQbJbjuzMdg0gMGmAQw2DWCwaQCDTQMYbBrAYNMABpsGMNg0gMGmAQw2DWCwaQCDTQMYbBrAYNMABpsGMNg0gMGmAQw2DWCwaQCDTQMYbBrAYNMABpsGMNg0gMGmAQw2DWCwaQCDTQMYbBrAYNMABpsHQ4jh0hEeUY0AAAAASUVORK5CYII=';

Future<String> _firstModelId(String endpoint) async {
  final trimmed = endpoint.trim().replaceAll(RegExp(r'/+$'), '');
  final modelsBase = trimmed.endsWith('/chat/completions')
      ? trimmed.substring(0, trimmed.length - '/chat/completions'.length)
      : trimmed.endsWith('/v1')
      ? trimmed
      : '$trimmed/v1';
  final modelsUri = Uri.parse('$modelsBase/models');

  final response = await http
      .get(modelsUri)
      .timeout(const Duration(seconds: 10));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw StateError(
      'LM Studio models request failed: HTTP ${response.statusCode}',
    );
  }

  final decoded = jsonDecode(response.body);
  if (decoded is! Map || decoded['data'] is! List || decoded['data'].isEmpty) {
    throw const FormatException('LM Studio models response has no models');
  }

  final first = (decoded['data'] as List).first;
  if (first is! Map || first['id'] is! String) {
    throw const FormatException('LM Studio first model has no id');
  }
  return first['id'] as String;
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:receipt_tamer/data/models/llm_backend.dart';
import 'package:receipt_tamer/data/services/llm_config_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('default LLM backend is unset until user chooses one', () async {
    final service = LlmConfigService();

    final config = await service.load();

    expect(config.backendType, LlmBackendType.unset);
    expect(config.isConfigured, isFalse);
    expect(config.cloud.provider, OpenAiModelProvider.xiaomiMimo);
    expect(
      config.cloud.endpoint,
      OpenAiModelProvider.xiaomiMimo.presetEndpoint,
    );
    expect(config.cloud.isMultimodal, isTrue);
    expect(
      config.cloud.extraParamsJson,
      OpenAiModelProvider.xiaomiMimo.disabledThinkingExtraBodyJson,
    );
    expect(config.cloud.extraParams, {
      'thinking': {'type': 'disabled'},
    });
  });

  test('preset providers define endpoint and disabled thinking extra body', () {
    expect(
      OpenAiModelProvider.xiaomiMimo.presetEndpoint,
      'https://api.xiaomimimo.com/v1',
    );
    expect(
      OpenAiModelProvider.deepSeek.presetEndpoint,
      'https://api.deepseek.com/v1',
    );
    for (final provider in [
      OpenAiModelProvider.xiaomiMimo,
      OpenAiModelProvider.deepSeek,
    ]) {
      expect(provider.usesPreset, isTrue);
      expect(
        provider.disabledThinkingExtraBodyJson,
        '{"thinking":{"type":"disabled"}}',
      );
    }
    expect(OpenAiModelProvider.custom.usesPreset, isFalse);
    expect(OpenAiModelProvider.custom.disabledThinkingExtraBodyJson, isEmpty);
    expect(
      OpenAiCompatibleConfig.forProvider(
        OpenAiModelProvider.xiaomiMimo,
      ).isMultimodal,
      isTrue,
    );
    expect(
      OpenAiCompatibleConfig.forProvider(
        OpenAiModelProvider.deepSeek,
      ).isMultimodal,
      isFalse,
    );
  });

  test(
    'cloud config persists multimodal flag and extra body without usage state',
    () async {
      final service = LlmConfigService();
      final config = LlmBackendConfig(
        backendType: LlmBackendType.openAiCompatible,
        cloud: const OpenAiCompatibleConfig(
          provider: OpenAiModelProvider.deepSeek,
          endpoint: 'https://api.example.com/v1',
          modelName: 'qwen-vl',
          apiKey: 'secret-key',
          isMultimodal: true,
          extraParamsJson: '{"enable_thinking":false}',
        ),
      );

      await service.save(config);
      final restored = await service.load();
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('llm.backend.config.v1')!;

      expect(restored.backendType, LlmBackendType.openAiCompatible);
      expect(restored.cloud.provider, OpenAiModelProvider.deepSeek);
      expect(restored.cloud.endpoint, 'https://api.example.com/v1');
      expect(restored.cloud.modelName, 'qwen-vl');
      expect(restored.cloud.apiKey, 'secret-key');
      expect(restored.cloud.isMultimodal, isTrue);
      expect(restored.cloud.extraParams, {'enable_thinking': false});
      expect(raw, isNot(contains('usage')));
      expect(raw, isNot(contains('promptTokens')));
      expect(raw, isNot(contains('completionTokens')));
      expect(raw, isNot(contains('totalTokens')));
    },
  );

  test('provider-specific cloud configs persist independently', () async {
    final service = LlmConfigService();
    final xiaomi = OpenAiCompatibleConfig.forProvider(
      OpenAiModelProvider.xiaomiMimo,
    ).copyWith(apiKey: 'mimo-key', modelName: 'mimo-model');
    final deepSeek = OpenAiCompatibleConfig.forProvider(
      OpenAiModelProvider.deepSeek,
    ).copyWith(apiKey: 'deepseek-key', modelName: 'deepseek-model');
    const custom = OpenAiCompatibleConfig(
      provider: OpenAiModelProvider.custom,
      endpoint: 'https://custom.example.com/v1',
      modelName: 'custom-model',
      apiKey: 'custom-key',
      extraParamsJson: '{"temperature":0}',
    );

    await service.save(
      LlmBackendConfig(
        backendType: LlmBackendType.openAiCompatible,
        cloud: deepSeek,
        cloudConfigs: {
          OpenAiModelProvider.xiaomiMimo: xiaomi,
          OpenAiModelProvider.deepSeek: deepSeek,
          OpenAiModelProvider.custom: custom,
        },
      ),
    );

    final restored = await service.load();

    expect(restored.cloud.provider, OpenAiModelProvider.deepSeek);
    expect(
      restored.cloudConfigForProvider(OpenAiModelProvider.xiaomiMimo).apiKey,
      'mimo-key',
    );
    expect(
      restored.cloudConfigForProvider(OpenAiModelProvider.xiaomiMimo).modelName,
      'mimo-model',
    );
    expect(
      restored
          .cloudConfigForProvider(OpenAiModelProvider.xiaomiMimo)
          .isMultimodal,
      isTrue,
    );
    expect(
      restored.cloudConfigForProvider(OpenAiModelProvider.deepSeek).apiKey,
      'deepseek-key',
    );
    expect(
      restored.cloudConfigForProvider(OpenAiModelProvider.custom).endpoint,
      'https://custom.example.com/v1',
    );
    expect(
      restored.cloudConfigForProvider(OpenAiModelProvider.custom).extraParams,
      {'temperature': 0},
    );
  });

  test(
    'legacy usage fields are ignored while loading existing config',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'llm.backend.config.v1',
        jsonEncode({
          'backendType': 'openAiCompatible',
          'local': {
            'modelName': 'Qwen3.5-0.8B-MNN-Text-Only',
            'usage': {'totalTokens': 99},
          },
          'cloud': {
            'endpoint': 'https://api.example.com/v1',
            'modelName': 'qwen-plus',
            'apiKey': 'sk-should-not-leak',
            'isMultimodal': true,
            'extraParamsJson': '{"enable_thinking":false}',
            'usage': {
              'promptTokens': 3,
              'completionTokens': 7,
              'totalTokens': 10,
              'records': [
                {'timestamp': '2026-05-25T01:02:03.000Z', 'count': 10},
              ],
            },
          },
        }),
      );

      final service = LlmConfigService();

      final config = await service.load();

      expect(config.backendType, LlmBackendType.openAiCompatible);
      expect(config.cloud.endpoint, 'https://api.example.com/v1');
      expect(config.cloud.modelName, 'qwen-plus');
      expect(config.cloud.isMultimodal, isTrue);
      expect(config.toSafeLogJson().toString(), isNot(contains('sk-should')));
      expect(config.toJson().toString(), isNot(contains('usage')));
      expect(config.toJson().toString(), isNot(contains('totalTokens')));
    },
  );
}

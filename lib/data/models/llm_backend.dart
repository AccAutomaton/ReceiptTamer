import 'dart:convert';
import 'dart:typed_data';

import 'ocr_result.dart';

enum LlmBackendType { unset, localMnn, openAiCompatible }

extension LlmBackendTypeCodec on LlmBackendType {
  static LlmBackendType fromName(String? value) {
    return LlmBackendType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => LlmBackendType.unset,
    );
  }
}

enum OpenAiModelProvider { xiaomiMimo, deepSeek, custom }

extension OpenAiModelProviderCodec on OpenAiModelProvider {
  static OpenAiModelProvider fromName(String? value) {
    return OpenAiModelProvider.values.firstWhere(
      (provider) => provider.name == value,
      orElse: () => OpenAiModelProvider.custom,
    );
  }

  String get displayName {
    return switch (this) {
      OpenAiModelProvider.xiaomiMimo => 'Xiaomi MiMo',
      OpenAiModelProvider.deepSeek => 'Deepseek',
      OpenAiModelProvider.custom => '其它 OpenAI 风格接口',
    };
  }

  bool get usesPreset => this != OpenAiModelProvider.custom;

  String get presetEndpoint {
    return switch (this) {
      OpenAiModelProvider.xiaomiMimo =>
        OpenAiCompatibleConfig.xiaomiMimoEndpoint,
      OpenAiModelProvider.deepSeek => 'https://api.deepseek.com/v1',
      OpenAiModelProvider.custom => '',
    };
  }

  String get disabledThinkingExtraBodyJson {
    return switch (this) {
      OpenAiModelProvider.xiaomiMimo || OpenAiModelProvider.deepSeek =>
        OpenAiCompatibleConfig.disabledThinkingExtraBodyJson,
      OpenAiModelProvider.custom => '',
    };
  }

  bool get defaultIsMultimodal {
    return switch (this) {
      OpenAiModelProvider.xiaomiMimo => true,
      OpenAiModelProvider.deepSeek || OpenAiModelProvider.custom => false,
    };
  }
}

class OpenAiCompatibleConfig {
  static const String emptyExtraBodyJson = '';
  static const String xiaomiMimoEndpoint = 'https://api.xiaomimimo.com/v1';
  static const String disabledThinkingExtraBodyJson =
      '{"thinking":{"type":"disabled"}}';

  final OpenAiModelProvider provider;
  final String endpoint;
  final String modelName;
  final String apiKey;
  final bool isMultimodal;
  final String extraParamsJson;

  const OpenAiCompatibleConfig({
    this.provider = OpenAiModelProvider.custom,
    this.endpoint = '',
    this.modelName = '',
    this.apiKey = '',
    this.isMultimodal = false,
    this.extraParamsJson = emptyExtraBodyJson,
  });

  const OpenAiCompatibleConfig.xiaomiMimoDefaults()
    : provider = OpenAiModelProvider.xiaomiMimo,
      endpoint = xiaomiMimoEndpoint,
      modelName = '',
      apiKey = '',
      isMultimodal = true,
      extraParamsJson = disabledThinkingExtraBodyJson;

  factory OpenAiCompatibleConfig.forProvider(OpenAiModelProvider provider) {
    return OpenAiCompatibleConfig(
      provider: provider,
      endpoint: provider.presetEndpoint,
      isMultimodal: provider.defaultIsMultimodal,
      extraParamsJson: provider.disabledThinkingExtraBodyJson,
    );
  }

  bool get isConfigured =>
      endpoint.trim().isNotEmpty && modelName.trim().isNotEmpty;

  Map<String, dynamic> get extraParams {
    final raw = extraParamsJson.trim();
    if (raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      return {};
    }
    return {};
  }

  OpenAiCompatibleConfig copyWith({
    OpenAiModelProvider? provider,
    String? endpoint,
    String? modelName,
    String? apiKey,
    bool? isMultimodal,
    String? extraParamsJson,
  }) {
    return OpenAiCompatibleConfig(
      provider: provider ?? this.provider,
      endpoint: endpoint ?? this.endpoint,
      modelName: modelName ?? this.modelName,
      apiKey: apiKey ?? this.apiKey,
      isMultimodal: isMultimodal ?? this.isMultimodal,
      extraParamsJson: extraParamsJson ?? this.extraParamsJson,
    );
  }

  Map<String, dynamic> toJson() => {
    'provider': provider.name,
    'endpoint': endpoint,
    'modelName': modelName,
    'apiKey': apiKey,
    'isMultimodal': isMultimodal,
    'extraParamsJson': extraParamsJson,
  };

  Map<String, dynamic> toSafeLogJson() => {
    'provider': provider.name,
    'endpoint': endpoint,
    'modelName': modelName,
    'apiKey': apiKey.isEmpty ? '' : '<redacted>',
    'isMultimodal': isMultimodal,
    'extraParamsJson': extraParamsJson,
  };

  factory OpenAiCompatibleConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const OpenAiCompatibleConfig.xiaomiMimoDefaults();
    return OpenAiCompatibleConfig(
      provider: OpenAiModelProviderCodec.fromName(json['provider'] as String?),
      endpoint: json['endpoint'] as String? ?? '',
      modelName: json['modelName'] as String? ?? '',
      apiKey: json['apiKey'] as String? ?? '',
      isMultimodal: json['isMultimodal'] as bool? ?? false,
      extraParamsJson: json['extraParamsJson'] as String? ?? emptyExtraBodyJson,
    );
  }
}

class LocalMnnConfig {
  final String modelName;

  const LocalMnnConfig({this.modelName = 'Qwen3.5-0.8B-MNN-Text-Only'});

  LocalMnnConfig copyWith({String? modelName}) {
    return LocalMnnConfig(modelName: modelName ?? this.modelName);
  }

  Map<String, dynamic> toJson() => {'modelName': modelName};

  factory LocalMnnConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const LocalMnnConfig();
    return LocalMnnConfig(
      modelName: json['modelName'] as String? ?? 'Qwen3.5-0.8B-MNN-Text-Only',
    );
  }
}

class LlmBackendConfig {
  final LlmBackendType backendType;
  final LocalMnnConfig local;
  final OpenAiCompatibleConfig cloud;
  final Map<OpenAiModelProvider, OpenAiCompatibleConfig> cloudConfigs;

  const LlmBackendConfig({
    this.backendType = LlmBackendType.unset,
    this.local = const LocalMnnConfig(),
    this.cloud = const OpenAiCompatibleConfig.xiaomiMimoDefaults(),
    this.cloudConfigs = const {},
  });

  bool get isConfigured {
    switch (backendType) {
      case LlmBackendType.unset:
        return false;
      case LlmBackendType.localMnn:
        return true;
      case LlmBackendType.openAiCompatible:
        return cloud.isConfigured;
    }
  }

  LlmBackendConfig copyWith({
    LlmBackendType? backendType,
    LocalMnnConfig? local,
    OpenAiCompatibleConfig? cloud,
    Map<OpenAiModelProvider, OpenAiCompatibleConfig>? cloudConfigs,
  }) {
    return LlmBackendConfig(
      backendType: backendType ?? this.backendType,
      local: local ?? this.local,
      cloud: cloud ?? this.cloud,
      cloudConfigs: cloudConfigs ?? this.cloudConfigs,
    );
  }

  OpenAiCompatibleConfig cloudConfigForProvider(OpenAiModelProvider provider) {
    final config = _normalizedCloudConfigs()[provider];
    return config ?? OpenAiCompatibleConfig.forProvider(provider);
  }

  Map<OpenAiModelProvider, OpenAiCompatibleConfig> _normalizedCloudConfigs() {
    final configs = <OpenAiModelProvider, OpenAiCompatibleConfig>{
      for (final provider in OpenAiModelProvider.values)
        provider: OpenAiCompatibleConfig.forProvider(provider),
    };
    for (final entry in cloudConfigs.entries) {
      configs[entry.key] = entry.value.copyWith(provider: entry.key);
    }
    configs[cloud.provider] = cloud;
    return configs;
  }

  LlmBackendConfig withCloudConfig(OpenAiCompatibleConfig config) {
    final configs = _normalizedCloudConfigs();
    configs[config.provider] = config;
    return copyWith(cloud: config, cloudConfigs: configs);
  }

  Map<String, dynamic> toJson() => {
    'backendType': backendType.name,
    'local': local.toJson(),
    'cloud': cloud.toJson(),
    'cloudConfigs': _normalizedCloudConfigs().map(
      (provider, config) => MapEntry(provider.name, config.toJson()),
    ),
  };

  Map<String, dynamic> toSafeLogJson() => {
    'backendType': backendType.name,
    'local': local.toJson(),
    'cloud': cloud.toSafeLogJson(),
    'cloudConfigs': _normalizedCloudConfigs().map(
      (provider, config) => MapEntry(provider.name, config.toSafeLogJson()),
    ),
  };

  factory LlmBackendConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const LlmBackendConfig();
    final cloud = OpenAiCompatibleConfig.fromJson(
      json['cloud'] as Map<String, dynamic>?,
    );
    return LlmBackendConfig(
      backendType: LlmBackendTypeCodec.fromName(json['backendType'] as String?),
      local: LocalMnnConfig.fromJson(json['local'] as Map<String, dynamic>?),
      cloud: cloud,
      cloudConfigs: _cloudConfigsFromJson(
        json['cloudConfigs'] as Map<String, dynamic>?,
        cloud,
      ),
    );
  }

  static Map<OpenAiModelProvider, OpenAiCompatibleConfig> _cloudConfigsFromJson(
    Map<String, dynamic>? json,
    OpenAiCompatibleConfig cloud,
  ) {
    final configs = <OpenAiModelProvider, OpenAiCompatibleConfig>{};
    if (json != null) {
      for (final entry in json.entries) {
        final provider = OpenAiModelProviderCodec.fromName(entry.key);
        final value = entry.value;
        if (value is Map) {
          configs[provider] = OpenAiCompatibleConfig.fromJson(
            value.map((key, value) => MapEntry(key.toString(), value)),
          ).copyWith(provider: provider);
        }
      }
    }
    configs[cloud.provider] = cloud;
    return configs;
  }
}

class LlmRequest {
  final String prompt;
  final Uint8List? imageBytes;
  final String? mimeType;
  final OcrType type;

  const LlmRequest.text({required this.prompt, this.type = OcrType.order})
    : imageBytes = null,
      mimeType = null;

  const LlmRequest.image({
    required this.prompt,
    required this.imageBytes,
    required this.mimeType,
    this.type = OcrType.order,
  });

  bool get hasImage => imageBytes != null && mimeType != null;
}

class LlmCompletion {
  final String text;

  const LlmCompletion({required this.text});
}

class LlmBackendStatus {
  final bool isAvailable;
  final bool isLoading;
  final String? message;

  const LlmBackendStatus({
    required this.isAvailable,
    this.isLoading = false,
    this.message,
  });
}

abstract class LlmBackend {
  Future<LlmBackendStatus> getStatus();

  Future<LlmCompletion> complete(LlmRequest request);
}

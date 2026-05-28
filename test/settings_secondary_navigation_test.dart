import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings routes model and storage management to secondary screens', () {
    final router = File('lib/router/app_router.dart').readAsStringSync();
    final settings = File(
      'lib/presentation/screens/settings/settings_screen.dart',
    ).readAsStringSync();

    expect(router, contains("path: '/settings/model-management'"));
    expect(router, contains("path: '/settings/storage'"));
    expect(settings, contains("context.push('/settings/model-management')"));
    expect(settings, contains("context.push('/settings/storage')"));
  });

  test('settings screen no longer inlines model and storage actions', () {
    final settings = File(
      'lib/presentation/screens/settings/settings_screen.dart',
    ).readAsStringSync();

    expect(settings, isNot(contains('_buildAiConfigSection')));
    expect(settings, isNot(contains('RadioGroup<LlmBackendType>')));
    expect(settings, isNot(contains('_endpointController')));
    expect(settings, isNot(contains('_downloadDefaultModel')));
    expect(settings, isNot(contains('_importModelZip')));
    expect(settings, isNot(contains('_deleteDownloadedModel')));
    expect(settings, isNot(contains('StorageRingChart')));
    expect(settings, isNot(contains('_clearCache')));
    expect(settings, isNot(contains('AppButton(')));
  });

  test('model management screen owns local and external model cards', () {
    final modelManagement = File(
      'lib/presentation/screens/settings/model_management_screen.dart',
    ).readAsStringSync();
    final llmBackend = File(
      'lib/data/models/llm_backend.dart',
    ).readAsStringSync();

    expect(modelManagement, contains("'本地模型'"));
    expect(modelManagement, contains("'外部模型'"));
    expect(modelManagement, contains('LlmBackendType.localMnn'));
    expect(modelManagement, contains('LlmBackendType.openAiCompatible'));
    expect(modelManagement, contains('_showInstallOptions'));
    expect(modelManagement, contains('_showModelDownloadDialog'));
    expect(modelManagement, contains('_saveExternalModel'));
    expect(modelManagement, contains('extra_body'));
    expect(modelManagement, contains("'模型提供商'"));
    expect(llmBackend, contains("'Xiaomi MiMo'"));
    expect(llmBackend, contains("'Deepseek'"));
    expect(llmBackend, contains("'其它 OpenAI 风格接口'"));
    expect(modelManagement, contains('_loadPresetModels'));
    expect(modelManagement, contains("'获取模型列表'"));
    expect(modelManagement, contains('Deepseek 目前不支持多模态'));
    expect(modelManagement, contains("'保存'"));
  });

  test(
    'model management screen removes old radio rows and local internals',
    () {
      final modelManagement = File(
        'lib/presentation/screens/settings/model_management_screen.dart',
      ).readAsStringSync();

      expect(modelManagement, isNot(contains('RadioListTile')));
      expect(modelManagement, isNot(contains('RadioGroup<LlmBackendType>')));
      expect(modelManagement, isNot(contains("'安装位置'")));
      expect(modelManagement, isNot(contains('_llmConfig.local.usage')));
      expect(
        modelManagement,
        isNot(contains('_resetUsage(LlmBackendType.localMnn')),
      );
      expect(modelManagement, isNot(contains('Token')));
      expect(modelManagement, isNot(contains('_resetCloudUsage')));
      expect(modelManagement, isNot(contains('_formatCompactNumber')));
      expect(modelManagement, contains('Switch.adaptive'));
      expect(modelManagement, contains("'模型名称'"));
      expect(modelManagement, contains("'安装'"));
      expect(modelManagement, contains("'重新安装'"));
      expect(modelManagement, contains("'从 ZIP 安装'"));
      expect(modelManagement, contains("'在线下载'"));
      expect(modelManagement, isNot(contains("'从压缩包安装'")));
      expect(modelManagement, isNot(contains("'直接下载'")));
      expect(modelManagement, contains('_ModelInstallChoice.downloadHfMirror'));
      expect(
        modelManagement,
        contains('_ModelInstallChoice.downloadHuggingFace'),
      );
      expect(modelManagement, contains('hf-mirror.com'));
      expect(modelManagement, contains('huggingface.co'));
      expect(modelManagement, contains('shouldCancel'));
      expect(modelManagement, contains('ModelDownloadCancelledException'));
      expect(modelManagement, isNot(contains('_buildRepositoryLink')));
      expect(modelManagement, isNot(contains('hf-mirror 项目页')));
      expect(modelManagement, contains('_buildInstallOptionButton'));
      expect(modelManagement, isNot(contains('minLines: 2')));
    },
  );

  test('model management screen gates backend switches by readiness', () {
    final modelManagement = File(
      'lib/presentation/screens/settings/model_management_screen.dart',
    ).readAsStringSync();

    expect(modelManagement, contains('_canEnableLocalModel'));
    expect(modelManagement, contains('_canEnableExternalModel'));
    expect(modelManagement, contains('status?.installed != true'));
    expect(modelManagement, contains('_currentCloudConfig.isConfigured'));
  });

  test(
    'model management screen keeps provider configs and gates model list',
    () {
      final modelManagement = File(
        'lib/presentation/screens/settings/model_management_screen.dart',
      ).readAsStringSync();

      expect(modelManagement, contains('_providerConfigs'));
      expect(modelManagement, contains('_updateCurrentProviderConfig'));
      expect(modelManagement, contains('填写 API key 后才可获取模型列表'));
      expect(
        modelManagement,
        contains('_apiKeyController.text.trim().isEmpty'),
      );
      expect(modelManagement, contains('onPressed: _canLoadPresetModels'));
      expect(
        modelManagement,
        contains('helperText: _selectedProvider.usesPreset'),
      );
      expect(modelManagement, isNot(contains('预置为关闭思考模式，随模型提供商自动维护')));
    },
  );

  test('model management screen shows API key errors directly', () {
    final modelManagement = File(
      'lib/presentation/screens/settings/model_management_screen.dart',
    ).readAsStringSync();

    expect(modelManagement, contains('e is OpenAiCompatibleException'));
    expect(modelManagement, contains('e.message'));
    expect(modelManagement, contains("'模型列表获取失败: \$e'"));
  });

  test('OCR configure dialog routes directly to model management', () {
    final orderEdit = File(
      'lib/presentation/screens/orders/order_edit_screen.dart',
    ).readAsStringSync();
    final invoiceEdit = File(
      'lib/presentation/screens/invoices/invoice_edit_screen.dart',
    ).readAsStringSync();

    for (final source in [orderEdit, invoiceEdit]) {
      expect(source, contains("context.push('/settings/model-management')"));
      expect(source, isNot(contains("context.push('/settings');")));
    }
  });

  test('storage management keeps chart and legend side by side', () {
    final storageManagement = File(
      'lib/presentation/screens/settings/storage_management_screen.dart',
    ).readAsStringSync();

    expect(storageManagement, contains('StorageRingChart'));
    expect(storageManagement, contains('StorageLegend'));
    expect(storageManagement, isNot(contains('constraints.maxWidth < 420')));
    expect(storageManagement, contains('Align('));
  });
}

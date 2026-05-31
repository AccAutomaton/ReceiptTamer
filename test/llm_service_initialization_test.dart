import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:receipt_tamer/data/models/llm_backend.dart';
import 'package:receipt_tamer/data/models/ocr_result.dart';
import 'package:receipt_tamer/data/services/llm_config_service.dart';
import 'package:receipt_tamer/data/services/llm_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.acautomaton.receipt.tamer/llm');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'waitForInitialization polls status instead of blocking native waitForLoaded',
    () async {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            if (call.method == 'getStatus') {
              return <String, dynamic>{
                'isLoading': false,
                'isInitialized': true,
                'archNotSupported': false,
              };
            }
            if (call.method == 'waitForLoaded') {
              throw StateError('waitForLoaded should not be called');
            }
            return null;
          });

      final service = LlmService();
      final initialized = await service.waitForInitialization(
        timeout: const Duration(seconds: 1),
      );

      expect(initialized, isTrue);
      expect(calls, equals(['getStatus']));
    },
  );

  test(
    'openai-compatible backend without endpoint and model is rejected early',
    () async {
      await LlmConfigService().save(
        const LlmBackendConfig(backendType: LlmBackendType.openAiCompatible),
      );
      final service = LlmService();

      final result = await service.extractStructuredDataFromText(
        '店铺 A\n实付 12.30',
        OcrType.order,
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('请先'));
    },
  );

  test(
    'preloadIfConfiguredLocalModel starts local backend immediately',
    () async {
      await LlmConfigService().save(
        const LlmBackendConfig(backendType: LlmBackendType.localMnn),
      );
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            if (call.method == 'initialize') {
              return <String, dynamic>{
                'isLoading': false,
                'isInitialized': true,
                'archNotSupported': false,
              };
            }
            return null;
          });

      final service = LlmService();
      final started = await service.preloadIfConfiguredLocalModel();
      await pumpEventQueue();

      expect(started, isTrue);
      expect(calls, contains('initialize'));
      expect(service.isInitialized, isTrue);
    },
  );

  test('preloadIfConfiguredLocalModel ignores non-local backend', () async {
    await LlmConfigService().save(
      const LlmBackendConfig(backendType: LlmBackendType.openAiCompatible),
    );
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return null;
        });

    final service = LlmService();
    final started = await service.preloadIfConfiguredLocalModel();
    await pumpEventQueue();

    expect(started, isFalse);
    expect(calls, isEmpty);
  });

  test('dispose cancels stale background load status updates', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'initialize') {
            return <String, dynamic>{
              'isLoading': true,
              'isInitialized': false,
              'archNotSupported': false,
            };
          }
          if (call.method == 'getStatus') {
            return <String, dynamic>{
              'isLoading': false,
              'isInitialized': true,
              'archNotSupported': false,
            };
          }
          if (call.method == 'disposeLlm') {
            return null;
          }
          return null;
        });

    final service = LlmService();
    await service.initialize();
    await pumpEventQueue();

    await service.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 650));

    expect(service.isInitialized, isFalse);
    expect(service.isModelLoading, isFalse);
    expect(
      calls.where((method) => method == 'disposeLlm').length,
      greaterThan(0),
    );
  });

  test('stale cancellation does not dispose a newer requested load', () async {
    var disposeCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'initialize') {
            return <String, dynamic>{
              'isLoading': true,
              'isInitialized': false,
              'archNotSupported': false,
            };
          }
          if (call.method == 'getStatus') {
            return <String, dynamic>{
              'isLoading': false,
              'isInitialized': true,
              'archNotSupported': false,
            };
          }
          if (call.method == 'disposeLlm') {
            disposeCalls++;
            return null;
          }
          return null;
        });

    final service = LlmService();
    await service.initialize();
    await pumpEventQueue();
    await service.dispose();
    await service.initialize();
    await pumpEventQueue();

    await Future<void>.delayed(const Duration(milliseconds: 650));

    expect(service.isInitialized, isTrue);
    expect(disposeCalls, 1);
  });
}

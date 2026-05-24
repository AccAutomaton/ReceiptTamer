import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/data/services/llm_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.acautomaton.receipt.tamer/llm');

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
}

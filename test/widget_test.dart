// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:receipt_tamer/app.dart';
import 'package:receipt_tamer/data/models/llm_backend.dart';
import 'package:receipt_tamer/data/services/llm_config_service.dart';

void main() {
  const llmChannel = MethodChannel('com.acautomaton.receipt.tamer/llm');
  const shareMethodChannel = MethodChannel('receive_sharing_intent/messages');
  const shareEventChannel = MethodChannel(
    'receive_sharing_intent/events-media',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareMethodChannel, (call) async {
          if (call.method == 'getInitialMedia') return '[]';
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareEventChannel, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(llmChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareMethodChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareEventChannel, null);
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(child: App(enableBackgroundInitialization: false)),
    );

    // Render one frame; background services are covered outside this smoke test.
    await tester.pump();

    // Verify that the home screen loads with the expected title.
    expect(find.text('首页'), findsWidgets);
  });

  testWidgets('App preloads local model after startup when configured', (
    WidgetTester tester,
  ) async {
    await LlmConfigService().save(
      const LlmBackendConfig(backendType: LlmBackendType.localMnn),
    );
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(llmChannel, (call) async {
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

    await tester.pumpWidget(const ProviderScope(child: App()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();

    expect(calls, contains('initialize'));

    await tester.pump(const Duration(milliseconds: 700));
  });
}

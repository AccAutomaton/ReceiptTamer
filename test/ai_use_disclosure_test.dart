import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/data/models/llm_backend.dart';
import 'package:receipt_tamer/presentation/utils/ai_use_disclosure.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('analysis chooser explains speed privacy and cost in place', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showAiAnalysisChoiceDialog(context),
              child: const Text('选择方式'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('选择方式'));
    await tester.pumpAndSettle();

    expect(find.text('纯手工'), findsOneWidget);
    expect(find.text('本地模型'), findsOneWidget);
    expect(find.text('云端模型'), findsOneWidget);
    expect(find.textContaining('数据不离开设备'), findsOneWidget);
    expect(find.textContaining('首次下载和加载较慢'), findsOneWidget);
    expect(find.textContaining('可能产生服务商费用'), findsOneWidget);
  });

  testWidgets(
    'first cloud upload names the destination host and is remembered',
    (tester) async {
      const config = LlmBackendConfig(
        backendType: LlmBackendType.openAiCompatible,
        cloud: OpenAiCompatibleConfig(
          endpoint: 'https://api.example.com/v1',
          modelName: 'example-model',
          isMultimodal: true,
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: _CloudConsentProbe(config: config)),
        ),
      );

      await tester.tap(find.text('开始上传'));
      await tester.pumpAndSettle();

      expect(find.text('首次云端上传确认'), findsOneWidget);
      expect(find.textContaining('api.example.com'), findsOneWidget);
      expect(find.textContaining('订单图片'), findsOneWidget);

      await tester.tap(find.text('确认并上传'));
      await tester.pumpAndSettle();
      expect(find.text('结果:true'), findsOneWidget);

      await tester.tap(find.text('开始上传'));
      await tester.pumpAndSettle();
      expect(find.text('首次云端上传确认'), findsNothing);
      expect(find.text('结果:true'), findsOneWidget);
    },
  );
}

class _CloudConsentProbe extends StatefulWidget {
  const _CloudConsentProbe({required this.config});

  final LlmBackendConfig config;

  @override
  State<_CloudConsentProbe> createState() => _CloudConsentProbeState();
}

class _CloudConsentProbeState extends State<_CloudConsentProbe> {
  bool? _result;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FilledButton(
          onPressed: () async {
            final result = await confirmCloudUploadIfNeeded(
              context,
              config: widget.config,
              content: CloudUploadContent.orderImage,
            );
            if (mounted) setState(() => _result = result);
          },
          child: const Text('开始上传'),
        ),
        Text('结果:${_result ?? '-'}'),
      ],
    );
  }
}

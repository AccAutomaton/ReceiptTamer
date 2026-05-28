import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OCR provider only blocks unsupported ABI for local MNN backend', () {
    final source = File(
      'lib/presentation/providers/ocr_provider.dart',
    ).readAsStringSync();
    final localMnnArchChecks = RegExp(
      r'backendConfig\.backendType\s*==\s*LlmBackendType\.localMnn[\s\S]{0,120}'
      r'llmService\?\.archNotSupported\s*==\s*true',
    ).allMatches(source);

    expect(localMnnArchChecks.length, 3);
    expect(
      source,
      isNot(contains('if (llmService?.archNotSupported == true)')),
    );
  });
}

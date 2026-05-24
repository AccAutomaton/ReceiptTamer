import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recognition entry UI uses spaced OCR wording', () {
    const files = [
      'lib/presentation/screens/orders/order_edit_screen.dart',
      'lib/presentation/screens/invoices/invoice_edit_screen.dart',
      'lib/core/constants/app_constants.dart',
      'lib/app.dart',
    ];
    const staleUserFacingPhrases = [
      'OCR识别',
      'AI识别',
      '本地AI识别',
      '开始OCR',
      'OCR 后台初始化',
    ];

    for (final filePath in files) {
      final source = File(filePath).readAsStringSync();
      for (final phrase in staleUserFacingPhrases) {
        expect(
          source.contains(phrase),
          isFalse,
          reason: '$filePath should not contain stale user-facing "$phrase"',
        );
      }
    }

    final constants = File(
      'lib/core/constants/app_constants.dart',
    ).readAsStringSync();
    expect(constants, contains("btnOCR = 'OCR 识别'"));
  });
}

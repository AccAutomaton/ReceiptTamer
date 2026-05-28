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

  test('OCR buttons and dialogs are driven by recognition state', () {
    final orderScreen = File(
      'lib/presentation/screens/orders/order_edit_screen.dart',
    ).readAsStringSync();
    final invoiceScreen = File(
      'lib/presentation/screens/invoices/invoice_edit_screen.dart',
    ).readAsStringSync();
    final provider = File(
      'lib/presentation/providers/ocr_provider.dart',
    ).readAsStringSync();

    for (final source in [orderScreen, invoiceScreen]) {
      expect(source, contains('final isRecognizing = ocrState.isLoading;'));
      expect(
        source,
        contains('final isOcrButtonBusy = isRecognizing || isModelLoading;'),
      );
      expect(source, contains('onPressed: (_isLoading || isOcrButtonBusy)'));
      expect(source, contains('icon: isOcrButtonBusy'));
      expect(source, contains('isRecognizing'));
      expect(source, contains('OcrStage.imageRecognizing'));
      expect(source, contains('isDirectVisionStage'));
      expect(source, contains("'图片理解'"));
    }

    expect(provider, contains('imageRecognizing'));
    expect(provider, contains('OcrStage.imageRecognizing'));
    expect(provider, contains('OcrStage.imageRecognizing => 0.0'));
    expect(provider, contains('OcrStage.imageRecognizing => 1.0'));
  });

  test('recognition terminal states clear stale model loading state', () {
    final provider = File(
      'lib/presentation/providers/ocr_provider.dart',
    ).readAsStringSync();
    final copyWithCalls = RegExp(
      r'state = state\.copyWith\(([\s\S]*?)\);',
      multiLine: true,
    ).allMatches(provider);

    for (final match in copyWithCalls) {
      final block = match.group(1)!;
      if (!block.contains('isLoading: false')) {
        continue;
      }

      expect(
        block,
        contains('isModelLoading: false'),
        reason:
            'Any terminal recognition state must clear stale model loading: ${block.trim()}',
      );
    }
  });
}

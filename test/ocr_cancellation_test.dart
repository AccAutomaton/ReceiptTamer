import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/data/models/ocr_result.dart';
import 'package:receipt_tamer/data/services/ocr_service.dart';
import 'package:receipt_tamer/presentation/providers/ocr_provider.dart';

void main() {
  test('cancelled recognition cannot publish its late result', () async {
    final service = _DelayedOcrService();
    final container = ProviderContainer(
      overrides: [ocrServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(ocrProvider.notifier);
    final recognition = notifier.recognizeFromBytes(
      Uint8List.fromList([1]),
      OcrType.order,
    );
    expect(container.read(ocrProvider).isLoading, isTrue);

    notifier.cancelRecognition();
    expect(container.read(ocrProvider).isLoading, isFalse);
    expect(container.read(ocrProvider).result, isNull);

    service.completeNext(OcrResult.orderSuccess(shopName: '迟到结果', amount: 10));
    await recognition;

    expect(container.read(ocrProvider).isLoading, isFalse);
    expect(container.read(ocrProvider).result, isNull);
  });

  test('an older operation cannot overwrite a newer recognition', () async {
    final service = _DelayedOcrService();
    final container = ProviderContainer(
      overrides: [ocrServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(ocrProvider.notifier);
    final first = notifier.recognizeFromBytes(
      Uint8List.fromList([1]),
      OcrType.order,
    );
    final second = notifier.recognizeFromBytes(
      Uint8List.fromList([2]),
      OcrType.order,
    );

    service.completeAt(1, OcrResult.orderSuccess(shopName: '新结果', amount: 20));
    await second;
    expect(container.read(ocrProvider).result?.shopName, '新结果');

    service.completeAt(0, OcrResult.orderSuccess(shopName: '旧结果', amount: 10));
    await first;
    expect(container.read(ocrProvider).result?.shopName, '新结果');
  });
}

class _DelayedOcrService extends OcrService {
  final List<Completer<OcrResult>> _requests = [];

  @override
  Future<OcrResult> recognizeFromBytes(Uint8List imageBytes, OcrType type) {
    final request = Completer<OcrResult>();
    _requests.add(request);
    return request.future;
  }

  void completeNext(OcrResult result) {
    _requests.firstWhere((request) => !request.isCompleted).complete(result);
  }

  void completeAt(int index, OcrResult result) {
    _requests[index].complete(result);
  }
}

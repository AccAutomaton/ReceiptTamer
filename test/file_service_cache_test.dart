import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:receipt_tamer/data/services/file_service.dart';
import 'package:receipt_tamer/data/services/model_asset_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  const storageChannel = MethodChannel('com.acautomaton.receipt.tamer/storage');
  late Directory rootDir;
  late Directory docsDir;
  late Directory filesDir;
  late Directory tempDir;

  setUp(() async {
    rootDir = await Directory.systemTemp.createTemp(
      'receipt_tamer_file_service_test_',
    );
    docsDir = Directory(p.join(rootDir.path, 'docs'))..createSync();
    filesDir = Directory(p.join(rootDir.path, 'files'))..createSync();
    tempDir = Directory(p.join(rootDir.path, 'cache'))..createSync();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          return switch (call.method) {
            'getApplicationDocumentsDirectory' => docsDir.path,
            'getTemporaryDirectory' => tempDir.path,
            _ => null,
          };
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
          return switch (call.method) {
            'getFilesDirPath' => filesDir.path,
            _ => null,
          };
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
    if (await rootDir.exists()) {
      await rootDir.delete(recursive: true);
    }
  });

  test(
    'model download cache is counted as cache storage and cleaned as temp files',
    () async {
      final downloadDir = Directory(
        p.join(tempDir.path, '${ModelAssetService.modelDirName}.download'),
      )..createSync(recursive: true);
      await File(
        p.join(downloadDir.path, 'llm.mnn.weight.part'),
      ).writeAsBytes([1, 2, 3]);
      await File(
        p.join(downloadDir.path, 'llm.mnn.weight.part.json'),
      ).writeAsString('{"etag":"weight"}');

      final service = FileService();

      final beforeUsage = await service.getStorageUsage();
      expect(beforeUsage['cache'], 20);

      final deletedCount = await service.cleanTempFiles();
      final afterUsage = await service.getStorageUsage();

      expect(deletedCount, 2);
      expect(afterUsage['cache'], 0);
      expect(await downloadDir.exists(), isFalse);
    },
  );

  test('legacy APK-extracted model directory is counted as model storage', () async {
    final modelDir = Directory(
      p.join(filesDir.path, ModelAssetService.modelDirName),
    )..createSync(recursive: true);
    await File(p.join(modelDir.path, 'llm_config.json')).writeAsString('{}');
    await File(p.join(modelDir.path, 'llm.mnn')).writeAsBytes([1, 2]);
    await File(p.join(modelDir.path, 'llm.mnn.weight')).writeAsBytes([3, 4, 5]);
    await File(p.join(modelDir.path, 'tokenizer.txt')).writeAsString('token');

    final usage = await FileService().getStorageUsage();

    expect(usage['model'], 12);
  });
}

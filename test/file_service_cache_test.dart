import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:receipt_tamer/data/services/file_service.dart';
import 'package:receipt_tamer/data/services/model_asset_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory rootDir;
  late Directory docsDir;
  late Directory tempDir;

  setUp(() async {
    rootDir = await Directory.systemTemp.createTemp(
      'receipt_tamer_file_service_test_',
    );
    docsDir = Directory(p.join(rootDir.path, 'docs'))..createSync();
    tempDir = Directory(p.join(rootDir.path, 'cache'))..createSync();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          return switch (call.method) {
            'getApplicationDocumentsDirectory' => docsDir.path,
            'getTemporaryDirectory' => tempDir.path,
            _ => null,
          };
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
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
}

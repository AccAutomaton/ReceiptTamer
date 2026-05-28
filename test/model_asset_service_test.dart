import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

import 'package:receipt_tamer/data/services/model_asset_service.dart';

void main() {
  late Directory tempDir;
  late Directory filesDir;
  late Directory cacheDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'receipt_tamer_model_test_',
    );
    filesDir = Directory(p.join(tempDir.path, 'files'))..createSync();
    cacheDir = Directory(p.join(tempDir.path, 'cache'))..createSync();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'local zip import normalizes single root folder and validates files',
    () async {
      final zipPath = await _createModelZip(
        tempDir,
        rootName: 'Qwen3.5-0.8B-MNN-Text-Only',
      );
      final service = ModelAssetService(
        filesDirOverride: filesDir,
        cacheDirOverride: cacheDir,
        minWeightBytes: 1,
      );

      final result = await service.importZip(zipPath: zipPath);

      expect(result.installed, isTrue);
      expect(
        await File(p.join(filesDir.path, 'qwen3.5-0.8b', 'llm.mnn')).exists(),
        isTrue,
      );
      expect(
        await File(zipPath).exists(),
        isTrue,
        reason: 'user-selected source zip must not be deleted',
      );
    },
  );

  test(
    'online install downloads required model files from Hugging Face sources',
    () async {
      final requestedUrls = <String>[];
      final progressEvents = <ModelDownloadProgress>[];
      final service = ModelAssetService(
        filesDirOverride: filesDir,
        cacheDirOverride: cacheDir,
        minWeightBytes: 1,
        repositoryUrls: [
          Uri.parse('https://hf-mirror.com/acautomaton/model'),
          Uri.parse('https://huggingface.co/acautomaton/model'),
        ],
        client: MockClient((request) async {
          requestedUrls.add(request.url.toString());
          final fileName = request.url.pathSegments.last;
          return http.Response.bytes(_modelFileBytes(fileName), 200);
        }),
      );

      final result = await service.downloadDefaultModel(
        resume: true,
        onProgress: progressEvents.add,
      );

      expect(result.installed, isTrue);
      expect(requestedUrls, [
        'https://hf-mirror.com/acautomaton/model/resolve/main/llm_config.json?download=true',
        'https://hf-mirror.com/acautomaton/model/resolve/main/llm.mnn?download=true',
        'https://hf-mirror.com/acautomaton/model/resolve/main/llm.mnn.weight?download=true',
        'https://hf-mirror.com/acautomaton/model/resolve/main/tokenizer.txt?download=true',
      ]);
      expect(progressEvents, isNotEmpty);
      expect(progressEvents.first.fileIndex, 1);
      expect(progressEvents.first.fileCount, 4);
      expect(progressEvents.first.sourceHost, 'hf-mirror.com');
      expect(progressEvents.last.fileName, 'tokenizer.txt');
      expect(
        await File(
          p.join(filesDir.path, 'qwen3.5-0.8b', 'tokenizer.txt'),
        ).exists(),
        isTrue,
      );
    },
  );

  test(
    'online install can use an explicitly selected repository source',
    () async {
      final requestedUrls = <String>[];
      final service = ModelAssetService(
        filesDirOverride: filesDir,
        cacheDirOverride: cacheDir,
        minWeightBytes: 1,
        repositoryUrls: [Uri.parse('https://hf-mirror.com/acautomaton/model')],
        client: MockClient((request) async {
          requestedUrls.add(request.url.toString());
          return http.Response.bytes(
            _modelFileBytes(request.url.pathSegments.last),
            200,
          );
        }),
      );

      final result = await service.downloadDefaultModel(
        repositoryUrl: Uri.parse('https://huggingface.co/acautomaton/model'),
      );

      expect(result.installed, isTrue);
      expect(
        requestedUrls.first,
        'https://huggingface.co/acautomaton/model/resolve/main/llm_config.json?download=true',
      );
      expect(
        requestedUrls.every((url) => url.startsWith('https://huggingface.co/')),
        isTrue,
      );
    },
  );

  test(
    'online install skips valid cached files and redownloads invalid files',
    () async {
      final downloadDir = Directory(
        p.join(cacheDir.path, '${ModelAssetService.modelDirName}.download'),
      )..createSync(recursive: true);
      await File(
        p.join(downloadDir.path, 'llm_config.json'),
      ).writeAsString('{}');
      await File(p.join(downloadDir.path, 'llm.mnn')).writeAsBytes([1]);
      await File(p.join(downloadDir.path, 'llm.mnn.weight')).writeAsBytes([1]);
      await File(
        p.join(downloadDir.path, 'tokenizer.txt'),
      ).writeAsString('tokenizer');

      final requestedFiles = <String>[];
      final progressEvents = <ModelDownloadProgress>[];
      final service = ModelAssetService(
        filesDirOverride: filesDir,
        cacheDirOverride: cacheDir,
        minWeightBytes: 3,
        repositoryUrls: [Uri.parse('https://hf-mirror.com/acautomaton/model')],
        client: MockClient((request) async {
          requestedFiles.add(request.url.pathSegments.last);
          return http.Response.bytes(
            _modelFileBytes(request.url.pathSegments.last),
            200,
          );
        }),
      );

      final result = await service.downloadDefaultModel(
        resume: true,
        onProgress: progressEvents.add,
      );

      expect(result.installed, isTrue);
      expect(requestedFiles, ['llm.mnn.weight']);
      expect(
        progressEvents
            .where((event) => event.skipped)
            .map((event) => event.fileName),
        containsAll(['llm_config.json', 'llm.mnn', 'tokenizer.txt']),
      );
      expect(
        await File(
          p.join(filesDir.path, 'qwen3.5-0.8b', 'llm.mnn.weight'),
        ).readAsBytes(),
        [1, 2, 3],
      );
    },
  );

  test(
    'install restores existing model directory if promotion fails',
    () async {
      final installedDir = Directory(
        p.join(filesDir.path, ModelAssetService.modelDirName),
      )..createSync(recursive: true);
      await _writeModelFiles(installedDir, weightBytes: [9, 9, 9]);
      final zipPath = await _createModelZip(tempDir);
      final service = ModelAssetService(
        filesDirOverride: filesDir,
        cacheDirOverride: cacheDir,
        minWeightBytes: 1,
        beforePromoteForTesting: () async {
          throw StateError('simulated promotion failure');
        },
      );

      await expectLater(
        service.importZip(zipPath: zipPath),
        throwsA(
          predicate(
            (Object error) =>
                error.toString().contains('simulated promotion failure'),
          ),
        ),
      );

      expect(await installedDir.exists(), isTrue);
      expect(
        await File(p.join(installedDir.path, 'llm.mnn.weight')).readAsBytes(),
        [9, 9, 9],
      );
      expect(
        await Directory(
          p.join(filesDir.path, '${ModelAssetService.modelDirName}.old'),
        ).exists(),
        isFalse,
      );
    },
  );

  test('file download resumes an interrupted model file with Range', () async {
    final partialBytes = [1, 2];
    final remainingBytes = [3, 4];
    final partFile = File(
      p.join(
        cacheDir.path,
        '${ModelAssetService.modelDirName}.download',
        'llm.mnn.weight.part',
      ),
    );
    await partFile.create(recursive: true);
    await partFile.writeAsBytes(partialBytes);
    await File(
      '${partFile.path}.json',
    ).writeAsString(jsonEncode({'etag': '"weight-etag"'}));

    late Map<String, String> capturedHeaders;
    final service = ModelAssetService(
      filesDirOverride: filesDir,
      cacheDirOverride: cacheDir,
      minWeightBytes: 1,
      repositoryUrls: [Uri.parse('https://hf-mirror.com/acautomaton/model')],
      client: MockClient((request) async {
        if (request.url.pathSegments.last != 'llm.mnn.weight') {
          return http.Response.bytes(
            _modelFileBytes(request.url.pathSegments.last),
            200,
          );
        }
        capturedHeaders = request.headers;
        return http.Response.bytes(
          remainingBytes,
          206,
          headers: {'etag': '"weight-etag"', 'content-range': 'bytes 2-3/4'},
        );
      }),
    );

    final result = await service.downloadDefaultModel(resume: true);

    expect(result.installed, isTrue);
    expect(capturedHeaders['range'], 'bytes=2-');
    expect(capturedHeaders['if-range'], '"weight-etag"');
    expect(
      await File(
        p.join(filesDir.path, 'qwen3.5-0.8b', 'llm.mnn.weight'),
      ).readAsBytes(),
      [1, 2, 3, 4],
    );
  });

  test(
    'file download restarts partial file when server ignores Range',
    () async {
      final partFile = File(
        p.join(
          cacheDir.path,
          '${ModelAssetService.modelDirName}.download',
          'llm.mnn.weight.part',
        ),
      );
      await partFile.create(recursive: true);
      await partFile.writeAsBytes([1, 2]);
      await File(
        '${partFile.path}.json',
      ).writeAsString(jsonEncode({'etag': '"weight-etag"'}));

      final service = ModelAssetService(
        filesDirOverride: filesDir,
        cacheDirOverride: cacheDir,
        minWeightBytes: 1,
        repositoryUrls: [Uri.parse('https://hf-mirror.com/acautomaton/model')],
        client: MockClient((request) async {
          if (request.url.pathSegments.last != 'llm.mnn.weight') {
            return http.Response.bytes(
              _modelFileBytes(request.url.pathSegments.last),
              200,
            );
          }
          return http.Response.bytes([9], 200, headers: {'etag': '"new-etag"'});
        }),
      );

      final result = await service.downloadDefaultModel(resume: true);

      expect(result.installed, isTrue);
      expect(
        await File(
          p.join(filesDir.path, 'qwen3.5-0.8b', 'llm.mnn.weight'),
        ).readAsBytes(),
        [9],
      );
    },
  );

  test('download cancellation keeps partial progress for retry', () async {
    var cancelRequested = false;
    final service = ModelAssetService(
      filesDirOverride: filesDir,
      cacheDirOverride: cacheDir,
      minWeightBytes: 1,
      repositoryUrls: [Uri.parse('https://hf-mirror.com/acautomaton/model')],
      client: _ChunkedClient([
        [1, 2],
        [3, 4],
      ]),
    );

    await expectLater(
      service.downloadDefaultModel(
        shouldCancel: () => cancelRequested,
        onProgress: (_) => cancelRequested = true,
      ),
      throwsA(isA<ModelDownloadCancelledException>()),
    );

    final downloadDir = p.join(
      cacheDir.path,
      '${ModelAssetService.modelDirName}.download',
    );
    expect(
      await File(p.join(downloadDir, 'llm_config.json.part')).readAsBytes(),
      [1, 2],
    );
    expect(
      await File(p.join(downloadDir, 'llm_config.json')).exists(),
      isFalse,
    );
  });
}

Future<String> _createModelZip(
  Directory tempDir, {
  String rootName = 'qwen3.5-0.8b',
}) async {
  final modelDir = Directory(p.join(tempDir.path, rootName))..createSync();
  await _writeModelFiles(modelDir);

  final zipPath = p.join(
    tempDir.path,
    '${DateTime.now().microsecondsSinceEpoch}.zip',
  );
  final encoder = ZipFileEncoder();
  encoder.create(zipPath);
  encoder.addDirectorySync(modelDir, includeDirName: true);
  encoder.closeSync();
  return zipPath;
}

Future<void> _writeModelFiles(
  Directory modelDir, {
  List<int> weightBytes = const [1, 2, 3],
}) async {
  await File(p.join(modelDir.path, 'llm_config.json')).writeAsString('{}');
  await File(p.join(modelDir.path, 'llm.mnn')).writeAsBytes([1]);
  await File(p.join(modelDir.path, 'llm.mnn.weight')).writeAsBytes(weightBytes);
  await File(p.join(modelDir.path, 'tokenizer.txt')).writeAsString('tokenizer');
}

List<int> _modelFileBytes(String fileName) {
  switch (fileName) {
    case 'llm_config.json':
      return utf8.encode('{}');
    case 'llm.mnn':
      return [1];
    case 'llm.mnn.weight':
      return [1, 2, 3];
    case 'tokenizer.txt':
      return utf8.encode('tokenizer');
    default:
      return utf8.encode('unexpected $fileName');
  }
}

class _ChunkedClient extends http.BaseClient {
  final List<List<int>> chunks;

  _ChunkedClient(this.chunks);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final controller = StreamController<List<int>>();
    Future<void>(() async {
      for (final chunk in chunks) {
        controller.add(chunk);
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      await controller.close();
    });
    final totalLength = chunks.fold<int>(
      0,
      (total, chunk) => total + chunk.length,
    );
    return http.StreamedResponse(
      controller.stream,
      200,
      contentLength: totalLength,
    );
  }
}

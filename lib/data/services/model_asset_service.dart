import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../core/services/log_config.dart';
import '../../core/services/log_service.dart';
import 'file_service.dart';

enum ModelAssetState { missing, installed, invalid, downloading }

class ModelAssetStatus {
  final ModelAssetState state;
  final String modelPath;
  final int sizeBytes;
  final String? errorMessage;

  const ModelAssetStatus({
    required this.state,
    required this.modelPath,
    this.sizeBytes = 0,
    this.errorMessage,
  });

  bool get installed => state == ModelAssetState.installed;
}

class ModelInstallResult {
  final bool installed;
  final String modelPath;
  final int sizeBytes;

  const ModelInstallResult({
    required this.installed,
    required this.modelPath,
    required this.sizeBytes,
  });
}

class ModelDownloadCancelledException implements Exception {
  const ModelDownloadCancelledException();

  @override
  String toString() => 'Model download cancelled';
}

class ModelDownloadProgress {
  final int downloadedBytes;
  final int totalBytes;
  final double progress;
  final int speedBytesPerSecond;
  final bool wasResumed;
  final int fileIndex;
  final int fileCount;
  final String fileName;
  final String sourceHost;
  final bool skipped;

  const ModelDownloadProgress({
    required this.downloadedBytes,
    required this.totalBytes,
    required this.progress,
    required this.speedBytesPerSecond,
    required this.wasResumed,
    required this.fileIndex,
    required this.fileCount,
    required this.fileName,
    required this.sourceHost,
    this.skipped = false,
  });
}

class ModelAssetService {
  static const String modelDirName = 'qwen3.5-0.8b';
  static const List<String> requiredModelFiles = [
    'llm_config.json',
    'llm.mnn',
    'llm.mnn.weight',
    'tokenizer.txt',
  ];

  static final Uri hfMirrorRepositoryUrl = Uri.parse(
    'https://hf-mirror.com/acautomaton/Qwen3.5-0.8B-MNN-Text-Only',
  );
  static final Uri huggingFaceRepositoryUrl = Uri.parse(
    'https://huggingface.co/acautomaton/Qwen3.5-0.8B-MNN-Text-Only',
  );

  static final List<Uri> defaultRepositoryUrls = [
    hfMirrorRepositoryUrl,
    huggingFaceRepositoryUrl,
  ];

  final http.Client _client;
  final List<Uri> _repositoryUrls;
  final Directory? _filesDirOverride;
  final Directory? _cacheDirOverride;
  final int minWeightBytes;
  final Future<void> Function()? disposeBeforeDelete;
  final Future<void> Function()? beforePromoteForTesting;

  ModelAssetService({
    http.Client? client,
    List<Uri>? repositoryUrls,
    Directory? filesDirOverride,
    Directory? cacheDirOverride,
    this.minWeightBytes = 400000000,
    this.disposeBeforeDelete,
    this.beforePromoteForTesting,
  }) : _client = client ?? http.Client(),
       _repositoryUrls = repositoryUrls ?? defaultRepositoryUrls,
       _filesDirOverride = filesDirOverride,
       _cacheDirOverride = cacheDirOverride;

  Future<ModelAssetStatus> getStatus() async {
    final modelDir = await _modelDir();
    if (!await modelDir.exists()) {
      return ModelAssetStatus(
        state: ModelAssetState.missing,
        modelPath: modelDir.path,
      );
    }
    final size = await _directorySize(modelDir);
    final valid = await _isModelDirValid(modelDir);
    return ModelAssetStatus(
      state: valid ? ModelAssetState.installed : ModelAssetState.invalid,
      modelPath: modelDir.path,
      sizeBytes: size,
      errorMessage: valid ? null : '模型文件不完整',
    );
  }

  Future<ModelInstallResult> downloadDefaultModel({
    bool resume = true,
    Uri? repositoryUrl,
    void Function(ModelDownloadProgress progress)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    Object? lastError;
    final repositories = repositoryUrl != null
        ? [repositoryUrl]
        : _repositoryUrls;
    for (final repositoryUrl in repositories) {
      try {
        final modelDir = await _downloadRepositoryToCache(
          repositoryUrl,
          resume: resume,
          onProgress: onProgress,
          shouldCancel: shouldCancel,
        );
        return await _installModelDirectory(modelDir, appOwnedSource: true);
      } on ModelDownloadCancelledException {
        rethrow;
      } catch (e, stackTrace) {
        lastError = e;
        logService.w(
          LogConfig.moduleLlm,
          '模型下载失败，尝试下一个源: $repositoryUrl, error=$e',
        );
        logService.d(LogConfig.moduleLlm, stackTrace.toString());
      }
    }
    throw StateError('模型下载失败: $lastError');
  }

  Future<int> getExistingDownloadSize() async {
    final cacheDir = await _cacheDir();
    final downloadDir = Directory(
      path.join(cacheDir.path, '$modelDirName.download'),
    );
    if (!await downloadDir.exists()) return 0;
    var total = 0;
    await for (final entity in downloadDir.list(recursive: true)) {
      if (entity is File &&
          (entity.path.endsWith('.part') ||
              requiredModelFiles.contains(path.basename(entity.path)))) {
        total += await entity.length();
      }
    }
    return total;
  }

  Future<ModelInstallResult> importZip({String? zipPath}) async {
    String? selectedPath = zipPath;
    if (selectedPath == null) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      selectedPath = result?.files.single.path;
    }
    if (selectedPath == null || selectedPath.isEmpty) {
      throw StateError('未选择模型压缩包');
    }

    final sourceZip = File(selectedPath);
    if (!await sourceZip.exists()) {
      throw StateError('模型压缩包不存在: $selectedPath');
    }

    final cacheDir = await _cacheDir();
    await cacheDir.create(recursive: true);
    final copiedZip = File(
      path.join(
        cacheDir.path,
        'import_${DateTime.now().millisecondsSinceEpoch}.zip',
      ),
    );
    await sourceZip.copy(copiedZip.path);
    return _installZip(copiedZip, appOwnedZip: true);
  }

  Future<bool> deleteDownloadedModel() async {
    await disposeBeforeDelete?.call();
    final dir = await _modelDir();
    if (!await dir.exists()) return false;
    await dir.delete(recursive: true);
    return true;
  }

  Future<int> getDownloadedModelSize() async {
    return _directorySize(await _modelDir());
  }

  Future<Directory> _downloadRepositoryToCache(
    Uri repositoryUrl, {
    required bool resume,
    void Function(ModelDownloadProgress progress)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    final cacheDir = await _cacheDir();
    final downloadDir = Directory(
      path.join(cacheDir.path, '$modelDirName.download'),
    );
    await downloadDir.create(recursive: true);

    var completedBytes = 0;
    for (var index = 0; index < requiredModelFiles.length; index++) {
      _throwIfCancelled(shouldCancel);
      final fileName = requiredModelFiles[index];
      final fileIndex = index + 1;
      final fileUrl = _resolveModelFileUrl(repositoryUrl, fileName);
      final targetFile = File(path.join(downloadDir.path, fileName));

      if (resume && await _isModelFileValid(targetFile, fileName)) {
        completedBytes += await targetFile.length();
        onProgress?.call(
          ModelDownloadProgress(
            downloadedBytes: completedBytes,
            totalBytes: completedBytes,
            progress: 1.0,
            speedBytesPerSecond: 0,
            wasResumed: true,
            fileIndex: fileIndex,
            fileCount: requiredModelFiles.length,
            fileName: fileName,
            sourceHost: repositoryUrl.host,
            skipped: true,
          ),
        );
        continue;
      }

      await _downloadFileToCache(
        fileUrl,
        targetFile,
        resume: resume,
        completedBytes: completedBytes,
        onProgress: onProgress,
        shouldCancel: shouldCancel,
        fileIndex: fileIndex,
        fileCount: requiredModelFiles.length,
        fileName: fileName,
        sourceHost: repositoryUrl.host,
      );
      if (!await _isModelFileValid(targetFile, fileName)) {
        throw StateError('妯″瀷鏂囦欢鏍￠獙澶辫触: $fileName');
      }
      completedBytes += await targetFile.length();
    }

    return downloadDir;
  }

  Future<File> _downloadFileToCache(
    Uri url,
    File targetFile, {
    required bool resume,
    required int completedBytes,
    void Function(ModelDownloadProgress progress)? onProgress,
    bool Function()? shouldCancel,
    required int fileIndex,
    required int fileCount,
    required String fileName,
    required String sourceHost,
  }) async {
    _throwIfCancelled(shouldCancel);
    await targetFile.parent.create(recursive: true);

    final partFile = File('${targetFile.path}.part');
    final metaFile = File('${partFile.path}.json');

    if (!resume) {
      await _deleteIfExists(partFile);
      await _deleteIfExists(metaFile);
    }

    final metadata = await _readDownloadMetadata(metaFile);
    if (metadata['url'] != null && metadata['url'] != url.toString()) {
      await _deleteIfExists(partFile);
      await _deleteIfExists(metaFile);
      metadata.clear();
    }

    final request = http.Request('GET', url);
    final partLength = await partFile.exists() ? await partFile.length() : 0;
    final validator = metadata['etag'] ?? metadata['lastModified'];

    if (resume && partLength > 0 && validator != null) {
      request.headers['range'] = 'bytes=$partLength-';
      request.headers['if-range'] = validator;
    }

    _throwIfCancelled(shouldCancel);
    final response = await _client.send(request);
    final appending = response.statusCode == 206 && partLength > 0;
    final restarting = response.statusCode == 200;
    if (!appending && !restarting) {
      throw HttpException(
        'HTTP ${response.statusCode}',
        uri: response.request?.url ?? url,
      );
    }
    if (appending) {
      final rangeStart = _resolveContentRangeStart(response);
      if (rangeStart != null && rangeStart != partLength) {
        throw HttpException(
          'Unexpected Content-Range start $rangeStart for $partLength bytes',
          uri: response.request?.url ?? url,
        );
      }
    }

    final startingBytes = appending ? partLength : 0;
    final totalBytes = _resolveTotalBytes(response, startingBytes);
    var downloadedBytes = startingBytes;
    var speedBytesPerSecond = 0;
    var lastBytes = downloadedBytes;
    final speedStopwatch = Stopwatch()..start();
    final sink = partFile.openWrite(
      mode: appending ? FileMode.append : FileMode.write,
    );
    try {
      await for (final chunk in response.stream) {
        _throwIfCancelled(shouldCancel);
        sink.add(chunk);
        downloadedBytes += chunk.length;

        if (speedStopwatch.elapsedMilliseconds >= 500) {
          final elapsed = speedStopwatch.elapsedMilliseconds;
          speedBytesPerSecond =
              ((downloadedBytes - lastBytes) * 1000 ~/ elapsed);
          lastBytes = downloadedBytes;
          speedStopwatch.reset();
        }

        if (totalBytes > 0) {
          onProgress?.call(
            ModelDownloadProgress(
              downloadedBytes: completedBytes + downloadedBytes,
              totalBytes: completedBytes + totalBytes,
              progress:
                  (completedBytes + downloadedBytes) /
                  (completedBytes + totalBytes),
              speedBytesPerSecond: speedBytesPerSecond,
              wasResumed: appending,
              fileIndex: fileIndex,
              fileCount: fileCount,
              fileName: fileName,
              sourceHost: sourceHost,
            ),
          );
        }
        _throwIfCancelled(shouldCancel);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    await metaFile.writeAsString(
      jsonEncode({
        if (response.headers['etag'] != null) 'etag': response.headers['etag'],
        if (response.headers['last-modified'] != null)
          'lastModified': response.headers['last-modified'],
        'url': url.toString(),
      }),
    );

    await _deleteIfExists(targetFile);
    await partFile.rename(targetFile.path);
    return targetFile;
  }

  Uri _resolveModelFileUrl(Uri repositoryUrl, String fileName) {
    final basePath = repositoryUrl.path.replaceAll(RegExp(r'/+$'), '');
    return repositoryUrl.replace(
      path: '$basePath/resolve/main/$fileName',
      queryParameters: {'download': 'true'},
    );
  }

  int _resolveTotalBytes(http.StreamedResponse response, int startingBytes) {
    final contentRange = response.headers['content-range'];
    if (contentRange != null) {
      final slashIndex = contentRange.lastIndexOf('/');
      if (slashIndex >= 0 && slashIndex < contentRange.length - 1) {
        final parsed = int.tryParse(contentRange.substring(slashIndex + 1));
        if (parsed != null && parsed > 0) return parsed;
      }
    }
    final contentLength = response.contentLength ?? 0;
    return startingBytes + contentLength;
  }

  int? _resolveContentRangeStart(http.StreamedResponse response) {
    final contentRange = response.headers['content-range'];
    if (contentRange == null) return null;
    final match = RegExp(r'bytes\s+(\d+)-').firstMatch(contentRange);
    return int.tryParse(match?.group(1) ?? '');
  }

  Future<ModelInstallResult> _installZip(
    File zipFile, {
    required bool appOwnedZip,
  }) async {
    final cacheDir = await _cacheDir();
    final extractDir = Directory(
      path.join(
        cacheDir.path,
        'model_extract_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );

    try {
      await _deleteDirectoryIfExists(extractDir);
      await extractDir.create(recursive: true);
      await extractFileToDisk(zipFile.path, extractDir.path);

      final extractedModelDir = await _findExtractedModelDir(extractDir);
      if (extractedModelDir == null) {
        throw StateError('压缩包中未找到有效的 MNN 模型文件');
      }

      return await _installModelDirectory(
        extractedModelDir,
        appOwnedSource: false,
      );
    } finally {
      await _deleteDirectoryIfExists(extractDir);
      if (appOwnedZip) {
        await _deleteIfExists(zipFile);
      }
    }
  }

  Future<ModelInstallResult> _installModelDirectory(
    Directory sourceDir, {
    required bool appOwnedSource,
  }) async {
    final filesDir = await _filesDir();
    final stagingDir = Directory(
      path.join(filesDir.path, '$modelDirName.installing'),
    );
    final finalDir = await _modelDir();
    final backupDir = Directory(path.join(filesDir.path, '$modelDirName.old'));

    try {
      await _deleteDirectoryIfExists(stagingDir);
      await stagingDir.create(recursive: true);
      await _copyDirectory(sourceDir, stagingDir);

      if (!await _isModelDirValid(stagingDir)) {
        throw StateError('模型文件校验失败');
      }

      var backupCreated = false;
      try {
        await _deleteDirectoryIfExists(backupDir);
        if (await finalDir.exists()) {
          await finalDir.rename(backupDir.path);
          backupCreated = true;
        }
        await beforePromoteForTesting?.call();
        await stagingDir.rename(finalDir.path);
        backupCreated = false;
        try {
          await _deleteDirectoryIfExists(backupDir);
        } catch (e, stackTrace) {
          logService.w(LogConfig.moduleLlm, '删除旧模型备份目录失败: $e');
          logService.d(LogConfig.moduleLlm, stackTrace.toString());
        }
      } catch (_) {
        if (backupCreated) {
          await _restoreModelBackup(backupDir, finalDir);
        }
        rethrow;
      }

      final size = await _directorySize(finalDir);
      return ModelInstallResult(
        installed: true,
        modelPath: finalDir.path,
        sizeBytes: size,
      );
    } finally {
      await _deleteDirectoryIfExists(stagingDir);
      if (appOwnedSource) {
        await _deleteDirectoryIfExists(sourceDir);
      }
    }
  }

  Future<void> _restoreModelBackup(
    Directory backupDir,
    Directory finalDir,
  ) async {
    if (!await backupDir.exists() || await finalDir.exists()) return;
    try {
      await backupDir.rename(finalDir.path);
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleLlm, '恢复旧模型目录失败', e, stackTrace);
      rethrow;
    }
  }

  Future<Directory?> _findExtractedModelDir(Directory extractDir) async {
    if (await _isModelDirValid(extractDir)) {
      return extractDir;
    }

    final candidates = <Directory>[];
    await for (final entity in extractDir.list(recursive: false)) {
      if (entity is Directory && await _isModelDirValid(entity)) {
        candidates.add(entity);
      }
    }
    if (candidates.length == 1) return candidates.single;
    return null;
  }

  Future<bool> _isModelDirValid(Directory dir) async {
    for (final fileName in requiredModelFiles) {
      if (!await _isModelFileValid(
        File(path.join(dir.path, fileName)),
        fileName,
      )) {
        return false;
      }
    }
    return true;
  }

  Future<bool> _isModelFileValid(File file, String fileName) async {
    if (!await file.exists()) return false;
    final length = await file.length();
    if (length <= 0) return false;
    if (fileName == 'llm.mnn.weight') {
      return length >= minWeightBytes;
    }
    if (fileName == 'llm_config.json') {
      try {
        jsonDecode(await file.readAsString());
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  void _throwIfCancelled(bool Function()? shouldCancel) {
    if (shouldCancel?.call() == true) {
      throw const ModelDownloadCancelledException();
    }
  }

  Future<Directory> _filesDir() async {
    if (_filesDirOverride != null) return _filesDirOverride;
    return Directory(await FileService().getFilesDirPath());
  }

  Future<Directory> _cacheDir() async {
    if (_cacheDirOverride != null) return _cacheDirOverride;
    return getTemporaryDirectory();
  }

  Future<Directory> _modelDir() async {
    final filesDir = await _filesDir();
    return Directory(path.join(filesDir.path, modelDirName));
  }

  Future<Map<String, String>> _readDownloadMetadata(File file) async {
    if (!await file.exists()) return {};
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        );
      }
    } catch (_) {
      return {};
    }
    return {};
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await for (final entity in source.list(recursive: false)) {
      final targetPath = path.join(
        destination.path,
        path.basename(entity.path),
      );
      if (entity is Directory) {
        final targetDir = Directory(targetPath);
        await targetDir.create(recursive: true);
        await _copyDirectory(entity, targetDir);
      } else if (entity is File) {
        await entity.copy(targetPath);
      }
    }
  }

  Future<int> _directorySize(Directory dir) async {
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _deleteDirectoryIfExists(Directory dir) async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}

import 'dart:convert';
import 'dart:collection';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/log_service.dart';
import '../../core/services/log_config.dart';
import '../datasources/database/database_helper.dart';
import '../datasources/database/invoice_order_relation_table.dart';
import '../models/backup_metadata.dart';

/// Helper class for passing archive data to isolate
class _ArchiveData {
  final String manifestJson;
  final List<int> dbBytes;
  final String dbName;
  final List<_FileData> images;
  final List<_FileData> pdfs;

  _ArchiveData({
    required this.manifestJson,
    required this.dbBytes,
    required this.dbName,
    required this.images,
    required this.pdfs,
  });

  Map<String, dynamic> toMap() => {
    'manifestJson': manifestJson,
    'dbBytes': dbBytes,
    'dbName': dbName,
    'images': images.map((f) => f.toMap()).toList(),
    'pdfs': pdfs.map((f) => f.toMap()).toList(),
  };
}

/// Helper class for file data
class _FileData {
  final String relativePath;
  final List<int> bytes;

  _FileData({required this.relativePath, required this.bytes});

  Map<String, dynamic> toMap() => {
    'relativePath': relativePath,
    'bytes': bytes,
  };

  static _FileData fromMap(Map<String, dynamic> map) => _FileData(
    relativePath: map['relativePath'] as String,
    bytes: map['bytes'] as List<int>,
  );
}

class _PreparedBackup {
  _PreparedBackup({
    required this.metadata,
    required this.stagingDirectory,
    required this.databaseFile,
    required this.images,
    required this.pdfs,
    required this.needsVersionWarning,
    required this.canRestore,
  });

  final BackupMetadata metadata;
  final Directory stagingDirectory;
  final File databaseFile;
  final Map<String, List<int>> images;
  final Map<String, List<int>> pdfs;
  final bool needsVersionWarning;
  final bool canRestore;

  Future<void> dispose() async {
    if (await stagingDirectory.exists()) {
      await stagingDirectory.delete(recursive: true);
    }
  }
}

class _DatabaseInspection {
  const _DatabaseInspection({
    required this.databaseVersion,
    required this.orderCount,
    required this.invoiceCount,
    required this.orderMediaPaths,
    required this.invoiceMediaPaths,
  });

  final int databaseVersion;
  final int orderCount;
  final int invoiceCount;
  final List<String> orderMediaPaths;
  final List<String> invoiceMediaPaths;
}

class _MergeSummary {
  const _MergeSummary({
    required this.ordersInserted,
    required this.invoicesInserted,
    required this.relationsInserted,
    required this.relationConflicts,
  });

  final int ordersInserted;
  final int invoicesInserted;
  final int relationsInserted;
  final int relationConflicts;
}

class _BackupValidationException implements Exception {
  const _BackupValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

enum _DatabaseReplacementCommitState { notCommitted, committed, unknown }

class _DatabaseReplacementResult {
  const _DatabaseReplacementResult({this.postCommitWarning});

  final Object? postCommitWarning;
}

class _DatabaseReplacementException implements Exception {
  const _DatabaseReplacementException({
    required this.message,
    required this.commitState,
  });

  final String message;
  final _DatabaseReplacementCommitState commitState;

  @override
  String toString() => message;
}

/// Top-level function for zip encoding in isolate
List<int>? _encodeArchiveInIsolate(Map<String, dynamic> data) {
  final archive = Archive();
  final dbBytes = data['dbBytes'] as List<int>;

  archive.addFile(
    ArchiveFile.string('manifest.json', data['manifestJson'] as String),
  );
  archive.addFile(
    ArchiveFile(data['dbName'] as String, dbBytes.length, dbBytes),
  );

  _addFilesToArchive(archive, data['images'] as List);
  _addFilesToArchive(archive, data['pdfs'] as List);

  return ZipEncoder().encode(archive);
}

void _addFilesToArchive(Archive archive, List files) {
  for (final item in files) {
    final fileData = _FileData.fromMap(item as Map<String, dynamic>);
    archive.addFile(
      ArchiveFile(fileData.relativePath, fileData.bytes.length, fileData.bytes),
    );
  }
}

/// Restore mode for backup restoration
enum RestoreMode {
  /// Clear all existing data before restoring
  overwrite,

  /// Keep existing data and merge with backup
  incremental,
}

/// Result of backup creation
class BackupResult {
  final bool success;
  final String? filePath;
  final String? errorMessage;
  final String? warningMessage;
  final BackupMetadata? metadata;

  BackupResult({
    required this.success,
    this.filePath,
    this.errorMessage,
    this.warningMessage,
    this.metadata,
  });
}

/// Result of backup validation
class BackupValidationResult {
  final bool isValid;
  final BackupMetadata? metadata;
  final String? errorMessage;
  final bool needsVersionWarning;
  final bool isDatabaseVersionHigher;
  final bool canRestore;

  BackupValidationResult({
    required this.isValid,
    this.metadata,
    this.errorMessage,
    this.needsVersionWarning = false,
    this.isDatabaseVersionHigher = false,
    this.canRestore = true,
  });
}

/// Backup service for creating and restoring backups
class BackupService {
  BackupService({
    DatabaseHelper? databaseHelper,
    Future<Directory> Function()? appDocumentsDirectoryProvider,
    Future<Directory> Function()? temporaryDirectoryProvider,
    Future<String> Function()? databasePathProvider,
    Future<Database> Function()? openCurrentDatabase,
    Future<void> Function()? closeCurrentDatabase,
    Future<String> Function()? appVersionProvider,
    Future<void> Function(File stagedDatabase, File liveDatabase)?
    atomicDatabaseFileReplacer,
  }) : _dbHelper = databaseHelper ?? DatabaseHelper(),
       _appDocumentsDirectoryProvider = appDocumentsDirectoryProvider,
       _temporaryDirectoryProvider = temporaryDirectoryProvider,
       _databasePathProvider = databasePathProvider,
       _openCurrentDatabaseOverride = openCurrentDatabase,
       _closeCurrentDatabaseOverride = closeCurrentDatabase,
       _appVersionProvider = appVersionProvider,
       _atomicDatabaseFileReplacerOverride = atomicDatabaseFileReplacer;

  final DatabaseHelper _dbHelper;
  final Future<Directory> Function()? _appDocumentsDirectoryProvider;
  final Future<Directory> Function()? _temporaryDirectoryProvider;
  final Future<String> Function()? _databasePathProvider;
  final Future<Database> Function()? _openCurrentDatabaseOverride;
  final Future<void> Function()? _closeCurrentDatabaseOverride;
  final Future<String> Function()? _appVersionProvider;
  final Future<void> Function(File stagedDatabase, File liveDatabase)?
  _atomicDatabaseFileReplacerOverride;

  /// Current app version
  String _currentAppVersion = '';

  /// Initialize the service
  Future<void> initialize() async {
    logService.i(LogConfig.moduleBackup, '初始化备份服务...');
    _currentAppVersion = _appVersionProvider != null
        ? await _appVersionProvider()
        : (await PackageInfo.fromPlatform()).version;
    logService.i(
      LogConfig.moduleBackup,
      '备份服务初始化完成, 应用版本: $_currentAppVersion',
    );
  }

  /// Get current app version
  String get currentAppVersion => _currentAppVersion;

  /// Get current database version
  int get databaseVersion => AppConstants.databaseVersion;

  Future<Directory> _getAppDocumentsDirectory() async {
    return _appDocumentsDirectoryProvider != null
        ? await _appDocumentsDirectoryProvider()
        : await getApplicationDocumentsDirectory();
  }

  Future<Directory> _getTemporaryDirectory() async {
    return _temporaryDirectoryProvider != null
        ? await _temporaryDirectoryProvider()
        : await getTemporaryDirectory();
  }

  Future<String> _getDatabasePath() async {
    return _databasePathProvider != null
        ? await _databasePathProvider()
        : await _dbHelper.getDatabasePath();
  }

  Future<Database> _openCurrentDatabase() async {
    return _openCurrentDatabaseOverride != null
        ? await _openCurrentDatabaseOverride()
        : await _dbHelper.database;
  }

  Future<void> _closeCurrentDatabase() async {
    if (_closeCurrentDatabaseOverride != null) {
      await _closeCurrentDatabaseOverride();
      return;
    }
    await _dbHelper.close();
  }

  /// Collect files from a directory, returning file data and count
  Future<(List<_FileData>, int)> _collectFiles(
    Directory dir,
    String prefix, {
    void Function(double progress)? onProgress,
  }) async {
    final files = <_FileData>[];
    if (!await dir.exists()) return (files, 0);

    final entities = await dir.list().toList();
    final fileEntities = entities.whereType<File>().toList();
    final totalFiles = fileEntities.length;

    for (var i = 0; i < totalFiles; i++) {
      final entity = fileEntities[i];
      final bytes = await entity.readAsBytes();
      final relativePath = '$prefix/${path.basename(entity.path)}';
      files.add(_FileData(relativePath: relativePath, bytes: bytes));
      onProgress?.call((i + 1) / totalFiles);
    }

    return (files, totalFiles);
  }

  /// Create a backup of all data
  /// [outputPath] - The path where the backup zip file will be saved
  /// [onProgress] - Optional callback for progress updates (0.0 to 1.0)
  Future<BackupResult> createBackup(
    String outputPath, {
    void Function(double progress)? onProgress,
  }) async {
    var databaseWasClosed = false;
    try {
      logService.i(LogConfig.moduleBackup, '========== 开始备份 ==========');
      logService.diag(LogConfig.moduleBackup, 'Output path', outputPath);

      // Ensure initialized
      if (_currentAppVersion.isEmpty) {
        await initialize();
      }

      // Get directories
      final appDir = await _getAppDocumentsDirectory();
      final imagesDir = Directory(
        path.join(appDir.path, AppConstants.imagesFolder),
      );
      final pdfsDir = Directory(
        path.join(appDir.path, AppConstants.pdfsFolder),
      );

      // Get database path
      final dbPath = await _getDatabasePath();
      final dbFile = File(dbPath);

      final unsafeOutputReason = _backupOutputPathRejectionReason(
        outputPath,
        databasePath: dbPath,
        imagesDirectory: imagesDir,
        pdfsDirectory: pdfsDir,
      );
      if (unsafeOutputReason != null) {
        logService.w(LogConfig.moduleBackup, unsafeOutputReason);
        return BackupResult(success: false, errorMessage: unsafeOutputReason);
      }

      if (!await dbFile.exists()) {
        return BackupResult(success: false, errorMessage: '数据库文件不存在');
      }

      // Get data counts from database
      final db = await _openCurrentDatabase();
      final orderResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${AppConstants.ordersTable}',
      );
      final orderCount = orderResult.isNotEmpty
          ? (orderResult.first['count'] as int?) ?? 0
          : 0;
      final invoiceResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${AppConstants.invoicesTable}',
      );
      final invoiceCount = invoiceResult.isNotEmpty
          ? (invoiceResult.first['count'] as int?) ?? 0
          : 0;

      // Close database before copying
      await _closeCurrentDatabase();
      databaseWasClosed = true;

      final dbBytes = await dbFile.readAsBytes();

      onProgress?.call(0.1);

      final (images, imageCount) = await _collectFiles(
        imagesDir,
        'images',
        onProgress: (fileProgress) =>
            onProgress?.call(0.1 + fileProgress * 0.4),
      );

      final (pdfs, pdfCount) = await _collectFiles(
        pdfsDir,
        'pdfs',
        onProgress: (fileProgress) =>
            onProgress?.call(0.5 + fileProgress * 0.4),
      );

      // Create metadata
      final metadata = BackupMetadata(
        appVersion: _currentAppVersion,
        databaseVersion: AppConstants.databaseVersion,
        backupTime: DateTime.now().toIso8601String(),
        orderCount: orderCount,
        invoiceCount: invoiceCount,
        imageCount: imageCount,
        pdfCount: pdfCount,
      );

      final manifestJson = metadata.toJson();
      final manifestString = jsonEncode(manifestJson);

      onProgress?.call(0.9);

      // Create archive data for isolate
      final archiveData = _ArchiveData(
        manifestJson: manifestString,
        dbBytes: dbBytes,
        dbName: 'database/${AppConstants.databaseName}',
        images: images,
        pdfs: pdfs,
      );

      // Encode zip in background isolate to avoid UI freeze
      final zipBytes = await compute(
        _encodeArchiveInIsolate,
        archiveData.toMap(),
      );
      if (zipBytes == null) {
        return BackupResult(success: false, errorMessage: '压缩备份文件失败');
      }

      final outputFile = File(outputPath);
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsBytes(zipBytes, flush: true);

      _PreparedBackup? verifiedBackup;
      try {
        verifiedBackup = await _prepareBackup(outputPath);
        if (!verifiedBackup.canRestore) {
          throw const _BackupValidationException('生成的备份无法由当前版本还原');
        }
      } catch (e, stackTrace) {
        logService.e(
          LogConfig.moduleBackup,
          '生成的备份未通过完整性校验，删除输出文件',
          e,
          stackTrace,
        );
        if (await outputFile.exists()) {
          await outputFile.delete();
        }
        throw _BackupValidationException('生成的备份未通过完整性校验: $e');
      } finally {
        await verifiedBackup?.dispose();
      }

      await _openCurrentDatabase();
      databaseWasClosed = false;

      _runNonCriticalRestoreStep('更新备份完成进度', () => onProgress?.call(1.0));

      logService.diag(LogConfig.moduleBackup, 'Orders', orderCount);
      logService.diag(LogConfig.moduleBackup, 'Invoices', invoiceCount);
      logService.diag(LogConfig.moduleBackup, 'Images', imageCount);
      logService.diag(LogConfig.moduleBackup, 'PDFs', pdfCount);
      logService.i(LogConfig.moduleBackup, '========== 备份完成 ==========');
      logService.i(LogConfig.moduleBackup, '备份文件已保存: $outputPath');

      return BackupResult(
        success: true,
        filePath: outputPath,
        metadata: metadata,
      );
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleBackup, '备份失败', e, stackTrace);
      return BackupResult(success: false, errorMessage: '备份失败: $e');
    } finally {
      if (databaseWasClosed) {
        try {
          await _openCurrentDatabase();
        } catch (e, stackTrace) {
          logService.e(LogConfig.moduleBackup, '备份后重新打开数据库失败', e, stackTrace);
        }
      }
    }
  }

  String? _backupOutputPathRejectionReason(
    String outputPath, {
    required String databasePath,
    required Directory imagesDirectory,
    required Directory pdfsDirectory,
  }) {
    final normalizedOutput = _normalizedAbsolutePath(outputPath);
    if (normalizedOutput == _normalizedAbsolutePath(databasePath)) {
      return '备份输出路径不能覆盖当前数据库';
    }
    if (_isSameOrWithinDirectory(normalizedOutput, imagesDirectory.path)) {
      return '备份输出路径不能位于图片数据目录内';
    }
    if (_isSameOrWithinDirectory(normalizedOutput, pdfsDirectory.path)) {
      return '备份输出路径不能位于 PDF 数据目录内';
    }
    return null;
  }

  String _normalizedAbsolutePath(String value) {
    final normalized = path.normalize(path.absolute(value));
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }

  bool _isSameOrWithinDirectory(String normalizedChild, String directory) {
    final normalizedDirectory = _normalizedAbsolutePath(directory);
    if (normalizedChild == normalizedDirectory) return true;
    final relative = path.relative(normalizedChild, from: normalizedDirectory);
    return relative != '..' &&
        !relative.startsWith('..${path.separator}') &&
        !path.isAbsolute(relative);
  }

  /// Validate a backup file and get its metadata
  Future<BackupValidationResult> validateBackup(String zipPath) async {
    _PreparedBackup? prepared;
    try {
      prepared = await _prepareBackup(zipPath);

      return BackupValidationResult(
        isValid: true,
        metadata: prepared.metadata,
        needsVersionWarning: prepared.needsVersionWarning,
        isDatabaseVersionHigher: !prepared.canRestore,
        canRestore: prepared.canRestore,
      );
    } on _BackupValidationException catch (e) {
      logService.w(LogConfig.moduleBackup, '备份验证未通过: ${e.message}');
      return BackupValidationResult(isValid: false, errorMessage: e.message);
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleBackup, '验证备份失败', e, stackTrace);
      return BackupValidationResult(
        isValid: false,
        errorMessage: '验证备份文件失败: $e',
      );
    } finally {
      await prepared?.dispose();
    }
  }

  Future<_PreparedBackup> _prepareBackup(String zipPath) async {
    if (_currentAppVersion.isEmpty) {
      await initialize();
    }

    final backupFile = File(zipPath);
    if (!await backupFile.exists()) {
      throw const _BackupValidationException('备份文件不存在');
    }

    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(
        await backupFile.readAsBytes(),
        verify: true,
      );
    } catch (e) {
      throw _BackupValidationException('备份文件无法解压或已损坏: $e');
    }

    ArchiveFile? manifestFile;
    ArchiveFile? databaseArchiveFile;
    final images = <String, List<int>>{};
    final pdfs = <String, List<int>>{};
    final expectedDatabaseEntry = 'database/${AppConstants.databaseName}';

    for (final entry in archive) {
      if (!entry.isFile) continue;
      final normalizedName = entry.name.replaceAll('\\', '/');

      if (normalizedName == 'manifest.json') {
        if (manifestFile != null) {
          throw const _BackupValidationException('备份文件包含重复的 manifest.json');
        }
        manifestFile = entry;
        continue;
      }

      if (normalizedName == expectedDatabaseEntry) {
        if (databaseArchiveFile != null) {
          throw const _BackupValidationException('备份文件包含重复的数据库');
        }
        databaseArchiveFile = entry;
        continue;
      }

      if (normalizedName.startsWith('database/')) {
        throw _BackupValidationException('备份中包含未知数据库文件: $normalizedName');
      }

      if (normalizedName.startsWith('images/')) {
        final fileName = _validatedArchiveFileName(normalizedName, 'images/');
        if (images.containsKey(fileName)) {
          throw _BackupValidationException('备份中包含重复图片: $fileName');
        }
        images[fileName] = List<int>.from(entry.content);
        continue;
      }

      if (normalizedName.startsWith('pdfs/')) {
        final fileName = _validatedArchiveFileName(normalizedName, 'pdfs/');
        if (pdfs.containsKey(fileName)) {
          throw _BackupValidationException('备份中包含重复 PDF: $fileName');
        }
        pdfs[fileName] = List<int>.from(entry.content);
      }
    }

    if (manifestFile == null) {
      throw const _BackupValidationException('备份文件缺少 manifest.json');
    }
    if (databaseArchiveFile == null) {
      throw _BackupValidationException('备份文件缺少 $expectedDatabaseEntry');
    }

    late final BackupMetadata metadata;
    try {
      final decoded = jsonDecode(utf8.decode(manifestFile.content));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('manifest.json 根节点必须是对象');
      }
      metadata = BackupMetadata.fromJson(decoded);
    } catch (e) {
      throw _BackupValidationException('manifest.json 格式无效: $e');
    }

    if (metadata.version != '1.0') {
      throw _BackupValidationException('不支持的备份格式版本: ${metadata.version}');
    }
    if (metadata.databaseVersion < 1 ||
        metadata.orderCount < 0 ||
        metadata.invoiceCount < 0 ||
        metadata.imageCount < 0 ||
        metadata.pdfCount < 0) {
      throw const _BackupValidationException('manifest.json 包含无效的版本或数量');
    }
    if (metadata.imageCount != images.length) {
      throw _BackupValidationException(
        '图片数量与 manifest.json 不符: '
        '声明 ${metadata.imageCount}，实际 ${images.length}',
      );
    }
    if (metadata.pdfCount != pdfs.length) {
      throw _BackupValidationException(
        'PDF 数量与 manifest.json 不符: '
        '声明 ${metadata.pdfCount}，实际 ${pdfs.length}',
      );
    }

    final databaseBytes = List<int>.from(databaseArchiveFile.content);
    if (!_hasSqliteHeader(databaseBytes)) {
      throw const _BackupValidationException('备份数据库不是有效的 SQLite 文件');
    }

    Directory? stagingDirectory;
    try {
      final tempRoot = await _getTemporaryDirectory();
      await tempRoot.create(recursive: true);
      stagingDirectory = await tempRoot.createTemp('receipt_tamer_restore_');
      final stagedDatabase = File(
        path.join(stagingDirectory.path, AppConstants.databaseName),
      );
      await stagedDatabase.writeAsBytes(databaseBytes, flush: true);

      final inspection = await _inspectDatabase(
        stagedDatabase,
        checkForeignKeys:
            metadata.databaseVersion >= AppConstants.databaseVersion,
      );
      _validateArchiveMediaReferences(inspection, images: images, pdfs: pdfs);
      if (inspection.databaseVersion != metadata.databaseVersion) {
        throw _BackupValidationException(
          '数据库版本与 manifest.json 不符: '
          '声明 ${metadata.databaseVersion}，实际 ${inspection.databaseVersion}',
        );
      }
      if (inspection.orderCount != metadata.orderCount) {
        throw _BackupValidationException(
          '订单数量与 manifest.json 不符: '
          '声明 ${metadata.orderCount}，实际 ${inspection.orderCount}',
        );
      }
      if (inspection.invoiceCount != metadata.invoiceCount) {
        throw _BackupValidationException(
          '发票数量与 manifest.json 不符: '
          '声明 ${metadata.invoiceCount}，实际 ${inspection.invoiceCount}',
        );
      }

      final canRestore =
          metadata.databaseVersion <= AppConstants.databaseVersion;
      if (canRestore) {
        await _prepareDatabaseForRestore(stagedDatabase);
        final preparedInspection = await _inspectDatabase(stagedDatabase);
        if (preparedInspection.databaseVersion !=
                AppConstants.databaseVersion ||
            preparedInspection.orderCount != metadata.orderCount ||
            preparedInspection.invoiceCount != metadata.invoiceCount) {
          throw const _BackupValidationException('备份数据库预处理后校验失败');
        }
      }

      final needsVersionWarning =
          metadata.appVersion != _currentAppVersion && canRestore;

      logService.i(
        LogConfig.moduleBackup,
        '备份预检通过: orders=${metadata.orderCount}, '
        'invoices=${metadata.invoiceCount}, images=${images.length}, '
        'pdfs=${pdfs.length}',
      );

      return _PreparedBackup(
        metadata: metadata,
        stagingDirectory: stagingDirectory,
        databaseFile: stagedDatabase,
        images: images,
        pdfs: pdfs,
        needsVersionWarning: needsVersionWarning,
        canRestore: canRestore,
      );
    } catch (_) {
      if (stagingDirectory != null && await stagingDirectory.exists()) {
        await stagingDirectory.delete(recursive: true);
      }
      rethrow;
    }
  }

  String _validatedArchiveFileName(String archivePath, String prefix) {
    final fileName = archivePath.substring(prefix.length);
    if (fileName.isEmpty ||
        fileName == '.' ||
        fileName == '..' ||
        fileName.contains('/') ||
        fileName.contains('\\')) {
      throw _BackupValidationException('备份中包含不安全的文件路径: $archivePath');
    }
    return fileName;
  }

  bool _hasSqliteHeader(List<int> bytes) {
    if (bytes.length < 16) return false;
    return String.fromCharCodes(bytes.take(16)) == 'SQLite format 3\u0000';
  }

  void _validateArchiveMediaReferences(
    _DatabaseInspection inspection, {
    required Map<String, List<int>> images,
    required Map<String, List<int>> pdfs,
  }) {
    void validate(
      String tableName,
      String mediaPath, {
      required Map<String, List<int>> archiveFiles,
      required String archiveFolder,
    }) {
      if (mediaPath.isEmpty) return;

      final fileName = _portableBasename(mediaPath);
      if (fileName.isEmpty) {
        throw _BackupValidationException(
          '备份数据库表 $tableName 包含无效附件路径: $mediaPath',
        );
      }
      final bytes = archiveFiles[fileName];
      if (bytes == null) {
        throw _BackupValidationException(
          '备份数据库表 $tableName 引用的附件缺失: '
          '$archiveFolder/$fileName',
        );
      }
      if (bytes.isEmpty) {
        throw _BackupValidationException(
          '备份数据库表 $tableName 引用的附件为空: '
          '$archiveFolder/$fileName',
        );
      }
    }

    for (final mediaPath in inspection.orderMediaPaths) {
      validate(
        AppConstants.ordersTable,
        mediaPath,
        archiveFiles: images,
        archiveFolder: 'images',
      );
    }
    for (final mediaPath in inspection.invoiceMediaPaths) {
      final fileName = _portableBasename(mediaPath);
      final isPdf = path.extension(fileName).toLowerCase() == '.pdf';
      validate(
        AppConstants.invoicesTable,
        mediaPath,
        archiveFiles: isPdf ? pdfs : images,
        archiveFolder: isPdf ? 'pdfs' : 'images',
      );
    }
  }

  Future<_DatabaseInspection> _inspectDatabase(
    File databaseFile, {
    bool checkForeignKeys = true,
  }) async {
    Database? database;
    try {
      database = await openDatabase(
        databaseFile.path,
        readOnly: true,
        singleInstance: false,
      );

      final integrityRows = await database.rawQuery('PRAGMA integrity_check');
      final integrity = integrityRows.isEmpty
          ? ''
          : integrityRows.first.values.first.toString().toLowerCase();
      if (integrity != 'ok') {
        throw _BackupValidationException('备份数据库完整性检查失败: $integrity');
      }

      const requiredColumns = <String, Set<String>>{
        AppConstants.ordersTable: {
          AppConstants.colId,
          AppConstants.colImagePath,
          AppConstants.colShopName,
          AppConstants.colAmount,
          AppConstants.colOrderDate,
          AppConstants.colMealTime,
          AppConstants.colOrderNumber,
          AppConstants.colCreatedAt,
          AppConstants.colUpdatedAt,
        },
        AppConstants.invoicesTable: {
          AppConstants.colId,
          AppConstants.colImagePath,
          AppConstants.colInvoiceNumber,
          AppConstants.colInvoiceDate,
          AppConstants.colTotalAmount,
          AppConstants.colSellerName,
          AppConstants.colCreatedAt,
          AppConstants.colUpdatedAt,
        },
        AppConstants.invoiceOrderRelationsTable: {
          AppConstants.colInvoiceId,
          AppConstants.colOrderId,
        },
      };

      final tableRows = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final tableNames = tableRows
          .map((row) => row['name'])
          .whereType<String>()
          .toSet();

      for (final entry in requiredColumns.entries) {
        if (!tableNames.contains(entry.key)) {
          throw _BackupValidationException('备份数据库缺少必需表: ${entry.key}');
        }
        final columnRows = await database.rawQuery(
          'PRAGMA table_info(${entry.key})',
        );
        final columnNames = columnRows
            .map((row) => row['name'])
            .whereType<String>()
            .toSet();
        final missingColumns = entry.value.difference(columnNames);
        if (missingColumns.isNotEmpty) {
          throw _BackupValidationException(
            '备份数据库表 ${entry.key} 缺少字段: '
            '${missingColumns.join(', ')}',
          );
        }
      }

      if (checkForeignKeys) {
        final foreignKeyErrors = await database.rawQuery(
          'PRAGMA foreign_key_check',
        );
        if (foreignKeyErrors.isNotEmpty) {
          throw const _BackupValidationException('备份数据库包含无效的外键关系');
        }
      }

      final versionRows = await database.rawQuery('PRAGMA user_version');
      final version = (versionRows.first.values.first as num).toInt();
      final orderRows = await database.rawQuery(
        'SELECT COUNT(*) AS count FROM ${AppConstants.ordersTable}',
      );
      final invoiceRows = await database.rawQuery(
        'SELECT COUNT(*) AS count FROM ${AppConstants.invoicesTable}',
      );
      final orderMediaRows = await database.query(
        AppConstants.ordersTable,
        columns: [AppConstants.colImagePath],
      );
      final invoiceMediaRows = await database.query(
        AppConstants.invoicesTable,
        columns: [AppConstants.colImagePath],
      );

      return _DatabaseInspection(
        databaseVersion: version,
        orderCount: (orderRows.first['count'] as num).toInt(),
        invoiceCount: (invoiceRows.first['count'] as num).toInt(),
        orderMediaPaths: [
          for (final row in orderMediaRows)
            (row[AppConstants.colImagePath] ?? '').toString(),
        ],
        invoiceMediaPaths: [
          for (final row in invoiceMediaRows)
            (row[AppConstants.colImagePath] ?? '').toString(),
        ],
      );
    } on _BackupValidationException {
      rethrow;
    } catch (e) {
      throw _BackupValidationException('备份数据库无法读取或已损坏: $e');
    } finally {
      await database?.close();
    }
  }

  Future<void> _prepareDatabaseForRestore(File databaseFile) async {
    Database? database;
    try {
      database = await openDatabase(
        databaseFile.path,
        version: AppConstants.databaseVersion,
        singleInstance: false,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            final relationTable = InvoiceOrderRelationTable(database: db);
            await relationTable.deleteOrphanedRelations();
            await relationTable.enforceSingleInvoicePerOrder();
          }
        },
        onOpen: (db) async {
          final relationTable = InvoiceOrderRelationTable(database: db);
          await relationTable.deleteOrphanedRelations();
          await relationTable.enforceSingleInvoicePerOrder();
        },
      );
    } finally {
      await database?.close();
    }
  }

  /// Restore data from a backup file
  /// [zipPath] - Path to the backup zip file
  /// [mode] - Restore mode (overwrite or incremental)
  /// [onProgress] - Optional callback for progress updates
  Future<BackupResult> restoreBackup(
    String zipPath,
    RestoreMode mode, {
    void Function(double progress)? onProgress,
  }) async {
    _PreparedBackup? prepared;
    try {
      logService.i(LogConfig.moduleBackup, '========== 开始还原 ==========');
      logService.diag(LogConfig.moduleBackup, '备份路径', zipPath);
      logService.diag(
        LogConfig.moduleBackup,
        '还原模式',
        mode == RestoreMode.overwrite ? '覆盖' : '增量',
      );

      onProgress?.call(0.02);
      prepared = await _prepareBackup(zipPath);
      if (!prepared.canRestore) {
        const message = '备份文件的数据库版本高于当前应用版本';
        logService.w(LogConfig.moduleBackup, message);
        return BackupResult(success: false, errorMessage: message);
      }
      onProgress?.call(0.15);

      if (mode == RestoreMode.overwrite) {
        return await _restoreOverwrite(prepared, onProgress);
      } else {
        return await _restoreIncremental(prepared, onProgress);
      }
    } on _BackupValidationException catch (e) {
      logService.w(LogConfig.moduleBackup, '备份验证未通过: ${e.message}');
      return BackupResult(success: false, errorMessage: e.message);
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleBackup, '还原失败', e, stackTrace);
      return BackupResult(success: false, errorMessage: '还原失败: $e');
    } finally {
      await prepared?.dispose();
    }
  }

  /// Restore with overwrite mode
  Future<BackupResult> _restoreOverwrite(
    _PreparedBackup prepared,
    void Function(double progress)? onProgress,
  ) async {
    final appDir = await _getAppDocumentsDirectory();
    final imagesDir = Directory(
      path.join(appDir.path, AppConstants.imagesFolder),
    );
    final pdfsDir = Directory(path.join(appDir.path, AppConstants.pdfsFolder));
    final dbPath = await _getDatabasePath();
    final dbFile = File(dbPath);
    final token = DateTime.now().microsecondsSinceEpoch.toString();
    final stagedDbFile = File('$dbPath.restore_new_$token');
    final rollbackDbFile = File('$dbPath.restore_old_$token');
    final createdMediaFiles = <File>[];
    var oldImageFiles = <File>[];
    var oldPdfFiles = <File>[];

    var databaseClosed = false;
    var databaseCommitState = _DatabaseReplacementCommitState.notCommitted;
    var restoreSucceeded = false;
    Object? postCommitWarning;

    try {
      await appDir.create(recursive: true);
      await dbFile.parent.create(recursive: true);
      await imagesDir.create(recursive: true);
      await pdfsDir.create(recursive: true);

      oldImageFiles = await _listDirectFiles(imagesDir);
      oldPdfFiles = await _listDirectFiles(pdfsDir);

      final imagePaths = await _restoreMediaIncrementally(
        prepared.images,
        imagesDir,
        createdMediaFiles,
      );
      final pdfPaths = await _restoreMediaIncrementally(
        prepared.pdfs,
        pdfsDir,
        createdMediaFiles,
      );
      onProgress?.call(0.38);

      await prepared.databaseFile.copy(stagedDbFile.path);
      await _rewritePreparedMediaPaths(
        stagedDbFile,
        imagesDir: imagesDir,
        pdfsDir: pdfsDir,
        imagePaths: imagePaths,
        pdfPaths: pdfPaths,
      );

      final stagedInspection = await _inspectDatabase(stagedDbFile);
      if (stagedInspection.databaseVersion != AppConstants.databaseVersion ||
          stagedInspection.orderCount != prepared.metadata.orderCount ||
          stagedInspection.invoiceCount != prepared.metadata.invoiceCount) {
        throw const _BackupValidationException('覆盖还原的隔离数据未通过二次校验');
      }
      await _validateRestoredMediaFiles(stagedInspection);
      onProgress?.call(0.55);

      await _closeCurrentDatabase();
      databaseClosed = true;
      await _deleteDatabaseSidecarsStrict(dbPath);

      if (!await dbFile.exists()) {
        throw const _BackupValidationException('当前数据库文件不存在，无法安全覆盖还原');
      }
      await dbFile.copy(rollbackDbFile.path);
      await _inspectDatabase(rollbackDbFile);

      final replacement = await _replaceDatabaseFileAtomically(
        stagedDbFile,
        dbFile,
      );
      databaseCommitState = _DatabaseReplacementCommitState.committed;
      postCommitWarning = replacement.postCommitWarning;
      if (postCommitWarning != null) {
        logService.w(
          LogConfig.moduleBackup,
          '数据库已完成原子替换，但替换操作随后报告异常，将继续复验: '
          '$postCommitWarning',
        );
      }
      _runNonCriticalRestoreStep('更新覆盖还原提交进度', () => onProgress?.call(0.82));

      await _openCurrentDatabase();
      final liveInspection = await _inspectDatabase(dbFile);
      if (liveInspection.databaseVersion != AppConstants.databaseVersion ||
          liveInspection.orderCount != prepared.metadata.orderCount ||
          liveInspection.invoiceCount != prepared.metadata.invoiceCount) {
        throw const _BackupValidationException('覆盖还原后数据库校验失败');
      }
      await _validateRestoredMediaFiles(liveInspection);

      final retainedImagePaths = imagePaths.values
          .map(_normalizedAbsolutePath)
          .toSet();
      final retainedPdfPaths = pdfPaths.values
          .map(_normalizedAbsolutePath)
          .toSet();
      await _deleteUnretainedMediaFiles(oldImageFiles, retainedImagePaths);
      await _deleteUnretainedMediaFiles(oldPdfFiles, retainedPdfPaths);
      await _safeDeleteFile(rollbackDbFile);
      restoreSucceeded = true;
      _runNonCriticalRestoreStep('更新覆盖还原完成进度', () => onProgress?.call(1.0));
      _runNonCriticalRestoreStep(
        '记录覆盖还原完成日志',
        () => logService.i(
          LogConfig.moduleBackup,
          '========== 覆盖还原完成 ==========',
        ),
      );
      return BackupResult(
        success: true,
        filePath: null,
        metadata: null,
        warningMessage: postCommitWarning == null
            ? null
            : '数据库已完成原子替换；替换操作随后报告异常，但新数据复验通过: '
                  '$postCommitWarning',
      );
    } catch (e, stackTrace) {
      if (e is _DatabaseReplacementException) {
        databaseCommitState = e.commitState;
      }

      if (databaseCommitState == _DatabaseReplacementCommitState.committed) {
        logService.e(
          LogConfig.moduleBackup,
          '覆盖还原已提交，但提交后复验或收尾失败；保留新数据库及附件',
          e,
          stackTrace,
        );
        try {
          await _openCurrentDatabase();
        } catch (reopenError, reopenStackTrace) {
          logService.e(
            LogConfig.moduleBackup,
            '覆盖还原提交后重新打开新数据库失败',
            reopenError,
            reopenStackTrace,
          );
        }

        return BackupResult(
          success: false,
          errorMessage: '覆盖还原已提交，但提交后复验失败: $e；新数据库及其附件已保留',
        );
      }

      if (databaseCommitState == _DatabaseReplacementCommitState.unknown) {
        logService.e(
          LogConfig.moduleBackup,
          '覆盖还原的数据库提交状态无法确认；保留所有数据库副本及新附件',
          e,
          stackTrace,
        );
        try {
          await _openCurrentDatabase();
        } catch (reopenError, reopenStackTrace) {
          logService.e(
            LogConfig.moduleBackup,
            '提交状态未知后重新打开数据库失败',
            reopenError,
            reopenStackTrace,
          );
        }

        return BackupResult(
          success: false,
          errorMessage: '覆盖还原的提交状态无法确认: $e；已保留数据库副本及新附件',
        );
      }

      logService.e(LogConfig.moduleBackup, '覆盖还原提交前失败', e, stackTrace);
      if (databaseClosed) {
        try {
          await _openCurrentDatabase();
        } catch (reopenError, reopenStackTrace) {
          logService.e(
            LogConfig.moduleBackup,
            '覆盖还原提交前失败后重新打开原数据库失败',
            reopenError,
            reopenStackTrace,
          );
        }
      }

      for (final file in createdMediaFiles.reversed) {
        await _safeDeleteFile(file);
      }

      return BackupResult(success: false, errorMessage: '覆盖还原失败: $e');
    } finally {
      if (databaseCommitState != _DatabaseReplacementCommitState.unknown) {
        await _safeDeleteFile(stagedDbFile);
      }
      if (restoreSucceeded ||
          databaseCommitState == _DatabaseReplacementCommitState.notCommitted) {
        await _safeDeleteFile(rollbackDbFile);
      }
    }
  }

  Future<List<File>> _listDirectFiles(Directory directory) async {
    if (!await directory.exists()) return [];
    return directory
        .list(followLinks: false)
        .where((entity) => entity is File)
        .cast<File>()
        .toList();
  }

  Future<void> _validateRestoredMediaFiles(
    _DatabaseInspection inspection,
  ) async {
    for (final mediaPath in [
      ...inspection.orderMediaPaths,
      ...inspection.invoiceMediaPaths,
    ]) {
      if (mediaPath.isEmpty) continue;
      final file = File(mediaPath);
      if (!await file.exists() || await file.length() == 0) {
        throw _BackupValidationException('还原数据库引用的附件不存在或为空: $mediaPath');
      }
    }
  }

  Future<void> _deleteUnretainedMediaFiles(
    List<File> oldFiles,
    Set<String> retainedPaths,
  ) async {
    for (final file in oldFiles) {
      if (!retainedPaths.contains(_normalizedAbsolutePath(file.path))) {
        await _safeDeleteFile(file);
      }
    }
  }

  Future<_DatabaseReplacementResult> _replaceDatabaseFileAtomically(
    File stagedDatabase,
    File liveDatabase,
  ) async {
    if (_normalizedAbsolutePath(stagedDatabase.parent.path) !=
        _normalizedAbsolutePath(liveDatabase.parent.path)) {
      throw const _BackupValidationException('原子替换数据库要求暂存文件位于同一目录');
    }

    if (!await stagedDatabase.exists()) {
      throw const _BackupValidationException('原子替换数据库的暂存文件不存在');
    }

    try {
      if (_atomicDatabaseFileReplacerOverride != null) {
        await _atomicDatabaseFileReplacerOverride(stagedDatabase, liveDatabase);
      } else {
        await stagedDatabase.rename(liveDatabase.path);
      }
      return const _DatabaseReplacementResult();
    } catch (e) {
      final commitState = await _detectDatabaseReplacementCommitState(
        stagedDatabase,
        liveDatabase,
      );
      if (commitState == _DatabaseReplacementCommitState.committed) {
        return _DatabaseReplacementResult(postCommitWarning: e);
      }
      throw _DatabaseReplacementException(
        message: commitState == _DatabaseReplacementCommitState.notCommitted
            ? '当前平台无法安全原子替换数据库，已保留原数据库: $e'
            : '原子替换数据库失败且提交状态无法确认: $e',
        commitState: commitState,
      );
    }
  }

  Future<_DatabaseReplacementCommitState> _detectDatabaseReplacementCommitState(
    File stagedDatabase,
    File liveDatabase,
  ) async {
    try {
      final stagedExists = await stagedDatabase.exists();
      final liveExists = await liveDatabase.exists();
      if (!stagedExists && liveExists) {
        return _DatabaseReplacementCommitState.committed;
      }
      if (stagedExists && liveExists) {
        return _DatabaseReplacementCommitState.notCommitted;
      }
      return _DatabaseReplacementCommitState.unknown;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleBackup, '检测原子替换数据库提交状态失败', e, stackTrace);
      return _DatabaseReplacementCommitState.unknown;
    }
  }

  Future<void> _rewritePreparedMediaPaths(
    File databaseFile, {
    required Directory imagesDir,
    required Directory pdfsDir,
    required Map<String, String> imagePaths,
    required Map<String, String> pdfPaths,
  }) async {
    Database? database;
    try {
      database = await openDatabase(
        databaseFile.path,
        singleInstance: false,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      );
      await database.transaction((transaction) async {
        final orders = await transaction.query(
          AppConstants.ordersTable,
          columns: [AppConstants.colId, AppConstants.colImagePath],
        );
        for (final order in orders) {
          final oldPath = (order[AppConstants.colImagePath] ?? '').toString();
          final newPath = _resolveOrderMediaPath(
            oldPath,
            imagePaths,
            imagesDir,
          );
          if (newPath != oldPath) {
            await transaction.update(
              AppConstants.ordersTable,
              {AppConstants.colImagePath: newPath},
              where: '${AppConstants.colId} = ?',
              whereArgs: [order[AppConstants.colId]],
            );
          }
        }

        final invoices = await transaction.query(
          AppConstants.invoicesTable,
          columns: [AppConstants.colId, AppConstants.colImagePath],
        );
        for (final invoice in invoices) {
          final oldPath = (invoice[AppConstants.colImagePath] ?? '').toString();
          final newPath = _resolveInvoiceMediaPath(
            oldPath,
            imagePaths,
            pdfPaths,
            imagesDir,
            pdfsDir,
          );
          if (newPath != oldPath) {
            await transaction.update(
              AppConstants.invoicesTable,
              {AppConstants.colImagePath: newPath},
              where: '${AppConstants.colId} = ?',
              whereArgs: [invoice[AppConstants.colId]],
            );
          }
        }
      });
    } finally {
      await database?.close();
    }
  }

  Future<void> _deleteDatabaseSidecarsStrict(String databasePath) async {
    for (final suffix in const ['-journal', '-wal', '-shm']) {
      final sidecarPath = '$databasePath$suffix';
      final entityType = await FileSystemEntity.type(
        sidecarPath,
        followLinks: false,
      );
      if (entityType == FileSystemEntityType.notFound) continue;
      if (entityType != FileSystemEntityType.file) {
        throw _BackupValidationException(
          '数据库 sidecar 不是普通文件，拒绝继续还原: $sidecarPath',
        );
      }

      await File(sidecarPath).delete();
      if (await FileSystemEntity.type(sidecarPath, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw _BackupValidationException(
          '数据库 sidecar 删除失败，拒绝继续还原: $sidecarPath',
        );
      }
    }
  }

  Future<void> _safeDeleteFile(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (e, stackTrace) {
      logService.w(LogConfig.moduleBackup, '清理文件失败: ${file.path}, $e');
      logService.d(LogConfig.moduleBackup, stackTrace.toString());
    }
  }

  /// Restore with incremental mode
  Future<BackupResult> _restoreIncremental(
    _PreparedBackup prepared,
    void Function(double progress)? onProgress,
  ) async {
    final createdFiles = <File>[];
    Database? sourceDatabase;
    var mergeCommitted = false;
    try {
      final appDir = await _getAppDocumentsDirectory();
      final imagesDir = Directory(
        path.join(appDir.path, AppConstants.imagesFolder),
      );
      final pdfsDir = Directory(
        path.join(appDir.path, AppConstants.pdfsFolder),
      );

      await imagesDir.create(recursive: true);
      await pdfsDir.create(recursive: true);

      final imagePaths = await _restoreMediaIncrementally(
        prepared.images,
        imagesDir,
        createdFiles,
      );
      final pdfPaths = await _restoreMediaIncrementally(
        prepared.pdfs,
        pdfsDir,
        createdFiles,
      );
      onProgress?.call(0.48);

      sourceDatabase = await openDatabase(
        prepared.databaseFile.path,
        readOnly: true,
        singleInstance: false,
      );
      final currentDatabase = await _openCurrentDatabase();

      final summary = await _mergeDatabaseData(
        sourceDatabase,
        currentDatabase,
        imagesDir: imagesDir,
        pdfsDir: pdfsDir,
        imagePaths: imagePaths,
        pdfPaths: pdfPaths,
      );
      mergeCommitted = true;
      final warningMessage = summary.relationConflicts > 0
          ? '数据已还原，但 ${summary.relationConflicts} 条订单关系与现有数据冲突，已保留现状'
          : null;
      _runNonCriticalRestoreStep('更新增量还原进度', () => onProgress?.call(0.92));
      _runNonCriticalRestoreStep('记录增量还原合并日志', () {
        logService.i(
          LogConfig.moduleBackup,
          '增量还原合并完成: '
          '新增订单 ${summary.ordersInserted} 条, '
          '新增发票 ${summary.invoicesInserted} 张, '
          '新增关系 ${summary.relationsInserted} 条',
        );
        if (summary.relationConflicts > 0) {
          logService.w(
            LogConfig.moduleBackup,
            '增量还原保留了 ${summary.relationConflicts} 条现有订单关系',
          );
        }
      });
      _runNonCriticalRestoreStep('更新增量还原完成进度', () => onProgress?.call(1.0));
      _runNonCriticalRestoreStep(
        '记录增量还原完成日志',
        () => logService.i(
          LogConfig.moduleBackup,
          '========== 增量还原完成 ==========',
        ),
      );
      return BackupResult(
        success: true,
        filePath: null,
        metadata: null,
        warningMessage: warningMessage,
      );
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleBackup, '增量还原失败', e, stackTrace);
      return BackupResult(success: false, errorMessage: '增量还原失败: $e');
    } finally {
      try {
        await sourceDatabase?.close();
      } catch (e, stackTrace) {
        logService.w(LogConfig.moduleBackup, '关闭增量还原源数据库失败: $e');
        logService.d(LogConfig.moduleBackup, stackTrace.toString());
      }
      if (!mergeCommitted) {
        for (final file in createdFiles.reversed) {
          await _safeDeleteFile(file);
        }
      }
    }
  }

  void _runNonCriticalRestoreStep(String description, void Function() step) {
    try {
      step();
    } catch (e, stackTrace) {
      try {
        logService.w(LogConfig.moduleBackup, '$description 失败，核心数据已提交: $e');
        logService.d(LogConfig.moduleBackup, stackTrace.toString());
      } catch (_) {
        // Non-critical reporting must never change the committed result.
      }
    }
  }

  Future<Map<String, String>> _restoreMediaIncrementally(
    Map<String, List<int>> sourceFiles,
    Directory destinationDirectory,
    List<File> createdFiles,
  ) async {
    final restoredPaths = <String, String>{};
    final entries = sourceFiles.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));

    for (final entry in entries) {
      final destination = await _selectIncrementalMediaDestination(
        destinationDirectory,
        entry.key,
        entry.value,
      );
      if (!await destination.exists()) {
        await destination.writeAsBytes(entry.value, flush: true);
        createdFiles.add(destination);
      }
      restoredPaths[entry.key] = destination.path;
    }
    return restoredPaths;
  }

  Future<File> _selectIncrementalMediaDestination(
    Directory directory,
    String fileName,
    List<int> bytes,
  ) async {
    final original = File(path.join(directory.path, fileName));
    if (!await original.exists() ||
        _bytesEqual(await original.readAsBytes(), bytes)) {
      return original;
    }

    final baseName = path.basenameWithoutExtension(fileName);
    final extension = path.extension(fileName);
    final contentToken = _stableContentToken(bytes);
    var collisionIndex = 0;
    while (true) {
      final suffix = collisionIndex == 0 ? '' : '_$collisionIndex';
      final candidate = File(
        path.join(directory.path, '${baseName}_$contentToken$suffix$extension'),
      );
      if (!await candidate.exists() ||
          _bytesEqual(await candidate.readAsBytes(), bytes)) {
        return candidate;
      }
      collisionIndex++;
    }
  }

  bool _bytesEqual(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  String _stableContentToken(List<int> bytes) {
    var hash = 0xcbf29ce484222325;
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x100000001b3) & 0xffffffffffffffff;
    }
    return '${hash.toRadixString(16).padLeft(16, '0')}_${bytes.length}';
  }

  String _resolveOrderMediaPath(
    String originalPath,
    Map<String, String> imagePaths,
    Directory imagesDir,
  ) {
    if (originalPath.trim().isEmpty) return '';
    final fileName = _portableBasename(originalPath);
    if (fileName.isEmpty) return originalPath;
    return imagePaths[fileName] ?? path.join(imagesDir.path, fileName);
  }

  String _resolveInvoiceMediaPath(
    String originalPath,
    Map<String, String> imagePaths,
    Map<String, String> pdfPaths,
    Directory imagesDir,
    Directory pdfsDir,
  ) {
    if (originalPath.trim().isEmpty) return '';
    final fileName = _portableBasename(originalPath);
    if (fileName.isEmpty) return originalPath;
    final isPdf = path.extension(fileName).toLowerCase() == '.pdf';
    if (isPdf && pdfPaths.containsKey(fileName)) return pdfPaths[fileName]!;
    if (imagePaths.containsKey(fileName)) return imagePaths[fileName]!;
    if (pdfPaths.containsKey(fileName)) return pdfPaths[fileName]!;
    return path.join(isPdf ? pdfsDir.path : imagesDir.path, fileName);
  }

  String _portableBasename(String value) {
    final normalized = value.replaceAll('\\', '/');
    return normalized.split('/').last;
  }

  /// Merge backup rows by complete record content. Existing rows are consumed
  /// one-for-one so genuine duplicate records keep their multiplicity, while
  /// importing the same backup again reuses those rows instead of doubling it.
  Future<_MergeSummary> _mergeDatabaseData(
    Database sourceDb,
    Database destDb, {
    required Directory imagesDir,
    required Directory pdfsDir,
    required Map<String, String> imagePaths,
    required Map<String, String> pdfPaths,
  }) async {
    const orderFingerprintColumns = [
      AppConstants.colImagePath,
      AppConstants.colShopName,
      AppConstants.colAmount,
      AppConstants.colOrderDate,
      AppConstants.colMealTime,
      AppConstants.colOrderNumber,
      AppConstants.colCreatedAt,
      AppConstants.colUpdatedAt,
    ];
    const invoiceFingerprintColumns = [
      AppConstants.colImagePath,
      AppConstants.colInvoiceNumber,
      AppConstants.colInvoiceDate,
      AppConstants.colTotalAmount,
      AppConstants.colSellerName,
      AppConstants.colCreatedAt,
      AppConstants.colUpdatedAt,
    ];

    final sourceOrders = await sourceDb.query(
      AppConstants.ordersTable,
      orderBy: AppConstants.colId,
    );
    final sourceInvoices = await sourceDb.query(
      AppConstants.invoicesTable,
      orderBy: AppConstants.colId,
    );
    final sourceRelations = await sourceDb.rawQuery('''
      SELECT r.${AppConstants.colInvoiceId}, r.${AppConstants.colOrderId}
      FROM ${AppConstants.invoiceOrderRelationsTable} r
      INNER JOIN ${AppConstants.invoicesTable} i
        ON i.${AppConstants.colId} = r.${AppConstants.colInvoiceId}
      INNER JOIN ${AppConstants.ordersTable} o
        ON o.${AppConstants.colId} = r.${AppConstants.colOrderId}
      ORDER BY
        r.${AppConstants.colOrderId} ASC,
        COALESCE(i.${AppConstants.colUpdatedAt}, '') DESC,
        COALESCE(i.${AppConstants.colCreatedAt}, '') DESC,
        r.${AppConstants.colInvoiceId} DESC
    ''');

    return destDb.transaction((transaction) async {
      final existingOrders = await transaction.query(
        AppConstants.ordersTable,
        orderBy: AppConstants.colId,
      );
      final existingInvoices = await transaction.query(
        AppConstants.invoicesTable,
        orderBy: AppConstants.colId,
      );
      final availableOrderIds = <String, ListQueue<int>>{};
      final availableInvoiceIds = <String, ListQueue<int>>{};

      for (final order in existingOrders) {
        final fingerprint = _recordFingerprint(order, orderFingerprintColumns);
        availableOrderIds
            .putIfAbsent(fingerprint, ListQueue<int>.new)
            .add((order[AppConstants.colId] as num).toInt());
      }
      for (final invoice in existingInvoices) {
        final fingerprint = _recordFingerprint(
          invoice,
          invoiceFingerprintColumns,
        );
        availableInvoiceIds
            .putIfAbsent(fingerprint, ListQueue<int>.new)
            .add((invoice[AppConstants.colId] as num).toInt());
      }

      final orderIdMap = <int, int>{};
      final invoiceIdMap = <int, int>{};
      var ordersInserted = 0;
      var invoicesInserted = 0;

      for (final sourceOrder in sourceOrders) {
        final oldId = (sourceOrder[AppConstants.colId] as num).toInt();
        final restoredOrder = Map<String, dynamic>.from(sourceOrder)
          ..remove(AppConstants.colId);
        restoredOrder[AppConstants.colImagePath] = _resolveOrderMediaPath(
          (sourceOrder[AppConstants.colImagePath] ?? '').toString(),
          imagePaths,
          imagesDir,
        );
        final fingerprint = _recordFingerprint(
          restoredOrder,
          orderFingerprintColumns,
        );
        final availableIds = availableOrderIds[fingerprint];
        if (availableIds != null && availableIds.isNotEmpty) {
          orderIdMap[oldId] = availableIds.removeFirst();
        } else {
          orderIdMap[oldId] = await transaction.insert(
            AppConstants.ordersTable,
            restoredOrder,
          );
          ordersInserted++;
        }
      }

      for (final sourceInvoice in sourceInvoices) {
        final oldId = (sourceInvoice[AppConstants.colId] as num).toInt();
        final restoredInvoice = Map<String, dynamic>.from(sourceInvoice)
          ..remove(AppConstants.colId);
        restoredInvoice[AppConstants.colImagePath] = _resolveInvoiceMediaPath(
          (sourceInvoice[AppConstants.colImagePath] ?? '').toString(),
          imagePaths,
          pdfPaths,
          imagesDir,
          pdfsDir,
        );
        final fingerprint = _recordFingerprint(
          restoredInvoice,
          invoiceFingerprintColumns,
        );
        final availableIds = availableInvoiceIds[fingerprint];
        if (availableIds != null && availableIds.isNotEmpty) {
          invoiceIdMap[oldId] = availableIds.removeFirst();
        } else {
          invoiceIdMap[oldId] = await transaction.insert(
            AppConstants.invoicesTable,
            restoredInvoice,
          );
          invoicesInserted++;
        }
      }

      final existingRelationRows = await transaction.query(
        AppConstants.invoiceOrderRelationsTable,
      );
      final existingInvoiceByOrder = <int, int>{
        for (final relation in existingRelationRows)
          (relation[AppConstants.colOrderId] as num).toInt():
              (relation[AppConstants.colInvoiceId] as num).toInt(),
      };
      final mergedSourceOrderIds = <int>{};
      var relationsInserted = 0;
      var relationConflicts = 0;

      for (final relation in sourceRelations) {
        final oldInvoiceId = (relation[AppConstants.colInvoiceId] as num)
            .toInt();
        final oldOrderId = (relation[AppConstants.colOrderId] as num).toInt();
        if (!mergedSourceOrderIds.add(oldOrderId)) continue;

        final newInvoiceId = invoiceIdMap[oldInvoiceId];
        final newOrderId = orderIdMap[oldOrderId];
        if (newInvoiceId == null || newOrderId == null) continue;

        final existingInvoiceId = existingInvoiceByOrder[newOrderId];
        if (existingInvoiceId == null) {
          await transaction.insert(
            AppConstants.invoiceOrderRelationsTable,
            {
              AppConstants.colInvoiceId: newInvoiceId,
              AppConstants.colOrderId: newOrderId,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          existingInvoiceByOrder[newOrderId] = newInvoiceId;
          relationsInserted++;
        } else if (existingInvoiceId != newInvoiceId) {
          relationConflicts++;
        }
      }

      return _MergeSummary(
        ordersInserted: ordersInserted,
        invoicesInserted: invoicesInserted,
        relationsInserted: relationsInserted,
        relationConflicts: relationConflicts,
      );
    });
  }

  String _recordFingerprint(Map<String, dynamic> record, List<String> columns) {
    return jsonEncode([
      for (final column in columns)
        if (column == AppConstants.colImagePath)
          _portableBasename((record[column] ?? '').toString())
        else if (record[column] is num)
          (record[column] as num).toDouble()
        else
          record[column],
    ]);
  }
}

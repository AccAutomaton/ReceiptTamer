import 'dart:convert';
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

/// Top-level function for zip encoding in isolate
List<int>? _encodeArchiveInIsolate(Map<String, dynamic> data) {
  final archive = Archive();
  final dbBytes = data['dbBytes'] as List<int>;

  archive.addFile(ArchiveFile.string('manifest.json', data['manifestJson'] as String));
  archive.addFile(ArchiveFile(data['dbName'] as String, dbBytes.length, dbBytes));

  _addFilesToArchive(archive, data['images'] as List);
  _addFilesToArchive(archive, data['pdfs'] as List);

  return ZipEncoder().encode(archive);
}

void _addFilesToArchive(Archive archive, List files) {
  for (final item in files) {
    final fileData = _FileData.fromMap(item as Map<String, dynamic>);
    archive.addFile(ArchiveFile(fileData.relativePath, fileData.bytes.length, fileData.bytes));
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
  final BackupMetadata? metadata;

  BackupResult({
    required this.success,
    this.filePath,
    this.errorMessage,
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
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Current app version
  String _currentAppVersion = '';

  /// Initialize the service
  Future<void> initialize() async {
    logService.i(LogConfig.moduleBackup, '初始化备份服务...');
    final packageInfo = await PackageInfo.fromPlatform();
    _currentAppVersion = packageInfo.version;
    logService.i(LogConfig.moduleBackup, '备份服务初始化完成, 应用版本: $_currentAppVersion');
  }

  /// Get current app version
  String get currentAppVersion => _currentAppVersion;

  /// Get current database version
  int get databaseVersion => AppConstants.databaseVersion;

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
    try {
      logService.i(LogConfig.moduleBackup, '========== 开始备份 ==========');
      logService.diag(LogConfig.moduleBackup, 'Output path', outputPath);

      // Ensure initialized
      if (_currentAppVersion.isEmpty) {
        await initialize();
      }

      // Get directories
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(path.join(appDir.path, AppConstants.imagesFolder));
      final pdfsDir = Directory(path.join(appDir.path, AppConstants.pdfsFolder));

      // Get database path
      final dbPath = await _dbHelper.getDatabasePath();
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        return BackupResult(
          success: false,
          errorMessage: '数据库文件不存在',
        );
      }

      // Get data counts from database
      final db = await _dbHelper.database;
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
      await _dbHelper.close();

      final dbBytes = await dbFile.readAsBytes();

      onProgress?.call(0.1);

      final (images, imageCount) = await _collectFiles(
        imagesDir,
        'images',
        onProgress: (fileProgress) => onProgress?.call(0.1 + fileProgress * 0.4),
      );

      final (pdfs, pdfCount) = await _collectFiles(
        pdfsDir,
        'pdfs',
        onProgress: (fileProgress) => onProgress?.call(0.5 + fileProgress * 0.4),
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
      final zipBytes = await compute(_encodeArchiveInIsolate, archiveData.toMap());
      if (zipBytes == null) {
        return BackupResult(
          success: false,
          errorMessage: '压缩备份文件失败',
        );
      }

      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(zipBytes);

      onProgress?.call(1.0);

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
      return BackupResult(
        success: false,
        errorMessage: '备份失败: $e',
      );
    }
  }

  /// Validate a backup file and get its metadata
  Future<BackupValidationResult> validateBackup(String zipPath) async {
    try {
      // Ensure initialized
      if (_currentAppVersion.isEmpty) {
        await initialize();
      }

      final file = File(zipPath);
      if (!await file.exists()) {
        return BackupValidationResult(
          isValid: false,
          errorMessage: '备份文件不存在',
        );
      }

      // Read zip file
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Find and parse manifest.json
      ArchiveFile? manifestFile;
      for (final file in archive) {
        if (file.name == 'manifest.json') {
          manifestFile = file;
          break;
        }
      }

      if (manifestFile == null) {
        return BackupValidationResult(
          isValid: false,
          errorMessage: '备份文件缺少 manifest.json',
        );
      }

      // Parse metadata
      final manifestContent = String.fromCharCodes(manifestFile.content as List<int>);
      final metadata = BackupMetadata.fromJson(
        jsonDecode(manifestContent) as Map<String, dynamic>,
      );

      // Check version compatibility
      bool needsVersionWarning = false;
      bool isDatabaseVersionHigher = false;
      bool canRestore = true;

      // Check database version
      if (metadata.databaseVersion > AppConstants.databaseVersion) {
        isDatabaseVersionHigher = true;
        canRestore = false;
      } else if (metadata.databaseVersion < AppConstants.databaseVersion) {
        // Lower database version - check if app version differs
        if (metadata.appVersion != _currentAppVersion) {
          needsVersionWarning = true;
        }
      } else if (metadata.appVersion != _currentAppVersion) {
        // Same database version but different app version
        needsVersionWarning = true;
      }

      return BackupValidationResult(
        isValid: true,
        metadata: metadata,
        needsVersionWarning: needsVersionWarning,
        isDatabaseVersionHigher: isDatabaseVersionHigher,
        canRestore: canRestore,
      );
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleBackup, '验证备份失败', e, stackTrace);
      return BackupValidationResult(
        isValid: false,
        errorMessage: '验证备份文件失败: $e',
      );
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
    try {
      logService.i(LogConfig.moduleBackup, '========== 开始还原 ==========');
      logService.diag(LogConfig.moduleBackup, 'Backup path', zipPath);
      logService.diag(LogConfig.moduleBackup, 'Mode', mode == RestoreMode.overwrite ? '覆盖' : '增量');

      // Validate first
      final validation = await validateBackup(zipPath);
      if (!validation.isValid || !validation.canRestore) {
        logService.w(LogConfig.moduleBackup, '备份验证失败: ${validation.errorMessage}');
        return BackupResult(
          success: false,
          errorMessage: validation.errorMessage ?? '备份文件无效或无法还原',
        );
      }

      // Read zip file
      final file = File(zipPath);
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      if (mode == RestoreMode.overwrite) {
        return await _restoreOverwrite(archive, onProgress);
      } else {
        return await _restoreIncremental(archive, onProgress);
      }
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleBackup, '还原失败', e, stackTrace);
      return BackupResult(
        success: false,
        errorMessage: '还原失败: $e',
      );
    }
  }

  /// Restore with overwrite mode
  Future<BackupResult> _restoreOverwrite(
    Archive archive,
    void Function(double progress)? onProgress,
  ) async {
    try {
      // Get directories
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(path.join(appDir.path, AppConstants.imagesFolder));
      final pdfsDir = Directory(path.join(appDir.path, AppConstants.pdfsFolder));

      // Close database
      await _dbHelper.close();

      // Clear existing data
      final dbPath = await _dbHelper.getDatabasePath();
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        await dbFile.delete();
      }

      // Clear images directory
      if (await imagesDir.exists()) {
        await for (final entity in imagesDir.list()) {
          if (entity is File) {
            await entity.delete();
          }
        }
      }

      // Clear PDFs directory
      if (await pdfsDir.exists()) {
        await for (final entity in pdfsDir.list()) {
          if (entity is File) {
            await entity.delete();
          }
        }
      }

      onProgress?.call(0.3);

      // Extract files from archive
      int totalFiles = archive.length;
      int processedFiles = 0;

      for (final file in archive) {
        final filename = file.name;

        if (filename == 'manifest.json') {
          // Skip manifest
          processedFiles++;
          continue;
        }

        if (filename.startsWith('database/')) {
          // Extract database file
          final dbBytes = file.content as List<int>;
          await dbFile.parent.create(recursive: true);
          await dbFile.writeAsBytes(dbBytes);
        } else if (filename.startsWith('images/')) {
          // Extract image file
          await imagesDir.create(recursive: true);
          final imageFile = File(path.join(imagesDir.path, path.basename(filename)));
          await imageFile.writeAsBytes(file.content as List<int>);
        } else if (filename.startsWith('pdfs/')) {
          // Extract PDF file
          await pdfsDir.create(recursive: true);
          final pdfFile = File(path.join(pdfsDir.path, path.basename(filename)));
          await pdfFile.writeAsBytes(file.content as List<int>);
        }

        processedFiles++;
        onProgress?.call(0.3 + (processedFiles / totalFiles) * 0.6);
      }

      // Reopen database (this will trigger onUpgrade if needed)
      await _dbHelper.database;

      onProgress?.call(1.0);

      logService.i(LogConfig.moduleBackup, '========== 覆盖还原完成 ==========');
      return BackupResult(
        success: true,
        filePath: null,
        metadata: null,
      );
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleBackup, '覆盖还原失败', e, stackTrace);
      return BackupResult(
        success: false,
        errorMessage: '覆盖还原失败: $e',
      );
    }
  }

  /// Restore with incremental mode
  Future<BackupResult> _restoreIncremental(
    Archive archive,
    void Function(double progress)? onProgress,
  ) async {
    try {
      // Get directories
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(path.join(appDir.path, AppConstants.imagesFolder));
      final pdfsDir = Directory(path.join(appDir.path, AppConstants.pdfsFolder));

      // Ensure directories exist
      await imagesDir.create(recursive: true);
      await pdfsDir.create(recursive: true);

      // Extract database to temp file
      final tempDir = await getTemporaryDirectory();
      final tempDbPath = path.join(tempDir.path, 'temp_restore.db');
      final tempDbFile = File(tempDbPath);

      ArchiveFile? dbArchiveFile;
      for (final file in archive) {
        if (file.name.startsWith('database/')) {
          dbArchiveFile = file;
          break;
        }
      }

      if (dbArchiveFile == null) {
        return BackupResult(
          success: false,
          errorMessage: '备份文件缺少数据库文件',
        );
      }

      await tempDbFile.writeAsBytes(dbArchiveFile.content as List<int>);

      onProgress?.call(0.3);

      // Open temp database
      final tempDb = await openDatabase(
        tempDbPath,
        version: AppConstants.databaseVersion,
        onCreate: (_, __) {},
        onUpgrade: (_, __, ___) {},
      );

      // Get current database
      final currentDb = await _dbHelper.database;

      // Merge data (inserts all records as new with new IDs)
      await _mergeDatabaseData(tempDb, currentDb);

      // Close temp database
      await tempDb.close();

      // Delete temp file
      if (await tempDbFile.exists()) {
        await tempDbFile.delete();
      }

      onProgress?.call(0.7);

      // Extract images and PDFs (rename if file exists)
      for (final file in archive) {
        final filename = file.name;

        if (filename.startsWith('images/')) {
          await _extractFileWithRename(
            file.content as List<int>,
            imagesDir.path,
            path.basename(filename),
          );
        } else if (filename.startsWith('pdfs/')) {
          await _extractFileWithRename(
            file.content as List<int>,
            pdfsDir.path,
            path.basename(filename),
          );
        }
      }

      onProgress?.call(1.0);

      logService.i(LogConfig.moduleBackup, '========== 增量还原完成 ==========');
      return BackupResult(
        success: true,
        filePath: null,
        metadata: null,
      );
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleBackup, '增量还原失败', e, stackTrace);
      return BackupResult(
        success: false,
        errorMessage: '增量还原失败: $e',
      );
    }
  }

  /// Extract file with rename if it already exists
  Future<void> _extractFileWithRename(
    List<int> bytes,
    String directory,
    String filename,
  ) async {
    var destFile = File(path.join(directory, filename));

    if (await destFile.exists()) {
      // Rename file with timestamp suffix
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final name = path.basenameWithoutExtension(filename);
      final ext = path.extension(filename);
      final newFilename = '${name}_$timestamp$ext';
      destFile = File(path.join(directory, newFilename));
    }

    await destFile.writeAsBytes(bytes);
  }

  /// Merge data from source database to destination database
  /// All records from backup are inserted as new records with new IDs
  /// Relations are updated with the new ID mappings
  Future<void> _mergeDatabaseData(
    Database sourceDb,
    Database destDb,
  ) async {
    // ID mapping: old ID -> new ID
    final orderIdMap = <int, int>{};
    final invoiceIdMap = <int, int>{};

    // Insert all orders as new records
    final sourceOrders = await sourceDb.query(AppConstants.ordersTable);
    for (final order in sourceOrders) {
      final oldOrderId = order[AppConstants.colId] as int;

      // Create a copy without the ID field (let database assign new ID)
      final newOrder = Map<String, dynamic>.from(order);
      newOrder.remove(AppConstants.colId);

      final newId = await destDb.insert(
        AppConstants.ordersTable,
        newOrder,
      );

      orderIdMap[oldOrderId] = newId;
    }

    // Insert all invoices as new records
    final sourceInvoices = await sourceDb.query(AppConstants.invoicesTable);
    for (final invoice in sourceInvoices) {
      final oldInvoiceId = invoice[AppConstants.colId] as int;

      // Create a copy without the ID field
      final newInvoice = Map<String, dynamic>.from(invoice);
      newInvoice.remove(AppConstants.colId);

      final newId = await destDb.insert(
        AppConstants.invoicesTable,
        newInvoice,
      );

      invoiceIdMap[oldInvoiceId] = newId;
    }

    // Insert relations with new IDs
    final sourceRelations = await sourceDb.query(AppConstants.invoiceOrderRelationsTable);
    for (final relation in sourceRelations) {
      final oldInvoiceId = relation[AppConstants.colInvoiceId] as int;
      final oldOrderId = relation[AppConstants.colOrderId] as int;

      // Get new IDs from mapping
      final newInvoiceId = invoiceIdMap[oldInvoiceId];
      final newOrderId = orderIdMap[oldOrderId];

      // Only insert if both IDs exist in the mapping
      if (newInvoiceId != null && newOrderId != null) {
        await destDb.insert(
          AppConstants.invoiceOrderRelationsTable,
          {
            AppConstants.colInvoiceId: newInvoiceId,
            AppConstants.colOrderId: newOrderId,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
  }
}
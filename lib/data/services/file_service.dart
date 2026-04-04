import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/log_service.dart';
import '../../core/services/log_config.dart';

/// File service for file management operations
/// Handles directory creation, file deletion, and file info retrieval
class FileService {
  /// MethodChannel for getting Android filesDir path
  static const MethodChannel _channel = MethodChannel('com.acautomaton.receipt.tamer/storage');

  /// Save bytes to Download/ReceiptTamer/[subDir] directory
  /// [subDir] example: "materials/20260331" or "backup/20260331"
  /// Returns the saved file path, or null if failed
  Future<String?> saveToDownloadDirectory({
    required String fileName,
    required List<int> bytes,
    String subDir = '',
  }) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'saveToDownloadDirectory',
        {
          'fileName': fileName,
          'bytes': Uint8List.fromList(bytes),
          'subDir': subDir,
        },
      );

      if (result != null && result['success'] == true) {
        return result['path'] as String?;
      } else {
        logService.e(LogConfig.moduleFile, '保存文件失败: ${result?['error']}');
        return null;
      }
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleFile, '保存到下载目录失败', e, stackTrace);
      return null;
    }
  }

  /// Copy file to Download/ReceiptTamer/[subDir] directory
  /// [subDir] example: "materials/20260331" or "backup/20260331"
  /// Returns the destination path, or null if failed
  Future<String?> copyToDownloadDirectory(
    String sourcePath, {
    String? customFileName,
    String subDir = '',
  }) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'copyToDownloadDirectory',
        {
          'sourcePath': sourcePath,
          'customFileName': customFileName,
          'subDir': subDir,
        },
      );

      if (result != null && result['success'] == true) {
        return result['path'] as String?;
      } else {
        logService.e(LogConfig.moduleFile, '复制文件失败: ${result?['error']}');
        return null;
      }
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleFile, '复制到下载目录失败', e, stackTrace);
      return null;
    }
  }

  /// Get the Download/ReceiptTamer/[subDir] directory path for display
  /// Returns the path string (e.g., "/storage/emulated/0/Download/ReceiptTamer/materials/20260331")
  Future<String?> getDownloadDirectoryPath({String subDir = ''}) async {
    try {
      final path = await _channel.invokeMethod<String>(
        'getDownloadDirectoryPath',
        {'subDir': subDir},
      );
      return path;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleFile, '获取下载目录路径失败', e, stackTrace);
      return null;
    }
  }

  /// Open file with system default application
  /// Returns true if successful, false otherwise
  Future<bool> openFile(String filePath) async {
    try {
      final result = await OpenFile.open(filePath);
      return result.type == ResultType.done;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleFile, '打开文件失败', e, stackTrace);
      return false;
    }
  }

  /// Open file manager and navigate to the specified directory
  /// [subDir] example: "materials/20260331" or "backup/20260331"
  /// Returns true if successful, false otherwise
  Future<bool> openFileManager({String subDir = ''}) async {
    try {
      final success = await _channel.invokeMethod<bool>(
        'openFileManager',
        {'subDir': subDir},
      );
      return success ?? false;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleFile, '打开文件管理器失败', e, stackTrace);
      return false;
    }
  }

  /// List files in Download/ReceiptTamer/[subDir] directory
  /// [subDir] example: "materials/20260331" or "backup/20260331"
  /// Returns list of files with name, path, size, date, uri fields
  Future<List<Map<String, dynamic>>> listFilesInDirectory({String subDir = ''}) async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'listFilesInDirectory',
        {'subDir': subDir},
      );
      if (result == null) return [];
      return result.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleFile, '列出文件失败', e, stackTrace);
      return [];
    }
  }

  /// List sub-directories under Download/ReceiptTamer/[parentDir]
  /// [parentDir] example: "materials" or "backup"
  /// Returns list of directories with name, path fields
  Future<List<Map<String, dynamic>>> listSubDirectories({String parentDir = ''}) async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'listSubDirectories',
        {'parentDir': parentDir},
      );
      if (result == null) return [];
      return result.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleFile, '列出子目录失败', e, stackTrace);
      return [];
    }
  }

  /// Share a file using system share dialog
  /// [fileUri] the content URI or file path
  /// [fileName] the file name to display
  /// [mimeType] the MIME type of the file
  /// Returns true if successful, false otherwise
  Future<bool> shareFile(String fileUri, String fileName, String mimeType) async {
    try {
      final success = await _channel.invokeMethod<bool>(
        'shareFile',
        {'fileUri': fileUri, 'fileName': fileName, 'mimeType': mimeType},
      );
      return success ?? false;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleFile, '分享文件失败', e, stackTrace);
      return false;
    }
  }

  /// Get MIME type from file name
  String getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'zip':
        return 'application/zip';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'txt':
        return 'text/plain';
      case 'json':
        return 'application/json';
      case 'apk':
        return 'application/vnd.android.package-archive';
      default:
        return 'application/octet-stream';
    }
  }

  /// Get the application documents directory
  Future<Directory> getAppDirectory() async {
    return await getApplicationDocumentsDirectory();
  }

  /// Get or create the images directory
  Future<Directory> getImagesDirectory() async {
    final appDir = await getAppDirectory();
    final imagesDir = Directory(path.join(appDir.path, AppConstants.imagesFolder));

    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    return imagesDir;
  }

  /// Get or create the PDFs directory
  Future<Directory> getPdfsDirectory() async {
    final appDir = await getAppDirectory();
    final pdfsDir = Directory(path.join(appDir.path, AppConstants.pdfsFolder));

    if (!await pdfsDir.exists()) {
      await pdfsDir.create(recursive: true);
    }

    return pdfsDir;
  }

  /// Create a directory if it doesn't exist
  Future<bool> createDirectory(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete a file at the given path
  Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Delete a directory and all its contents
  Future<bool> deleteDirectory(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Check if a file exists
  Future<bool> fileExists(String filePath) async {
    try {
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// Check if a directory exists
  Future<bool> directoryExists(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      return await dir.exists();
    } catch (e) {
      return false;
    }
  }

  /// Get file size in bytes
  Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Get directory size in bytes
  Future<int> getDirectorySize(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) return 0;

      int totalSize = 0;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  /// Get file extension
  String getFileExtension(String filePath) {
    return path.extension(filePath);
  }

  /// Get file name without extension
  String getFileNameWithoutExtension(String filePath) {
    return path.basenameWithoutExtension(filePath);
  }

  /// Get file name with extension
  String getFileName(String filePath) {
    return path.basename(filePath);
  }

  /// Format file size to human readable string
  String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// Get file last modified date
  Future<DateTime?> getFileLastModified(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final stat = await file.stat();
        return stat.modified;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// List all files in a directory
  Future<List<File>> listFiles(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) return [];

      final entities = await dir.list().toList();
      final files = <File>[];

      for (final entity in entities) {
        if (entity is File) {
          files.add(entity);
        }
      }

      return files;
    } catch (e) {
      return [];
    }
  }

  /// List all files with a specific extension
  Future<List<File>> listFilesByExtension(String dirPath, String extension) async {
    try {
      final files = await listFiles(dirPath);
      return files.where((file) {
        final ext = path.extension(file.path).toLowerCase();
        return ext == extension.toLowerCase();
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Clean up temporary files
  /// Includes: temp directory, file_picker cache, backup temp files
  Future<int> cleanTempFiles() async {
    int deletedCount = 0;

    try {
      final tempDir = await getTemporaryDirectory();

      // Clean temp directory recursively
      deletedCount += await _cleanDirectoryRecursively(tempDir);

      // Also clean any backup temp files in app documents directory
      final appDir = await getAppDirectory();
      final backupTempFile = File(path.join(appDir.path, 'temp_restore.db'));
      if (await backupTempFile.exists()) {
        try {
          await backupTempFile.delete();
          deletedCount++;
        } catch (e) {
          // Ignore
        }
      }
    } catch (e) {
      // Ignore errors
    }

    return deletedCount;
  }

  /// Clean a directory recursively, including all subdirectories
  Future<int> _cleanDirectoryRecursively(Directory dir) async {
    int deletedCount = 0;

    try {
      if (!await dir.exists()) return 0;

      await for (final entity in dir.list()) {
        if (entity is File) {
          try {
            await entity.delete();
            deletedCount++;
          } catch (e) {
            // Skip files that can't be deleted (may be in use)
          }
        } else if (entity is Directory) {
          // Recursively clean subdirectories
          deletedCount += await _cleanDirectoryRecursively(entity);
          // Try to delete empty directory
          try {
            if (await entity.exists()) {
              final contents = await entity.list().toList();
              if (contents.isEmpty) {
                await entity.delete();
              }
            }
          } catch (e) {
            // Ignore
          }
        }
      }
    } catch (e) {
      // Ignore errors
    }

    return deletedCount;
  }

  /// Delete a file if it's in the temporary directory
  /// Returns true if file was deleted, false otherwise
  Future<bool> deleteTempFile(String filePath) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File(filePath);

      // Only delete if file exists and is in temp directory
      if (await file.exists() && filePath.startsWith(tempDir.path)) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get app storage usage info
  /// Returns a map with storage sizes for: images, pdfs, data, model, cache
  Future<Map<String, int>> getStorageUsage() async {
    final appDir = await getAppDirectory();
    final imagesDir = await getImagesDirectory();
    final pdfsDir = await getPdfsDirectory();

    // Database size
    final dbPath = await _getDatabasePath();
    int dbSize = 0;
    if (dbPath != null) {
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        dbSize = await dbFile.length();
      }
    }

    // Model size (stored in Android filesDir/qwen3.5-0.8b/)
    // Flutter's getApplicationDocumentsDirectory() returns app_flutter/,
    // but Android's filesDir is files/
    final modelSize = await _getModelSize(appDir.path);

    // Cache size
    final tempDir = await getTemporaryDirectory();
    final cacheSize = await getDirectorySize(tempDir.path);

    // Image and PDF sizes
    final imagesSize = await getDirectorySize(imagesDir.path);
    final pdfsSize = await getDirectorySize(pdfsDir.path);

    return {
      'images': imagesSize,
      'pdfs': pdfsSize,
      'data': dbSize,
      'model': modelSize,
      'cache': cacheSize,
    };
  }

  /// Get model directory size
  /// Model is stored in Android's filesDir (not app_flutter)
  Future<int> _getModelSize(String flutterDocPath) async {
    try {
      // Get filesDir path directly from Android via MethodChannel
      final filesDirPath = await _channel.invokeMethod<String>('getFilesDirPath');
      if (filesDirPath == null) {
        logService.w(LogConfig.moduleFile, '从 Android 获取 filesDir 路径失败');
        return 0;
      }

      final modelDirPath = path.join(filesDirPath, 'qwen3.5-0.8b');
      logService.d(LogConfig.moduleFile, '模型目录路径: $modelDirPath');

      return await getDirectorySize(modelDirPath);
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleFile, '获取模型大小失败', e, stackTrace);
      return 0;
    }
  }

  /// Get database file path
  Future<String?> _getDatabasePath() async {
    try {
      // Use sqflite's getDatabasesPath
      final databasesPath = await getDatabasesPath();
      return path.join(databasesPath, AppConstants.databaseName);
    } catch (e) {
      return null;
    }
  }

  /// Get total storage size
  Future<int> getTotalStorageSize() async {
    final usage = await getStorageUsage();
    return usage.values.fold<int>(0, (sum, size) => sum + size);
  }

  /// Copy file to a new location
  Future<bool> copyFile(String sourcePath, String destinationPath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) return false;

      final destFile = File(destinationPath);
      await sourceFile.copy(destinationPath);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Move file to a new location
  Future<bool> moveFile(String sourcePath, String destinationPath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) return false;

      final destFile = File(destinationPath);
      await sourceFile.rename(destinationPath);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Save a PDF file to the app's PDFs directory
  Future<String> savePdf(File pdfFile) async {
    try {
      final pdfsDir = await getPdfsDirectory();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}${path.extension(pdfFile.path)}';
      final savedPath = path.join(pdfsDir.path, fileName);

      // Copy the file to the app's PDFs directory
      await pdfFile.copy(savedPath);
      return savedPath;
    } catch (e) {
      rethrow;
    }
  }
}

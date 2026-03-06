import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../../core/constants/app_constants.dart';

/// File service for file management operations
/// Handles directory creation, file deletion, and file info retrieval
class FileService {
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
  Future<int> cleanTempFiles() async {
    int deletedCount = 0;

    try {
      final tempDir = await getTemporaryDirectory();
      final entities = await tempDir.list().toList();

      for (final entity in entities) {
        if (entity is File) {
          try {
            await entity.delete();
            deletedCount++;
          } catch (e) {
            // Skip files that can't be deleted
          }
        }
      }
    } catch (e) {
      // Ignore errors
    }

    return deletedCount;
  }

  /// Get app storage usage info
  Future<Map<String, int>> getStorageUsage() async {
    final imagesDir = await getImagesDirectory();
    final pdfsDir = await getPdfsDirectory();

    return {
      'images': await getDirectorySize(imagesDir.path),
      'pdfs': await getDirectorySize(pdfsDir.path),
      'total': await getDirectorySize((await getAppDirectory()).path),
    };
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
}

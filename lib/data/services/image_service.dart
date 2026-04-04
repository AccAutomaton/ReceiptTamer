import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../../core/constants/app_constants.dart';
import '../../core/services/log_config.dart';
import '../../core/services/log_service.dart';

/// Image service for handling image operations
/// Supports saving, loading, and deleting images from device storage
class ImageService {
  final ImagePicker _imagePicker = ImagePicker();

  /// Get the application documents directory
  Future<Directory> _getAppDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(path.join(appDir.path, AppConstants.imagesFolder));

    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    return imagesDir;
  }

  /// Pick an image from gallery
  Future<File?> pickImageFromGallery() async {
    final XFile? pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: AppConstants.imageQuality,
    );

    if (pickedFile == null) return null;

    return File(pickedFile.path);
  }

  /// Pick an image from camera
  Future<File?> pickImageFromCamera() async {
    final XFile? pickedFile = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: AppConstants.imageQuality,
    );

    if (pickedFile == null) return null;

    return File(pickedFile.path);
  }

  /// Pick multiple images from gallery
  Future<List<File>> pickMultipleImages() async {
    final List<XFile> pickedFiles = await _imagePicker.pickMultiImage(
      imageQuality: AppConstants.imageQuality,
    );

    return pickedFiles.map((xFile) => File(xFile.path)).toList();
  }

  /// Save image to app directory with a unique filename
  Future<String> saveImage(File imageFile) async {
    try {
      final imagesDir = await _getAppDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(imageFile.path);
      final filename = 'img_$timestamp$extension';
      final savedPath = path.join(imagesDir.path, filename);

      final savedFile = await imageFile.copy(savedPath);
      logService.i(LogConfig.moduleFile, '图片已保存: ${savedFile.path}');
      return savedFile.path;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleFile, '图片保存失败', e, stackTrace);
      rethrow;
    }
  }

  /// Save image bytes to app directory
  Future<String> saveImageBytes(Uint8List imageBytes, String extension) async {
    try {
      final imagesDir = await _getAppDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'img_$timestamp$extension';
      final savedPath = path.join(imagesDir.path, filename);

      final file = File(savedPath);
      await file.writeAsBytes(imageBytes);
      logService.diag(LogConfig.moduleFile, '图片大小', '${imageBytes.length} bytes');
      logService.i(LogConfig.moduleFile, '图片字节已保存: $savedPath');
      return savedPath;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleFile, '图片字节保存失败', e, stackTrace);
      rethrow;
    }
  }

  /// Load an image from the given path
  Future<File?> loadImage(String imagePath) async {
    final file = File(imagePath);
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  /// Delete an image by path
  Future<bool> deleteImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        logService.i(LogConfig.moduleFile, '图片已删除: $imagePath');
        return true;
      }
      return false;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleFile, '图片删除失败: $imagePath', e, stackTrace);
      return false;
    }
  }

  /// Get image file size
  Future<int> getImageSize(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      return 0;
    }
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

  /// Check if a path is a valid image
  bool isImagePath(String? path) {
    if (path == null || path.isEmpty) return false;
    final ext = path.toLowerCase();
    return ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.png') ||
        ext.endsWith('.gif') ||
        ext.endsWith('.bmp') ||
        ext.endsWith('.webp');
  }

  /// Check if a path is a PDF
  bool isPdfPath(String? path) {
    if (path == null || path.isEmpty) return false;
    return path.toLowerCase().endsWith('.pdf');
  }

  /// Get all saved images
  Future<List<File>> getAllImages() async {
    try {
      final imagesDir = await _getAppDirectory();
      final entities = await imagesDir.list().toList();

      final imageFiles = <File>[];
      for (final entity in entities) {
        if (entity is File && isImagePath(entity.path)) {
          imageFiles.add(entity);
        }
      }

      // Sort by modification time, newest first
      imageFiles.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      return imageFiles;
    } catch (e) {
      return [];
    }
  }

  /// Get total size of all images in storage
  Future<int> getTotalImagesSize() async {
    final images = await getAllImages();
    int totalSize = 0;

    for (final image in images) {
      totalSize += await image.length();
    }

    return totalSize;
  }

  /// Clear all unused images (images not referenced in database)
  /// This requires passing a set of used image paths
  Future<int> clearUnusedImages(Set<String> usedPaths) async {
    logService.i(LogConfig.moduleFile, '开始清理未使用图片，已使用图片数: ${usedPaths.length}');
    final allImages = await getAllImages();
    int deletedCount = 0;

    for (final image in allImages) {
      if (!usedPaths.contains(image.path)) {
        if (await deleteImage(image.path)) {
          deletedCount++;
        }
      }
    }

    logService.i(LogConfig.moduleFile, '未使用图片清理完成，已删除: $deletedCount 张');
    return deletedCount;
  }
}

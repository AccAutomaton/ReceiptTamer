import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../../core/constants/app_constants.dart';
import '../models/app_version.dart';

/// Update check result
enum UpdateCheckResult {
  available,
  notAvailable,
  error,
}

/// Result of checking for updates
class UpdateCheckResponse {
  final UpdateCheckResult result;
  final AppVersion? latestVersion;
  final String? errorMessage;
  final String? currentVersion;

  const UpdateCheckResponse({
    required this.result,
    this.latestVersion,
    this.errorMessage,
    this.currentVersion,
  });
}

/// Download progress info
class DownloadProgress {
  final int downloadedBytes;
  final int totalBytes;
  final double progress;
  final int speed; // bytes per second

  const DownloadProgress({
    required this.downloadedBytes,
    required this.totalBytes,
    required this.progress,
    required this.speed,
  });

  String get formattedDownloaded => _formatBytes(downloadedBytes);
  String get formattedTotal => _formatBytes(totalBytes);
  String get formattedSpeed => _formatBytes(speed);

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Download result
class DownloadResult {
  final String? filePath;
  final bool success;
  final String? errorMessage;
  final bool wasResumed;

  const DownloadResult({
    this.filePath,
    required this.success,
    this.errorMessage,
    this.wasResumed = false,
  });
}

/// Service for checking and downloading app updates from GitHub Releases
class UpdateService {
  /// GitHub API base URL
  static const String _githubApiBaseUrl = 'https://api.github.com';

  /// APK file name for downloads (fixed name for resume support)
  static const String _apkFileName = 'app-update.apk';

  /// Get the latest release API URL
  String get _latestReleaseUrl =>
      '$_githubApiBaseUrl/repos/${AppConstants.githubOwner}/${AppConstants.githubRepo}/releases/latest';

  /// HTTP client
  final http.Client _httpClient;

  /// Connectivity instance for network detection
  final Connectivity _connectivity;

  /// Constructor
  UpdateService({http.Client? httpClient, Connectivity? connectivity})
      : _httpClient = httpClient ?? http.Client(),
        _connectivity = connectivity ?? Connectivity();

  /// Check if connected to WiFi
  Future<bool> isWifiConnection() async {
    final results = await _connectivity.checkConnectivity();
    return results.contains(ConnectivityResult.wifi);
  }

  /// Check if has any network connection
  Future<bool> hasNetworkConnection() async {
    final results = await _connectivity.checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  /// Get current app version
  Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  /// Check for updates
  /// Returns UpdateCheckResponse with the latest version info
  Future<UpdateCheckResponse> checkForUpdates() async {
    try {
      // Get current version
      final currentVersion = await getCurrentVersion();

      // Fetch latest release from GitHub
      debugPrint('UpdateService: Requesting $_latestReleaseUrl');
      final response = await _httpClient.get(
        Uri.parse(_latestReleaseUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': '${AppConstants.appName}/$currentVersion',
        },
      );

      debugPrint('UpdateService: Response status ${response.statusCode}');
      debugPrint('UpdateService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final json = _parseJson(response.body);
        if (json == null) {
          return UpdateCheckResponse(
            result: UpdateCheckResult.error,
            errorMessage: 'Failed to parse release info',
            currentVersion: currentVersion,
          );
        }

        final latestVersion = AppVersion.fromGitHubRelease(json);
        debugPrint('UpdateService: Latest version: ${latestVersion.version}, Current: $currentVersion');

        // Check if update is available
        if (latestVersion.isNewerThan(currentVersion)) {
          return UpdateCheckResponse(
            result: UpdateCheckResult.available,
            latestVersion: latestVersion,
            currentVersion: currentVersion,
          );
        } else {
          return UpdateCheckResponse(
            result: UpdateCheckResult.notAvailable,
            latestVersion: latestVersion,
            currentVersion: currentVersion,
          );
        }
      } else if (response.statusCode == 403) {
        // Rate limited by GitHub API
        debugPrint('UpdateService: Rate limited by GitHub API');
        return UpdateCheckResponse(
          result: UpdateCheckResult.error,
          errorMessage: 'RATE_LIMITED',
          currentVersion: currentVersion,
        );
      } else if (response.statusCode == 404) {
        // No releases found
        return UpdateCheckResponse(
          result: UpdateCheckResult.notAvailable,
          currentVersion: currentVersion,
        );
      } else {
        return UpdateCheckResponse(
          result: UpdateCheckResult.error,
          errorMessage: 'Server returned ${response.statusCode}',
          currentVersion: currentVersion,
        );
      }
    } catch (e) {
      debugPrint('UpdateService: Error checking for updates: $e');
      return UpdateCheckResponse(
        result: UpdateCheckResult.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Get the APK file path for download
  Future<String> getApkFilePath() async {
    final tempDir = await getTemporaryDirectory();
    return path.join(tempDir.path, _apkFileName);
  }

  /// Get existing partial download size
  Future<int> getExistingDownloadSize(String url) async {
    try {
      final filePath = await getApkFilePath();
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
    } catch (e) {
      debugPrint('Error checking existing download: $e');
    }
    return 0;
  }

  /// Clear existing partial download
  Future<void> clearPartialDownload() async {
    try {
      final filePath = await getApkFilePath();
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('Cleared partial download: $filePath');
      }
    } catch (e) {
      debugPrint('Error clearing partial download: $e');
    }
  }

  /// Download APK file with resume support
  /// Returns DownloadResult with file path when complete
  /// onProgress is called with DownloadProgress info
  Future<DownloadResult> downloadApkWithResume(
    String url, {
    void Function(DownloadProgress progress)? onProgress,
    bool forceRestart = false,
  }) async {
    try {
      final filePath = await getApkFilePath();
      final file = File(filePath);

      // Check existing partial download
      int existingSize = 0;
      bool wasResumed = false;

      if (!forceRestart && await file.exists()) {
        existingSize = await file.length();
        if (existingSize > 0) {
          wasResumed = true;
          debugPrint('Resuming download from byte $existingSize');
        }
      } else if (forceRestart && await file.exists()) {
        await file.delete();
      }

      // Build request with Range header if resuming
      final request = http.Request('GET', Uri.parse(url));
      if (existingSize > 0) {
        request.headers['Range'] = 'bytes=$existingSize-';
      }

      final response = await _httpClient.send(request);

      // Check response status
      // 200 = full download, 206 = partial download (resume)
      if (response.statusCode != 200 && response.statusCode != 206) {
        debugPrint('Download failed: ${response.statusCode}');
        return DownloadResult(
          success: false,
          errorMessage: 'Server returned ${response.statusCode}',
        );
      }

      final contentLength = response.contentLength ?? 0;
      final totalBytes = existingSize + contentLength;
      int downloadedBytes = existingSize;

      // Calculate download speed
      int speed = 0;
      int lastBytes = downloadedBytes;
      final speedStopwatch = Stopwatch()..start();

      // Write to file (append mode if resuming)
      final sink = file.openWrite(mode: existingSize > 0 ? FileMode.append : FileMode.write);
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          downloadedBytes += chunk.length;

          // Calculate speed every second
          if (speedStopwatch.elapsedMilliseconds >= 500) {
            final elapsed = speedStopwatch.elapsedMilliseconds;
            speed = ((downloadedBytes - lastBytes) * 1000 ~/ elapsed);
            lastBytes = downloadedBytes;
            speedStopwatch.reset();
          }

          if (totalBytes > 0) {
            onProgress?.call(DownloadProgress(
              downloadedBytes: downloadedBytes,
              totalBytes: totalBytes,
              progress: downloadedBytes / totalBytes,
              speed: speed,
            ));
          }
        }

        await sink.flush();
        await sink.close();

        debugPrint('Download complete: $filePath');
        return DownloadResult(
          filePath: filePath,
          success: true,
          wasResumed: wasResumed,
        );
      } catch (e) {
        await sink.close();
        debugPrint('Download error: $e');
        // Keep partial file for resume
        return DownloadResult(
          success: false,
          errorMessage: e.toString(),
        );
      }
    } catch (e) {
      debugPrint('Download error: $e');
      return DownloadResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Download APK file (legacy method for compatibility)
  /// Returns the file path when complete
  /// onProgress is called with progress between 0.0 and 1.0
  Future<String?> downloadApk(
    String url, {
    void Function(double progress)? onProgress,
    void Function()? onCancel,
  }) async {
    final result = await downloadApkWithResume(
      url,
      onProgress: (p) => onProgress?.call(p.progress),
    );
    return result.filePath;
  }

  /// Install APK file
  /// Returns true if installation was initiated successfully
  Future<bool> installApk(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('APK file not found: $filePath');
        return false;
      }

      final result = await OpenFile.open(filePath);
      debugPrint('OpenFile result: ${result.type} - ${result.message}');

      return result.type == ResultType.done;
    } catch (e) {
      debugPrint('Install error: $e');
      return false;
    }
  }

  /// Delete APK file after installation
  Future<void> deleteApk(String? filePath) async {
    if (filePath == null) return;

    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('Deleted APK: $filePath');
      }
    } catch (e) {
      debugPrint('Error deleting APK: $e');
    }
  }

  /// Parse JSON string safely
  Map<String, dynamic>? _parseJson(String body) {
    try {
      return json.decode(body) as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('JSON parse error: $e');
      return null;
    }
  }

  /// Dispose resources
  void dispose() {
    _httpClient.close();
  }
}
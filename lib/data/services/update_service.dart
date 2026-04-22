import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../../core/constants/app_constants.dart';
import '../../core/services/log_service.dart';
import '../../core/services/log_config.dart';
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

/// Result of fetching all releases
class FetchReleasesResult {
  final bool success;
  final List<AppVersion> releases;
  final String? errorMessage;
  final int? nextPage; // Next page number for pagination, null if no more pages
  final bool rateLimited;

  const FetchReleasesResult({
    required this.success,
    this.releases = const [],
    this.errorMessage,
    this.nextPage,
    this.rateLimited = false,
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

  /// Get all releases API URL (with pagination)
  String getAllReleasesUrl({int perPage = 30, int page = 1}) =>
      '$_githubApiBaseUrl/repos/${AppConstants.githubOwner}/${AppConstants.githubRepo}/releases?per_page=$perPage&page=$page';

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
      logService.i(LogConfig.moduleUpdate, '========== 开始检查更新 ==========');
      // Get current version
      final currentVersion = await getCurrentVersion();
      logService.diag(LogConfig.moduleUpdate, 'Current version', currentVersion);

      // Fetch latest release from GitHub
      logService.i(LogConfig.moduleUpdate, '请求 $_latestReleaseUrl');
      final response = await _httpClient.get(
        Uri.parse(_latestReleaseUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': '${AppConstants.appName}/$currentVersion',
        },
      );

      logService.i(LogConfig.moduleUpdate, '响应状态 ${response.statusCode}');

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
        logService.i(LogConfig.moduleUpdate, '最新版本: ${latestVersion.version}，当前版本: $currentVersion');

        // Check if update is available
        if (latestVersion.isNewerThan(currentVersion)) {
          logService.i(LogConfig.moduleUpdate, '发现新版本: ${latestVersion.version}');
          logService.i(LogConfig.moduleUpdate, '========== 检查更新完成 (有更新) ==========');
          return UpdateCheckResponse(
            result: UpdateCheckResult.available,
            latestVersion: latestVersion,
            currentVersion: currentVersion,
          );
        } else {
          logService.i(LogConfig.moduleUpdate, '已是最新版本');
          logService.i(LogConfig.moduleUpdate, '========== 检查更新完成 (无更新) ==========');
          return UpdateCheckResponse(
            result: UpdateCheckResult.notAvailable,
            latestVersion: latestVersion,
            currentVersion: currentVersion,
          );
        }
      } else if (response.statusCode == 403) {
        // Rate limited by GitHub API
        logService.w(LogConfig.moduleUpdate, 'GitHub API 请求限流');
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
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleUpdate, '检查更新失败', e, stackTrace);
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
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleUpdate, '检查已下载文件失败', e, stackTrace);
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
        logService.i(LogConfig.moduleUpdate, '已清除部分下载: $filePath');
      }
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleUpdate, '清除部分下载失败', e, stackTrace);
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
      logService.i(LogConfig.moduleUpdate, '========== 开始下载 APK ==========');
      logService.diag(LogConfig.moduleUpdate, 'URL', url);
      logService.diag(LogConfig.moduleUpdate, 'Force restart', forceRestart);

      final filePath = await getApkFilePath();
      final file = File(filePath);

      // Check existing partial download
      int existingSize = 0;
      bool wasResumed = false;

      if (!forceRestart && await file.exists()) {
        existingSize = await file.length();
        if (existingSize > 0) {
          wasResumed = true;
          logService.i(LogConfig.moduleUpdate, '从 $existingSize 字节处继续下载');
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
        logService.e(LogConfig.moduleUpdate, '下载失败: ${response.statusCode}');
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

        logService.diag(LogConfig.moduleUpdate, 'Total size', '$downloadedBytes bytes');
        logService.i(LogConfig.moduleUpdate, '========== 下载完成 ==========');
        logService.i(LogConfig.moduleUpdate, '下载完成: $filePath');
        return DownloadResult(
          filePath: filePath,
          success: true,
          wasResumed: wasResumed,
        );
      } catch (e, stackTrace) {
        await sink.close();
        logService.e(LogConfig.moduleUpdate, '下载错误', e, stackTrace);
        // Keep partial file for resume
        return DownloadResult(
          success: false,
          errorMessage: e.toString(),
        );
      }
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleUpdate, '下载错误', e, stackTrace);
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
      logService.i(LogConfig.moduleUpdate, '========== 开始安装 APK ==========');
      logService.diag(LogConfig.moduleUpdate, 'APK path', filePath);

      final file = File(filePath);
      if (!await file.exists()) {
        logService.w(LogConfig.moduleUpdate, 'APK 文件不存在: $filePath');
        return false;
      }

      final result = await OpenFile.open(filePath);
      logService.i(LogConfig.moduleUpdate, 'OpenFile 结果: ${result.type} - ${result.message}');

      logService.i(LogConfig.moduleUpdate, '========== 安装请求已发送 ==========');
      return result.type == ResultType.done;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleUpdate, '安装错误', e, stackTrace);
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
        logService.i(LogConfig.moduleUpdate, '已删除 APK: $filePath');
      }
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleUpdate, '删除 APK 失败', e, stackTrace);
    }
  }

  /// Parse JSON string safely
  Map<String, dynamic>? _parseJson(String body) {
    try {
      return json.decode(body) as Map<String, dynamic>?;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleUpdate, 'JSON 解析错误', e, stackTrace);
      return null;
    }
  }

  /// Parse JSON array safely
  List<Map<String, dynamic>>? _parseJsonList(String body) {
    try {
      final list = json.decode(body) as List<dynamic>;
      return list.map((e) => e as Map<String, dynamic>).toList();
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleUpdate, 'JSON 解析错误', e, stackTrace);
      return null;
    }
  }

  /// Fetch all releases from GitHub (including pre-release)
  /// Returns FetchReleasesResult with list of AppVersion objects
  Future<FetchReleasesResult> fetchAllReleases({
    int perPage = 30,
    int page = 1,
  }) async {
    try {
      logService.i(LogConfig.moduleUpdate, '========== 开始获取更新历史 ==========');
      logService.diag(LogConfig.moduleUpdate, 'Page', page);
      logService.diag(LogConfig.moduleUpdate, 'PerPage', perPage);

      final currentVersion = await getCurrentVersion();
      final url = getAllReleasesUrl(perPage: perPage, page: page);

      logService.i(LogConfig.moduleUpdate, '请求 $url');
      final response = await _httpClient.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': '${AppConstants.appName}/$currentVersion',
        },
      );

      logService.i(LogConfig.moduleUpdate, '响应状态 ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonList = _parseJsonList(response.body);
        if (jsonList == null) {
          return FetchReleasesResult(
            success: false,
            errorMessage: 'Failed to parse releases list',
          );
        }

        final releases = jsonList
            .map((json) => AppVersion.fromGitHubRelease(json))
            .toList();

        // Determine if there are more pages
        // If returned count equals perPage, there might be more pages
        final hasMorePages = releases.length >= perPage;
        final nextPage = hasMorePages ? page + 1 : null;

        logService.i(LogConfig.moduleUpdate, '获取到 ${releases.length} 个版本');
        logService.i(LogConfig.moduleUpdate, '========== 获取更新历史完成 ==========');

        return FetchReleasesResult(
          success: true,
          releases: releases,
          nextPage: nextPage,
        );
      } else if (response.statusCode == 403) {
        logService.w(LogConfig.moduleUpdate, 'GitHub API 请求限流');
        return FetchReleasesResult(
          success: false,
          errorMessage: 'RATE_LIMITED',
          rateLimited: true,
        );
      } else if (response.statusCode == 404) {
        return FetchReleasesResult(
          success: false,
          errorMessage: 'Repository not found',
        );
      } else {
        return FetchReleasesResult(
          success: false,
          errorMessage: 'Server returned ${response.statusCode}',
        );
      }
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleUpdate, '获取更新历史失败', e, stackTrace);
      return FetchReleasesResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Dispose resources
  void dispose() {
    _httpClient.close();
  }
}
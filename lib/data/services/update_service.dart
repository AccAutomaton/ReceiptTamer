import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

/// Service for checking and downloading app updates from GitHub Releases
class UpdateService {
  /// GitHub API base URL
  static const String _githubApiBaseUrl = 'https://api.github.com';

  /// Get the latest release API URL
  String get _latestReleaseUrl =>
      '$_githubApiBaseUrl/repos/${AppConstants.githubOwner}/${AppConstants.githubRepo}/releases/latest';

  /// HTTP client
  final http.Client _httpClient;

  /// Constructor
  UpdateService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

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
      final response = await _httpClient.get(
        Uri.parse(_latestReleaseUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': '${AppConstants.appName}/${currentVersion}',
        },
      );

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
      debugPrint('Error checking for updates: $e');
      return UpdateCheckResponse(
        result: UpdateCheckResult.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Download APK file
  /// Returns the file path when complete
  /// onProgress is called with progress between 0.0 and 1.0
  Future<String?> downloadApk(
    String url, {
    void Function(double progress)? onProgress,
    void Function()? onCancel,
  }) async {
    try {
      // Get download directory
      final tempDir = await getTemporaryDirectory();
      final fileName = 'app-update-${DateTime.now().millisecondsSinceEpoch}.apk';
      final filePath = path.join(tempDir.path, fileName);
      final file = File(filePath);

      // Send request
      final request = http.Request('GET', Uri.parse(url));
      final response = await _httpClient.send(request);

      if (response.statusCode != 200) {
        debugPrint('Download failed: ${response.statusCode}');
        return null;
      }

      final contentLength = response.contentLength;
      int downloadedBytes = 0;

      // Write to file with progress
      final sink = file.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          downloadedBytes += chunk.length;

          if (contentLength != null && contentLength > 0) {
            onProgress?.call(downloadedBytes / contentLength);
          }
        }

        await sink.flush();
        await sink.close();

        return filePath;
      } catch (e) {
        await sink.close();
        // Delete partial file on error
        if (await file.exists()) {
          await file.delete();
        }
        debugPrint('Download error: $e');
        return null;
      }
    } catch (e) {
      debugPrint('Download error: $e');
      return null;
    }
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
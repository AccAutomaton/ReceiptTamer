import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_version.dart';

/// Cache keys
class ReleaseHistoryCacheKeys {
  static const String cache = 'release_history_cache';
  static const String cacheTime = 'release_history_cache_time';
}

/// Service for caching release history data
class ReleaseHistoryCache {
  /// Save releases to cache
  static Future<void> saveCache(List<AppVersion> releases) async {
    final prefs = await SharedPreferences.getInstance();

    // Convert releases to JSON list
    final jsonList = releases.map((r) => {
      'tag_name': r.tagName,
      'name': r.name,
      'body': r.changelog,
      'published_at': r.publishedAt?.toIso8601String(),
      'prerelease': r.isPreRelease,
      'assets': [
        if (r.downloadUrl != null)
          {
            'browser_download_url': r.downloadUrl,
            'name': 'app-release.apk',
            'size': r.fileSize,
          },
      ],
    }).toList();

    await prefs.setString(ReleaseHistoryCacheKeys.cache, jsonEncode(jsonList));
    await prefs.setString(
      ReleaseHistoryCacheKeys.cacheTime,
      DateTime.now().toIso8601String(),
    );
  }

  /// Get cached releases
  static Future<List<AppVersion>?> getCache() async {
    final prefs = await SharedPreferences.getInstance();

    final cachedJson = prefs.getString(ReleaseHistoryCacheKeys.cache);
    if (cachedJson == null) return null;

    try {
      final jsonList = jsonDecode(cachedJson) as List<dynamic>;
      return jsonList
          .map((json) => AppVersion.fromGitHubRelease(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Invalid cache data, return null
      return null;
    }
  }

  /// Get cache time
  static Future<DateTime?> getCacheTime() async {
    final prefs = await SharedPreferences.getInstance();

    final cacheTimeStr = prefs.getString(ReleaseHistoryCacheKeys.cacheTime);
    if (cacheTimeStr == null) return null;

    return DateTime.tryParse(cacheTimeStr);
  }

  /// Clear cache
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ReleaseHistoryCacheKeys.cache);
    await prefs.remove(ReleaseHistoryCacheKeys.cacheTime);
  }

  /// Check if cache exists
  static Future<bool> hasCache() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(ReleaseHistoryCacheKeys.cache);
  }
}
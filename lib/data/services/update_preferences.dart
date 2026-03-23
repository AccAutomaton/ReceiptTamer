import 'package:shared_preferences/shared_preferences.dart';

/// Manages update-related preferences
class UpdatePreferences {
  static const String _keyLastCheckTime = 'update_last_check_time';
  static const String _keyIgnoredVersion = 'update_ignored_version';

  /// Check interval in hours
  static const int checkIntervalHours = 12;

  /// Get the last check time
  static Future<DateTime?> getLastCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_keyLastCheckTime);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// Set the last check time to now
  static Future<void> setLastCheckTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastCheckTime, time.millisecondsSinceEpoch);
  }

  /// Check if enough time has passed since last check (12 hours)
  static Future<bool> shouldCheckForUpdate() async {
    final lastCheck = await getLastCheckTime();
    if (lastCheck == null) return true;

    final now = DateTime.now();
    final difference = now.difference(lastCheck);
    return difference.inHours >= checkIntervalHours;
  }

  /// Get the ignored version
  static Future<String?> getIgnoredVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyIgnoredVersion);
  }

  /// Set the ignored version
  static Future<void> setIgnoredVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyIgnoredVersion, version);
  }

  /// Clear the ignored version
  static Future<void> clearIgnoredVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIgnoredVersion);
  }

  /// Check if a version is ignored
  static Future<bool> isVersionIgnored(String version) async {
    final ignored = await getIgnoredVersion();
    return ignored == version;
  }
}
/// App version information model
class AppVersion {
  /// Version number without 'v' prefix (e.g., "1.0.0")
  final String version;

  /// Git tag name (e.g., "v1.0.0")
  final String tagName;

  /// Release name/title
  final String? name;

  /// Release notes/changelog
  final String? changelog;

  /// APK download URL
  final String? downloadUrl;

  /// APK file size in bytes
  final int? fileSize;

  /// Release published date
  final DateTime? publishedAt;

  const AppVersion({
    required this.version,
    required this.tagName,
    this.name,
    this.changelog,
    this.downloadUrl,
    this.fileSize,
    this.publishedAt,
  });

  /// Parse from GitHub API response
  factory AppVersion.fromGitHubRelease(Map<String, dynamic> json) {
    final tagName = json['tag_name'] as String? ?? '';
    final version = tagName.startsWith('v') ? tagName.substring(1) : tagName;

    // Find APK asset
    String? downloadUrl;
    int? fileSize;
    final assets = json['assets'] as List<dynamic>? ?? [];
    for (final asset in assets) {
      final name = asset['name'] as String? ?? '';
      if (name.endsWith('.apk')) {
        downloadUrl = asset['browser_download_url'] as String?;
        fileSize = asset['size'] as int?;
        break;
      }
    }

    // Parse published date
    DateTime? publishedAt;
    final publishedAtStr = json['published_at'] as String?;
    if (publishedAtStr != null) {
      publishedAt = DateTime.tryParse(publishedAtStr);
    }

    return AppVersion(
      version: version,
      tagName: tagName,
      name: json['name'] as String?,
      changelog: json['body'] as String?,
      downloadUrl: downloadUrl,
      fileSize: fileSize,
      publishedAt: publishedAt,
    );
  }

  /// Compare with another version
  /// Returns:
  /// - negative if this < other
  /// - 0 if this == other
  /// - positive if this > other
  int compareTo(String otherVersion) {
    final thisParts = version.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final otherParts = otherVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // Pad with zeros to ensure same length
    while (thisParts.length < otherParts.length) {
      thisParts.add(0);
    }
    while (otherParts.length < thisParts.length) {
      otherParts.add(0);
    }

    for (int i = 0; i < thisParts.length; i++) {
      if (thisParts[i] != otherParts[i]) {
        return thisParts[i].compareTo(otherParts[i]);
      }
    }

    return 0;
  }

  /// Check if this version is newer than the given version
  bool isNewerThan(String currentVersion) {
    return compareTo(currentVersion) > 0;
  }

  /// Format file size to human readable string
  String? get formattedFileSize {
    if (fileSize == null) return null;

    final bytes = fileSize!;
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

  @override
  String toString() {
    return 'AppVersion(version: $version, tagName: $tagName, downloadUrl: $downloadUrl)';
  }
}
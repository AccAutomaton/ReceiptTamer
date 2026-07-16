import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:receipt_tamer/data/services/update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _officialLatestUrl =
    'https://api.github.com/repos/AccAutomaton/ReceiptTamer/releases/latest';
const _officialReleasesUrl =
    'https://api.github.com/repos/AccAutomaton/ReceiptTamer/releases?per_page=30&page=1';
const _officialApkUrl =
    'https://github.com/AccAutomaton/ReceiptTamer/releases/download/v0.6.0/app-release.apk';
const _mirrorPrefix = 'https://gh.dpik.top/';

Map<String, dynamic> _releaseJson() => {
  'tag_name': 'v0.6.0',
  'name': 'ReceiptTamer v0.6.0',
  'body': '更新说明',
  'published_at': '2026-07-16T00:00:00Z',
  'prerelease': false,
  'assets': [
    {
      'name': 'app-release.apk',
      'browser_download_url': _officialApkUrl,
      'size': 6,
    },
  ],
};

http.Response _jsonResponse(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class _TestUpdateService extends UpdateService {
  final String? apkFilePath;
  final String currentVersion;
  final String currentBuildNumber;

  _TestUpdateService({
    required super.httpClient,
    this.apkFilePath,
    this.currentVersion = '0.5.2',
    this.currentBuildNumber = '20260701',
  });

  @override
  Future<String> getCurrentVersion() async => currentVersion;

  @override
  Future<String> getCurrentBuildNumber() async => currentBuildNumber;

  @override
  Future<String> getApkFilePath() async => apkFilePath!;
}

void main() {
  test('检查更新优先请求 github.akams.cn 镜像节点', () async {
    final requestedUrls = <String>[];
    final client = MockClient((request) async {
      requestedUrls.add(request.url.toString());
      return _jsonResponse(_releaseJson());
    });
    final service = _TestUpdateService(httpClient: client);
    addTearDown(service.dispose);

    final result = await service.checkForUpdates();

    expect(
      result.result,
      UpdateCheckResult.available,
      reason: result.errorMessage,
    );
    expect(result.latestVersion?.downloadUrl, _officialApkUrl);
    expect(requestedUrls, ['$_mirrorPrefix$_officialLatestUrl']);
  });

  test('镜像检查更新失败时回退 GitHub 官方 API', () async {
    final requestedUrls = <String>[];
    final client = MockClient((request) async {
      requestedUrls.add(request.url.toString());
      if (request.url.host == 'gh.dpik.top') {
        return http.Response('mirror unavailable', 503);
      }
      return _jsonResponse(_releaseJson());
    });
    final service = _TestUpdateService(httpClient: client);
    addTearDown(service.dispose);

    final result = await service.checkForUpdates();

    expect(
      result.result,
      UpdateCheckResult.available,
      reason: result.errorMessage,
    );
    expect(requestedUrls, [
      '$_mirrorPrefix$_officialLatestUrl',
      '$_mirrorPrefix$_officialLatestUrl',
      '$_mirrorPrefix$_officialLatestUrl',
      _officialLatestUrl,
    ]);
  });

  test('更新历史同样使用镜像优先和官方回退', () async {
    final requestedUrls = <String>[];
    final client = MockClient((request) async {
      requestedUrls.add(request.url.toString());
      if (request.url.host == 'gh.dpik.top') {
        return http.Response('mirror unavailable', 502);
      }
      return _jsonResponse([_releaseJson()]);
    });
    final service = _TestUpdateService(httpClient: client);
    addTearDown(service.dispose);

    final result = await service.fetchAllReleases();

    expect(result.success, isTrue, reason: result.errorMessage);
    expect(result.releases.single.version, '0.6.0');
    expect(requestedUrls, [
      '$_mirrorPrefix$_officialReleasesUrl',
      '$_mirrorPrefix$_officialReleasesUrl',
      '$_mirrorPrefix$_officialReleasesUrl',
      _officialReleasesUrl,
    ]);
  });

  test('镜像 APK 下载失败后从官方源续传已有部分', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'receipt_tamer_update_test_',
    );
    addTearDown(() => tempDir.delete(recursive: true));
    final apkFile = File('${tempDir.path}${Platform.pathSeparator}update.apk');
    await apkFile.writeAsBytes([1, 2, 3]);

    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.host == 'gh.dpik.top') {
        return http.Response('mirror unavailable', 503);
      }
      return http.Response.bytes(
        [4, 5, 6],
        206,
        headers: {'content-length': '3', 'content-range': 'bytes 3-5/6'},
      );
    });
    final service = _TestUpdateService(
      httpClient: client,
      apkFilePath: apkFile.path,
    );
    addTearDown(service.dispose);

    final result = await service.downloadApkWithResume(_officialApkUrl);

    expect(result.success, isTrue);
    expect(result.wasResumed, isTrue);
    expect(await apkFile.readAsBytes(), [1, 2, 3, 4, 5, 6]);
    expect(requests.map((request) => request.url.toString()), [
      '$_mirrorPrefix$_officialApkUrl',
      '$_mirrorPrefix$_officialApkUrl',
      '$_mirrorPrefix$_officialApkUrl',
      _officialApkUrl,
    ]);
    expect(requests.map((request) => request.headers['Range']), [
      'bytes=3-',
      'bytes=3-',
      'bytes=3-',
      'bytes=3-',
    ]);
  });

  test('下载失败后用户继续时重新从镜像源开始尝试', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'receipt_tamer_update_retry_test_',
    );
    addTearDown(() => tempDir.delete(recursive: true));
    final apkFile = File('${tempDir.path}${Platform.pathSeparator}update.apk');

    final requestedUrls = <String>[];
    var requestCount = 0;
    final client = MockClient((request) async {
      requestedUrls.add(request.url.toString());
      requestCount++;
      if (requestCount <= 4) {
        return http.Response('temporarily unavailable', 503);
      }
      return http.Response.bytes([1, 2, 3], 200);
    });
    final service = _TestUpdateService(
      httpClient: client,
      apkFilePath: apkFile.path,
    );
    addTearDown(service.dispose);

    final firstResult = await service.downloadApkWithResume(_officialApkUrl);
    final continuedResult = await service.downloadApkWithResume(
      _officialApkUrl,
    );

    expect(firstResult.success, isFalse);
    expect(continuedResult.success, isTrue);
    expect(await apkFile.readAsBytes(), [1, 2, 3]);
    expect(requestedUrls, [
      '$_mirrorPrefix$_officialApkUrl',
      '$_mirrorPrefix$_officialApkUrl',
      '$_mirrorPrefix$_officialApkUrl',
      _officialApkUrl,
      '$_mirrorPrefix$_officialApkUrl',
    ]);
  });

  test('退出安装器未安装时保留 APK，确认升级后才清理', () async {
    SharedPreferences.setMockInitialValues({});
    final tempDir = await Directory.systemTemp.createTemp(
      'receipt_tamer_apk_cleanup_test_',
    );
    addTearDown(() => tempDir.delete(recursive: true));
    final apkFile = File('${tempDir.path}${Platform.pathSeparator}update.apk');
    await apkFile.writeAsBytes([1, 2, 3]);

    final firstService = _TestUpdateService(
      httpClient: MockClient((_) async => http.Response('', 200)),
      apkFilePath: apkFile.path,
    );
    final cancelledInstallService = _TestUpdateService(
      httpClient: MockClient((_) async => http.Response('', 200)),
      apkFilePath: apkFile.path,
    );
    final upgradedService = _TestUpdateService(
      httpClient: MockClient((_) async => http.Response('', 200)),
      apkFilePath: apkFile.path,
      currentVersion: '0.6.0',
      currentBuildNumber: '20260717',
    );
    addTearDown(firstService.dispose);
    addTearDown(cancelledInstallService.dispose);
    addTearDown(upgradedService.dispose);

    await firstService.markApkForCleanup(apkFile.path, targetVersion: '0.6.0');
    await cancelledInstallService.cleanupPendingApk();

    expect(await apkFile.readAsBytes(), [1, 2, 3]);

    await upgradedService.cleanupPendingApk();

    expect(await apkFile.exists(), isFalse);

    // The cleanup marker is removed with the APK, so a later partial download
    // at the same path is preserved until another installation starts.
    await apkFile.writeAsBytes([4, 5, 6]);
    await upgradedService.cleanupPendingApk();
    expect(await apkFile.readAsBytes(), [4, 5, 6]);
  });

  test('同版本号退出安装器时保留 APK，仅在构建号变化后清理', () async {
    SharedPreferences.setMockInitialValues({});
    final tempDir = await Directory.systemTemp.createTemp(
      'receipt_tamer_same_version_cleanup_test_',
    );
    addTearDown(() => tempDir.delete(recursive: true));
    final apkFile = File('${tempDir.path}${Platform.pathSeparator}update.apk');
    await apkFile.writeAsBytes([1, 2, 3]);

    final sourceService = _TestUpdateService(
      httpClient: MockClient((_) async => http.Response('', 200)),
      apkFilePath: apkFile.path,
    );
    final cancelledInstallService = _TestUpdateService(
      httpClient: MockClient((_) async => http.Response('', 200)),
      apkFilePath: apkFile.path,
    );
    final upgradedBuildService = _TestUpdateService(
      httpClient: MockClient((_) async => http.Response('', 200)),
      apkFilePath: apkFile.path,
      currentBuildNumber: '20260717',
    );
    addTearDown(sourceService.dispose);
    addTearDown(cancelledInstallService.dispose);
    addTearDown(upgradedBuildService.dispose);

    await sourceService.markApkForCleanup(apkFile.path, targetVersion: '0.5.2');
    await cancelledInstallService.cleanupPendingApk();
    expect(await apkFile.exists(), isTrue);

    await upgradedBuildService.cleanupPendingApk();
    expect(await apkFile.exists(), isFalse);
  });

  test('退出安装器后再次尝试可直接复用完整 APK', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'receipt_tamer_apk_reuse_test_',
    );
    addTearDown(() => tempDir.delete(recursive: true));
    final apkFile = File('${tempDir.path}${Platform.pathSeparator}update.apk');
    await apkFile.writeAsBytes([1, 2, 3]);

    var networkRequests = 0;
    final service = _TestUpdateService(
      httpClient: MockClient((_) async {
        networkRequests++;
        return http.Response('unexpected request', 500);
      }),
      apkFilePath: apkFile.path,
    );
    addTearDown(service.dispose);

    final result = await service.downloadApkWithResume(
      _officialApkUrl,
      expectedTotalBytes: 3,
    );

    expect(result.success, isTrue);
    expect(result.filePath, apkFile.path);
    expect(networkRequests, 0);
  });
}

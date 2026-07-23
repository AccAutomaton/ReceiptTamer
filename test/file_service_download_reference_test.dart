import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/data/services/file_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.acautomaton.receipt.tamer/storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('copy result requires and preserves a shareable URI', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'copyToDownloadDirectory');
      return {
        'success': true,
        'path': '/Download/ReceiptTamer/materials/report.pdf',
        'uri': 'content://downloads/42',
        'fileName': 'report.pdf',
      };
    });

    final result = await FileService().copyToDownloadDirectoryReference(
      '/cache/report.pdf',
      subDir: 'materials/20260723',
    );

    expect(result?.path, contains('report.pdf'));
    expect(result?.uri, 'content://downloads/42');
    expect(result?.name, 'report.pdf');
  });

  test('copy result rejects a success response without URI', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      return {
        'success': true,
        'path': '/Download/ReceiptTamer/materials/report.pdf',
        'fileName': 'report.pdf',
      };
    });

    final result = await FileService().copyToDownloadDirectoryReference(
      '/cache/report.pdf',
    );

    expect(result, isNull);
  });

  test('shareFiles sends every URI in one platform call', () async {
    late MethodCall recorded;
    messenger.setMockMethodCallHandler(channel, (call) async {
      recorded = call;
      return true;
    });

    final success = await FileService().shareFiles(const [
      DownloadedFileReference(
        path: '/downloads/a.pdf',
        uri: 'content://downloads/a',
        name: 'a.pdf',
      ),
      DownloadedFileReference(
        path: '/downloads/b.xlsx',
        uri: 'content://downloads/b',
        name: 'b.xlsx',
      ),
    ]);

    expect(success, isTrue);
    expect(recorded.method, 'shareFiles');
    expect(recorded.arguments['fileUris'], [
      'content://downloads/a',
      'content://downloads/b',
    ]);
  });

  test('openDownloadedFile uses the durable content URI', () async {
    late MethodCall recorded;
    messenger.setMockMethodCallHandler(channel, (call) async {
      recorded = call;
      return true;
    });

    final success = await FileService().openDownloadedFile(
      const DownloadedFileReference(
        path: '/downloads/report.pdf',
        uri: 'content://downloads/report',
        name: 'report.pdf',
      ),
    );

    expect(success, isTrue);
    expect(recorded.method, 'openDownloadedFile');
    expect(recorded.arguments['fileUri'], 'content://downloads/report');
    expect(recorded.arguments['mimeType'], 'application/pdf');
  });
}

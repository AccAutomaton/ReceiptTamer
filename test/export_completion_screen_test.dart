import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/data/services/file_service.dart';
import 'package:receipt_tamer/presentation/screens/export/export_completion_screen.dart';

void main() {
  testWidgets('shows three outcomes and replaces a failed retry result', (
    tester,
  ) async {
    _configureTestViewport(tester);

    final sessionDirectory = Directory(
      '${Directory.systemTemp.path}/receipt_export_completion_widget_test',
    );
    final results = <ExportMaterialResult>[
      _success(ExportMaterialType.mealProof),
      ExportMaterialResult(
        type: ExportMaterialType.invoice,
        status: ExportMaterialStatus.failure,
        message: '发票附件不可用',
        retry: () async => _success(ExportMaterialType.invoice),
      ),
      const ExportMaterialResult(
        type: ExportMaterialType.mealDetails,
        status: ExportMaterialStatus.notSelected,
        message: '本次没有选择生成',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: ExportCompletionScreen(
          results: results,
          subDir: 'materials/20260723',
          sessionDirectory: sessionDirectory,
        ),
      ),
    );

    expect(find.text('用餐证明'), findsOneWidget);
    expect(find.text('发票'), findsOneWidget);
    expect(find.text('用餐明细'), findsOneWidget);
    expect(find.text('已导出'), findsOneWidget);
    expect(find.text('导出失败'), findsOneWidget);
    expect(find.text('未选择'), findsOneWidget);
    expect(find.text('发票附件不可用'), findsOneWidget);
    expect(find.text('分享全部成功项'), findsOneWidget);
    expect(find.text('打包 ZIP 后分享'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(find.text('导出失败'), findsNothing);
    expect(find.text('已导出'), findsNWidgets(2));
    expect(find.text('发票附件不可用'), findsNothing);
  });

  testWidgets('open preview share-all and on-demand ZIP use distinct actions', (
    tester,
  ) async {
    _configureTestViewport(tester);

    final artifacts = await tester.runAsync(() async {
      final directory = await Directory.systemTemp.createTemp(
        'receipt_export_completion_actions_',
      );
      final file = File('${directory.path}/meal-proof.pdf');
      await file.writeAsBytes([1, 2, 3]);
      return (directory, file);
    });
    final sessionDirectory = artifacts!.$1;
    final preview = artifacts.$2;
    final service = _RecordingFileService();
    final zipCompleter = Completer<DownloadedFileReference?>();
    var zipBuildCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ExportCompletionScreen(
          results: [
            _success(ExportMaterialType.mealProof, previewPath: preview.path),
            const ExportMaterialResult(
              type: ExportMaterialType.invoice,
              status: ExportMaterialStatus.notSelected,
            ),
            const ExportMaterialResult(
              type: ExportMaterialType.mealDetails,
              status: ExportMaterialStatus.notSelected,
            ),
          ],
          subDir: 'materials/20260723',
          sessionDirectory: sessionDirectory,
          fileService: service,
          zipBuilder: (_) {
            zipBuildCount++;
            return zipCompleter.future;
          },
        ),
      ),
    );

    expect(zipBuildCount, 0);

    await tester.tap(find.text('打开'));
    await tester.pump();
    expect(service.openDownloadedCount, 1);
    expect(service.openPreviewPaths, isEmpty);

    await tester.tap(find.text('预览'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    expect(service.openDownloadedCount, 1);
    expect(service.openPreviewPaths, [preview.path]);

    await tester.tap(find.text('分享'));
    await tester.pump();
    expect(service.sharedNames, ['mealProof.pdf']);

    await tester.ensureVisible(find.text('分享全部成功项'));
    await tester.tap(find.text('分享全部成功项'));
    await tester.pump();
    expect(service.shareAllCount, 1);

    await tester.ensureVisible(find.text('打包 ZIP 后分享'));
    await tester.tap(find.text('打包 ZIP 后分享'));
    await tester.pump();
    expect(zipBuildCount, 1);
    final popScopeFinder = find.byKey(
      const ValueKey('export-completion-pop-scope'),
    );
    expect((tester.widget(popScopeFinder) as dynamic).canPop, isFalse);

    zipCompleter.complete(
      const DownloadedFileReference(
        path: '/downloads/materials.zip',
        uri: 'content://downloads/materials.zip',
        name: 'materials.zip',
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(service.sharedNames, ['mealProof.pdf', 'materials.zip']);
    expect((tester.widget(popScopeFinder) as dynamic).canPop, isTrue);
  });
}

void _configureTestViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

ExportMaterialResult _success(ExportMaterialType type, {String? previewPath}) {
  final extension = type == ExportMaterialType.mealDetails ? 'xlsx' : 'pdf';
  final name = '${type.name}.$extension';
  return ExportMaterialResult(
    type: type,
    status: ExportMaterialStatus.success,
    file: DownloadedFileReference(
      path: '/downloads/$name',
      uri: 'content://downloads/$name',
      name: name,
    ),
    previewPath: previewPath ?? '/cache/$name',
    message: '已保存为 $name',
  );
}

class _RecordingFileService extends FileService {
  int openDownloadedCount = 0;
  int shareAllCount = 0;
  final List<String> openPreviewPaths = [];
  final List<String> sharedNames = [];

  @override
  Future<bool> openDownloadedFile(DownloadedFileReference file) async {
    openDownloadedCount++;
    return true;
  }

  @override
  Future<bool> openFile(String filePath) async {
    openPreviewPaths.add(filePath);
    return true;
  }

  @override
  Future<bool> shareFile(
    String fileUri,
    String fileName,
    String mimeType,
  ) async {
    sharedNames.add(fileName);
    return true;
  }

  @override
  Future<bool> shareFiles(List<DownloadedFileReference> files) async {
    shareAllCount++;
    return true;
  }
}

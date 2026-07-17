import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/core/constants/app_constants.dart';
import 'package:receipt_tamer/data/services/cleanup_service.dart';
import 'package:receipt_tamer/data/services/file_service.dart';
import 'package:receipt_tamer/data/services/image_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'database failure rolls back every row and never removes attachments',
    () async {
      final harness = await _CleanupHarness.create();
      addTearDown(harness.close);
      final orderOne = await harness.addOrder(1, bytes: [1]);
      final orderTwo = await harness.addOrder(2, bytes: [2]);
      final invoice = await harness.addInvoice(10, bytes: [3]);
      await harness.addRelation(10, 1);
      await harness.addRelation(10, 2);
      await harness.database.execute('''
      CREATE TRIGGER fail_invoice_delete
      BEFORE DELETE ON ${AppConstants.invoicesTable}
      BEGIN
        SELECT RAISE(ABORT, 'injected invoice delete failure');
      END
    ''');

      final images = _RecordingImageService();
      final files = _RecordingFileService();
      final service = CleanupService(
        database: harness.database,
        imageService: images,
        fileService: files,
      );

      await expectLater(
        service.deleteOrders(orderIds: {1}, deleteInvoices: true),
        throwsA(isA<DatabaseException>()),
      );

      expect(await harness.ids(AppConstants.ordersTable), {1, 2});
      expect(await harness.ids(AppConstants.invoicesTable), {10});
      expect(await harness.relationCount(), 2);
      expect(await File(orderOne).exists(), isTrue);
      expect(await File(orderTwo).exists(), isTrue);
      expect(await File(invoice).exists(), isTrue);
      expect(images.deletedPaths, isEmpty);
      expect(files.deletedPaths, isEmpty);
    },
  );

  test(
    'attachment failure is disclosed after committed database deletion',
    () async {
      final harness = await _CleanupHarness.create();
      addTearDown(harness.close);
      final invoice = await harness.addInvoice(10, bytes: [1, 2, 3]);
      final files = _RecordingFileService(failingPaths: {invoice});
      final service = CleanupService(
        database: harness.database,
        imageService: _RecordingImageService(),
        fileService: files,
      );

      final result = await service.deleteInvoices(invoiceIds: {10});

      expect(result.invoicesDeleted, 1);
      expect(result.ordersDeleted, 0);
      expect(result.filesDeleted, 0);
      expect(result.filesFailedToDelete, 1);
      expect(result.undeletedFilePaths, [invoice]);
      expect(await harness.ids(AppConstants.invoicesTable), isEmpty);
      expect(await File(invoice).exists(), isTrue);
      expect(files.deletedPaths, [invoice]);
    },
  );

  test(
    'successful cascade commits one hop then removes collected files',
    () async {
      final harness = await _CleanupHarness.create();
      addTearDown(harness.close);
      final orderOne = await harness.addOrder(1, bytes: [1]);
      final orderTwo = await harness.addOrder(2, bytes: [2, 2]);
      final retainedOrder = await harness.addOrder(3, bytes: [3, 3, 3]);
      final invoiceOne = await harness.addInvoice(10, bytes: [4, 4, 4, 4]);
      final invoiceTwo = await harness.addInvoice(20, bytes: [5, 5, 5, 5, 5]);
      await harness.addRelation(10, 1);
      await harness.addRelation(10, 2);
      await harness.addRelation(20, 2);
      await harness.addRelation(20, 3);

      final service = CleanupService(
        database: harness.database,
        imageService: _RecordingImageService(),
        fileService: _RecordingFileService(),
      );

      final result = await service.deleteOrders(
        orderIds: {1},
        deleteInvoices: true,
      );

      expect(result.cascadeOrderIds, {2});
      expect(result.cascadeInvoiceIds, {10, 20});
      expect(result.ordersDeleted, 2);
      expect(result.invoicesDeleted, 2);
      expect(result.filesDeleted, 4);
      expect(result.spaceFreedBytes, 1 + 2 + 4 + 5);
      expect(result.undeletedFilePaths, isEmpty);
      expect(await harness.ids(AppConstants.ordersTable), {3});
      expect(await harness.ids(AppConstants.invoicesTable), isEmpty);
      expect(await harness.relationCount(), 0);
      expect(await File(orderOne).exists(), isFalse);
      expect(await File(orderTwo).exists(), isFalse);
      expect(await File(invoiceOne).exists(), isFalse);
      expect(await File(invoiceTwo).exists(), isFalse);
      expect(await File(retainedOrder).exists(), isTrue);
    },
  );

  test('attachment referenced by a surviving row is retained', () async {
    final harness = await _CleanupHarness.create();
    addTearDown(harness.close);
    final sharedPath = await harness.addOrder(1, bytes: [1, 2]);
    await harness.database.insert(AppConstants.ordersTable, {
      AppConstants.colId: 2,
      AppConstants.colImagePath: sharedPath,
    });
    final images = _RecordingImageService();
    final service = CleanupService(
      database: harness.database,
      imageService: images,
      fileService: _RecordingFileService(),
    );

    final result = await service.deleteOrders(orderIds: {1});

    expect(result.ordersDeleted, 1);
    expect(result.filesDeleted, 0);
    expect(result.filesFailedToDelete, 0);
    expect(images.deletedPaths, isEmpty);
    expect(await harness.ids(AppConstants.ordersTable), {2});
    expect(await File(sharedPath).exists(), isTrue);
  });
}

class _CleanupHarness {
  _CleanupHarness({required this.database, required this.directory});

  final Database database;
  final Directory directory;

  static Future<_CleanupHarness> create() async {
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
    );
    await database.execute('''
      CREATE TABLE ${AppConstants.ordersTable} (
        ${AppConstants.colId} INTEGER PRIMARY KEY,
        ${AppConstants.colImagePath} TEXT NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE ${AppConstants.invoicesTable} (
        ${AppConstants.colId} INTEGER PRIMARY KEY,
        ${AppConstants.colImagePath} TEXT NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE ${AppConstants.invoiceOrderRelationsTable} (
        ${AppConstants.colInvoiceId} INTEGER NOT NULL,
        ${AppConstants.colOrderId} INTEGER NOT NULL,
        PRIMARY KEY (
          ${AppConstants.colInvoiceId},
          ${AppConstants.colOrderId}
        )
      )
    ''');
    return _CleanupHarness(
      database: database,
      directory: Directory.systemTemp.createTempSync('cleanup_atomicity_'),
    );
  }

  Future<String> addOrder(int id, {required List<int> bytes}) async {
    final path = '${directory.path}${Platform.pathSeparator}order_$id.jpg';
    await File(path).writeAsBytes(bytes);
    await database.insert(AppConstants.ordersTable, {
      AppConstants.colId: id,
      AppConstants.colImagePath: path,
    });
    return path;
  }

  Future<String> addInvoice(int id, {required List<int> bytes}) async {
    final path = '${directory.path}${Platform.pathSeparator}invoice_$id.pdf';
    await File(path).writeAsBytes(bytes);
    await database.insert(AppConstants.invoicesTable, {
      AppConstants.colId: id,
      AppConstants.colImagePath: path,
    });
    return path;
  }

  Future<void> addRelation(int invoiceId, int orderId) async {
    await database.insert(AppConstants.invoiceOrderRelationsTable, {
      AppConstants.colInvoiceId: invoiceId,
      AppConstants.colOrderId: orderId,
    });
  }

  Future<Set<int>> ids(String table) async {
    final rows = await database.query(table, columns: [AppConstants.colId]);
    return rows.map((row) => row[AppConstants.colId] as int).toSet();
  }

  Future<int> relationCount() async {
    final rows = await database.rawQuery(
      'SELECT COUNT(*) AS count '
      'FROM ${AppConstants.invoiceOrderRelationsTable}',
    );
    return rows.single['count'] as int;
  }

  Future<void> close() async {
    await database.close();
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  }
}

class _RecordingImageService extends ImageService {
  final List<String> deletedPaths = [];

  @override
  Future<int> getImageSize(String imagePath) => File(imagePath).length();

  @override
  Future<bool> deleteImage(String imagePath) async {
    deletedPaths.add(imagePath);
    final file = File(imagePath);
    if (!await file.exists()) return false;
    await file.delete();
    return true;
  }
}

class _RecordingFileService extends FileService {
  _RecordingFileService({this.failingPaths = const {}});

  final Set<String> failingPaths;
  final List<String> deletedPaths = [];

  @override
  Future<int> getFileSize(String filePath) => File(filePath).length();

  @override
  Future<bool> deleteFile(String filePath) async {
    deletedPaths.add(filePath);
    if (failingPaths.contains(filePath)) return false;
    final file = File(filePath);
    if (!await file.exists()) return false;
    await file.delete();
    return true;
  }
}

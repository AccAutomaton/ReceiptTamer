import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:receipt_tamer/core/constants/app_constants.dart';
import 'package:receipt_tamer/data/models/backup_metadata.dart';
import 'package:receipt_tamer/data/services/backup_service.dart';
import 'package:receipt_tamer/presentation/widgets/settings/backup_dialog.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('BackupService', () {
    late Directory rootDirectory;
    late Directory appDirectory;
    late Directory tempDirectory;
    late Directory imagesDirectory;
    late Directory pdfsDirectory;
    late String databasePath;
    late String backupPath;
    late _LiveDatabaseHarness liveDatabase;
    late BackupService service;

    setUp(() async {
      rootDirectory = await Directory.systemTemp.createTemp(
        'receipt_tamer_backup_service_test_',
      );
      appDirectory = Directory(p.join(rootDirectory.path, 'documents'))
        ..createSync(recursive: true);
      tempDirectory = Directory(p.join(rootDirectory.path, 'cache'))
        ..createSync(recursive: true);
      imagesDirectory = Directory(
        p.join(appDirectory.path, AppConstants.imagesFolder),
      )..createSync(recursive: true);
      pdfsDirectory = Directory(
        p.join(appDirectory.path, AppConstants.pdfsFolder),
      )..createSync(recursive: true);
      final databaseDirectory = Directory(p.join(rootDirectory.path, 'db'))
        ..createSync(recursive: true);
      databasePath = p.join(databaseDirectory.path, AppConstants.databaseName);
      backupPath = p.join(rootDirectory.path, 'baseline.zip');

      liveDatabase = _LiveDatabaseHarness(databasePath);
      final database = await liveDatabase.open();
      await _createProductionSchema(database);
      await _seedBaseline(
        database,
        imagesDirectory: imagesDirectory,
        pdfsDirectory: pdfsDirectory,
      );

      service = BackupService(
        appDocumentsDirectoryProvider: () async => appDirectory,
        temporaryDirectoryProvider: () async => tempDirectory,
        databasePathProvider: () async => databasePath,
        openCurrentDatabase: liveDatabase.open,
        closeCurrentDatabase: liveDatabase.close,
        appVersionProvider: () async => '0.5.2',
      );
      final backup = await service.createBackup(backupPath);
      expect(backup.success, isTrue, reason: backup.errorMessage);
    });

    tearDown(() async {
      await liveDatabase.close();
      if (await rootDirectory.exists()) {
        await rootDirectory.delete(recursive: true);
      }
    });

    test(
      'rejects missing, corrupt, incomplete, and count-mismatched databases',
      () async {
        final valid = await service.validateBackup(backupPath);
        expect(valid.isValid, isTrue, reason: valid.errorMessage);

        final manifestOnlyPath = p.join(
          rootDirectory.path,
          'manifest_only.zip',
        );
        await _writeArchiveVariant(
          backupPath,
          manifestOnlyPath,
          keepEntry: (name) => name == 'manifest.json',
        );
        final manifestOnly = await service.validateBackup(manifestOnlyPath);
        expect(manifestOnly.isValid, isFalse);
        expect(manifestOnly.errorMessage, contains('缺少 database/'));

        final corruptPath = p.join(rootDirectory.path, 'corrupt_database.zip');
        await _writeArchiveVariant(
          backupPath,
          corruptPath,
          replacementDatabase: utf8.encode('not a sqlite database'),
        );
        final corrupt = await service.validateBackup(corruptPath);
        expect(corrupt.isValid, isFalse);
        expect(corrupt.errorMessage, contains('不是有效的 SQLite'));

        final incompleteDatabasePath = p.join(
          rootDirectory.path,
          'incomplete.db',
        );
        final incompleteDatabase = await databaseFactoryFfi.openDatabase(
          incompleteDatabasePath,
          options: OpenDatabaseOptions(singleInstance: false),
        );
        await incompleteDatabase.execute('''
          CREATE TABLE ${AppConstants.ordersTable} (
            ${AppConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
            ${AppConstants.colImagePath} TEXT NOT NULL,
            ${AppConstants.colShopName} TEXT,
            ${AppConstants.colAmount} REAL,
            ${AppConstants.colOrderDate} TEXT,
            ${AppConstants.colMealTime} TEXT,
            ${AppConstants.colOrderNumber} TEXT,
            ${AppConstants.colCreatedAt} TEXT NOT NULL,
            ${AppConstants.colUpdatedAt} TEXT NOT NULL
          )
        ''');
        await incompleteDatabase.execute(
          'PRAGMA user_version = ${AppConstants.databaseVersion}',
        );
        await incompleteDatabase.close();
        final incompletePath = p.join(rootDirectory.path, 'incomplete.zip');
        await _writeStandaloneBackup(
          incompletePath,
          databaseBytes: await File(incompleteDatabasePath).readAsBytes(),
          metadata: BackupMetadata(
            appVersion: '0.5.2',
            databaseVersion: AppConstants.databaseVersion,
            backupTime: DateTime.utc(2026, 7, 17).toIso8601String(),
            orderCount: 0,
            invoiceCount: 0,
          ),
        );
        final incomplete = await service.validateBackup(incompletePath);
        expect(incomplete.isValid, isFalse);
        expect(incomplete.errorMessage, contains('缺少必需表'));

        final mismatchPath = p.join(rootDirectory.path, 'count_mismatch.zip');
        await _writeArchiveVariant(
          backupPath,
          mismatchPath,
          manifestTransform: (manifest) {
            manifest['order_count'] = (manifest['order_count'] as int) + 1;
            return manifest;
          },
        );
        final mismatch = await service.validateBackup(mismatchPath);
        expect(mismatch.isValid, isFalse);
        expect(mismatch.errorMessage, contains('订单数量与 manifest.json 不符'));

        final missingAttachmentPath = p.join(
          rootDirectory.path,
          'missing_attachment.zip',
        );
        await _writeArchiveVariant(
          backupPath,
          missingAttachmentPath,
          entryNameTransform: (name) =>
              name == 'images/receipt.png' ? 'images/unreferenced.png' : name,
        );
        final missingAttachment = await service.validateBackup(
          missingAttachmentPath,
        );
        expect(missingAttachment.isValid, isFalse);
        expect(missingAttachment.errorMessage, contains('引用的附件缺失'));

        final emptyAttachmentPath = p.join(
          rootDirectory.path,
          'empty_attachment.zip',
        );
        await _writeArchiveVariant(
          backupPath,
          emptyAttachmentPath,
          entryReplacements: {'pdfs/invoice.pdf': <int>[]},
        );
        final emptyAttachment = await service.validateBackup(
          emptyAttachmentPath,
        );
        expect(emptyAttachment.isValid, isFalse);
        expect(emptyAttachment.errorMessage, contains('引用的附件为空'));

        final orderPdfDatabasePath = p.join(rootDirectory.path, 'order_pdf.db');
        final orderPdfDatabase = await databaseFactoryFfi.openDatabase(
          orderPdfDatabasePath,
          options: OpenDatabaseOptions(singleInstance: false),
        );
        await _createProductionSchema(orderPdfDatabase);
        await orderPdfDatabase.insert(AppConstants.ordersTable, {
          AppConstants.colImagePath: p.join(rootDirectory.path, 'order.pdf'),
          AppConstants.colShopName: 'Invalid PDF order',
          AppConstants.colCreatedAt: '2026-07-17T08:00:00.000',
          AppConstants.colUpdatedAt: '2026-07-17T08:00:00.000',
        });
        await orderPdfDatabase.close();
        final orderPdfBackupPath = p.join(rootDirectory.path, 'order_pdf.zip');
        await _writeStandaloneBackup(
          orderPdfBackupPath,
          databaseBytes: await File(orderPdfDatabasePath).readAsBytes(),
          metadata: BackupMetadata(
            appVersion: '0.5.2',
            databaseVersion: AppConstants.databaseVersion,
            backupTime: DateTime.utc(2026, 7, 17).toIso8601String(),
            orderCount: 1,
            invoiceCount: 0,
            pdfCount: 1,
          ),
          pdfs: {
            'order.pdf': [1, 2, 3],
          },
        );
        final orderPdf = await service.validateBackup(orderPdfBackupPath);
        expect(orderPdf.isValid, isFalse);
        expect(orderPdf.errorMessage, contains('images/order.pdf'));
      },
    );

    test(
      'create backup fails and removes output for a missing media reference',
      () async {
        final database = await liveDatabase.open();
        await database.update(AppConstants.ordersTable, {
          AppConstants.colImagePath: p.join(
            imagesDirectory.path,
            'missing.png',
          ),
        });
        final invalidOutputPath = p.join(
          rootDirectory.path,
          'invalid_created_backup.zip',
        );

        final result = await service.createBackup(invalidOutputPath);

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('未通过完整性校验'));
        expect(await File(invalidOutputPath).exists(), isFalse);
      },
    );

    test('create backup rejects live database and media paths', () async {
      final originalImage = File(p.join(imagesDirectory.path, 'receipt.png'));

      final databaseResult = await service.createBackup(databasePath);
      final imageResult = await service.createBackup(originalImage.path);
      final nestedPdfOutput = p.join(pdfsDirectory.path, 'unsafe.zip');
      final pdfResult = await service.createBackup(nestedPdfOutput);

      expect(databaseResult.success, isFalse);
      expect(databaseResult.errorMessage, contains('不能覆盖当前数据库'));
      expect(imageResult.success, isFalse);
      expect(imageResult.errorMessage, contains('图片数据目录'));
      expect(pdfResult.success, isFalse);
      expect(pdfResult.errorMessage, contains('PDF 数据目录'));
      expect(await originalImage.readAsBytes(), [1, 2, 3, 4]);
      expect(await File(nestedPdfOutput).exists(), isFalse);
      final database = await liveDatabase.open();
      expect(await _count(database, AppConstants.ordersTable), 1);
    });

    test(
      'create backup is not successful when the live database cannot reopen',
      () async {
        var failNextOpen = false;
        final reopenFailureService = BackupService(
          appDocumentsDirectoryProvider: () async => appDirectory,
          temporaryDirectoryProvider: () async => tempDirectory,
          databasePathProvider: () async => databasePath,
          openCurrentDatabase: () async {
            if (failNextOpen) {
              failNextOpen = false;
              throw StateError('simulated reopen failure');
            }
            return liveDatabase.open();
          },
          closeCurrentDatabase: () async {
            await liveDatabase.close();
            failNextOpen = true;
          },
          appVersionProvider: () async => '0.5.2',
        );
        final outputPath = p.join(rootDirectory.path, 'reopen_failure.zip');

        final result = await reopenFailureService.createBackup(outputPath);

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('simulated reopen failure'));
        expect(await File(outputPath).exists(), isTrue);
        final database = await liveDatabase.open();
        expect(await _count(database, AppConstants.ordersTable), 1);
      },
    );

    test(
      'invalid overwrite is non-destructive and valid overwrite restores paths',
      () async {
        var database = await liveDatabase.open();
        await database.insert(AppConstants.ordersTable, {
          AppConstants.colImagePath: '',
          AppConstants.colShopName: 'Later order',
          AppConstants.colAmount: 9.0,
          AppConstants.colOrderDate: '2026-07-02',
          AppConstants.colMealTime: 'lunch',
          AppConstants.colOrderNumber: 'LATER-1',
          AppConstants.colCreatedAt: '2026-07-02T10:00:00.000',
          AppConstants.colUpdatedAt: '2026-07-02T10:00:00.000',
        });
        await File(
          p.join(imagesDirectory.path, 'extra.png'),
        ).writeAsBytes([99]);
        final originalReceiptPath = p.join(imagesDirectory.path, 'receipt.png');
        await File(originalReceiptPath).writeAsBytes([8, 8, 8]);

        final manifestOnlyPath = p.join(
          rootDirectory.path,
          'manifest_only.zip',
        );
        await _writeArchiveVariant(
          backupPath,
          manifestOnlyPath,
          keepEntry: (name) => name == 'manifest.json',
        );
        final rejected = await service.restoreBackup(
          manifestOnlyPath,
          RestoreMode.overwrite,
        );
        expect(rejected.success, isFalse);
        database = await liveDatabase.open();
        expect(await _count(database, AppConstants.ordersTable), 2);
        expect(
          await File(p.join(imagesDirectory.path, 'extra.png')).exists(),
          isTrue,
        );

        final restored = await service.restoreBackup(
          backupPath,
          RestoreMode.overwrite,
        );
        expect(restored.success, isTrue, reason: restored.errorMessage);

        database = await liveDatabase.open();
        expect(await _count(database, AppConstants.ordersTable), 1);
        expect(await _count(database, AppConstants.invoicesTable), 1);
        expect(
          await _count(database, AppConstants.invoiceOrderRelationsTable),
          1,
        );
        final order = (await database.query(AppConstants.ordersTable)).single;
        final invoice = (await database.query(
          AppConstants.invoicesTable,
        )).single;
        final restoredOrderPath = order[AppConstants.colImagePath] as String;
        final restoredInvoicePath =
            invoice[AppConstants.colImagePath] as String;
        expect(restoredOrderPath, isNot(originalReceiptPath));
        expect(restoredInvoicePath, p.join(pdfsDirectory.path, 'invoice.pdf'));
        expect(await File(restoredOrderPath).readAsBytes(), [1, 2, 3, 4]);
        expect(await File(restoredInvoicePath).readAsBytes(), [5, 6, 7]);
        expect(await File(originalReceiptPath).exists(), isFalse);
        expect(
          await File(p.join(imagesDirectory.path, 'extra.png')).exists(),
          isFalse,
        );
      },
    );

    test(
      'overwrite fails fast when a database sidecar cannot be removed',
      () async {
        final blockedSidecar = Directory('$databasePath-shm');
        await blockedSidecar.create();

        final result = await service.restoreBackup(
          backupPath,
          RestoreMode.overwrite,
        );

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('sidecar'));
        expect(await blockedSidecar.exists(), isTrue);
        final database = await liveDatabase.open();
        expect(await _count(database, AppConstants.ordersTable), 1);
        expect(await _count(database, AppConstants.invoicesTable), 1);
      },
    );

    test(
      'atomic database replacement failure preserves the old bundle',
      () async {
        final originalReceiptPath = p.join(imagesDirectory.path, 'receipt.png');
        await File(originalReceiptPath).writeAsBytes([8, 8, 8]);
        final originalImageCount = await _fileCount(imagesDirectory);
        final failingReplacementService = BackupService(
          appDocumentsDirectoryProvider: () async => appDirectory,
          temporaryDirectoryProvider: () async => tempDirectory,
          databasePathProvider: () async => databasePath,
          openCurrentDatabase: liveDatabase.open,
          closeCurrentDatabase: liveDatabase.close,
          appVersionProvider: () async => '0.5.2',
          atomicDatabaseFileReplacer: (stagedDatabase, liveDatabase) async {
            throw const FileSystemException('simulated atomic replace failure');
          },
        );

        final result = await failingReplacementService.restoreBackup(
          backupPath,
          RestoreMode.overwrite,
        );

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('无法安全原子替换数据库'));
        final database = await liveDatabase.open();
        expect(await _count(database, AppConstants.ordersTable), 1);
        final order = (await database.query(AppConstants.ordersTable)).single;
        expect(order[AppConstants.colImagePath], originalReceiptPath);
        expect(await File(originalReceiptPath).readAsBytes(), [8, 8, 8]);
        expect(await _fileCount(imagesDirectory), originalImageCount);
        final restoreArtifacts = await File(databasePath).parent
            .list()
            .where((entity) => p.basename(entity.path).contains('.restore_'))
            .toList();
        expect(restoreArtifacts, isEmpty);
      },
    );

    test(
      'post-rename replacement error keeps the committed database and media',
      () async {
        final originalReceiptPath = p.join(imagesDirectory.path, 'receipt.png');
        await File(originalReceiptPath).writeAsBytes([8, 8, 8]);
        final database = await liveDatabase.open();
        await database.update(AppConstants.ordersTable, {
          AppConstants.colShopName: 'Current-only shop',
        });

        final postRenameFailureService = BackupService(
          appDocumentsDirectoryProvider: () async => appDirectory,
          temporaryDirectoryProvider: () async => tempDirectory,
          databasePathProvider: () async => databasePath,
          openCurrentDatabase: liveDatabase.open,
          closeCurrentDatabase: liveDatabase.close,
          appVersionProvider: () async => '0.5.2',
          atomicDatabaseFileReplacer: (stagedDatabase, liveDatabase) async {
            await stagedDatabase.rename(liveDatabase.path);
            throw StateError('simulated post-rename failure');
          },
        );

        final result = await postRenameFailureService.restoreBackup(
          backupPath,
          RestoreMode.overwrite,
        );

        expect(result.success, isTrue, reason: result.errorMessage);
        expect(
          result.warningMessage,
          contains('simulated post-rename failure'),
        );
        final restoredDatabase = await liveDatabase.open();
        final order = (await restoredDatabase.query(
          AppConstants.ordersTable,
        )).single;
        expect(order[AppConstants.colShopName], 'Backup shop');
        final restoredReceiptPath = order[AppConstants.colImagePath] as String;
        expect(restoredReceiptPath, isNot(originalReceiptPath));
        expect(await File(restoredReceiptPath).readAsBytes(), [1, 2, 3, 4]);
        expect(await File(originalReceiptPath).exists(), isFalse);
        final invoice = (await restoredDatabase.query(
          AppConstants.invoicesTable,
        )).single;
        expect(
          await File(
            invoice[AppConstants.colImagePath] as String,
          ).readAsBytes(),
          [5, 6, 7],
        );
        final restoreArtifacts = await File(databasePath).parent
            .list()
            .where((entity) => p.basename(entity.path).contains('.restore_'))
            .toList();
        expect(restoreArtifacts, isEmpty);
      },
    );

    test(
      'post-commit verification failure preserves the new database bundle',
      () async {
        final originalReceiptPath = p.join(imagesDirectory.path, 'receipt.png');
        await File(originalReceiptPath).writeAsBytes([8, 8, 8]);
        var rejectDatabaseOpen = false;
        final verificationFailureService = BackupService(
          appDocumentsDirectoryProvider: () async => appDirectory,
          temporaryDirectoryProvider: () async => tempDirectory,
          databasePathProvider: () async => databasePath,
          openCurrentDatabase: () async {
            if (rejectDatabaseOpen) {
              throw StateError('simulated post-commit verification failure');
            }
            return liveDatabase.open();
          },
          closeCurrentDatabase: () async {
            await liveDatabase.close();
            rejectDatabaseOpen = true;
          },
          appVersionProvider: () async => '0.5.2',
        );

        final result = await verificationFailureService.restoreBackup(
          backupPath,
          RestoreMode.overwrite,
        );

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('覆盖还原已提交'));
        expect(
          result.errorMessage,
          contains('simulated post-commit verification failure'),
        );
        final committedDatabase = await liveDatabase.open();
        final order = (await committedDatabase.query(
          AppConstants.ordersTable,
        )).single;
        final committedReceiptPath = order[AppConstants.colImagePath] as String;
        expect(committedReceiptPath, isNot(originalReceiptPath));
        expect(await File(committedReceiptPath).readAsBytes(), [1, 2, 3, 4]);
        final invoice = (await committedDatabase.query(
          AppConstants.invoicesTable,
        )).single;
        expect(
          await File(
            invoice[AppConstants.colImagePath] as String,
          ).readAsBytes(),
          [5, 6, 7],
        );
      },
    );

    test('migrates a v1 backup and enforces one invoice per order', () async {
      final legacyDatabasePath = p.join(rootDirectory.path, 'legacy_v1.db');
      final legacyDatabase = await databaseFactoryFfi.openDatabase(
        legacyDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await _createProductionSchema(
        legacyDatabase,
        databaseVersion: 1,
        createUniqueOrderIndex: false,
      );
      final orderId = await legacyDatabase.insert(AppConstants.ordersTable, {
        AppConstants.colImagePath: '',
        AppConstants.colShopName: 'Legacy shop',
        AppConstants.colAmount: 20.0,
        AppConstants.colOrderDate: '2025-01-01',
        AppConstants.colMealTime: 'dinner',
        AppConstants.colOrderNumber: 'LEGACY-1',
        AppConstants.colCreatedAt: '2025-01-01T08:00:00.000',
        AppConstants.colUpdatedAt: '2025-01-01T08:00:00.000',
      });
      final olderInvoiceId = await legacyDatabase
          .insert(AppConstants.invoicesTable, {
            AppConstants.colImagePath: '',
            AppConstants.colInvoiceNumber: 'LEGACY-OLD',
            AppConstants.colInvoiceDate: '2025-01-01T00:00:00.000',
            AppConstants.colTotalAmount: 20.0,
            AppConstants.colSellerName: 'Legacy shop',
            AppConstants.colCreatedAt: '2025-01-01T09:00:00.000',
            AppConstants.colUpdatedAt: '2025-01-01T09:00:00.000',
          });
      final newerInvoiceId = await legacyDatabase
          .insert(AppConstants.invoicesTable, {
            AppConstants.colImagePath: '',
            AppConstants.colInvoiceNumber: 'LEGACY-NEW',
            AppConstants.colInvoiceDate: '2025-01-02T00:00:00.000',
            AppConstants.colTotalAmount: 20.0,
            AppConstants.colSellerName: 'Legacy shop',
            AppConstants.colCreatedAt: '2025-01-02T09:00:00.000',
            AppConstants.colUpdatedAt: '2025-01-02T09:00:00.000',
          });
      await legacyDatabase.insert(AppConstants.invoiceOrderRelationsTable, {
        AppConstants.colInvoiceId: olderInvoiceId,
        AppConstants.colOrderId: orderId,
      });
      await legacyDatabase.insert(AppConstants.invoiceOrderRelationsTable, {
        AppConstants.colInvoiceId: newerInvoiceId,
        AppConstants.colOrderId: orderId,
      });
      await legacyDatabase.insert(AppConstants.invoiceOrderRelationsTable, {
        AppConstants.colInvoiceId: 999999,
        AppConstants.colOrderId: orderId,
      });
      await legacyDatabase.close();

      final legacyBackupPath = p.join(rootDirectory.path, 'legacy_v1.zip');
      await _writeStandaloneBackup(
        legacyBackupPath,
        databaseBytes: await File(legacyDatabasePath).readAsBytes(),
        metadata: BackupMetadata(
          appVersion: '0.4.0',
          databaseVersion: 1,
          backupTime: DateTime.utc(2025, 1, 2).toIso8601String(),
          orderCount: 1,
          invoiceCount: 2,
        ),
      );

      final validation = await service.validateBackup(legacyBackupPath);
      expect(validation.isValid, isTrue, reason: validation.errorMessage);
      expect(validation.canRestore, isTrue);

      final restored = await service.restoreBackup(
        legacyBackupPath,
        RestoreMode.overwrite,
      );
      expect(restored.success, isTrue, reason: restored.errorMessage);

      final database = await liveDatabase.open();
      final versionRows = await database.rawQuery('PRAGMA user_version');
      expect(versionRows.single.values.single, AppConstants.databaseVersion);
      final relations = await database.query(
        AppConstants.invoiceOrderRelationsTable,
      );
      expect(relations, hasLength(1));
      expect(relations.single[AppConstants.colInvoiceId], newerInvoiceId);
      expect(await database.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      await expectLater(
        database.insert(AppConstants.invoiceOrderRelationsTable, {
          AppConstants.colInvoiceId: olderInvoiceId,
          AppConstants.colOrderId: orderId,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test(
      'incremental restore is idempotent and maps conflicting media paths',
      () async {
        var database = await liveDatabase.open();
        await database.delete(AppConstants.invoiceOrderRelationsTable);
        await database.delete(AppConstants.invoicesTable);
        await database.delete(AppConstants.ordersTable);
        final conflictingPath = p.join(imagesDirectory.path, 'receipt.png');
        await File(conflictingPath).writeAsBytes([8, 8, 8]);
        await database.insert(AppConstants.ordersTable, {
          AppConstants.colImagePath: conflictingPath,
          AppConstants.colShopName: 'Existing order',
          AppConstants.colAmount: 3.0,
          AppConstants.colOrderDate: '2026-07-10',
          AppConstants.colMealTime: 'dinner',
          AppConstants.colOrderNumber: 'EXISTING-1',
          AppConstants.colCreatedAt: '2026-07-10T10:00:00.000',
          AppConstants.colUpdatedAt: '2026-07-10T10:00:00.000',
        });

        final firstRestore = await service.restoreBackup(
          backupPath,
          RestoreMode.incremental,
        );
        expect(firstRestore.success, isTrue, reason: firstRestore.errorMessage);

        database = await liveDatabase.open();
        expect(await _count(database, AppConstants.ordersTable), 2);
        expect(await _count(database, AppConstants.invoicesTable), 1);
        expect(
          await _count(database, AppConstants.invoiceOrderRelationsTable),
          1,
        );
        final importedOrder = (await database.query(
          AppConstants.ordersTable,
          where: '${AppConstants.colShopName} = ?',
          whereArgs: ['Backup shop'],
        )).single;
        final importedPath = importedOrder[AppConstants.colImagePath] as String;
        expect(importedPath, isNot(conflictingPath));
        expect(await File(importedPath).exists(), isTrue);
        expect(await File(importedPath).readAsBytes(), [1, 2, 3, 4]);
        expect(await File(conflictingPath).readAsBytes(), [8, 8, 8]);

        final imageCountAfterFirstRestore = await _fileCount(imagesDirectory);
        final secondRestore = await service.restoreBackup(
          backupPath,
          RestoreMode.incremental,
        );
        expect(
          secondRestore.success,
          isTrue,
          reason: secondRestore.errorMessage,
        );

        database = await liveDatabase.open();
        expect(await _count(database, AppConstants.ordersTable), 2);
        expect(await _count(database, AppConstants.invoicesTable), 1);
        expect(
          await _count(database, AppConstants.invoiceOrderRelationsTable),
          1,
        );
        expect(await _fileCount(imagesDirectory), imageCountAfterFirstRestore);
        final importedAgain = (await database.query(
          AppConstants.ordersTable,
          where: '${AppConstants.colShopName} = ?',
          whereArgs: ['Backup shop'],
        )).single;
        expect(importedAgain[AppConstants.colImagePath], importedPath);
      },
    );

    test(
      'post-commit progress errors do not turn an incremental restore into failure',
      () async {
        final database = await liveDatabase.open();
        await database.delete(AppConstants.invoiceOrderRelationsTable);
        await database.delete(AppConstants.invoicesTable);
        await database.delete(AppConstants.ordersTable);

        final result = await service.restoreBackup(
          backupPath,
          RestoreMode.incremental,
          onProgress: (progress) {
            if (progress >= 0.9) {
              throw StateError('simulated post-commit progress failure');
            }
          },
        );

        expect(result.success, isTrue, reason: result.errorMessage);
        expect(await _count(database, AppConstants.ordersTable), 1);
        expect(await _count(database, AppConstants.invoicesTable), 1);
        expect(
          await _count(database, AppConstants.invoiceOrderRelationsTable),
          1,
        );
      },
    );

    test('incremental relation conflicts return a visible warning', () async {
      final database = await liveDatabase.open();
      final orderId =
          (await database.query(
                AppConstants.ordersTable,
                columns: [AppConstants.colId],
              )).single[AppConstants.colId]
              as int;
      await database.delete(AppConstants.invoiceOrderRelationsTable);
      final conflictingInvoiceId = await database
          .insert(AppConstants.invoicesTable, {
            AppConstants.colImagePath: '',
            AppConstants.colInvoiceNumber: 'CONFLICTING-INVOICE',
            AppConstants.colInvoiceDate: '2026-07-17T00:00:00.000',
            AppConstants.colTotalAmount: 1.0,
            AppConstants.colSellerName: 'Existing seller',
            AppConstants.colCreatedAt: '2026-07-17T09:00:00.000',
            AppConstants.colUpdatedAt: '2026-07-17T09:00:00.000',
          });
      await database.insert(AppConstants.invoiceOrderRelationsTable, {
        AppConstants.colInvoiceId: conflictingInvoiceId,
        AppConstants.colOrderId: orderId,
      });

      final result = await service.restoreBackup(
        backupPath,
        RestoreMode.incremental,
      );

      expect(result.success, isTrue, reason: result.errorMessage);
      expect(result.warningMessage, contains('1 条订单关系'));
      expect(result.warningMessage, contains('已保留现状'));
      final relations = await database.query(
        AppConstants.invoiceOrderRelationsTable,
      );
      expect(relations, hasLength(1));
      expect(relations.single[AppConstants.colInvoiceId], conflictingInvoiceId);
    });
  });

  testWidgets('backup progress blocks barrier taps and system back', (
    tester,
  ) async {
    final tempDirectory = Directory.systemTemp.createTempSync(
      'receipt_tamer_backup_dialog_test_',
    );
    const pathProviderChannel = MethodChannel(
      'plugins.flutter.io/path_provider',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          return tempDirectory.path;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, null);
      if (tempDirectory.existsSync()) {
        tempDirectory.deleteSync(recursive: true);
      }
    });
    PackageInfo.setMockInitialValues(
      appName: 'ReceiptTamer',
      packageName: 'com.acautomaton.receipt.tamer',
      version: '0.5.2',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
    final hangingService = _HangingBackupService();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    showBackupDialog(context, backupService: hangingService),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('创建备份'));
    await tester.pump();
    expect(find.text('正在创建备份...'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('正在创建备份...'), findsOneWidget);

    await tester.tapAt(const Offset(4, 4));
    await tester.pump();
    expect(find.text('正在创建备份...'), findsOneWidget);

    hangingService.completeWithFailure();
    await tester.pumpAndSettle();
    expect(find.text('备份失败'), findsOneWidget);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
  });
}

class _LiveDatabaseHarness {
  _LiveDatabaseHarness(this.path);

  final String path;
  Database? _database;

  Future<Database> open() async {
    final current = _database;
    if (current != null && current.isOpen) return current;
    _database = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        singleInstance: false,
        onConfigure: (database) => database.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    return _database!;
  }

  Future<void> close() async {
    final current = _database;
    _database = null;
    if (current != null && current.isOpen) await current.close();
  }
}

class _HangingBackupService extends BackupService {
  final Completer<BackupResult> _completer = Completer<BackupResult>();

  @override
  Future<BackupResult> createBackup(
    String outputPath, {
    void Function(double progress)? onProgress,
  }) {
    return _completer.future;
  }

  void completeWithFailure() {
    _completer.complete(
      BackupResult(success: false, errorMessage: 'expected test failure'),
    );
  }
}

Future<void> _createProductionSchema(
  Database database, {
  int databaseVersion = AppConstants.databaseVersion,
  bool createUniqueOrderIndex = true,
}) async {
  await database.execute('''
    CREATE TABLE ${AppConstants.ordersTable} (
      ${AppConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
      ${AppConstants.colImagePath} TEXT NOT NULL,
      ${AppConstants.colShopName} TEXT,
      ${AppConstants.colAmount} REAL,
      ${AppConstants.colOrderDate} TEXT,
      ${AppConstants.colMealTime} TEXT,
      ${AppConstants.colOrderNumber} TEXT,
      ${AppConstants.colCreatedAt} TEXT NOT NULL,
      ${AppConstants.colUpdatedAt} TEXT NOT NULL
    )
  ''');
  await database.execute('''
    CREATE TABLE ${AppConstants.invoicesTable} (
      ${AppConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
      ${AppConstants.colImagePath} TEXT NOT NULL,
      ${AppConstants.colInvoiceNumber} TEXT,
      ${AppConstants.colInvoiceDate} TEXT,
      ${AppConstants.colTotalAmount} REAL,
      ${AppConstants.colSellerName} TEXT DEFAULT '',
      ${AppConstants.colCreatedAt} TEXT NOT NULL,
      ${AppConstants.colUpdatedAt} TEXT NOT NULL
    )
  ''');
  await database.execute('''
    CREATE TABLE ${AppConstants.invoiceOrderRelationsTable} (
      ${AppConstants.colInvoiceId} INTEGER NOT NULL,
      ${AppConstants.colOrderId} INTEGER NOT NULL,
      PRIMARY KEY (${AppConstants.colInvoiceId}, ${AppConstants.colOrderId}),
      FOREIGN KEY (${AppConstants.colInvoiceId})
        REFERENCES ${AppConstants.invoicesTable}(${AppConstants.colId})
        ON DELETE CASCADE,
      FOREIGN KEY (${AppConstants.colOrderId})
        REFERENCES ${AppConstants.ordersTable}(${AppConstants.colId})
        ON DELETE CASCADE
    )
  ''');
  if (createUniqueOrderIndex) {
    await database.execute('''
      CREATE UNIQUE INDEX idx_invoice_order_relations_order_id
      ON ${AppConstants.invoiceOrderRelationsTable}(${AppConstants.colOrderId})
    ''');
  }
  await database.execute('PRAGMA user_version = $databaseVersion');
}

Future<void> _seedBaseline(
  Database database, {
  required Directory imagesDirectory,
  required Directory pdfsDirectory,
}) async {
  final imagePath = p.join(imagesDirectory.path, 'receipt.png');
  final pdfPath = p.join(pdfsDirectory.path, 'invoice.pdf');
  await File(imagePath).writeAsBytes([1, 2, 3, 4]);
  await File(pdfPath).writeAsBytes([5, 6, 7]);
  final orderId = await database.insert(AppConstants.ordersTable, {
    AppConstants.colImagePath: imagePath,
    AppConstants.colShopName: 'Backup shop',
    AppConstants.colAmount: 12.5,
    AppConstants.colOrderDate: '2026-07-01',
    AppConstants.colMealTime: 'lunch',
    AppConstants.colOrderNumber: 'ORDER-1',
    AppConstants.colCreatedAt: '2026-07-01T10:00:00.000',
    AppConstants.colUpdatedAt: '2026-07-01T10:00:00.000',
  });
  final invoiceId = await database.insert(AppConstants.invoicesTable, {
    AppConstants.colImagePath: pdfPath,
    AppConstants.colInvoiceNumber: 'INVOICE-1',
    AppConstants.colInvoiceDate: '2026-07-01T00:00:00.000',
    AppConstants.colTotalAmount: 12.5,
    AppConstants.colSellerName: 'Backup shop',
    AppConstants.colCreatedAt: '2026-07-01T11:00:00.000',
    AppConstants.colUpdatedAt: '2026-07-01T11:00:00.000',
  });
  await database.insert(AppConstants.invoiceOrderRelationsTable, {
    AppConstants.colInvoiceId: invoiceId,
    AppConstants.colOrderId: orderId,
  });
}

Future<int> _count(Database database, String table) async {
  final rows = await database.rawQuery('SELECT COUNT(*) AS count FROM $table');
  return (rows.single['count'] as num).toInt();
}

Future<int> _fileCount(Directory directory) async {
  return (await directory.list().where((entity) => entity is File).toList())
      .length;
}

Future<void> _writeArchiveVariant(
  String sourcePath,
  String destinationPath, {
  bool Function(String name)? keepEntry,
  List<int>? replacementDatabase,
  String Function(String name)? entryNameTransform,
  Map<String, List<int>> entryReplacements = const {},
  Map<String, dynamic> Function(Map<String, dynamic> manifest)?
  manifestTransform,
}) async {
  final sourceArchive = ZipDecoder().decodeBytes(
    await File(sourcePath).readAsBytes(),
  );
  final destinationArchive = Archive();
  for (final entry in sourceArchive) {
    if (!entry.isFile) continue;
    final name = entry.name.replaceAll('\\', '/');
    if (keepEntry != null && !keepEntry(name)) continue;
    var bytes = entryReplacements[name] ?? List<int>.from(entry.content);
    if (name == 'database/${AppConstants.databaseName}' &&
        replacementDatabase != null) {
      bytes = replacementDatabase;
    }
    if (name == 'manifest.json' && manifestTransform != null) {
      final manifest = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(bytes)) as Map,
      );
      bytes = utf8.encode(jsonEncode(manifestTransform(manifest)));
    }
    final destinationName = entryNameTransform?.call(name) ?? name;
    destinationArchive.addFile(
      ArchiveFile(destinationName, bytes.length, bytes),
    );
  }
  await File(
    destinationPath,
  ).writeAsBytes(ZipEncoder().encode(destinationArchive));
}

Future<void> _writeStandaloneBackup(
  String destinationPath, {
  required List<int> databaseBytes,
  required BackupMetadata metadata,
  Map<String, List<int>> images = const {},
  Map<String, List<int>> pdfs = const {},
}) async {
  final archive = Archive()
    ..addFile(
      ArchiveFile.string('manifest.json', jsonEncode(metadata.toJson())),
    )
    ..addFile(
      ArchiveFile(
        'database/${AppConstants.databaseName}',
        databaseBytes.length,
        databaseBytes,
      ),
    );
  for (final entry in images.entries) {
    archive.addFile(
      ArchiveFile('images/${entry.key}', entry.value.length, entry.value),
    );
  }
  for (final entry in pdfs.entries) {
    archive.addFile(
      ArchiveFile('pdfs/${entry.key}', entry.value.length, entry.value),
    );
  }
  await File(destinationPath).writeAsBytes(ZipEncoder().encode(archive));
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/models/meal_proof_item.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/data/services/invoice_export_service.dart';
import 'package:receipt_tamer/data/services/meal_proof_export_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('receipt_export_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('invoice label keeps a 50-character remark and linked order time', () {
    final remark = List.filled(50, '备').join();
    final item = InvoiceExportItem(
      invoice: const Invoice(id: 8, imagePath: 'invoice.png'),
      orders: const [
        Order(
          id: 3,
          imagePath: 'order.png',
          orderDate: '2026-07-16',
          mealTime: 'lunch',
        ),
      ],
      remark: remark,
    );

    expect(item.buildLabel(), startsWith('$remark|'));
    expect(item.buildLabel(), contains('2026年07月16日午餐'));
    expect(item.buildLabel(showRemark: false), '2026年07月16日午餐');
    expect(item.buildLabel(showTimeLabel: false), remark);
  });

  test(
    'invoice attachment validation partitions missing and usable files',
    () async {
      final existingPath =
          '${tempDir.path}${Platform.pathSeparator}invoice.png';
      await File(existingPath).writeAsBytes([1, 2, 3]);
      final existing = InvoiceExportItem(
        invoice: Invoice(id: 1, imagePath: existingPath),
        orders: const [],
      );
      final missing = InvoiceExportItem(
        invoice: Invoice(
          id: 2,
          imagePath: '${tempDir.path}${Platform.pathSeparator}missing.png',
        ),
        orders: const [],
      );
      const empty = InvoiceExportItem(
        invoice: Invoice(id: 3, imagePath: ''),
        orders: [],
      );

      final result = await InvoiceExportService.validateAttachments(
        items: [existing, missing, empty],
        getFilePath: (path) => path,
      );

      expect(result.exportableItems, [existing]);
      expect(result.unavailableItems, [missing, empty]);
    },
  );

  test(
    'missing invoice attachment never creates a blank success PDF',
    () async {
      final outputPath = '${tempDir.path}${Platform.pathSeparator}invoice.pdf';
      final item = InvoiceExportItem(
        invoice: Invoice(
          id: 9,
          imagePath: '${tempDir.path}${Platform.pathSeparator}missing.png',
        ),
        orders: const [],
      );

      await expectLater(
        InvoiceExportService.generateInvoicePdf(
          items: [item],
          outputPath: outputPath,
          getFilePath: (path) => path,
        ),
        throwsA(isA<InvoiceAttachmentUnavailableException>()),
      );
      expect(await File(outputPath).exists(), isFalse);
    },
  );

  test(
    'missing order screenshot never creates a partial meal proof PDF',
    () async {
      final outputPath = '${tempDir.path}${Platform.pathSeparator}meal.pdf';
      final order = Order(
        id: 4,
        imagePath: '${tempDir.path}${Platform.pathSeparator}missing.png',
      );
      final item = MealProofItem(
        order: order,
        invoice: null,
        proratedInvoiceAmount: 0,
        totalInvoiceAmount: 0,
        isProRated: false,
      );

      await expectLater(
        MealProofExportService.generatePdf(
          items: [item],
          outputPath: outputPath,
          getImagePath: (path) => path,
        ),
        throwsA(isA<MealProofAttachmentUnavailableException>()),
      );
      expect(await File(outputPath).exists(), isFalse);
    },
  );

  test('generated invoice PDF contains remark and order-time stamps', () async {
    final sourcePath = '${tempDir.path}${Platform.pathSeparator}invoice.png';
    final outputPath = '${tempDir.path}${Platform.pathSeparator}invoice.pdf';
    final sourceImage = img.Image(width: 160, height: 90);
    img.fill(sourceImage, color: img.ColorRgb8(245, 245, 245));
    await File(sourcePath).writeAsBytes(img.encodePng(sourceImage));
    final remark = List.filled(50, 'A').join();
    final item = InvoiceExportItem(
      invoice: Invoice(id: 10, imagePath: sourcePath),
      orders: const [Order(orderDate: '2026-07-16', mealTime: 'dinner')],
      remark: remark,
    );

    await InvoiceExportService.generateInvoicePdf(
      items: [item],
      outputPath: outputPath,
      getFilePath: (path) => path,
      showRemark: true,
      showTimeLabel: true,
    );

    final document = PdfDocument(
      inputBytes: await File(outputPath).readAsBytes(),
    );
    final extracted = PdfTextExtractor(document).extractText();
    document.dispose();
    final normalized = extracted.replaceAll(RegExp(r'\s+'), '');
    expect(normalized, contains(remark));
    expect(normalized, contains('2026年07月16日晚餐'));
  });
}

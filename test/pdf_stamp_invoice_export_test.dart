import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/services/invoice_export_service.dart';

const _samplePdfPath = r'C:\Users\acautomaton\Downloads\1774976051663.pdf';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'invoice PDF export rasterizes stamp-annotation PDFs',
    () async {
      final source = File(_samplePdfPath);
      final sourceBytes = await source.readAsBytes();
      expect(_stampSubtypeCount(sourceBytes), greaterThan(0));

      final tempDir = await Directory.systemTemp.createTemp(
        'receipt_tamer_pdf_stamp_export_',
      );
      try {
        final outputPath = '${tempDir.path}/invoice_export.pdf';
        await InvoiceExportService.generateInvoicePdf(
          items: [
            InvoiceExportItem(
              invoice: const Invoice(imagePath: _samplePdfPath),
              orders: const [],
            ),
          ],
          outputPath: outputPath,
          getFilePath: (path) => path,
          showRemark: false,
          showTimeLabel: false,
        );

        final outputBytes = await File(outputPath).readAsBytes();
        expect(outputBytes.length, greaterThan(100000));
        expect(_stampSubtypeCount(outputBytes), 0);
      } finally {
        await tempDir.delete(recursive: true);
      }
    },
    skip: File(_samplePdfPath).existsSync()
        ? false
        : 'Local stamp sample PDF is not available.',
  );
}

int _stampSubtypeCount(List<int> pdfBytes) {
  final text = String.fromCharCodes(pdfBytes);
  return RegExp(r'/Subtype\s*/Stamp').allMatches(text).length;
}

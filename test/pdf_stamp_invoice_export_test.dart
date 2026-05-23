import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;
import 'package:receipt_tamer/core/services/pdfrx_font_service.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/services/invoice_export_service.dart';

const _samplePdfPath = r'C:\Users\acautomaton\Downloads\1774976051663.pdf';
const _fontSensitivePdfPath =
    r'C:\Users\acautomaton\Downloads\1774460494127.pdf';
const _printedTitlePdfPath =
    r'C:\Users\acautomaton\Downloads\1774802913105.pdf';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'pdfrx font resolver maps common Chinese invoice font aliases',
    () async {
      final resolver = PdfrxFontService.instance.createFontResolver();

      for (final query in const [
        pdfrx.PdfFontQuery(
          face: 'STSong-Light-UniGB-UCS2-H',
          weight: 400,
          isItalic: false,
          charset: pdfrx.PdfFontCharset.gb2312,
          pitchFamily: 0,
        ),
        pdfrx.PdfFontQuery(
          face: 'VFRUUO+STKaitiSC-Bold',
          weight: 700,
          isItalic: false,
          charset: pdfrx.PdfFontCharset.gb2312,
          pitchFamily: 0,
        ),
        pdfrx.PdfFontQuery(
          face: 'SimSun',
          weight: 400,
          isItalic: false,
          charset: pdfrx.PdfFontCharset.gb2312,
          pitchFamily: 0,
        ),
        pdfrx.PdfFontQuery(
          face: 'Microsoft YaHei',
          weight: 400,
          isItalic: false,
          charset: pdfrx.PdfFontCharset.gb2312,
          pitchFamily: 0,
        ),
        pdfrx.PdfFontQuery(
          face: 'FangSong',
          weight: 400,
          isItalic: false,
          charset: pdfrx.PdfFontCharset.gb2312,
          pitchFamily: 0,
        ),
        pdfrx.PdfFontQuery(
          face: 'CourierNewPSMT',
          weight: 400,
          isItalic: false,
          charset: pdfrx.PdfFontCharset.ansi,
          pitchFamily: 1,
        ),
        pdfrx.PdfFontQuery(
          face: 'TimesNewRomanPSMT',
          weight: 400,
          isItalic: false,
          charset: pdfrx.PdfFontCharset.ansi,
          pitchFamily: 16,
        ),
        pdfrx.PdfFontQuery(
          face: 'InvoiceAmountDigits',
          weight: 400,
          isItalic: false,
          charset: pdfrx.PdfFontCharset.ansi,
          pitchFamily: 0,
        ),
        pdfrx.PdfFontQuery(
          face: 'InvoiceNumberDigits',
          weight: 400,
          isItalic: false,
          charset: pdfrx.PdfFontCharset.gb2312,
          pitchFamily: 0,
        ),
        pdfrx.PdfFontQuery(
          face: 'UnknownInvoiceFont',
          weight: 400,
          isItalic: false,
          charset: pdfrx.PdfFontCharset.ansi,
          pitchFamily: 0,
        ),
      ]) {
        final resolution = await resolver.resolve(
          query,
          const pdfrx.PdfFontResolveContext(),
        );

        expect(resolution, isNotNull, reason: query.face);
        final data = await resolution!.loadData!();
        expect(data.length, greaterThan(50000), reason: query.face);
      }
    },
  );

  test(
    'pdfrx font resolver maps Times and amount digits to Times fallback',
    () async {
      final resolver = PdfrxFontService.instance.createFontResolver();

      for (final query in const [
        pdfrx.PdfFontQuery(
          face: 'TimesNewRomanPSMT',
          weight: 400,
          isItalic: false,
          charset: pdfrx.PdfFontCharset.ansi,
          pitchFamily: 16,
        ),
        pdfrx.PdfFontQuery(
          face: 'InvoiceAmountDigits',
          weight: 400,
          isItalic: false,
          charset: pdfrx.PdfFontCharset.ansi,
          pitchFamily: 0,
        ),
        pdfrx.PdfFontQuery(
          face: 'RMBTotalAmount',
          weight: 700,
          isItalic: false,
          charset: pdfrx.PdfFontCharset.ansi,
          pitchFamily: 0,
        ),
      ]) {
        final resolution = await resolver.resolve(
          query,
          const pdfrx.PdfFontResolveContext(),
        );

        expect(resolution?.resolvedFace, 'Tinos', reason: query.face);
      }
    },
  );

  test(
    'pdfrx font resolver maps invoice taxpayer identifiers to Courier fallback',
    () async {
      final resolver = PdfrxFontService.instance.createFontResolver();

      for (final query in const [
        pdfrx.PdfFontQuery(
          face: 'CourierNew',
          weight: 400,
          isItalic: false,
          charset: pdfrx.PdfFontCharset.ansi,
          pitchFamily: 1,
        ),
        pdfrx.PdfFontQuery(
          face: 'CourierNewPSMT',
          weight: 400,
          isItalic: false,
          charset: pdfrx.PdfFontCharset.ansi,
          pitchFamily: 1,
        ),
        pdfrx.PdfFontQuery(
          face: 'Courier',
          weight: 400,
          isItalic: false,
          charset: pdfrx.PdfFontCharset.ansi,
          pitchFamily: 1,
        ),
        pdfrx.PdfFontQuery(
          face: 'TaxpayerCodeDigits',
          weight: 400,
          isItalic: false,
          charset: pdfrx.PdfFontCharset.gb2312,
          pitchFamily: 0,
        ),
      ]) {
        final resolution = await resolver.resolve(
          query,
          const pdfrx.PdfFontResolveContext(),
        );

        expect(resolution?.resolvedFace, 'Courier Prime', reason: query.face);
      }
    },
  );

  test(
    'pdfrx font resolver maps invoice stamp Arial tax ids to Arial fallback',
    () async {
      final resolver = PdfrxFontService.instance.createFontResolver();

      for (final query in const [
        pdfrx.PdfFontQuery(
          face: 'Arial',
          weight: 400,
          isItalic: false,
          charset: pdfrx.PdfFontCharset.ansi,
          pitchFamily: 0,
        ),
        pdfrx.PdfFontQuery(
          face: 'ArialMT',
          weight: 400,
          isItalic: false,
          charset: pdfrx.PdfFontCharset.ansi,
          pitchFamily: 0,
        ),
      ]) {
        final resolution = await resolver.resolve(
          query,
          const pdfrx.PdfFontResolveContext(),
        );

        expect(resolution?.resolvedFace, 'Arimo', reason: query.face);
      }
    },
  );

  test(
    'pdfrx font resolver maps invoice title Kai fonts to formal Kai fallback',
    () async {
      final resolver = PdfrxFontService.instance.createFontResolver();

      for (final query in [
        const pdfrx.PdfFontQuery(
          face: 'STKaitiSC-Bold',
          weight: 700,
          isItalic: false,
          charset: pdfrx.PdfFontCharset.gb2312,
          pitchFamily: 0,
        ),
        const pdfrx.PdfFontQuery(
          face: 'KaiTi',
          weight: 400,
          isItalic: false,
          charset: pdfrx.PdfFontCharset.gb2312,
          pitchFamily: 0,
        ),
        pdfrx.PdfFontQuery(
          face: String.fromCharCodes(utf8.encode('SWQMSB+楷体')),
          weight: 400,
          isItalic: false,
          charset: pdfrx.PdfFontCharset.gb2312,
          pitchFamily: 0,
        ),
      ]) {
        final resolution = await resolver.resolve(
          query,
          const pdfrx.PdfFontResolveContext(),
        );

        expect(resolution?.resolvedFace, 'LXGW ZhenKai GB', reason: query.face);
      }
    },
  );

  test(
    'pdfrx font resolver maps STKaiti regular titles to printed serif fallback',
    () async {
      final resolver = PdfrxFontService.instance.createFontResolver();

      for (final query in const [
        pdfrx.PdfFontQuery(
          face: 'STKaiti-Regular',
          weight: 400,
          isItalic: false,
          charset: pdfrx.PdfFontCharset.gb2312,
          pitchFamily: 0,
        ),
        pdfrx.PdfFontQuery(
          face: 'STKaiti-Regular-Identity-H',
          weight: 400,
          isItalic: false,
          charset: pdfrx.PdfFontCharset.gb2312,
          pitchFamily: 0,
        ),
        pdfrx.PdfFontQuery(
          face: 'STKaiti',
          weight: 400,
          isItalic: false,
          charset: pdfrx.PdfFontCharset.gb2312,
          pitchFamily: 0,
        ),
      ]) {
        final resolution = await resolver.resolve(
          query,
          const pdfrx.PdfFontResolveContext(),
        );

        expect(resolution?.resolvedFace, 'Noto Serif SC', reason: query.face);
      }
    },
  );

  test('pdfrx font service does not preload embedded declared fonts', () async {
    final resolver = _TrackingFontResolver();
    final fontManager = pdfrx.PdfFontManager(resolvers: [resolver]);

    await PdfrxFontService.instance.prepareFontManagerForPdfBytes(
      fontManager,
      utf8.encode(
        '1 0 obj <</Type/FontDescriptor/FontName/UNBXXO+SimSun'
        '/FontFile2 4 0 R>> endobj '
        '2 0 obj <</Type/Font/Subtype/CIDFontType2'
        '/BaseFont/UNBXXO+SimSun/FontDescriptor 1 0 R>> endobj '
        '3 0 obj <</Type/Font/Subtype/Type0/BaseFont/UNBXXO+SimSun'
        '/DescendantFonts[2 0 R]>> endobj',
      ),
    );

    expect(resolver.resolvedFaces, isEmpty);
  });

  test(
    'pdfrx font service preloads unembedded declared title fallbacks',
    () async {
      final resolver = _TrackingFontResolver();
      final fontManager = pdfrx.PdfFontManager(resolvers: [resolver]);

      await PdfrxFontService.instance.prepareFontManagerForPdfBytes(
        fontManager,
        utf8.encode(
          '1 0 obj <</Type/FontDescriptor/FontName/STKaiti-Regular>> endobj '
          '2 0 obj <</Type/Font/Subtype/CIDFontType0'
          '/BaseFont/STKaiti-Regular/FontDescriptor 1 0 R>> endobj '
          '3 0 obj <</Type/Font/Subtype/Type0'
          '/BaseFont/STKaiti-Regular-Identity-H'
          '/DescendantFonts[2 0 R]>> endobj',
        ),
      );

      expect(resolver.resolvedFaces, ['STKaiti-Regular']);
    },
  );

  test(
    'pdfrx font service extracts Shenzhen printed title fallback',
    () async {
      final sourceBytes = await File(_printedTitlePdfPath).readAsBytes();
      final queries = PdfrxFontService.instance.extractUnembeddedFontQueries(
        sourceBytes,
      );
      final faces = queries.map((query) => query.face).toSet();

      expect(
        faces,
        contains(anyOf('STKaiti-Regular', 'STKaiti-Regular-Identity-H')),
      );
      expect(faces, isNot(contains('UNBXXO+SimSun')));
      expect(faces, isNot(contains('ZKTGSX+CourierNewPSMT')));
    },
    skip: File(_printedTitlePdfPath).existsSync()
        ? false
        : 'Local Shenzhen printed-title PDF sample is not available.',
  );

  test(
    'pdfrx font resolver maps non-amount digit fonts to Source Han Sans Light',
    () async {
      final resolver = PdfrxFontService.instance.createFontResolver();

      for (final query in const [
        pdfrx.PdfFontQuery(
          face: 'InvoiceNumberDigits',
          weight: 400,
          isItalic: false,
          charset: pdfrx.PdfFontCharset.gb2312,
          pitchFamily: 0,
        ),
        pdfrx.PdfFontQuery(
          face: 'InvoiceDateDigits',
          weight: 400,
          isItalic: false,
          charset: pdfrx.PdfFontCharset.gb2312,
          pitchFamily: 0,
        ),
      ]) {
        final resolution = await resolver.resolve(
          query,
          const pdfrx.PdfFontResolveContext(),
        );

        expect(
          resolution?.resolvedFace,
          'Source Han Sans SC Light',
          reason: query.face,
        );
      }
    },
  );

  test(
    'pdfrx font resolver decodes PDF byte-style Chinese font names',
    () async {
      final resolver = PdfrxFontService.instance.createFontResolver();

      final kaiResolution = await resolver.resolve(
        pdfrx.PdfFontQuery(
          face: String.fromCharCodes(utf8.encode('SWQMSB+楷体')),
          weight: 400,
          isItalic: false,
          charset: pdfrx.PdfFontCharset.gb2312,
          pitchFamily: 0,
        ),
        const pdfrx.PdfFontResolveContext(),
      );
      final songResolution = await resolver.resolve(
        pdfrx.PdfFontQuery(
          face: String.fromCharCodes(utf8.encode('SWWNNY+宋体')),
          weight: 400,
          isItalic: false,
          charset: pdfrx.PdfFontCharset.gb2312,
          pitchFamily: 0,
        ),
        const pdfrx.PdfFontResolveContext(),
      );

      expect(kaiResolution?.resolvedFace, 'LXGW ZhenKai GB');
      expect(songResolution?.resolvedFace, 'Noto Serif SC');
    },
  );

  test('pdfrx font resolver only uses bundled fallback fonts', () async {
    final resolver = PdfrxFontService.instance.createFontResolver();
    final expectedFaces = {
      'Tinos',
      'Noto Serif SC',
      'LXGW ZhenKai GB',
      'Source Han Sans SC Light',
      'Courier Prime',
      'Arimo',
    };

    for (final query in const [
      pdfrx.PdfFontQuery(
        face: 'STSong-Light-UniGB-UCS2-H',
        weight: 400,
        isItalic: false,
        charset: pdfrx.PdfFontCharset.gb2312,
        pitchFamily: 0,
      ),
      pdfrx.PdfFontQuery(
        face: 'VFRUUO+STKaitiSC-Bold',
        weight: 700,
        isItalic: false,
        charset: pdfrx.PdfFontCharset.gb2312,
        pitchFamily: 0,
      ),
      pdfrx.PdfFontQuery(
        face: 'CourierNewPSMT',
        weight: 400,
        isItalic: false,
        charset: pdfrx.PdfFontCharset.ansi,
        pitchFamily: 1,
      ),
      pdfrx.PdfFontQuery(
        face: 'UnknownInvoiceFont',
        weight: 400,
        isItalic: false,
        charset: pdfrx.PdfFontCharset.ansi,
        pitchFamily: 0,
      ),
    ]) {
      final resolution = await resolver.resolve(
        query,
        const pdfrx.PdfFontResolveContext(),
      );

      expect(resolution, isNotNull, reason: query.face);
      expect(expectedFaces, contains(resolution!.resolvedFace));
    }
  });

  test(
    'pdfrx font service extracts exact embedded PDF font names',
    () async {
      final sourceBytes = await File(_fontSensitivePdfPath).readAsBytes();
      final queries = PdfrxFontService.instance.extractFontQueries(sourceBytes);
      final faces = queries.map((query) => query.face).toSet();

      expect(faces, contains('STSong-Light-UniGB-UCS2-H'));
      expect(faces, contains('VFRUUO+STKaitiSC-Bold'));
    },
    skip: File(_fontSensitivePdfPath).existsSync()
        ? false
        : 'Local font-sensitive PDF sample is not available.',
  );

  test('pdfrx font service extracts utf8 PDF font names', () {
    final queries = PdfrxFontService.instance.extractFontQueries(
      utf8.encode('/BaseFont /SWQMSB+楷体 /FontName /SWWNNY+宋体'),
    );
    final faces = queries.map((query) => query.face).toSet();

    expect(faces, contains('SWQMSB+楷体'));
    expect(faces, contains('SWWNNY+宋体'));
  });

  test('pdfrx font service deduplicates batch PDF font names', () {
    final queries = PdfrxFontService.instance
        .extractFontQueriesForPdfByteCollections([
          utf8.encode('/BaseFont /SWQMSB+楷体 /FontName /SWWNNY+宋体'),
          utf8.encode('/BaseFont /SWQMSB+楷体 /FontName /TimesNewRomanPSMT'),
        ]);
    final faces = queries.map((query) => query.face).toList();

    expect(faces, ['SWQMSB+楷体', 'SWWNNY+宋体', 'TimesNewRomanPSMT']);
  });

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

  test(
    'invoice PDF export rasterizes font-sensitive PDFs with pdfrx',
    () async {
      final source = File(_fontSensitivePdfPath);
      final sourceBytes = await source.readAsBytes();
      expect(_stampSubtypeCount(sourceBytes), 0);

      final tempDir = await Directory.systemTemp.createTemp(
        'receipt_tamer_pdf_template_export_',
      );
      try {
        final outputPath = '${tempDir.path}/invoice_export.pdf';
        await InvoiceExportService.generateInvoicePdf(
          items: [
            InvoiceExportItem(
              invoice: const Invoice(imagePath: _fontSensitivePdfPath),
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
        expect(
          String.fromCharCodes(outputBytes),
          isNot(contains('STSong-Light-UniGB-UCS2-H')),
        );
      } finally {
        await tempDir.delete(recursive: true);
      }
    },
    skip: File(_fontSensitivePdfPath).existsSync()
        ? false
        : 'Local font-sensitive PDF sample is not available.',
  );

  test(
    'invoice PDF export rasterizes Shenzhen printed-title PDF with pdfrx',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'receipt_tamer_pdf_shenzhen_title_export_',
      );
      try {
        final outputPath = '${tempDir.path}/invoice_export.pdf';
        await InvoiceExportService.generateInvoicePdf(
          items: [
            InvoiceExportItem(
              invoice: const Invoice(imagePath: _printedTitlePdfPath),
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
        expect(
          String.fromCharCodes(outputBytes),
          isNot(contains('STKaiti-Regular')),
        );
      } finally {
        await tempDir.delete(recursive: true);
      }
    },
    skip: File(_printedTitlePdfPath).existsSync()
        ? false
        : 'Local Shenzhen printed-title PDF sample is not available.',
  );
}

int _stampSubtypeCount(List<int> pdfBytes) {
  final text = String.fromCharCodes(pdfBytes);
  return RegExp(r'/Subtype\s*/Stamp').allMatches(text).length;
}

class _TrackingFontResolver implements pdfrx.PdfFontResolver {
  final resolvedFaces = <String>[];

  @override
  pdfrx.PdfFontResolution? resolve(
    pdfrx.PdfFontQuery query,
    pdfrx.PdfFontResolveContext context,
  ) {
    resolvedFaces.add(query.face);
    return null;
  }
}

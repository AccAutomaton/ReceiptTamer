import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;
import 'package:receipt_tamer/core/services/pdfrx_font_service.dart';

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

    final fallbackCount = await PdfrxFontService.instance
        .prepareFontManagerForPdfBytes(
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

    expect(fallbackCount, 0);
    expect(resolver.resolvedFaces, isEmpty);
  });

  test(
    'pdfrx font service preloads unembedded declared title fallbacks',
    () async {
      final resolver = _TrackingFontResolver();
      final fontManager = pdfrx.PdfFontManager(resolvers: [resolver]);

      final fallbackCount = await PdfrxFontService.instance
          .prepareFontManagerForPdfBytes(
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

      expect(fallbackCount, 1);
      expect(resolver.resolvedFaces, ['STKaiti-Regular']);
    },
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

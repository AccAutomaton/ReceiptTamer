import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;

/// Provides bundled CJK font fallbacks for pdfrx/PDFium rendering.
class PdfrxFontService {
  PdfrxFontService._();

  static final PdfrxFontService instance = PdfrxFontService._();

  static const String _sansPath = 'assets/fonts/NotoSansSC-VF.ttf';
  static const String _serifPath = 'assets/fonts/NotoSerifSC-VF.ttf';
  static const String _kaiPath = 'assets/fonts/LXGWWenKai-Regular.ttf';

  final Map<String, Uint8List> _fontDataCache = {};

  pdfrx.PdfFontManager createFontManager() {
    return pdfrx.PdfFontManager(resolvers: [createFontResolver()]);
  }

  Future<pdfrx.PdfFontManager> createPreparedFontManagerForPdfBytes(
    List<int> pdfBytes,
  ) async {
    final fontManager = createFontManager();
    await prepareFontManagerForPdfBytes(fontManager, pdfBytes);
    return fontManager;
  }

  Future<void> prepareFontManagerForPdfBytes(
    pdfrx.PdfFontManager fontManager,
    List<int> pdfBytes,
  ) async {
    await fontManager.prepare();

    final queries = extractFontQueries(pdfBytes);
    if (queries.isEmpty) return;

    await fontManager.loadMissingFonts(queries);
  }

  pdfrx.PdfFontResolver createFontResolver() {
    return _BundledCjkFontResolver(this);
  }

  Future<Uint8List> loadFontData(String assetPath) async {
    final cachedData = _fontDataCache[assetPath];
    if (cachedData != null) return cachedData;

    final byteData = await rootBundle.load(assetPath);
    final data = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
    _fontDataCache[assetPath] = data;
    return data;
  }

  _BundledFontAsset? _chooseFont(pdfrx.PdfFontQuery query) {
    final face = _normalizeFace(query.face);
    if (_containsAny(face, const ['kaiti', 'stkaiti', 'simkai', 'kai', '楷'])) {
      return const _BundledFontAsset(_kaiPath, 'LXGW WenKai');
    }

    if (_containsAny(face, const [
      'song',
      'simsun',
      'stsong',
      'serif',
      'fangsong',
      'simfang',
      'stfang',
      'ming',
      'pmingliu',
      'batang',
      'songti',
      '宋',
      '仿宋',
      '明',
    ])) {
      return const _BundledFontAsset(_serifPath, 'Noto Serif SC');
    }

    return const _BundledFontAsset(_sansPath, 'Noto Sans SC');
  }

  List<pdfrx.PdfFontQuery> extractFontQueries(List<int> pdfBytes) {
    final content = String.fromCharCodes(pdfBytes);
    final matches = RegExp(
      r'/(?:BaseFont|FontName)\s*/([^\s<>\[\]\(\)/%]+)',
    ).allMatches(content);

    final queries = <pdfrx.PdfFontQuery>[];
    final seen = <String>{};
    for (final match in matches) {
      final face = _decodePdfName(match.group(1)!);
      if (_chooseFont(_queryForFace(face)) == null) continue;

      final query = _queryForFace(face);
      final key =
          '${query.face}\x1f${query.weight}\x1f${query.isItalic}\x1f${query.charset}';
      if (seen.add(key)) {
        queries.add(query);
      }
    }
    return queries;
  }

  static pdfrx.PdfFontQuery _queryForFace(String face) {
    final normalizedFace = _normalizeFace(face);
    final isBold =
        normalizedFace.contains('bold') ||
        normalizedFace.contains('bd') ||
        normalizedFace.contains('black');
    final isItalic =
        normalizedFace.contains('italic') || normalizedFace.contains('oblique');
    final charset =
        normalizedFace.contains('big5') ||
            normalizedFace.contains('mingliu') ||
            normalizedFace.contains('pmingliu')
        ? pdfrx.PdfFontCharset.chineseBig5
        : pdfrx.PdfFontCharset.gb2312;

    return pdfrx.PdfFontQuery(
      face: face,
      weight: isBold ? 700 : 400,
      isItalic: isItalic,
      charset: charset,
      pitchFamily: 0,
    );
  }

  static String _decodePdfName(String name) {
    if (name.codeUnits.any((codeUnit) => codeUnit > 0xff)) {
      return name.replaceAllMapped(RegExp(r'#([0-9A-Fa-f]{2})'), (match) {
        return String.fromCharCode(int.parse(match.group(1)!, radix: 16));
      });
    }

    final bytes = <int>[];
    for (var i = 0; i < name.length; i += 1) {
      final char = name[i];
      if (char == '#' &&
          i + 2 < name.length &&
          RegExp(r'^[0-9A-Fa-f]{2}$').hasMatch(name.substring(i + 1, i + 3))) {
        bytes.add(int.parse(name.substring(i + 1, i + 3), radix: 16));
        i += 2;
      } else {
        bytes.add(name.codeUnitAt(i));
      }
    }

    try {
      return utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      return String.fromCharCodes(bytes);
    }
  }

  static String _normalizeFace(String face) {
    final decodedFace = _decodePdfName(face);
    final baseFace = decodedFace.contains('+')
        ? decodedFace.split('+').last
        : decodedFace;
    return baseFace.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
  }

  static bool _containsAny(String value, List<String> needles) {
    for (final needle in needles) {
      if (value.contains(needle)) return true;
    }
    return false;
  }
}

class _BundledCjkFontResolver implements pdfrx.PdfFontResolver {
  const _BundledCjkFontResolver(this._service);

  final PdfrxFontService _service;

  @override
  FutureOr<pdfrx.PdfFontResolution?> resolve(
    pdfrx.PdfFontQuery query,
    pdfrx.PdfFontResolveContext context,
  ) {
    final asset = _service._chooseFont(query);
    if (asset == null) return null;

    return pdfrx.PdfFontResolution(
      loadData: ({onProgress}) async {
        final data = await _service.loadFontData(asset.path);
        onProgress?.call(loaded: data.length, total: data.length);
        return data;
      },
      resolvedFace: asset.resolvedFace,
      source: Uri(path: asset.path),
    );
  }
}

class _BundledFontAsset {
  const _BundledFontAsset(this.path, this.resolvedFace);

  final String path;
  final String resolvedFace;
}

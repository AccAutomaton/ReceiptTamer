import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;

/// Provides bundled CJK font fallbacks for pdfrx/PDFium rendering.
class PdfrxFontService {
  PdfrxFontService._();

  static final PdfrxFontService instance = PdfrxFontService._();
  static const int _maxCachedFontBytes = 2 * 1024 * 1024;

  static const String _sansPath = 'assets/fonts/NotoSansSC-VF.ttf';
  static const String _serifPath = 'assets/fonts/NotoSerifSC-VF.ttf';
  static const String _kaiPath = 'assets/fonts/LXGWZhenKaiGB-Regular.ttf';
  static const String _tinosRegularPath = 'assets/fonts/Tinos-Regular.ttf';
  static const String _tinosBoldPath = 'assets/fonts/Tinos-Bold.ttf';
  static const String _tinosItalicPath = 'assets/fonts/Tinos-Italic.ttf';
  static const String _tinosBoldItalicPath =
      'assets/fonts/Tinos-BoldItalic.ttf';
  static const String _courierPrimeRegularPath =
      'assets/fonts/CourierPrime-Regular.ttf';
  static const String _arimoRegularPath = 'assets/fonts/Arimo-Regular.ttf';

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

    // PDFium may silently substitute declared-but-unembedded fonts instead of
    // emitting a missing-font event. Preload only those declared fallbacks so
    // embedded font subsets still win and large bundled fonts are not repeated.
    final declaredFallbackQueries = extractUnembeddedFontQueries(pdfBytes);
    if (declaredFallbackQueries.isEmpty) return;

    await fontManager.loadMissingFonts(declaredFallbackQueries);
  }

  List<pdfrx.PdfFontQuery> extractFontQueriesForPdfByteCollections(
    Iterable<List<int>> pdfByteCollections,
  ) {
    return _dedupeFontQueries(pdfByteCollections.expand(extractFontQueries));
  }

  List<pdfrx.PdfFontQuery> extractUnembeddedFontQueries(List<int> pdfBytes) {
    final content = String.fromCharCodes(pdfBytes);
    final objects = _parsePdfObjects(content);
    if (objects.isEmpty) return const [];

    final queries = <_DeclaredFallbackFontQuery>[];
    for (final object in objects.values) {
      if (_referencesEmbeddedFontData(object, objects, <int>{})) continue;

      for (final face in _extractDeclaredFontFaces(object)) {
        final query = _queryForFace(face);
        final asset = _chooseFont(query);
        if (asset == null) continue;
        queries.add(_DeclaredFallbackFontQuery(query, asset.path));
      }
    }

    return _dedupeFontQueriesByAssetPath(queries);
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
    if (data.length <= _maxCachedFontBytes) {
      _fontDataCache[assetPath] = data;
    }
    return data;
  }

  Future<void> clearLoadedPdfiumFonts() {
    return pdfrx.PdfrxEntryFunctions.instance.clearAllFontData();
  }

  _BundledFontAsset? _chooseFont(pdfrx.PdfFontQuery query) {
    final face = _normalizeFace(query.face);
    if (_isPrintedKaiFallbackFont(face)) {
      return const _BundledFontAsset(_serifPath, 'Noto Serif SC');
    }

    if (_containsAny(face, const ['kaiti', 'stkaiti', 'simkai', 'kai', '楷'])) {
      return const _BundledFontAsset(_kaiPath, 'LXGW ZhenKai GB');
    }

    if (_isCourierFallbackFont(face)) {
      return const _BundledFontAsset(_courierPrimeRegularPath, 'Courier Prime');
    }

    if (_isArialFallbackFont(face)) {
      return const _BundledFontAsset(_arimoRegularPath, 'Arimo');
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

    if (_isTimesFallbackFont(query, face)) {
      return _chooseTinosFont(query);
    }

    return const _BundledFontAsset(_sansPath, 'Source Han Sans SC Light');
  }

  List<pdfrx.PdfFontQuery> extractFontQueries(List<int> pdfBytes) {
    final content = String.fromCharCodes(pdfBytes);
    final matches = RegExp(
      r'/(?:BaseFont|FontName)\s*/([^\s<>\[\]\(\)/%]+)',
    ).allMatches(content);

    final queries = <pdfrx.PdfFontQuery>[];
    for (final match in matches) {
      final face = _decodePdfName(match.group(1)!);
      if (_chooseFont(_queryForFace(face)) == null) continue;

      final query = _queryForFace(face);
      queries.add(query);
    }
    return _dedupeFontQueries(queries);
  }

  static List<pdfrx.PdfFontQuery> _dedupeFontQueries(
    Iterable<pdfrx.PdfFontQuery> queries,
  ) {
    final deduped = <pdfrx.PdfFontQuery>[];
    final seen = <String>{};
    for (final query in queries) {
      if (seen.add(_fontQueryKey(query))) {
        deduped.add(query);
      }
    }
    return deduped;
  }

  static String _fontQueryKey(pdfrx.PdfFontQuery query) {
    return '${query.face}\x1f${query.weight}\x1f${query.isItalic}\x1f${query.charset}';
  }

  static List<pdfrx.PdfFontQuery> _dedupeFontQueriesByAssetPath(
    Iterable<_DeclaredFallbackFontQuery> queries,
  ) {
    final deduped = <pdfrx.PdfFontQuery>[];
    final seenAssetPaths = <String>{};
    for (final query in queries) {
      if (seenAssetPaths.add(query.assetPath)) {
        deduped.add(query.fontQuery);
      }
    }
    return deduped;
  }

  static Map<int, String> _parsePdfObjects(String content) {
    final objects = <int, String>{};
    final objectMatches = RegExp(
      r'(\d+)\s+\d+\s+obj\b(.*?)\bendobj',
      dotAll: true,
    ).allMatches(content);
    for (final match in objectMatches) {
      objects[int.parse(match.group(1)!)] = match.group(2)!;
    }
    return objects;
  }

  static Iterable<String> _extractDeclaredFontFaces(String objectBody) {
    return RegExp(
      r'/(?:BaseFont|FontName)\s*/([^\s<>\[\]\(\)/%]+)',
    ).allMatches(objectBody).map((match) {
      return _decodePdfName(match.group(1)!);
    });
  }

  static bool _referencesEmbeddedFontData(
    String objectBody,
    Map<int, String> objects,
    Set<int> visited,
  ) {
    if (RegExp(r'/FontFile[23]?\b').hasMatch(objectBody)) return true;

    for (final objectId in _referencedFontObjectIds(objectBody)) {
      if (!visited.add(objectId)) continue;
      final referencedObject = objects[objectId];
      if (referencedObject == null) continue;
      if (_referencesEmbeddedFontData(referencedObject, objects, visited)) {
        return true;
      }
    }

    return false;
  }

  static Iterable<int> _referencedFontObjectIds(String objectBody) sync* {
    for (final match in RegExp(
      r'/FontDescriptor\s+(\d+)\s+\d+\s+R',
    ).allMatches(objectBody)) {
      yield int.parse(match.group(1)!);
    }

    for (final match in RegExp(
      r'/DescendantFonts\s*\[(.*?)\]',
      dotAll: true,
    ).allMatches(objectBody)) {
      final descendantFonts = match.group(1)!;
      for (final ref in RegExp(
        r'(\d+)\s+\d+\s+R',
      ).allMatches(descendantFonts)) {
        yield int.parse(ref.group(1)!);
      }
    }
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

  static bool _isTimesFallbackFont(pdfrx.PdfFontQuery query, String face) {
    return _isAmountFont(face) || _isLatinFont(query, face);
  }

  static bool _isPrintedKaiFallbackFont(String face) {
    return face == 'stkaiti' || face.contains('stkaitiregular');
  }

  static bool _isCourierFallbackFont(String face) {
    return _containsAny(face, const [
      'courier',
      'taxpayer',
      'taxid',
      'taxno',
      'taxcode',
      'creditcode',
      'socialcredit',
      'identificationnumber',
    ]);
  }

  static bool _isArialFallbackFont(String face) {
    if (face.contains('unicode')) return false;
    return face == 'arial' ||
        face == 'arialmt' ||
        face == 'arialregular' ||
        face.startsWith('arialbold') ||
        face.startsWith('arialitalic') ||
        face.startsWith('arialnarrow');
  }

  static bool _isAmountFont(String face) {
    return _containsAny(face, const [
      'amount',
      'money',
      'currency',
      'total',
      'subtotal',
      'rmb',
      'cny',
      'price',
      'taxamount',
      'netamount',
      'jine',
      'heji',
      '金额',
      '合计',
      '价税',
      '小写',
      '大写',
    ]);
  }

  static bool _isLatinFont(pdfrx.PdfFontQuery query, String face) {
    return query.charset == pdfrx.PdfFontCharset.ansi ||
        _containsAny(face, const [
          'times',
          'roman',
          'helvetica',
          'calibri',
          'cambria',
          'verdana',
          'tahoma',
          'latin',
          'english',
          'psmt',
        ]);
  }

  static _BundledFontAsset _chooseTinosFont(pdfrx.PdfFontQuery query) {
    final isBold = query.weight >= 600;
    if (isBold && query.isItalic) {
      return const _BundledFontAsset(_tinosBoldItalicPath, 'Tinos');
    }
    if (isBold) {
      return const _BundledFontAsset(_tinosBoldPath, 'Tinos');
    }
    if (query.isItalic) {
      return const _BundledFontAsset(_tinosItalicPath, 'Tinos');
    }
    return const _BundledFontAsset(_tinosRegularPath, 'Tinos');
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

class _DeclaredFallbackFontQuery {
  const _DeclaredFallbackFontQuery(this.fontQuery, this.assetPath);

  final pdfrx.PdfFontQuery fontQuery;
  final String assetPath;
}

import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// PDF中文字体加载服务
/// 提供统一的TrueType字体加载和缓存机制
class PdfFontService {
  // 单例模式
  static final PdfFontService _instance = PdfFontService._internal();
  static PdfFontService get instance => _instance;
  PdfFontService._internal();

  // 字体数据缓存
  Uint8List? _fontData;
  bool _isLoading = false;
  bool _isLoaded = false;

  // 字体路径
  static const String _fontPath = 'assets/fonts/MiSans-Medium.ttf';

  /// 加载字体数据
  /// 首次调用时从assets加载，后续调用使用缓存
  Future<Uint8List> loadFontData() async {
    if (_isLoaded && _fontData != null) {
      return _fontData!;
    }

    if (_isLoading) {
      // 等待加载完成
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      return _fontData!;
    }

    _isLoading = true;
    try {
      final byteData = await rootBundle.load(_fontPath);
      // Convert ByteData to Uint8List
      _fontData = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
      _isLoaded = true;
      return _fontData!;
    } finally {
      _isLoading = false;
    }
  }

  /// 获取中文字体
  /// @param size 字体大小
  /// @return PdfTrueTypeFont 字体对象
  Future<PdfTrueTypeFont> getChineseFont(double size) async {
    final fontData = await loadFontData();
    return PdfTrueTypeFont(fontData, size);
  }

  /// 检查字体是否已加载
  bool isFontLoaded() => _isLoaded;

  /// 清除缓存（用于测试或重新加载）
  void clearCache() {
    _fontData = null;
    _isLoaded = false;
  }
}
import 'dart:io';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../core/services/log_service.dart';
import '../../core/services/log_config.dart';

/// PDF service for extracting text from PDF files
class PdfService {
  /// Extract text content from a PDF file
  /// Returns the extracted text, or empty string if extraction fails
  Future<String> extractTextFromPdf(String pdfPath) async {
    try {
      final file = File(pdfPath);
      if (!await file.exists()) {
        logService.w(LogConfig.moduleFile, 'PDF 文件不存在: $pdfPath');
        return '';
      }

      final bytes = await file.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);

      final textExtractor = PdfTextExtractor(document);
      final text = textExtractor.extractText();

      document.dispose();

      logService.i(LogConfig.moduleFile, '从 PDF 提取了 ${text.length} 个字符');
      return text;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleFile, '从 PDF 提取文本失败', e, stackTrace);
      return '';
    }
  }

  /// Check if a PDF is text-based (contains extractable text)
  /// Returns true if text content exceeds the minimum threshold
  Future<bool> isTextBasedPdf(String pdfPath, {int minTextLength = 50}) async {
    try {
      final text = await extractTextFromPdf(pdfPath);
      // Clean up whitespace and check length
      final cleanText = text.replaceAll(RegExp(r'\s+'), ' ').trim();
      return cleanText.length >= minTextLength;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleFile, '检查 PDF 类型失败', e, stackTrace);
      return false;
    }
  }

  /// Get PDF page count
  Future<int> getPageCount(String pdfPath) async {
    try {
      final file = File(pdfPath);
      if (!await file.exists()) {
        return 0;
      }

      final bytes = await file.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      final count = document.pages.count;
      document.dispose();

      return count;
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleFile, '获取 PDF 页数失败', e, stackTrace);
      return 0;
    }
  }
}
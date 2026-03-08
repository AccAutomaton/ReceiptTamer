import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// PDF service for extracting text from PDF files
class PdfService {
  /// Extract text content from a PDF file
  /// Returns the extracted text, or empty string if extraction fails
  Future<String> extractTextFromPdf(String pdfPath) async {
    try {
      final file = File(pdfPath);
      if (!await file.exists()) {
        debugPrint('PDF file not found: $pdfPath');
        return '';
      }

      final bytes = await file.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);

      final textExtractor = PdfTextExtractor(document);
      final text = textExtractor.extractText();

      document.dispose();

      debugPrint('Extracted ${text.length} characters from PDF');
      return text;
    } catch (e) {
      debugPrint('Error extracting text from PDF: $e');
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
    } catch (e) {
      debugPrint('Error checking PDF type: $e');
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
    } catch (e) {
      debugPrint('Error getting PDF page count: $e');
      return 0;
    }
  }
}
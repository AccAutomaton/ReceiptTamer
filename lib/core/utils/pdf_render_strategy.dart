/// Chooses the PDF rendering path for preview/export.
class PdfRenderStrategy {
  PdfRenderStrategy._();

  static final RegExp _stampAnnotationPattern = RegExp(r'/Subtype\s*/Stamp\b');

  /// PDFium/pdfrx is needed when the visual content lives in Stamp
  /// annotations, because Syncfusion page templates can omit them.
  ///
  /// PDFs without Stamp annotations stay on the Syncfusion template path,
  /// which preserves some tax-invoice fonts that PDFium may substitute poorly.
  static bool needsPdfiumRendering(List<int> pdfBytes) {
    final content = String.fromCharCodes(pdfBytes);
    return _stampAnnotationPattern.hasMatch(content);
  }
}

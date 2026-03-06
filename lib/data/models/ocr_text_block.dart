import 'package:freezed_annotation/freezed_annotation.dart';

part 'ocr_text_block.freezed.dart';
part 'ocr_text_block.g.dart';

/// Point coordinate for text bounding box
@freezed
abstract class OcrPoint with _$OcrPoint {
  const factory OcrPoint({
    required int x,
    required int y,
  }) = _OcrPoint;

  factory OcrPoint.fromJson(Map<String, dynamic> json) =>
      _$OcrPointFromJson(json);
}

/// OCR text block with bounding box and confidence
///
/// Represents a single detected text region from OCR processing.
/// Contains the recognized text, bounding box coordinates (4 corners),
/// and confidence score.
@freezed
abstract class OcrTextBlock with _$OcrTextBlock {
  const factory OcrTextBlock({
    /// Recognized text content
    required String text,

    /// Bounding box as 4 corner points (top-left, top-right, bottom-right, bottom-left)
    required List<OcrPoint> boundingBox,

    /// Confidence score (0.0 to 1.0)
    required double confidence,
  }) = _OcrTextBlock;

  factory OcrTextBlock.fromJson(Map<String, dynamic> json) =>
      _$OcrTextBlockFromJson(json);
}

/// OCR raw result containing all detected text blocks
@freezed
abstract class OcrRawResult with _$OcrRawResult {
  const factory OcrRawResult({
    /// Whether OCR was successful
    required bool success,

    /// List of detected text blocks
    required List<OcrTextBlock> textBlocks,

    /// Error message if failed
    String? errorMessage,

    /// Processing time in milliseconds
    int? processingTimeMs,
  }) = _OcrRawResult;

  factory OcrRawResult.fromJson(Map<String, dynamic> json) =>
      _$OcrRawResultFromJson(json);
}

/// Extension for OcrTextBlock helper methods
extension OcrTextBlockX on OcrTextBlock {
  /// Get combined text from all blocks
  String get combinedText => text;

  /// Check if this block contains numeric content
  bool get hasNumericContent => RegExp(r'\d').hasMatch(text);

  /// Check if this block looks like a price (contains currency symbol or ends with decimal)
  bool get isPriceLike =>
      text.contains(RegExp(r'[¥￥$]')) ||
      RegExp(r'\d+\.\d{2}$').hasMatch(text);

  /// Check if this block looks like a date
  bool get isDateLike =>
      RegExp(r'\d{4}[-/年]\d{1,2}[-/月]\d{1,2}').hasMatch(text) ||
      RegExp(r'\d{1,2}[-/]\d{1,2}[-/]\d{4}').hasMatch(text);

  /// Check if this block looks like a time
  bool get isTimeLike => RegExp(r'\d{1,2}:\d{2}').hasMatch(text);

  /// Check if this block looks like an order number (long digit sequence)
  bool get isOrderNumberLike => RegExp(r'\d{15,}').hasMatch(text);

  /// Get approximate width of bounding box
  int get width {
    if (boundingBox.length < 4) return 0;
    final xs = boundingBox.map((p) => p.x);
    return xs.reduce((a, b) => a > b ? a : b) - xs.reduce((a, b) => a < b ? a : b);
  }

  /// Get approximate height of bounding box
  int get height {
    if (boundingBox.length < 4) return 0;
    final ys = boundingBox.map((p) => p.y);
    return ys.reduce((a, b) => a > b ? a : b) - ys.reduce((a, b) => a < b ? a : b);
  }
}

/// Extension for OcrRawResult helper methods
extension OcrRawResultX on OcrRawResult {
  /// Get all text combined with newlines
  String get fullText => textBlocks.map((b) => b.text).join('\n');

  /// Get all text combined with spaces (for LLM input)
  String get fullTextSingleLine => textBlocks.map((b) => b.text).join(' ');

  /// Get text blocks sorted by position (top to bottom, left to right)
  List<OcrTextBlock> get sortedBlocks {
    final sorted = List<OcrTextBlock>.from(textBlocks);
    sorted.sort((a, b) {
      // Sort by y first (top to bottom), then by x (left to right)
      final aTop = a.boundingBox.isNotEmpty ? a.boundingBox.first.y : 0;
      final bTop = b.boundingBox.isNotEmpty ? b.boundingBox.first.y : 0;
      final yDiff = aTop - bTop;
      if (yDiff.abs() > 20) return yDiff; // Consider same line within 20px
      final aLeft = a.boundingBox.isNotEmpty ? a.boundingBox.first.x : 0;
      final bLeft = b.boundingBox.isNotEmpty ? b.boundingBox.first.x : 0;
      return aLeft - bLeft;
    });
    return sorted;
  }

  /// Get text from sorted blocks
  String get sortedText => sortedBlocks.map((b) => b.text).join('\n');
}

/// Helper methods for creating OcrRawResult
extension OcrRawResultFactory on OcrRawResult {
  /// Create a successful OCR result
  static OcrRawResult success({
    required List<OcrTextBlock> textBlocks,
    int? processingTimeMs,
  }) {
    return OcrRawResult(
      success: true,
      textBlocks: textBlocks,
      processingTimeMs: processingTimeMs,
    );
  }

  /// Create a failed OCR result
  static OcrRawResult failure({required String errorMessage}) {
    return OcrRawResult(
      success: false,
      textBlocks: [],
      errorMessage: errorMessage,
    );
  }
}
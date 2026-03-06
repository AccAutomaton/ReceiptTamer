import 'package:freezed_annotation/freezed_annotation.dart';

part 'ocr_result.freezed.dart';

/// OCR result data types
enum OcrType {
  order,
  invoice,
}

/// OCR recognition result model
@freezed
abstract class OcrResult with _$OcrResult {
  const factory OcrResult({
    required bool success,
    required OcrType type,
    String? errorMessage,

    // Order-specific fields
    String? shopName,
    double? amount,
    String? orderTime,
    String? orderNumber,

    // Invoice-specific fields
    String? invoiceNumber,
    String? invoiceDate,
    double? totalAmount,
  }) = _OcrResult;

  /// Create a successful order OCR result
  factory OcrResult.orderSuccess({
    required String shopName,
    required double amount,
    String? orderTime,
    String? orderNumber,
  }) {
    return OcrResult(
      success: true,
      type: OcrType.order,
      shopName: shopName,
      amount: amount,
      orderTime: orderTime,
      orderNumber: orderNumber,
    );
  }

  /// Create a successful invoice OCR result
  factory OcrResult.invoiceSuccess({
    required String invoiceNumber,
    required String invoiceDate,
    required double totalAmount,
  }) {
    return OcrResult(
      success: true,
      type: OcrType.invoice,
      invoiceNumber: invoiceNumber,
      invoiceDate: invoiceDate,
      totalAmount: totalAmount,
    );
  }

  /// Create a failed OCR result
  factory OcrResult.failure({
    required String errorMessage,
    required OcrType type,
  }) {
    return OcrResult(
      success: false,
      type: type,
      errorMessage: errorMessage,
    );
  }

  const OcrResult._();
}

/// Extension for OcrResult helper methods
extension OcrResultX on OcrResult {
  /// Check if result contains order data
  bool get hasOrderData => type == OcrType.order && success;

  /// Check if result contains invoice data
  bool get hasInvoiceData => type == OcrType.invoice && success;

  /// Get formatted error message
  String get formattedError => errorMessage ?? 'OCR识别失败';
}

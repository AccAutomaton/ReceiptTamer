import 'dart:convert';

import '../models/ocr_result.dart';

class LlmPromptBuilder {
  const LlmPromptBuilder._();

  static String buildTextPrompt(OcrType type, String text) {
    return switch (type) {
      OcrType.order => _buildOrderTextPrompt(text),
      OcrType.invoice => _buildInvoiceTextPrompt(text),
    };
  }

  static String buildImagePrompt(OcrType type) {
    return switch (type) {
      OcrType.order => '''
Read the receipt/order image and extract fields. Return one compact JSON object only:
{"shopName":"","amount":"","orderTime":"","orderNumber":""}

Rules:
- shopName: merchant or restaurant name, not courier/customer/address names.
- amount: actual paid amount.
- orderTime: order time in yyyy-MM-dd HH:mm:ss when visible.
- orderNumber: order id only, remove spaces and symbols.
''',
      OcrType.invoice => '''
Read the invoice image and extract fields. Return one compact JSON object only:
{"invoiceNumber":"","invoiceDate":"","totalAmount":"","sellerName":""}

Rules:
- invoiceNumber: invoice number only.
- invoiceDate: yyyy-MM-dd when visible.
- totalAmount: tax-included total.
- sellerName: seller company name, not buyer company name.
''',
    };
  }

  static String _buildOrderTextPrompt(String text) {
    return '''
Extract receipt/order fields from OCR text. Return one compact JSON object only:
{"shopName":"","amount":"","orderTime":"","orderNumber":""}

Rules:
- shopName: merchant or restaurant name, not courier/customer/address names.
- amount: actual paid amount, usually after "实付".
- orderTime: order time in yyyy-MM-dd HH:mm:ss, remove milliseconds.
- orderNumber: order id only, remove spaces, pipes, and copy suffixes.

OCR text:
$text
''';
  }

  static String _buildInvoiceTextPrompt(String text) {
    return '''
Extract invoice fields from OCR text. Return one compact JSON object only:
{"invoiceNumber":"","invoiceDate":"","totalAmount":"","sellerName":""}

Rules:
- invoiceNumber: invoice number only.
- invoiceDate: yyyy-MM-dd.
- totalAmount: tax-included total, often near "小写" or "价税合计".
- sellerName: seller company name, usually below seller information, not buyer information.

OCR text:
$text
''';
  }
}

class LlmResultParser {
  const LlmResultParser._();

  static OcrResult parse(String rawText, OcrType type) {
    try {
      final jsonText = _extractJson(rawText);
      final json = Map<String, dynamic>.from(jsonDecode(jsonText) as Map);
      if (json['error'] != null) {
        return OcrResult.failure(
          errorMessage: json['error'].toString(),
          type: type,
        );
      }

      if (type == OcrType.order) {
        return OcrResult.orderSuccess(
          shopName: json['shopName'] as String? ?? '',
          amount: _parseAmount(json['amount']),
          orderTime: json['orderTime'] as String?,
          orderNumber: _cleanNumber(json['orderNumber'] as String? ?? ''),
        );
      }

      return OcrResult.invoiceSuccess(
        invoiceNumber: _cleanNumber(json['invoiceNumber'] as String? ?? ''),
        invoiceDate: json['invoiceDate'] as String? ?? '',
        totalAmount: _parseAmount(json['totalAmount']),
        sellerName: json['sellerName'] as String? ?? '',
      );
    } catch (e) {
      return OcrResult.failure(
        errorMessage: '解析 LLM 结果失败: $e',
        type: type,
      );
    }
  }

  static String _extractJson(String rawText) {
    final withoutFence = rawText
        .replaceAll(RegExp(r'```json\s*', caseSensitive: false), '')
        .replaceAll('```', '');
    final start = withoutFence.indexOf('{');
    if (start < 0) {
      throw const FormatException('response does not contain JSON object');
    }

    var depth = 0;
    var inString = false;
    for (var i = start; i < withoutFence.length; i++) {
      final char = withoutFence[i];
      final escaped = i > 0 && withoutFence[i - 1] == '\\';
      if (char == '"' && !escaped) {
        inString = !inString;
      }
      if (inString) continue;
      if (char == '{') depth++;
      if (char == '}') {
        depth--;
        if (depth == 0) {
          return withoutFence.substring(start, i + 1);
        }
      }
    }
    throw const FormatException('response JSON object is incomplete');
  }

  static String _cleanNumber(String value) {
    if (value.isEmpty) return '';
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
  }

  static double _parseAmount(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^\d.\-]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }
}

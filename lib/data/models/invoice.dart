import 'package:freezed_annotation/freezed_annotation.dart';

part 'invoice.freezed.dart';
part 'invoice.g.dart';

/// Invoice data model
/// Represents an invoice/fapiao that can be linked to an order
@freezed
abstract class Invoice with _$Invoice {
  const factory Invoice({
    @JsonKey(includeIfNull: false) int? id,
    @Default('') String imagePath,
    @JsonKey(includeIfNull: false) int? orderId,
    @Default('') String invoiceNumber,
    @JsonKey(includeIfNull: false) String? invoiceDate,
    @Default(0.0) double totalAmount,
    @Default('') String createdAt,
    @Default('') String updatedAt,
  }) = _Invoice;

  factory Invoice.fromJson(Map<String, dynamic> json) => _$InvoiceFromJson(json);

  /// Create a new invoice with default timestamps
  factory Invoice.create({
    String imagePath = '',
    int? orderId,
    String invoiceNumber = '',
    String? invoiceDate,
    double totalAmount = 0.0,
  }) {
    final now = DateTime.now();
    return Invoice(
      imagePath: imagePath,
      orderId: orderId,
      invoiceNumber: invoiceNumber,
      invoiceDate: invoiceDate,
      totalAmount: totalAmount,
      createdAt: now.toIso8601String(),
      updatedAt: now.toIso8601String(),
    );
  }
}

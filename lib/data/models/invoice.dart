import 'package:freezed_annotation/freezed_annotation.dart';

part 'invoice.freezed.dart';
part 'invoice.g.dart';

/// Invoice data model
/// Represents an invoice/fapiao that can be linked to an order
@freezed
abstract class Invoice with _$Invoice {
  const factory Invoice({
    @JsonKey(includeIfNull: false) int? id,
    @JsonKey(name: 'image_path') @Default('') String imagePath,
    @JsonKey(name: 'order_id', includeIfNull: false) int? orderId,
    @JsonKey(name: 'invoice_number') @Default('') String invoiceNumber,
    @JsonKey(name: 'invoice_date', includeIfNull: false) String? invoiceDate,
    @JsonKey(name: 'total_amount') @Default(0.0) double totalAmount,
    @JsonKey(name: 'created_at') @Default('') String createdAt,
    @JsonKey(name: 'updated_at') @Default('') String updatedAt,
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

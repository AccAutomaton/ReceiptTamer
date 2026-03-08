import 'package:freezed_annotation/freezed_annotation.dart';

part 'invoice_order_relation.freezed.dart';
part 'invoice_order_relation.g.dart';

/// Invoice-Order relation model
/// Represents a many-to-many relationship between invoices and orders
@freezed
abstract class InvoiceOrderRelation with _$InvoiceOrderRelation {
  const factory InvoiceOrderRelation({
    @JsonKey(name: 'invoice_id') required int invoiceId,
    @JsonKey(name: 'order_id') required int orderId,
  }) = _InvoiceOrderRelation;

  factory InvoiceOrderRelation.fromJson(Map<String, dynamic> json) =>
      _$InvoiceOrderRelationFromJson(json);
}
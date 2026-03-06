import 'package:freezed_annotation/freezed_annotation.dart';

part 'order.freezed.dart';
part 'order.g.dart';

/// Order data model
/// Represents a catering delivery order with receipt information
@freezed
abstract class Order with _$Order {
  const factory Order({
    @JsonKey(includeIfNull: false) int? id,
    @Default('') String imagePath,
    @Default('') String shopName,
    @Default(0.0) double amount,
    @JsonKey(includeIfNull: false) String? orderTime,
    @Default('') String orderNumber,
    @Default('') String createdAt,
    @Default('') String updatedAt,
  }) = _Order;

  factory Order.fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);

  /// Create a new order with default timestamps
  factory Order.create({
    String imagePath = '',
    String shopName = '',
    double amount = 0.0,
    String? orderTime,
    String orderNumber = '',
  }) {
    final now = DateTime.now();
    return Order(
      imagePath: imagePath,
      shopName: shopName,
      amount: amount,
      orderTime: orderTime,
      orderNumber: orderNumber,
      createdAt: now.toIso8601String(),
      updatedAt: now.toIso8601String(),
    );
  }
}

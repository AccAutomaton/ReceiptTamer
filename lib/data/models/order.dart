import 'package:freezed_annotation/freezed_annotation.dart';

part 'order.freezed.dart';
part 'order.g.dart';

/// Order data model
/// Represents a catering delivery order with receipt information
@freezed
abstract class Order with _$Order {
  const factory Order({
    @JsonKey(includeIfNull: false) int? id,
    @JsonKey(name: 'image_path') @Default('') String imagePath,
    @JsonKey(name: 'shop_name') @Default('') String shopName,
    @Default(0.0) double amount,
    @JsonKey(name: 'order_date', includeIfNull: false) String? orderDate,
    @JsonKey(name: 'meal_time', includeIfNull: false) String? mealTime,
    @JsonKey(name: 'order_number') @Default('') String orderNumber,
    @JsonKey(name: 'created_at') @Default('') String createdAt,
    @JsonKey(name: 'updated_at') @Default('') String updatedAt,
    // UI-only field, not stored in database
    // Used to display invoice relation status in order list
    @JsonKey(includeFromJson: false, includeToJson: false) @Default(false) bool hasInvoice,
  }) = _Order;

  factory Order.fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);

  /// Create a new order with default timestamps
  factory Order.create({
    String imagePath = '',
    String shopName = '',
    double amount = 0.0,
    String? orderDate,
    String? mealTime,
    String orderNumber = '',
  }) {
    final now = DateTime.now();
    return Order(
      imagePath: imagePath,
      shopName: shopName,
      amount: amount,
      orderDate: orderDate,
      mealTime: mealTime,
      orderNumber: orderNumber,
      createdAt: now.toIso8601String(),
      updatedAt: now.toIso8601String(),
    );
  }
}

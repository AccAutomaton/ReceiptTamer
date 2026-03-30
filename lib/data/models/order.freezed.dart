// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'order.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Order {

@JsonKey(includeIfNull: false) int? get id;@JsonKey(name: 'image_path') String get imagePath;@JsonKey(name: 'shop_name') String get shopName; double get amount;@JsonKey(name: 'order_date', includeIfNull: false) String? get orderDate;@JsonKey(name: 'meal_time', includeIfNull: false) String? get mealTime;@JsonKey(name: 'order_number') String get orderNumber;@JsonKey(name: 'created_at') String get createdAt;@JsonKey(name: 'updated_at') String get updatedAt;// UI-only field, not stored in database
// Used to display invoice relation status in order list
@JsonKey(includeFromJson: false, includeToJson: false) bool get hasInvoice;
/// Create a copy of Order
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrderCopyWith<Order> get copyWith => _$OrderCopyWithImpl<Order>(this as Order, _$identity);

  /// Serializes this Order to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Order&&(identical(other.id, id) || other.id == id)&&(identical(other.imagePath, imagePath) || other.imagePath == imagePath)&&(identical(other.shopName, shopName) || other.shopName == shopName)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.orderDate, orderDate) || other.orderDate == orderDate)&&(identical(other.mealTime, mealTime) || other.mealTime == mealTime)&&(identical(other.orderNumber, orderNumber) || other.orderNumber == orderNumber)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.hasInvoice, hasInvoice) || other.hasInvoice == hasInvoice));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,imagePath,shopName,amount,orderDate,mealTime,orderNumber,createdAt,updatedAt,hasInvoice);

@override
String toString() {
  return 'Order(id: $id, imagePath: $imagePath, shopName: $shopName, amount: $amount, orderDate: $orderDate, mealTime: $mealTime, orderNumber: $orderNumber, createdAt: $createdAt, updatedAt: $updatedAt, hasInvoice: $hasInvoice)';
}


}

/// @nodoc
abstract mixin class $OrderCopyWith<$Res>  {
  factory $OrderCopyWith(Order value, $Res Function(Order) _then) = _$OrderCopyWithImpl;
@useResult
$Res call({
@JsonKey(includeIfNull: false) int? id,@JsonKey(name: 'image_path') String imagePath,@JsonKey(name: 'shop_name') String shopName, double amount,@JsonKey(name: 'order_date', includeIfNull: false) String? orderDate,@JsonKey(name: 'meal_time', includeIfNull: false) String? mealTime,@JsonKey(name: 'order_number') String orderNumber,@JsonKey(name: 'created_at') String createdAt,@JsonKey(name: 'updated_at') String updatedAt,@JsonKey(includeFromJson: false, includeToJson: false) bool hasInvoice
});




}
/// @nodoc
class _$OrderCopyWithImpl<$Res>
    implements $OrderCopyWith<$Res> {
  _$OrderCopyWithImpl(this._self, this._then);

  final Order _self;
  final $Res Function(Order) _then;

/// Create a copy of Order
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? imagePath = null,Object? shopName = null,Object? amount = null,Object? orderDate = freezed,Object? mealTime = freezed,Object? orderNumber = null,Object? createdAt = null,Object? updatedAt = null,Object? hasInvoice = null,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,imagePath: null == imagePath ? _self.imagePath : imagePath // ignore: cast_nullable_to_non_nullable
as String,shopName: null == shopName ? _self.shopName : shopName // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,orderDate: freezed == orderDate ? _self.orderDate : orderDate // ignore: cast_nullable_to_non_nullable
as String?,mealTime: freezed == mealTime ? _self.mealTime : mealTime // ignore: cast_nullable_to_non_nullable
as String?,orderNumber: null == orderNumber ? _self.orderNumber : orderNumber // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String,hasInvoice: null == hasInvoice ? _self.hasInvoice : hasInvoice // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Order].
extension OrderPatterns on Order {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Order value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Order() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Order value)  $default,){
final _that = this;
switch (_that) {
case _Order():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Order value)?  $default,){
final _that = this;
switch (_that) {
case _Order() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(includeIfNull: false)  int? id, @JsonKey(name: 'image_path')  String imagePath, @JsonKey(name: 'shop_name')  String shopName,  double amount, @JsonKey(name: 'order_date', includeIfNull: false)  String? orderDate, @JsonKey(name: 'meal_time', includeIfNull: false)  String? mealTime, @JsonKey(name: 'order_number')  String orderNumber, @JsonKey(name: 'created_at')  String createdAt, @JsonKey(name: 'updated_at')  String updatedAt, @JsonKey(includeFromJson: false, includeToJson: false)  bool hasInvoice)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Order() when $default != null:
return $default(_that.id,_that.imagePath,_that.shopName,_that.amount,_that.orderDate,_that.mealTime,_that.orderNumber,_that.createdAt,_that.updatedAt,_that.hasInvoice);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(includeIfNull: false)  int? id, @JsonKey(name: 'image_path')  String imagePath, @JsonKey(name: 'shop_name')  String shopName,  double amount, @JsonKey(name: 'order_date', includeIfNull: false)  String? orderDate, @JsonKey(name: 'meal_time', includeIfNull: false)  String? mealTime, @JsonKey(name: 'order_number')  String orderNumber, @JsonKey(name: 'created_at')  String createdAt, @JsonKey(name: 'updated_at')  String updatedAt, @JsonKey(includeFromJson: false, includeToJson: false)  bool hasInvoice)  $default,) {final _that = this;
switch (_that) {
case _Order():
return $default(_that.id,_that.imagePath,_that.shopName,_that.amount,_that.orderDate,_that.mealTime,_that.orderNumber,_that.createdAt,_that.updatedAt,_that.hasInvoice);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(includeIfNull: false)  int? id, @JsonKey(name: 'image_path')  String imagePath, @JsonKey(name: 'shop_name')  String shopName,  double amount, @JsonKey(name: 'order_date', includeIfNull: false)  String? orderDate, @JsonKey(name: 'meal_time', includeIfNull: false)  String? mealTime, @JsonKey(name: 'order_number')  String orderNumber, @JsonKey(name: 'created_at')  String createdAt, @JsonKey(name: 'updated_at')  String updatedAt, @JsonKey(includeFromJson: false, includeToJson: false)  bool hasInvoice)?  $default,) {final _that = this;
switch (_that) {
case _Order() when $default != null:
return $default(_that.id,_that.imagePath,_that.shopName,_that.amount,_that.orderDate,_that.mealTime,_that.orderNumber,_that.createdAt,_that.updatedAt,_that.hasInvoice);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Order implements Order {
  const _Order({@JsonKey(includeIfNull: false) this.id, @JsonKey(name: 'image_path') this.imagePath = '', @JsonKey(name: 'shop_name') this.shopName = '', this.amount = 0.0, @JsonKey(name: 'order_date', includeIfNull: false) this.orderDate, @JsonKey(name: 'meal_time', includeIfNull: false) this.mealTime, @JsonKey(name: 'order_number') this.orderNumber = '', @JsonKey(name: 'created_at') this.createdAt = '', @JsonKey(name: 'updated_at') this.updatedAt = '', @JsonKey(includeFromJson: false, includeToJson: false) this.hasInvoice = false});
  factory _Order.fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);

@override@JsonKey(includeIfNull: false) final  int? id;
@override@JsonKey(name: 'image_path') final  String imagePath;
@override@JsonKey(name: 'shop_name') final  String shopName;
@override@JsonKey() final  double amount;
@override@JsonKey(name: 'order_date', includeIfNull: false) final  String? orderDate;
@override@JsonKey(name: 'meal_time', includeIfNull: false) final  String? mealTime;
@override@JsonKey(name: 'order_number') final  String orderNumber;
@override@JsonKey(name: 'created_at') final  String createdAt;
@override@JsonKey(name: 'updated_at') final  String updatedAt;
// UI-only field, not stored in database
// Used to display invoice relation status in order list
@override@JsonKey(includeFromJson: false, includeToJson: false) final  bool hasInvoice;

/// Create a copy of Order
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrderCopyWith<_Order> get copyWith => __$OrderCopyWithImpl<_Order>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrderToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Order&&(identical(other.id, id) || other.id == id)&&(identical(other.imagePath, imagePath) || other.imagePath == imagePath)&&(identical(other.shopName, shopName) || other.shopName == shopName)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.orderDate, orderDate) || other.orderDate == orderDate)&&(identical(other.mealTime, mealTime) || other.mealTime == mealTime)&&(identical(other.orderNumber, orderNumber) || other.orderNumber == orderNumber)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.hasInvoice, hasInvoice) || other.hasInvoice == hasInvoice));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,imagePath,shopName,amount,orderDate,mealTime,orderNumber,createdAt,updatedAt,hasInvoice);

@override
String toString() {
  return 'Order(id: $id, imagePath: $imagePath, shopName: $shopName, amount: $amount, orderDate: $orderDate, mealTime: $mealTime, orderNumber: $orderNumber, createdAt: $createdAt, updatedAt: $updatedAt, hasInvoice: $hasInvoice)';
}


}

/// @nodoc
abstract mixin class _$OrderCopyWith<$Res> implements $OrderCopyWith<$Res> {
  factory _$OrderCopyWith(_Order value, $Res Function(_Order) _then) = __$OrderCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(includeIfNull: false) int? id,@JsonKey(name: 'image_path') String imagePath,@JsonKey(name: 'shop_name') String shopName, double amount,@JsonKey(name: 'order_date', includeIfNull: false) String? orderDate,@JsonKey(name: 'meal_time', includeIfNull: false) String? mealTime,@JsonKey(name: 'order_number') String orderNumber,@JsonKey(name: 'created_at') String createdAt,@JsonKey(name: 'updated_at') String updatedAt,@JsonKey(includeFromJson: false, includeToJson: false) bool hasInvoice
});




}
/// @nodoc
class __$OrderCopyWithImpl<$Res>
    implements _$OrderCopyWith<$Res> {
  __$OrderCopyWithImpl(this._self, this._then);

  final _Order _self;
  final $Res Function(_Order) _then;

/// Create a copy of Order
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? imagePath = null,Object? shopName = null,Object? amount = null,Object? orderDate = freezed,Object? mealTime = freezed,Object? orderNumber = null,Object? createdAt = null,Object? updatedAt = null,Object? hasInvoice = null,}) {
  return _then(_Order(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,imagePath: null == imagePath ? _self.imagePath : imagePath // ignore: cast_nullable_to_non_nullable
as String,shopName: null == shopName ? _self.shopName : shopName // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,orderDate: freezed == orderDate ? _self.orderDate : orderDate // ignore: cast_nullable_to_non_nullable
as String?,mealTime: freezed == mealTime ? _self.mealTime : mealTime // ignore: cast_nullable_to_non_nullable
as String?,orderNumber: null == orderNumber ? _self.orderNumber : orderNumber // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String,hasInvoice: null == hasInvoice ? _self.hasInvoice : hasInvoice // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on

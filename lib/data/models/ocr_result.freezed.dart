// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ocr_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$OcrResult {

 bool get success; OcrType get type; String? get errorMessage;// Order-specific fields
 String? get shopName; double? get amount; String? get orderTime; String? get orderNumber;// Invoice-specific fields
 String? get invoiceNumber; String? get invoiceDate; double? get totalAmount; String? get sellerName;
/// Create a copy of OcrResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OcrResultCopyWith<OcrResult> get copyWith => _$OcrResultCopyWithImpl<OcrResult>(this as OcrResult, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OcrResult&&(identical(other.success, success) || other.success == success)&&(identical(other.type, type) || other.type == type)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.shopName, shopName) || other.shopName == shopName)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.orderTime, orderTime) || other.orderTime == orderTime)&&(identical(other.orderNumber, orderNumber) || other.orderNumber == orderNumber)&&(identical(other.invoiceNumber, invoiceNumber) || other.invoiceNumber == invoiceNumber)&&(identical(other.invoiceDate, invoiceDate) || other.invoiceDate == invoiceDate)&&(identical(other.totalAmount, totalAmount) || other.totalAmount == totalAmount)&&(identical(other.sellerName, sellerName) || other.sellerName == sellerName));
}


@override
int get hashCode => Object.hash(runtimeType,success,type,errorMessage,shopName,amount,orderTime,orderNumber,invoiceNumber,invoiceDate,totalAmount,sellerName);

@override
String toString() {
  return 'OcrResult(success: $success, type: $type, errorMessage: $errorMessage, shopName: $shopName, amount: $amount, orderTime: $orderTime, orderNumber: $orderNumber, invoiceNumber: $invoiceNumber, invoiceDate: $invoiceDate, totalAmount: $totalAmount, sellerName: $sellerName)';
}


}

/// @nodoc
abstract mixin class $OcrResultCopyWith<$Res>  {
  factory $OcrResultCopyWith(OcrResult value, $Res Function(OcrResult) _then) = _$OcrResultCopyWithImpl;
@useResult
$Res call({
 bool success, OcrType type, String? errorMessage, String? shopName, double? amount, String? orderTime, String? orderNumber, String? invoiceNumber, String? invoiceDate, double? totalAmount, String? sellerName
});




}
/// @nodoc
class _$OcrResultCopyWithImpl<$Res>
    implements $OcrResultCopyWith<$Res> {
  _$OcrResultCopyWithImpl(this._self, this._then);

  final OcrResult _self;
  final $Res Function(OcrResult) _then;

/// Create a copy of OcrResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? success = null,Object? type = null,Object? errorMessage = freezed,Object? shopName = freezed,Object? amount = freezed,Object? orderTime = freezed,Object? orderNumber = freezed,Object? invoiceNumber = freezed,Object? invoiceDate = freezed,Object? totalAmount = freezed,Object? sellerName = freezed,}) {
  return _then(_self.copyWith(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as OcrType,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,shopName: freezed == shopName ? _self.shopName : shopName // ignore: cast_nullable_to_non_nullable
as String?,amount: freezed == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double?,orderTime: freezed == orderTime ? _self.orderTime : orderTime // ignore: cast_nullable_to_non_nullable
as String?,orderNumber: freezed == orderNumber ? _self.orderNumber : orderNumber // ignore: cast_nullable_to_non_nullable
as String?,invoiceNumber: freezed == invoiceNumber ? _self.invoiceNumber : invoiceNumber // ignore: cast_nullable_to_non_nullable
as String?,invoiceDate: freezed == invoiceDate ? _self.invoiceDate : invoiceDate // ignore: cast_nullable_to_non_nullable
as String?,totalAmount: freezed == totalAmount ? _self.totalAmount : totalAmount // ignore: cast_nullable_to_non_nullable
as double?,sellerName: freezed == sellerName ? _self.sellerName : sellerName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [OcrResult].
extension OcrResultPatterns on OcrResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OcrResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OcrResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OcrResult value)  $default,){
final _that = this;
switch (_that) {
case _OcrResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OcrResult value)?  $default,){
final _that = this;
switch (_that) {
case _OcrResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool success,  OcrType type,  String? errorMessage,  String? shopName,  double? amount,  String? orderTime,  String? orderNumber,  String? invoiceNumber,  String? invoiceDate,  double? totalAmount,  String? sellerName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OcrResult() when $default != null:
return $default(_that.success,_that.type,_that.errorMessage,_that.shopName,_that.amount,_that.orderTime,_that.orderNumber,_that.invoiceNumber,_that.invoiceDate,_that.totalAmount,_that.sellerName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool success,  OcrType type,  String? errorMessage,  String? shopName,  double? amount,  String? orderTime,  String? orderNumber,  String? invoiceNumber,  String? invoiceDate,  double? totalAmount,  String? sellerName)  $default,) {final _that = this;
switch (_that) {
case _OcrResult():
return $default(_that.success,_that.type,_that.errorMessage,_that.shopName,_that.amount,_that.orderTime,_that.orderNumber,_that.invoiceNumber,_that.invoiceDate,_that.totalAmount,_that.sellerName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool success,  OcrType type,  String? errorMessage,  String? shopName,  double? amount,  String? orderTime,  String? orderNumber,  String? invoiceNumber,  String? invoiceDate,  double? totalAmount,  String? sellerName)?  $default,) {final _that = this;
switch (_that) {
case _OcrResult() when $default != null:
return $default(_that.success,_that.type,_that.errorMessage,_that.shopName,_that.amount,_that.orderTime,_that.orderNumber,_that.invoiceNumber,_that.invoiceDate,_that.totalAmount,_that.sellerName);case _:
  return null;

}
}

}

/// @nodoc


class _OcrResult extends OcrResult {
  const _OcrResult({required this.success, required this.type, this.errorMessage, this.shopName, this.amount, this.orderTime, this.orderNumber, this.invoiceNumber, this.invoiceDate, this.totalAmount, this.sellerName}): super._();
  

@override final  bool success;
@override final  OcrType type;
@override final  String? errorMessage;
// Order-specific fields
@override final  String? shopName;
@override final  double? amount;
@override final  String? orderTime;
@override final  String? orderNumber;
// Invoice-specific fields
@override final  String? invoiceNumber;
@override final  String? invoiceDate;
@override final  double? totalAmount;
@override final  String? sellerName;

/// Create a copy of OcrResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OcrResultCopyWith<_OcrResult> get copyWith => __$OcrResultCopyWithImpl<_OcrResult>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OcrResult&&(identical(other.success, success) || other.success == success)&&(identical(other.type, type) || other.type == type)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.shopName, shopName) || other.shopName == shopName)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.orderTime, orderTime) || other.orderTime == orderTime)&&(identical(other.orderNumber, orderNumber) || other.orderNumber == orderNumber)&&(identical(other.invoiceNumber, invoiceNumber) || other.invoiceNumber == invoiceNumber)&&(identical(other.invoiceDate, invoiceDate) || other.invoiceDate == invoiceDate)&&(identical(other.totalAmount, totalAmount) || other.totalAmount == totalAmount)&&(identical(other.sellerName, sellerName) || other.sellerName == sellerName));
}


@override
int get hashCode => Object.hash(runtimeType,success,type,errorMessage,shopName,amount,orderTime,orderNumber,invoiceNumber,invoiceDate,totalAmount,sellerName);

@override
String toString() {
  return 'OcrResult(success: $success, type: $type, errorMessage: $errorMessage, shopName: $shopName, amount: $amount, orderTime: $orderTime, orderNumber: $orderNumber, invoiceNumber: $invoiceNumber, invoiceDate: $invoiceDate, totalAmount: $totalAmount, sellerName: $sellerName)';
}


}

/// @nodoc
abstract mixin class _$OcrResultCopyWith<$Res> implements $OcrResultCopyWith<$Res> {
  factory _$OcrResultCopyWith(_OcrResult value, $Res Function(_OcrResult) _then) = __$OcrResultCopyWithImpl;
@override @useResult
$Res call({
 bool success, OcrType type, String? errorMessage, String? shopName, double? amount, String? orderTime, String? orderNumber, String? invoiceNumber, String? invoiceDate, double? totalAmount, String? sellerName
});




}
/// @nodoc
class __$OcrResultCopyWithImpl<$Res>
    implements _$OcrResultCopyWith<$Res> {
  __$OcrResultCopyWithImpl(this._self, this._then);

  final _OcrResult _self;
  final $Res Function(_OcrResult) _then;

/// Create a copy of OcrResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? success = null,Object? type = null,Object? errorMessage = freezed,Object? shopName = freezed,Object? amount = freezed,Object? orderTime = freezed,Object? orderNumber = freezed,Object? invoiceNumber = freezed,Object? invoiceDate = freezed,Object? totalAmount = freezed,Object? sellerName = freezed,}) {
  return _then(_OcrResult(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as OcrType,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,shopName: freezed == shopName ? _self.shopName : shopName // ignore: cast_nullable_to_non_nullable
as String?,amount: freezed == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double?,orderTime: freezed == orderTime ? _self.orderTime : orderTime // ignore: cast_nullable_to_non_nullable
as String?,orderNumber: freezed == orderNumber ? _self.orderNumber : orderNumber // ignore: cast_nullable_to_non_nullable
as String?,invoiceNumber: freezed == invoiceNumber ? _self.invoiceNumber : invoiceNumber // ignore: cast_nullable_to_non_nullable
as String?,invoiceDate: freezed == invoiceDate ? _self.invoiceDate : invoiceDate // ignore: cast_nullable_to_non_nullable
as String?,totalAmount: freezed == totalAmount ? _self.totalAmount : totalAmount // ignore: cast_nullable_to_non_nullable
as double?,sellerName: freezed == sellerName ? _self.sellerName : sellerName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on

// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'meal_proof_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MealProofItem {

 Order get order; Invoice get invoice; double get proratedInvoiceAmount; double get totalInvoiceAmount; bool get isProRated;
/// Create a copy of MealProofItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MealProofItemCopyWith<MealProofItem> get copyWith => _$MealProofItemCopyWithImpl<MealProofItem>(this as MealProofItem, _$identity);

  /// Serializes this MealProofItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MealProofItem&&(identical(other.order, order) || other.order == order)&&(identical(other.invoice, invoice) || other.invoice == invoice)&&(identical(other.proratedInvoiceAmount, proratedInvoiceAmount) || other.proratedInvoiceAmount == proratedInvoiceAmount)&&(identical(other.totalInvoiceAmount, totalInvoiceAmount) || other.totalInvoiceAmount == totalInvoiceAmount)&&(identical(other.isProRated, isProRated) || other.isProRated == isProRated));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,order,invoice,proratedInvoiceAmount,totalInvoiceAmount,isProRated);

@override
String toString() {
  return 'MealProofItem(order: $order, invoice: $invoice, proratedInvoiceAmount: $proratedInvoiceAmount, totalInvoiceAmount: $totalInvoiceAmount, isProRated: $isProRated)';
}


}

/// @nodoc
abstract mixin class $MealProofItemCopyWith<$Res>  {
  factory $MealProofItemCopyWith(MealProofItem value, $Res Function(MealProofItem) _then) = _$MealProofItemCopyWithImpl;
@useResult
$Res call({
 Order order, Invoice invoice, double proratedInvoiceAmount, double totalInvoiceAmount, bool isProRated
});


$OrderCopyWith<$Res> get order;$InvoiceCopyWith<$Res> get invoice;

}
/// @nodoc
class _$MealProofItemCopyWithImpl<$Res>
    implements $MealProofItemCopyWith<$Res> {
  _$MealProofItemCopyWithImpl(this._self, this._then);

  final MealProofItem _self;
  final $Res Function(MealProofItem) _then;

/// Create a copy of MealProofItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? order = null,Object? invoice = null,Object? proratedInvoiceAmount = null,Object? totalInvoiceAmount = null,Object? isProRated = null,}) {
  return _then(_self.copyWith(
order: null == order ? _self.order : order // ignore: cast_nullable_to_non_nullable
as Order,invoice: null == invoice ? _self.invoice : invoice // ignore: cast_nullable_to_non_nullable
as Invoice,proratedInvoiceAmount: null == proratedInvoiceAmount ? _self.proratedInvoiceAmount : proratedInvoiceAmount // ignore: cast_nullable_to_non_nullable
as double,totalInvoiceAmount: null == totalInvoiceAmount ? _self.totalInvoiceAmount : totalInvoiceAmount // ignore: cast_nullable_to_non_nullable
as double,isProRated: null == isProRated ? _self.isProRated : isProRated // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of MealProofItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OrderCopyWith<$Res> get order {
  
  return $OrderCopyWith<$Res>(_self.order, (value) {
    return _then(_self.copyWith(order: value));
  });
}/// Create a copy of MealProofItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$InvoiceCopyWith<$Res> get invoice {
  
  return $InvoiceCopyWith<$Res>(_self.invoice, (value) {
    return _then(_self.copyWith(invoice: value));
  });
}
}


/// Adds pattern-matching-related methods to [MealProofItem].
extension MealProofItemPatterns on MealProofItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MealProofItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MealProofItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MealProofItem value)  $default,){
final _that = this;
switch (_that) {
case _MealProofItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MealProofItem value)?  $default,){
final _that = this;
switch (_that) {
case _MealProofItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Order order,  Invoice invoice,  double proratedInvoiceAmount,  double totalInvoiceAmount,  bool isProRated)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MealProofItem() when $default != null:
return $default(_that.order,_that.invoice,_that.proratedInvoiceAmount,_that.totalInvoiceAmount,_that.isProRated);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Order order,  Invoice invoice,  double proratedInvoiceAmount,  double totalInvoiceAmount,  bool isProRated)  $default,) {final _that = this;
switch (_that) {
case _MealProofItem():
return $default(_that.order,_that.invoice,_that.proratedInvoiceAmount,_that.totalInvoiceAmount,_that.isProRated);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Order order,  Invoice invoice,  double proratedInvoiceAmount,  double totalInvoiceAmount,  bool isProRated)?  $default,) {final _that = this;
switch (_that) {
case _MealProofItem() when $default != null:
return $default(_that.order,_that.invoice,_that.proratedInvoiceAmount,_that.totalInvoiceAmount,_that.isProRated);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MealProofItem implements MealProofItem {
  const _MealProofItem({required this.order, required this.invoice, this.proratedInvoiceAmount = 0.0, this.totalInvoiceAmount = 0.0, this.isProRated = false});
  factory _MealProofItem.fromJson(Map<String, dynamic> json) => _$MealProofItemFromJson(json);

@override final  Order order;
@override final  Invoice invoice;
@override@JsonKey() final  double proratedInvoiceAmount;
@override@JsonKey() final  double totalInvoiceAmount;
@override@JsonKey() final  bool isProRated;

/// Create a copy of MealProofItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MealProofItemCopyWith<_MealProofItem> get copyWith => __$MealProofItemCopyWithImpl<_MealProofItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MealProofItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MealProofItem&&(identical(other.order, order) || other.order == order)&&(identical(other.invoice, invoice) || other.invoice == invoice)&&(identical(other.proratedInvoiceAmount, proratedInvoiceAmount) || other.proratedInvoiceAmount == proratedInvoiceAmount)&&(identical(other.totalInvoiceAmount, totalInvoiceAmount) || other.totalInvoiceAmount == totalInvoiceAmount)&&(identical(other.isProRated, isProRated) || other.isProRated == isProRated));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,order,invoice,proratedInvoiceAmount,totalInvoiceAmount,isProRated);

@override
String toString() {
  return 'MealProofItem(order: $order, invoice: $invoice, proratedInvoiceAmount: $proratedInvoiceAmount, totalInvoiceAmount: $totalInvoiceAmount, isProRated: $isProRated)';
}


}

/// @nodoc
abstract mixin class _$MealProofItemCopyWith<$Res> implements $MealProofItemCopyWith<$Res> {
  factory _$MealProofItemCopyWith(_MealProofItem value, $Res Function(_MealProofItem) _then) = __$MealProofItemCopyWithImpl;
@override @useResult
$Res call({
 Order order, Invoice invoice, double proratedInvoiceAmount, double totalInvoiceAmount, bool isProRated
});


@override $OrderCopyWith<$Res> get order;@override $InvoiceCopyWith<$Res> get invoice;

}
/// @nodoc
class __$MealProofItemCopyWithImpl<$Res>
    implements _$MealProofItemCopyWith<$Res> {
  __$MealProofItemCopyWithImpl(this._self, this._then);

  final _MealProofItem _self;
  final $Res Function(_MealProofItem) _then;

/// Create a copy of MealProofItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? order = null,Object? invoice = null,Object? proratedInvoiceAmount = null,Object? totalInvoiceAmount = null,Object? isProRated = null,}) {
  return _then(_MealProofItem(
order: null == order ? _self.order : order // ignore: cast_nullable_to_non_nullable
as Order,invoice: null == invoice ? _self.invoice : invoice // ignore: cast_nullable_to_non_nullable
as Invoice,proratedInvoiceAmount: null == proratedInvoiceAmount ? _self.proratedInvoiceAmount : proratedInvoiceAmount // ignore: cast_nullable_to_non_nullable
as double,totalInvoiceAmount: null == totalInvoiceAmount ? _self.totalInvoiceAmount : totalInvoiceAmount // ignore: cast_nullable_to_non_nullable
as double,isProRated: null == isProRated ? _self.isProRated : isProRated // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of MealProofItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OrderCopyWith<$Res> get order {
  
  return $OrderCopyWith<$Res>(_self.order, (value) {
    return _then(_self.copyWith(order: value));
  });
}/// Create a copy of MealProofItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$InvoiceCopyWith<$Res> get invoice {
  
  return $InvoiceCopyWith<$Res>(_self.invoice, (value) {
    return _then(_self.copyWith(invoice: value));
  });
}
}

// dart format on

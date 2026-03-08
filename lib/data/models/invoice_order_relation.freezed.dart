// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'invoice_order_relation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$InvoiceOrderRelation {

@JsonKey(name: 'invoice_id') int get invoiceId;@JsonKey(name: 'order_id') int get orderId;
/// Create a copy of InvoiceOrderRelation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InvoiceOrderRelationCopyWith<InvoiceOrderRelation> get copyWith => _$InvoiceOrderRelationCopyWithImpl<InvoiceOrderRelation>(this as InvoiceOrderRelation, _$identity);

  /// Serializes this InvoiceOrderRelation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InvoiceOrderRelation&&(identical(other.invoiceId, invoiceId) || other.invoiceId == invoiceId)&&(identical(other.orderId, orderId) || other.orderId == orderId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,invoiceId,orderId);

@override
String toString() {
  return 'InvoiceOrderRelation(invoiceId: $invoiceId, orderId: $orderId)';
}


}

/// @nodoc
abstract mixin class $InvoiceOrderRelationCopyWith<$Res>  {
  factory $InvoiceOrderRelationCopyWith(InvoiceOrderRelation value, $Res Function(InvoiceOrderRelation) _then) = _$InvoiceOrderRelationCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'invoice_id') int invoiceId,@JsonKey(name: 'order_id') int orderId
});




}
/// @nodoc
class _$InvoiceOrderRelationCopyWithImpl<$Res>
    implements $InvoiceOrderRelationCopyWith<$Res> {
  _$InvoiceOrderRelationCopyWithImpl(this._self, this._then);

  final InvoiceOrderRelation _self;
  final $Res Function(InvoiceOrderRelation) _then;

/// Create a copy of InvoiceOrderRelation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? invoiceId = null,Object? orderId = null,}) {
  return _then(_self.copyWith(
invoiceId: null == invoiceId ? _self.invoiceId : invoiceId // ignore: cast_nullable_to_non_nullable
as int,orderId: null == orderId ? _self.orderId : orderId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [InvoiceOrderRelation].
extension InvoiceOrderRelationPatterns on InvoiceOrderRelation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InvoiceOrderRelation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InvoiceOrderRelation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InvoiceOrderRelation value)  $default,){
final _that = this;
switch (_that) {
case _InvoiceOrderRelation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InvoiceOrderRelation value)?  $default,){
final _that = this;
switch (_that) {
case _InvoiceOrderRelation() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'invoice_id')  int invoiceId, @JsonKey(name: 'order_id')  int orderId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InvoiceOrderRelation() when $default != null:
return $default(_that.invoiceId,_that.orderId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'invoice_id')  int invoiceId, @JsonKey(name: 'order_id')  int orderId)  $default,) {final _that = this;
switch (_that) {
case _InvoiceOrderRelation():
return $default(_that.invoiceId,_that.orderId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'invoice_id')  int invoiceId, @JsonKey(name: 'order_id')  int orderId)?  $default,) {final _that = this;
switch (_that) {
case _InvoiceOrderRelation() when $default != null:
return $default(_that.invoiceId,_that.orderId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InvoiceOrderRelation implements InvoiceOrderRelation {
  const _InvoiceOrderRelation({@JsonKey(name: 'invoice_id') required this.invoiceId, @JsonKey(name: 'order_id') required this.orderId});
  factory _InvoiceOrderRelation.fromJson(Map<String, dynamic> json) => _$InvoiceOrderRelationFromJson(json);

@override@JsonKey(name: 'invoice_id') final  int invoiceId;
@override@JsonKey(name: 'order_id') final  int orderId;

/// Create a copy of InvoiceOrderRelation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InvoiceOrderRelationCopyWith<_InvoiceOrderRelation> get copyWith => __$InvoiceOrderRelationCopyWithImpl<_InvoiceOrderRelation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InvoiceOrderRelationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InvoiceOrderRelation&&(identical(other.invoiceId, invoiceId) || other.invoiceId == invoiceId)&&(identical(other.orderId, orderId) || other.orderId == orderId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,invoiceId,orderId);

@override
String toString() {
  return 'InvoiceOrderRelation(invoiceId: $invoiceId, orderId: $orderId)';
}


}

/// @nodoc
abstract mixin class _$InvoiceOrderRelationCopyWith<$Res> implements $InvoiceOrderRelationCopyWith<$Res> {
  factory _$InvoiceOrderRelationCopyWith(_InvoiceOrderRelation value, $Res Function(_InvoiceOrderRelation) _then) = __$InvoiceOrderRelationCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'invoice_id') int invoiceId,@JsonKey(name: 'order_id') int orderId
});




}
/// @nodoc
class __$InvoiceOrderRelationCopyWithImpl<$Res>
    implements _$InvoiceOrderRelationCopyWith<$Res> {
  __$InvoiceOrderRelationCopyWithImpl(this._self, this._then);

  final _InvoiceOrderRelation _self;
  final $Res Function(_InvoiceOrderRelation) _then;

/// Create a copy of InvoiceOrderRelation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? invoiceId = null,Object? orderId = null,}) {
  return _then(_InvoiceOrderRelation(
invoiceId: null == invoiceId ? _self.invoiceId : invoiceId // ignore: cast_nullable_to_non_nullable
as int,orderId: null == orderId ? _self.orderId : orderId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on

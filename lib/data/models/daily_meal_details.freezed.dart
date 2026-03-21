// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'daily_meal_details.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DailyMealDetails {

 String get date;// Format: yyyy-MM-dd
 double get breakfastPaid; double get breakfastInvoice; double get lunchPaid; double get lunchInvoice; double get dinnerPaid; double get dinnerInvoice;
/// Create a copy of DailyMealDetails
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DailyMealDetailsCopyWith<DailyMealDetails> get copyWith => _$DailyMealDetailsCopyWithImpl<DailyMealDetails>(this as DailyMealDetails, _$identity);

  /// Serializes this DailyMealDetails to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DailyMealDetails&&(identical(other.date, date) || other.date == date)&&(identical(other.breakfastPaid, breakfastPaid) || other.breakfastPaid == breakfastPaid)&&(identical(other.breakfastInvoice, breakfastInvoice) || other.breakfastInvoice == breakfastInvoice)&&(identical(other.lunchPaid, lunchPaid) || other.lunchPaid == lunchPaid)&&(identical(other.lunchInvoice, lunchInvoice) || other.lunchInvoice == lunchInvoice)&&(identical(other.dinnerPaid, dinnerPaid) || other.dinnerPaid == dinnerPaid)&&(identical(other.dinnerInvoice, dinnerInvoice) || other.dinnerInvoice == dinnerInvoice));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,date,breakfastPaid,breakfastInvoice,lunchPaid,lunchInvoice,dinnerPaid,dinnerInvoice);

@override
String toString() {
  return 'DailyMealDetails(date: $date, breakfastPaid: $breakfastPaid, breakfastInvoice: $breakfastInvoice, lunchPaid: $lunchPaid, lunchInvoice: $lunchInvoice, dinnerPaid: $dinnerPaid, dinnerInvoice: $dinnerInvoice)';
}


}

/// @nodoc
abstract mixin class $DailyMealDetailsCopyWith<$Res>  {
  factory $DailyMealDetailsCopyWith(DailyMealDetails value, $Res Function(DailyMealDetails) _then) = _$DailyMealDetailsCopyWithImpl;
@useResult
$Res call({
 String date, double breakfastPaid, double breakfastInvoice, double lunchPaid, double lunchInvoice, double dinnerPaid, double dinnerInvoice
});




}
/// @nodoc
class _$DailyMealDetailsCopyWithImpl<$Res>
    implements $DailyMealDetailsCopyWith<$Res> {
  _$DailyMealDetailsCopyWithImpl(this._self, this._then);

  final DailyMealDetails _self;
  final $Res Function(DailyMealDetails) _then;

/// Create a copy of DailyMealDetails
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? date = null,Object? breakfastPaid = null,Object? breakfastInvoice = null,Object? lunchPaid = null,Object? lunchInvoice = null,Object? dinnerPaid = null,Object? dinnerInvoice = null,}) {
  return _then(_self.copyWith(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,breakfastPaid: null == breakfastPaid ? _self.breakfastPaid : breakfastPaid // ignore: cast_nullable_to_non_nullable
as double,breakfastInvoice: null == breakfastInvoice ? _self.breakfastInvoice : breakfastInvoice // ignore: cast_nullable_to_non_nullable
as double,lunchPaid: null == lunchPaid ? _self.lunchPaid : lunchPaid // ignore: cast_nullable_to_non_nullable
as double,lunchInvoice: null == lunchInvoice ? _self.lunchInvoice : lunchInvoice // ignore: cast_nullable_to_non_nullable
as double,dinnerPaid: null == dinnerPaid ? _self.dinnerPaid : dinnerPaid // ignore: cast_nullable_to_non_nullable
as double,dinnerInvoice: null == dinnerInvoice ? _self.dinnerInvoice : dinnerInvoice // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [DailyMealDetails].
extension DailyMealDetailsPatterns on DailyMealDetails {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DailyMealDetails value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DailyMealDetails() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DailyMealDetails value)  $default,){
final _that = this;
switch (_that) {
case _DailyMealDetails():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DailyMealDetails value)?  $default,){
final _that = this;
switch (_that) {
case _DailyMealDetails() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String date,  double breakfastPaid,  double breakfastInvoice,  double lunchPaid,  double lunchInvoice,  double dinnerPaid,  double dinnerInvoice)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DailyMealDetails() when $default != null:
return $default(_that.date,_that.breakfastPaid,_that.breakfastInvoice,_that.lunchPaid,_that.lunchInvoice,_that.dinnerPaid,_that.dinnerInvoice);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String date,  double breakfastPaid,  double breakfastInvoice,  double lunchPaid,  double lunchInvoice,  double dinnerPaid,  double dinnerInvoice)  $default,) {final _that = this;
switch (_that) {
case _DailyMealDetails():
return $default(_that.date,_that.breakfastPaid,_that.breakfastInvoice,_that.lunchPaid,_that.lunchInvoice,_that.dinnerPaid,_that.dinnerInvoice);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String date,  double breakfastPaid,  double breakfastInvoice,  double lunchPaid,  double lunchInvoice,  double dinnerPaid,  double dinnerInvoice)?  $default,) {final _that = this;
switch (_that) {
case _DailyMealDetails() when $default != null:
return $default(_that.date,_that.breakfastPaid,_that.breakfastInvoice,_that.lunchPaid,_that.lunchInvoice,_that.dinnerPaid,_that.dinnerInvoice);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DailyMealDetails implements DailyMealDetails {
  const _DailyMealDetails({required this.date, this.breakfastPaid = 0.0, this.breakfastInvoice = 0.0, this.lunchPaid = 0.0, this.lunchInvoice = 0.0, this.dinnerPaid = 0.0, this.dinnerInvoice = 0.0});
  factory _DailyMealDetails.fromJson(Map<String, dynamic> json) => _$DailyMealDetailsFromJson(json);

@override final  String date;
// Format: yyyy-MM-dd
@override@JsonKey() final  double breakfastPaid;
@override@JsonKey() final  double breakfastInvoice;
@override@JsonKey() final  double lunchPaid;
@override@JsonKey() final  double lunchInvoice;
@override@JsonKey() final  double dinnerPaid;
@override@JsonKey() final  double dinnerInvoice;

/// Create a copy of DailyMealDetails
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DailyMealDetailsCopyWith<_DailyMealDetails> get copyWith => __$DailyMealDetailsCopyWithImpl<_DailyMealDetails>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DailyMealDetailsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DailyMealDetails&&(identical(other.date, date) || other.date == date)&&(identical(other.breakfastPaid, breakfastPaid) || other.breakfastPaid == breakfastPaid)&&(identical(other.breakfastInvoice, breakfastInvoice) || other.breakfastInvoice == breakfastInvoice)&&(identical(other.lunchPaid, lunchPaid) || other.lunchPaid == lunchPaid)&&(identical(other.lunchInvoice, lunchInvoice) || other.lunchInvoice == lunchInvoice)&&(identical(other.dinnerPaid, dinnerPaid) || other.dinnerPaid == dinnerPaid)&&(identical(other.dinnerInvoice, dinnerInvoice) || other.dinnerInvoice == dinnerInvoice));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,date,breakfastPaid,breakfastInvoice,lunchPaid,lunchInvoice,dinnerPaid,dinnerInvoice);

@override
String toString() {
  return 'DailyMealDetails(date: $date, breakfastPaid: $breakfastPaid, breakfastInvoice: $breakfastInvoice, lunchPaid: $lunchPaid, lunchInvoice: $lunchInvoice, dinnerPaid: $dinnerPaid, dinnerInvoice: $dinnerInvoice)';
}


}

/// @nodoc
abstract mixin class _$DailyMealDetailsCopyWith<$Res> implements $DailyMealDetailsCopyWith<$Res> {
  factory _$DailyMealDetailsCopyWith(_DailyMealDetails value, $Res Function(_DailyMealDetails) _then) = __$DailyMealDetailsCopyWithImpl;
@override @useResult
$Res call({
 String date, double breakfastPaid, double breakfastInvoice, double lunchPaid, double lunchInvoice, double dinnerPaid, double dinnerInvoice
});




}
/// @nodoc
class __$DailyMealDetailsCopyWithImpl<$Res>
    implements _$DailyMealDetailsCopyWith<$Res> {
  __$DailyMealDetailsCopyWithImpl(this._self, this._then);

  final _DailyMealDetails _self;
  final $Res Function(_DailyMealDetails) _then;

/// Create a copy of DailyMealDetails
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? date = null,Object? breakfastPaid = null,Object? breakfastInvoice = null,Object? lunchPaid = null,Object? lunchInvoice = null,Object? dinnerPaid = null,Object? dinnerInvoice = null,}) {
  return _then(_DailyMealDetails(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,breakfastPaid: null == breakfastPaid ? _self.breakfastPaid : breakfastPaid // ignore: cast_nullable_to_non_nullable
as double,breakfastInvoice: null == breakfastInvoice ? _self.breakfastInvoice : breakfastInvoice // ignore: cast_nullable_to_non_nullable
as double,lunchPaid: null == lunchPaid ? _self.lunchPaid : lunchPaid // ignore: cast_nullable_to_non_nullable
as double,lunchInvoice: null == lunchInvoice ? _self.lunchInvoice : lunchInvoice // ignore: cast_nullable_to_non_nullable
as double,dinnerPaid: null == dinnerPaid ? _self.dinnerPaid : dinnerPaid // ignore: cast_nullable_to_non_nullable
as double,dinnerInvoice: null == dinnerInvoice ? _self.dinnerInvoice : dinnerInvoice // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on

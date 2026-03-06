// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ocr_text_block.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OcrPoint {

 int get x; int get y;
/// Create a copy of OcrPoint
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OcrPointCopyWith<OcrPoint> get copyWith => _$OcrPointCopyWithImpl<OcrPoint>(this as OcrPoint, _$identity);

  /// Serializes this OcrPoint to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OcrPoint&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,x,y);

@override
String toString() {
  return 'OcrPoint(x: $x, y: $y)';
}


}

/// @nodoc
abstract mixin class $OcrPointCopyWith<$Res>  {
  factory $OcrPointCopyWith(OcrPoint value, $Res Function(OcrPoint) _then) = _$OcrPointCopyWithImpl;
@useResult
$Res call({
 int x, int y
});




}
/// @nodoc
class _$OcrPointCopyWithImpl<$Res>
    implements $OcrPointCopyWith<$Res> {
  _$OcrPointCopyWithImpl(this._self, this._then);

  final OcrPoint _self;
  final $Res Function(OcrPoint) _then;

/// Create a copy of OcrPoint
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? x = null,Object? y = null,}) {
  return _then(_self.copyWith(
x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as int,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [OcrPoint].
extension OcrPointPatterns on OcrPoint {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OcrPoint value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OcrPoint() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OcrPoint value)  $default,){
final _that = this;
switch (_that) {
case _OcrPoint():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OcrPoint value)?  $default,){
final _that = this;
switch (_that) {
case _OcrPoint() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int x,  int y)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OcrPoint() when $default != null:
return $default(_that.x,_that.y);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int x,  int y)  $default,) {final _that = this;
switch (_that) {
case _OcrPoint():
return $default(_that.x,_that.y);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int x,  int y)?  $default,) {final _that = this;
switch (_that) {
case _OcrPoint() when $default != null:
return $default(_that.x,_that.y);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OcrPoint implements OcrPoint {
  const _OcrPoint({required this.x, required this.y});
  factory _OcrPoint.fromJson(Map<String, dynamic> json) => _$OcrPointFromJson(json);

@override final  int x;
@override final  int y;

/// Create a copy of OcrPoint
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OcrPointCopyWith<_OcrPoint> get copyWith => __$OcrPointCopyWithImpl<_OcrPoint>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OcrPointToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OcrPoint&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,x,y);

@override
String toString() {
  return 'OcrPoint(x: $x, y: $y)';
}


}

/// @nodoc
abstract mixin class _$OcrPointCopyWith<$Res> implements $OcrPointCopyWith<$Res> {
  factory _$OcrPointCopyWith(_OcrPoint value, $Res Function(_OcrPoint) _then) = __$OcrPointCopyWithImpl;
@override @useResult
$Res call({
 int x, int y
});




}
/// @nodoc
class __$OcrPointCopyWithImpl<$Res>
    implements _$OcrPointCopyWith<$Res> {
  __$OcrPointCopyWithImpl(this._self, this._then);

  final _OcrPoint _self;
  final $Res Function(_OcrPoint) _then;

/// Create a copy of OcrPoint
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? x = null,Object? y = null,}) {
  return _then(_OcrPoint(
x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as int,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$OcrTextBlock {

/// Recognized text content
 String get text;/// Bounding box as 4 corner points (top-left, top-right, bottom-right, bottom-left)
 List<OcrPoint> get boundingBox;/// Confidence score (0.0 to 1.0)
 double get confidence;
/// Create a copy of OcrTextBlock
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OcrTextBlockCopyWith<OcrTextBlock> get copyWith => _$OcrTextBlockCopyWithImpl<OcrTextBlock>(this as OcrTextBlock, _$identity);

  /// Serializes this OcrTextBlock to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OcrTextBlock&&(identical(other.text, text) || other.text == text)&&const DeepCollectionEquality().equals(other.boundingBox, boundingBox)&&(identical(other.confidence, confidence) || other.confidence == confidence));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,text,const DeepCollectionEquality().hash(boundingBox),confidence);

@override
String toString() {
  return 'OcrTextBlock(text: $text, boundingBox: $boundingBox, confidence: $confidence)';
}


}

/// @nodoc
abstract mixin class $OcrTextBlockCopyWith<$Res>  {
  factory $OcrTextBlockCopyWith(OcrTextBlock value, $Res Function(OcrTextBlock) _then) = _$OcrTextBlockCopyWithImpl;
@useResult
$Res call({
 String text, List<OcrPoint> boundingBox, double confidence
});




}
/// @nodoc
class _$OcrTextBlockCopyWithImpl<$Res>
    implements $OcrTextBlockCopyWith<$Res> {
  _$OcrTextBlockCopyWithImpl(this._self, this._then);

  final OcrTextBlock _self;
  final $Res Function(OcrTextBlock) _then;

/// Create a copy of OcrTextBlock
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? text = null,Object? boundingBox = null,Object? confidence = null,}) {
  return _then(_self.copyWith(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,boundingBox: null == boundingBox ? _self.boundingBox : boundingBox // ignore: cast_nullable_to_non_nullable
as List<OcrPoint>,confidence: null == confidence ? _self.confidence : confidence // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [OcrTextBlock].
extension OcrTextBlockPatterns on OcrTextBlock {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OcrTextBlock value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OcrTextBlock() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OcrTextBlock value)  $default,){
final _that = this;
switch (_that) {
case _OcrTextBlock():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OcrTextBlock value)?  $default,){
final _that = this;
switch (_that) {
case _OcrTextBlock() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String text,  List<OcrPoint> boundingBox,  double confidence)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OcrTextBlock() when $default != null:
return $default(_that.text,_that.boundingBox,_that.confidence);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String text,  List<OcrPoint> boundingBox,  double confidence)  $default,) {final _that = this;
switch (_that) {
case _OcrTextBlock():
return $default(_that.text,_that.boundingBox,_that.confidence);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String text,  List<OcrPoint> boundingBox,  double confidence)?  $default,) {final _that = this;
switch (_that) {
case _OcrTextBlock() when $default != null:
return $default(_that.text,_that.boundingBox,_that.confidence);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OcrTextBlock implements OcrTextBlock {
  const _OcrTextBlock({required this.text, required final  List<OcrPoint> boundingBox, required this.confidence}): _boundingBox = boundingBox;
  factory _OcrTextBlock.fromJson(Map<String, dynamic> json) => _$OcrTextBlockFromJson(json);

/// Recognized text content
@override final  String text;
/// Bounding box as 4 corner points (top-left, top-right, bottom-right, bottom-left)
 final  List<OcrPoint> _boundingBox;
/// Bounding box as 4 corner points (top-left, top-right, bottom-right, bottom-left)
@override List<OcrPoint> get boundingBox {
  if (_boundingBox is EqualUnmodifiableListView) return _boundingBox;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_boundingBox);
}

/// Confidence score (0.0 to 1.0)
@override final  double confidence;

/// Create a copy of OcrTextBlock
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OcrTextBlockCopyWith<_OcrTextBlock> get copyWith => __$OcrTextBlockCopyWithImpl<_OcrTextBlock>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OcrTextBlockToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OcrTextBlock&&(identical(other.text, text) || other.text == text)&&const DeepCollectionEquality().equals(other._boundingBox, _boundingBox)&&(identical(other.confidence, confidence) || other.confidence == confidence));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,text,const DeepCollectionEquality().hash(_boundingBox),confidence);

@override
String toString() {
  return 'OcrTextBlock(text: $text, boundingBox: $boundingBox, confidence: $confidence)';
}


}

/// @nodoc
abstract mixin class _$OcrTextBlockCopyWith<$Res> implements $OcrTextBlockCopyWith<$Res> {
  factory _$OcrTextBlockCopyWith(_OcrTextBlock value, $Res Function(_OcrTextBlock) _then) = __$OcrTextBlockCopyWithImpl;
@override @useResult
$Res call({
 String text, List<OcrPoint> boundingBox, double confidence
});




}
/// @nodoc
class __$OcrTextBlockCopyWithImpl<$Res>
    implements _$OcrTextBlockCopyWith<$Res> {
  __$OcrTextBlockCopyWithImpl(this._self, this._then);

  final _OcrTextBlock _self;
  final $Res Function(_OcrTextBlock) _then;

/// Create a copy of OcrTextBlock
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? text = null,Object? boundingBox = null,Object? confidence = null,}) {
  return _then(_OcrTextBlock(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,boundingBox: null == boundingBox ? _self._boundingBox : boundingBox // ignore: cast_nullable_to_non_nullable
as List<OcrPoint>,confidence: null == confidence ? _self.confidence : confidence // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}


/// @nodoc
mixin _$OcrRawResult {

/// Whether OCR was successful
 bool get success;/// List of detected text blocks
 List<OcrTextBlock> get textBlocks;/// Error message if failed
 String? get errorMessage;/// Processing time in milliseconds
 int? get processingTimeMs;
/// Create a copy of OcrRawResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OcrRawResultCopyWith<OcrRawResult> get copyWith => _$OcrRawResultCopyWithImpl<OcrRawResult>(this as OcrRawResult, _$identity);

  /// Serializes this OcrRawResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OcrRawResult&&(identical(other.success, success) || other.success == success)&&const DeepCollectionEquality().equals(other.textBlocks, textBlocks)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.processingTimeMs, processingTimeMs) || other.processingTimeMs == processingTimeMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,success,const DeepCollectionEquality().hash(textBlocks),errorMessage,processingTimeMs);

@override
String toString() {
  return 'OcrRawResult(success: $success, textBlocks: $textBlocks, errorMessage: $errorMessage, processingTimeMs: $processingTimeMs)';
}


}

/// @nodoc
abstract mixin class $OcrRawResultCopyWith<$Res>  {
  factory $OcrRawResultCopyWith(OcrRawResult value, $Res Function(OcrRawResult) _then) = _$OcrRawResultCopyWithImpl;
@useResult
$Res call({
 bool success, List<OcrTextBlock> textBlocks, String? errorMessage, int? processingTimeMs
});




}
/// @nodoc
class _$OcrRawResultCopyWithImpl<$Res>
    implements $OcrRawResultCopyWith<$Res> {
  _$OcrRawResultCopyWithImpl(this._self, this._then);

  final OcrRawResult _self;
  final $Res Function(OcrRawResult) _then;

/// Create a copy of OcrRawResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? success = null,Object? textBlocks = null,Object? errorMessage = freezed,Object? processingTimeMs = freezed,}) {
  return _then(_self.copyWith(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,textBlocks: null == textBlocks ? _self.textBlocks : textBlocks // ignore: cast_nullable_to_non_nullable
as List<OcrTextBlock>,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,processingTimeMs: freezed == processingTimeMs ? _self.processingTimeMs : processingTimeMs // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [OcrRawResult].
extension OcrRawResultPatterns on OcrRawResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OcrRawResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OcrRawResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OcrRawResult value)  $default,){
final _that = this;
switch (_that) {
case _OcrRawResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OcrRawResult value)?  $default,){
final _that = this;
switch (_that) {
case _OcrRawResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool success,  List<OcrTextBlock> textBlocks,  String? errorMessage,  int? processingTimeMs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OcrRawResult() when $default != null:
return $default(_that.success,_that.textBlocks,_that.errorMessage,_that.processingTimeMs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool success,  List<OcrTextBlock> textBlocks,  String? errorMessage,  int? processingTimeMs)  $default,) {final _that = this;
switch (_that) {
case _OcrRawResult():
return $default(_that.success,_that.textBlocks,_that.errorMessage,_that.processingTimeMs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool success,  List<OcrTextBlock> textBlocks,  String? errorMessage,  int? processingTimeMs)?  $default,) {final _that = this;
switch (_that) {
case _OcrRawResult() when $default != null:
return $default(_that.success,_that.textBlocks,_that.errorMessage,_that.processingTimeMs);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OcrRawResult implements OcrRawResult {
  const _OcrRawResult({required this.success, required final  List<OcrTextBlock> textBlocks, this.errorMessage, this.processingTimeMs}): _textBlocks = textBlocks;
  factory _OcrRawResult.fromJson(Map<String, dynamic> json) => _$OcrRawResultFromJson(json);

/// Whether OCR was successful
@override final  bool success;
/// List of detected text blocks
 final  List<OcrTextBlock> _textBlocks;
/// List of detected text blocks
@override List<OcrTextBlock> get textBlocks {
  if (_textBlocks is EqualUnmodifiableListView) return _textBlocks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_textBlocks);
}

/// Error message if failed
@override final  String? errorMessage;
/// Processing time in milliseconds
@override final  int? processingTimeMs;

/// Create a copy of OcrRawResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OcrRawResultCopyWith<_OcrRawResult> get copyWith => __$OcrRawResultCopyWithImpl<_OcrRawResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OcrRawResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OcrRawResult&&(identical(other.success, success) || other.success == success)&&const DeepCollectionEquality().equals(other._textBlocks, _textBlocks)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.processingTimeMs, processingTimeMs) || other.processingTimeMs == processingTimeMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,success,const DeepCollectionEquality().hash(_textBlocks),errorMessage,processingTimeMs);

@override
String toString() {
  return 'OcrRawResult(success: $success, textBlocks: $textBlocks, errorMessage: $errorMessage, processingTimeMs: $processingTimeMs)';
}


}

/// @nodoc
abstract mixin class _$OcrRawResultCopyWith<$Res> implements $OcrRawResultCopyWith<$Res> {
  factory _$OcrRawResultCopyWith(_OcrRawResult value, $Res Function(_OcrRawResult) _then) = __$OcrRawResultCopyWithImpl;
@override @useResult
$Res call({
 bool success, List<OcrTextBlock> textBlocks, String? errorMessage, int? processingTimeMs
});




}
/// @nodoc
class __$OcrRawResultCopyWithImpl<$Res>
    implements _$OcrRawResultCopyWith<$Res> {
  __$OcrRawResultCopyWithImpl(this._self, this._then);

  final _OcrRawResult _self;
  final $Res Function(_OcrRawResult) _then;

/// Create a copy of OcrRawResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? success = null,Object? textBlocks = null,Object? errorMessage = freezed,Object? processingTimeMs = freezed,}) {
  return _then(_OcrRawResult(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,textBlocks: null == textBlocks ? _self._textBlocks : textBlocks // ignore: cast_nullable_to_non_nullable
as List<OcrTextBlock>,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,processingTimeMs: freezed == processingTimeMs ? _self.processingTimeMs : processingTimeMs // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on

// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'backup_metadata.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BackupMetadata {

/// Backup format version
 String get version;/// App version that created the backup
@JsonKey(name: 'app_version') String get appVersion;/// Database version that created the backup
@JsonKey(name: 'database_version') int get databaseVersion;/// Backup creation time (ISO 8601 format)
@JsonKey(name: 'backup_time') String get backupTime;/// Number of orders in the backup
@JsonKey(name: 'order_count') int get orderCount;/// Number of invoices in the backup
@JsonKey(name: 'invoice_count') int get invoiceCount;/// Number of images in the backup
@JsonKey(name: 'image_count') int get imageCount;/// Number of PDFs in the backup
@JsonKey(name: 'pdf_count') int get pdfCount;
/// Create a copy of BackupMetadata
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BackupMetadataCopyWith<BackupMetadata> get copyWith => _$BackupMetadataCopyWithImpl<BackupMetadata>(this as BackupMetadata, _$identity);

  /// Serializes this BackupMetadata to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BackupMetadata&&(identical(other.version, version) || other.version == version)&&(identical(other.appVersion, appVersion) || other.appVersion == appVersion)&&(identical(other.databaseVersion, databaseVersion) || other.databaseVersion == databaseVersion)&&(identical(other.backupTime, backupTime) || other.backupTime == backupTime)&&(identical(other.orderCount, orderCount) || other.orderCount == orderCount)&&(identical(other.invoiceCount, invoiceCount) || other.invoiceCount == invoiceCount)&&(identical(other.imageCount, imageCount) || other.imageCount == imageCount)&&(identical(other.pdfCount, pdfCount) || other.pdfCount == pdfCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,version,appVersion,databaseVersion,backupTime,orderCount,invoiceCount,imageCount,pdfCount);

@override
String toString() {
  return 'BackupMetadata(version: $version, appVersion: $appVersion, databaseVersion: $databaseVersion, backupTime: $backupTime, orderCount: $orderCount, invoiceCount: $invoiceCount, imageCount: $imageCount, pdfCount: $pdfCount)';
}


}

/// @nodoc
abstract mixin class $BackupMetadataCopyWith<$Res>  {
  factory $BackupMetadataCopyWith(BackupMetadata value, $Res Function(BackupMetadata) _then) = _$BackupMetadataCopyWithImpl;
@useResult
$Res call({
 String version,@JsonKey(name: 'app_version') String appVersion,@JsonKey(name: 'database_version') int databaseVersion,@JsonKey(name: 'backup_time') String backupTime,@JsonKey(name: 'order_count') int orderCount,@JsonKey(name: 'invoice_count') int invoiceCount,@JsonKey(name: 'image_count') int imageCount,@JsonKey(name: 'pdf_count') int pdfCount
});




}
/// @nodoc
class _$BackupMetadataCopyWithImpl<$Res>
    implements $BackupMetadataCopyWith<$Res> {
  _$BackupMetadataCopyWithImpl(this._self, this._then);

  final BackupMetadata _self;
  final $Res Function(BackupMetadata) _then;

/// Create a copy of BackupMetadata
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? version = null,Object? appVersion = null,Object? databaseVersion = null,Object? backupTime = null,Object? orderCount = null,Object? invoiceCount = null,Object? imageCount = null,Object? pdfCount = null,}) {
  return _then(_self.copyWith(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,appVersion: null == appVersion ? _self.appVersion : appVersion // ignore: cast_nullable_to_non_nullable
as String,databaseVersion: null == databaseVersion ? _self.databaseVersion : databaseVersion // ignore: cast_nullable_to_non_nullable
as int,backupTime: null == backupTime ? _self.backupTime : backupTime // ignore: cast_nullable_to_non_nullable
as String,orderCount: null == orderCount ? _self.orderCount : orderCount // ignore: cast_nullable_to_non_nullable
as int,invoiceCount: null == invoiceCount ? _self.invoiceCount : invoiceCount // ignore: cast_nullable_to_non_nullable
as int,imageCount: null == imageCount ? _self.imageCount : imageCount // ignore: cast_nullable_to_non_nullable
as int,pdfCount: null == pdfCount ? _self.pdfCount : pdfCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [BackupMetadata].
extension BackupMetadataPatterns on BackupMetadata {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BackupMetadata value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BackupMetadata() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BackupMetadata value)  $default,){
final _that = this;
switch (_that) {
case _BackupMetadata():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BackupMetadata value)?  $default,){
final _that = this;
switch (_that) {
case _BackupMetadata() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String version, @JsonKey(name: 'app_version')  String appVersion, @JsonKey(name: 'database_version')  int databaseVersion, @JsonKey(name: 'backup_time')  String backupTime, @JsonKey(name: 'order_count')  int orderCount, @JsonKey(name: 'invoice_count')  int invoiceCount, @JsonKey(name: 'image_count')  int imageCount, @JsonKey(name: 'pdf_count')  int pdfCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BackupMetadata() when $default != null:
return $default(_that.version,_that.appVersion,_that.databaseVersion,_that.backupTime,_that.orderCount,_that.invoiceCount,_that.imageCount,_that.pdfCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String version, @JsonKey(name: 'app_version')  String appVersion, @JsonKey(name: 'database_version')  int databaseVersion, @JsonKey(name: 'backup_time')  String backupTime, @JsonKey(name: 'order_count')  int orderCount, @JsonKey(name: 'invoice_count')  int invoiceCount, @JsonKey(name: 'image_count')  int imageCount, @JsonKey(name: 'pdf_count')  int pdfCount)  $default,) {final _that = this;
switch (_that) {
case _BackupMetadata():
return $default(_that.version,_that.appVersion,_that.databaseVersion,_that.backupTime,_that.orderCount,_that.invoiceCount,_that.imageCount,_that.pdfCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String version, @JsonKey(name: 'app_version')  String appVersion, @JsonKey(name: 'database_version')  int databaseVersion, @JsonKey(name: 'backup_time')  String backupTime, @JsonKey(name: 'order_count')  int orderCount, @JsonKey(name: 'invoice_count')  int invoiceCount, @JsonKey(name: 'image_count')  int imageCount, @JsonKey(name: 'pdf_count')  int pdfCount)?  $default,) {final _that = this;
switch (_that) {
case _BackupMetadata() when $default != null:
return $default(_that.version,_that.appVersion,_that.databaseVersion,_that.backupTime,_that.orderCount,_that.invoiceCount,_that.imageCount,_that.pdfCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BackupMetadata implements BackupMetadata {
  const _BackupMetadata({this.version = '1.0', @JsonKey(name: 'app_version') required this.appVersion, @JsonKey(name: 'database_version') required this.databaseVersion, @JsonKey(name: 'backup_time') required this.backupTime, @JsonKey(name: 'order_count') this.orderCount = 0, @JsonKey(name: 'invoice_count') this.invoiceCount = 0, @JsonKey(name: 'image_count') this.imageCount = 0, @JsonKey(name: 'pdf_count') this.pdfCount = 0});
  factory _BackupMetadata.fromJson(Map<String, dynamic> json) => _$BackupMetadataFromJson(json);

/// Backup format version
@override@JsonKey() final  String version;
/// App version that created the backup
@override@JsonKey(name: 'app_version') final  String appVersion;
/// Database version that created the backup
@override@JsonKey(name: 'database_version') final  int databaseVersion;
/// Backup creation time (ISO 8601 format)
@override@JsonKey(name: 'backup_time') final  String backupTime;
/// Number of orders in the backup
@override@JsonKey(name: 'order_count') final  int orderCount;
/// Number of invoices in the backup
@override@JsonKey(name: 'invoice_count') final  int invoiceCount;
/// Number of images in the backup
@override@JsonKey(name: 'image_count') final  int imageCount;
/// Number of PDFs in the backup
@override@JsonKey(name: 'pdf_count') final  int pdfCount;

/// Create a copy of BackupMetadata
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BackupMetadataCopyWith<_BackupMetadata> get copyWith => __$BackupMetadataCopyWithImpl<_BackupMetadata>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BackupMetadataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BackupMetadata&&(identical(other.version, version) || other.version == version)&&(identical(other.appVersion, appVersion) || other.appVersion == appVersion)&&(identical(other.databaseVersion, databaseVersion) || other.databaseVersion == databaseVersion)&&(identical(other.backupTime, backupTime) || other.backupTime == backupTime)&&(identical(other.orderCount, orderCount) || other.orderCount == orderCount)&&(identical(other.invoiceCount, invoiceCount) || other.invoiceCount == invoiceCount)&&(identical(other.imageCount, imageCount) || other.imageCount == imageCount)&&(identical(other.pdfCount, pdfCount) || other.pdfCount == pdfCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,version,appVersion,databaseVersion,backupTime,orderCount,invoiceCount,imageCount,pdfCount);

@override
String toString() {
  return 'BackupMetadata(version: $version, appVersion: $appVersion, databaseVersion: $databaseVersion, backupTime: $backupTime, orderCount: $orderCount, invoiceCount: $invoiceCount, imageCount: $imageCount, pdfCount: $pdfCount)';
}


}

/// @nodoc
abstract mixin class _$BackupMetadataCopyWith<$Res> implements $BackupMetadataCopyWith<$Res> {
  factory _$BackupMetadataCopyWith(_BackupMetadata value, $Res Function(_BackupMetadata) _then) = __$BackupMetadataCopyWithImpl;
@override @useResult
$Res call({
 String version,@JsonKey(name: 'app_version') String appVersion,@JsonKey(name: 'database_version') int databaseVersion,@JsonKey(name: 'backup_time') String backupTime,@JsonKey(name: 'order_count') int orderCount,@JsonKey(name: 'invoice_count') int invoiceCount,@JsonKey(name: 'image_count') int imageCount,@JsonKey(name: 'pdf_count') int pdfCount
});




}
/// @nodoc
class __$BackupMetadataCopyWithImpl<$Res>
    implements _$BackupMetadataCopyWith<$Res> {
  __$BackupMetadataCopyWithImpl(this._self, this._then);

  final _BackupMetadata _self;
  final $Res Function(_BackupMetadata) _then;

/// Create a copy of BackupMetadata
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? version = null,Object? appVersion = null,Object? databaseVersion = null,Object? backupTime = null,Object? orderCount = null,Object? invoiceCount = null,Object? imageCount = null,Object? pdfCount = null,}) {
  return _then(_BackupMetadata(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,appVersion: null == appVersion ? _self.appVersion : appVersion // ignore: cast_nullable_to_non_nullable
as String,databaseVersion: null == databaseVersion ? _self.databaseVersion : databaseVersion // ignore: cast_nullable_to_non_nullable
as int,backupTime: null == backupTime ? _self.backupTime : backupTime // ignore: cast_nullable_to_non_nullable
as String,orderCount: null == orderCount ? _self.orderCount : orderCount // ignore: cast_nullable_to_non_nullable
as int,invoiceCount: null == invoiceCount ? _self.invoiceCount : invoiceCount // ignore: cast_nullable_to_non_nullable
as int,imageCount: null == imageCount ? _self.imageCount : imageCount // ignore: cast_nullable_to_non_nullable
as int,pdfCount: null == pdfCount ? _self.pdfCount : pdfCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on

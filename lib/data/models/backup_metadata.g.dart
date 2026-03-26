// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backup_metadata.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BackupMetadata _$BackupMetadataFromJson(Map<String, dynamic> json) =>
    _BackupMetadata(
      version: json['version'] as String? ?? '1.0',
      appVersion: json['app_version'] as String,
      databaseVersion: (json['database_version'] as num).toInt(),
      backupTime: json['backup_time'] as String,
      orderCount: (json['order_count'] as num?)?.toInt() ?? 0,
      invoiceCount: (json['invoice_count'] as num?)?.toInt() ?? 0,
      imageCount: (json['image_count'] as num?)?.toInt() ?? 0,
      pdfCount: (json['pdf_count'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$BackupMetadataToJson(_BackupMetadata instance) =>
    <String, dynamic>{
      'version': instance.version,
      'app_version': instance.appVersion,
      'database_version': instance.databaseVersion,
      'backup_time': instance.backupTime,
      'order_count': instance.orderCount,
      'invoice_count': instance.invoiceCount,
      'image_count': instance.imageCount,
      'pdf_count': instance.pdfCount,
    };

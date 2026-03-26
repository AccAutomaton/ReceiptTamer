import 'package:freezed_annotation/freezed_annotation.dart';

part 'backup_metadata.freezed.dart';
part 'backup_metadata.g.dart';

/// Backup metadata model
/// Contains information about the backup for version compatibility checking
@freezed
abstract class BackupMetadata with _$BackupMetadata {
  const factory BackupMetadata({
    /// Backup format version
    @Default('1.0') String version,

    /// App version that created the backup
    @JsonKey(name: 'app_version') required String appVersion,

    /// Database version that created the backup
    @JsonKey(name: 'database_version') required int databaseVersion,

    /// Backup creation time (ISO 8601 format)
    @JsonKey(name: 'backup_time') required String backupTime,

    /// Number of orders in the backup
    @JsonKey(name: 'order_count') @Default(0) int orderCount,

    /// Number of invoices in the backup
    @JsonKey(name: 'invoice_count') @Default(0) int invoiceCount,

    /// Number of images in the backup
    @JsonKey(name: 'image_count') @Default(0) int imageCount,

    /// Number of PDFs in the backup
    @JsonKey(name: 'pdf_count') @Default(0) int pdfCount,
  }) = _BackupMetadata;

  factory BackupMetadata.fromJson(Map<String, dynamic> json) =>
      _$BackupMetadataFromJson(json);
}
/// 日志配置常量
class LogConfig {
  /// 模块标签
  static const String moduleApp = 'APP';
  static const String moduleDb = 'DB';
  static const String moduleOcr = 'OCR';
  static const String moduleLlm = 'LLM';
  static const String moduleFile = 'FILE';
  static const String moduleBackup = 'BACKUP';
  static const String moduleUpdate = 'UPDATE';
  static const String moduleShare = 'SHARE';
  static const String moduleUi = 'UI';

  /// 日志文件存储配置
  static const String logDirName = 'logs';
  static const String logFilePrefix = 'app_';
  static const String logFileExtension = '.log';
  static const int maxFileSize = 5 * 1024 * 1024; // 5MB
  static const int maxFiles = 10;
  static const int retentionDays = 7;
  static const int writeBufferSize = 100; // 批量写入缓冲大小

  /// 日志级别过滤（生产环境）
  /// DEBUG级别在生产环境会被过滤
  static const bool enableDebugInProduction = false;

  /// 导出配置
  static const String exportFilePrefix = 'logs_export_';
  static const int tapCountToTrigger = 10; // 连点次数触发导出
  static const int tapTimeoutMs = 500; // 点击间隔超时（毫秒）
}
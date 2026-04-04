import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'log_config.dart';
import 'package:receipt_tamer/data/services/file_service.dart';

/// 自定义日志打印器 - 统一格式
class AppLogPrinter extends LogPrinter {
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  @override
  List<String> log(LogEvent event) {
    final timestamp = _dateFormat.format(event.time);
    final level = _levelToString(event.level);
    final message = event.message;

    // 格式: [时间] [级别] [模块] 消息
    final formattedMessage = '[$timestamp] [$level] $message';

    // 如果有错误，添加错误信息
    if (event.error != null) {
      return [
        formattedMessage,
        'Error: ${event.error}',
        if (event.stackTrace != null) 'StackTrace: ${event.stackTrace}',
      ];
    }

    return [formattedMessage];
  }

  String _levelToString(Level level) {
    switch (level) {
      case Level.debug:
        return 'DEBUG';
      case Level.info:
        return 'INFO';
      case Level.warning:
        return 'WARN';
      case Level.error:
        return 'ERROR';
      case Level.fatal:
        return 'FATAL';
      case Level.trace:
        return 'TRACE';
      default:
        return 'UNKNOWN';
    }
  }
}

/// 文件输出器 - 支持按日期轮转和大小限制
class FileLogOutput extends LogOutput {
  final String? basePath;
  final int maxFileSize;
  final int maxFiles;
  final int retentionDays;
  final int bufferSize;

  File? _currentFile;
  int _currentFileSize = 0;
  String _currentDate = '';
  final List<String> _buffer = [];
  String? _logDirPath;

  FileLogOutput({
    this.basePath,
    this.maxFileSize = LogConfig.maxFileSize,
    this.maxFiles = LogConfig.maxFiles,
    this.retentionDays = LogConfig.retentionDays,
    this.bufferSize = LogConfig.writeBufferSize,
  });

  /// 初始化日志目录
  Future<void> initialize() async {
    if (basePath != null) {
      _logDirPath = basePath!;
    } else {
      // 使用应用内部存储目录
      final appDir = await getApplicationSupportDirectory();
      _logDirPath = path.join(appDir.path, LogConfig.logDirName);
    }

    // 创建日志目录
    final logDir = Directory(_logDirPath!);
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }

    // 清理过期日志
    await _cleanOldLogs();

    // 打开当前日志文件
    await _openCurrentFile();
  }

  @override
  void output(OutputEvent event) {
    for (final line in event.lines) {
      _buffer.add(line);

      // 达到缓冲大小时写入文件
      if (_buffer.length >= bufferSize) {
        _flushBuffer();
      }
    }
  }

  /// 刷新缓冲区到文件
  Future<void> flush() async {
    if (_buffer.isNotEmpty) {
      await _flushBuffer();
    }
  }

  Future<void> _flushBuffer() async {
    if (_currentFile == null || _buffer.isEmpty) return;

    // 检查日期轮转
    final today = _getDateString();
    if (today != _currentDate) {
      await _rotateFile(today);
    }

    // 检查大小轮转
    if (_currentFileSize > maxFileSize) {
      await _rotateFile(today);
    }

    // 写入文件
    final content = '${_buffer.join('\n')}\n';
    await _currentFile!.writeAsString(
      content,
      mode: FileMode.append,
      flush: false,
    );

    _currentFileSize += content.length;
    _buffer.clear();
  }

  /// 获取当前日期字符串
  String _getDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// 获取日志文件路径
  String _getLogFilePath(String dateStr) {
    return path.join(
      _logDirPath!,
      '${LogConfig.logFilePrefix}$dateStr${LogConfig.logFileExtension}',
    );
  }

  /// 打开当前日志文件
  Future<void> _openCurrentFile() async {
    final today = _getDateString();
    _currentDate = today;
    final filePath = _getLogFilePath(today);

    _currentFile = File(filePath);
    if (await _currentFile!.exists()) {
      _currentFileSize = await _currentFile!.length();
    } else {
      await _currentFile!.create();
      _currentFileSize = 0;
    }
  }

  /// 轮转日志文件
  Future<void> _rotateFile(String newDate) async {
    // 刷新当前缓冲
    await _flushBuffer();

    // 关闭当前文件
    _currentFile = null;
    _currentFileSize = 0;
    _currentDate = newDate;

    // 打开新文件
    await _openCurrentFile();

    // 检查文件数量限制
    await _enforceMaxFiles();
  }

  /// 清理过期日志
  Future<void> _cleanOldLogs() async {
    final logDir = Directory(_logDirPath!);
    if (!await logDir.exists()) return;

    final cutoffDate = DateTime.now().subtract(Duration(days: retentionDays));
    final files = await logDir.list().toList();

    for (final file in files) {
      if (file is File) {
        final fileName = path.basename(file.path);
        if (fileName.startsWith(LogConfig.logFilePrefix) &&
            fileName.endsWith(LogConfig.logFileExtension)) {
          // 解析日期
          final dateStr = fileName.substring(
            LogConfig.logFilePrefix.length,
            fileName.length - LogConfig.logFileExtension.length,
          );
          try {
            final fileDate = DateTime.parse(dateStr);
            if (fileDate.isBefore(cutoffDate)) {
              await file.delete();
            }
          } catch (_) {
            // 无法解析日期的文件，跳过
          }
        }
      }
    }
  }

  /// 强制文件数量限制
  Future<void> _enforceMaxFiles() async {
    final logDir = Directory(_logDirPath!);
    if (!await logDir.exists()) return;

    final files = await logDir
        .list()
        .where((f) =>
            f is File &&
            path.basename(f.path).startsWith(LogConfig.logFilePrefix))
        .toList();

    if (files.length > maxFiles) {
      // 按修改时间排序，删除最旧的
      files.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));

      final toDelete = files.length - maxFiles;
      for (var i = 0; i < toDelete; i++) {
        await files[i].delete();
      }
    }
  }

  /// 获取所有日志文件路径
  Future<List<String>> getLogFiles() async {
    final logDir = Directory(_logDirPath!);
    if (!await logDir.exists()) return [];

    final files = await logDir
        .list()
        .where((f) =>
            f is File &&
            path.basename(f.path).startsWith(LogConfig.logFilePrefix))
        .toList();

    return files.map((f) => f.path).toList();
  }

  /// 获取日志目录路径
  String? get logDirPath => _logDirPath;
}

/// 内存输出器 - 用于导出日志
class MemoryLogOutput extends LogOutput {
  final List<String> _logs = [];
  static const int _maxLogs = 10000; // 最大内存日志条数

  @override
  void output(OutputEvent event) {
    for (final line in event.lines) {
      _logs.add(line);
    }

    // 限制内存大小
    if (_logs.length > _maxLogs) {
      _logs.removeRange(0, _logs.length - _maxLogs);
    }
  }

  /// 获取所有内存日志
  List<String> getLogs() => List.unmodifiable(_logs);

  /// 清空内存日志
  void clear() => _logs.clear();
}

/// 统一日志服务
class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  /// MethodChannel用于接收Android原生层日志
  static const MethodChannel _channel = MethodChannel('com.acautomaton.receipt.tamer/log');

  late final Logger _logger;
  late final FileLogOutput _fileOutput;
  late final MemoryLogOutput _memoryOutput;
  bool _initialized = false;

  /// 是否已初始化
  bool get isInitialized => _initialized;

  /// 初始化日志服务
  Future<void> initialize() async {
    if (_initialized) return;

    // 创建输出器
    _fileOutput = FileLogOutput();
    await _fileOutput.initialize();

    _memoryOutput = MemoryLogOutput();

    // 配置Logger
    _logger = Logger(
      filter: kDebugMode
          ? DevelopmentFilter()
          : ProductionFilter(),
      printer: AppLogPrinter(),
      output: MultiOutput([
        ConsoleOutput(),
        _fileOutput,
        _memoryOutput,
      ]),
    );

    // 设置MethodChannel处理器，接收Android层日志
    _channel.setMethodCallHandler(_handleMethodCall);

    _initialized = true;
    i(LogConfig.moduleApp, 'LogService initialized');
  }

  /// 处理来自Android原生层的MethodChannel调用
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'writeLog':
        final args = call.arguments as Map<dynamic, dynamic>;
        final level = args['level'] as String?;
        final module = args['module'] as String?;
        final message = args['message'] as String?;
        final error = args['error'] as String?;
        final stackTrace = args['stackTrace'] as String?;

        if (module != null && message != null) {
          _writeNativeLog(level ?? 'I', module, message, error, stackTrace);
        }
        break;
    }
  }

  /// 写入来自Android原生层的日志
  void _writeNativeLog(
    String level,
    String module,
    String message,
    String? error,
    String? stackTrace,
  ) {
    final formattedMessage = error != null ? '$message | Error: $error' : message;
    final fullMessage = stackTrace != null ? '$formattedMessage\n$stackTrace' : formattedMessage;

    switch (level.toUpperCase()) {
      case 'D':
        _logger.d('[$module] $fullMessage');
        break;
      case 'I':
        _logger.i('[$module] $fullMessage');
        break;
      case 'W':
        _logger.w('[$module] $fullMessage');
        break;
      case 'E':
        _logger.e('[$module] $fullMessage');
        break;
      default:
        _logger.i('[$module] $fullMessage');
    }
  }

  /// 刷新日志缓冲区
  Future<void> flush() async {
    await _fileOutput.flush();
  }

  /// DEBUG级别日志
  void d(String module, String message) {
    _logger.d('[$module] $message');
  }

  /// INFO级别日志
  void i(String module, String message) {
    _logger.i('[$module] $message');
  }

  /// WARN级别日志
  void w(String module, String message) {
    _logger.w('[$module] $message');
  }

  /// ERROR级别日志
  void e(String module, String message, [Object? error, StackTrace? stackTrace]) {
    _logger.e('[$module] $message', error: error, stackTrace: stackTrace);
  }

  /// 诊断日志（DEBUG级别，带DIAG标签）
  void diag(String module, String metric, dynamic value) {
    _logger.d('[$module] [DIAG] $metric: $value');
  }

  /// 批量诊断日志
  void diagBatch(String module, Map<String, dynamic> metrics) {
    for (final entry in metrics.entries) {
      diag(module, entry.key, entry.value);
    }
  }

  /// 导出日志到Download目录
  Future<String?> exportLogs() async {
    if (!_initialized) return null;

    try {
      i(LogConfig.moduleApp, 'Starting log export');

      // 刷新文件缓冲
      await _fileOutput.flush();

      // 收集日志文件
      final logFiles = await _fileOutput.getLogFiles();

      // 生成系统信息
      final systemInfo = await _generateSystemInfo();

      // 创建ZIP文件
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final zipFileName = '${LogConfig.exportFilePrefix}$timestamp.zip';

      // 创建临时ZIP文件
      final tempDir = await getTemporaryDirectory();
      final zipPath = path.join(tempDir.path, zipFileName);

      // 创建ZIP归档
      final archive = Archive();

      // 添加日志文件
      for (final logFilePath in logFiles) {
        final file = File(logFilePath);
        if (await file.exists()) {
          final content = await file.readAsBytes();
          final fileName = path.basename(logFilePath);
          archive.addFile(ArchiveFile(fileName, content.length, content));
        }
      }

      // 添加系统信息文件
      final systemInfoBytes = systemInfo.codeUnits;
      archive.addFile(
        ArchiveFile('system_info.json', systemInfoBytes.length, systemInfoBytes),
      );

      // 编码ZIP
      final zipData = ZipEncoder().encode(archive);
      if (zipData == null) {
        e(LogConfig.moduleApp, 'Failed to encode ZIP archive');
        return null;
      }

      // 写入临时文件
      await File(zipPath).writeAsBytes(zipData);

      // 保存到Download目录
      final fileService = FileService();
      final savedPath = await fileService.saveToDownloadDirectory(
        fileName: zipFileName,
        bytes: zipData,
        subDir: LogConfig.logDirName,
      );

      if (savedPath != null) {
        i(LogConfig.moduleApp, 'Logs exported to: $savedPath');
      }

      return savedPath;
    } catch (ex, stackTrace) {
      e(LogConfig.moduleApp, 'Failed to export logs', ex, stackTrace);
      return null;
    }
  }

  /// 生成系统信息JSON
  Future<String> _generateSystemInfo() async {
    final info = <String, dynamic>{
      'export_time': DateTime.now().toIso8601String(),
      'platform': Platform.operatingSystem,
      'platform_version': Platform.operatingSystemVersion,
      'dart_version': Platform.version,
      'is_release': kReleaseMode,
      'is_debug': kDebugMode,
    };

    return const JsonEncoder.withIndent('  ').convert(info);
  }

  /// 清除所有日志文件
  Future<bool> clearLogs() async {
    if (!_initialized) return false;

    try {
      await _fileOutput.flush();

      final logDir = Directory(_fileOutput.logDirPath!);
      if (await logDir.exists()) {
        await logDir.delete(recursive: true);
        await logDir.create(recursive: true);
      }

      _memoryOutput.clear();

      i(LogConfig.moduleApp, 'All logs cleared');
      return true;
    } catch (ex, stackTrace) {
      e(LogConfig.moduleApp, 'Failed to clear logs', ex, stackTrace);
      return false;
    }
  }
}

/// 导出全局日志服务实例
final logService = LogService();
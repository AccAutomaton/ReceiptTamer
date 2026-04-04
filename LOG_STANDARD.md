# ReceiptTamer 日志规范

本文档定义了 ReceiptTamer 项目的日志输出规范，所有开发人员应遵循此规范进行日志记录。

---

## 1. 日志框架

本项目使用 `logger` 包作为统一日志框架。

**核心文件**：
- `lib/core/services/log_service.dart` - 统一日志服务
- `lib/core/services/log_config.dart` - 日志配置常量

**使用方式**：
```dart
import '../../core/services/log_service.dart';
import '../../core/services/log_config.dart';

// 基本用法
logService.i(LogConfig.moduleDb, 'Order created: id=123');
logService.e(LogConfig.moduleOcr, 'Recognition failed', error, stackTrace);

// 诊断日志
logService.diag(LogConfig.moduleLlm, 'Processing time', '1250ms');
```

---

## 2. 日志级别

| 级别 | 方法 | 使用场景 | 示例 |
|------|------|---------|------|
| **DEBUG** | `logService.d()` | 详细调试信息，仅开发阶段可见 | 变量值、流程追踪 |
| **INFO** | `logService.i()` | 正常运行状态信息 | 初始化完成、操作成功 |
| **WARN** | `logService.w()` | 潜在问题警告，不影响运行 | 重试操作、兼容性提示 |
| **ERROR** | `logService.e()` | 错误事件，需要关注 | 操作失败、异常捕获 |
| **DIAG** | `logService.diag()` | 性能诊断数据 | 执行时间、数据量 |

---

## 3. 日志格式

### 标准格式

```
[YYYY-MM-DD HH:mm:ss] [级别] [模块] 消息内容
```

### 示例

```
[2026-04-04 14:30:15] [INFO] [DB] Order created: id=123, shop="美团外卖"
[2026-04-04 14:30:16] [ERROR] [OCR] Recognition failed: timeout
[2026-04-04 14:30:17] [DIAG] [LLM] Extraction time: 1250ms
```

### 诊断日志格式

诊断日志用于记录性能指标和技术调试数据：

```dart
logService.diag(LogConfig.moduleLlm, 'Processing time', '${stopwatch.elapsedMilliseconds}ms');
logService.diag(LogConfig.moduleOcr, 'Text blocks', textBlocks.length);
```

---

## 4. 模块标签

使用 `LogConfig` 中定义的模块标签：

| 标签 | 常量 | 模块 |
|------|------|------|
| `APP` | `LogConfig.moduleApp` | 应用入口/生命周期 |
| `DB` | `LogConfig.moduleDb` | 数据库操作 |
| `OCR` | `LogConfig.moduleOcr` | OCR识别 |
| `LLM` | `LogConfig.moduleLlm` | LLM推理 |
| `FILE` | `LogConfig.moduleFile` | 文件服务 |
| `BACKUP` | `LogConfig.moduleBackup` | 备份还原 |
| `UPDATE` | `LogConfig.moduleUpdate` | 版本更新 |
| `SHARE` | `LogConfig.moduleShare` | 分享处理 |
| `UI` | `LogConfig.moduleUi` | 界面交互 |

---

## 5. 日志记录最佳实践

### 5.1 数据库操作

```dart
// 插入
logService.i(LogConfig.moduleDb, 'Order inserted: id=$id, shop="$shopName"');

// 更新
logService.i(LogConfig.moduleDb, 'Order updated: id=$id, rowsAffected=$count');

// 删除
logService.i(LogConfig.moduleDb, 'Order deleted: id=$id, rowsAffected=$count');

// 初始化/升级
logService.i(LogConfig.moduleDb, 'Database initialized, version: $version');
```

### 5.2 OCR/LLM 处理

```dart
// Pipeline 开始
logService.i(LogConfig.moduleOcr, '========== OCR Pipeline Start ==========');

// 诊断信息
logService.diag(LogConfig.moduleOcr, 'Image size', '${bytes.length} bytes');
logService.diag(LogConfig.moduleOcr, 'Recognition time', '${time}ms');

// 错误处理
logService.e(LogConfig.moduleOcr, 'Recognition failed', error, stackTrace);
```

### 5.3 文件操作

```dart
// 导出成功
logService.i(LogConfig.moduleFile, 'File exported: $filePath');

// 下载进度（关键节点）
logService.i(LogConfig.moduleUpdate, 'Download complete: $filePath');
```

### 5.4 错误处理

```dart
// 带异常栈的错误日志
logService.e(LogConfig.moduleDb, 'Database operation failed', error, stackTrace);

// 简单错误
logService.w(LogConfig.moduleOcr, 'Model not available, using fallback');
```

---

## 6. 文件存储

### 存储路径

```
Download/ReceiptTamer/logs/
├── app_2026-04-04.log      # 当天日志
├── app_2026-04-03.log      # 昨天日志
└── ...
```

### 轮转策略

| 参数 | 值 |
|------|---|
| 单文件大小限制 | 5MB |
| 保留天数 | 7天 |
| 最大文件数 | 10个 |
| 写入缓冲 | 100条异步批量写入 |

---

## 7. 日志导出

### 触发方式

在设置页面连点应用图标 **10次**（每次间隔不超过500ms）触发日志导出。

### 导出内容

导出ZIP文件包含：
- 所有日志文件（`app_*.log`）
- `system_info.json` - 设备信息、应用版本

### 导出路径

```
Download/ReceiptTamer/logs/logs_export_20260404_143015.zip
```

---

## 8. Android 原生层日志

### 统一存储

Android原生层日志通过MethodChannel异步发送到Flutter层，与Flutter日志**统一写入同一个文件**，格式完全一致。

**注意**：Android层日志不再直接输出到Logcat，而是通过Flutter层统一输出到控制台。在开发调试时，可在Flutter运行的终端中查看所有日志。

### 格式说明

存储到文件的格式与Flutter层一致：

```
[YYYY-MM-DD HH:mm:ss] [级别] [模块] 消息
```

**示例**：
```
[2026-04-04 14:30:15] [INFO] [OCR] Recognition started
[2026-04-04 14:30:16] [ERROR] [LLM] Model load failed
```

### 模块标签

与Flutter层使用相同的模块标签：

| 模块 | 标签 | 说明 |
|------|------|------|
| 应用生命周期 | `APP` | Activity生命周期、应用初始化 |
| OCR识别 | `OCR` | OCR引擎初始化和识别 |
| LLM推理 | `LLM` | MNN模型加载和推理 |
| 文件服务 | `FILE` | 文件下载、保存、分享 |

### Kotlin 层

使用 `LogHelper` 统一封装：

```kotlin
import com.acautomaton.receipt.tamer.LogHelper

LogHelper.i("OCR", "Recognition started")
LogHelper.e("LLM", "Model load failed", exception)
LogHelper.diag("OCR", "Processing time", "${time}ms")
```

### C++ 层

C++层日志通过异步桥接机制发送到Flutter层：

**机制说明**：
- 日志先进入缓冲队列，后台线程批量发送
- 通过JNI调用 `LogReceiver.receiveLog()` 转发到Kotlin层
- 最终通过 `LogHelper` 发送到Flutter层统一写入文件
- 同时输出到Logcat便于开发调试

**使用方式**：
```cpp
// 使用现有宏定义（自动桥接到Flutter）
LOGI("Model loaded successfully");
LOGE("Failed to load model");
LOGD("Debug info: %s", value);

// 模块标签固定为 "LLM"
// 格式：[时间] [级别] [LLM] 消息
```

**注意事项**：
- 日志通过异步队列发送，避免JNI调用阻塞推理线程
- 批量发送（每10条或100ms）减少性能开销
- 消息长度限制512字符，超出部分会被截断

---

## 9. 注意事项

1. **不要记录敏感信息**：避免记录用户密码、密钥等敏感数据
2. **控制日志量**：避免在循环中频繁记录日志
3. **使用正确级别**：DEBUG仅用于开发调试，INFO用于正常状态，ERROR用于错误
4. **包含上下文**：日志消息应包含足够的上下文信息便于问题定位
5. **异常必须带栈**：ERROR级别日志如有异常必须包含堆栈信息

---

## 10. 日志配置

配置项位于 `lib/core/services/log_config.dart`：

```dart
class LogConfig {
  // 模块标签
  static const String moduleApp = 'APP';
  static const String moduleDb = 'DB';
  // ...

  // 存储配置
  static const int maxFileSize = 5 * 1024 * 1024; // 5MB
  static const int maxFiles = 10;
  static const int retentionDays = 7;

  // 导出触发
  static const int tapCountToTrigger = 10;
  static const int tapTimeoutMs = 500;
}
```

---

## 11. 日志语言规范

本项目日志消息采用**中文**记录，便于开发调试和问题排查。

### 翻译原则

| 类别 | 处理方式 | 示例 |
|------|---------|------|
| **技术术语** | 保持英文 | OCR, LLM, PDF, JSON, APK, MNN, Pipeline, Prompt, Token, MethodChannel, Activity, Intent |
| **专有名词** | 保持英文 | Flutter, Android, Kotlin, GitHub, Asset, Logcat |
| **变量/常量名** | 保持英文 | modelDir, configPath, maxTokens, temperature |
| **包名/类名** | 保持英文 | MnnEngine, LogHelper, OrderRepository |
| **动词/状态词** | 翻译为中文 | loaded → 已加载, failed → 失败, started → 已开始 |
| **描述性文字** | 翻译为中文 | "Model loaded successfully" → "模型加载成功" |

### 翻译示例

| 原文 | 中文翻译 |
|------|---------|
| `Model loaded successfully` | `模型加载成功` |
| `Failed to load model` | `模型加载失败` |
| `Creating MNN LLM instance...` | `正在创建 MNN LLM 实例...` |
| `Config file not found: %s` | `配置文件未找到: %s` |
| `Order inserted: id=$id` | `订单已插入: id=$id` |
| `Share handler initialized` | `分享处理器初始化完成` |
| `Database initialized, version: $version` | `数据库初始化完成, 版本: $version` |

### 特殊说明

1. **诊断日志**：`[DIAG]` 标签保持不变，后面的描述可翻译
2. **格式化字符串**：保持 `%s`, `%d`, `%zu` 等格式化占位符不变
3. **分隔线**：`========== MNN LLM Pipeline Start ==========` 可翻译为 `========== MNN LLM Pipeline 开始 ==========`
4. **错误消息**：返回给用户的错误消息（如 JSON 中的 error 字段）可翻译为中文
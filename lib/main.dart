import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/services/log_service.dart';
import 'core/services/log_config.dart';

void main() async {
  // 确保 Flutter 绑定初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化日志服务（必须在任何其他服务初始化之前）
  await logService.initialize();

  logService.i(LogConfig.moduleApp, 'Flutter 应用启动');

  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}

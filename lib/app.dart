import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/log_service.dart';
import 'core/services/log_config.dart';
import 'data/services/share_handler_service.dart';
import 'presentation/providers/ocr_provider.dart';

/// The root widget of the application.
/// Wraps the app with ProviderScope for Riverpod state management.
class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  final ShareHandlerService _shareHandlerService = ShareHandlerService();
  bool _initialized = false;
  bool _navigating = false;

  /// 不需要自动导航到分享页面的路由
  static const _skipAutoNavigateRoutes = {
    '/share',
    '/orders/new',
    '/invoices/new',
  };

  @override
  void initState() {
    super.initState();
    logService.d(LogConfig.moduleApp, 'App initState');
    // LogService 已在 main.dart 中初始化
    // 使用 addPostFrameCallback 确保首帧渲染完成后再初始化其他服务
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _delayedInitialize();
    });
  }

  Future<void> _delayedInitialize() async {
    // 首帧已渲染完成，现在可以安全地进行后台初始化
    await Future.delayed(const Duration(milliseconds: 100));

    // 开始后台初始化OCR/LLM模型（不阻塞UI）
    _startOcrBackgroundInitialization();

    // 初始化分享处理器
    await Future.delayed(const Duration(milliseconds: 200));
    _initializeShareHandler();
  }

  /// 在后台初始化OCR，不阻塞UI
  void _startOcrBackgroundInitialization() {
    Future.delayed(const Duration(milliseconds: 50), () async {
      try {
        logService.i(LogConfig.moduleApp, '开始 OCR 后台初始化...');
        // 触发OCR初始化，但不等待完成
        ref.read(ocrProvider.notifier).initialize();
      } catch (e, stackTrace) {
        logService.e(LogConfig.moduleApp, 'OCR 后台初始化错误', e, stackTrace);
      }
    });
  }

  Future<void> _initializeShareHandler() async {
    if (_initialized) return;

    try {
      logService.i(LogConfig.moduleApp, '初始化分享处理器...');
      await _shareHandlerService.initialize();
      _initialized = true;

      // Listen for shared media events
      _shareHandlerService.sharedMediaNotifier.addListener(_onSharedMedia);

      // Check if there's already pending shared media (app launched via share)
      _onSharedMedia();
      logService.i(LogConfig.moduleApp, '分享处理器初始化完成');
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleApp, '初始化分享处理器失败', e, stackTrace);
    }
  }

  void _onSharedMedia() {
    if (!mounted || _navigating) return;

    final sharedMedia = _shareHandlerService.sharedMediaNotifier.value;
    logService.i(LogConfig.moduleApp, 'onSharedMedia 调用，hasMedia: ${sharedMedia != null && sharedMedia.isNotEmpty}');

    if (sharedMedia != null && sharedMedia.isNotEmpty) {
      // 检查当前路由是否需要跳过自动导航
      final router = ref.read(routerProvider);
      final currentLocation = router.routerDelegate.currentConfiguration.uri.toString();
      logService.i(LogConfig.moduleApp, '当前位置: $currentLocation');

      // 如果当前已经在分享相关页面，不自动导航
      if (_skipAutoNavigateRoutes.any((route) => currentLocation.startsWith(route))) {
        logService.i(LogConfig.moduleApp, '跳过自动导航，已在 $currentLocation');
        return;
      }

      _navigating = true;
      // Use WidgetsBinding to ensure we're not in a build phase
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          logService.i(LogConfig.moduleApp, '导航到 /share，共 ${sharedMedia.length} 项');
          router.go('/share');
        } catch (e, stackTrace) {
          logService.e(LogConfig.moduleApp, '导航到分享页面失败', e, stackTrace);
        } finally {
          _navigating = false;
        }
      });
    }
  }

  @override
  void dispose() {
    logService.d(LogConfig.moduleApp, 'App dispose');
    _shareHandlerService.sharedMediaNotifier.removeListener(_onSharedMedia);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'ReceiptTamer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      // 本地化配置 - 支持中文
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'), // 中文（简体）
        Locale('zh', 'TW'), // 中文（繁体）
        Locale('en', 'US'), // 英文（备用）
      ],
      locale: const Locale('zh', 'CN'), // 默认中文
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ReceiptTamer 的系统栏显示约定。
///
/// 页面内容延伸到状态栏和手势导航区域，系统图标则跟随浅色/暗色主题切换。
/// Android 10+ 的系统栏对比度遮罩会被关闭，避免透明导航栏被 ROM
/// 重新绘制成独立的黑色或灰色底带。
abstract final class AppSystemUi {
  static Future<void> configureForStartup(Brightness brightness) async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(overlayStyleFor(brightness));
  }

  static SystemUiOverlayStyle overlayStyleFor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    );
  }
}

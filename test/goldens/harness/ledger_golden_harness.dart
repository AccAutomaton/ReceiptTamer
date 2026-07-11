import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/core/theme/app_theme.dart';

const Key ledgerGoldenBoundaryKey = ValueKey('ledger_golden_boundary');

Future<void> loadLedgerGoldenFonts() async {
  const fonts = <String, String>{
    'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    'NotoSerifSC': 'assets/fonts/NotoSerifSC-VF.ttf',
    'NotoSansSC': 'assets/fonts/NotoSansSC-VF.ttf',
    'MiSans': 'assets/fonts/MiSans-Medium.ttf',
    'CourierPrime': 'assets/fonts/CourierPrime-Regular.ttf',
  };
  for (final entry in fonts.entries) {
    final loader = FontLoader(entry.key)..addFont(rootBundle.load(entry.value));
    await loader.load();
  }
}

class LedgerGoldenVariant {
  const LedgerGoldenVariant({
    required this.id,
    required this.size,
    required this.brightness,
    required this.textScale,
  });

  final String id;
  final Size size;
  final Brightness brightness;
  final double textScale;

  bool get isDark => brightness == Brightness.dark;

  String get fileStem => '$id-${isDark ? 'dark' : 'light'}-$textScale';
}

abstract final class LedgerGoldenVariants {
  static const androidRegularLight = LedgerGoldenVariant(
    id: 'android_regular',
    size: Size(412, 915),
    brightness: Brightness.light,
    textScale: 1,
  );

  static const androidCompactLightLarge = LedgerGoldenVariant(
    id: 'android_compact',
    size: Size(360, 800),
    brightness: Brightness.light,
    textScale: 1.3,
  );

  static const androidRegularDarkAccessible = LedgerGoldenVariant(
    id: 'android_regular',
    size: Size(412, 915),
    brightness: Brightness.dark,
    textScale: 2,
  );

  static const representative = [
    androidRegularLight,
    androidCompactLightLarge,
    androidRegularDarkAccessible,
  ];
}

extension LedgerGoldenTester on WidgetTester {
  Future<void> pumpLedgerGolden({
    required Widget child,
    required LedgerGoldenVariant variant,
  }) async {
    view.physicalSize = variant.size;
    view.devicePixelRatio = 1;

    await pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: variant.isDark ? ThemeMode.dark : ThemeMode.light,
        builder: (context, appChild) {
          final media = MediaQuery.of(context).copyWith(
            disableAnimations: true,
            platformBrightness: variant.brightness,
            textScaler: TextScaler.linear(variant.textScale),
          );
          return MediaQuery(data: media, child: appChild!);
        },
        home: RepaintBoundary(key: ledgerGoldenBoundaryKey, child: child),
      ),
    );
  }

  Future<void> settleLedgerGolden() async {
    // Avoid pumpAndSettle: some production screens own refresh/ticker objects.
    // Reduced motion plus a bounded number of frames is deterministic and
    // catches accidental continuous animation in the screenshot harness.
    await pump();
    await pump(const Duration(milliseconds: 1));
    await pump(const Duration(milliseconds: 20));
  }

  void resetLedgerGoldenView() {
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  }
}

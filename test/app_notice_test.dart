import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/core/theme/app_theme.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_notice.dart';

void main() {
  tearDown(AppNotice.dismiss);

  testWidgets('通知使用报销联动纸签样式并固定显示在顶部', (tester) async {
    late BuildContext noticeContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              noticeContext = context;
              return const Center(child: Text('页面内容'));
            },
          ),
        ),
      ),
    );

    AppNotice.show(
      noticeContext,
      '另有 2 笔同票订单一并选中',
      tone: AppNoticeTone.linkage,
    );
    await tester.pump();
    await tester.pump(AppMotion.standard);

    final notice = find.byKey(const ValueKey('app-notice'));
    expect(notice, findsOneWidget);
    expect(find.text('另有 2 笔同票订单一并选中'), findsOneWidget);
    expect(find.byIcon(Icons.link_rounded), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.getTopLeft(notice).dy, 6);

    final material = tester.widget<Material>(notice);
    expect(material.elevation, 0);
    expect(material.color, isNot(AppPalette.actionPrimary));
    final shape = material.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(AppRadii.control));
    expect(shape.side, isNot(BorderSide.none));
  });

  testWidgets('成功错误和联动通知共享纸签且新消息替换旧消息', (tester) async {
    late BuildContext noticeContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) {
            noticeContext = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );

    AppNotice.success(noticeContext, '保存成功');
    await tester.pump();
    await tester.pump(AppMotion.standard);
    final successMaterial = tester.widget<Material>(
      find.byKey(const ValueKey('app-notice')),
    );
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);

    AppNotice.error(noticeContext, '保存失败');
    await tester.pump();
    await tester.pump(AppMotion.standard);

    expect(find.text('保存成功'), findsNothing);
    expect(find.text('保存失败'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    final errorMaterial = tester.widget<Material>(
      find.byKey(const ValueKey('app-notice')),
    );
    expect(errorMaterial.color, successMaterial.color);
    expect(errorMaterial.shape, successMaterial.shape);
  });

  testWidgets('带操作的顶部通知可点击并在执行后收起', (tester) async {
    late BuildContext noticeContext;
    var actionCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) {
            noticeContext = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );

    AppNotice.success(
      noticeContext,
      '日志已导出',
      actionLabel: '查看',
      onAction: () => actionCount += 1,
    );
    await tester.pump();
    await tester.pump(AppMotion.standard);

    final action = find.text('查看');
    expect(action, findsOneWidget);
    expect(
      tester.getSize(find.byType(TextButton)).height,
      greaterThanOrEqualTo(48),
    );

    await tester.tap(action);
    await tester.tap(action);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(actionCount, 1);
    expect(find.byKey(const ValueKey('app-notice')), findsNothing);
  });

  testWidgets('宿主 Overlay 销毁时通知会安全释放', (tester) async {
    late BuildContext noticeContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            noticeContext = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );

    AppNotice.info(noticeContext, '即将销毁');
    await tester.pump();
    await tester.pumpWidget(const SizedBox.expand());
    await tester.pump();

    AppNotice.dismiss();
    expect(tester.takeException(), isNull);
  });

  testWidgets('来源路由已退出时可直接向存活的 Overlay 显示通知', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox.expand()),
      ),
    );

    final overlay = navigatorKey.currentState!.overlay!;
    expect(Overlay.maybeOf(overlay.context, rootOverlay: true), isNull);
    AppNotice.showOnOverlay(overlay, '部分文件导出失败', tone: AppNoticeTone.error);
    await tester.pump();

    expect(find.text('部分文件导出失败'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
  });

  testWidgets('普通通知会按统一时长自动收起', (tester) async {
    expect(AppNotice.defaultDuration, const Duration(seconds: 4));
    expect(AppNotice.linkageDuration, const Duration(milliseconds: 1800));

    late BuildContext noticeContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) {
            noticeContext = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );

    AppNotice.info(noticeContext, '再次返回回到桌面');
    await tester.pump();
    await tester.pump(AppMotion.standard);
    expect(find.byKey(const ValueKey('app-notice')), findsOneWidget);

    await tester.pump(AppNotice.defaultDuration);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-notice')), findsNothing);
  });

  testWidgets('快速替换后旧计时器不会移除新通知', (tester) async {
    late BuildContext noticeContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) {
            noticeContext = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );

    AppNotice.info(
      noticeContext,
      '旧通知',
      duration: const Duration(milliseconds: 300),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    AppNotice.warning(
      noticeContext,
      '新通知',
      duration: const Duration(seconds: 2),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('旧通知'), findsNothing);
    expect(find.text('新通知'), findsOneWidget);
  });

  testWidgets('通知在来源页面退出后仍完成反馈', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    late BuildContext routeContext;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: Text('首页')),
      ),
    );

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (context) {
          routeContext = context;
          return const Scaffold(body: Text('编辑页'));
        },
      ),
    );
    await tester.pumpAndSettle();

    AppNotice.success(routeContext, '保存成功');
    await tester.pump();
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsOneWidget);
    expect(find.text('保存成功'), findsOneWidget);
  });

  testWidgets('分支导航隐藏后通知仍显示在根 Overlay', (tester) async {
    late BuildContext branchContext;
    late StateSetter updateHost;
    var branchHidden = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            updateHost = setState;
            return Offstage(
              offstage: branchHidden,
              child: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (context) {
                    branchContext = context;
                    return const Scaffold(body: Text('分支页面'));
                  },
                ),
              ),
            );
          },
        ),
      ),
    );

    updateHost(() => branchHidden = true);
    await tester.pump();
    AppNotice.info(branchContext, '跨分支反馈');
    await tester.pump();

    expect(find.text('分支页面'), findsNothing);
    expect(find.text('跨分支反馈'), findsOneWidget);
  });

  testWidgets('暗色大字和减少动态效果下仍可读且不溢出', (tester) async {
    late BuildContext noticeContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            textScaler: const TextScaler.linear(2),
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) {
            noticeContext = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );

    AppNotice.error(noticeContext, '这是一条用于验证暗色大字布局的错误提示');
    await tester.pump();

    final notice = find.byKey(const ValueKey('app-notice'));
    expect(notice, findsOneWidget);
    expect(tester.getSize(notice).width, lessThanOrEqualTo(360));
    expect(tester.takeException(), isNull);

    final liveRegions = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .where((widget) => widget.properties.liveRegion == true);
    expect(liveRegions, isNotEmpty);
  });
}

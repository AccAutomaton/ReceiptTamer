import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/core/theme/app_theme.dart';
import 'package:receipt_tamer/core/utils/date_formatter.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/presentation/widgets/common/ledger_month_sheet.dart';
import 'package:receipt_tamer/presentation/widgets/common/scroll_edge_fog.dart';
import 'package:receipt_tamer/presentation/widgets/invoice/invoice_ledger_row.dart';
import 'package:receipt_tamer/presentation/widgets/order/order_ledger_row.dart';

void main() {
  group('账页日期', () {
    test('优先使用合法业务日期', () {
      final result = DateFormatter.resolveLedgerDate(
        businessDate: '2026-07-09',
        createdAt: '2026-06-01T12:30:00',
      );

      expect(result, DateTime(2026, 7, 9));
    });

    test('空或非法业务日期回退收录时间', () {
      final emptyDate = DateFormatter.resolveLedgerDate(
        businessDate: '  ',
        createdAt: '2026-06-17T08:30:00',
      );
      final invalidDate = DateFormatter.resolveLedgerDate(
        businessDate: '不是日期',
        createdAt: '2026-06-11T12:30:00',
      );

      expect(emptyDate, DateTime(2026, 6, 17, 8, 30));
      expect(invalidDate, DateTime(2026, 6, 11, 12, 30));
    });
  });

  testWidgets('连续账页不用逐行 Card，并保留点击和长按语义', (tester) async {
    var tapCount = 0;
    var longPressCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: LedgerMonthSheet(
            monthLabel: '2026 年 7 月',
            summary: '2 笔订单 · 1 笔已有发票',
            totalLabel: '订单合计',
            totalAmount: '¥128.64',
            entries: [
              LedgerEntryRow(
                key: const ValueKey('first-entry'),
                day: '09',
                dateCaption: '午餐',
                title: '青禾餐食',
                subtitle: '订单 #23891',
                amount: '¥42.80',
                relationLabel: '未关联发票',
                onTap: () => tapCount++,
                onLongPress: () => longPressCount++,
              ),
              const LedgerEntryRow(
                day: '08',
                dateCaption: '午餐',
                title: '云帆便当',
                subtitle: '订单 #71952',
                amount: '¥85.84',
                relationLabel: '发票 1 张',
                relationTone: LedgerRelationTone.linked,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(Card), findsNothing);
    expect(find.byType(LedgerEntryRow), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('first-entry')));
    await tester.longPress(find.byKey(const ValueKey('first-entry')));

    expect(tapCount, 1);
    expect(longPressCount, 1);
  });

  testWidgets('日期栏不单独着色并继承整行选中状态', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: Column(
            children: [
              LedgerEntryRow(
                day: '12',
                dateCaption: '早餐',
                title: '青禾餐厅',
                subtitle: '#RT-2026-100000',
                amount: '¥18.00',
                relationLabel: '已关联发票',
              ),
              LedgerEntryRow(
                day: '11',
                dateCaption: '晚餐',
                title: '山茶面馆',
                subtitle: '#RT-2024-100089',
                amount: '¥336.99',
                relationLabel: '已关联发票',
                selected: true,
              ),
              LedgerEntryRow(
                day: '10',
                dateCaption: '午餐',
                title: '云帆便当',
                subtitle: '#RT-2026-100090',
                amount: '¥42.00',
                relationLabel: '已关联发票',
                leading: Icon(Icons.check_box_outline_blank),
              ),
            ],
          ),
        ),
      ),
    );

    for (final entry in {'12': false, '11': false, '10': true}.entries) {
      final dateRail = find.ancestor(
        of: find.text(entry.key),
        matching: find.byWidgetPredicate((widget) {
          if (widget is! Container || widget.decoration is! BoxDecoration) {
            return false;
          }
          final decoration = widget.decoration! as BoxDecoration;
          final border = decoration.border;
          return border is Border &&
              border.right.style == BorderStyle.solid &&
              border.top.style == BorderStyle.none &&
              border.bottom.style == BorderStyle.none;
        }),
      );
      expect(dateRail, findsOneWidget);
      final decoration =
          tester.widget<Container>(dateRail).decoration! as BoxDecoration;
      expect(decoration.color, isNull);
      final border = decoration.border! as Border;
      expect(
        border.left.style,
        entry.value ? BorderStyle.solid : BorderStyle.none,
      );
    }
  });

  testWidgets('账页筛选签保留 48dp 命中高度', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: LedgerFilterStrip(
            children: [
              LedgerFilterChip(
                label: '未关联 3',
                icon: Icons.link_off,
                onPressed: () => pressed = true,
              ),
            ],
          ),
        ),
      ),
    );

    final chip = find.byType(LedgerFilterChip);
    expect(tester.getSize(chip).height, greaterThanOrEqualTo(48));
    await tester.tap(chip);
    expect(pressed, isTrue);
  });

  testWidgets('月份标题在本月末行离开雾边后由下一月推走', (tester) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ScrollEdgeFog(
            showBottom: false,
            topHeight: ledgerMonthFadeSafeTop,
            child: CustomScrollView(
              controller: controller,
              slivers: [
                LedgerMonthSheetSliver(
                  monthLabel: '2026 年 7 月',
                  summary: '5 笔',
                  totalLabel: '合计',
                  totalAmount: '¥100.00',
                  padding: const EdgeInsets.only(bottom: 14),
                  entries: [
                    for (var index = 0; index < 5; index++)
                      SizedBox(key: ValueKey('july-row-$index'), height: 80),
                  ],
                ),
                LedgerMonthSheetSliver(
                  monthLabel: '2026 年 6 月',
                  summary: '2 笔',
                  totalLabel: '合计',
                  totalAmount: '¥60.00',
                  padding: EdgeInsets.zero,
                  entries: const [SizedBox(height: 80), SizedBox(height: 80)],
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 500)),
              ],
            ),
          ),
        ),
      ),
    );

    controller.jumpTo(396);
    await tester.pump();
    final pinnedTitleTop = tester.getRect(find.text('2026 年 7 月')).top;
    final lastVisibleRow = tester.getRect(
      find.byKey(const ValueKey('july-row-4')),
    );
    expect(pinnedTitleTop, greaterThanOrEqualTo(28));
    expect(
      lastVisibleRow.bottom,
      greaterThan(
        ledgerMonthHeaderExtent(tester.element(find.byType(CustomScrollView))),
      ),
    );

    controller.jumpTo(410);
    await tester.pump();
    final leavingTitleTop = tester.getRect(find.text('2026 年 7 月')).top;
    final hiddenLastRow = tester.getRect(
      find.byKey(const ValueKey('july-row-4')),
    );
    expect(
      hiddenLastRow.bottom,
      lessThan(
        ledgerMonthHeaderExtent(tester.element(find.byType(CustomScrollView))),
      ),
    );
    expect(leavingTitleTop, lessThan(pinnedTitleTop));

    controller.jumpTo(520);
    await tester.pump();
    expect(
      tester.getRect(find.text('2026 年 7 月')).bottom,
      lessThanOrEqualTo(0),
    );
    expect(
      tester.getRect(find.text('2026 年 6 月')).top,
      greaterThanOrEqualTo(28),
    );
  });

  for (final textScale in [1.0, 2.0]) {
    testWidgets('412 宽粘性月份栏在 $textScale 倍字号下无溢出', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            );
          },
          home: Scaffold(
            body: ScrollEdgeFog(
              showBottom: false,
              topHeight: ledgerMonthFadeSafeTop,
              child: Padding(
                padding: const EdgeInsets.only(right: 20),
                child: CustomScrollView(
                  slivers: const [
                    LedgerMonthSheetSliver(
                      monthLabel: '2026 年 7 月',
                      summary: '9 笔',
                      totalLabel: '合计',
                      totalAmount: '¥2,917.25',
                      entries: [SizedBox(height: 80), SizedBox(height: 80)],
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 500)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.text('2026 年 7 月')).top,
        greaterThanOrEqualTo(ledgerMonthFadeSafeTop),
      );
      final header = find.byKey(LedgerMonthSheetSliver.headerSurfaceKey).first;
      final headerRect = tester.getRect(header);
      expect(
        tester.getRect(find.text('9 笔')).bottom,
        lessThanOrEqualTo(headerRect.bottom),
      );

      final titleRect = tester.getRect(
        find.descendant(of: header, matching: find.text('2026 年 7 月')),
      );
      final summaryRect = tester.getRect(
        find.descendant(of: header, matching: find.text('9 笔')),
      );
      final totalLabelRect = tester.getRect(
        find.descendant(of: header, matching: find.text('合计')),
      );
      final totalAmountRect = tester.getRect(
        find.descendant(of: header, matching: find.text('¥2,917.25')),
      );
      final contentTop = [
        titleRect.top,
        totalLabelRect.top,
      ].reduce((value, element) => value < element ? value : element);
      final contentBottom = [
        summaryRect.bottom,
        totalAmountRect.bottom,
      ].reduce((value, element) => value > element ? value : element);
      expect(
        contentTop - headerRect.top,
        closeTo(headerRect.bottom - contentBottom, 1.5),
      );
      expect(
        contentTop - headerRect.top,
        greaterThanOrEqualTo(ledgerMonthFadeSafeTop),
      );

      final surfaceContainer = tester.widget<Container>(
        find.descendant(of: header, matching: find.byType(Container)).first,
      );
      final foreground = surfaceContainer.foregroundDecoration as BoxDecoration;
      final foregroundBorder = foreground.border! as Border;
      expect(foregroundBorder.top.style, BorderStyle.solid);
      expect(foregroundBorder.right.style, BorderStyle.solid);
      final headerRadius = foreground.borderRadius! as BorderRadius;
      expect(
        headerRadius.topLeft,
        const Radius.circular(ledgerMonthSheetRadius),
      );
      expect(headerRadius.topRight, headerRadius.topLeft);

      final entries = find
          .byKey(LedgerMonthSheetSliver.entriesSurfaceKey)
          .first;
      final entriesContainer = tester.widget<Container>(
        find.descendant(of: entries, matching: find.byType(Container)).first,
      );
      final entriesForeground =
          entriesContainer.foregroundDecoration as BoxDecoration;
      final entriesRadius = entriesForeground.borderRadius! as BorderRadius;
      expect(
        entriesRadius.bottomLeft,
        const Radius.circular(ledgerMonthSheetRadius),
      );
      expect(entriesRadius.bottomRight, entriesRadius.bottomLeft);
    });
  }

  testWidgets('360 宽与 2.0 倍字体下订单发票账行无溢出', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            );
          },
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LedgerMonthSheet(
                  monthLabel: '2026 年 7 月',
                  summary: '2 张发票 · 已关联 3 笔订单',
                  totalLabel: '发票合计',
                  totalAmount: '¥4,282.80',
                  entries: const [
                    OrderLedgerRow(
                      order: Order(
                        id: 1,
                        shopName: '青禾餐饮管理有限公司职工餐厅测试店',
                        amount: 4282.8,
                        orderDate: '非法日期',
                        createdAt: '2026-07-09T12:00:00',
                        orderNumber: '23891000000000000000',
                      ),
                    ),
                    InvoiceLedgerRow(
                      invoice: Invoice(
                        id: 2,
                        sellerName: '云帆城市服务有限公司测试销售分部',
                        totalAmount: 128.64,
                        invoiceDate: '',
                        createdAt: '2026-07-10T08:00:00',
                        invoiceNumber: '04400000000000009801',
                      ),
                      orderCount: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('09'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('日'), findsOneWidget);
      expect(find.text('开票'), findsNothing);
    }
  });
}

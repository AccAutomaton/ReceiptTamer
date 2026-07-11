import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/presentation/widgets/common/muted_status_chip.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_surface.dart';
import 'package:receipt_tamer/presentation/widgets/invoice/invoice_card.dart';
import 'package:receipt_tamer/presentation/widgets/invoice/invoice_month_section_header.dart';
import 'package:receipt_tamer/presentation/widgets/order/month_section_header.dart';
import 'package:receipt_tamer/presentation/widgets/order/order_card.dart';

void main() {
  testWidgets('month section headers use low-cost morning surfaces', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              MonthSectionHeader(
                year: 2026,
                month: 6,
                orderCount: 3,
                totalAmount: 88,
                isPinned: true,
              ),
              InvoiceMonthSectionHeader(
                year: 2026,
                month: 6,
                invoiceCount: 2,
                totalAmount: 66,
                isPinned: true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(GlassSurface), findsNWidgets(2));
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets(
    'order and invoice cards use muted status chips and amount color',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                OrderCard(
                  order: Order(
                    shopName: '冷调食堂',
                    amount: 36,
                    orderDate: '2026-06-01',
                    mealTime: 'lunch',
                    hasInvoice: true,
                  ),
                ),
                InvoiceCard(
                  invoice: Invoice(
                    sellerName: '冷调发票',
                    totalAmount: 36,
                    invoiceDate: '2026-06-01',
                  ),
                  orderCount: 1,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(MutedStatusChip), findsNWidgets(2));
      expect(
        find.text('¥36.00').evaluate().map((e) {
          final text = e.widget as Text;
          return text.style?.color;
        }),
        everyElement(AppPalette.amountMuted),
      );
    },
  );

  testWidgets('order relation chip is compact and aligns with date row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 240);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 380,
              child: OrderCard(
                order: Order(
                  shopName: '订单卡片店铺',
                  amount: 36,
                  orderDate: '2026-06-01',
                  mealTime: 'lunch',
                  hasInvoice: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final dateFinder = find.textContaining('2026年06月01日');
    final chipLabelFinder = find.text('未关联发票');

    expect(dateFinder, findsOneWidget);
    expect(chipLabelFinder, findsOneWidget);

    final chipText = tester.widget<Text>(chipLabelFinder);
    expect(chipText.style?.fontSize, 10);

    final dateCenterY = tester.getRect(dateFinder).center.dy;
    final chipCenterY = tester.getRect(find.byType(MutedStatusChip)).center.dy;
    expect((dateCenterY - chipCenterY).abs(), lessThanOrEqualTo(1));
  });

  testWidgets('invoice relation chip is compact and aligns with date row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 260);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 380,
              child: InvoiceCard(
                invoice: Invoice(
                  sellerName: '发票卡片销售方',
                  totalAmount: 36,
                  invoiceDate: '2026-06-01',
                ),
                orderCount: 1,
              ),
            ),
          ),
        ),
      ),
    );

    final dateFinder = find.textContaining('2026年06月01日');
    final chipLabelFinder = find.text('已关联1条订单');

    expect(dateFinder, findsOneWidget);
    expect(chipLabelFinder, findsOneWidget);

    final chipText = tester.widget<Text>(chipLabelFinder);
    expect(chipText.style?.fontSize, 10);

    final dateRect = tester.getRect(dateFinder);
    final chipRect = tester.getRect(find.byType(MutedStatusChip));
    expect(
      (dateRect.center.dy - chipRect.center.dy).abs(),
      lessThanOrEqualTo(1),
    );
    expect(chipRect.left, greaterThan(dateRect.right));
  });
}

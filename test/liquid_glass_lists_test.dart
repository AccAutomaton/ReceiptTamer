import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/presentation/widgets/common/muted_status_chip.dart';
import 'package:receipt_tamer/presentation/widgets/invoice/invoice_card.dart';
import 'package:receipt_tamer/presentation/widgets/invoice/invoice_month_section_header.dart';
import 'package:receipt_tamer/presentation/widgets/order/month_section_header.dart';
import 'package:receipt_tamer/presentation/widgets/order/order_card.dart';

void main() {
  testWidgets('month section headers use glass function surfaces', (
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

    expect(find.byType(BackdropFilter), findsNWidgets(2));
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
}

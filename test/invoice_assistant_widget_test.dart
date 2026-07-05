import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/core/constants/app_constants.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/data/models/uninvoiced_shop_summary.dart';
import 'package:receipt_tamer/data/repositories/invoice_repository.dart';
import 'package:receipt_tamer/data/repositories/order_repository.dart';
import 'package:receipt_tamer/presentation/providers/invoice_provider.dart';
import 'package:receipt_tamer/presentation/providers/order_provider.dart';
import 'package:receipt_tamer/presentation/screens/home/home_screen.dart';
import 'package:receipt_tamer/presentation/screens/invoices/invoice_edit_screen.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_text_field.dart';

void main() {
  testWidgets('home quick access includes invoice assistant', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderRepositoryProvider.overrideWithValue(_FakeOrderRepository()),
          invoiceRepositoryProvider.overrideWithValue(_FakeInvoiceRepository()),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('开票助手'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'invoice editor accepts multiple initial orders without field prefill',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            invoiceRepositoryProvider.overrideWithValue(
              _FakeInvoiceRepository(),
            ),
          ],
          child: const MaterialApp(
            home: InvoiceEditScreen(initialOrderIds: [1, 2]),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('已选择 2 个订单'), findsOneWidget);

      final amountField = tester.widget<AppAmountField>(
        find.byWidgetPredicate(
          (widget) =>
              widget is AppAmountField &&
              widget.label == AppConstants.labelTotalAmount,
        ),
      );
      expect(amountField.controller!.text, isEmpty);

      final sellerField = tester.widget<AppTextField>(
        find.byWidgetPredicate(
          (widget) =>
              widget is AppTextField &&
              widget.label == AppConstants.labelSellerName,
        ),
      );
      expect(sellerField.controller!.text, isEmpty);
    },
  );
}

class _FakeOrderRepository extends OrderRepository {
  @override
  Future<List<Order>> getAll({int? limit, int? offset}) async => const [];

  @override
  Future<int> getCount() async => 0;

  @override
  Future<List<UninvoicedShopSummary>> getUninvoicedShopSummaries({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return const [];
  }
}

class _FakeInvoiceRepository extends InvoiceRepository {
  @override
  Future<List<Invoice>> getAll({int? limit, int? offset}) async => const [];

  @override
  Future<int> getCount() async => 0;

  @override
  Future<List<Map<String, dynamic>>> getSellerNamesWithCount() async =>
      const [];
}

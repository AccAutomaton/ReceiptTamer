import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/data/models/daily_meal_details.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/models/meal_proof_item.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/data/services/invoice_proration_util.dart';
import 'package:receipt_tamer/data/services/meal_details_export_service.dart';
import 'package:receipt_tamer/data/services/meal_proof_export_service.dart';

void main() {
  const breakfast = Order(
    id: 1,
    amount: 30,
    orderDate: '2026-07-01',
    mealTime: 'breakfast',
  );
  const lunch = Order(
    id: 2,
    amount: 70,
    orderDate: '2026-07-02',
    mealTime: 'lunch',
  );
  const dinner = Order(
    id: 3,
    amount: 25,
    orderDate: '2026-07-02',
    mealTime: 'dinner',
  );
  const firstInvoice = Invoice(id: 11, totalAmount: 80);
  const secondInvoice = Invoice(id: 12, totalAmount: 25);
  const equalTotalInvoice = Invoice(id: 13, totalAmount: 100);
  const ordersById = <int, Order>{1: breakfast, 2: lunch, 3: dinner};

  test(
    'one invoice prorates across many orders without changing its total',
    () {
      final result = InvoiceProrationUtil.calculate(
        invoice: firstInvoice,
        orders: const [breakfast, lunch],
      );

      expect(result.needsProration, isTrue);
      expect(result.orderAmounts[0].proratedInvoiceAmount, closeTo(24, 1e-9));
      expect(result.orderAmounts[1].proratedInvoiceAmount, closeTo(56, 1e-9));
      expect(
        result.orderAmounts.fold<double>(
          0,
          (sum, item) => sum + item.proratedInvoiceAmount,
        ),
        closeTo(firstInvoice.totalAmount, 1e-9),
      );
    },
  );

  test('one order continues to show only the invoice total', () async {
    final result = InvoiceProrationUtil.calculate(
      invoice: secondInvoice,
      orders: const [dinner],
    );
    final items = await MealProofExportService.prepareMealProofItems(
      invoices: const [secondInvoice],
      getOrderIdsForInvoice: (_) async => const [3],
      getOrderById: (orderId) async => ordersById[orderId],
    );

    expect(result.needsProration, isFalse);
    expect(result.orderAmounts.single.isProrated, isFalse);
    expect(items.single.invoiceAmountDisplay, '25.00元');
  });

  test('many orders show allocation even when their total matches invoice', () {
    final result = InvoiceProrationUtil.calculate(
      invoice: equalTotalInvoice,
      orders: const [breakfast, lunch],
    );

    expect(result.needsProration, isTrue);
    expect(result.orderAmounts.every((item) => item.isProrated), isTrue);
    expect(result.orderAmounts[0].proratedInvoiceAmount, 30);
    expect(result.orderAmounts[1].proratedInvoiceAmount, 70);
  });

  test(
    'meal proof prints allocated amount over total for equal totals',
    () async {
      final items = await MealProofExportService.prepareMealProofItems(
        invoices: const [equalTotalInvoice],
        getOrderIdsForInvoice: (_) async => const [1, 2],
        getOrderById: (orderId) async => ordersById[orderId],
      );

      expect(items.map((item) => item.invoiceAmountDisplay), [
        '30.00/100.00元',
        '70.00/100.00元',
      ]);
    },
  );

  test(
    'meal details count every order once and preserve invoice totals',
    () async {
      final details = await MealDetailsExportService.prepareDailyMealDetails(
        invoices: const [firstInvoice, secondInvoice],
        getOrderIdsForInvoice: (invoiceId) async => switch (invoiceId) {
          11 => const [1, 2],
          12 => const [3],
          _ => const [],
        },
        getOrderById: (orderId) async => ordersById[orderId],
      );

      expect(details, hasLength(2));
      expect(
        details.fold<double>(0, (sum, item) => sum + item.totalPaid),
        closeTo(125, 1e-9),
      );
      expect(
        details.fold<double>(0, (sum, item) => sum + item.totalInvoice),
        closeTo(105, 1e-9),
      );
      expect(details.first.breakfastInvoice, closeTo(24, 1e-9));
      expect(details.last.lunchInvoice, closeTo(56, 1e-9));
      expect(details.last.dinnerInvoice, closeTo(25, 1e-9));
    },
  );

  test('meal details reject a legacy order linked to two invoices', () async {
    expect(
      MealDetailsExportService.prepareDailyMealDetails(
        invoices: const [firstInvoice, secondInvoice],
        getOrderIdsForInvoice: (_) async => const [1],
        getOrderById: (orderId) async => ordersById[orderId],
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('meal details do not count a duplicated invoice input twice', () async {
    final details = await MealDetailsExportService.prepareDailyMealDetails(
      invoices: const [firstInvoice, firstInvoice],
      getOrderIdsForInvoice: (_) async => const [1, 2],
      getOrderById: (orderId) async => ordersById[orderId],
    );

    expect(
      details.fold<double>(0, (sum, item) => sum + item.totalInvoice),
      closeTo(80, 1e-9),
    );
  });

  test('order-based meal proof rejects more than one linked invoice', () async {
    expect(
      MealProofExportService.prepareMealProofItemsFromOrders(
        orders: const [breakfast],
        getInvoiceIdsForOrder: (_) async => const [11, 12],
        getInvoiceById: (_) async => firstInvoice,
        getOrderIdsForInvoice: (_) async => const [1],
        getOrderById: (orderId) async => ordersById[orderId],
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('order-based meal proof prorates against every linked order', () async {
    final items = await MealProofExportService.prepareMealProofItemsFromOrders(
      orders: const [breakfast],
      getInvoiceIdsForOrder: (_) async => const [11],
      getInvoiceById: (_) async => firstInvoice,
      getOrderIdsForInvoice: (_) async => const [1, 2],
      getOrderById: (orderId) async => ordersById[orderId],
    );

    expect(items, hasLength(1));
    expect(items.single.invoiceAmountDisplay, '24.00/80.00元');
  });

  test(
    'order-based meal proof rejects a relation removed mid-export',
    () async {
      await expectLater(
        MealProofExportService.prepareMealProofItemsFromOrders(
          orders: const [breakfast],
          getInvoiceIdsForOrder: (_) async => const [11],
          getInvoiceById: (_) async => firstInvoice,
          getOrderIdsForInvoice: (_) async => const [],
          getOrderById: (orderId) async => ordersById[orderId],
        ),
        throwsA(isA<StateError>()),
      );
    },
  );
}

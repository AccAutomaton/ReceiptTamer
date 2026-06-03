import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/data/repositories/invoice_repository.dart';
import 'package:receipt_tamer/data/repositories/order_repository.dart';
import 'package:receipt_tamer/presentation/providers/invoice_provider.dart';
import 'package:receipt_tamer/presentation/providers/order_provider.dart';
import 'package:receipt_tamer/presentation/screens/invoices/invoices_screen.dart';
import 'package:receipt_tamer/presentation/screens/orders/orders_screen.dart';
import 'package:receipt_tamer/presentation/widgets/common/liquid_glass_edge.dart';
import 'package:receipt_tamer/presentation/widgets/invoice/invoice_card.dart';
import 'package:receipt_tamer/presentation/widgets/order/month_fast_scroll_bar.dart';
import 'package:receipt_tamer/presentation/widgets/order/order_card.dart';

void main() {
  testWidgets(
    'orders fast scrollbar avoids bottom nav and balances the card gutter',
    (tester) async {
      _setViewport(tester);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orderRepositoryProvider.overrideWithValue(
              _FakeOrderRepository(_orders),
            ),
          ],
          child: const MaterialApp(home: OrdersScreen()),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      _expectFastScrollLayout(
        tester,
        cardFinder: find.descendant(
          of: find.byType(OrderCard).first,
          matching: find.byType(LiquidGlassEdge),
        ),
      );
    },
  );

  testWidgets(
    'invoices fast scrollbar avoids bottom nav and balances the card gutter',
    (tester) async {
      _setViewport(tester);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            invoiceRepositoryProvider.overrideWithValue(
              _FakeInvoiceRepository(_invoices),
            ),
          ],
          child: const MaterialApp(home: InvoicesScreen()),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      _expectFastScrollLayout(
        tester,
        cardFinder: find.descendant(
          of: find.byType(InvoiceCard).first,
          matching: find.byType(LiquidGlassEdge),
        ),
      );
    },
  );
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void _expectFastScrollLayout(
  WidgetTester tester, {
  required Finder cardFinder,
}) {
  final scrollBarRect = tester.getRect(find.byType(MonthFastScrollBar));
  final cardRect = tester.getRect(cardFinder.first);
  final viewportBottom = tester.view.physicalSize.height;
  final viewportRight = tester.view.physicalSize.width;
  final scrollCenterX = scrollBarRect.center.dx;

  expect(
    scrollBarRect.bottom,
    viewportBottom - AppGlassTokens.navCenterButtonSize - 44,
  );
  expect(scrollCenterX - cardRect.right, viewportRight - scrollCenterX);
}

const _orders = [
  Order(
    id: 1,
    shopName: 'A',
    amount: 20,
    orderDate: '2026-06-01',
    createdAt: '2026-06-01T12:00:00',
  ),
  Order(
    id: 2,
    shopName: 'B',
    amount: 30,
    orderDate: '2026-05-01',
    createdAt: '2026-05-01T12:00:00',
  ),
];

const _invoices = [
  Invoice(
    id: 1,
    sellerName: 'A',
    totalAmount: 20,
    invoiceDate: '2026-06-01',
    createdAt: '2026-06-01T12:00:00',
  ),
  Invoice(
    id: 2,
    sellerName: 'B',
    totalAmount: 30,
    invoiceDate: '2026-05-01',
    createdAt: '2026-05-01T12:00:00',
  ),
];

class _FakeOrderRepository extends OrderRepository {
  _FakeOrderRepository(this._orders);

  final List<Order> _orders;

  @override
  Future<List<Order>> getAll({int? limit, int? offset}) async => _orders;
}

class _FakeInvoiceRepository extends InvoiceRepository {
  _FakeInvoiceRepository(this._invoices);

  final List<Invoice> _invoices;

  @override
  Future<List<Invoice>> getAll({int? limit, int? offset}) async => _invoices;

  @override
  Future<List<Invoice>> getByOrderId(int orderId) async => _invoices;

  @override
  Future<List<int>> getOrderIdsForInvoice(int invoiceId) async => [1];
}

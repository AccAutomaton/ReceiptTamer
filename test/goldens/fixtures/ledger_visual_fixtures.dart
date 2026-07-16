import 'dart:io';
import 'dart:ui' show Offset, Rect;

import 'package:image/image.dart' as image;
import 'package:receipt_tamer/core/models/ledger_month_summary.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/data/models/uninvoiced_shop_summary.dart';
import 'package:receipt_tamer/data/repositories/invoice_repository.dart';
import 'package:receipt_tamer/data/repositories/order_repository.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// One clock for every visual fixture and screenshot assertion.
abstract final class LedgerVisualClock {
  static final DateTime now = DateTime.parse('2026-07-10T10:24:00+08:00');
}

/// Sanitized, cross-month data used by widget Goldens and Android screenshots.
///
/// Names, numbers and files are synthetic. Do not replace these with production
/// database exports or user receipts.
abstract final class LedgerVisualFixtures {
  static const String fixtureId = 'ledger_july_redacted_v1';

  static const List<Order> orders = [
    Order(
      id: 101,
      imagePath: '__fixture__/order-101.png',
      shopName: '青禾餐食 · 测试店',
      amount: 42.80,
      orderDate: '2026-07-09',
      mealTime: 'lunch',
      orderNumber: 'RT-FIX-000101',
      createdAt: '2026-07-09T12:08:00+08:00',
      updatedAt: '2026-07-09T12:08:00+08:00',
      hasInvoice: false,
    ),
    Order(
      id: 102,
      imagePath: '__fixture__/order-102.png',
      shopName: '云帆便当 · 脱敏样本',
      amount: 85.84,
      orderDate: '2026-07-08',
      mealTime: 'dinner',
      orderNumber: 'RT-FIX-000102',
      createdAt: '2026-07-08T18:32:00+08:00',
      updatedAt: '2026-07-08T18:32:00+08:00',
      hasInvoice: true,
    ),
    Order(
      id: 103,
      imagePath: '__fixture__/order-103.png',
      shopName: '纸上食堂 · 样本门店',
      amount: 26.00,
      orderDate: '2026-06-28',
      mealTime: 'breakfast',
      orderNumber: 'RT-FIX-000103',
      createdAt: '2026-06-28T08:11:00+08:00',
      updatedAt: '2026-06-28T08:11:00+08:00',
      hasInvoice: true,
    ),
  ];

  static const List<Invoice> invoices = [
    Invoice(
      id: 201,
      imagePath: '__fixture__/invoice-201.png',
      invoiceNumber: 'FIX2026070001',
      invoiceDate: '2026-07-10',
      totalAmount: 85.84,
      sellerName: '示例餐饮有限公司（脱敏）',
      createdAt: '2026-07-10T09:18:00+08:00',
      updatedAt: '2026-07-10T09:18:00+08:00',
    ),
    Invoice(
      id: 202,
      imagePath: '__fixture__/invoice-202.pdf',
      invoiceNumber: 'FIX2026060002',
      invoiceDate: '2026-06-30',
      totalAmount: 26.00,
      sellerName: '样本票据服务有限公司（脱敏）',
      createdAt: '2026-06-30T16:05:00+08:00',
      updatedAt: '2026-06-30T16:05:00+08:00',
    ),
  ];

  static const List<LedgerMonthSummary> orderMonthSummaries = [
    LedgerMonthSummary(
      monthKey: '2026-07',
      itemCount: 2,
      totalAmount: 128.64,
      linkedItemCount: 1,
    ),
    LedgerMonthSummary(
      monthKey: '2026-06',
      itemCount: 1,
      totalAmount: 26.00,
      linkedItemCount: 1,
    ),
  ];

  static const List<LedgerMonthSummary> invoiceMonthSummaries = [
    LedgerMonthSummary(
      monthKey: '2026-07',
      itemCount: 1,
      totalAmount: 85.84,
      linkedItemCount: 1,
    ),
    LedgerMonthSummary(
      monthKey: '2026-06',
      itemCount: 1,
      totalAmount: 26.00,
      linkedItemCount: 1,
    ),
  ];

  /// Materializes anonymous media only inside a caller-owned temporary folder.
  /// This keeps binary receipts out of source control while allowing preview
  /// and file-error states to share stable local paths.
  static LedgerFixtureMedia materializeMedia(Directory root) {
    root.createSync(recursive: true);
    final orderImage = File('${root.path}/order-101.png');
    final secondOrderImage = File('${root.path}/order-102.png');
    final thirdOrderImage = File('${root.path}/order-103.png');
    final invoiceImage = File('${root.path}/invoice-201.png');
    final invoicePdf = File('${root.path}/invoice-202.pdf');

    orderImage.writeAsBytesSync(
      _receiptPng(
        width: 360,
        height: 720,
        label: 'REDACTED ORDER 101',
        accent: image.ColorRgb8(29, 112, 116),
      ),
    );
    secondOrderImage.writeAsBytesSync(
      _receiptPng(
        width: 360,
        height: 720,
        label: 'REDACTED ORDER 102',
        accent: image.ColorRgb8(90, 98, 101),
      ),
    );
    thirdOrderImage.writeAsBytesSync(
      _receiptPng(
        width: 360,
        height: 720,
        label: 'REDACTED ORDER 103',
        accent: image.ColorRgb8(169, 76, 68),
      ),
    );
    invoiceImage.writeAsBytesSync(
      _receiptPng(
        width: 720,
        height: 460,
        label: 'REDACTED INVOICE 201',
        accent: image.ColorRgb8(29, 112, 116),
      ),
    );

    final document = PdfDocument();
    try {
      final page = document.pages.add();
      page.graphics.drawString(
        'REDACTED INVOICE FIXTURE 202',
        PdfStandardFont(PdfFontFamily.courier, 18),
        brush: PdfSolidBrush(PdfColor(21, 26, 28)),
        bounds: const Rect.fromLTWH(36, 48, 420, 40),
      );
      page.graphics.drawLine(
        PdfPen(PdfColor(29, 112, 116), width: 2),
        const Offset(36, 96),
        const Offset(430, 96),
      );
      invoicePdf.writeAsBytesSync(document.saveSync());
    } finally {
      document.dispose();
    }

    return LedgerFixtureMedia(
      orderImagePaths: [
        orderImage.path,
        secondOrderImage.path,
        thirdOrderImage.path,
      ],
      invoiceImagePath: invoiceImage.path,
      invoicePdfPath: invoicePdf.path,
    );
  }

  static List<int> _receiptPng({
    required int width,
    required int height,
    required String label,
    required image.Color accent,
  }) {
    final canvas = image.Image(width: width, height: height, numChannels: 4);
    image.fill(canvas, color: image.ColorRgb8(244, 245, 242));
    image.fillRect(canvas, x1: 0, y1: 0, x2: width - 1, y2: 62, color: accent);
    image.drawString(
      canvas,
      label,
      font: image.arial24,
      x: 18,
      y: 20,
      color: image.ColorRgb8(255, 255, 255),
    );
    for (var y = 100; y < height - 50; y += 54) {
      image.fillRect(
        canvas,
        x1: 24,
        y1: y,
        x2: width - 24,
        y2: y + 2,
        color: image.ColorRgb8(218, 222, 217),
      );
      final shortening = ((y ~/ 54) % 3) * 42;
      image.fillRect(
        canvas,
        x1: 24,
        y1: y + 15,
        x2: width - 72 - shortening,
        y2: y + 24,
        color: image.ColorRgb8(90, 98, 101),
      );
    }
    return image.encodePng(canvas, level: 6);
  }
}

class LedgerFixtureMedia {
  const LedgerFixtureMedia({
    required this.orderImagePaths,
    required this.invoiceImagePath,
    required this.invoicePdfPath,
  });

  final List<String> orderImagePaths;
  final String invoiceImagePath;
  final String invoicePdfPath;
}

class LedgerFixtureOrderRepository extends OrderRepository {
  LedgerFixtureOrderRepository({this.items = LedgerVisualFixtures.orders});

  final List<Order> items;

  @override
  Future<List<Order>> getAll({int? limit, int? offset}) async =>
      _page(items, limit: limit, offset: offset);

  @override
  Future<List<Order>> getRecentlyCreated({int limit = 10}) async {
    final sorted = [...items]
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return _page(sorted, limit: limit);
  }

  @override
  Future<Order?> getById(int id) async =>
      items.where((order) => order.id == id).firstOrNull;

  @override
  Future<int> getCount() async => items.length;

  @override
  Future<List<LedgerMonthSummary>> getMonthSummaries() async =>
      LedgerVisualFixtures.orderMonthSummaries;

  @override
  Future<List<int>> getInvoiceIdsForOrder(int orderId) async =>
      switch (orderId) {
        102 => const [201],
        103 => const [202],
        _ => const [],
      };

  @override
  Future<Map<int, Set<int>>> getInvoiceIdsForOrders(List<int> orderIds) async {
    return {
      for (final orderId in orderIds)
        orderId: (await getInvoiceIdsForOrder(orderId)).toSet(),
    };
  }

  @override
  Future<Map<int, int>> getInvoiceCountsForOrders(List<int> orderIds) async {
    return {
      for (final orderId in orderIds)
        orderId: (await getInvoiceIdsForOrder(orderId)).length,
    };
  }

  @override
  Future<List<UninvoicedShopSummary>> getUninvoicedShopSummaries({
    DateTime? startDate,
    DateTime? endDate,
  }) async => const [
    UninvoicedShopSummary(
      shopKey: '青禾餐食 · 测试店',
      displayName: '青禾餐食 · 测试店',
      orderCount: 1,
      totalAmount: 42.80,
    ),
  ];
}

class LedgerFixtureInvoiceRepository extends InvoiceRepository {
  LedgerFixtureInvoiceRepository({this.items = LedgerVisualFixtures.invoices});

  final List<Invoice> items;

  @override
  Future<List<Invoice>> getAll({int? limit, int? offset}) async =>
      _page(items, limit: limit, offset: offset);

  @override
  Future<List<Invoice>> getRecentlyCreated({int limit = 10}) async {
    final sorted = [...items]
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return _page(sorted, limit: limit);
  }

  @override
  Future<Invoice?> getById(int id) async =>
      items.where((invoice) => invoice.id == id).firstOrNull;

  @override
  Future<int> getCount() async => items.length;

  @override
  Future<List<LedgerMonthSummary>> getMonthSummaries() async =>
      LedgerVisualFixtures.invoiceMonthSummaries;

  @override
  Future<List<Invoice>> getByOrderId(
    int orderId, {
    int? limit,
    int? offset,
  }) async {
    final invoiceIds = switch (orderId) {
      102 => const {201},
      103 => const {202},
      _ => const <int>{},
    };
    return _page(
      items.where((invoice) => invoiceIds.contains(invoice.id)).toList(),
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<List<int>> getOrderIdsForInvoice(int invoiceId) async =>
      switch (invoiceId) {
        201 => const [102],
        202 => const [103],
        _ => const [],
      };

  @override
  Future<Map<int, Set<int>>> getOrderIdsForInvoices(
    List<int> invoiceIds,
  ) async {
    return {
      for (final invoiceId in invoiceIds)
        invoiceId: (await getOrderIdsForInvoice(invoiceId)).toSet(),
    };
  }

  @override
  Future<int> getOrderCountForInvoice(int invoiceId) async =>
      (await getOrderIdsForInvoice(invoiceId)).length;

  @override
  Future<Map<int, int>> getOrderCountsForInvoices(List<int> invoiceIds) async {
    return {
      for (final invoiceId in invoiceIds)
        invoiceId: (await getOrderIdsForInvoice(invoiceId)).length,
    };
  }
}

List<T> _page<T>(List<T> items, {int? limit, int? offset}) {
  final start = (offset ?? 0).clamp(0, items.length);
  final end = limit == null
      ? items.length
      : (start + limit).clamp(start, items.length);
  return items.sublist(start, end);
}

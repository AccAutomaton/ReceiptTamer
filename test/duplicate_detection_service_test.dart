import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/data/services/duplicate_detection_service.dart';

void main() {
  late Directory tempDirectory;
  late DuplicateDetectionService service;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'receipt_tamer_duplicate_test_',
    );
    service = DuplicateDetectionService();
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('identical attachment hash is reported as a strong warning', () async {
    final candidate = File('${tempDirectory.path}/candidate.jpg');
    final existing = File('${tempDirectory.path}/existing.jpg');
    await candidate.writeAsBytes([1, 2, 3, 4]);
    await existing.writeAsBytes([1, 2, 3, 4]);

    final report = await service.checkOrder(
      attachmentPath: candidate.path,
      merchant: '本次商家',
      orderNumber: 'NEW-1',
      orderDate: '2026-07-23',
      amount: 20,
      existingOrders: [
        Order(
          id: 7,
          imagePath: existing.path,
          shopName: '已有商家',
          amount: 18,
          orderDate: '2026-07-20',
          orderNumber: 'OLD-1',
        ),
      ],
      existingInvoices: const [],
    );

    expect(report.hasStrongWarning, isTrue);
    expect(report.identicalAttachments.single.record.id, 7);
  });

  test('same reference is compared independently from attachment', () async {
    final candidate = File('${tempDirectory.path}/candidate.jpg');
    final existing = File('${tempDirectory.path}/existing.jpg');
    await candidate.writeAsBytes([1]);
    await existing.writeAsBytes([2]);

    final report = await service.checkInvoice(
      attachmentPath: candidate.path,
      sellerName: '甲公司',
      invoiceNumber: ' 123 456 ',
      invoiceDate: '2026-07-23',
      amount: 30,
      existingOrders: const [],
      existingInvoices: [
        Invoice(
          id: 8,
          imagePath: existing.path,
          sellerName: '乙公司',
          totalAmount: 99,
          invoiceDate: '2026-06-01',
          invoiceNumber: '123456',
        ),
      ],
    );

    expect(report.identicalAttachments, isEmpty);
    expect(report.sameReferences.single.record.id, 8);
  });

  test(
    'merchant date and amount match remains a suspected duplicate',
    () async {
      final candidate = File('${tempDirectory.path}/candidate.jpg');
      final existing = File('${tempDirectory.path}/existing.jpg');
      await candidate.writeAsBytes([1]);
      await existing.writeAsBytes([2]);

      final report = await service.checkOrder(
        attachmentPath: candidate.path,
        merchant: '同一 商家',
        orderNumber: '',
        orderDate: '2026-07-23T18:30:00',
        amount: 42.5,
        existingOrders: [
          Order(
            id: 9,
            imagePath: existing.path,
            shopName: '同一商家',
            amount: 42.5,
            orderDate: '2026-07-23',
          ),
        ],
        existingInvoices: const [],
      );

      expect(report.hasStrongWarning, isFalse);
      expect(report.sameReferences, isEmpty);
      expect(report.suspectedFields.single.record.id, 9);
    },
  );

  test('editing a record excludes itself from every rule', () async {
    final attachment = File('${tempDirectory.path}/same.jpg');
    await attachment.writeAsBytes([1, 2, 3]);

    final report = await service.checkInvoice(
      attachmentPath: attachment.path,
      sellerName: '商家',
      invoiceNumber: 'INV-1',
      invoiceDate: '2026-07-23',
      amount: 10,
      existingOrders: const [],
      existingInvoices: [
        Invoice(
          id: 10,
          imagePath: attachment.path,
          sellerName: '商家',
          totalAmount: 10,
          invoiceDate: '2026-07-23',
          invoiceNumber: 'INV-1',
        ),
      ],
      excludeInvoiceId: 10,
    );

    expect(report.hasMatches, isFalse);
  });
}

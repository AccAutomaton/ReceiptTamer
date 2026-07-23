import 'dart:io';

import 'package:crypto/crypto.dart';

import '../models/invoice.dart';
import '../models/order.dart';

enum DuplicateRule { identicalAttachment, sameReference, suspectedFields }

enum DuplicateRecordType { order, invoice }

class DuplicateRecordSnapshot {
  const DuplicateRecordSnapshot({
    required this.type,
    required this.id,
    required this.merchant,
    required this.referenceNumber,
    required this.date,
    required this.amount,
    required this.attachmentPath,
  });

  final DuplicateRecordType type;
  final int? id;
  final String merchant;
  final String referenceNumber;
  final String? date;
  final double amount;
  final String attachmentPath;

  String get typeLabel => type == DuplicateRecordType.order ? '订单' : '发票';
}

class DuplicateMatch {
  const DuplicateMatch({required this.rule, required this.record});

  final DuplicateRule rule;
  final DuplicateRecordSnapshot record;
}

class DuplicateCheckReport {
  const DuplicateCheckReport({
    required this.candidate,
    this.identicalAttachments = const [],
    this.sameReferences = const [],
    this.suspectedFields = const [],
  });

  final DuplicateRecordSnapshot candidate;
  final List<DuplicateMatch> identicalAttachments;
  final List<DuplicateMatch> sameReferences;
  final List<DuplicateMatch> suspectedFields;

  bool get hasMatches =>
      identicalAttachments.isNotEmpty ||
      sameReferences.isNotEmpty ||
      suspectedFields.isNotEmpty;

  bool get hasStrongWarning => identicalAttachments.isNotEmpty;
}

/// Performs explainable, on-demand duplicate checks without changing the
/// database or backup format.
class DuplicateDetectionService {
  final Map<String, Future<String?>> _hashCache = {};

  Future<DuplicateCheckReport> checkOrder({
    required String attachmentPath,
    required String merchant,
    required String orderNumber,
    required String? orderDate,
    required double amount,
    required List<Order> existingOrders,
    required List<Invoice> existingInvoices,
    int? excludeOrderId,
  }) async {
    final candidate = DuplicateRecordSnapshot(
      type: DuplicateRecordType.order,
      id: excludeOrderId,
      merchant: merchant.trim(),
      referenceNumber: orderNumber.trim(),
      date: orderDate,
      amount: amount,
      attachmentPath: attachmentPath,
    );
    final records = <DuplicateRecordSnapshot>[
      for (final order in existingOrders)
        if (order.id != excludeOrderId) _fromOrder(order),
      for (final invoice in existingInvoices) _fromInvoice(invoice),
    ];

    return _buildReport(
      candidate: candidate,
      attachmentCandidates: records,
      sameTypeCandidates: records
          .where((record) => record.type == DuplicateRecordType.order)
          .toList(growable: false),
    );
  }

  Future<DuplicateCheckReport> checkInvoice({
    required String attachmentPath,
    required String sellerName,
    required String invoiceNumber,
    required String? invoiceDate,
    required double amount,
    required List<Order> existingOrders,
    required List<Invoice> existingInvoices,
    int? excludeInvoiceId,
  }) async {
    final candidate = DuplicateRecordSnapshot(
      type: DuplicateRecordType.invoice,
      id: excludeInvoiceId,
      merchant: sellerName.trim(),
      referenceNumber: invoiceNumber.trim(),
      date: invoiceDate,
      amount: amount,
      attachmentPath: attachmentPath,
    );
    final records = <DuplicateRecordSnapshot>[
      for (final order in existingOrders) _fromOrder(order),
      for (final invoice in existingInvoices)
        if (invoice.id != excludeInvoiceId) _fromInvoice(invoice),
    ];

    return _buildReport(
      candidate: candidate,
      attachmentCandidates: records,
      sameTypeCandidates: records
          .where((record) => record.type == DuplicateRecordType.invoice)
          .toList(growable: false),
    );
  }

  Future<DuplicateCheckReport> _buildReport({
    required DuplicateRecordSnapshot candidate,
    required List<DuplicateRecordSnapshot> attachmentCandidates,
    required List<DuplicateRecordSnapshot> sameTypeCandidates,
  }) async {
    final identicalAttachments = <DuplicateMatch>[];
    final candidateHash = await _hashFile(candidate.attachmentPath);
    if (candidateHash != null) {
      for (final record in attachmentCandidates) {
        final existingHash = await _hashFile(record.attachmentPath);
        if (existingHash == candidateHash) {
          identicalAttachments.add(
            DuplicateMatch(
              rule: DuplicateRule.identicalAttachment,
              record: record,
            ),
          );
        }
      }
    }

    final sameReferences = <DuplicateMatch>[];
    final normalizedReference = _normalizeText(candidate.referenceNumber);
    if (normalizedReference.isNotEmpty) {
      for (final record in sameTypeCandidates) {
        if (_normalizeText(record.referenceNumber) == normalizedReference) {
          sameReferences.add(
            DuplicateMatch(rule: DuplicateRule.sameReference, record: record),
          );
        }
      }
    }

    final suspectedFields = <DuplicateMatch>[];
    final normalizedMerchant = _normalizeText(candidate.merchant);
    final normalizedDate = _normalizeDate(candidate.date);
    if (normalizedMerchant.isNotEmpty &&
        normalizedDate.isNotEmpty &&
        candidate.amount > 0) {
      for (final record in sameTypeCandidates) {
        if (_normalizeText(record.merchant) == normalizedMerchant &&
            _normalizeDate(record.date) == normalizedDate &&
            (record.amount - candidate.amount).abs() < 0.005) {
          suspectedFields.add(
            DuplicateMatch(rule: DuplicateRule.suspectedFields, record: record),
          );
        }
      }
    }

    return DuplicateCheckReport(
      candidate: candidate,
      identicalAttachments: List.unmodifiable(identicalAttachments),
      sameReferences: List.unmodifiable(sameReferences),
      suspectedFields: List.unmodifiable(suspectedFields),
    );
  }

  Future<String?> _hashFile(String path) async {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) return null;

    String? cacheKey;
    try {
      final file = File(normalizedPath);
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file) return null;
      cacheKey =
          '$normalizedPath|${stat.size}|${stat.modified.microsecondsSinceEpoch}';
      final hashFuture = _hashCache.putIfAbsent(
        cacheKey,
        () async => (await sha256.bind(file.openRead()).first).toString(),
      );
      return await hashFuture;
    } on FileSystemException {
      if (cacheKey != null) {
        _hashCache.remove(cacheKey);
      }
      return null;
    }
  }

  DuplicateRecordSnapshot _fromOrder(Order order) {
    return DuplicateRecordSnapshot(
      type: DuplicateRecordType.order,
      id: order.id,
      merchant: order.shopName.trim(),
      referenceNumber: order.orderNumber.trim(),
      date: order.orderDate,
      amount: order.amount,
      attachmentPath: order.imagePath,
    );
  }

  DuplicateRecordSnapshot _fromInvoice(Invoice invoice) {
    return DuplicateRecordSnapshot(
      type: DuplicateRecordType.invoice,
      id: invoice.id,
      merchant: invoice.sellerName.trim(),
      referenceNumber: invoice.invoiceNumber.trim(),
      date: invoice.invoiceDate,
      amount: invoice.totalAmount,
      attachmentPath: invoice.imagePath,
    );
  }

  String _normalizeText(String value) =>
      value.replaceAll(RegExp(r'\s+'), '').toLowerCase();

  String _normalizeDate(String? value) {
    final trimmed = value?.trim() ?? '';
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) {
      final month = parsed.month.toString().padLeft(2, '0');
      final day = parsed.day.toString().padLeft(2, '0');
      return '${parsed.year}-$month-$day';
    }
    return trimmed.length >= 10 ? trimmed.substring(0, 10) : trimmed;
  }
}

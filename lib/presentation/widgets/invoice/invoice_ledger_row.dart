import 'package:flutter/material.dart';

import 'package:receipt_tamer/core/utils/date_formatter.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/presentation/widgets/common/ledger_month_sheet.dart';

class InvoiceLedgerRow extends StatelessWidget {
  final Invoice invoice;
  final int orderCount;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;

  const InvoiceLedgerRow({
    super.key,
    required this.invoice,
    required this.orderCount,
    this.onTap,
    this.onLongPress,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateFormatter.resolveLedgerDate(
      businessDate: invoice.invoiceDate,
      createdAt: invoice.createdAt,
    );
    final invoiceNumber = invoice.invoiceNumber.trim();
    final hasLinkedOrders = orderCount > 0;

    return LedgerEntryRow(
      day: date?.day.toString().padLeft(2, '0') ?? '--',
      dateCaption: '日',
      title: invoice.sellerName.trim().isEmpty
          ? '未知商家'
          : invoice.sellerName.trim(),
      subtitle: invoiceNumber.isEmpty ? '无发票号' : '发票号 $invoiceNumber',
      amount: DateFormatter.formatAmount(invoice.totalAmount),
      relationLabel: hasLinkedOrders ? '已关联 $orderCount 笔' : '未关联订单',
      relationTone: hasLinkedOrders
          ? LedgerRelationTone.linked
          : LedgerRelationTone.action,
      onTap: onTap,
      onLongPress: onLongPress,
      selected: selected,
    );
  }
}

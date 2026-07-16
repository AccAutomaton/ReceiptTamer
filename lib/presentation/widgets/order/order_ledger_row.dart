import 'package:flutter/material.dart';

import 'package:receipt_tamer/core/utils/date_formatter.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/presentation/widgets/common/ledger_month_sheet.dart';

class OrderLedgerRow extends StatelessWidget {
  final Order order;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;

  const OrderLedgerRow({
    super.key,
    required this.order,
    this.onTap,
    this.onLongPress,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateFormatter.resolveLedgerDate(
      businessDate: order.orderDate,
      createdAt: order.createdAt,
    );
    final mealTime = DateFormatter.mealTimeToDisplayName(
      DateFormatter.mealTimeFromString(order.mealTime),
    );
    final hasMealTime = mealTime != '-';
    final orderNumber = order.orderNumber.trim();

    return LedgerEntryRow(
      day: date?.day.toString().padLeft(2, '0') ?? '--',
      dateCaption: hasMealTime ? mealTime : '—',
      title: order.shopName.trim().isEmpty ? '未命名店铺' : order.shopName.trim(),
      subtitle: orderNumber.isEmpty ? '无订单号' : '#$orderNumber',
      amount: DateFormatter.formatAmount(order.amount),
      relationLabel: order.hasInvoice ? '已关联发票' : '未关联发票',
      relationTone: order.hasInvoice
          ? LedgerRelationTone.linked
          : LedgerRelationTone.neutral,
      onTap: onTap,
      onLongPress: onLongPress,
      selected: selected,
    );
  }
}

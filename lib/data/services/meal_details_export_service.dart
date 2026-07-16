import 'dart:io';

import 'package:receipt_tamer/core/services/log_config.dart';
import 'package:receipt_tamer/core/services/log_service.dart';
import 'package:receipt_tamer/data/models/daily_meal_details.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/data/services/invoice_proration_util.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart';

/// Meal details export service
/// Generates Excel spreadsheet with daily meal expense breakdown
class MealDetailsExportService {
  /// Prepare daily meal details from selected invoices and their orders
  /// Groups orders by date and meal time, applies invoice amount proration
  /// When [fillMissingDates] is true, fills all dates between first and last order date
  static Future<List<DailyMealDetails>> prepareDailyMealDetails({
    required List<Invoice> invoices,
    required Future<List<int>> Function(int) getOrderIdsForInvoice,
    required Future<Order?> Function(int) getOrderById,
    bool fillMissingDates = false,
  }) async {
    // Map to store daily amounts: date -> mealTime -> {paid, invoice}
    final dailyAmounts = <String, Map<String, _MealAmount>>{};
    final invoiceIdByOrder = <int, int>{};
    final processedInvoiceIds = <int>{};

    for (final invoice in invoices) {
      if (invoice.id == null) continue;
      if (!processedInvoiceIds.add(invoice.id!)) continue;

      final orderIds = (await getOrderIdsForInvoice(invoice.id!)).toSet();
      if (orderIds.isEmpty) continue;

      // Get all orders for this invoice
      final orders = <Order>[];
      for (final orderId in orderIds) {
        final previousInvoiceId = invoiceIdByOrder[orderId];
        if (previousInvoiceId != null && previousInvoiceId != invoice.id) {
          throw StateError(
            '订单 $orderId 同时关联发票 $previousInvoiceId 与 ${invoice.id}',
          );
        }
        invoiceIdByOrder[orderId] = invoice.id!;

        final order = await getOrderById(orderId);
        if (order != null) {
          orders.add(order);
        }
      }

      if (orders.isEmpty) continue;

      // Use shared proration utility
      final prorationResult = InvoiceProrationUtil.calculate(
        invoice: invoice,
        orders: orders,
      );

      // Distribute amounts to dates and meal times
      for (final proratedOrder in prorationResult.orderAmounts) {
        final order = proratedOrder.order;
        final orderDate = order.orderDate;
        if (orderDate == null || orderDate.isEmpty) continue;

        final paidAmount = order.amount;
        final invoiceAmount = proratedOrder.proratedInvoiceAmount;

        // Get meal time
        final mealTime =
            order.mealTime ?? 'lunch'; // Default to lunch if not specified

        // Initialize date entry if not exists
        dailyAmounts.putIfAbsent(
          orderDate,
          () => {
            'breakfast': _MealAmount(),
            'lunch': _MealAmount(),
            'dinner': _MealAmount(),
          },
        );

        // Add amounts to appropriate meal time
        dailyAmounts[orderDate]![mealTime]!.paid += paidAmount;
        dailyAmounts[orderDate]![mealTime]!.invoice += invoiceAmount;
      }
    }

    // If fillMissingDates is true, fill all dates between first and last
    if (fillMissingDates && dailyAmounts.isNotEmpty) {
      final sortedDates = dailyAmounts.keys.toList()..sort();
      final firstDate = DateTime.parse(sortedDates.first);
      final lastDate = DateTime.parse(sortedDates.last);

      // Fill all dates in between
      for (
        var date = firstDate;
        !date.isAfter(lastDate);
        date = date.add(const Duration(days: 1))
      ) {
        final dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        dailyAmounts.putIfAbsent(
          dateStr,
          () => {
            'breakfast': _MealAmount(),
            'lunch': _MealAmount(),
            'dinner': _MealAmount(),
          },
        );
      }
    }

    // Convert to DailyMealDetails list
    final details = dailyAmounts.entries.map((entry) {
      final date = entry.key;
      final meals = entry.value;
      final breakfast = meals['breakfast'] ?? _MealAmount();
      final lunch = meals['lunch'] ?? _MealAmount();
      final dinner = meals['dinner'] ?? _MealAmount();

      return DailyMealDetails(
        date: date,
        breakfastPaid: breakfast.paid,
        breakfastInvoice: breakfast.invoice,
        lunchPaid: lunch.paid,
        lunchInvoice: lunch.invoice,
        dinnerPaid: dinner.paid,
        dinnerInvoice: dinner.invoice,
      );
    }).toList();

    // Sort by date ascending
    details.sort((a, b) => a.date.compareTo(b.date));

    return details;
  }

  /// Generate Excel file for meal details
  static Future<void> generateExcel({
    required List<DailyMealDetails> items,
    required String outputPath,
    bool skipEmptyDays = false,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('Items list cannot be empty');
    }

    logService.i(LogConfig.moduleFile, '开始生成用餐明细Excel，共 ${items.length} 项');

    try {
      final bytes = buildExcelBytes(items: items, skipEmptyDays: skipEmptyDays);
      final file = File(outputPath);
      await file.writeAsBytes(bytes);

      logService.diag(LogConfig.moduleFile, '文件大小', '${bytes.length} bytes');
      logService.i(LogConfig.moduleFile, '用餐明细Excel已导出: $outputPath');
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleFile, '用餐明细Excel导出失败', e, stackTrace);
      rethrow;
    }
  }

  /// Build Excel bytes for meal details.
  static List<int> buildExcelBytes({
    required List<DailyMealDetails> items,
    bool skipEmptyDays = false,
  }) {
    if (items.isEmpty) {
      throw ArgumentError('Items list cannot be empty');
    }

    final displayItems = skipEmptyDays
        ? items.where((item) => item.hasAnyMeal).toList()
        : items;

    if (displayItems.isEmpty) {
      throw ArgumentError('No items to export after filtering');
    }

    final workbook = Workbook();
    try {
      final sheet = workbook.worksheets[0];
      sheet.name = '用餐明细';

      // Set column widths.
      sheet.getRangeByIndex(1, 1).columnWidth = 18; // 日期
      sheet.getRangeByIndex(1, 2).columnWidth = 12; // 早餐实付
      sheet.getRangeByIndex(1, 3).columnWidth = 12; // 早餐发票
      sheet.getRangeByIndex(1, 4).columnWidth = 12; // 午餐实付
      sheet.getRangeByIndex(1, 5).columnWidth = 12; // 午餐发票
      sheet.getRangeByIndex(1, 6).columnWidth = 12; // 晚餐实付
      sheet.getRangeByIndex(1, 7).columnWidth = 12; // 晚餐发票
      sheet.getRangeByIndex(1, 8).columnWidth = 12; // 实付总额
      sheet.getRangeByIndex(1, 9).columnWidth = 12; // 发票总额

      // Create header row.
      _setHeaderValue(sheet, 1, 1, '日期');
      _setHeaderValue(sheet, 1, 2, '早餐实付');
      _setHeaderValue(sheet, 1, 3, '早餐发票');
      _setHeaderValue(sheet, 1, 4, '午餐实付');
      _setHeaderValue(sheet, 1, 5, '午餐发票');
      _setHeaderValue(sheet, 1, 6, '晚餐实付');
      _setHeaderValue(sheet, 1, 7, '晚餐发票');
      _setHeaderValue(sheet, 1, 8, '实付总额');
      _setHeaderValue(sheet, 1, 9, '发票总额');

      // Add data rows.
      for (var i = 0; i < displayItems.length; i++) {
        final item = displayItems[i];
        final rowIndex = i + 2;

        _setCellValue(sheet, rowIndex, 1, item.dateDisplay);
        _setAmountValue(sheet, rowIndex, 2, item.breakfastPaid);
        _setAmountValue(sheet, rowIndex, 3, item.breakfastInvoice);
        _setAmountValue(sheet, rowIndex, 4, item.lunchPaid);
        _setAmountValue(sheet, rowIndex, 5, item.lunchInvoice);
        _setAmountValue(sheet, rowIndex, 6, item.dinnerPaid);
        _setAmountValue(sheet, rowIndex, 7, item.dinnerInvoice);
        _setAmountValue(sheet, rowIndex, 8, item.totalPaid);
        _setAmountValue(sheet, rowIndex, 9, item.totalInvoice);
      }

      // Add summary row.
      final summaryRowIndex = displayItems.length + 2;
      _setCellValue(sheet, summaryRowIndex, 1, '总计');
      _setAmountValue(
        sheet,
        summaryRowIndex,
        2,
        displayItems.fold(0.0, (sum, item) => sum + item.breakfastPaid),
      );
      _setAmountValue(
        sheet,
        summaryRowIndex,
        3,
        displayItems.fold(0.0, (sum, item) => sum + item.breakfastInvoice),
      );
      _setAmountValue(
        sheet,
        summaryRowIndex,
        4,
        displayItems.fold(0.0, (sum, item) => sum + item.lunchPaid),
      );
      _setAmountValue(
        sheet,
        summaryRowIndex,
        5,
        displayItems.fold(0.0, (sum, item) => sum + item.lunchInvoice),
      );
      _setAmountValue(
        sheet,
        summaryRowIndex,
        6,
        displayItems.fold(0.0, (sum, item) => sum + item.dinnerPaid),
      );
      _setAmountValue(
        sheet,
        summaryRowIndex,
        7,
        displayItems.fold(0.0, (sum, item) => sum + item.dinnerInvoice),
      );
      _setAmountValue(
        sheet,
        summaryRowIndex,
        8,
        displayItems.fold(0.0, (sum, item) => sum + item.totalPaid),
      );
      _setAmountValue(
        sheet,
        summaryRowIndex,
        9,
        displayItems.fold(0.0, (sum, item) => sum + item.totalInvoice),
      );

      return workbook.saveAsStream();
    } finally {
      workbook.dispose();
    }
  }

  /// Set header cell value with bold style
  static void _setHeaderValue(
    Worksheet sheet,
    int rowIndex,
    int colIndex,
    String value,
  ) {
    final cell = sheet.getRangeByIndex(rowIndex, colIndex);
    cell.setText(value);
    cell.cellStyle.bold = true;
    cell.cellStyle.hAlign = HAlignType.center;
  }

  /// Set cell value
  static void _setCellValue(
    Worksheet sheet,
    int rowIndex,
    int colIndex,
    String value,
  ) {
    final cell = sheet.getRangeByIndex(rowIndex, colIndex);
    cell.setText(value);
    cell.cellStyle.hAlign = HAlignType.center;
  }

  /// Set amount cell value (numeric format with 2 decimal places)
  static void _setAmountValue(
    Worksheet sheet,
    int rowIndex,
    int colIndex,
    double amount,
  ) {
    final cell = sheet.getRangeByIndex(rowIndex, colIndex);
    cell.setNumber(amount);
    cell.numberFormat = '0.00';
    cell.cellStyle.hAlign = HAlignType.right;
  }
}

/// Helper class to store paid and invoice amounts for a meal
class _MealAmount {
  double paid = 0.0;
  double invoice = 0.0;
}

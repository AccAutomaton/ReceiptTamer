import 'dart:io';

import 'package:receipt_tamer/core/services/log_config.dart';
import 'package:receipt_tamer/core/services/log_service.dart';
import 'package:receipt_tamer/data/models/daily_meal_details.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/data/services/invoice_proration_util.dart';
import 'package:excel/excel.dart';

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

    for (final invoice in invoices) {
      if (invoice.id == null) continue;

      final orderIds = await getOrderIdsForInvoice(invoice.id!);
      if (orderIds.isEmpty) continue;

      // Get all orders for this invoice
      final orders = <Order>[];
      for (final orderId in orderIds) {
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
        final mealTime = order.mealTime ?? 'lunch'; // Default to lunch if not specified

        // Initialize date entry if not exists
        dailyAmounts.putIfAbsent(orderDate, () => {
          'breakfast': _MealAmount(),
          'lunch': _MealAmount(),
          'dinner': _MealAmount(),
        });

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
      for (var date = firstDate; !date.isAfter(lastDate); date = date.add(const Duration(days: 1))) {
        final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        dailyAmounts.putIfAbsent(dateStr, () => {
          'breakfast': _MealAmount(),
          'lunch': _MealAmount(),
          'dinner': _MealAmount(),
        });
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

    // Filter out empty days if requested
    final displayItems = skipEmptyDays
        ? items.where((item) => item.hasAnyMeal).toList()
        : items;

    if (displayItems.isEmpty) {
      throw ArgumentError('No items to export after filtering');
    }

    try {
      // Create Excel document
      final excel = Excel.createExcel();
      final sheetName = '用餐明细';

      // Access the new sheet first (this creates it), then delete Sheet1
      final sheet = excel[sheetName];
      excel.delete('Sheet1');

      // Set column widths
      sheet.setColumnWidth(0, 18);  // 日期
      sheet.setColumnWidth(1, 12);  // 早餐实付
      sheet.setColumnWidth(2, 12);  // 早餐发票
      sheet.setColumnWidth(3, 12);  // 午餐实付
      sheet.setColumnWidth(4, 12);  // 午餐发票
      sheet.setColumnWidth(5, 12);  // 晚餐实付
      sheet.setColumnWidth(6, 12);  // 晚餐发票
      sheet.setColumnWidth(7, 12);  // 实付总额
      sheet.setColumnWidth(8, 12);  // 发票总额

      // Create header row
      _setHeaderValue(sheet, 0, 0, '日期');
      _setHeaderValue(sheet, 0, 1, '早餐实付');
      _setHeaderValue(sheet, 0, 2, '早餐发票');
      _setHeaderValue(sheet, 0, 3, '午餐实付');
      _setHeaderValue(sheet, 0, 4, '午餐发票');
      _setHeaderValue(sheet, 0, 5, '晚餐实付');
      _setHeaderValue(sheet, 0, 6, '晚餐发票');
      _setHeaderValue(sheet, 0, 7, '实付总额');
      _setHeaderValue(sheet, 0, 8, '发票总额');

      // Add data rows
      for (var i = 0; i < displayItems.length; i++) {
        final item = displayItems[i];
        final rowIndex = i + 1;

        _setCellValue(sheet, rowIndex, 0, item.dateDisplay);
        _setAmountValue(sheet, rowIndex, 1, item.breakfastPaid);
        _setAmountValue(sheet, rowIndex, 2, item.breakfastInvoice);
        _setAmountValue(sheet, rowIndex, 3, item.lunchPaid);
        _setAmountValue(sheet, rowIndex, 4, item.lunchInvoice);
        _setAmountValue(sheet, rowIndex, 5, item.dinnerPaid);
        _setAmountValue(sheet, rowIndex, 6, item.dinnerInvoice);
        _setAmountValue(sheet, rowIndex, 7, item.totalPaid);
        _setAmountValue(sheet, rowIndex, 8, item.totalInvoice);
      }

      // Add summary row
      final summaryRowIndex = displayItems.length + 1;
      _setCellValue(sheet, summaryRowIndex, 0, '总计');
      _setAmountValue(sheet, summaryRowIndex, 1,
          displayItems.fold(0.0, (sum, item) => sum + item.breakfastPaid));
      _setAmountValue(sheet, summaryRowIndex, 2,
          displayItems.fold(0.0, (sum, item) => sum + item.breakfastInvoice));
      _setAmountValue(sheet, summaryRowIndex, 3,
          displayItems.fold(0.0, (sum, item) => sum + item.lunchPaid));
      _setAmountValue(sheet, summaryRowIndex, 4,
          displayItems.fold(0.0, (sum, item) => sum + item.lunchInvoice));
      _setAmountValue(sheet, summaryRowIndex, 5,
          displayItems.fold(0.0, (sum, item) => sum + item.dinnerPaid));
      _setAmountValue(sheet, summaryRowIndex, 6,
          displayItems.fold(0.0, (sum, item) => sum + item.dinnerInvoice));
      _setAmountValue(sheet, summaryRowIndex, 7,
          displayItems.fold(0.0, (sum, item) => sum + item.totalPaid));
      _setAmountValue(sheet, summaryRowIndex, 8,
          displayItems.fold(0.0, (sum, item) => sum + item.totalInvoice));

      // Save file
      final bytes = excel.encode();
      if (bytes == null) {
        throw Exception('Failed to encode Excel file');
      }

      final file = File(outputPath);
      await file.writeAsBytes(bytes);

      logService.diag(LogConfig.moduleFile, '文件大小', '${bytes.length} bytes');
      logService.i(LogConfig.moduleFile, '用餐明细Excel已导出: $outputPath');
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleFile, '用餐明细Excel导出失败', e, stackTrace);
      rethrow;
    }
  }

  /// Set header cell value with bold style
  static void _setHeaderValue(Sheet sheet, int rowIndex, int colIndex, String value) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: rowIndex),
    );
    cell.value = TextCellValue(value);
    cell.cellStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );
  }

  /// Set cell value
  static void _setCellValue(Sheet sheet, int rowIndex, int colIndex, String value) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: rowIndex),
    );
    cell.value = TextCellValue(value);
    cell.cellStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Center,
    );
  }

  /// Set amount cell value (always shows 2 decimal places)
  static void _setAmountValue(Sheet sheet, int rowIndex, int colIndex, double amount) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: rowIndex),
    );
    cell.value = TextCellValue(amount.toStringAsFixed(2));
    cell.cellStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Right,
    );
  }
}

/// Helper class to store paid and invoice amounts for a meal
class _MealAmount {
  double paid = 0.0;
  double invoice = 0.0;
}
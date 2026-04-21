import 'dart:io';
import 'dart:ui';

import 'package:receipt_tamer/core/services/log_config.dart';
import 'package:receipt_tamer/core/services/log_service.dart';
import 'package:receipt_tamer/core/services/pdf_font_service.dart';
import 'package:receipt_tamer/core/utils/date_formatter.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// PDF export service for generating order and invoice PDF documents
class PdfExportService {
  /// Generate orders list PDF
  static Future<void> generateOrdersPdf(
    List<Order> orders,
    String outputPath,
  ) async {
    logService.i(LogConfig.moduleFile, '开始生成订单列表PDF，共 ${orders.length} 条');

    final document = PdfDocument();
    document.documentInformation.title = '订单列表';

    try {
      // Add page with header
      final page = document.pages.add();
      final graphics = page.graphics;

      // Define fonts - use TrueType font for Chinese characters
      final titleFont = await PdfFontService.instance.getChineseFont(18);
      final headerFont = await PdfFontService.instance.getChineseFont(10);
      final contentFont = await PdfFontService.instance.getChineseFont(9);

      final blackBrush = PdfSolidBrush(PdfColor(0, 0, 0));
      final grayBrush = PdfSolidBrush(PdfColor(128, 128, 128));
      final headerBrush = PdfSolidBrush(PdfColor(240, 240, 240));

      // Draw title
      graphics.drawString(
        '订单列表',
        titleFont,
        brush: blackBrush,
        bounds: Rect.fromLTWH(0, 0, 500, 30),
      );

      // Draw generation time
      graphics.drawString(
        '生成时间: ${DateFormatter.formatDisplay(DateTime.now())}',
        contentFont,
        brush: grayBrush,
        bounds: Rect.fromLTWH(0, 25, 300, 15),
      );

      // Define table columns
      const colWidths = [100.0, 60.0, 70.0, 50.0, 100.0, 120.0]; // shopName, amount, date, mealTime, orderNumber, createdAt
      const colHeaders = ['店铺名称', '金额', '日期', '时段', '订单号', '录入时间'];

      // Draw table header
      double y = 50;
      double x = 0;
      const rowHeight = 20.0;

      for (int i = 0; i < colHeaders.length; i++) {
        graphics.drawRectangle(
          brush: headerBrush,
          bounds: Rect.fromLTWH(x, y, colWidths[i], rowHeight),
        );
        graphics.drawString(
          colHeaders[i],
          headerFont,
          brush: blackBrush,
          bounds: Rect.fromLTWH(x + 5, y + 3, colWidths[i] - 10, rowHeight - 6),
        );
        x += colWidths[i];
      }

      y += rowHeight;

      // Draw data rows
      for (final order in orders) {
        x = 0;

        // Shop name
        graphics.drawString(
          _truncateText(order.shopName, 12),
          contentFont,
          brush: blackBrush,
          bounds: Rect.fromLTWH(x + 5, y + 3, colWidths[0] - 10, rowHeight - 6),
        );
        x += colWidths[0];

        // Amount
        graphics.drawString(
          DateFormatter.formatAmount(order.amount),
          contentFont,
          brush: blackBrush,
          bounds: Rect.fromLTWH(x + 5, y + 3, colWidths[1] - 10, rowHeight - 6),
        );
        x += colWidths[1];

        // Date
        graphics.drawString(
          order.orderDate ?? '-',
          contentFont,
          brush: blackBrush,
          bounds: Rect.fromLTWH(x + 5, y + 3, colWidths[2] - 10, rowHeight - 6),
        );
        x += colWidths[2];

        // Meal time
        graphics.drawString(
          DateFormatter.mealTimeToDisplayName(
              DateFormatter.mealTimeFromString(order.mealTime)),
          contentFont,
          brush: blackBrush,
          bounds: Rect.fromLTWH(x + 5, y + 3, colWidths[3] - 10, rowHeight - 6),
        );
        x += colWidths[3];

        // Order number
        graphics.drawString(
          _truncateText(order.orderNumber, 14),
          contentFont,
          brush: blackBrush,
          bounds: Rect.fromLTWH(x + 5, y + 3, colWidths[4] - 10, rowHeight - 6),
        );
        x += colWidths[4];

        // Created at
        graphics.drawString(
          _formatDateTime(order.createdAt),
          contentFont,
          brush: blackBrush,
          bounds: Rect.fromLTWH(x + 5, y + 3, colWidths[5] - 10, rowHeight - 6),
        );

        y += rowHeight;

        // Add new page if needed
        if (y > page.getClientSize().height - 50) {
          document.pages.add();
          y = 50;
        }
      }

      // Add summary at the end
      y += 20;
      final totalAmount = orders.fold<double>(0, (sum, o) => sum + o.amount);
      graphics.drawString(
        '合计: ${orders.length} 条订单，总金额 ${DateFormatter.formatAmount(totalAmount)}',
        headerFont,
        brush: blackBrush,
        bounds: Rect.fromLTWH(0, y, 500, 20),
      );

      // Save document
      final bytes = document.saveSync();
      document.dispose();

      await File(outputPath).writeAsBytes(bytes);

      logService.diag(LogConfig.moduleFile, '文件大小', '${bytes.length} bytes');
      logService.i(LogConfig.moduleFile, '订单列表PDF已导出: $outputPath');
    } catch (e, stackTrace) {
      document.dispose();
      logService.e(LogConfig.moduleFile, '订单列表PDF导出失败', e, stackTrace);
      rethrow;
    }
  }

  /// Generate invoices list PDF
  static Future<void> generateInvoicesPdf(
    List<Invoice> invoices,
    String outputPath,
  ) async {
    logService.i(LogConfig.moduleFile, '开始生成发票列表PDF，共 ${invoices.length} 张');

    final document = PdfDocument();
    document.documentInformation.title = '发票列表';

    try {
      // Add page with header
      final page = document.pages.add();
      final graphics = page.graphics;

      // Define fonts - use TrueType font for Chinese characters
      final titleFont = await PdfFontService.instance.getChineseFont(18);
      final headerFont = await PdfFontService.instance.getChineseFont(10);
      final contentFont = await PdfFontService.instance.getChineseFont(9);

      final blackBrush = PdfSolidBrush(PdfColor(0, 0, 0));
      final grayBrush = PdfSolidBrush(PdfColor(128, 128, 128));
      final headerBrush = PdfSolidBrush(PdfColor(240, 240, 240));

      // Draw title
      graphics.drawString(
        '发票列表',
        titleFont,
        brush: blackBrush,
        bounds: Rect.fromLTWH(0, 0, 500, 30),
      );

      // Draw generation time
      graphics.drawString(
        '生成时间: ${DateFormatter.formatDisplay(DateTime.now())}',
        contentFont,
        brush: grayBrush,
        bounds: Rect.fromLTWH(0, 25, 300, 15),
      );

      // Define table columns
      const colWidths = [100.0, 60.0, 60.0, 120.0, 80.0]; // invoiceNumber, invoiceDate, totalAmount, sellerName, createdAt
      const colHeaders = ['发票号码', '开票日期', '价税合计', '销售方名称', '录入时间'];

      // Draw table header
      double y = 50;
      double x = 0;
      const rowHeight = 20.0;

      for (int i = 0; i < colHeaders.length; i++) {
        graphics.drawRectangle(
          brush: headerBrush,
          bounds: Rect.fromLTWH(x, y, colWidths[i], rowHeight),
        );
        graphics.drawString(
          colHeaders[i],
          headerFont,
          brush: blackBrush,
          bounds: Rect.fromLTWH(x + 5, y + 3, colWidths[i] - 10, rowHeight - 6),
        );
        x += colWidths[i];
      }

      y += rowHeight;

      // Draw data rows
      for (final invoice in invoices) {
        x = 0;

        // Invoice number
        graphics.drawString(
          _truncateText(invoice.invoiceNumber, 12),
          contentFont,
          brush: blackBrush,
          bounds: Rect.fromLTWH(x + 5, y + 3, colWidths[0] - 10, rowHeight - 6),
        );
        x += colWidths[0];

        // Invoice date
        graphics.drawString(
          invoice.invoiceDate ?? '-',
          contentFont,
          brush: blackBrush,
          bounds: Rect.fromLTWH(x + 5, y + 3, colWidths[1] - 10, rowHeight - 6),
        );
        x += colWidths[1];

        // Total amount
        graphics.drawString(
          DateFormatter.formatAmount(invoice.totalAmount),
          contentFont,
          brush: blackBrush,
          bounds: Rect.fromLTWH(x + 5, y + 3, colWidths[2] - 10, rowHeight - 6),
        );
        x += colWidths[2];

        // Seller name
        graphics.drawString(
          _truncateText(invoice.sellerName, 15),
          contentFont,
          brush: blackBrush,
          bounds: Rect.fromLTWH(x + 5, y + 3, colWidths[3] - 10, rowHeight - 6),
        );
        x += colWidths[3];

        // Created at
        graphics.drawString(
          _formatDateTime(invoice.createdAt),
          contentFont,
          brush: blackBrush,
          bounds: Rect.fromLTWH(x + 5, y + 3, colWidths[4] - 10, rowHeight - 6),
        );

        y += rowHeight;

        // Add new page if needed
        if (y > page.getClientSize().height - 50) {
          document.pages.add();
          y = 50;
        }
      }

      // Add summary at the end
      y += 20;
      final totalAmount = invoices.fold<double>(0, (sum, i) => sum + i.totalAmount);
      graphics.drawString(
        '合计: ${invoices.length} 张发票，总金额 ${DateFormatter.formatAmount(totalAmount)}',
        headerFont,
        brush: blackBrush,
        bounds: Rect.fromLTWH(0, y, 500, 20),
      );

      // Save document
      final bytes = document.saveSync();
      document.dispose();

      await File(outputPath).writeAsBytes(bytes);

      logService.diag(LogConfig.moduleFile, '文件大小', '${bytes.length} bytes');
      logService.i(LogConfig.moduleFile, '发票列表PDF已导出: $outputPath');
    } catch (e, stackTrace) {
      document.dispose();
      logService.e(LogConfig.moduleFile, '发票列表PDF导出失败', e, stackTrace);
      rethrow;
    }
  }

  static String _truncateText(String text, int maxChars) {
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars - 2)}..';
  }

  static String _formatDateTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoString;
    }
  }
}
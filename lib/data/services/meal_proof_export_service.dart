import 'dart:io';
import 'dart:ui';

import 'package:catering_receipt_recorder/core/utils/date_formatter.dart';
import 'package:catering_receipt_recorder/data/models/invoice.dart';
import 'package:catering_receipt_recorder/data/models/meal_proof_item.dart';
import 'package:catering_receipt_recorder/data/models/order.dart';
import 'package:catering_receipt_recorder/data/services/invoice_proration_util.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Meal proof export service
/// Generates meal proof PDF documents from selected invoices and orders
class MealProofExportService {
  /// Prepare meal proof items from selected invoices and their orders
  static Future<List<MealProofItem>> prepareMealProofItems({
    required List<Invoice> invoices,
    required Future<List<int>> Function(int) getOrderIdsForInvoice,
    required Future<Order?> Function(int) getOrderById,
  }) async {
    final items = <MealProofItem>[];

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

      for (final proratedOrder in prorationResult.orderAmounts) {
        items.add(MealProofItem(
          order: proratedOrder.order,
          invoice: invoice,
          proratedInvoiceAmount: proratedOrder.proratedInvoiceAmount,
          totalInvoiceAmount: invoice.totalAmount,
          isProRated: prorationResult.needsProration,
        ));
      }
    }

    // Sort items by date and meal time
    _sortMealProofItems(items);

    return items;
  }

  /// Sort meal proof items by date (ascending) and meal time (breakfast < lunch < dinner)
  static void _sortMealProofItems(List<MealProofItem> items) {
    items.sort((a, b) {
      // First sort by date (ascending)
      final dateA = a.order.orderDate ?? '';
      final dateB = b.order.orderDate ?? '';
      final dateCompare = dateA.compareTo(dateB);
      if (dateCompare != 0) return dateCompare;

      // Then sort by meal time
      final mealTimeA = DateFormatter.mealTimeFromString(a.order.mealTime);
      final mealTimeB = DateFormatter.mealTimeFromString(b.order.mealTime);
      final indexA = mealTimeA?.index ?? 99;
      final indexB = mealTimeB?.index ?? 99;
      return indexA.compareTo(indexB);
    });
  }

  /// Generate PDF document for meal proof
  static Future<void> generatePdf({
    required List<MealProofItem> items,
    required String outputPath,
    required String Function(String) getImagePath, // Function to resolve image path
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('Items list cannot be empty');
    }

    final document = PdfDocument();
    document.pageSettings.size = PdfPageSize.a4;
    document.pageSettings.margins.all = 36; // Narrow margins (~1.27cm / 0.5 inch)

    // Define fonts - use CJK font for Chinese characters
    final titleFont = PdfCjkStandardFont(
      PdfCjkFontFamily.heiseiKakuGothicW5,
      10,
    );

    try {
      // Process items in groups of 4 (2x2 grid per page)
      for (var pageIndex = 0; pageIndex * 4 < items.length; pageIndex++) {
        final startIndex = pageIndex * 4;
        final endIndex = startIndex + 4 > items.length ? items.length : startIndex + 4;
        final pageItems = items.sublist(startIndex, endIndex);

        // Add a new page for each iteration
        final page = document.pages.add();
        final graphics = page.graphics;

        // Get page dimensions
        final pageSize = page.getClientSize();
        final pageWidth = pageSize.width;
        final pageHeight = pageSize.height;

        // Calculate cell dimensions
        // Layout: 4 rows * 2 columns
        // Row 1 & 3: text (shorter)
        // Row 2 & 4: image (taller)
        final cellWidth = pageWidth / 2;
        final textRowHeight = 40.0; // Height for text rows
        final imageRowHeight = (pageHeight - textRowHeight * 2) / 2; // Height for image rows

        // Fill content for each cell (max 4 items per page)
        for (var j = 0; j < pageItems.length; j++) {
          final item = pageItems[j];
          final col = j % 2; // 0 or 1
          final rowPair = j ~/ 2; // 0 (items 0,1) or 1 (items 2,3)

          // Calculate position
          final x = col * cellWidth;
          final textY = rowPair * (textRowHeight + imageRowHeight);
          final imageY = textY + textRowHeight;

          // Draw text cell
          _drawTextCell(
            graphics: graphics,
            item: item,
            x: x,
            y: textY,
            width: cellWidth,
            height: textRowHeight,
            font: titleFont,
          );

          // Draw image cell
          await _drawImageCell(
            graphics: graphics,
            imagePath: item.order.imagePath,
            getImagePath: getImagePath,
            x: x,
            y: imageY,
            width: cellWidth,
            height: imageRowHeight,
          );
        }
      }

      // Save document
      final bytes = document.saveSync();
      document.dispose();

      // Validate output path
      if (outputPath.isEmpty) {
        throw ArgumentError('Output path cannot be empty');
      }

      final file = File(outputPath);
      await file.writeAsBytes(bytes);
    } catch (e) {
      document.dispose();
      rethrow;
    }
  }

  /// Draw text cell with meal information
  static void _drawTextCell({
    required PdfGraphics graphics,
    required MealProofItem item,
    required double x,
    required double y,
    required double width,
    required double height,
    required PdfFont font,
  }) {
    final blackBrush = PdfSolidBrush(PdfColor(0, 0, 0));

    // Line 1: "yyyy年MM月dd日 x餐"
    final line1 = '${item.dateDisplay} ${item.mealTimeDisplay}';
    // Line 2: "实付xx.xx元|发票金额xx.xx元"
    final line2 = '${item.amountDisplay}|发票金额${item.invoiceAmountDisplay}';

    // Calculate line heights for centering
    final lineHeight = font.height;
    final totalTextHeight = lineHeight * 2;
    final startY = y + (height - totalTextHeight) / 2;

    // Draw line 1 (centered horizontally)
    final line1Size = font.measureString(line1);
    final line1X = x + (width - line1Size.width) / 2;
    graphics.drawString(
      line1,
      font,
      brush: blackBrush,
      bounds: Rect.fromLTWH(line1X, startY, line1Size.width, lineHeight),
    );

    // Draw line 2 (centered horizontally)
    final line2Size = font.measureString(line2);
    final line2X = x + (width - line2Size.width) / 2;
    graphics.drawString(
      line2,
      font,
      brush: blackBrush,
      bounds: Rect.fromLTWH(line2X, startY + lineHeight, line2Size.width, lineHeight),
    );
  }

  /// Draw image cell with aspect ratio preserved
  static Future<void> _drawImageCell({
    required PdfGraphics graphics,
    required String imagePath,
    required String Function(String) getImagePath,
    required double x,
    required double y,
    required double width,
    required double height,
  }) async {
    if (imagePath.isEmpty) return;

    try {
      final resolvedPath = getImagePath(imagePath);
      final file = File(resolvedPath);
      if (!await file.exists()) return;

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;

      final image = PdfBitmap(bytes);

      // Validate image dimensions
      if (image.width <= 0 || image.height <= 0) return;

      // Calculate aspect ratio
      final imgWidth = image.width.toDouble();
      final imgHeight = image.height.toDouble();
      final imgRatio = imgWidth / imgHeight;
      final cellRatio = width / height;

      double drawWidth, drawHeight;
      if (imgRatio > cellRatio) {
        // Image is wider than cell, fit to width
        drawWidth = width - 10; // Small padding
        drawHeight = drawWidth / imgRatio;
      } else {
        // Image is taller than cell, fit to height
        drawHeight = height - 10;
        drawWidth = drawHeight * imgRatio;
      }

      // Ensure dimensions are valid
      if (drawWidth <= 0 || drawHeight <= 0) return;

      // Center image in cell
      final drawX = x + (width - drawWidth) / 2;
      final drawY = y + (height - drawHeight) / 2;

      graphics.drawImage(
        image,
        Rect.fromLTWH(drawX, drawY, drawWidth, drawHeight),
      );
    } catch (e) {
      // Ignore image loading errors, but could log for debugging
      // print('Error loading image: $e');
    }
  }
}
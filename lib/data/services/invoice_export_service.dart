import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Invoice export item for PDF generation
/// Represents a single invoice with its associated orders
class InvoiceExportItem {
  final Invoice invoice;
  final List<Order> orders;

  const InvoiceExportItem({
    required this.invoice,
    required this.orders,
  });

  /// Generate time label for the invoice
  /// Format: "yyyy年MM月dd日早/中/晚餐"
  /// Same day meals are combined with "、" (e.g., "中、晚餐")
  /// Different days are separated with "|" (e.g., "早餐|午餐")
  String get timeLabel {
    if (orders.isEmpty) return '';

    // Group orders by date
    final Map<String, List<String>> dateMealMap = {};
    for (final order in orders) {
      final date = order.orderDate ?? '';
      final mealTime = order.mealTime ?? '';
      if (date.isEmpty) continue;

      dateMealMap.putIfAbsent(date, () => []);
      if (mealTime.isNotEmpty && !dateMealMap[date]!.contains(mealTime)) {
        dateMealMap[date]!.add(mealTime);
      }
    }

    if (dateMealMap.isEmpty) return '';

    // Sort dates
    final sortedDates = dateMealMap.keys.toList()..sort();

    // Build label parts
    final parts = <String>[];
    for (final date in sortedDates) {
      final mealTimes = dateMealMap[date]!;
      if (mealTimes.isEmpty) continue;

      // Sort meal times: breakfast, lunch, dinner
      mealTimes.sort((a, b) {
        final indexA = _mealTimeOrder(a);
        final indexB = _mealTimeOrder(b);
        return indexA.compareTo(indexB);
      });

      // Format date
      final datePart = _formatDate(date);

      // Format meal times
      final mealPart = mealTimes.map(_mealTimeDisplayName).join('、');

      parts.add('$datePart$mealPart');
    }

    return parts.join('|');
  }

  int _mealTimeOrder(String mealTime) {
    switch (mealTime) {
      case 'breakfast':
        return 0;
      case 'lunch':
        return 1;
      case 'dinner':
        return 2;
      default:
        return 99;
    }
  }

  String _mealTimeDisplayName(String mealTime) {
    switch (mealTime) {
      case 'breakfast':
        return '早餐';
      case 'lunch':
        return '午餐';
      case 'dinner':
        return '晚餐';
      default:
        return '';
    }
  }

  String _formatDate(String dateStr) {
    // Input format: yyyy-MM-dd
    // Output format: yyyy年MM月dd日
    try {
      final parts = dateStr.split('-');
      if (parts.length >= 3) {
        return '${parts[0]}年${parts[1]}月${parts[2]}日';
      }
    } catch (e) {
      // ignore
    }
    return dateStr;
  }
}

/// Invoice export service
/// Generates PDF documents from selected invoices
class InvoiceExportService {
  /// Prepare invoice export items from selected invoices and their orders
  static Future<List<InvoiceExportItem>> prepareInvoiceExportItems({
    required List<Invoice> invoices,
    required Future<List<int>> Function(int) getOrderIdsForInvoice,
    required Future<Order?> Function(int) getOrderById,
  }) async {
    final items = <InvoiceExportItem>[];

    // Sort invoices by invoice date (ascending)
    final sortedInvoices = List<Invoice>.from(invoices);
    sortedInvoices.sort((a, b) {
      final dateA = a.invoiceDate ?? '';
      final dateB = b.invoiceDate ?? '';
      return dateA.compareTo(dateB);
    });

    for (final invoice in sortedInvoices) {
      if (invoice.id == null) continue;

      final orderIds = await getOrderIdsForInvoice(invoice.id!);

      // Get all orders for this invoice
      final orders = <Order>[];
      for (final orderId in orderIds) {
        final order = await getOrderById(orderId);
        if (order != null) {
          orders.add(order);
        }
      }

      items.add(InvoiceExportItem(
        invoice: invoice,
        orders: orders,
      ));
    }

    return items;
  }

  /// Generate invoice PDF document
  static Future<void> generateInvoicePdf({
    required List<InvoiceExportItem> items,
    required String outputPath,
    required String Function(String) getFilePath,
    bool showTimeLabel = true, // Whether to show time labels on invoices
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('Items list cannot be empty');
    }

    final document = PdfDocument();
    document.pageSettings.size = PdfPageSize.a4;
    document.pageSettings.margins.all = 0; // No margins, we'll handle positioning

    // Define fonts - use CJK font for Chinese characters
    final labelFont = PdfCjkStandardFont(
      PdfCjkFontFamily.heiseiKakuGothicW5,
      9,
    );

    try {
      // Process items in pairs (2 invoices per page)
      for (var i = 0; i < items.length; i += 2) {
        final item1 = items[i];
        final item2 = i + 1 < items.length ? items[i + 1] : null;

        // Add a new page
        final page = document.pages.add();
        final graphics = page.graphics;

        // Get page dimensions
        final pageSize = page.getClientSize();
        final pageWidth = pageSize.width;
        final pageHeight = pageSize.height;

        // Calculate half page height for each invoice
        final halfHeight = pageHeight / 2;

        // Small margin for labels
        const labelMargin = 5.0;

        // Draw first invoice (top half)
        await _drawInvoice(
          graphics: graphics,
          item: item1,
          x: 0,
          y: 0,
          width: pageWidth,
          height: halfHeight,
          labelFont: labelFont,
          getFilePath: getFilePath,
          labelPosition: _LabelPosition.topLeft,
          labelMargin: labelMargin,
          showTimeLabel: showTimeLabel,
        );

        // Draw second invoice (bottom half) if exists
        if (item2 != null) {
          await _drawInvoice(
            graphics: graphics,
            item: item2,
            x: 0,
            y: halfHeight,
            width: pageWidth,
            height: halfHeight,
            labelFont: labelFont,
            getFilePath: getFilePath,
            labelPosition: _LabelPosition.bottomLeft,
            labelMargin: labelMargin,
            showTimeLabel: showTimeLabel,
          );
        }
      }

      // Save document
      final bytes = document.saveSync();
      document.dispose();

      // Write to output file
      final file = File(outputPath);
      await file.writeAsBytes(bytes);
    } catch (e) {
      document.dispose();
      rethrow;
    }
  }

  /// Draw a single invoice in the specified region
  static Future<void> _drawInvoice({
    required PdfGraphics graphics,
    required InvoiceExportItem item,
    required double x,
    required double y,
    required double width,
    required double height,
    required PdfFont labelFont,
    required String Function(String) getFilePath,
    required _LabelPosition labelPosition,
    required double labelMargin,
    bool showTimeLabel = true,
  }) async {
    final imagePath = item.invoice.imagePath;
    if (imagePath.isEmpty) return;

    try {
      final resolvedPath = getFilePath(imagePath);
      final file = File(resolvedPath);
      if (!await file.exists()) return;

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;

      // Check if it's a PDF or image
      final isPdf = imagePath.toLowerCase().endsWith('.pdf');

      if (isPdf) {
        await _drawPdfInvoice(
          graphics: graphics,
          pdfBytes: bytes,
          x: x,
          y: y,
          width: width,
          height: height,
        );
      } else {
        await _drawImageInvoice(
          graphics: graphics,
          imageBytes: bytes,
          x: x,
          y: y,
          width: width,
          height: height,
        );
      }

      // Draw time label if enabled
      if (showTimeLabel) {
        _drawTimeLabel(
          graphics: graphics,
          label: item.timeLabel,
          font: labelFont,
          x: x,
          y: y,
          width: width,
          height: height,
          position: labelPosition,
          margin: labelMargin,
        );
      }
    } catch (e) {
      // Ignore errors for individual invoices
      debugPrint('Error drawing invoice: $e');
    }
  }

  /// Draw an image invoice with auto-rotation
  static Future<void> _drawImageInvoice({
    required PdfGraphics graphics,
    required List<int> imageBytes,
    required double x,
    required double y,
    required double width,
    required double height,
  }) async {
    // Decode image to check dimensions and potentially rotate
    final uint8Bytes = Uint8List.fromList(imageBytes);
    final decodedImage = img.decodeImage(uint8Bytes);
    if (decodedImage == null) return;

    // Get image dimensions
    double imgWidth = decodedImage.width.toDouble();
    double imgHeight = decodedImage.height.toDouble();

    // Check if image needs rotation (if height > width, it's portrait)
    // We want landscape orientation (width > height)
    bool needsRotation = imgHeight > imgWidth;

    // Rotate image if needed
    img.Image finalImage;
    if (needsRotation) {
      // Rotate 90 degrees clockwise to make it landscape
      finalImage = img.copyRotate(decodedImage, angle: 90);
      // After rotation, swap dimensions
      final temp = imgWidth;
      imgWidth = imgHeight;
      imgHeight = temp;
    } else {
      finalImage = decodedImage;
    }

    // Encode back to PNG for PDF
    final encodedBytes = Uint8List.fromList(img.encodePng(finalImage));
    final image = PdfBitmap(encodedBytes);

    // Validate image dimensions
    if (image.width <= 0 || image.height <= 0) return;

    // Add small padding
    const padding = 10.0;
    final availableWidth = width - padding * 2;
    final availableHeight = height - padding * 2;

    // Calculate scale to fit in available area
    final scaleX = availableWidth / imgWidth;
    final scaleY = availableHeight / imgHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final drawWidth = imgWidth * scale;
    final drawHeight = imgHeight * scale;

    // Ensure valid dimensions
    if (drawWidth <= 0 || drawHeight <= 0) return;

    // Center the image
    final drawX = x + (width - drawWidth) / 2;
    final drawY = y + (height - drawHeight) / 2;

    graphics.drawImage(
      image,
      Rect.fromLTWH(drawX, drawY, drawWidth, drawHeight),
    );
  }

  /// Draw a PDF invoice (first page only)
  static Future<void> _drawPdfInvoice({
    required PdfGraphics graphics,
    required List<int> pdfBytes,
    required double x,
    required double y,
    required double width,
    required double height,
  }) async {
    try {
      // Load the source PDF
      final sourceDoc = PdfDocument(inputBytes: pdfBytes);
      if (sourceDoc.pages.count == 0) {
        sourceDoc.dispose();
        return;
      }

      // Get the first page
      final sourcePage = sourceDoc.pages[0];

      // Get source page dimensions
      final sourceWidth = sourcePage.size.width;
      final sourceHeight = sourcePage.size.height;

      // Check if PDF needs rotation (if height > width)
      bool needsRotation = sourceHeight > sourceWidth;

      // Add small padding
      const padding = 10.0;
      final availableWidth = width - padding * 2;
      final availableHeight = height - padding * 2;

      // Calculate effective dimensions after rotation
      double effectiveWidth, effectiveHeight;
      if (needsRotation) {
        effectiveWidth = sourceHeight;
        effectiveHeight = sourceWidth;
      } else {
        effectiveWidth = sourceWidth;
        effectiveHeight = sourceHeight;
      }

      // Calculate scale
      final scaleX = availableWidth / effectiveWidth;
      final scaleY = availableHeight / effectiveHeight;
      final scale = scaleX < scaleY ? scaleX : scaleY;

      final drawWidth = effectiveWidth * scale;
      final drawHeight = effectiveHeight * scale;

      // Center the content
      final drawX = x + (width - drawWidth) / 2;
      final drawY = y + (height - drawHeight) / 2;

      // Create a template from the source page
      final template = sourcePage.createTemplate();

      // Draw the template
      if (needsRotation) {
        // For rotation, we use PdfPageLayer with transform
        // Draw at the calculated position with rotation
        graphics.save();
        graphics.translateTransform(drawX + drawWidth / 2, drawY + drawHeight / 2);
        graphics.rotateTransform(-90);
        graphics.drawPdfTemplate(
          template,
          Offset(-drawHeight / 2, -drawWidth / 2),
          Size(drawHeight, drawWidth),
        );
        graphics.restore();
      } else {
        graphics.drawPdfTemplate(
          template,
          Offset(drawX, drawY),
          Size(drawWidth, drawHeight),
        );
      }

      sourceDoc.dispose();
    } catch (e) {
      debugPrint('Error processing PDF invoice: $e');
    }
  }

  /// Draw time label at specified position
  static void _drawTimeLabel({
    required PdfGraphics graphics,
    required String label,
    required PdfFont font,
    required double x,
    required double y,
    required double width,
    required double height,
    required _LabelPosition position,
    required double margin,
    double maxWidth = 200, // Max width for label before wrapping
  }) {
    if (label.isEmpty) return;

    // Create string format with word wrap
    final format = PdfStringFormat(
      wordWrap: PdfWordWrapType.word,
    );

    // Measure the text size (single line for width estimate)
    final singleLineSize = font.measureString(label);

    // Estimate number of lines needed
    final estimatedLines = (singleLineSize.width / maxWidth).ceil() + 1;
    final labelHeight = font.height * estimatedLines;

    // Calculate label position
    double labelX, labelY;

    switch (position) {
      case _LabelPosition.topLeft:
        labelX = x + margin;
        labelY = y + margin;
        break;
      case _LabelPosition.bottomLeft:
        labelY = y + height - margin - labelHeight;
        labelX = x + margin;
        break;
    }

    // Draw background for better readability (use estimated height)
    final bgRect = Rect.fromLTWH(
      labelX - 2,
      labelY - 2,
      maxWidth + 4,
      labelHeight + 4,
    );

    // Draw semi-transparent white background
    graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(255, 255, 255, 220)),
      bounds: bgRect,
    );

    // Draw label text with wrapping
    graphics.drawString(
      label,
      font,
      brush: PdfSolidBrush(PdfColor(0, 0, 0)),
      bounds: Rect.fromLTWH(labelX, labelY, maxWidth, labelHeight),
      format: format,
    );
  }
}

/// Label position enum
enum _LabelPosition {
  topLeft,
  bottomLeft,
}
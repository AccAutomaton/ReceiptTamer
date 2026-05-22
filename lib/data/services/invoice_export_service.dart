import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:receipt_tamer/core/services/pdf_font_service.dart';
import 'package:receipt_tamer/core/services/pdfrx_font_service.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart' as pdfrx;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../core/services/log_service.dart';
import '../../core/services/log_config.dart';

/// Meal entry helper class for time label generation
class _MealEntry {
  final String date;
  final String mealTime;
  _MealEntry({required this.date, required this.mealTime});
}

/// Invoice export item for PDF generation
/// Represents a single invoice with its associated orders
class InvoiceExportItem {
  final Invoice invoice;
  final List<Order> orders;
  final String? remark; // 发票备注

  const InvoiceExportItem({
    required this.invoice,
    required this.orders,
    this.remark,
  });

  /// Generate truncated time label for the invoice
  /// Format: "yyyy年MM月dd日早/中/晚餐"
  /// Same day meals are combined with "、" (e.g., "中、晚餐")
  /// Different days are separated with "|" (e.g., "早餐|午餐")
  /// When more than 5 orders, show first 5 then "...等共计x个订单"
  String get truncatedTimeLabel {
    if (orders.isEmpty) return '';

    // Collect all meal entries with date and meal time
    final mealEntries = <_MealEntry>[];
    for (final order in orders) {
      final date = order.orderDate ?? '';
      final mealTime = order.mealTime ?? '';
      if (date.isEmpty || mealTime.isEmpty) continue;
      mealEntries.add(_MealEntry(date: date, mealTime: mealTime));
    }

    if (mealEntries.isEmpty) return '';

    // Sort by date and meal time
    mealEntries.sort((a, b) {
      final dateCompare = a.date.compareTo(b.date);
      if (dateCompare != 0) return dateCompare;
      return _mealTimeOrder(a.mealTime).compareTo(_mealTimeOrder(b.mealTime));
    });

    // Determine truncation
    final totalCount = mealEntries.length;
    final displayCount = totalCount > 5 ? 5 : totalCount;
    final displayEntries = mealEntries.take(displayCount).toList();

    // Group by date
    final Map<String, List<String>> dateMealMap = {};
    for (final entry in displayEntries) {
      dateMealMap.putIfAbsent(entry.date, () => []);
      if (!dateMealMap[entry.date]!.contains(entry.mealTime)) {
        dateMealMap[entry.date]!.add(entry.mealTime);
      }
    }

    // Sort dates
    final sortedDates = dateMealMap.keys.toList()..sort();

    // Build label parts
    final parts = <String>[];
    for (final date in sortedDates) {
      final mealTimes = dateMealMap[date]!;
      mealTimes.sort((a, b) => _mealTimeOrder(a).compareTo(_mealTimeOrder(b)));

      final datePart = _formatDate(date);
      final mealPart = mealTimes.map(_mealTimeDisplayName).join('、');
      parts.add('$datePart$mealPart');
    }

    // Add truncation suffix if needed
    if (totalCount > 5) {
      parts.add('...等共计$totalCount个订单');
    }

    return parts.join('|');
  }

  /// Generate full label combining remark and time label
  /// Format: "备注内容|时间标签" or "备注内容" or "时间标签"
  String get fullLabel {
    final parts = <String>[];

    // Add remark if present
    if (remark != null && remark!.isNotEmpty) {
      parts.add(remark!);
    }

    // Add truncated time label
    final timeLabel = truncatedTimeLabel;
    if (timeLabel.isNotEmpty) {
      parts.add(timeLabel);
    }

    return parts.join('|');
  }

  /// Original timeLabel getter for backward compatibility
  /// Now uses truncatedTimeLabel internally
  String get timeLabel => truncatedTimeLabel;

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
  static const double _pdfRasterDpi = 200;

  /// Prepare invoice export items from selected invoices and their orders
  static Future<List<InvoiceExportItem>> prepareInvoiceExportItems({
    required List<Invoice> invoices,
    required Future<List<int>> Function(int) getOrderIdsForInvoice,
    required Future<Order?> Function(int) getOrderById,
    String? remark, // 统一备注
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

      items.add(
        InvoiceExportItem(invoice: invoice, orders: orders, remark: remark),
      );
    }

    return items;
  }

  /// Generate invoice PDF document
  static Future<void> generateInvoicePdf({
    required List<InvoiceExportItem> items,
    required String outputPath,
    required String Function(String) getFilePath,
    bool showTimeLabel = true, // Whether to show time labels on invoices
    bool showRemark = true, // Whether to show remarks on invoices
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('Items list cannot be empty');
    }

    final document = PdfDocument();
    document.pageSettings.size = PdfPageSize.a4;
    document.pageSettings.margins.all =
        0; // No margins, we'll handle positioning

    // Define fonts - use TrueType font for Chinese characters
    final labelFont = await PdfFontService.instance.getChineseFont(9);

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

        // Margin for labels
        const labelMargin = 16.0;

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
          showRemark: showRemark,
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
            showRemark: showRemark,
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
    bool showRemark = true,
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

      // Draw label if either remark or time label is enabled
      if (showRemark || showTimeLabel) {
        final parts = <String>[];

        // Add remark only if showRemark is enabled
        if (showRemark && item.remark != null && item.remark!.isNotEmpty) {
          parts.add(item.remark!);
        }

        // Add time label only if showTimeLabel is enabled
        if (showTimeLabel) {
          final timeLabel = item.truncatedTimeLabel;
          if (timeLabel.isNotEmpty) {
            parts.add(timeLabel);
          }
        }

        final label = parts.join('|');

        if (label.isNotEmpty) {
          _drawTimeLabel(
            graphics: graphics,
            label: label,
            font: labelFont,
            x: x,
            y: y,
            width: width,
            height: height,
            position: labelPosition,
            margin: labelMargin,
          );
        }
      }
    } catch (e, stackTrace) {
      // Ignore errors for individual invoices
      logService.e(LogConfig.moduleFile, '绘制发票失败', e, stackTrace);
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
      final renderedPage = await _renderFirstPdfPageToPng(pdfBytes);
      if (renderedPage == null) return;

      await _drawImageInvoice(
        graphics: graphics,
        imageBytes: renderedPage,
        x: x,
        y: y,
        width: width,
        height: height,
      );
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleFile, '处理 PDF 发票失败', e, stackTrace);
    }
  }

  /// Render the first PDF page to a PNG with annotations/forms included.
  static Future<List<int>?> _renderFirstPdfPageToPng(List<int> pdfBytes) async {
    final pdfData = Uint8List.fromList(pdfBytes);
    final fontManager = PdfrxFontService.instance.createFontManager();
    await PdfrxFontService.instance.prepareFontManagerForPdfBytes(
      fontManager,
      pdfData,
    );

    final document = await _openPdfDocumentAfterFontWarmup(
      pdfData,
      fontManager,
    );
    try {
      if (document.pages.isEmpty) return null;

      final page = document.pages[0];
      final scale = _pdfRasterDpi / 72;
      final pageImage = await page.render(
        fullWidth: page.width * scale,
        fullHeight: page.height * scale,
        annotationRenderingMode:
            pdfrx.PdfAnnotationRenderingMode.annotationAndForms,
      );
      if (pageImage == null) return null;

      try {
        final image = await pageImage.createImage();
        try {
          final byteData = await image.toByteData(format: ImageByteFormat.png);
          return byteData?.buffer.asUint8List();
        } finally {
          image.dispose();
        }
      } finally {
        pageImage.dispose();
      }
    } finally {
      document.dispose();
    }
  }

  static Future<pdfrx.PdfDocument> _openPdfDocumentAfterFontWarmup(
    Uint8List pdfData,
    pdfrx.PdfFontManager fontManager,
  ) async {
    final document = await pdfrx.PdfDocument.openData(pdfData);
    if (document.pages.isEmpty) return document;

    final loadResult = Completer<pdfrx.PdfFontLoadResult?>();
    final association = document.associateFontManager(
      fontManager,
      onLoadComplete: (result) {
        if (!loadResult.isCompleted) {
          loadResult.complete(result);
        }
      },
    );

    var shouldReturnInitialDocument = true;
    try {
      await document.reloadPages(pageNumbersToReload: const [1]);
      await _renderPdfPageWarmup(document.pages[0]);

      final result = await loadResult.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );

      if (result?.hasLoadedFonts ?? false) {
        shouldReturnInitialDocument = false;
        return await pdfrx.PdfDocument.openData(pdfData);
      }

      return document;
    } finally {
      association.dispose();
      if (!shouldReturnInitialDocument) {
        document.dispose();
      }
    }
  }

  static Future<void> _renderPdfPageWarmup(pdfrx.PdfPage page) async {
    final pageImage = await page.render(
      fullWidth: 8,
      fullHeight: 8,
      annotationRenderingMode:
          pdfrx.PdfAnnotationRenderingMode.annotationAndForms,
    );
    pageImage?.dispose();
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
    final format = PdfStringFormat(wordWrap: PdfWordWrapType.word);

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
enum _LabelPosition { topLeft, bottomLeft }

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

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
    return buildLabel();
  }

  /// Build the label exactly as it will be stamped on the exported invoice.
  String buildLabel({bool showTimeLabel = true, bool showRemark = true}) {
    final parts = <String>[];

    // Add remark if present
    if (showRemark && remark != null && remark!.isNotEmpty) {
      parts.add(remark!);
    }

    // Add truncated time label
    if (showTimeLabel) {
      final timeLabel = truncatedTimeLabel;
      if (timeLabel.isNotEmpty) {
        parts.add(timeLabel);
      }
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

/// Result of checking whether selected invoice attachments can be exported.
class InvoiceAttachmentValidationResult {
  const InvoiceAttachmentValidationResult({
    required this.exportableItems,
    required this.unavailableItems,
  });

  final List<InvoiceExportItem> exportableItems;
  final List<InvoiceExportItem> unavailableItems;

  bool get hasUnavailableItems => unavailableItems.isNotEmpty;
}

/// Raised when an invoice attachment is missing, empty, or cannot be rendered.
class InvoiceAttachmentUnavailableException implements Exception {
  const InvoiceAttachmentUnavailableException(this.invoices, {this.cause});

  final List<Invoice> invoices;
  final Object? cause;

  @override
  String toString() {
    final count = invoices.length;
    return '有$count张发票的附件缺失或损坏，请在发票详情中重新添加附件';
  }
}

/// Invoice export service
/// Generates PDF documents from selected invoices
class InvoiceExportService {
  static const double _pdfRasterDpi = 200;
  static const Duration _pdfFontLoadTimeout = Duration(milliseconds: 250);
  static const Duration _slowInvoiceStepThreshold = Duration(milliseconds: 500);

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

  /// Partition items before export so callers can report partial selection
  /// problems instead of creating an empty PDF and claiming success.
  static Future<InvoiceAttachmentValidationResult> validateAttachments({
    required List<InvoiceExportItem> items,
    required String Function(String) getFilePath,
  }) async {
    final exportableItems = <InvoiceExportItem>[];
    final unavailableItems = <InvoiceExportItem>[];

    for (final item in items) {
      try {
        final sourcePath = item.invoice.imagePath.trim();
        if (sourcePath.isEmpty) {
          unavailableItems.add(item);
          continue;
        }
        final file = File(getFilePath(sourcePath));
        if (!await file.exists() || await file.length() == 0) {
          unavailableItems.add(item);
          continue;
        }
        exportableItems.add(item);
      } catch (_) {
        unavailableItems.add(item);
      }
    }

    return InvoiceAttachmentValidationResult(
      exportableItems: List.unmodifiable(exportableItems),
      unavailableItems: List.unmodifiable(unavailableItems),
    );
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
    if (outputPath.isEmpty) {
      throw ArgumentError('Output path cannot be empty');
    }

    final validation = await validateAttachments(
      items: items,
      getFilePath: getFilePath,
    );
    if (validation.hasUnavailableItems) {
      throw InvoiceAttachmentUnavailableException(
        validation.unavailableItems.map((item) => item.invoice).toList(),
      );
    }

    final document = PdfDocument();
    document.pageSettings.size = PdfPageSize.a4;
    document.pageSettings.margins.all =
        0; // No margins, we'll handle positioning

    // Define fonts - use TrueType font for Chinese characters
    final labelFont = await PdfFontService.instance.getChineseFont(9);
    final exportStopwatch = Stopwatch()..start();

    logService.diagBatch(LogConfig.moduleFile, {
      'invoice_export_items': items.length,
      'invoice_export_pdf_sources': _countPdfInvoiceSources(items),
    });

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

      exportStopwatch.stop();
      logService.diag(
        LogConfig.moduleFile,
        'invoice_export_total_ms',
        exportStopwatch.elapsedMilliseconds,
      );
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
    try {
      final drawStopwatch = Stopwatch()..start();
      final imagePath = item.invoice.imagePath.trim();
      final resolvedPath = getFilePath(imagePath);
      final file = File(resolvedPath);

      // Check if it's a PDF or image
      final isPdf = imagePath.toLowerCase().endsWith('.pdf');
      final bytes = await file.readAsBytes();

      if (isPdf) {
        await _drawPdfInvoice(
          graphics: graphics,
          pdfBytes: bytes,
          sourcePath: resolvedPath,
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

      final label = item.buildLabel(
        showTimeLabel: showTimeLabel,
        showRemark: showRemark,
      );
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

      drawStopwatch.stop();
      if (drawStopwatch.elapsed >= _slowInvoiceStepThreshold) {
        logService.diag(
          LogConfig.moduleFile,
          'invoice_draw_ms',
          '${drawStopwatch.elapsedMilliseconds}ms $resolvedPath',
        );
      }
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleFile, '绘制发票失败', e, stackTrace);
      throw InvoiceAttachmentUnavailableException([item.invoice], cause: e);
    }
  }

  static int _countPdfInvoiceSources(List<InvoiceExportItem> items) {
    final resolvedPaths = <String>{};
    for (final item in items) {
      final imagePath = item.invoice.imagePath;
      if (imagePath.isEmpty || !imagePath.toLowerCase().endsWith('.pdf')) {
        continue;
      }

      resolvedPaths.add(imagePath);
    }
    return resolvedPaths.length;
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
    if (decodedImage == null) {
      throw const FormatException('无法解码发票图片');
    }

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

    if (!needsRotation) {
      try {
        _drawBitmapBytes(
          graphics: graphics,
          imageBytes: uint8Bytes,
          imageWidth: imgWidth,
          imageHeight: imgHeight,
          x: x,
          y: y,
          width: width,
          height: height,
        );
        return;
      } catch (_) {
        // Some decoded image formats are not accepted by Syncfusion directly.
      }
    }

    _drawBitmapBytes(
      graphics: graphics,
      imageBytes: Uint8List.fromList(img.encodePng(finalImage)),
      imageWidth: imgWidth,
      imageHeight: imgHeight,
      x: x,
      y: y,
      width: width,
      height: height,
    );
  }

  static void _drawBitmapBytes({
    required PdfGraphics graphics,
    required List<int> imageBytes,
    required double imageWidth,
    required double imageHeight,
    required double x,
    required double y,
    required double width,
    required double height,
  }) {
    final image = PdfBitmap(imageBytes);
    if (image.width <= 0 || image.height <= 0) {
      throw const FormatException('发票图片尺寸无效');
    }

    final bitmapWidth = imageWidth > 0 ? imageWidth : image.width.toDouble();
    final bitmapHeight = imageHeight > 0
        ? imageHeight
        : image.height.toDouble();

    // Add small padding
    const padding = 10.0;
    final availableWidth = width - padding * 2;
    final availableHeight = height - padding * 2;

    // Calculate scale to fit in available area
    final scaleX = availableWidth / bitmapWidth;
    final scaleY = availableHeight / bitmapHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final drawWidth = bitmapWidth * scale;
    final drawHeight = bitmapHeight * scale;

    // Ensure valid dimensions
    if (drawWidth <= 0 || drawHeight <= 0) {
      throw const FormatException('发票图片绘制尺寸无效');
    }

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
    required String sourcePath,
    required double x,
    required double y,
    required double width,
    required double height,
  }) async {
    try {
      final renderStopwatch = Stopwatch()..start();
      final renderedPage = await _renderFirstPdfPageToPng(pdfBytes);
      renderStopwatch.stop();
      if (renderedPage == null) {
        throw const FormatException('无法渲染发票 PDF 首页');
      }

      if (renderStopwatch.elapsed >= _slowInvoiceStepThreshold) {
        logService.diag(
          LogConfig.moduleFile,
          'invoice_pdf_render_ms',
          '${renderStopwatch.elapsedMilliseconds}ms $sourcePath',
        );
      }

      if (renderedPage.width >= renderedPage.height) {
        _drawBitmapBytes(
          graphics: graphics,
          imageBytes: renderedPage.pngBytes,
          imageWidth: renderedPage.width.toDouble(),
          imageHeight: renderedPage.height.toDouble(),
          x: x,
          y: y,
          width: width,
          height: height,
        );
        return;
      }

      await _drawImageInvoice(
        graphics: graphics,
        imageBytes: renderedPage.pngBytes,
        x: x,
        y: y,
        width: width,
        height: height,
      );
    } catch (e, stackTrace) {
      logService.e(LogConfig.moduleFile, '处理 PDF 发票失败', e, stackTrace);
      rethrow;
    }
  }

  /// Render the first PDF page to a PNG with annotations/forms included.
  static Future<_RenderedPdfPage?> _renderFirstPdfPageToPng(
    List<int> pdfBytes,
  ) async {
    final pdfData = pdfBytes is Uint8List
        ? pdfBytes
        : Uint8List.fromList(pdfBytes);
    await PdfrxFontService.instance.clearLoadedPdfiumFonts();

    try {
      final fontManager = PdfrxFontService.instance.createFontManager();
      await PdfrxFontService.instance.prepareFontManagerForPdfBytes(
        fontManager,
        pdfData,
      );

      final document = await _openPdfDocumentAfterFontWarmup(
        pdfData,
        fontManager,
        waitForFontLoad: true,
      );
      try {
        if (document.pages.isEmpty) return null;

        final page = document.pages[0];
        final scale = _pdfRasterDpi / 72;
        final renderWidth = page.width * scale;
        final renderHeight = page.height * scale;
        final pageImage = await page.render(
          fullWidth: renderWidth,
          fullHeight: renderHeight,
          annotationRenderingMode:
              pdfrx.PdfAnnotationRenderingMode.annotationAndForms,
        );
        if (pageImage == null) return null;

        try {
          final image = await pageImage.createImage();
          try {
            final byteData = await image.toByteData(
              format: ImageByteFormat.png,
            );
            if (byteData == null) return null;
            return _RenderedPdfPage(
              pngBytes: byteData.buffer.asUint8List(
                byteData.offsetInBytes,
                byteData.lengthInBytes,
              ),
              width: image.width,
              height: image.height,
            );
          } finally {
            image.dispose();
          }
        } finally {
          pageImage.dispose();
        }
      } finally {
        document.dispose();
      }
    } finally {
      await PdfrxFontService.instance.clearLoadedPdfiumFonts();
    }
  }

  static Future<pdfrx.PdfDocument> _openPdfDocumentAfterFontWarmup(
    Uint8List pdfData,
    pdfrx.PdfFontManager fontManager, {
    required bool waitForFontLoad,
  }) async {
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
      if (!waitForFontLoad) return document;

      final result = await loadResult.future.timeout(
        _pdfFontLoadTimeout,
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
    final format = PdfStringFormat(wordWrap: PdfWordWrapType.character);

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

    // Keep the stamp legible over dark or busy invoice content.
    graphics.drawRectangle(
      bounds: Rect.fromLTWH(
        labelX - 3,
        labelY - 2,
        maxWidth + 6,
        labelHeight + 4,
      ),
      brush: PdfSolidBrush(PdfColor(255, 255, 255)),
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
enum _LabelPosition { topLeft, bottomLeft }

class _RenderedPdfPage {
  const _RenderedPdfPage({
    required this.pngBytes,
    required this.width,
    required this.height,
  });

  final Uint8List pngBytes;
  final int width;
  final int height;
}
